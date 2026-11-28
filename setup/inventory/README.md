# Mac inventory and sync

Read-only tooling for three jobs:

1. Find apps and tools that are installed but no longer used.
2. Re-run the same inventory any time later.
3. Keep two Macs on the same set of software, with the dotfiles' mise config
   as the source of truth.

Nothing here installs or removes software. Installing is `mise bootstrap`'s
job; removing stays a manual, reviewed step.

## Where things are declared

| What | Where | Installed by |
| --- | --- | --- |
| CLI tools with a mise registry entry | `[tools]` in `.config/mise/config.toml` (every OS) or `config.macos.toml` (Macs only) | `mise install` / `mise bootstrap` |
| Homebrew formulae with no registry entry | `"brew:<formula>"` in `config.macos.toml` `[bootstrap.packages]` | `mise bootstrap` |
| GUI apps | `"brew-cask:<cask>"` in the same table | `mise bootstrap` |
| Mac App Store apps | `"mas:<id>"` in the same table (`mas list` shows IDs) | `mise bootstrap` (signed in to the App Store) |
| macOS settings | `[bootstrap.macos.*]` in `config.macos.toml` | `mise bootstrap` |
| Dotfiles | `[dotfiles]` | `mise bootstrap` / `mise dotfiles apply` |

To add something, either edit the file or let mise write it:

```sh
mise use -g stern@latest                       # CLI tool → [tools]
mise bootstrap packages use -g brew-cask:obsidian mas:1295203466
```

`-g` writes to `~/.config/mise/config.toml`, which is this repo's
`config.toml`. Move Mac-only entries to `config.macos.toml` by hand.

## Tasks

| Task | What it does |
| --- | --- |
| `mise run mac:inventory` | Snapshot this Mac and write `report.md` |
| `mise run mac:inventory:remote <host>` | Snapshot another Mac over SSH |
| `mise run mac:inventory:diff [a] [b]` | Compare two Macs' latest snapshots |
| `mise run mac:status` | mise's own drift view: declared packages/tools that are missing |

The report lists:

- **Removal candidates**: apps not opened in 90+ days. *Last opened* is
  Spotlight's launch record. *Data touched* is the newest change to the app's
  preferences and containers, because some apps never get a launch record
  (menu-bar agents, apps launched by JetBrains Toolbox).
- **Ghost casks**: Homebrew still lists the cask, but its app was deleted.
- **Homebrew formulae duplicated by a mise tool**: both put the same command
  on PATH.
- **CLI tools never seen in shell history**: zsh history (timestamped),
  PowerShell history (no timestamps, so only counts) and bash history. Tools
  referenced by shell init files are left out. A tool only scripts or agents
  call will look unused.
- **Drift**: installed but not declared (it won't follow you to the other
  Mac), and declared but not installed.
- **Other package managers** (npm -g, Volta, dotnet tools, cargo, go, krew,
  VS Code extensions), with the mise backend each could move to.
- **Cleanup commands** for the mechanical cases only.

## Where snapshots go

Snapshots list installed software, and this repository is public, so they
are never written here. The directory is `$MAC_INVENTORY_DIR`, else
`~/Library/Mobile Documents/com~apple~CloudDocs/mac-inventory` (iCloud
Drive, private and visible from both Macs), else
`~/.local/state/mac-inventory`.

```
mac-inventory/
  <LocalHostName>/latest.json       newest snapshot
  <LocalHostName>/YYYY-MM-DD.json   one per day collected, for history
  <LocalHostName>/report.md
  diff-<a>-vs-<b>.md
```

## Bringing the other Mac in line

1. **Inventory it before changing anything.** Either:
   - from this Mac, if it accepts SSH (Remote Login or Tailscale SSH):
     `mise run mac:inventory:remote <host>`. The collector streams over SSH
     and needs only the system `python3`, so the other Mac needs no setup; or
   - on the other Mac: `git -C ~/dotfiles pull && mise run mac:inventory`.
     With iCloud Drive on both, the snapshot appears here too.
2. **Compare**: `mise run mac:inventory:diff`. Apps listed as only on the
   other Mac that are not declared are what to remove there; apps only on
   this Mac are what bootstrap will add.
3. **Read the other Mac's `report.md`** for what it has that nothing
   declares, plus its ghost casks and duplicates.
4. **Bootstrap it**: on the other Mac, `~/dotfiles/setup/setup-macos.sh`
   (first time) or `mise bootstrap --yes`. From here, `mise bootstrap remote`
   can do it over SSH:
   `mise bootstrap remote --host <host> --source ~/dotfiles --dry-run`.
5. **Remove** what the diff and report flagged, by hand:
   `brew uninstall [--cask] …`, `mas uninstall <id>`, or drag the app to the
   Trash.

`mise bootstrap packages prune --manager brew-cask` only removes casks that
mise itself installed, so on a Mac set up before this config existed,
removal stays manual.

## Requirements

- `collect` uses only the system `python3` (3.9, from the Command Line
  Tools that Homebrew requires).
- `report` and `diff` read the mise TOML with `tomllib`, so they run on
  mise's Python (3.11+). Under an older Python they still run, minus the
  drift sections.
- `mac:status` puts Homebrew's bundled portable Ruby on PATH, because mise
  needs Ruby 3+ to evaluate casks from third-party taps and macOS ships 2.6.
