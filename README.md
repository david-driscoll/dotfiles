# dotfiles

David Driscoll's personal machine configuration, bootstrapped end-to-end by
[mise](https://mise.jdx.dev) — one declarative config drives tools, symlinks,
macOS settings, and (on mac/Linux) the login shell.

## Platforms

| OS | Why it matters | Entry point |
| --- | --- | --- |
| **macOS** | Daily driver — GUI apps, full desktop | `setup/setup-macos.sh` |
| **Linux** | GitHub Codespaces (auto-run on container create) + self-hosted Coder workspaces — ephemeral, no attached TTY | `install.sh` |
| **Windows** | Work machine | `setup/setup.ps1` |

## Quick start

Pick your OS. Every script is idempotent — re-running it is always safe (see
[Common operations](#common-operations)).

### macOS

```sh
setup/setup-macos.sh
```

In order:

1. Installs Homebrew (upstream installer, `NONINTERACTIVE=1`) if it isn't
   already on `PATH` or at `/opt/homebrew` / `/usr/local`.
2. Loads `brew shellenv` into the running script so the rest of the steps
   can see `brew`/`mise`.
3. `brew install mise` if mise isn't already present.
4. Installs oh-my-zsh (`--unattended`) if `~/.oh-my-zsh` doesn't exist yet —
   `.zshrc` unconditionally sources it and nothing else in this repo
   installs the framework itself.
5. Symlinks `~/.config/mise` → this repo's `.config/mise` (see
   [The one bootstrap symlink](#the-one-bootstrap-symlink) below).
6. `mise trust --all`, then `mise bootstrap --yes` — installs
   `[bootstrap.packages]` Homebrew formulae, runs the `brew:casks` task
   (installs `setup/Brewfile.darwin`'s GUI apps), applies `[dotfiles]`, and
   installs `[tools]`.

Source: `setup/setup-macos.sh`.

### Linux — Codespaces, Coder, or WSL

```sh
./install.sh
```

GitHub Codespaces runs this automatically on container creation. In order:

1. Installs mise via `curl -fsSL https://mise.run | sh`-equivalent (downloads
   the installer first, sanity-checks it isn't truncated, then runs it) if
   mise isn't already resolvable.
2. Symlinks `~/.config/mise` → this repo's `.config/mise`.
3. `mise trust --all`, then `mise bootstrap --yes` — installs
   `[dotfiles]` and `[tools]` (no `[bootstrap.packages]` on Linux by
   default — see the [tool table](#tool-table)).
4. Checks (never triggers) `gh` auth: logs whether `gh` is already
   authenticated, has `GITHUB_TOKEN`/`GH_TOKEN` available, or needs
   `gh auth login` run by hand later. It never calls `gh auth login` itself
   — that opens an interactive device-code flow that would hang a
   non-interactive container build.

`uname -s` reports WSL as plain `Linux` (same as mise sees it), so this
script also covers WSL with no special-casing.

If run on macOS, `install.sh` detects `Darwin` and `exec`s straight into
`setup/setup-macos.sh` instead — same process, so that script's exit code
becomes `install.sh`'s exit code. You can also just run
`setup/setup-macos.sh` directly.

Source: `install.sh`.

### Windows

Open an elevated PowerShell prompt (the script self-elevates via UAC if you
don't) and run:

```powershell
setup\setup.ps1
```

In order:

1. Sets the execution policy to `Unrestricted` (machine scope) if it isn't
   already, so this script and the profile stubs it writes can run.
2. Enables required Windows optional features (WSL, Hyper-V, Virtual
   Machine Platform, Containers) and capabilities (OpenSSH client + server)
   if not already enabled/installed.
3. `winget install jdx.mise` and `winget install Git.Git`, then refreshes
   this process's `PATH` from the registry (winget doesn't do this for you).
4. Junctions `%USERPROFILE%\.config\mise` → this repo's `.config\mise`
   (falls back to setting `MISE_GLOBAL_CONFIG_FILE` if the junction can't be
   created).
5. Writes a one-line stub at every PowerShell profile path (Windows
   PowerShell 5.1 and PowerShell 7, both `profile.ps1` and
   `Microsoft.PowerShell_profile.ps1`) that dot-sources this repo's
   `profile.ps1` — see [Windows caveats](#platform-caveats) for why these
   are stubs, not `[dotfiles]` entries.
6. Wires `git config --global include.path` to `git\gitconfig.windows` for
   the Windows-only overrides.
7. `mise trust`, `mise dotfiles apply --yes`, `mise install` — run
   individually rather than `mise bootstrap`, since Windows has nothing in
   `[bootstrap.packages]` or `[bootstrap.user]` (see
   [Windows caveats](#platform-caveats)).
8. Installs the winget package list at the bottom of the script — GUI apps
   and platform pieces mise/aqua has no backend for (1Password, VS Code,
   browsers, Docker Desktop, fonts, etc.).

**Note:** `setup/setup.ps1` was authored and statically verified (PowerShell
AST parse) from macOS — it has not yet been run on a real Windows machine.
Treat the first run as a dry run you watch closely.

Source: `setup/setup.ps1`.

## Architecture

### Global vs. repo-local mise config

```
~/dotfiles/
  .config/mise/
    config.toml              # GLOBAL — symlinked to ~/.config/mise/config.toml
    config.macos.toml        # GLOBAL, macOS-only layer
    config.macos-arm64.toml  # GLOBAL, macOS+arm64-only layer
    config.linux.toml        # GLOBAL, Linux-only layer
    mise.lock                # committed lockfile
  mise.toml                  # REPO-LOCAL — active only when cwd is inside this checkout
```

`.config/mise/config.toml` is the **global** config: general-purpose CLI
tools (`[tools]`), the cross-platform `[dotfiles]` table, `[bootstrap.*]`,
and settings that should apply no matter what directory you're standing in
— it's symlinked to `~/.config/mise/config.toml` on every machine. Crew
tooling (the `crew` CLI itself, `apm`, `skillfile`, and their env/hooks)
lives here specifically because it needs to work from any directory, not
just inside this checkout.

`mise.toml` at the repo root is **repo-local** — mise only reads it when
your current directory is inside this checkout. It holds exactly two
things that are genuinely repo-specific: the `update-agents` task (operates
on this repo's own `ai/`/`agents/` apm projects) and the `brew:casks` task
(shells out to `{{config_root}}/setup/Brewfile.darwin`, a path that only
resolves correctly when `{{config_root}}` is this repo's root).

### Platform config layering

macOS- and Linux-only `[dotfiles]`/`[bootstrap.*]` entries live in sibling
files named `config.<platform>.toml` (and `config.<platform>-<arch>.toml`
for architecture-specific entries), following mise's own [platform config-file
convention](https://mise.jdx.dev/configuration/environments.html#platform-environments):

| File | Loaded on |
| --- | --- |
| `config.toml` | every platform |
| `config.macos.toml` | macOS |
| `config.macos-arm64.toml` | macOS + arm64 (Apple Silicon) — currently the only architecture file that exists; there is no `config.macos-x64.toml` yet |
| `config.linux.toml` | Linux (including WSL — mise reports WSL as plain `linux`, there's no separate WSL platform) |

**This layering only activates when `MISE_AUTO_ENV=1` is set as a real
environment variable before mise reads any config** — confirmed empirically
against mise 2026.7.7 and documented in `config.toml`'s own `[settings]`
comment. Setting `auto_env = true` in `[settings]` is not sufficient by
itself (bootstrap ordering: mise has to know which extra files to read
before it can read the file that tells it to). `.zshrc` and `.bashrc` both
`export MISE_AUTO_ENV=1` ahead of `mise activate`; `install.sh` and
`setup/setup-macos.sh` export it too, since their own `mise trust`/`mise
bootstrap` calls need to see the platform-only entries. **Windows does not
set `MISE_AUTO_ENV=1`**, but as of the junction in `setup/setup.ps1`,
`%USERPROFILE%\.config\mise` points at this same directory — so Windows
loads plain `config.toml` (nothing platform-gated), with a copy fallback
for `[dotfiles]` entries (see [Windows caveats](#platform-caveats)).

### The one bootstrap symlink

Every other symlink in this repo is declared in `[dotfiles]` and applied by
`mise bootstrap`/`mise dotfiles apply` — except one: `~/.config/mise` itself
can't be, because it's the file `[dotfiles]` lives in. mise has to already
be pointed at this repo's config before it can read the table that would
otherwise create that link — a chicken-and-egg case. Each OS's entry-point
script creates this one symlink by hand, before calling into mise at all:

- macOS / Linux: `ln -s <repo>/.config/mise ~/.config/mise` (`link_mise_config()` in `install.sh` and `setup/setup-macos.sh`)
- Windows: `New-Item -ItemType Junction -Path $MiseConfigHome -Value $MiseConfigRepo` in `setup/setup.ps1`

All three handle re-runs: an existing correct link is a no-op, a stale/wrong
link gets relinked, and a real directory in the way gets moved aside
(backed up, timestamped) rather than deleted.

### Who owns what

| Table | Scope | Owns |
| --- | --- | --- |
| `[tools]` (`config.toml`) | every platform | CLI tools mise/aqua can install directly — pinned versions |
| `[dotfiles]` (`config.toml` + platform layers) | symlinks/copies from repo → `$HOME`, gated per-platform via the layering above | `.zshrc`, `~/.ssh`, `~/.gitconfig`, `starship.toml`, `~/.config/powershell`, macOS-only entries (karabiner, 1Password SSH agent, `.gitconfig.local`), Linux-only entries (`.wslrc`, `.gitconfig.local`) |
| `[bootstrap.packages]` (`config.macos.toml`) | macOS only | Homebrew **formulae** mise's own registry can't provide (zsh + plugins, git, moreutils, mas, azure-cli, gitkraken-cli, speedtest-cli, powershell) |
| `[bootstrap.macos.*]` (`config.macos.toml`) | macOS only | Dock/Finder/keyboard/trackpad `defaults`, `[bootstrap.hooks].post-packages` → the `brew:casks` task (Homebrew **casks**, i.e. GUI apps, from `setup/Brewfile.darwin`) |
| `[bootstrap.user]` (`config.macos-arm64.toml`) | macOS (Apple Silicon) only | `login_shell` for `chsh` |

### Lockfile and version bumps

`.config/mise/mise.lock` is committed — `[settings] lockfile = true` in
`config.toml`. Tool versions are pinned directly in `[tools]` entries (e.g.
`gh = "2.96.0"`), not left floating. `renovate.json` scopes Renovate to mise
config files only (`enabledManagers: ["mise"]`, matching `mise.toml` and
`.config/mise/config.toml` file patterns) with `automerge: true` — Renovate,
not a human, opens (and merges) the version-bump PRs for everything in
`[tools]`.

## Tool table

Generated from the actual config files on this branch — not the epic's
pre-implementation draft, which used different names for a few tools (see
notes).

### mise `[tools]` — every platform (`.config/mise/config.toml`)

| Tool | Version | Notes |
| --- | --- | --- |
| `fzf` | 0.74.1 | |
| `uv` | 0.11.32 | |
| `jq` | 1.8.2 | |
| `yq` | 4.53.3 | |
| `sops` | 3.13.3 | |
| `age` | 1.3.1 | |
| `npm:@github/copilot` | 1.0.75 | |
| `dotnet:graphify-dotnet` | 0.7.0 | |
| `biome` | 2.5.5 | |
| `node` | 24.18.0 | |
| `dotnet` | 10.0.302 | |
| `github:microsoft/apm` | v0.26.0 | binary `apm` |
| `github:eljulians/skillfile` | v1.9.0 | binary `skillfile` |
| `gh` | 2.96.0 | aqua:cli/cli |
| `terraform` | 1.15.8 | aqua:hashicorp/terraform |
| `pulumi` | 3.254.0 | aqua:pulumi/pulumi |
| `kubectl` | 1.36.3 | aqua:kubernetes/kubernetes/kubectl |
| `helm` | 4.2.3 | aqua:helm/helm |
| `helmfile` | 1.7.1 | aqua:helmfile/helmfile |
| `kustomize` | 5.8.1 | aqua:kubernetes-sigs/kustomize |
| `kubeconform` | 0.8.0 | aqua:yannh/kubeconform |
| `flux2` | 2.9.3 | aqua:fluxcd/flux2 — installs the `flux` binary; the epic called this tool "flux", but the mise registry shorthand is `flux2` |
| `task` | 3.52.0 | aqua:go-task/task — installs the `task` binary; the epic called this "go-task" |
| `starship` | 1.26.0 | aqua:starship/starship |
| `zoxide` | 0.10.0 | aqua:ajeetdsouza/zoxide |
| `direnv` | 2.37.1 | aqua:direnv/direnv |
| `eza` | 0.23.5 | asdf:mise-plugins/mise-eza |
| `talosctl` | 1.13.7 | aqua:siderolabs/talos |
| `talhelper` | 3.1.15 | aqua:budimanjojo/talhelper |
| `mkcert` | 1.4.4 | aqua:FiloSottile/mkcert |
| `powershell` | 7.6.4 | replaces the old `brew "powershell/tap/powershell"` formula for general use — see the macOS login-shell caveat below for why a *separate* Homebrew `pwsh` also exists |
| `python` | 3.14.6 | replaces duplicated `brew "python"` entries |

The epic's tool table also listed `stern`; it does not appear in
`config.toml`'s `[tools]` on this branch — flagged as a discrepancy rather
than silently reconciled, since it wasn't possible to confirm from the repo
alone whether that was a deliberate drop.

### Homebrew formulae — macOS only (`.config/mise/config.macos.toml`, `[bootstrap.packages]`)

Installed via `mise bootstrap` (or `mise bootstrap --only packages`); status
checkable with `mise bootstrap packages status`.

| Formula | Why brew, not mise |
| --- | --- |
| `zsh`, `zsh-autosuggestions`, `zsh-autocomplete`, `zsh-syntax-highlighting`, `zsh-completions`, `zsh-you-should-use` | zsh ecosystem — not in mise's registry |
| `git` | |
| `moreutils` | |
| `mas` | |
| `azure-cli` | |
| `gitkraken-cli` | |
| `speedtest-cli` | epic flagged this with a "?" — carried forward from the deleted `setup/Brewfile` rather than silently dropped |
| `powershell` | **deliberate duplicate** of the mise-tool `powershell` pin above — exists solely so `[bootstrap.user]`'s `login_shell` has a Homebrew-managed `pwsh` binary to point `chsh` at; see [Platform caveats](#platform-caveats) |

### Homebrew casks — macOS GUI apps (`setup/Brewfile.darwin`, via the `brew:casks` task)

Installed by the repo-local `mise.toml`'s `brew:casks` task, wired in via
`config.macos.toml`'s `[bootstrap.hooks].post-packages`. Full list (grouped
in the source file): 1Password + 1Password CLI, gpg-suite, tailscale-app,
karabiner-elements, linearmouse, middleclick, stats, eul, hiddenbar, alcove,
dockdoor, typewhisper, wezterm, iterm2, warp, jetbrains-toolbox,
visual-studio-code (+ Insiders), docker, gitkraken, devtoys, arc,
google-chrome, firefox, microsoft-edge, vivaldi, slack, microsoft-teams,
discord, and a set of Nerd Font casks. See `setup/Brewfile.darwin` directly
for the current, definitive list — several groups (3 terminals, 5 browsers,
10 font casks) are flagged in-file as trim candidates that haven't been
resolved yet.

### winget — Windows only (`setup/setup.ps1`)

No mise/aqua backend exists for these — see
[Platform caveats](#platform-caveats). Notable entries: `AgileBits.1Password`
(+ CLI), `GnuPG.Gpg4win`, `tailscale`, `Microsoft.VisualStudioCode` (+
Insiders), `Microsoft.AzureCLI`, `Microsoft.WindowsTerminal` (+ Preview),
`Docker.DockerDesktop`, browsers (Chrome, Firefox, Edge + betas),
`SlackTechnologies.Slack`, `Microsoft.Teams`, `Microsoft.PowerToys`,
`DEVCOM.JetBrainsMonoNerdFont`, and more. Every CLI tool that `[tools]`
already covers (jq, kubectl, helm, terraform, starship, zoxide, sops, gh,
python, powershell, ...) was deliberately removed from this list when it
was rewritten — `mise install` in the script above is what installs those
on Windows now. See the script's own `$WingetPackages` array for the
complete, current list and inline notes on unresolved trim candidates
(TortoiseGit, GitHub Desktop, browser betas, the NirSoft set).

## Platform caveats

These will bite if you don't know about them going in.

- **Windows has no `[bootstrap.packages]` winget backend.** A third-party
  mise-winget plugin was evaluated and rejected (see the `#73` spike,
  `docs/research/mise-bootstrap-plugins.md`) — the winget package list in
  `setup/setup.ps1` stays a plain PowerShell array, not a mise-declared
  table, and isn't tracked by `mise bootstrap status`.
- **Windows has no `[bootstrap.user]` / `login_shell`.** `chsh` is
  Unix-only. `setup/setup.ps1` never calls `mise bootstrap` at all — it
  calls `mise trust`, `mise dotfiles apply --yes`, and `mise install`
  individually, since those are the only three bootstrap phases that mean
  anything on Windows.
- **mise's `[dotfiles]` file symlinks fall back to *copying* on Windows** —
  a real file symlink needs `SeCreateSymbolicLinkPrivilege` (elevation or
  Developer Mode); a copy silently drifts from the repo the moment either
  side is edited. That's acceptable for files Windows or another tool owns
  after the first write (`~/.ssh`, `~/.gitconfig`), but wrong for a file
  meant to be edited in place — which is exactly why the PowerShell
  profiles are **not** `[dotfiles]` entries at all. `setup/setup.ps1`
  instead writes a one-line stub at every profile path that dot-sources
  `profile.ps1` in this repo, so an edit there is live in the next shell
  with no copy to go stale. Directory entries (like `~/.config/mise`
  itself) still get a real junction, which Windows allows without
  elevation.
- **`MISE_AUTO_ENV=1` is required for platform config layering to
  activate** — see [Platform config layering](#platform-config-layering)
  above. Without it, `config.macos.toml`/`config.linux.toml` are never
  read, even with `auto_env = true` set in `[settings]`.
- **`~/.gitconfig.local` must be deployed before your first commit on a new
  machine, or git has no email configured.** Per `#65`/`#81`,
  `~/.gitconfig` (the shared, committed file) intentionally carries only
  `user.name` — `user.email`, `user.signingkey`, and `github.user` all live
  in the per-OS `git/gitconfig.<os>` files, pulled in via `~/.gitconfig`'s
  `[include] path = ~/.gitconfig.local`. That `.gitconfig.local` is itself
  a `[dotfiles]` entry (macOS/Linux, via the platform layers) or written by
  `setup/setup.ps1`'s `git config --global include.path` call (Windows) —
  either way, it only exists after bootstrap has actually run once.
- **macOS login-shell duplication is deliberate, not an oversight.**
  `config.macos-arm64.toml`'s `[bootstrap.user]` points `login_shell` at
  the Homebrew-installed `pwsh` (`/opt/homebrew/opt/powershell/bin/pwsh`),
  *not* the mise-tool `pwsh` pinned in `[tools]` — bootstrap's phase order
  runs `[bootstrap.user]` before `[tools]` installs anything, so the
  mise-tool binary wouldn't even exist yet on a first run, and a shim-based
  login shell would break the moment mise's own state changes. The mise
  `[tools]` `powershell` pin still exists for everyday interactive/script
  use.
- **Linux deliberately has no `[bootstrap.user]` / `login_shell`.**
  Codespaces hardcodes `$SHELL=/bin/bash` for every terminal regardless of
  `/etc/passwd`, and there's no established Homebrew-equivalent
  mise-independent `pwsh` binary on Linux — both reasons are documented in
  `config.linux.toml`'s header.
- **Only `config.macos-arm64.toml` exists today** — there is no
  `config.macos-x64.toml`, despite a comment in the arm64 file describing
  an Intel twin. Don't assume Intel Mac coverage exists until that file is
  actually added.

## Common operations

**Re-run bootstrap** (safe, idempotent, on any OS — declarative steps
converge, already-correct state is skipped):

```sh
setup/setup-macos.sh   # macOS
./install.sh           # Linux / Codespaces / Coder / WSL
```

```powershell
setup\setup.ps1        # Windows
```

**Check for drift** without changing anything:

```sh
mise bootstrap status          # aggregate: packages, dotfiles, tools, etc.
mise dotfiles status           # just the [dotfiles] table
mise bootstrap macos defaults status   # macOS defaults only
```

**Add a tool** — edit the `[tools]` table in
`.config/mise/config.toml` (or `mise.toml` if it's genuinely repo-specific),
pin a version, then `mise install`. Renovate will take over future version
bumps for anything added to a mise-managed file (see
[Lockfile and version bumps](#lockfile-and-version-bumps)).

**Add a macOS default** — use the read-only capture helper instead of
guessing the domain/key/type by hand:

```sh
setup/capture-defaults.sh snapshot before
# ... change one thing in System Settings ...
setup/capture-defaults.sh snapshot after
setup/capture-defaults.sh diff before after
setup/capture-defaults.sh type <domain> <key>   # confirm the true stored type
```

Then encode the result in `.config/mise/config.macos.toml`'s
`[bootstrap.macos.*]` tables. This script never runs `defaults write` or
`defaults delete` — it only reads and diffs.

**Roll back the pwsh login shell** (macOS) back to zsh:

```sh
chsh -s /bin/zsh
```

zsh stays listed in `/etc/shells` and fully dotfiles-managed regardless —
this doesn't touch `.zshrc`, `.zprofile`, or remove zsh from `/etc/shells`.

## Status

This migration is tracked as epic
[#61](https://github.com/david-driscoll/dotfiles/issues/61). Everything
described above reflects `master` as of this PR. Still open, not yet
reflected in any script:

- [#89](https://github.com/david-driscoll/dotfiles/pull/89) (closes #83) —
  a single idempotent mise task for the 10 `gh` CLI extensions. Until it
  merges, the repo-local `mise.toml`'s `gh-extensions`/`gh-mcp` tasks only
  install one of the ten (`shuymn/gh-mcp`).
- [#91](https://github.com/david-driscoll/dotfiles/pull/91) — an optional
  macOS launchd agent for periodic `mise up`/drift checks. Not installed by
  any script today.
- [#90](https://github.com/david-driscoll/dotfiles/issues/90) — restoring
  Azure CLI extension installation (`az extension add`) as a single mise
  task, mirroring #89's pattern. Not started; `az extension add` isn't run
  anywhere in this repo today.
