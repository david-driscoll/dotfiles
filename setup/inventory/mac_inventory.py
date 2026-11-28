#!/usr/bin/env python3
"""mac_inventory.py — read-only inventory of a Mac's apps and tools.

Subcommands
-----------
collect   Snapshot this Mac to JSON (apps + last-used dates, Homebrew, Mac App
          Store, mise, other global package managers, shell-history usage).
          Needs only the system python3 (3.9, from the Command Line Tools),
          so it also works on a Mac that has not been bootstrapped yet, or
          over SSH:  ssh other-mac python3 - collect < mac_inventory.py
report    Turn one snapshot into a Markdown report: apps and CLI tools that
          look unused, Homebrew formulae duplicated by mise tools, and drift
          between what is installed and what the dotfiles declare.
diff      Compare two snapshots (e.g. this Mac vs the other one).

Nothing here installs, removes, or changes anything. Snapshots hold a list of
installed software, so they are written outside this (public) repository —
see the mac:inventory tasks in .config/mise/config.macos.toml.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

SCHEMA_VERSION = 1
HOME = Path.home()
NOW = dt.datetime.now(dt.timezone.utc)

# Apps that ship with macOS or are otherwise not worth flagging as "unused".
APPLE_BUNDLE_PREFIX = "com.apple."

# Apps used within this many days count as "in use".
DEFAULT_STALE_DAYS = 90

# Words that start a shell segment but are not the command being run.
COMMAND_PREFIXES = {
    "sudo", "time", "nohup", "env", "exec", "command", "builtin", "noglob",
    "watch", "xargs", "nice", "caffeinate", "&", "!",
}


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def run(cmd: List[str], timeout: int = 120) -> Tuple[int, str]:
    """Run a command, returning (exit code, stdout). Never raises."""
    if shutil.which(cmd[0]) is None and not os.path.isabs(cmd[0]):
        return 127, ""
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1", "MISE_QUIET": "1"},
        )
        return proc.returncode, proc.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def run_json(cmd: List[str], timeout: int = 120) -> Any:
    code, out = run(cmd, timeout)
    if code != 0 or not out.strip():
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def iso(ts: Optional[float]) -> Optional[str]:
    if ts is None:
        return None
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).isoformat(timespec="seconds")


def parse_iso(value: Optional[str]) -> Optional[dt.datetime]:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value)
    except ValueError:
        return None


def days_since(value: Optional[str]) -> Optional[int]:
    when = parse_iso(value)
    return None if when is None else (NOW - when).days


def mtime(path: Path) -> Optional[float]:
    try:
        return path.stat().st_mtime
    except OSError:
        return None


def log(msg: str) -> None:
    print(f"[mac-inventory] {msg}", file=sys.stderr)


# --------------------------------------------------------------------------
# collect
# --------------------------------------------------------------------------

def collect_host() -> Dict[str, Any]:
    _, name = run(["scutil", "--get", "ComputerName"])
    _, local = run(["scutil", "--get", "LocalHostName"])
    _, model = run(["sysctl", "-n", "hw.model"])
    _, chip = run(["sysctl", "-n", "machdep.cpu.brand_string"])
    _, setup_done = run(["stat", "-f", "%B", "/private/var/db/.AppleSetupDone"])
    return {
        "computer_name": name.strip(),
        "local_host_name": local.strip(),
        "model": model.strip(),
        "chip": chip.strip(),
        "arch": platform.machine(),
        "macos": platform.mac_ver()[0],
        "setup_date": iso(float(setup_done)) if setup_done.strip().isdigit() else None,
        "collected_at": NOW.isoformat(timespec="seconds"),
    }


def spotlight_attrs(app: Path) -> Dict[str, Any]:
    """Read launch metadata from Spotlight as a plist (no date parsing needed)."""
    names = ["kMDItemLastUsedDate", "kMDItemUseCount", "kMDItemCFBundleIdentifier",
             "kMDItemVersion", "kMDItemPhysicalSize", "kMDItemAppStoreHasReceipt"]
    cmd = ["mdls", "-plist", "-"]
    for n in names:
        cmd += ["-name", n]
    try:
        proc = subprocess.run(cmd + [str(app)], capture_output=True, timeout=30)
        return plistlib.loads(proc.stdout) if proc.returncode == 0 and proc.stdout else {}
    except (OSError, subprocess.TimeoutExpired, plistlib.InvalidFileException, ValueError):
        return {}


def info_plist(app: Path) -> Dict[str, Any]:
    try:
        with open(app / "Contents" / "Info.plist", "rb") as fh:
            return plistlib.load(fh)
    except (OSError, plistlib.InvalidFileException, ValueError):
        return {}


def activity_time(bundle_id: Optional[str], name: str) -> Optional[float]:
    """Latest mtime among an app's preference/data locations.

    A fallback when Spotlight has no launch record. Background/menu-bar apps
    touch these without being "used", so the report labels it separately.
    """
    lib = HOME / "Library"
    candidates = [lib / "Application Support" / name]
    if bundle_id:
        candidates += [
            lib / "Preferences" / f"{bundle_id}.plist",
            lib / "Containers" / bundle_id,
            lib / "Application Support" / bundle_id,
            lib / "Caches" / bundle_id,
            lib / "HTTPStorages" / bundle_id,
            lib / "Saved Application State" / f"{bundle_id}.savedState",
        ]
    times = [t for t in (mtime(p) for p in candidates) if t is not None]
    return max(times) if times else None


def find_apps() -> List[Path]:
    """Apps in /Applications and ~/Applications, plus one level of grouping
    folders (e.g. /Applications/Utilities, ~/Applications/CrossOver).
    Browser web-app shim folders ("Chrome Apps.localized") are skipped."""
    apps: List[Path] = []
    seen: Set[str] = set()

    def add(path: Path) -> None:
        key = str(path.resolve())
        if key not in seen:
            seen.add(key)
            apps.append(path)

    for root in (Path("/Applications"), HOME / "Applications"):
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if entry.suffix == ".app":
                add(entry)
            elif entry.is_dir() and not entry.name.startswith(".") and not entry.name.endswith(" Apps.localized"):
                for child in sorted(entry.iterdir()):
                    if child.suffix == ".app":
                        add(child)
    return apps


def collect_brew() -> Dict[str, Any]:
    brew = shutil.which("brew") or next(
        (p for p in ("/opt/homebrew/bin/brew", "/usr/local/bin/brew") if os.path.exists(p)), None)
    if not brew:
        return {"available": False}
    info = run_json([brew, "info", "--json=v2", "--installed"], timeout=300) or {}
    prefix = run([brew, "--prefix"])[1].strip()
    _, leaves_out = run([brew, "leaves", "--installed-on-request"])
    _, taps_out = run([brew, "tap"])

    formulae = []
    for f in info.get("formulae", []):
        inst = (f.get("installed") or [{}])[-1]
        opt_bin = Path(prefix) / "opt" / f["name"] / "bin"
        bins = sorted(p.name for p in opt_bin.iterdir()) if opt_bin.is_dir() else []
        formulae.append({
            "name": f["name"],
            "full_name": f.get("full_name", f["name"]),
            "tap": f.get("tap"),
            "version": inst.get("version"),
            "on_request": bool(inst.get("installed_on_request")),
            "desc": f.get("desc"),
            "bins": bins,
        })

    casks = []
    for c in info.get("casks", []):
        apps, bins, bundle_ids = [], [], []
        for art in c.get("artifacts", []):
            if not isinstance(art, dict):
                continue
            for app in art.get("app", []):
                if isinstance(app, str):
                    apps.append(app)
                elif isinstance(app, dict) and app.get("target"):
                    apps.append(Path(app["target"]).name)
            for b in art.get("binary", []):
                if isinstance(b, str):
                    bins.append(Path(b).name)
            # pkg-installed casks have no `app` artifact; their uninstall
            # stanza names the bundle IDs it quits, which identifies the app.
            for stanza in art.get("uninstall", []) + art.get("zap", []):
                quit_ids = stanza.get("quit", []) if isinstance(stanza, dict) else []
                bundle_ids += [quit_ids] if isinstance(quit_ids, str) else quit_ids
        casks.append({
            "token": c["token"],
            "full_token": c.get("full_token", c["token"]),
            "tap": c.get("tap"),
            "version": c.get("installed"),
            "auto_updates": bool(c.get("auto_updates")),
            "desc": c.get("desc"),
            "apps": apps,
            "bins": bins,
            "bundle_ids": sorted(set(bundle_ids)),
        })

    return {
        "available": True,
        "prefix": prefix,
        "leaves": leaves_out.split(),
        "taps": taps_out.split(),
        "formulae": formulae,
        "casks": casks,
    }


def collect_mas() -> List[Dict[str, Any]]:
    code, out = run(["mas", "list"])
    if code != 0:
        return []
    apps = []
    for line in out.splitlines():
        m = re.match(r"\s*(\d+)\s+(.+?)\s+\(([^)]*)\)\s*$", line)
        if m:
            apps.append({"id": m.group(1), "name": m.group(2).strip(), "version": m.group(3)})
    return apps


def collect_mise() -> Dict[str, Any]:
    data = run_json(["mise", "ls", "--json"])
    if data is None:
        return {"available": False}
    _, bin_paths_out = run(["mise", "bin-paths"])
    bin_dirs = [Path(l.strip()) for l in bin_paths_out.splitlines() if l.strip()]

    def tool_bins(install_path: str) -> List[str]:
        names: Set[str] = set()
        for d in bin_dirs:
            if str(d).startswith(install_path) and d.is_dir():
                names |= {f.name for f in d.iterdir() if f.is_file() and os.access(f, os.X_OK)}
        return sorted(names)

    tools = []
    for name, versions in data.items():
        for v in versions:
            tools.append({
                "name": name,
                "version": v.get("version"),
                "installed": bool(v.get("installed")),
                "active": bool(v.get("active")),
                "source": (v.get("source") or {}).get("path"),
                "bins": tool_bins(v.get("install_path", "")) if v.get("active") else [],
            })
    prune_out = ""
    try:
        proc = subprocess.run(["mise", "prune", "--dry-run", "--yes"], capture_output=True, text=True, timeout=120)
        prune_out = "\n".join(l for l in (proc.stdout + proc.stderr).splitlines()
                              if "[dryrun]" in l and "configuration links" not in l)
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {
        "available": True,
        "version": run(["mise", "--version"])[1].strip(),
        "tools": tools,
        "prunable": [l.strip() for l in prune_out.splitlines() if l.strip()],
    }


def collect_other_managers() -> Dict[str, Any]:
    result: Dict[str, Any] = {}

    npm = run_json(["npm", "ls", "-g", "--depth=0", "--json"])
    result["npm_global"] = sorted(set((npm or {}).get("dependencies", {})) - {"npm", "corepack"})

    code, out = run(["uv", "tool", "list"])
    result["uv_tools"] = [l.split()[0] for l in out.splitlines() if l and not l.startswith(("-", " "))] if code == 0 else []

    code, out = run(["pipx", "list", "--short"])
    result["pipx"] = [l.split()[0] for l in out.splitlines() if l.strip()] if code == 0 else []

    code, out = run(["dotnet", "tool", "list", "-g"])
    result["dotnet_tools"] = [l.split()[0] for l in out.splitlines()[2:] if l.strip()] if code == 0 else []

    code, out = run(["gh", "extension", "list"])
    result["gh_extensions"] = [l.split("\t")[1] for l in out.splitlines() if "\t" in l] if code == 0 else []

    for key, binary in (("vscode_extensions", "code"), ("vscode_insiders_extensions", "code-insiders")):
        code, out = run([binary, "--list-extensions"])
        result[key] = out.split() if code == 0 else []

    code, out = run(["volta", "list", "all", "--format=plain"])
    result["volta"] = [l.strip() for l in out.splitlines() if l.strip()] if code == 0 else []

    code, out = run(["kubectl", "krew", "list"])
    result["krew"] = out.split() if code == 0 else []

    cargo_bin = HOME / ".cargo" / "bin"
    result["cargo_bin"] = sorted(p.name for p in cargo_bin.iterdir()) if cargo_bin.is_dir() else []
    go_bin = HOME / "go" / "bin"
    result["go_bin"] = sorted(p.name for p in go_bin.iterdir()) if go_bin.is_dir() else []
    result["conda"] = any((HOME / d).exists() for d in ("miniconda3", "anaconda3", ".conda"))
    return result


def collect_login_items() -> Dict[str, Any]:
    code, out = run(["osascript", "-e",
                     'tell application "System Events" to get the name of every login item'], timeout=20)
    items = [s.strip() for s in out.split(",") if s.strip()] if code == 0 else []
    agents_dir = HOME / "Library" / "LaunchAgents"
    agents = sorted(p.name for p in agents_dir.glob("*.plist")) if agents_dir.is_dir() else []
    return {"login_items": items, "launch_agents": agents}


def split_segments(line: str) -> Iterable[str]:
    for seg in re.split(r"\|\|?|&&|;|\$\(|`|\(", line):
        words = seg.strip().split()
        while words and (words[0] in COMMAND_PREFIXES or "=" in words[0]):
            words.pop(0)
        if words and words[0] in ("mise", "mise.exe") and len(words) > 2 and words[1] in ("x", "exec"):
            words = words[words.index("--") + 1:] if "--" in words else words[2:]
        if words:
            yield words[0].split("/")[-1]
            if len(words) > 1 and words[0] in ("gh", "kubectl", "brew", "dotnet"):
                yield f"{words[0]} {words[1]}"


def collect_shell_usage() -> Dict[str, Any]:
    """Count how often each command appears in shell history.

    zsh history carries timestamps (EXTENDED_HISTORY). PowerShell's
    PSReadLine history does not, so for pwsh we only count, plus a count over
    its most recent RECENT_PWSH_LINES lines as a rough recency signal.
    """
    RECENT_PWSH_LINES = 3000
    usage: Dict[str, Dict[str, Any]] = {}

    def bump(cmd: str, field: str, ts: Optional[float] = None) -> None:
        entry = usage.setdefault(cmd, {"zsh": 0, "pwsh": 0, "pwsh_recent": 0, "bash": 0, "last": None})
        entry[field] += 1
        if ts is not None and (entry["last"] is None or ts > entry["last"]):
            entry["last"] = ts

    zsh = HOME / ".zsh_history"
    if zsh.is_file():
        data = zsh.read_bytes().decode("utf-8", errors="replace")
        for line in data.splitlines():
            m = re.match(r"^: (\d+):\d+;(.*)$", line)
            ts, text = (float(m.group(1)), m.group(2)) if m else (None, line)
            for cmd in set(split_segments(text)):
                bump(cmd, "zsh", ts)

    pwsh = HOME / ".local/share/powershell/PSReadLine/ConsoleHost_history.txt"
    if pwsh.is_file():
        lines = pwsh.read_text(errors="replace").splitlines()
        recent_from = max(0, len(lines) - RECENT_PWSH_LINES)
        for i, text in enumerate(lines):
            for cmd in set(split_segments(text)):
                bump(cmd, "pwsh")
                if i >= recent_from:
                    bump(cmd, "pwsh_recent")

    bash = HOME / ".bash_history"
    if bash.is_file():
        for text in bash.read_text(errors="replace").splitlines():
            for cmd in set(split_segments(text)):
                bump(cmd, "bash")

    for entry in usage.values():
        entry["last"] = iso(entry["last"])

    rc_words: Set[str] = set()
    rc_files = [HOME / ".zshrc", HOME / ".zprofile", HOME / ".bashrc", HOME / ".bash_aliases"]
    for pattern in ("profile*.ps1", "profile.pwsh/*.ps1", "powershell/*.ps1"):
        rc_files += list((HOME / "dotfiles").glob(pattern))
    for f in rc_files:
        try:
            rc_words |= set(re.findall(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", f.read_text(errors="replace")))
        except OSError:
            pass
    return {
        "shell_init_words": sorted(rc_words),
        "sources": {"zsh": zsh.is_file(), "pwsh": pwsh.is_file(), "bash": bash.is_file()},
        "pwsh_history_mtime": iso(mtime(pwsh)),
        "commands": usage,
    }


def collect_apps(brew: Dict[str, Any], mas: List[Dict[str, Any]], login: Dict[str, Any]) -> List[Dict[str, Any]]:
    cask_by_app: Dict[str, str] = {}
    cask_by_bundle: Dict[str, str] = {}
    cask_by_norm: Dict[str, str] = {}
    for c in brew.get("casks", []):
        for a in c["apps"]:
            cask_by_app[a] = c["token"]
        for b in c.get("bundle_ids", []):
            cask_by_bundle.setdefault(b, c["token"])
        cask_by_norm.setdefault(_norm(re.sub(r"-app$", "", c["token"])), c["token"])
    mas_names = [m["name"].lower() for m in mas]
    mas_by_name = {m["name"].lower(): m["id"] for m in mas if mas_names.count(m["name"].lower()) == 1}
    login_items = {s.lower() for s in login.get("login_items", [])}

    apps = []
    for path in find_apps():
        if path.name.startswith(".") or "uninstall" in path.name.lower():
            continue
        md = spotlight_attrs(path)
        plist = info_plist(path)
        bundle_id = md.get("kMDItemCFBundleIdentifier") or plist.get("CFBundleIdentifier")
        name = path.stem
        has_receipt = bool(md.get("kMDItemAppStoreHasReceipt")) or (path / "Contents" / "_MASReceipt").exists()
        mas_id = mas_by_name.get(name.lower())
        if mas_id is None and has_receipt:
            # mas names occasionally differ from the bundle name ("Keynote" vs "Keynote Creator Studio").
            mas_id = next((i for n, i in mas_by_name.items() if n.split()[0] == name.lower().split()[0]), None)
        cask = (cask_by_app.get(path.name) or cask_by_bundle.get(bundle_id or "")
                or cask_by_norm.get(_norm(name)))
        resolved = str(path.resolve())
        if bundle_id and bundle_id.startswith(APPLE_BUNDLE_PREFIX) and not has_receipt or resolved.startswith("/System/"):
            source = "apple"
        elif cask:
            source = "cask"
        elif has_receipt:
            source = "mas"
        elif (bundle_id or "").startswith("com.jetbrains.") and bundle_id != "com.jetbrains.toolbox":
            source = "jetbrains-toolbox"   # installed and updated by JetBrains Toolbox
        else:
            source = "manual"
        last_used = md.get("kMDItemLastUsedDate")
        apps.append({
            "name": name,
            "path": str(path),
            "bundle_id": bundle_id,
            "version": md.get("kMDItemVersion") or plist.get("CFBundleShortVersionString"),
            "source": source,
            "cask": cask,
            "mas_id": mas_id,
            # mdls -plist dates are naive UTC; astimezone() would misread them as local time.
            "last_used": last_used.replace(tzinfo=dt.timezone.utc).isoformat(timespec="seconds") if isinstance(last_used, dt.datetime) else None,
            "use_count": md.get("kMDItemUseCount"),
            "activity": iso(activity_time(bundle_id, name)),
            "size_mb": round((md.get("kMDItemPhysicalSize") or 0) / 1_048_576),
            "login_item": name.lower() in login_items,
            "arch": "intel-only" if _intel_only(path, plist) else None,
        })
    return apps


def _norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def _intel_only(path: Path, plist: Dict[str, Any]) -> bool:
    exe = plist.get("CFBundleExecutable")
    if not exe:
        return False
    code, out = run(["lipo", "-archs", str(path / "Contents" / "MacOS" / exe)], timeout=10)
    return code == 0 and "arm64" not in out and "x86_64" in out


def cmd_collect(args: argparse.Namespace) -> int:
    log("collecting host info, Homebrew, Mac App Store, mise ...")
    host = collect_host()
    brew = collect_brew()
    mas = collect_mas()
    login = collect_login_items()
    log("reading app metadata (Spotlight) ...")
    apps = collect_apps(brew, mas, login)
    log("collecting mise, other package managers, shell history ...")
    snapshot = {
        "schema": SCHEMA_VERSION,
        "host": host,
        "apps": apps,
        "brew": brew,
        "mas": mas,
        "mise": collect_mise(),
        "other": collect_other_managers(),
        "startup": login,
        "shell_usage": collect_shell_usage(),
    }
    text = json.dumps(snapshot, indent=1, sort_keys=True, default=str)
    if args.out and args.out != "-":
        out = Path(args.out).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
        log(f"wrote {out} ({len(apps)} apps)")
    else:
        sys.stdout.write(text)
    return 0


# --------------------------------------------------------------------------
# declared config (what the dotfiles say should be installed)
# --------------------------------------------------------------------------

def load_declared(dotfiles: Path) -> Optional[Dict[str, Set[str]]]:
    try:
        import tomllib  # Python 3.11+
    except ImportError:
        log("python < 3.11: skipping drift checks (run via `mise run`, which uses mise's python)")
        return None
    declared: Dict[str, Set[str]] = {"tools": set(), "brew": set(), "brew-cask": set(), "mas": set()}
    files = sorted((dotfiles / ".config" / "mise").glob("config*.toml")) + [dotfiles / "mise.toml"]
    for f in files:
        if not f.is_file():
            continue
        with open(f, "rb") as fh:
            cfg = tomllib.load(fh)
        for tool in cfg.get("tools", {}):
            declared["tools"].add(tool_short_name(tool))
        for key in cfg.get("bootstrap", {}).get("packages", {}):
            manager, _, pkg = key.partition(":")
            if manager in declared:
                declared[manager].add(pkg.split("/")[-1])
        # Casks mise can't evaluate are installed by [bootstrap.hooks] commands.
        for cmds in cfg.get("bootstrap", {}).get("hooks", {}).values():
            for cmd in cmds if isinstance(cmds, list) else [cmds]:
                text = cmd if isinstance(cmd, str) else str(cmd.get("run", ""))
                for token in re.findall(r"brew install --cask\s+(\S+)", text):
                    declared["brew-cask"].add(token.split("/")[-1])
    brewfile = dotfiles / "setup" / "Brewfile.darwin"
    if brewfile.is_file():
        for line in brewfile.read_text().splitlines():
            m = re.match(r'\s*(cask|brew|mas)\s+"([^"]+)"(?:,\s*id:\s*(\d+))?', line)
            if m:
                kind, name, mas_id = m.groups()
                bucket = {"cask": "brew-cask", "brew": "brew", "mas": "mas"}[kind]
                declared[bucket].add(mas_id if kind == "mas" else name.split("/")[-1])
    return declared


# mise registry short names that install a differently-named binary/formula.
TOOL_ALIASES = {"flux2": "flux", "powershell": "pwsh", "1password-cli": "op", "task": "go-task"}


def tool_short_name(tool: str) -> str:
    name = tool.split(":", 1)[-1]          # drop backend prefix (aqua:, github:, npm: ...)
    name = name.split("/")[-1]              # owner/repo -> repo
    return name.lstrip("@")


# --------------------------------------------------------------------------
# report
# --------------------------------------------------------------------------

def fmt_date(value: Optional[str]) -> str:
    return value[:10] if value else "—"


def fmt_age(value: Optional[str]) -> str:
    d = days_since(value)
    if d is None:
        return "never recorded"
    return "today" if d == 0 else f"{d}d ago"


def md_table(headers: List[str], rows: List[List[Any]]) -> str:
    if not rows:
        return "_None._\n"
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    for r in rows:
        lines.append("| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |")
    return "\n".join(lines) + "\n"


def app_install_ref(app: Dict[str, Any]) -> str:
    if app["source"] == "cask":
        return f"`brew-cask:{app['cask']}`"
    if app["source"] == "mas" and app.get("mas_id"):
        return f"`mas:{app['mas_id']}`"
    return app["source"]


def classify_apps(apps: List[Dict[str, Any]], stale_days: int) -> Dict[str, List[Dict[str, Any]]]:
    """Split apps into in-use / removal candidates.

    In use: opened within stale_days, a login item, or (when Spotlight has no
    launch record at all) its data folders changed within stale_days.
    """
    buckets: Dict[str, List[Dict[str, Any]]] = {"stale": [], "active": [], "apple": []}
    for a in apps:
        if a["source"] == "apple":
            buckets["apple"].append(a)
            continue
        used = days_since(a["last_used"])
        touched = days_since(a["activity"])
        if a["login_item"]:
            a["evidence"] = "login item"
        elif used is not None and used <= stale_days:
            a["evidence"] = f"opened {fmt_age(a['last_used'])}"
        elif used is None and touched is not None and touched <= stale_days:
            a["evidence"] = f"no launch record; data touched {fmt_age(a['activity'])}"
        else:
            buckets["stale"].append(a)
            continue
        buckets["active"].append(a)
    return buckets


def cli_last_use(usage: Dict[str, Any], names: Iterable[str]) -> Tuple[int, int, Optional[str]]:
    """(total history hits, recent pwsh hits, last zsh timestamp) across bin names."""
    total = recent = 0
    last: Optional[str] = None
    for n in names:
        u = usage.get(n)
        if not u:
            continue
        total += u["zsh"] + u["pwsh"] + u["bash"]
        recent += u["pwsh_recent"]
        if u["last"] and (last is None or u["last"] > last):
            last = u["last"]
    return total, recent, last


def cmd_report(args: argparse.Namespace) -> int:
    snap = json.loads(Path(args.snapshot).expanduser().read_text())
    stale_days = args.stale_days
    host = snap["host"]
    usage = snap.get("shell_usage", {}).get("commands", {})
    shell_init = set(snap.get("shell_usage", {}).get("shell_init_words", []))
    brew = snap.get("brew", {})
    mise = snap.get("mise", {})
    declared = load_declared(Path(args.dotfiles).expanduser()) if args.dotfiles else None

    out: List[str] = []
    w = out.append
    w(f"# Mac inventory — {host['computer_name']}\n")
    w(f"{host['model']} · {host['chip']} · macOS {host['macos']} · set up {fmt_date(host.get('setup_date'))} · "
      f"collected {host['collected_at'][:16].replace('T', ' ')} UTC\n")
    w("Generated by `mise run mac:inventory` (setup/inventory/mac_inventory.py). Read-only: nothing was installed or removed.\n")

    # ---- GUI apps -----------------------------------------------------------
    buckets = classify_apps(snap["apps"], stale_days)
    by_source: Dict[str, int] = {}
    for a in snap["apps"]:
        by_source[a["source"]] = by_source.get(a["source"], 0) + 1
    w("## Summary\n")
    w(md_table(["", "Count"], [
        ["Apps (non-Apple)", len(snap["apps"]) - len(buckets["apple"])],
        ["… installed by Homebrew cask", by_source.get("cask", 0)],
        ["… from the Mac App Store", by_source.get("mas", 0)],
        ["… installed manually (no package manager)", by_source.get("manual", 0)],
        [f"Apps not used in {stale_days}+ days (removal candidates)", len(buckets["stale"])],
        ["Homebrew formulae you installed (leaves)", len(brew.get("leaves", []))],
        ["Homebrew casks", len(brew.get("casks", []))],
        ["mise tools active", sum(1 for t in mise.get("tools", []) if t["active"])],
        ["mise tool versions nothing uses (`mise prune`)", len(mise.get("prunable", []))],
    ]))

    w(f"## Removal candidates: apps not used in {stale_days}+ days\n")
    w("*Last opened* is Spotlight's launch record (`kMDItemLastUsedDate`). Some apps are never "
      "recorded (menu-bar agents, apps started by other apps or by JetBrains Toolbox), so "
      "*Data touched* adds the newest change to the app's preferences/containers: a hint of use, "
      "not proof.\n")
    rows = sorted(buckets["stale"], key=lambda a: max(a["last_used"] or "", a["activity"] or ""))
    w(md_table(["App", "Installed via", "Last opened", "Data touched", "Size MB"],
               [[a["name"], app_install_ref(a), f"{fmt_date(a['last_used'])} ({fmt_age(a['last_used'])})",
                 fmt_date(a["activity"]), a["size_mb"]] for a in rows]))

    intel = [a for a in snap["apps"] if a.get("arch") == "intel-only"]
    if intel:
        w("## Intel-only apps (run under Rosetta)\n")
        w(md_table(["App", "Installed via"], [[a["name"], app_install_ref(a)] for a in intel]))

    w(f"## Apps in use (opened within {stale_days} days, or a login item)\n")
    rows = sorted(buckets["active"], key=lambda a: a["name"].lower())
    w(md_table(["App", "Installed via", "Why"],
               [[a["name"], app_install_ref(a), a["evidence"]] for a in rows]))

    # ---- CLI tools ------------------------------------------------------------
    mise_bins: Dict[str, str] = {}
    for t in mise.get("tools", []):
        if t["active"]:
            for b in t["bins"]:
                mise_bins.setdefault(b, t["name"])
    leaves = set(brew.get("leaves", []))
    formulae = {f["name"]: f for f in brew.get("formulae", [])}
    leaf_formulae = [f for f in brew.get("formulae", []) if f["name"] in leaves or f["full_name"] in leaves]

    w("## Homebrew formulae duplicated by a mise tool\n")
    w("Both Homebrew and mise put these commands on PATH. mise wins when it is activated, so the "
      "Homebrew copy is usually dead weight — but check nothing launched outside your shell "
      "(GUI apps, launchd jobs) relies on the `/opt/homebrew/bin` copy first.\n")
    dup_rows = []
    for f in leaf_formulae:
        shared = sorted(set(f["bins"]) & set(mise_bins))
        if shared:
            dup_rows.append([f"`{f['full_name']}`", ", ".join(sorted({mise_bins[b] for b in shared})),
                             ", ".join(shared[:4]) + (" …" if len(shared) > 4 else "")])
    w(md_table(["Homebrew formula", "mise tool", "Shared commands"], dup_rows))

    present_casks = {a["cask"] for a in snap["apps"] if a.get("cask")}
    ghost = [c for c in brew.get("casks", []) if c["apps"] and c["token"] not in present_casks]
    w("## Ghost casks: Homebrew still lists them, but the app is gone\n")
    w("The app was deleted by hand, so Homebrew's record is stale (and a declared one would be "
      "reinstalled on the next `mise bootstrap`).\n")
    w(md_table(["Cask", "Expected app"], [[f"`{c['full_token']}`", ", ".join(c["apps"])] for c in ghost]))

    w("## Cleanup commands (review before running)\n")
    w("Only the mechanical cases: Homebrew copies of tools mise already provides, stale cask "
      "records, and old mise tool versions. Everything else above is a judgement call.\n")
    cmds = []
    dup_formulae = [f["full_name"] for f in leaf_formulae if set(f["bins"]) & set(mise_bins)]
    if dup_formulae:
        cmds.append("brew uninstall " + " ".join(sorted(dup_formulae)))
    if ghost:
        cmds.append("brew uninstall --cask " + " ".join(sorted(c["token"] for c in ghost)))
    if mise.get("prunable"):
        cmds.append("mise prune")
    w("```sh\n" + ("\n".join(cmds) or "# nothing to clean up") + "\n```\n")

    history_note = (f"Usage counts come from shell history (zsh with timestamps; PowerShell without — "
                    f"*recent pwsh* counts its last 3,000 commands, history file last written "
                    f"{fmt_date(snap.get('shell_usage', {}).get('pwsh_history_mtime'))}). A tool used "
                    "only by scripts or other tools will look unused. Tools your shell init files reference "
                    "(starship, zoxide, direnv, zsh plugins …) are left out.\n")

    w("## Homebrew formulae never seen in shell history\n")
    w(history_note)
    rows = []
    for f in sorted(leaf_formulae, key=lambda f: f["name"]):
        names = set(f["bins"]) or {f["name"]}
        total, recent, last = cli_last_use(usage, names)
        if total == 0 and not (names | {f["name"]}) & shell_init:
            rows.append([f"`{f['full_name']}`", (f.get("desc") or "")[:70], ", ".join(sorted(names)[:3])])
    w(md_table(["Formula", "Description", "Commands"], rows))

    w("## mise tools never seen in shell history\n")
    rows = []
    for t in sorted((t for t in mise.get("tools", []) if t["active"]), key=lambda t: t["name"]):
        names = set(t["bins"]) or {tool_short_name(t["name"])}
        total, _, _ = cli_last_use(usage, names)
        if total == 0 and not (names | {tool_short_name(t["name"])}) & shell_init:
            rows.append([f"`{t['name']}`", t["version"], (t.get("source") or "").replace(str(HOME), "~")])
    w(md_table(["Tool", "Version", "Declared in"], rows))

    w("## CLI usage (Homebrew leaves + mise tools)\n")
    rows = []
    seen: Set[str] = set()
    for label, names in [(f"brew `{f['name']}`", set(f["bins"]) or {f["name"]}) for f in leaf_formulae] + \
                        [(f"mise `{t['name']}`", set(t["bins"]) or {tool_short_name(t['name'])})
                         for t in mise.get("tools", []) if t["active"]]:
        total, recent, last = cli_last_use(usage, names)
        if total and label not in seen:
            seen.add(label)
            rows.append([label, total, recent, fmt_date(last)])
    rows.sort(key=lambda r: (r[3] if r[3] != "—" else "", r[1]))
    w(md_table(["Tool", "History hits", "Recent pwsh hits", "Last zsh use"], rows))

    # ---- drift ------------------------------------------------------------------
    if declared is not None:
        w("## Drift: installed but not declared in dotfiles\n")
        w("Not reproduced on a new machine. Either declare it (`mise bootstrap packages use -g …` / "
          "`mise use -g …`) or remove it.\n")
        declared_cli = declared["tools"] | {TOOL_ALIASES.get(t, t) for t in declared["tools"]} | declared["brew"]
        declared_cli |= {"mise"}  # installed by setup/setup-macos.sh before mise exists
        undeclared_formulae = [f for f in leaf_formulae
                               if f["name"] not in declared_cli and f["full_name"].split("/")[-1] not in declared_cli]
        w("### Homebrew formulae\n")
        w(md_table(["Formula", "Also a mise tool?", "Description"],
                   [[f"`{f['full_name']}`", "yes — drop the brew copy" if set(f["bins"]) & set(mise_bins) else "",
                     (f.get("desc") or "")[:70]] for f in sorted(undeclared_formulae, key=lambda f: f["name"])]))
        w("### Casks\n")
        w(md_table(["Cask", "Apps"],
                   [[f"`{c['full_token']}`", ", ".join(c["apps"]) or "—"]
                    for c in sorted(brew.get("casks", []), key=lambda c: c["token"])
                    if c["token"] not in declared["brew-cask"]]))
        w("### Mac App Store\n")
        w(md_table(["App", "ID"], [[m["name"], f"`mas:{m['id']}`"] for m in snap.get("mas", [])
                                  if m["id"] not in declared["mas"]]))
        w("### Apps installed manually (no package manager)\n")
        w("Check `brew search --cask <name>`; many of these have a cask, which makes them reproducible.\n")
        w(md_table(["App", "Bundle ID", "Last used"],
                   [[a["name"], a["bundle_id"] or "—", fmt_date(a["last_used"])]
                    for a in sorted(snap["apps"], key=lambda a: a["name"].lower()) if a["source"] == "manual"]))

        w("## Drift: declared in dotfiles but not installed\n")
        installed_casks = {c["token"] for c in brew.get("casks", [])}
        installed_mas = {m["id"] for m in snap.get("mas", [])}
        rows = [[f"`brew-cask:{c}`"] for c in sorted(declared["brew-cask"] - installed_casks)]
        rows += [[f"`mas:{m}`"] for m in sorted(declared["mas"] - installed_mas)]
        rows += [[f"`brew:{b}`"] for b in sorted(declared["brew"] - set(formulae))]
        w(md_table(["Package"], rows))

    # ---- other managers -----------------------------------------------------------
    other = snap.get("other", {})
    w("## Other package managers\n")
    w("Tools installed outside Homebrew/mise don't follow you to the other Mac. mise has backends for "
      "most of them (`npm:`, `pipx:`, `dotnet:`, `cargo:`, `go:`), so they can move into `[tools]`.\n")
    rows = []
    for key, label, hint in [
        ("npm_global", "npm -g", "`npm:<pkg>` in mise [tools]"),
        ("volta", "Volta", "mise already manages node; move packages to `npm:<pkg>`"),
        ("uv_tools", "uv tool", "`pipx:<pkg>` (mise uses uv for it)"),
        ("pipx", "pipx", "`pipx:<pkg>`"),
        ("dotnet_tools", "dotnet tool -g", "`dotnet:<pkg>`"),
        ("go_bin", "~/go/bin", "`go:<module>`"),
        ("cargo_bin", "~/.cargo/bin", "`cargo:<crate>` (rustup proxies are expected)"),
        ("krew", "kubectl krew", "keep krew, or `aqua:`/`github:` per plugin"),
        ("gh_extensions", "gh extensions", "installed by .config/mise/scripts/gh-extensions.ps1"),
        ("vscode_extensions", "VS Code extensions", "VS Code Settings Sync"),
        ("vscode_insiders_extensions", "VS Code Insiders extensions", "VS Code Settings Sync"),
    ]:
        items = other.get(key) or []
        if items:
            shown = ", ".join(items[:12]) + (f" … (+{len(items) - 12})" if len(items) > 12 else "")
            rows.append([label, len(items), shown, hint])
    if other.get("conda"):
        rows.append(["conda", "—", "miniconda/anaconda directory present", "uv/mise python replace this"])
    w(md_table(["Manager", "Count", "Packages", "mise route"], rows))

    w("## Startup items\n")
    st = snap.get("startup", {})
    w("**Login items:** " + (", ".join(st.get("login_items", [])) or "none") + "\n")
    w("**~/Library/LaunchAgents:** " + (", ".join(st.get("launch_agents", [])) or "none") + "\n")

    if mise.get("prunable"):
        w("## mise housekeeping\n")
        w(f"`mise prune` would remove {len(mise['prunable'])} unused tool versions.\n")

    text = "\n".join(out)
    if args.out and args.out != "-":
        Path(args.out).expanduser().write_text(text)
        log(f"wrote {args.out}")
    else:
        sys.stdout.write(text)
    return 0


# --------------------------------------------------------------------------
# diff
# --------------------------------------------------------------------------

def cmd_diff(args: argparse.Namespace) -> int:
    a = json.loads(Path(args.a).expanduser().read_text())
    b = json.loads(Path(args.b).expanduser().read_text())
    an, bn = a["host"]["computer_name"], b["host"]["computer_name"]
    declared = load_declared(Path(args.dotfiles).expanduser()) if args.dotfiles else None

    def app_key(app: Dict[str, Any]) -> str:
        return app.get("bundle_id") or app["name"]

    def app_map(s: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
        return {app_key(x): x for x in s["apps"] if x["source"] != "apple"}

    out: List[str] = []
    w = out.append
    w(f"# Mac inventory diff — {an} vs {bn}\n")
    w(md_table(["", an, bn], [
        ["Model", a["host"]["model"], b["host"]["model"]],
        ["Chip", a["host"]["chip"], b["host"]["chip"]],
        ["macOS", a["host"]["macos"], b["host"]["macos"]],
        ["Collected", a["host"]["collected_at"][:10], b["host"]["collected_at"][:10]],
    ]))

    am, bm = app_map(a), app_map(b)

    def declared_note(app: Dict[str, Any]) -> str:
        if declared is None:
            return ""
        if app.get("cask") and app["cask"] in declared["brew-cask"]:
            return "declared"
        if app.get("mas_id") and app["mas_id"] in declared["mas"]:
            return "declared"
        return ""

    for title, left, right, host in [(f"Apps only on {an}", am, bm, an), (f"Apps only on {bn}", bm, am, bn)]:
        w(f"## {title}\n")
        rows = [[x["name"], app_install_ref(x), f"{fmt_date(x['last_used'])} ({fmt_age(x['last_used'])})", declared_note(x)]
                for k, x in sorted(left.items(), key=lambda kv: kv[1]["name"].lower()) if k not in right]
        w(md_table(["App", "Installed via", f"Last used on {host}", "In dotfiles"], rows))

    w("## Apps on both, version differs\n")
    rows = [[am[k]["name"], am[k]["version"], bm[k]["version"]]
            for k in sorted(set(am) & set(bm), key=lambda k: am[k]["name"].lower())
            if am[k]["version"] != bm[k]["version"]]
    w(md_table(["App", an, bn], rows))

    def set_section(title: str, sa: Set[str], sb: Set[str]) -> None:
        w(f"## {title}\n")
        rows = [[x, "✓" if x in sa else "", "✓" if x in sb else ""] for x in sorted(sa ^ sb)]
        w(md_table(["", an, bn], rows) if rows else "_Identical._\n")

    set_section("Homebrew formulae you installed (leaves)", set(a["brew"].get("leaves", [])), set(b["brew"].get("leaves", [])))
    set_section("Homebrew casks", {c["full_token"] for c in a["brew"].get("casks", [])},
                {c["full_token"] for c in b["brew"].get("casks", [])})
    set_section("Homebrew taps", set(a["brew"].get("taps", [])), set(b["brew"].get("taps", [])))
    set_section("Mac App Store", {f"{m['name']} ({m['id']})" for m in a.get("mas", [])},
                {f"{m['name']} ({m['id']})" for m in b.get("mas", [])})

    def mise_active(s: Dict[str, Any]) -> Dict[str, str]:
        return {t["name"]: t["version"] for t in s.get("mise", {}).get("tools", []) if t["active"]}

    ma, mb = mise_active(a), mise_active(b)
    w("## mise tools (active versions)\n")
    rows = [[t, ma.get(t, "—"), mb.get(t, "—")] for t in sorted(set(ma) | set(mb)) if ma.get(t) != mb.get(t)]
    w(md_table(["Tool", an, bn], rows) if rows else "_Identical._\n")

    for key, label in [("npm_global", "npm -g"), ("dotnet_tools", "dotnet tools"), ("gh_extensions", "gh extensions"),
                       ("vscode_extensions", "VS Code extensions"), ("volta", "Volta")]:
        set_section(label, set(a.get("other", {}).get(key) or []), set(b.get("other", {}).get(key) or []))

    text = "\n".join(out)
    if args.out and args.out != "-":
        Path(args.out).expanduser().write_text(text)
        log(f"wrote {args.out}")
    else:
        sys.stdout.write(text)
    return 0


# --------------------------------------------------------------------------

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("collect", help="snapshot this Mac to JSON")
    p.add_argument("--out", "-o", default="-", help="output file (default: stdout)")
    p.set_defaults(func=cmd_collect)

    p = sub.add_parser("report", help="Markdown report for one snapshot")
    p.add_argument("snapshot")
    p.add_argument("--out", "-o", default="-")
    p.add_argument("--dotfiles", default=str(HOME / "dotfiles"), help="dotfiles checkout for drift checks ('' to skip)")
    p.add_argument("--stale-days", type=int, default=DEFAULT_STALE_DAYS)
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("diff", help="compare two snapshots")
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--out", "-o", default="-")
    p.add_argument("--dotfiles", default=str(HOME / "dotfiles"))
    p.set_defaults(func=cmd_diff)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
