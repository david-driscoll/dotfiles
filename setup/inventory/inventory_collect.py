#!/usr/bin/env python3
"""Collect a read-only JSON snapshot of this Mac's apps and tools."""

# Covers apps (with Spotlight last-used dates), Homebrew, the Mac App Store,
# mise, other global package managers, startup items and shell-history usage.
#
# Self-contained on purpose: it needs only the system python3 (3.9, from the
# Command Line Tools), so it also runs on a Mac that has not been bootstrapped,
# streamed over SSH:  ssh other-mac python3 - < inventory_collect.py
#
# Nothing here installs, removes or changes anything.


from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import plistlib
import re
import shutil
# Only run_command() uses subprocess, with fixed, read-only commands.
import subprocess  # nosec B404
import sys
import time
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

SCHEMA_VERSION = 1
HOME = Path.home()
NOW = dt.datetime.now(dt.timezone.utc)
RECENT_PWSH_LINES = 3000
SPOTLIGHT_ATTRS = ("kMDItemLastUsedDate", "kMDItemUseCount", "kMDItemCFBundleIdentifier",
                   "kMDItemVersion", "kMDItemPhysicalSize", "kMDItemAppStoreHasReceipt")
# Words that start a shell segment but are not the command being run.
COMMAND_PREFIXES = {"sudo", "time", "nohup", "env", "exec", "command", "builtin", "noglob",
                    "watch", "xargs", "nice", "caffeinate", "&", "!"}
# Commands whose first argument is worth counting too ("gh dash", "brew bundle").
SUBCOMMAND_TOOLS = {"gh", "kubectl", "brew", "dotnet"}
APPLE_BUNDLE_PREFIX = "com.apple."
BREW_LOCATIONS = ("/opt/homebrew/bin/brew", "/usr/local/bin/brew")

Json = Dict[str, Any]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def log(msg: str) -> None:
    """Print a progress message to stderr (stdout may carry the snapshot)."""
    print(f"[mac-inventory] {msg}", file=sys.stderr)


def resolve_executable(name: str) -> Optional[str]:
    """Return an absolute path for a command name, or None if absent."""
    if os.path.isabs(name):
        return name if os.access(name, os.X_OK) else None
    return shutil.which(name)


def run_command(cmd: List[str], timeout: int = 120) -> Tuple[int, str, str]:
    """
    Run one read-only inventory command; never raises.

    Every caller passes a fixed argument list built in this file. There is no
    shell and no user input, and the executable is resolved to an absolute
    path first. Returns (exit code, stdout, stderr); 127 when not installed.
    """
    exe = resolve_executable(cmd[0])
    if exe is None:
        return 127, "", ""
    env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE="1", MISE_QUIET="1")
    try:
        # Fixed argv from this file, absolute executable path, no shell.
        # nosemgrep
        proc = subprocess.run(  # nosec B603
            [exe, *cmd[1:]], capture_output=True, text=True, timeout=timeout, env=env, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return 1, "", ""
    return proc.returncode, proc.stdout, proc.stderr


def run_out(cmd: List[str], timeout: int = 120) -> Optional[str]:
    """Return a command's stdout when it succeeds, else None."""
    code, out, _ = run_command(cmd, timeout)
    return out if code == 0 else None


def run_json(cmd: List[str], timeout: int = 120) -> Any:
    """Return a command's stdout parsed as JSON, or None."""
    out = run_out(cmd, timeout)
    if not out or not out.strip():
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def iso(ts: Optional[float]) -> Optional[str]:
    """Format a POSIX timestamp as UTC ISO-8601, passing None through."""
    if ts is None:
        return None
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).isoformat(timespec="seconds")


def mtime(path: Path) -> Optional[float]:
    """Return a path's modification time, or None if it does not exist."""
    try:
        return path.stat().st_mtime
    except OSError:
        return None


def list_names(directory: Path) -> List[str]:
    """Sorted entry names of a directory; empty when it does not exist."""
    return sorted(p.name for p in directory.iterdir()) if directory.is_dir() else []


def norm(value: str) -> str:
    """Lower-case a name and drop everything but letters and digits."""
    return re.sub(r"[^a-z0-9]", "", value.lower())


def lines_of(out: Optional[str]) -> List[str]:
    """Non-empty, stripped lines of a command's output."""
    return [line.strip() for line in (out or "").splitlines() if line.strip()]


# --------------------------------------------------------------------------
# host
# --------------------------------------------------------------------------

def collect_host() -> Json:
    """Machine identity: names, model, chip, macOS version, setup date."""
    setup_done = (run_out(["stat", "-f", "%B", "/private/var/db/.AppleSetupDone"]) or "").strip()
    return {
        "computer_name": (run_out(["scutil", "--get", "ComputerName"]) or "").strip(),
        "local_host_name": (run_out(["scutil", "--get", "LocalHostName"]) or "").strip(),
        "model": (run_out(["sysctl", "-n", "hw.model"]) or "").strip(),
        "chip": (run_out(["sysctl", "-n", "machdep.cpu.brand_string"]) or "").strip(),
        "arch": platform.machine(),
        "macos": platform.mac_ver()[0],
        "setup_date": iso(float(setup_done)) if setup_done.isdigit() else None,
        "collected_at": NOW.isoformat(timespec="seconds"),
    }


# --------------------------------------------------------------------------
# Homebrew
# --------------------------------------------------------------------------

def brew_executable() -> Optional[str]:
    """Locate brew on PATH or at its default install locations."""
    found = shutil.which("brew")
    if found:
        return found
    return next((p for p in BREW_LOCATIONS if os.path.exists(p)), None)


def formula_entry(formula: Json, prefix: str) -> Json:
    """Summarize one installed formula, including the commands it links."""
    installed = (formula.get("installed") or [{}])[-1]
    return {
        "name": formula["name"],
        "full_name": formula.get("full_name", formula["name"]),
        "tap": formula.get("tap"),
        "version": installed.get("version"),
        "on_request": bool(installed.get("installed_on_request")),
        "desc": formula.get("desc"),
        "bins": list_names(Path(prefix) / "opt" / formula["name"] / "bin"),
    }


def artifact_app_names(artifact: Json) -> List[str]:
    """App bundle names an `app` artifact installs."""
    names = []
    for app in artifact.get("app", []):
        if isinstance(app, str):
            names.append(app)
        elif isinstance(app, dict) and app.get("target"):
            names.append(Path(app["target"]).name)
    return names


def artifact_binary_names(artifact: Json) -> List[str]:
    """Command names a `binary` artifact links."""
    return [Path(b).name for b in artifact.get("binary", []) if isinstance(b, str)]


def artifact_quit_ids(artifact: Json) -> List[str]:
    """
    Bundle IDs an uninstall/zap stanza quits.

    pkg-installed casks have no `app` artifact; the IDs their uninstall
    stanza quits are how the app on disk is matched back to the cask.
    """
    ids: List[str] = []
    for stanza in artifact.get("uninstall", []) + artifact.get("zap", []):
        quit_ids = stanza.get("quit", []) if isinstance(stanza, dict) else []
        ids += [quit_ids] if isinstance(quit_ids, str) else quit_ids
    return ids


def cask_entry(cask: Json) -> Json:
    """Summarize one installed cask: apps, commands and bundle IDs."""
    apps: List[str] = []
    bins: List[str] = []
    bundle_ids: List[str] = []
    for artifact in cask.get("artifacts", []):
        if isinstance(artifact, dict):
            apps += artifact_app_names(artifact)
            bins += artifact_binary_names(artifact)
            bundle_ids += artifact_quit_ids(artifact)
    return {
        "token": cask["token"],
        "full_token": cask.get("full_token", cask["token"]),
        "tap": cask.get("tap"),
        "version": cask.get("installed"),
        "auto_updates": bool(cask.get("auto_updates")),
        "desc": cask.get("desc"),
        "apps": apps,
        "bins": bins,
        "bundle_ids": sorted(set(bundle_ids)),
    }


def collect_brew() -> Json:
    """Installed formulae, casks, leaves and taps."""
    brew = brew_executable()
    if not brew:
        return {"available": False}
    info = run_json([brew, "info", "--json=v2", "--installed"], timeout=300) or {}
    prefix = (run_out([brew, "--prefix"]) or "").strip()
    return {
        "available": True,
        "prefix": prefix,
        "leaves": (run_out([brew, "leaves", "--installed-on-request"]) or "").split(),
        "taps": (run_out([brew, "tap"]) or "").split(),
        "formulae": [formula_entry(f, prefix) for f in info.get("formulae", [])],
        "casks": [cask_entry(c) for c in info.get("casks", [])],
    }


# --------------------------------------------------------------------------
# Mac App Store, mise, other package managers
# --------------------------------------------------------------------------

def collect_mas() -> List[Json]:
    """Mac App Store apps as listed by `mas list`."""
    apps = []
    for line in (run_out(["mas", "list"]) or "").splitlines():
        match = re.match(r"\s*(\d+)\s+(.+?)\s+\(([^)]*)\)\s*$", line)
        if match:
            apps.append({"id": match.group(1), "name": match.group(2).strip(), "version": match.group(3)})
    return apps


def mise_tool_bins(install_path: str, bin_dirs: List[Path]) -> List[str]:
    """Executables mise puts on PATH for one install directory."""
    names: Set[str] = set()
    for directory in bin_dirs:
        if str(directory).startswith(install_path) and directory.is_dir():
            names |= {f.name for f in directory.iterdir() if f.is_file() and os.access(f, os.X_OK)}
    return sorted(names)


def mise_prunable() -> List[str]:
    """Tool versions `mise prune` would remove (it reports on stderr)."""
    _, out, err = run_command(["mise", "prune", "--dry-run", "--yes"])
    return [line for line in lines_of(out + err) if "[dryrun]" in line and "configuration links" not in line]


def collect_mise() -> Json:
    """Every tool version mise knows about, with active ones' commands."""
    data = run_json(["mise", "ls", "--json"])
    if data is None:
        return {"available": False}
    # Aqua tools keep binaries in the install root or a nested folder, so ask
    # mise for the real bin dirs instead of assuming <install>/bin.
    bin_dirs = [Path(p) for p in lines_of(run_out(["mise", "bin-paths"]))]
    tools = []
    for name, versions in data.items():
        for version in versions:
            active = bool(version.get("active"))
            tools.append({
                "name": name,
                "version": version.get("version"),
                "installed": bool(version.get("installed")),
                "active": active,
                "source": (version.get("source") or {}).get("path"),
                "bins": mise_tool_bins(version.get("install_path", ""), bin_dirs) if active else [],
            })
    return {
        "available": True,
        "version": (run_out(["mise", "--version"]) or "").strip(),
        "tools": tools,
        "prunable": mise_prunable(),
    }


def parse_npm(out: str) -> List[str]:
    """Global npm packages, minus the two that ship with node."""
    try:
        deps = json.loads(out).get("dependencies", {})
    except (json.JSONDecodeError, AttributeError):
        return []
    return sorted(set(deps) - {"npm", "corepack"})


def parse_uv(out: str) -> List[str]:
    """Tool names from `uv tool list` (skips the indented command lines)."""
    return [line.split()[0] for line in out.splitlines() if line and not line.startswith(("-", " "))]


def parse_first_words(out: str) -> List[str]:
    """First word of each non-empty line."""
    return [line.split()[0] for line in lines_of(out)]


def parse_table_body(out: str) -> List[str]:
    """First column of a table with a two-line header (`dotnet tool list`)."""
    return [line.split()[0] for line in out.splitlines()[2:] if line.strip()]


def parse_gh_extensions(out: str) -> List[str]:
    """Repository column of `gh extension list`."""
    return [line.split("\t")[1] for line in out.splitlines() if "\t" in line]


def parse_words(out: str) -> List[str]:
    """Whitespace-separated words."""
    return out.split()


OTHER_MANAGERS = (
    ("npm_global", ["npm", "ls", "-g", "--depth=0", "--json"], parse_npm),
    ("uv_tools", ["uv", "tool", "list"], parse_uv),
    ("pipx", ["pipx", "list", "--short"], parse_first_words),
    ("dotnet_tools", ["dotnet", "tool", "list", "-g"], parse_table_body),
    ("gh_extensions", ["gh", "extension", "list"], parse_gh_extensions),
    ("vscode_extensions", ["code", "--list-extensions"], parse_words),
    ("vscode_insiders_extensions", ["code-insiders", "--list-extensions"], parse_words),
    ("volta", ["volta", "list", "all", "--format=plain"], lines_of),
    ("krew", ["kubectl", "krew", "list"], parse_words),
)


def collect_other_managers() -> Json:
    """Global packages installed outside Homebrew and mise."""
    result: Json = {}
    for key, cmd, parse in OTHER_MANAGERS:
        out = run_out(cmd)
        result[key] = parse(out) if out is not None else []
    result["cargo_bin"] = list_names(HOME / ".cargo" / "bin")
    result["go_bin"] = list_names(HOME / "go" / "bin")
    result["conda"] = any((HOME / d).exists() for d in ("miniconda3", "anaconda3", ".conda"))
    return result


def login_item_names() -> List[str]:
    """
    Login item names from System Events.

    System Events occasionally fails to answer while it starts up, and an
    empty list would make every login item look unused, so retry once.
    """
    script = 'tell application "System Events" to get the name of every login item'
    out = None
    for _ in range(2):
        out = run_out(["osascript", "-e", script], timeout=20)
        if out is not None:
            break
        time.sleep(2)
    return [s.strip() for s in (out or "").split(",") if s.strip()]


def collect_login_items() -> Json:
    """Login items (System Events) and per-user LaunchAgents."""
    agents_dir = HOME / "Library" / "LaunchAgents"
    return {
        "login_items": login_item_names(),
        "launch_agents": sorted(p.name for p in agents_dir.glob("*.plist")) if agents_dir.is_dir() else [],
    }


# --------------------------------------------------------------------------
# shell history
# --------------------------------------------------------------------------

def strip_prefixes(words: List[str]) -> List[str]:
    """Drop leading `sudo`-style wrappers and VAR=value assignments."""
    while words and (words[0] in COMMAND_PREFIXES or "=" in words[0]):
        words = words[1:]
    return words


def unwrap_mise_exec(words: List[str]) -> List[str]:
    """Turn `mise x tool -- cmd …` into `cmd …`."""
    if len(words) > 2 and words[0] in ("mise", "mise.exe") and words[1] in ("x", "exec"):
        return words[words.index("--") + 1:] if "--" in words else words[2:]
    return words


def split_segments(line: str) -> Iterable[str]:
    """Yield the command names a shell line runs (and `tool sub` pairs)."""
    for segment in re.split(r"\|\|?|&&|;|\$\(|`|\(", line):
        words = unwrap_mise_exec(strip_prefixes(segment.strip().split()))
        if not words:
            continue
        yield words[0].split("/")[-1]
        if len(words) > 1 and words[0] in SUBCOMMAND_TOOLS:
            yield f"{words[0]} {words[1]}"


class UsageCounter:
    """Per-command history hit counts, plus the latest zsh timestamp."""

    def __init__(self) -> None:
        """Start with no commands counted."""
        self.commands: Dict[str, Json] = {}

    def bump(self, line: str, field: str, ts: Optional[float] = None) -> None:
        """Count every command a history line runs under one shell field."""
        for cmd in set(split_segments(line)):
            entry = self.commands.setdefault(cmd, {"zsh": 0, "pwsh": 0, "pwsh_recent": 0, "bash": 0, "last": None})
            entry[field] += 1
            if ts is not None and (entry["last"] is None or ts > entry["last"]):
                entry["last"] = ts

    def finish(self) -> Dict[str, Json]:
        """Return the counts with timestamps rendered as ISO strings."""
        for entry in self.commands.values():
            entry["last"] = iso(entry["last"])
        return self.commands


def read_zsh(counter: UsageCounter, path: Path) -> None:
    """Count zsh EXTENDED_HISTORY lines (`: <ts>:<dur>;<cmd>`)."""
    for line in path.read_bytes().decode("utf-8", errors="replace").splitlines():
        match = re.match(r"^: (\d+):\d+;(.*)$", line)
        if match:
            counter.bump(match.group(2), "zsh", float(match.group(1)))
        else:
            counter.bump(line, "zsh")


def read_pwsh(counter: UsageCounter, path: Path) -> None:
    """
    Count PSReadLine history.

    It has no timestamps, so the last RECENT_PWSH_LINES lines also count
    as a rough recency signal.
    """
    lines = path.read_text(errors="replace").splitlines()
    recent_from = max(0, len(lines) - RECENT_PWSH_LINES)
    for index, line in enumerate(lines):
        counter.bump(line, "pwsh")
        if index >= recent_from:
            counter.bump(line, "pwsh_recent")


def read_bash(counter: UsageCounter, path: Path) -> None:
    """Count plain bash history lines."""
    for line in path.read_text(errors="replace").splitlines():
        counter.bump(line, "bash")


def shell_init_words(dotfiles: Path) -> List[str]:
    """
    Every word in the shell init files.

    Tools these files run (starship, zoxide, direnv, zsh plugins) are used
    on every shell start without ever being typed.
    """
    files = [HOME / ".zshrc", HOME / ".zprofile", HOME / ".bashrc", HOME / ".bash_aliases"]
    for pattern in ("profile*.ps1", "profile.pwsh/*.ps1", "powershell/*.ps1"):
        files += list(dotfiles.glob(pattern))
    words: Set[str] = set()
    for file in files:
        try:
            words |= set(re.findall(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", file.read_text(errors="replace")))
        except OSError:
            continue
    return sorted(words)


def collect_shell_usage() -> Json:
    """How often each command appears in zsh, PowerShell and bash history."""
    zsh = HOME / ".zsh_history"
    pwsh = HOME / ".local/share/powershell/PSReadLine/ConsoleHost_history.txt"
    bash = HOME / ".bash_history"
    counter = UsageCounter()
    for path, reader in ((zsh, read_zsh), (pwsh, read_pwsh), (bash, read_bash)):
        if path.is_file():
            reader(counter, path)
    return {
        "shell_init_words": shell_init_words(HOME / "dotfiles"),
        "sources": {"zsh": zsh.is_file(), "pwsh": pwsh.is_file(), "bash": bash.is_file()},
        "pwsh_history_mtime": iso(mtime(pwsh)),
        "commands": counter.finish(),
    }


# --------------------------------------------------------------------------
# apps
# --------------------------------------------------------------------------

def app_bundles_in(root: Path) -> Iterable[Path]:
    """
    Yield .app bundles in root and one level of grouping folders.

    Covers e.g. /Applications/Utilities and ~/Applications/CrossOver. Hidden
    staging folders and browser web-app shims ("Chrome Apps.localized") are
    skipped.
    """
    for entry in sorted(root.iterdir()):
        if entry.suffix == ".app":
            yield entry
        elif entry.is_dir() and not entry.name.startswith(".") and not entry.name.endswith(" Apps.localized"):
            yield from (child for child in sorted(entry.iterdir()) if child.suffix == ".app")


def find_apps() -> List[Path]:
    """Apps in /Applications and ~/Applications, deduplicated by real path."""
    apps: List[Path] = []
    seen: Set[str] = set()
    for root in (Path("/Applications"), HOME / "Applications"):
        if not root.is_dir():
            continue
        for app in app_bundles_in(root):
            key = str(app.resolve())
            if key not in seen:
                seen.add(key)
                apps.append(app)
    return apps


def spotlight_attrs(app: Path) -> Json:
    """Launch metadata from Spotlight, read as a plist (no date parsing)."""
    cmd = ["mdls", "-plist", "-"]
    for name in SPOTLIGHT_ATTRS:
        cmd += ["-name", name]
    out = run_out(cmd + [str(app)], timeout=30)
    if not out:
        return {}
    try:
        return plistlib.loads(out.encode())
    except (plistlib.InvalidFileException, ValueError):
        return {}


def info_plist(app: Path) -> Json:
    """The app bundle's Info.plist, or {} if unreadable."""
    try:
        with open(app / "Contents" / "Info.plist", "rb") as handle:
            return plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException, ValueError):
        return {}


def activity_time(bundle_id: Optional[str], name: str) -> Optional[float]:
    """
    Latest mtime among an app's preference and data locations.

    A fallback when Spotlight has no launch record. Background and menu-bar
    apps touch these without being "used", so the report labels it apart.
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


def intel_only(path: Path, plist: Json) -> bool:
    """True when the app's main executable has no arm64 slice."""
    exe = plist.get("CFBundleExecutable")
    if not exe:
        return False
    out = run_out(["lipo", "-archs", str(path / "Contents" / "MacOS" / exe)], timeout=10)
    return out is not None and "arm64" not in out and "x86_64" in out


class AppIndex:
    """Lookups that tie an app on disk to its cask, App Store ID, login item."""

    def __init__(self, brew: Json, mas: List[Json], login: Json) -> None:
        """Build the cask, App Store and login-item lookups."""
        self.by_app: Dict[str, str] = {}
        self.by_bundle: Dict[str, str] = {}
        self.by_norm: Dict[str, str] = {}
        for cask in brew.get("casks", []):
            self._add_cask(cask)
        names = [m["name"].lower() for m in mas]
        # Two App Store apps can share a name ("Copilot"); don't guess an ID then.
        self.mas_by_name = {m["name"].lower(): m["id"] for m in mas if names.count(m["name"].lower()) == 1}
        self.login_items = {s.lower() for s in login.get("login_items", [])}

    def _add_cask(self, cask: Json) -> None:
        for app in cask["apps"]:
            self.by_app[app] = cask["token"]
        for bundle_id in cask.get("bundle_ids", []):
            self.by_bundle.setdefault(bundle_id, cask["token"])
        self.by_norm.setdefault(norm(re.sub(r"-app$", "", cask["token"])), cask["token"])

    def cask_for(self, path: Path, bundle_id: Optional[str]) -> Optional[str]:
        """Cask token for an app: by bundle name, quit ID, then fuzzy name."""
        return (self.by_app.get(path.name) or self.by_bundle.get(bundle_id or "")
                or self.by_norm.get(norm(path.stem)))

    def mas_id_for(self, name: str, has_receipt: bool) -> Optional[str]:
        """App Store ID by name; with a receipt, also by first word."""
        found = self.mas_by_name.get(name.lower())
        if found is not None or not has_receipt:
            return found
        # Store names sometimes differ ("Keynote" vs "Keynote Creator Studio").
        first = name.lower().split()[0]
        return next((i for n, i in self.mas_by_name.items() if n.split()[0] == first), None)


def is_apple_app(path: Path, bundle_id: str, has_receipt: bool) -> bool:
    """Apps that ship with macOS (App Store apps by Apple don't count)."""
    if str(path.resolve()).startswith("/System/"):
        return True
    return bundle_id.startswith(APPLE_BUNDLE_PREFIX) and not has_receipt


def app_source(path: Path, bundle_id: Optional[str], cask: Optional[str], has_receipt: bool) -> str:
    """Classify how an app was installed."""
    bundle = bundle_id or ""
    if is_apple_app(path, bundle, has_receipt):
        return "apple"
    if cask:
        return "cask"
    if has_receipt:
        return "mas"
    if bundle.startswith("com.jetbrains.") and bundle != "com.jetbrains.toolbox":
        return "jetbrains-toolbox"  # installed and updated by JetBrains Toolbox
    return "manual"


def last_used_iso(value: Any) -> Optional[str]:
    """Render a Spotlight date as UTC ISO-8601 (mdls -plist dates are naive UTC)."""
    if not isinstance(value, dt.datetime):
        return None
    return value.replace(tzinfo=dt.timezone.utc).isoformat(timespec="seconds")


def app_entry(path: Path, index: AppIndex) -> Json:
    """Everything the report needs to know about one app."""
    attrs = spotlight_attrs(path)
    plist = info_plist(path)
    bundle_id = attrs.get("kMDItemCFBundleIdentifier") or plist.get("CFBundleIdentifier")
    has_receipt = bool(attrs.get("kMDItemAppStoreHasReceipt")) or (path / "Contents" / "_MASReceipt").exists()
    cask = index.cask_for(path, bundle_id)
    return {
        "name": path.stem,
        "path": str(path),
        "bundle_id": bundle_id,
        "version": attrs.get("kMDItemVersion") or plist.get("CFBundleShortVersionString"),
        "source": app_source(path, bundle_id, cask, has_receipt),
        "cask": cask,
        "mas_id": index.mas_id_for(path.stem, has_receipt),
        "last_used": last_used_iso(attrs.get("kMDItemLastUsedDate")),
        "use_count": attrs.get("kMDItemUseCount"),
        "activity": iso(activity_time(bundle_id, path.stem)),
        "size_mb": round((attrs.get("kMDItemPhysicalSize") or 0) / 1_048_576),
        "login_item": path.stem.lower() in index.login_items,
        "arch": "intel-only" if intel_only(path, plist) else None,
    }


def is_helper_app(path: Path) -> bool:
    """Hidden helper bundles and uninstallers are not apps anyone opens."""
    return path.name.startswith(".") or "uninstall" in path.name.lower()


def collect_apps(brew: Json, mas: List[Json], login: Json) -> List[Json]:
    """One entry per app bundle on disk."""
    index = AppIndex(brew, mas, login)
    return [app_entry(path, index) for path in find_apps() if not is_helper_app(path)]


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def collect() -> Json:
    """Build the whole snapshot."""
    log("collecting host info, Homebrew, Mac App Store, mise ...")
    host = collect_host()
    brew = collect_brew()
    mas = collect_mas()
    login = collect_login_items()
    log("reading app metadata (Spotlight) ...")
    apps = collect_apps(brew, mas, login)
    log("collecting mise, other package managers, shell history ...")
    return {
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


def main(argv: Optional[List[str]] = None) -> int:
    """Write the snapshot to --out, or to stdout by default."""
    parser = argparse.ArgumentParser(description="Snapshot this Mac's apps and tools to JSON (read-only).")
    parser.add_argument("--out", "-o", default="-", help="output file (default: stdout)")
    args = parser.parse_args(argv)
    snapshot = collect()
    text = json.dumps(snapshot, indent=1, sort_keys=True, default=str)
    if args.out == "-":
        sys.stdout.write(text)
        return 0
    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    log(f"wrote {out} ({len(snapshot['apps'])} apps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
