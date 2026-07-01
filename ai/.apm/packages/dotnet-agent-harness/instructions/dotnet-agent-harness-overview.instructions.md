---
root: true
targets: ['agentsmd', 'claudecode', 'copilot', 'geminicli', 'codexcli', 'factorydroid', 'antigravity', 'opencode']
description: 'dotnet-agent-harness: Comprehensive .NET development skills for all AI agents'
globs: ['**/*']
antigravity:
  trigger: always_on
---

# dotnet-agent-harness

Comprehensive .NET development guidance for modern C#, ASP.NET Core, MAUI, Blazor, and cloud-native apps.

## APM-first architecture

- `ai/.apm/packages/dotnet-agent-harness/` is the source of truth for this toolkit's agent content.
  Edit skills, agents, commands, hooks, and instructions there.
- Platform output files (AGENTS.md, `.claude/`, `.github/`, etc.) are build artifacts produced by
  `apm compile`. Regenerate them instead of editing by hand.
- After editing package content, run `apm install` (to sync MCP and local deps) then `apm compile`
  (to regenerate platform files).

## Surface ownership

- `instructions/`: always-on repository guidance, routing, and cross-cutting constraints.
- `skills/`: reusable domain knowledge and implementation standards.
- `agents/`: named specialists with bounded scope and tool budgets.
- `commands/`: user-invocable entry points that prefer the local runtime over hand-written procedures.
- `hooks/`: ambient reminders and lightweight automation; keep them advisory and portable.

## Working contract

- Keep skill and agent frontmatter strictly APM-compliant and add target-specific blocks only for
  real runtime differences.
- Keep commands deterministic, keep hooks advisory.
- Validate compiled output with `apm compile --dry-run`; apply with `apm compile`.
- Do not hand-edit generated target directories to patch a platform quirk — fix the source and recompile.

## Platform model

This toolkit provides:

- 151 skills
- 18 specialist agents/subagents
- instructions, commands, hooks, and MCP config

Compatible targets include:

- Claude Code
- GitHub Copilot CLI
- OpenCode
- Codex CLI
- Gemini CLI

Target support is intentionally asymmetric. Author the shared behavior once, then add target-specific
blocks only where the runtime surface actually differs.

## Quick Start

Add this package as a local APM dependency in your project's `apm.yml`:

```yaml
dependencies:
  local:
    - path/to/ai/.apm/packages/dotnet-agent-harness
```

Then run `apm install` and `apm compile` to deploy.

## OpenCode behavior

- Tab cycles **primary** agents only.
- `@mention` invokes subagents.
- `dotnet-architect` is configured as a primary OpenCode agent in this toolkit so it can appear in Tab rotation.

## Hook coverage

- Claude Code receives .NET session routing, post-edit Roslyn analysis, dotnet format, slopwatch
  advisories, inline error recovery, and a per-prompt routing reminder.
- Gemini CLI and OpenCode inherit the shared .NET session routing hooks.

## Troubleshooting

If a skill or agent is not being invoked, check that `apm compile` has been run and that the generated
platform files are up to date.

Use the `dotnet-agent-harness:search` and `dotnet-agent-harness:recommend` commands to explore
available skills and agents rather than scanning package directories manually.

