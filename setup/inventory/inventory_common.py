"""Shared helpers for the inventory report and diff."""

# Formatting, date math, app classification, shell-history lookups, and reading
# what the dotfiles' mise config declares.


from __future__ import annotations

import datetime as dt
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

Json = Dict[str, Any]
Declared = Dict[str, Set[str]]

HOME = Path.home()
NOW = dt.datetime.now(dt.timezone.utc)
DEFAULT_STALE_DAYS = 90
# mise registry short names that install a differently-named binary/formula.
TOOL_ALIASES = {"flux2": "flux", "powershell": "pwsh", "1password-cli": "op", "task": "go-task"}
DECLARED_MANAGERS = ("brew", "brew-cask", "mas")


def log(msg: str) -> None:
    """Print a progress message to stderr."""
    print(f"[mac-inventory] {msg}", file=sys.stderr)


def write_output(text: str, out: str) -> None:
    """Write text to a file, or to stdout when out is '-'."""
    if out == "-":
        sys.stdout.write(text)
        return
    Path(out).expanduser().write_text(text)
    log(f"wrote {out}")


# --------------------------------------------------------------------------
# dates and formatting
# --------------------------------------------------------------------------

def days_since(value: Optional[str]) -> Optional[int]:
    """Whole days between an ISO timestamp and now; None if missing."""
    if not value:
        return None
    try:
        return (NOW - dt.datetime.fromisoformat(value)).days
    except ValueError:
        return None


def fmt_date(value: Optional[str]) -> str:
    """YYYY-MM-DD of an ISO timestamp, or an em dash."""
    return value[:10] if value else "—"


def fmt_age(value: Optional[str]) -> str:
    """Human age of an ISO timestamp: 'today', '12d ago', 'never recorded'."""
    days = days_since(value)
    if days is None:
        return "never recorded"
    return "today" if days == 0 else f"{days}d ago"


def md_cell(value: Any) -> str:
    """One Markdown table cell, with pipes escaped."""
    return str(value).replace("|", "\\|")


def md_table(headers: List[str], rows: List[List[Any]]) -> str:
    """A Markdown table, or '_None._' when there are no rows."""
    if not rows:
        return "_None._\n"
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    lines += ["| " + " | ".join(md_cell(c) for c in row) + " |" for row in rows]
    return "\n".join(lines) + "\n"


def app_install_ref(app: Json) -> str:
    """How to declare an app in mise, or how it was installed."""
    if app["source"] == "cask":
        return f"`brew-cask:{app['cask']}`"
    if app["source"] == "mas" and app.get("mas_id"):
        return f"`mas:{app['mas_id']}`"
    return app["source"]


def shorten(items: List[str], limit: int = 12) -> str:
    """Comma-join the first `limit` items, noting how many were left out."""
    shown = ", ".join(items[:limit])
    return shown + (f" … (+{len(items) - limit})" if len(items) > limit else "")


# --------------------------------------------------------------------------
# apps and CLI usage
# --------------------------------------------------------------------------

def app_evidence(app: Json, stale_days: int) -> Optional[str]:
    """Why an app counts as in use, or None for a removal candidate."""
    # In use means opened within stale_days, a login item, or (when Spotlight
    # has no launch record at all) its data folders changed within stale_days.
    used = days_since(app["last_used"])
    touched = days_since(app["activity"])
    if app["login_item"]:
        return "login item"
    if used is not None and used <= stale_days:
        return f"opened {fmt_age(app['last_used'])}"
    if used is None and touched is not None and touched <= stale_days:
        return f"no launch record; data touched {fmt_age(app['activity'])}"
    return None


def classify_apps(apps: List[Json], stale_days: int) -> Dict[str, List[Json]]:
    """Split apps into apple / active (with an `evidence` key) / stale."""
    buckets: Dict[str, List[Json]] = {"stale": [], "active": [], "apple": []}
    for app in apps:
        if app["source"] == "apple":
            buckets["apple"].append(app)
            continue
        app["evidence"] = app_evidence(app, stale_days)
        buckets["active" if app["evidence"] else "stale"].append(app)
    return buckets


def cli_last_use(usage: Json, names: Iterable[str]) -> Tuple[int, int, Optional[str]]:
    """(total history hits, recent pwsh hits, last zsh timestamp) across names."""
    total = recent = 0
    last: Optional[str] = None
    for entry in (usage[n] for n in names if n in usage):
        total += entry["zsh"] + entry["pwsh"] + entry["bash"]
        recent += entry["pwsh_recent"]
        if entry["last"] and (last is None or entry["last"] > last):
            last = entry["last"]
    return total, recent, last


def tool_short_name(tool: str) -> str:
    """Strip a mise tool key's backend prefix and owner: 'aqua:a/b' -> 'b'."""
    name = tool.split(":", 1)[-1]
    return name.split("/")[-1].lstrip("@")


# --------------------------------------------------------------------------
# what the dotfiles declare
# --------------------------------------------------------------------------

def config_files(dotfiles: Path) -> List[Path]:
    """The global mise config layers plus the repo-local mise.toml."""
    files = sorted((dotfiles / ".config" / "mise").glob("config*.toml")) + [dotfiles / "mise.toml"]
    return [f for f in files if f.is_file()]


def add_packages(declared: Declared, packages: Json) -> None:
    """Record `manager:package` keys from [bootstrap.packages]."""
    for key in packages:
        manager, _, package = key.partition(":")
        if manager in declared:
            declared[manager].add(package.split("/")[-1])


def hook_commands(hooks: Json) -> Iterable[str]:
    """Every command string in [bootstrap.hooks]."""
    for commands in hooks.values():
        for command in commands if isinstance(commands, list) else [commands]:
            yield command if isinstance(command, str) else str(command.get("run", ""))


def add_hook_casks(declared: Declared, hooks: Json) -> None:
    """Casks mise can't evaluate are installed by `brew install --cask` hooks."""
    for command in hook_commands(hooks):
        for token in re.findall(r"brew install --cask\s+(\S+)", command):
            declared["brew-cask"].add(token.split("/")[-1])


def load_declared(dotfiles: Path) -> Optional[Declared]:
    """Read what the dotfiles' mise config declares, by manager."""
    # Needs tomllib (Python 3.11+); returns None on older Pythons so the
    # caller skips the drift sections.
    try:
        import tomllib  # Python 3.11+
    except ImportError:
        log("python < 3.11: skipping drift checks (run via `mise run`, which uses mise's python)")
        return None
    declared: Declared = {"tools": set(), **{m: set() for m in DECLARED_MANAGERS}}
    for file in config_files(dotfiles):
        with open(file, "rb") as handle:
            cfg = tomllib.load(handle)
        declared["tools"] |= {tool_short_name(t) for t in cfg.get("tools", {})}
        bootstrap = cfg.get("bootstrap", {})
        add_packages(declared, bootstrap.get("packages", {}))
        add_hook_casks(declared, bootstrap.get("hooks", {}))
    return declared
