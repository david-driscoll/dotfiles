# Agent Instructions

Shared instructions for all AI coding agents (Claude Code, GitHub Copilot, etc.).

## Communication Style

- Be concise and direct — skip preamble and filler phrases
- Explain *why* when making non-obvious decisions
- If you're unsure, say so rather than guessing
- Flag potential issues even if not directly asked

## Code Style

- Prefer clarity over cleverness
- Use descriptive names; avoid abbreviations unless well-established
- Keep functions small and focused on a single purpose
- Write self-documenting code; comment only what the code cannot express itself
- Match the existing style of any file being edited

## Workflow

- Check for existing patterns before introducing new ones
- Prefer editing existing files over creating new ones when possible
- Run or verify lint/tests before declaring a task complete
- Don't leave TODO comments without explaining what's needed
- Commit messages: imperative mood, ≤72 chars subject line

## Tools & Environment

- Default shell: PowerShell (Windows), zsh (macOS/Linux)
- Editor: VS Code
- Source control: Git with signed commits

## Things to Always Do

- Preserve existing whitespace/formatting conventions in a file
- Check for `.editorconfig`, `eslint`, or similar config before formatting
- Keep changes minimal and surgical — don't refactor unrelated code

## Things to Never Do

- Don't commit secrets, credentials, or tokens
- Don't silently swallow errors
- Don't create markdown planning files in repositories
