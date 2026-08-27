---
name: neo4j-modeling-skill
source: https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-modeling-skill
installed_at: 2026-07-15T14:46:54-04:00
installed_for: sakai
---

# neo4j-modeling-skill (vendored pointer)

Design, review, and refactor the graph data model that mirrors a codebase. Covers choosing
node labels vs relationship types vs properties, detecting anti-patterns (generic labels,
supernodes, missing constraints), designing intermediate nodes for n-ary relationships, and
enforcing schema with constraints/indexes.

**Full skill source:** https://github.com/neo4j-contrib/neo4j-skills/blob/main/neo4j-modeling-skill

**When to use:** When Sakai is deciding how CodeToNeo4j's output (projects, files, symbols,
relationships) should be modeled or extended in Neo4j, or when reviewing whether the
existing code-graph schema still serves the team's query needs efficiently.

**Key defaults from the skill (see source for full detail):**
- List 5+ real queries the model must answer before designing/changing it
- Nodes = entities with identity (e.g. `:File`, `:Symbol`, `:Project`); relationships =
  directed connections (e.g. `:REFERENCES`, `:DEFINED_IN`, `:DEPENDS_ON`)
- No generic labels (`:Entity`, `:Node`) or generic relationship types (`:RELATED_TO`)
- Every node type used in `MERGE` needs a uniqueness constraint on its key property
- Inspect the live schema (`db.schema.visualization()`, `apoc.meta.schema()`) before
  proposing any change to an existing code graph

If the full skill content is needed for a complex modeling decision, fetch it live from the
source URL above rather than relying solely on this pointer stub.
