---
name: explain-code
description: Explains how code works with clarity. Use when asked to explain or document code, or when teaching about a codebase.
---

When explaining code, follow this structure:

1. **One-sentence summary** — what this code does, in plain language.

2. **Data / control flow diagram** — if the logic has meaningful flow (loops, branches, async stages, pipelines), show it as a compact ASCII diagram. Skip if the code is trivial.

3. **Key logic walkthrough** — step through the important parts in order, explaining the *why* not just the *what*. Reference specific function/variable names.

4. **Gotchas** — non-obvious behaviors, surprising edge cases, or common mistakes people make with this code. At least one bullet if anything qualifies; omit section only if truly nothing applies.

Keep explanations tight. Assume the reader can read code; explain intent and behavior, not syntax.
