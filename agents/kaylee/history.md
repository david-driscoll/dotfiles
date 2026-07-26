# Project Context

- **Owner:** David Driscoll
- **Project:** dotfiles — personal machine configuration symlinked into `$HOME`
- **Stack:** zsh, mise (toolchain + tasks), Homebrew/Brewfile, shell scripts, starship
- **Role:** Dotfiles / Shell Engineer
- **Created:** 2026-07-26T16:12:00-04:00

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

📌 Joined the team (2026-07-26T16:12:00-04:00) as Dotfiles / Shell Engineer — owns zsh config, the mise
toolchain, symlinks, `.config/` contents, and shell scripting in this repo.

- **Two distinct mise configs — do not confuse them.** `mise.config.toml` at the repo root is
  the *global* user config, symlinked to `~/.config/mise/config.toml` by the bootstrap scripts;
  it is minimal (`experimental = true`, one `uv` pin). `.config/mise.toml` is *this repo's*
  project config and holds the real toolchain, `[tasks]`, `[hooks]`, and `[env]`.
- **The repo-local mise config was just migrated.** `.mise.toml` (root) and `mise/config.toml`
  were deleted in favour of `.config/mise.toml` + `.config/mise.lock`. Verify any path
  assumption against the current tree rather than older docs or scripts.
- **`uv` is pinned in two places** — both `mise.config.toml` and `.config/mise.toml` pin `uv`
  (0.11.32 at time of writing). A version bump has to touch both or they silently diverge.
- **Bootstrap symlinks are triplicated.** `install.sh`, `setup/setup.sh`, and
  `setup/setup-osx.sh` each contain their own `rm` + `ln -s` blocks for the same targets
  (mise global config, `.bashrc`, `.zshrc`). A symlink change usually needs to land in all three.
- **mise owns the `crew` CLI.** The `crew:install` task clones Blacklite/crew to `CREW_SRC`,
  builds it, and drops a single symlink at `CREW_BIN/crew`, which reaches PATH via `_.path`.
  There is no global `npm link` — do not "fix" a missing `crew` by installing it globally.
- **Editing a repo file edits the live machine.** Most of these files are symlinked into
  `$HOME`, so a change to `.zshrc` here takes effect in the next shell immediately.
