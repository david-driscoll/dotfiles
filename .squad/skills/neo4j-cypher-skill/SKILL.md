---
name: neo4j-cypher-skill
source: https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-cypher-skill
installed_at: 2026-07-15T14:46:54-04:00
installed_for: sakai
---

# neo4j-cypher-skill (vendored pointer)

Write, optimize, and debug Cypher queries against the code-graph database. Covers CYPHER 25
syntax, query planning, indexes, and common patterns (MATCH, MERGE, CREATE, WITH, RETURN,
CALL, UNWIND, FOREACH, LOAD CSV, vector/fulltext SEARCH, subqueries, batch writes).

**Full skill source:** https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-cypher-skill

**When to use:** Any time a team member (or Sakai on their behalf) needs to query the
code-graph mirrored from a repository by CodeToNeo4j — e.g. "find all callers of X",
"show the dependency chain for module Y", "which files reference symbol Z".

**Key defaults from the skill (see source for full detail):**
- `CYPHER 25` as the first token in every query
- Inspect schema first — for the code graph, prefer a cached `<repo>-schema.json` if Sakai
  has generated one, otherwise run `CALL db.schema.visualization()` live
- `MERGE` only on constrained/unique keys
- `LIMIT 25` default on exploratory reads; push `LIMIT` before high-cardinality traversals
- Label-free `MATCH (n)` is forbidden unless bound
- Style: PascalCase labels, SCREAMING_SNAKE_CASE relationship types, camelCase properties

If the full skill content is needed for a complex query, fetch it live from the source URL
above rather than relying solely on this pointer stub.
