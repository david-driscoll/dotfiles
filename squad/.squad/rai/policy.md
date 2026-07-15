# RAI Policy

## Check Categories

### 🔴 Critical (cannot be disabled)
- Credential/secret exposure in code or config
- Prompt injection vulnerabilities
- PII exposure (emails, keys, tokens, passwords)
- Generation of harmful or dangerous content

### 🟡 Advisory (can be disabled with justification)
- Bias indicators in variable/function naming
- Exclusionary language in user-facing content
- Overly broad data collection patterns
- Missing rate limiting on public APIs

## Terminology Standards
- Use inclusive language in all user-facing strings
- Prefer "allowlist/denylist" over legacy terms
- Avoid gendered pronouns in generic contexts

## Opt-Out
- Temporary opt-down of advisory checks supported (auto re-enables after 30 days)
- Log justification to audit trail
- Critical checks cannot be opted out

## Audit Trail
- Location: `.squad/rai/audit-trail.md`
- Format: date | agent | verdict | finding summary
- Redacted — never contains raw secrets or harmful content
