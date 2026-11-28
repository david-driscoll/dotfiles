#!/usr/bin/env python3
"""Read-only inventory of a Mac's apps and tools (CLI behind the mac:* tasks)."""

# collect   Snapshot this Mac to JSON (inventory_collect.py, which also runs on
#           its own over SSH: ssh other-mac python3 - < inventory_collect.py).
# report    Markdown report for one snapshot: unused apps and tools, ghost
#           casks, Homebrew/mise duplicates, drift from the dotfiles config.
# diff      Compare two snapshots, e.g. this Mac against the other one.
#
# Nothing here installs, removes or changes anything. Snapshots list installed
# software, so the mac:* tasks write them outside this public repository.


from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Optional

import inventory_collect
from inventory_common import DEFAULT_STALE_DAYS, HOME, load_declared, write_output
from inventory_diff import build_diff
from inventory_report import build_report


def read_snapshot(path: str) -> dict:
    """Load a snapshot JSON file."""
    return json.loads(Path(path).expanduser().read_text())


def declared_from(dotfiles: str) -> Optional[dict]:
    """The dotfiles' declarations, or None when drift checks are disabled."""
    return load_declared(Path(dotfiles).expanduser()) if dotfiles else None


def cmd_collect(args: argparse.Namespace) -> int:
    """Snapshot this Mac."""
    return inventory_collect.main(["--out", args.out])


def cmd_report(args: argparse.Namespace) -> int:
    """Write the report for one snapshot."""
    text = build_report(read_snapshot(args.snapshot), declared_from(args.dotfiles), args.stale_days)
    write_output(text, args.out)
    return 0


def cmd_diff(args: argparse.Namespace) -> int:
    """Write the comparison of two snapshots."""
    text = build_diff(read_snapshot(args.a), read_snapshot(args.b), declared_from(args.dotfiles))
    write_output(text, args.out)
    return 0


def build_parser() -> argparse.ArgumentParser:
    """Command-line interface: collect | report | diff."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    dotfiles_help = "dotfiles checkout for drift checks ('' to skip)"

    collect = sub.add_parser("collect", help="snapshot this Mac to JSON")
    collect.add_argument("--out", "-o", default="-", help="output file (default: stdout)")
    collect.set_defaults(func=cmd_collect)

    report = sub.add_parser("report", help="Markdown report for one snapshot")
    report.add_argument("snapshot")
    report.add_argument("--out", "-o", default="-")
    report.add_argument("--dotfiles", default=str(HOME / "dotfiles"), help=dotfiles_help)
    report.add_argument("--stale-days", type=int, default=DEFAULT_STALE_DAYS)
    report.set_defaults(func=cmd_report)

    diff = sub.add_parser("diff", help="compare two snapshots")
    diff.add_argument("a")
    diff.add_argument("b")
    diff.add_argument("--out", "-o", default="-")
    diff.add_argument("--dotfiles", default=str(HOME / "dotfiles"), help=dotfiles_help)
    diff.set_defaults(func=cmd_diff)
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    """Parse arguments and run the chosen subcommand."""
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
