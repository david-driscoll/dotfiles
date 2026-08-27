# Routing

## Rules

| Signal | Agent |
|--------|-------|
| Architecture, cross-cutting design, code review spanning multiple domains | Holden |
| Modern C#/.NET 10, Blazor, xUnit, TUnit, Aspire AppHosts | Naomi |
| .NET 11 preview, C# 14+ language features, BCL/runtime changes | Miller |
| MSBuild, `.props`/`.targets`, project SDK, NuGet package authoring/publishing | Amos |
| PowerShell scripts, shell automation, dotfiles management, cross-platform scripting | Alex |
| Git branching, PR workflows, GitHub Actions, CI/CD on GitHub, repo hygiene | Bobbie |
| Azure Pipelines (YAML/classic), ADO builds/releases, Azure DevOps boards & repos | Drummer |
| Create/iterate a specification or plan in a repo; break specs into work items for Ralph | Fred |
| Research an unknown, validate a recommendation, find docs/links for a spec | Elvi |
| Review a spec/plan for overall project fit, scope, or priority conflicts | Avasarala |
| Stand up/maintain a Neo4j code graph, run CodeToNeo4j indexing, write/optimize Cypher for codebase exploration | Sakai |
| SQL Server/Azure SQL or Cosmos DB schema design, indexing, query/RU tuning, partition-key strategy, migrations | Ashford |
| Memory, decisions merge, session logs, orchestration log | Scribe |
| Work queue, backlog monitor, keep-alive between tasks | Ralph |
| RAI review, content safety, ethical check | Rai |

## Escalation

When a task spans multiple domains (e.g., MSBuild + CI pipeline), route to **Holden** to
decompose and fan out to the specialists. For ambiguous requests, prefer the most specific
specialist; Holden handles ambiguity as a last resort.

## Spec → Work Item Pipeline

1. **Fred** drafts/iterates the specification or plan in the target repository, capturing
   detail, docs, and links; raises any unknowns as questions.
2. **Elvi** researches unknowns Fred flags (or Avasarala flags), tries any given
   recommendation first, and reports findings with citations back to Fred.
3. **Avasarala** reviews the resulting spec for overall project fit — scope, priority,
   consistency with other specs — and either approves or rejects with itemized concerns
   (Reviewer Rejection Protocol applies on rejection).
4. Once approved, **Fred** decomposes the spec into work items and hands them to **Ralph**
   for distribution to specialists.
