# Spike: mise bootstrap package plugins

Research for [#73](https://github.com/david-driscoll/dotfiles/issues/73), part of the
[mise bootstrap migration epic](https://github.com/david-driscoll/dotfiles/issues/61).

Question: can `[bootstrap.plugins]` / `[bootstrap.packages]` (or a mise tool backend)
replace any of the hand-maintained, duplicated package lists in this repo — VS Code
extensions (unmanaged today), krew plugins (unmanaged today), the ~70-entry `winget`
list in `setup/setup.ps1`, and the 10-line `gh extension install` list duplicated
across `install.sh` / `setup/setup-osx.sh` / `setup/setup.ps1` (+ a partial mise task)?

**Headline finding, verified against the live repos:** the two example plugin URLs
the mise docs themselves cite —
[`github.com/mise-plugins/mise-vscode-extensions`](https://github.com/mise-plugins/mise-vscode-extensions)
and [`github.com/mise-plugins/mise-krew`](https://github.com/mise-plugins/mise-krew) —
both return **HTTP 404**. Neither exists. The docs page is illustrating the syntax
with aspirational/placeholder repo names, not naming real, installable plugins. This
matters a lot for questions 1 and 2 below.

## Summary

| Plugin | Exists? | Maintained | Recommendation | Why |
| --- | --- | --- | --- | --- |
| mise-vscode-extensions | **No** — doc-cited URL 404s; no equivalent found anywhere | N/A | **Skip** | Nothing to adopt. The only real "mise + vscode" projects are IDE extensions *for using mise inside VS Code* (`hverlin/mise-vscode`), not plugins that manage VS Code's own extensions. |
| mise-krew | **No** at the cited URL; **yes** under a different name/org: [`soupglasses/mise-krew`](https://github.com/soupglasses/mise-krew) | Yes — v2.1.0, active commits into 2026-05 | **Skip for now** | Real plugin exists and is well-built, but it's a full *tool backend* (not a `[bootstrap.packages]` plugin), needs the `krew` binary already wired up, and this repo manages zero krew plugins today — no current pain to solve. |
| winget plugin | **Yes** — [`Yuzu02/mise-winget`](https://github.com/Yuzu02/mise-winget) | Barely — 3 commits, all on one day (2026-03-07), 2 stars, no follow-up activity | **Skip / build: no** | Technically real and well-designed (Lua backend, Windows-only, version-pinned), but single-day, single-maintainer, unproven at scale — and most of this repo's winget list is GUI apps, a poor fit for a shim-based tool backend. Keep the script. |
| gh-extensions plugin | **No** — no such plugin exists anywhere (checked `mise-plugins` org, GitHub-wide search) | N/A | **Adopt option (b): consolidate into the existing mise task, delete the duplicated script lines** | Building a plugin is pure yak-shaving for zero benefit over what a two-line mise task already does. The task exists today but is *incomplete* — fix that instead. |

Also checked: no `az-extensions` (Azure CLI extension) plugin exists anywhere either —
see [Other plugins scanned](#other-relevant-plugins-scanned-in-mise-plugins) below.
`mise-azure-cli` exists but only version-pins the `az` binary itself, not `az extension add`
subcommands.

---

## 1. mise-vscode-extensions

**Verified:** `curl -o /dev/null -w '%{http_code}' https://github.com/mise-plugins/mise-vscode-extensions` → `404`, confirmed twice. The repo does not exist under `mise-plugins` or (as far as a broad GitHub code/repo search can tell) under any other org. `gh api orgs/mise-plugins/repos --paginate` enumerates all 273 repos in the org — none named anything with "vscode" in it.

The [bootstrap package-plugins doc](https://mise.jdx.dev/bootstrap/packages/plugins.html) cites it as the worked example for the `[bootstrap.plugins]` table:

```toml
[bootstrap.plugins]
vscode = "https://github.com/mise-plugins/mise-vscode-extensions"

[bootstrap.packages]
"vscode:ms-python.python" = "latest"
```

That's a real, coherent *syntax* — mise genuinely supports declaring an arbitrary
plugin source and referencing it with a prefix — but the specific plugin the docs
name for VS Code extensions isn't a thing you can `mise plugin install` today.

What *does* exist, and is not the same thing:
- [`hverlin/mise-vscode`](https://github.com/hverlin/mise-vscode) (218 stars, active) — a VS Code
  *extension* that lets VS Code use mise-managed tools/tasks. It manages nothing about VS Code's
  own extension list.
- [`rgeraskin/vscode-mise`](https://github.com/rgeraskin/vscode-mise), `Mossop/vscode-mise`,
  `jbadeau/mise-vscode`, `syhol/mise-vscode` — same category, same non-answer.

**Recommend: skip.** There is nothing to adopt. Building one from scratch is possible
in principle (see the [package-plugin interface](#appendix-package-plugin-interface-verified)
below — `package_installed.lua` + `package_install.lua` wrapping `code --list-extensions` /
`code --install-extension`), and it would need to handle both `code` and `code-insiders`
binaries since this repo installs both on all three OSes — but that's greenfield plugin
authoring, not a spike-scope adoption. Worth a low-priority "build" issue if David wants
VS Code extensions declaratively managed and is willing to own a small Lua plugin; not
worth blocking the bootstrap migration on.

## 2. mise-krew

**Verified:** `github.com/mise-plugins/mise-krew` → 404, same as above. But a real,
actively maintained plugin exists at a different location:
[`soupglasses/mise-krew`](https://github.com/soupglasses/mise-krew) — MIT licensed, 15
stars, 1 fork, latest release `2.1.0` (2026-05-07), commits through 2026-05-07. Confirmed
via the [jdx/mise "Full krew support" discussion](https://github.com/jdx/mise/discussions/6690):
the maintainer (`soupglasses`) built it in response to that thread after a `jdx/mise`
contributor pointed at the vfox-backend plugin architecture; the original requester
(`ttiurani`) confirmed in the thread that v2.0.0 "works perfectly, no need to pre-install
krew anymore."

**Architecturally this is not a `[bootstrap.packages]` plugin at all** — checked its repo
tree directly (`gh api repos/soupglasses/mise-krew/git/trees/main`): its `hooks/` directory
has `backend_install.lua`, `backend_list_versions.lua`, `backend_exec_env.lua`. Per the
[package-plugin dev docs](https://mise.jdx.dev/package-plugin-development.html), a repo with
`backend_*.lua` hooks is a **tool backend**, not a package plugin (`package_installed.lua` +
`package_install.lua`) — mise explicitly keeps the two plugin kinds in separate repos. So
this is used like any other mise tool, in `[tools]`, not in `[bootstrap.packages]`:

```toml
[plugins]
krew = "https://github.com/soupglasses/mise-krew"

[tools]
"krew:tree" = "latest"       # a specific kubectl-krew plugin, version-pinned
```

That's actually a **better** deal than the bootstrap-packages story documented for
question 5 (real version pinning, real shims, normal `mise uninstall`/`mise prune`
lifecycle) — but it only manages *krew plugins*, not the `krew` binary itself. This repo
doesn't install `krew` today at all. The mise registry's own `krew` shortname
(`gh api repos/mise-plugins/registry/contents/plugins/krew` → `repository =
https://github.com/bjw-s/asdf-krew.git`) points to a **third, unrelated, archived**
plugin that installs the `krew` binary as a normal versioned tool — so `mise use krew` out
of the box gets you the archived `bjw-s/asdf-krew`, not `soupglasses/mise-krew`. Getting
full krew-plugin management here would mean stacking two plugins from two different
maintainers, one of them archived.

**Recommend: skip for now.** The repo manages six kubectl-adjacent tools (`kubectl`,
`helm`, `flux`, `kustomize`, `stern`, `talosctl`) but zero krew plugins — there's no
existing drift to fix, no duplicated list to consolidate, nothing broken. Adopting a
niche community plugin (plus a second, archived one, just to get the `krew` binary)
for a capability nobody's using yet doesn't match "reversible over clever." If David
starts actually installing `kubectl` plugins by hand, `soupglasses/mise-krew` is the
right tool to reach for then — worth a note-for-later, not a follow-up issue today.

## 3. A winget plugin

**Verified it exists:** [`Yuzu02/mise-winget`](https://github.com/Yuzu02/mise-winget) — MIT,
2 stars, 0 open issues. `gh api repos/Yuzu02/mise-winget/commits` shows exactly 3 commits,
all dated 2026-03-07 (initial commit → "Add mise backend plugin for winget" → a same-day
bugfix for `hooks/pre_install.lua`), nothing since. Description: "generated from a
community template," has CI workflows, but is effectively a single afternoon's work with
no real-world mileage.

**Interface, verified from its README:** it's a **backend plugin** (`backend_list_versions.lua`,
`backend_install.lua`, `backend_exec_env.lua` — same family as `mise-krew`, confirming
package-plugin dev docs' `os = ["macos","linux","windows"]` field is real and Windows genuinely
is a supported platform for mise's Lua plugin runtime). Used in `[tools]`:

```toml
"winget:Hashicorp.Terraform" = "latest"
```

It parses `winget show --id <id> --versions` for version listing, shells out to
`winget install` with `--silent --accept-package-agreements`, and — notably — falls
back to generating `.cmd` shims for installers that ignore mise's requested install
location (common for MSI/NSIS-based Windows installers). It explicitly detects
non-Windows and errors with a clear message rather than silently no-op'ing.

**Would it replace the scripted list?** Only partially, and this is the crux: this
repo's `setup/setup.ps1` `$wingetPrograms` array (`grep -c` confirms 70 entries) is
almost entirely **GUI applications** — 1Password, VS Code + Insiders, Office, four
browsers, Slack, Teams, Docker Desktop, JetBrains Toolbox, PowerToys, NirSoft utilities,
Notepad++, TortoiseGit, GitHub Desktop, Fiddler, LINQPad — not CLI tools with predictable
`bin/` layouts. The epic's own plan already moves every CLI tool in that list (`kubectl`,
`helm`, `terraform`, `starship`, `zoxide`, `sops`, `flux`, `age`, `jq`, …) to native
cross-platform `mise [tools]` entries directly, with no winget backend needed at all —
so mise-winget's actual addressable slice of this repo's winget list is small (maybe
`gh`/`GitHub.cli`, `NuGet`, `npiperelay` — things with a real single-binary shim story),
and its shim-fallback path for GUI installers is exactly the least-proven part of a
3-commit plugin.

**Effort estimate to build our own instead:** the interface is well-documented (Lua,
three hooks, `os` gating in `metadata.lua`, `requires` for host binaries in
`mise.plugin.toml`) and `mise-winget`'s source is a usable reference implementation to
fork or read — so writing a narrower one (just the handful of CLI-shaped packages, no
GUI shim fallback) is maybe a day of work, not a big lift. But there's no reason to:
nothing in this repo's winget list needs it once the CLI tools move to native `[tools]`
entries, per the epic's own plan.

**Recommend: skip, keep the script.** Windows still has no first-party winget backend
in mise itself (confirmed by the same docs page: only `apk:`, `apt:`, `dnf:`, `pacman:`,
`brew:`, `flatpak:`, `mas:` are built into `[bootstrap.packages]` — no `winget:`), and the
one community attempt at filling that gap is too immature to bet a GUI-app install list
on. `setup/setup.ps1` staying a hand-maintained script for the app tier is the reversible
choice; revisit only if `mise-winget` gets real adoption/maintenance history, or if David
wants to pilot it narrowly on the handful of CLI-only entries.

## 4. A gh-extensions plugin

**Verified no plugin exists:** searched `mise-plugins` org (273 repos, none matching
`gh-ext*`), GitHub-wide repo search for `"gh extensions" mise` and `gh-extension mise`,
and the mise-plugins `registry` shortname list — nothing.

Three options, as asked:

**(a) Write a package plugin.** Feasible per the
[package-plugin dev docs](https://mise.jdx.dev/package-plugin-development.html):
`package_installed.lua` would shell out to `gh extension list` and diff against the
declared package IDs; `package_install.lua` would call `gh extension install
<owner>/<repo>`. Maybe half a day of work including testing. But it buys nothing over
option (b) below except being invocable as `"gh:owner/repo" = "latest"` syntax inside
`[bootstrap.packages]` instead of a task — and it inherits the **no-removal/no-pruning**
constraint (see §5), which the existing task doesn't have to (a task is just a shell
command; you control its logic completely, including diffing away extensions no longer
listed if you want that later).

**(b) Keep the existing mise task as the single source of truth, delete the duplicated
script lines.** Verified the current state of `.config/mise.toml`: there already is a
`[tasks.gh-extensions]` task, wired into `postinstall`:

```toml
[hooks]
postinstall = [{ task = "gh-extensions" }, { task = "crew:update" }]

[tasks.gh-mcp]
run = "gh extensions install shuymn/gh-mcp"

[tasks.gh-extensions]
run.tasks = ["gh-mcp"]
```

This is exactly the "partially duplicated again as a mise task" the issue description
flagged — it only installs **one** of the ten extensions (`shuymn/gh-mcp`, and note the
task itself has a typo: `gh extensions install` should be `gh extension install`,
singular). The other nine (`davidraviv/gh-clean-branches`, `github/gh-codeql`,
`mislav/gh-contrib`, `github/gh-copilot`, `dlvhdr/gh-dash`, `meiji163/gh-notify`,
`seachicken/gh-poi`, `vilmibm/gh-screensaver`, `AdamVig/gh-watch`) only live in the three
duplicated scripts. Expanding this task to the full list and deleting the ten lines from
`install.sh`, `setup/setup-osx.sh`, and `setup/setup.ps1` collapses a 3× duplication down
to one place, for free, using a mechanism the repo has already half-adopted.

One real wrinkle, checked against `gh extension install --help`: it does **not** silently
no-op on a second install — the `--force` flag is documented as "Force upgrade extension,
**or ignore if latest already installed**," which only makes sense if the default
(no `--force`) behavior errors or exits non-zero when the extension is already present.
Today the three scripts get away with this because none of them run with `set -e` (checked
`head -5` of each — no `set -e`/`set -euo pipefail` at the top of `install.sh` or
`setup-osx.sh`), so a failing `gh extension install` line is silently swallowed and the
next line still runs. A mise task's `run` array does **not** have that same
forgiving default — a non-zero exit from a shell command in a task will fail the task
(and the `postinstall` hook chain that depends on it) on every `mise install` after the
first. **The follow-up issue must have each install line pass `--force` (or check `gh
extension list` first)** or this "consolidation" turns a currently-harmless duplicate
list into a hard `mise install` failure on every subsequent run.

**(c) Status quo.** Rejected — this is the textbook case the epic exists to fix:
identical content in four places (three scripts + one incomplete task) that will drift
the moment someone adds an eleventh extension to only one of them.

**Recommend: (b).** Fix the typo, complete the extension list, add `--force` (or an
existence check) to each line, delete the ten lines from all three scripts. No new
plugin, no new dependency, removes a real duplication the epic flagged, and is safely
scoped to a single follow-up issue.

## 5. The no-pruning constraint, per recommendation

Documented directly on the bootstrap package-plugins page: *"Package removal and pruning
are not supported in the first version… Removing config entries does not uninstall
packages."* This is specific to the `[bootstrap.packages]` / `[bootstrap.plugins]`
mechanism (package-plugin hooks: `package_installed.lua` / `package_install.lua`), not to
mise generally.

Since nothing in questions 1–3 is being adopted, the constraint doesn't bite today. For
completeness, here's how it would land on each thing evaluated:

- **VS Code extensions (skipped, nothing to adopt):** would matter a lot if built later —
  removing `"vscode:some.extension" = "latest"` from config would leave the extension
  installed in VS Code forever. Extensions are cheap and low-risk to leave installed, so
  this constraint would be *acceptable* for this package type if the plugin is ever built.
- **krew plugins (skipped):** N/A for the same reason, but worth noting for later:
  `soupglasses/mise-krew` is a **tool backend**, not a bootstrap package plugin, so it
  does *not* inherit this constraint — normal `mise uninstall`/`mise prune` apply. If
  krew plugin management is adopted down the line, removal actually works normally.
- **winget (skipped):** N/A currently. If ever adopted, same tool-backend distinction
  applies — `mise-winget` is a backend plugin too, so `mise uninstall winget:X` should
  behave like uninstalling any other mise tool version, not like the pruning-free
  `[bootstrap.packages]` path. This wasn't independently verified by testing (no install
  was performed, per this task's safety rules), so treat it as *inferred from the plugin's
  architecture*, not confirmed.
- **gh-extensions (recommended: keep as a mise task):** entirely outside this constraint
  — a `[tasks]` entry is just a shell command you own. If David later wants "remove an
  extension from the list and have it actually uninstalled," that's straightforward to
  add to the task (`gh extension list` diffed against the declared set, `gh extension
  remove` for anything extra) — something no package-plugin approach would give for free
  anyway.

## Other relevant plugins scanned (`mise-plugins` org)

Specifically hunted for anything matching this repo's stack per the epic's suggestion
(dotnet tools, npm globals, Azure CLI extensions):

- **Azure CLI extensions (`az extension add azure-devops`, `az extension add
  interactive`, duplicated in `install.sh`, `setup/setup-osx.sh`, `setup/setup.ps1`, and
  `setup/setup.sh` — four places, verified by grep):** no `az-extensions`-style plugin
  exists anywhere (checked `mise-plugins` org repo names/descriptions, GitHub-wide repo
  search). `mise-plugins/mise-azure-cli` exists but only version-pins the `az` binary
  itself (an asdf-style tool plugin), unrelated to `az extension add`. **This is the same
  shape of problem as gh-extensions** — a short, duplicated, idempotency-sensitive list
  with no plugin ecosystem answer. Same fix applies: a small mise task, not a plugin.
  Flagging as a good candidate for a follow-up issue alongside the gh-extensions one.
- Nothing else in the 273-repo `mise-plugins` org (`gh api orgs/mise-plugins/repos
  --paginate`, full listing) matches this repo's stack in a way that isn't already
  covered by an existing native `[tools]` entry (dotnet, node, uv, etc. are all
  first-class mise tools already, not plugin territory).

## Recommended follow-up issues

1. **Fix and complete the `gh-extensions` mise task; delete the duplicated script
   lines.** Scope: fix the `gh extensions install` → `gh extension install` typo in
   `.config/mise.toml`, add the nine missing extensions to `[tasks.gh-extensions]` (or a
   set of `gh-*` sub-tasks like the existing `gh-mcp` one), make each install line
   tolerant of "already installed" (via `--force` or a pre-check), then remove the ten
   `gh extension install` lines from `install.sh`, `setup/setup-osx.sh`, and
   `setup/setup.ps1`.
2. **Do the same for `az extension add azure-devops` / `az extension add interactive`.**
   Scope: add a small mise task (or fold into an existing postinstall task) that runs
   both `az extension add` calls idempotently (`az extension add` already no-ops if the
   extension is present — worth double-checking, but this is lower-risk than `gh
   extension install`), then delete the duplicated lines from `install.sh`,
   `setup/setup-osx.sh`, `setup/setup.ps1`, and `setup/setup.sh` (four places).

No follow-up issues for VS Code extensions, krew, or winget — all three are "skip," not
"adopt," per the reasoning above. If priorities change:
- VS Code extensions would need a **build-from-scratch** package plugin (no existing one
  to adopt) — worth a low-priority issue only if David actively wants this managed.
- krew plugin management has a real, working answer (`soupglasses/mise-krew`) to reach
  for the day this repo actually installs kubectl plugins by hand more than once.
- winget has a real but immature plugin (`Yuzu02/mise-winget`) worth revisiting if it
  gains maintenance history, or piloting narrowly on 2-3 CLI-only packages if David wants
  to poke at it now.

## Appendix: package-plugin interface (verified)

From [`mise.jdx.dev/package-plugin-development.html`](https://mise.jdx.dev/package-plugin-development.html)
and cross-checked against real plugin source (`soupglasses/mise-krew`, `Yuzu02/mise-winget`):

- Package plugins (`[bootstrap.packages]`) are **Lua-based**, with a
  `metadata.lua` + `mise.plugin.toml` + `hooks/` layout:
  - `hooks/package_installed.lua` (required) — fast, side-effect-free installed/missing check
  - `hooks/package_install.lua` (required) — installs, respects `ctx.dry_run` / `ctx.update`
  - `hooks/package_upgrade.lua` (optional) — falls back to `package_install` if absent
- **Tool backends** (used via `[tools]`, e.g. `mise-krew`, `mise-winget`) are a
  *different* Lua hook set — `hooks/backend_list_versions.lua`,
  `hooks/backend_install.lua`, `hooks/backend_exec_env.lua` (optional) — and mise
  requires the two kinds to live in separate repos; a repo can't be both.
- `os = ["macos", "linux", "windows"]` in `metadata.lua`/`mise.plugin.toml` is optional
  and defaults to all platforms — **Windows is a genuinely supported platform for Lua
  plugins**, confirmed in practice by `mise-winget`, which runs its Lua hooks natively on
  Windows (no WSL/git-bash required) and calls `winget.exe` directly.
- `requires` in `mise.plugin.toml` declares host binaries the hooks invoke (e.g. `code`,
  `helm`, `kubectl`, `gh`, `winget`).
- Bootstrap order, quoted from the docs: *"mise bootstrap installs declared package
  plugins first, applies built-in package managers, installs `[tools]`, then applies
  plugin managers."* This lets package-plugin hooks assume host binaries provisioned by
  the same config's `[tools]` are already on `PATH`.

## What could not be verified

- Whether `gh extension install <owner>/<repo>` on an already-installed extension
  actually exits non-zero (inferred from the `--force` flag's documented purpose, not
  from running it — running installs is out of scope for this research task per the
  hard safety rules).
- Whether `mise-winget`'s shim-fallback path actually works end-to-end for any of this
  repo's specific GUI-app winget IDs — no Windows machine was used to test it, consistent
  with "do not install software" for this spike.
- Whether `az extension add` is itself idempotent when re-run (widely believed to be, but
  not independently confirmed here).
