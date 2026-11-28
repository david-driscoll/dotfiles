"""
Compare two inventory snapshots, e.g. this Mac against the other one.

Apps only on one side (and whether the dotfiles declare them), version
differences, and set differences for Homebrew, the App Store, mise tools and
other package managers.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Set

from inventory_common import Declared, Json, app_install_ref, fmt_age, fmt_date, md_table

OTHER_SETS = (
    ("npm_global", "npm -g"), ("dotnet_tools", "dotnet tools"), ("gh_extensions", "gh extensions"),
    ("vscode_extensions", "VS Code extensions"), ("volta", "Volta"),
)


def app_map(snap: Json) -> Dict[str, Json]:
    """Non-Apple apps keyed by bundle ID (falling back to name)."""
    return {(a.get("bundle_id") or a["name"]): a for a in snap["apps"] if a["source"] != "apple"}


def declared_note(app: Json, declared: Optional[Declared]) -> str:
    """'declared' when the dotfiles declare the app's cask or App Store ID."""
    if declared is None:
        return ""
    if app.get("cask") in declared["brew-cask"] or app.get("mas_id") in declared["mas"]:
        return "declared"
    return ""


class DiffContext:
    """Both snapshots plus their app maps and host names."""

    def __init__(self, a: Json, b: Json, declared: Optional[Declared]) -> None:
        """Index both snapshots."""
        self.a, self.b, self.declared = a, b, declared
        self.an, self.bn = a["host"]["computer_name"], b["host"]["computer_name"]
        self.am, self.bm = app_map(a), app_map(b)

    def set_section(self, title: str, left: Set[str], right: Set[str]) -> List[str]:
        """A ✓-matrix of items present on only one side."""
        rows = [[x, "✓" if x in left else "", "✓" if x in right else ""] for x in sorted(left ^ right)]
        return [f"## {title}\n", md_table(["", self.an, self.bn], rows) if rows else "_Identical._\n"]


def section_hosts(ctx: DiffContext) -> List[str]:
    """Title and the two machines side by side."""
    rows = [[label, ctx.a["host"][key], ctx.b["host"][key]]
            for label, key in (("Model", "model"), ("Chip", "chip"), ("macOS", "macos"))]
    rows.append(["Collected", ctx.a["host"]["collected_at"][:10], ctx.b["host"]["collected_at"][:10]])
    return [f"# Mac inventory diff — {ctx.an} vs {ctx.bn}\n", md_table(["", ctx.an, ctx.bn], rows)]


def apps_only_on(ctx: DiffContext, left: Dict[str, Json], right: Dict[str, Json], host: str) -> List[str]:
    """Apps present on `host` but not the other Mac."""
    apps = sorted((app for key, app in left.items() if key not in right), key=lambda a: a["name"].lower())
    rows = [[a["name"], app_install_ref(a), f"{fmt_date(a['last_used'])} ({fmt_age(a['last_used'])})",
             declared_note(a, ctx.declared)] for a in apps]
    return [f"## Apps only on {host}\n", md_table(["App", "Installed via", f"Last used on {host}", "In dotfiles"], rows)]


def section_apps(ctx: DiffContext) -> List[str]:
    """Apps on one side only, then version differences."""
    shared = sorted(set(ctx.am) & set(ctx.bm), key=lambda k: ctx.am[k]["name"].lower())
    versions = [[ctx.am[k]["name"], ctx.am[k]["version"], ctx.bm[k]["version"]]
                for k in shared if ctx.am[k]["version"] != ctx.bm[k]["version"]]
    return (apps_only_on(ctx, ctx.am, ctx.bm, ctx.an) + apps_only_on(ctx, ctx.bm, ctx.am, ctx.bn)
            + ["## Apps on both, version differs\n", md_table(["App", ctx.an, ctx.bn], versions)])


def cask_tokens(snap: Json) -> Set[str]:
    """Full cask tokens of a snapshot."""
    return {c["full_token"] for c in snap["brew"].get("casks", [])}


def mas_labels(snap: Json) -> Set[str]:
    """'Name (id)' for each App Store app of a snapshot."""
    return {f"{m['name']} ({m['id']})" for m in snap.get("mas", [])}


def section_packages(ctx: DiffContext) -> List[str]:
    """Homebrew leaves, casks, taps and App Store apps."""
    a, b = ctx.a, ctx.b
    return (ctx.set_section("Homebrew formulae you installed (leaves)",
                            set(a["brew"].get("leaves", [])), set(b["brew"].get("leaves", [])))
            + ctx.set_section("Homebrew casks", cask_tokens(a), cask_tokens(b))
            + ctx.set_section("Homebrew taps", set(a["brew"].get("taps", [])), set(b["brew"].get("taps", [])))
            + ctx.set_section("Mac App Store", mas_labels(a), mas_labels(b)))


def mise_active(snap: Json) -> Dict[str, str]:
    """Active mise tool versions of a snapshot."""
    return {t["name"]: t["version"] for t in snap.get("mise", {}).get("tools", []) if t["active"]}


def section_mise(ctx: DiffContext) -> List[str]:
    """mise tools whose active version differs."""
    ma, mb = mise_active(ctx.a), mise_active(ctx.b)
    rows = [[t, ma.get(t, "—"), mb.get(t, "—")] for t in sorted(set(ma) | set(mb)) if ma.get(t) != mb.get(t)]
    return ["## mise tools (active versions)\n", md_table(["Tool", ctx.an, ctx.bn], rows) if rows else "_Identical._\n"]


def section_other(ctx: DiffContext) -> List[str]:
    """Other package managers, one ✓-matrix each."""
    parts: List[str] = []
    for key, label in OTHER_SETS:
        left = set(ctx.a.get("other", {}).get(key) or [])
        right = set(ctx.b.get("other", {}).get(key) or [])
        parts += ctx.set_section(label, left, right)
    return parts


def build_diff(a: Json, b: Json, declared: Optional[Declared]) -> str:
    """Render the Markdown comparison of two snapshots."""
    ctx = DiffContext(a, b, declared)
    parts: List[str] = []
    for section in (section_hosts, section_apps, section_packages, section_mise, section_other):
        parts += section(ctx)
    return "\n".join(parts)
