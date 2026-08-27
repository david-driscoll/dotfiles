---
name: neo4j-getting-started-skill
source: https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-getting-started-skill
installed_at: 2026-07-15T14:46:54-04:00
installed_for: sakai
---

# neo4j-getting-started-skill (vendored pointer)

Zero-to-running-app orchestration: prerequisites → context → provision → model → load →
explore → query → build. Use for first-time Neo4j setup (local Docker or Aura) before
CodeToNeo4j has anything to write into.

**Full skill source:** https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-getting-started-skill

**When to use:** When a repository has no Neo4j instance yet and Sakai needs to provision
one (local Docker or Aura) before running `codetoneo4j` against it for the first time.

**Key defaults from the skill (see source for full detail):**
- Writes progress to `progress.md` in the working directory for resumability
- Organizes generated artifacts into `schema/`, `data/`, `queries/`, `scripts/` folders
- Time budget: ≤15 min autonomous, ≤90 min human-in-the-loop

If the full skill content is needed, fetch it live from the source URL above rather than
relying solely on this pointer stub.
