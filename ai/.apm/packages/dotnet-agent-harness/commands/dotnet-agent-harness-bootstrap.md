---
name: dotnet-agent-harness-bootstrap
description:
  'Initialize dotnet-agent-harness APM package for a project — installs MCP servers, deploys agents,
  compiles platform-specific files, and optionally installs the slopwatch .NET tool.'
targets: ['*']
portability: universal
flattening-risk: low
simulated: true
version: '0.0.1'
author: 'dotnet-agent-harness'
codexcli:
  sandbox_mode: 'read-only'
---

# /dotnet-agent-harness:bootstrap

Initialize the dotnet-agent-harness toolkit for a project using APM.

## Execution Contract

```bash
# In the project's ai/ directory (or wherever apm.yml lives):
apm install
apm compile
```

## What It Does

1. `apm install` resolves and installs all package dependencies declared in `apm.yml`, including
   MCP server configurations and local packages such as `dotnet-agent-harness`.
2. `apm compile` generates platform-specific output files:
   - `.claude/` — agents, skills, hooks, settings for Claude Code
   - `.github/instructions/` — Copilot instruction files
   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` — root agent context files
   - `.cursor/`, `.windsurf/`, `.opencode/`, `.codex/`, `.gemini/` — other runtimes

## MCP Servers configured by this package

| Server | Type | Purpose |
|--------|------|---------|
| serena | stdio (`uvx oraios/serena`) | Semantic code navigation and refactoring |
| microsoftdocs-mcp | http | Official Microsoft/Azure documentation |

## Optional: slopwatch

Install [slopwatch](https://github.com/rudironsoni/slopwatch) as a local .NET tool to enable
post-edit code quality monitoring:

```bash
dotnet tool install slopwatch.cmd --create-manifest-if-needed
```

Once installed, the `slopwatch analyze -d . --hook` post-edit hook activates automatically.

## Notes

- Run `apm install --dry-run` first to preview changes without writing files.
- Run `apm compile --dry-run` to preview which files will be generated and where.
- To update the package content, edit files under `ai/.apm/packages/dotnet-agent-harness/`
  and re-run `apm compile`.
