### 2026-07-26T20-14-51: Kaylee cast as Dotfiles / Shell Engineer; Firefly locked in as the crew's casting universe
**By:** Crew (Coordinator)
**What:** Kaylee cast as Dotfiles / Shell Engineer; Firefly locked in as the crew's casting universe
**References:** kaylee, .crew/casting/registry.json, .crew/team.md, .crew/routing.md
**Why:** **What:** Kaylee joins the crew as Dotfiles / Shell Engineer — the first domain member
on this team. Firefly is recorded as the active casting universe for the `dotfiles`
assignment (`dotfiles-2026-07-26`), locking it in for all future members.

**Scope of the role:** zsh configuration, the mise toolchain (`.config/mise.toml`,
`.config/mise.lock`, tasks/hooks/env), symlink and bootstrap scripts (`install.sh`,
`setup/`), `.config/` contents, and shell scripting.

**Why Firefly:** requested by the user; it is on the casting allowlist with capacity 10,
leaving headroom for ~9 further members before overflow handling applies.

**State-ownership note discovered while adding this member:** the coordinator protocol in
`.github/agents/crew.agent.md` lists `.crew/casting/*.json` among the runtime-managed paths
that must not be written with file tools under a non-local backend. The runtime disagrees —
`crew_state_write` to a `casting/` key is rejected with "Static config such as config.json,
team.md, routing.md, charters, templates, and skills must not be changed with state tools",
and this repo's `.gitignore` explicitly says `.crew/casting/* is identity and MUST be
committed to main, not ignored`. Casting state is therefore disk-owned and committed;
decisions, agent history, and logs remain runtime-owned on the `crew-state` branch.
Treat the protocol's HARD RULE list as over-broad on this one path.

**Roster consequence:** Kaylee is currently the only domain member, so reviewer-rejection
lockout cannot be satisfied internally. If her work is rejected, the Coordinator must
escalate and cast a new specialist rather than let her self-revise. Recorded as rule 8 in
routing.md.