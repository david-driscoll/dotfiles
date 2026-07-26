# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Shell & zsh config | Kaylee | `.zshrc`, oh-my-zsh, starship prompt, aliases, `PATH`, shell startup order and speed |
| Toolchain & mise | Kaylee | `.config/mise.toml`, `mise.lock`, tool version pins, `[tasks]`, `[hooks]`, `[env]` |
| Symlinks & bootstrap | Kaylee | `install.sh`, `setup/setup.sh`, `setup/setup-osx.sh`, Brewfile, linking repo files into `$HOME` |
| `.config/` contents | Kaylee | Adding, moving, or reorganizing app config under `.config/` |
| Shell scripting | Kaylee | Writing and fixing `*.sh`, macOS/Linux portability, quoting, `set -euo pipefail` |
| Config review | Kaylee | Review shell/toolchain changes for correctness and portability |
| Session logging | Scribe | Automatic — never needs routing |
| RAI review | Rai | Content safety, credential detection, ethical review |
| Verification / devil's advocate | Fact Checker | Verify claims and versions, challenge a plan before it ships |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `crew` | Triage: analyze issue, assign `crew:{member}` label | Crew (Coordinator) — no Lead cast yet |
| `crew:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `crew` label, the **Coordinator** triages it — analyzing content, assigning the right `crew:{member}` label, and commenting with triage notes. Once a Lead is cast, triage moves to the Lead.
2. When a `crew:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `crew` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `crew:{member}` label is applied to an issue, route to that member. The Coordinator handles all `crew` (base label) triage until a Lead is cast.
8. **Single-member reviewer lockout.** Kaylee is currently the only domain member. If her work is rejected by a reviewer, strict lockout applies — she may NOT produce the revision. With no other eligible domain agent on the roster, the Coordinator must escalate to the user and cast a new specialist rather than re-admitting the locked-out author.
