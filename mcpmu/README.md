# mcpmu — MCP Server Manager Configuration

This directory contains the dotfiles configuration for [`Bigsy/mcpmu`](https://github.com/Bigsy/mcpmu), a multiplexing Model Context Protocol (MCP) server manager.

## Architecture & Integration

- **Tool Management (`mise`)**:
  - Installed via mise Go toolchain: `go:github.com/Bigsy/mcpmu/cmd/mcpmu@0.1.33`.
  - Declared in `.config/mise/config.toml` under `[tools]`.
- **Dotfiles Symlinks**:
  - `config.json` is mapped to `~/.config/mcpmu/config.json`.
  - On Windows, `setup/setup.ps1` maintains hardlinks on NTFS to ensure zero drift.
- **Secrets Management (`fnox` + `age`)**:
  - Secrets and tokens required by MCP servers are kept out of `config.json` and passed via environment variables.
  - Environment variables are defined and encrypted in `fnox.toml` using `fnox` with native `age` encryption.
  - Encryption recipients are configured in `fnox.toml` using age public keys.
  - Fnox automatically loads secrets on shell activation (`fnox activate`) or per-command via `fnox exec`.
- **AI Agent Skill**:
  - The configuration skill is tracked in `.github/skills/mcpmu/SKILL.md` and `.claude/skills/mcpmu/SKILL.md`.
  - Installed across all detected AI agents (Claude Code, Codex CLI, Cursor, etc.) via `mcpmu skill install`.

## Managing Secrets

To view, edit, or set secret environment variables:

```bash
# View a secret
fnox get MCPMU_SERVE_TOKEN

# Set or update a secret
fnox set MCPMU_SERVE_TOKEN "my-secret-token"

# List configured secrets
fnox list

# Edit fnox configuration and secrets directly
fnox edit
```

Referencing secrets in `mcpmu`:
- Command line env: `mcpmu add my-server --env API_KEY=MY_SECRET -- ./server`
- HTTP bearer token env: `mcpmu add figma https://mcp.figma.com/mcp --bearer-env FIGMA_TOKEN`
- HTTP header env: `mcpmu add searxng https://example.com/mcp --env-header "CF-Access-Client-Secret: CF_SECRET"`

## CLI Usage

```bash
# Check status and health
mcpmu status
mcpmu doctor

# List configured servers
mcpmu list

# Add a stdio server
mcpmu add context7 -- npx -y @upstash/context7-mcp

# Run terminal UI
mcpmu tui

# Register with Claude Code
claude mcp add mcpmu -- mcpmu serve --stdio
```
