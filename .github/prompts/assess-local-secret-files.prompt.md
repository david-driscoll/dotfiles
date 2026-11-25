---
description: 'Safely inventory common local credential-file paths without exposing file contents or changing files.'
name: 'Assess local secret files'
agent: agent
argument-hint: 'Optional additional file paths to assess'
---

# Assess local secret files safely

## Mission

Produce a read-only, heuristic inventory of common local credential/configuration files. Do not migrate, edit, copy, print, or otherwise expose any file contents or secret values.

## Scope and preconditions

- Use [the fnox assessment script](../../.config/fnox/scripts/assess-local-secret-files.ps1). It checks bounded common paths and optional exact paths without recursion.
- Run it with PowerShell 7 (`pwsh`) when available. If unavailable, explain that the script was not run; do not install dependencies or substitute a scanner that prints content.
- Treat the script's classes as indicators only. A reference or auth-like setting may be a false positive, and no finding does not prove the file is secret-free.
- Do not inspect credential file contents with other tools or include values, snippets, lines, tokens, usernames, or raw command output containing file contents in chat, reports, or tool arguments. The approved script performs bounded in-memory pattern checks on regular text candidates; it never emits their contents.
- The script skips recognized environment-file, private-key, and age-identity paths without reading them. Do not supply other private-key paths as explicit candidates.
- Do not run `fnox files write`, `fnox set --file`, migration commands, permission changes, hook installation, or any other write action during this assessment.

## Inputs

Assess default candidates. If the user supplies additional paths, pass them literally through `-Path`; do not expand globs or search parent/child directories.

```powershell
$scriptPath = Join-Path (Join-Path '.config' 'fnox') (Join-Path 'scripts' 'assess-local-secret-files.ps1')
pwsh -NoProfile -File $scriptPath -Json
```

For explicit paths, append `-Path 'path-one','path-two'` to the command. Do not pass secret values as arguments.

## Workflow

1. Confirm the script exists in the current repository and that the assessment is limited to the intended machine and paths.
2. Run the script once for default candidates, adding only user-requested explicit paths. Do not broaden scope through recursion or directory scans.
3. Keep the output to the script's safe metadata: path, status, and classification. Do not run a second command that prints the file or matched text.
4. Summarize each candidate as present, missing, skipped, or unreadable and report only its heuristic classes. Explain that `credential-reference` can be a file/certificate/external-auth reference, while `potential-embedded-auth-indicator` is not proof of an exposed credential.
5. Compare the results with the existing fnox setup only at the reference level. Do not assume a candidate should be migrated or make changes to fnox configuration.
6. If the user later wants a migration, describe the proposed paths and target behavior first. **Require explicit user approval before any migration, file write, permission change, or hook installation.** If approval is not explicit, stop after reporting.

## Output expectations

Return a concise table with `Path`, `Status`, and `Heuristic classification`. Include no excerpts, detected values, or file contents. State the bounded inspection limits and heuristic caveat.

## Quality assurance

- Confirm no files were written or modified.
- Confirm every reported field came from the script's metadata output.
- Do not state that a file is safe solely because the script reported no known indicators.
