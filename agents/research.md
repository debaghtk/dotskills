---
name: research
description: "Research-first development. Use when the solution isn't obvious. Claude and Codex research independently, cross-validate findings, then plan and implement."
skills:
  - ds-codex
---

# Research-Driven Development

Use this workflow when the problem is clear but the solution isn't — you need to research before you can plan.

**Default Codex model: `gpt-5.4`**. Always use `-m gpt-5.4` unless the user explicitly requests a different model. Do NOT ask the user for model selection — use gpt-5.4.

## Input

The user provides: $ARGUMENTS

This may be a problem statement, a feature with unclear implementation, or a technical question that needs investigation.

## Phase 1: Clarify the Problem

Before researching, make sure you understand what we're solving:

1. Restate the problem in your own words.
2. Identify what's unclear — is it the approach, the tool, the architecture, or the constraints?
3. If requirements are ambiguous, ask the user to clarify before proceeding. Don't research a vague problem.

## Phase 2: Parallel Research

Claude and Codex research the same problem independently, then cross-validate.

### Step 1: Claude Research

Use your own tools to investigate:

**Web Search** — Use `WebSearch` to find:
- How other teams/companies have solved this problem
- Industry standards and best practices
- Common pitfalls and gotchas
- Recent approaches (include current year in queries for up-to-date results)

Search at least 2-3 different queries with different angles. Don't stop at the first result.

**Documentation (Context7)** — If the problem involves a specific library, framework, or tool:
1. Use `mcp__context7__resolve-library-id` to find the library
2. Use `mcp__context7__query-docs` to look up relevant APIs, patterns, and examples

Check docs for recommended patterns, built-in solutions we might be overlooking, version-specific behavior, and migration guides.

**Codebase** — Explore what's already implemented, current patterns, and available dependencies.

### Step 2: Codex Research

**ACTION REQUIRED: You must use the Bash tool to run `codex exec` here. Do not skip this.**

Start a Codex session following the ds-codex skill (use `--sandbox read-only`). The prompt to Codex must include:

- Context: "You are researching how to solve a technical problem. Investigate thoroughly using your knowledge."
- The actual problem statement
- Instructions: "Provide: 1) Known approaches to this problem (with trade-offs), 2) Industry standards and best practices, 3) Common pitfalls, 4) Libraries or tools commonly used, 5) Your recommended approach and why. Be specific — include code patterns, library names, and version considerations."

### Step 3: Cross-Validation

Compare Claude and Codex findings:

1. **Where they agree**: These are high-confidence findings. Note them.
2. **Where they disagree**: Investigate further. Use WebSearch or Context7 to break the tie. If still unclear, present both perspectives to the user.
3. **What one found that the other missed**: Feed missing findings back to the other for a second opinion.

Feed Claude's findings to Codex by resuming the session (follow ds-codex skill resume syntax). The prompt must include:

- "I (Claude) researched the same problem and found the following. Cross-check against your findings. Where do you agree or disagree? What did I miss? What did you miss?"
- Your actual research summary

Then review Codex's response. If it surfaced new information, do additional WebSearch or Context7 lookups to verify.

### Step 4: Synthesize

Compile the combined research into a summary:

```markdown
## Research Summary

### Problem
<restate the problem>

### Approaches Found
1. **<Approach A>**: <description>
   - Pros: ...
   - Cons: ...
   - Confidence: <high/medium — based on whether Claude and Codex agreed>
2. **<Approach B>**: <description>
   - Pros: ...
   - Cons: ...
   - Confidence: <high/medium>

### Points of Agreement
- <findings both Claude and Codex converged on>

### Points of Disagreement
- <where they differed, and what further research revealed>

### Relevant Documentation
- <key findings from Context7 / library docs>

### Recommendation
<which approach and why, considering our codebase and constraints>

### Sources
- [Title](url)
- [Title](url)
```

Present this to the user and get alignment on the approach before proceeding.

## Phase 3: Plan

Once the user agrees on the approach:

1. Write a detailed implementation plan:
   - **Approach**: The chosen solution with rationale
   - **Files to modify**: List every file with a summary of changes
   - **Dependencies**: Any new packages or tools needed
   - **Edge cases**: Informed by research findings
   - **Testing strategy**: How we'll verify correctness
2. Save the plan to `.claude/plans/research-workflow.md`.
3. Present the plan to the user for approval.

## Phase 4: Implementation

1. Implement the approved plan.
2. Reference documentation findings during implementation — re-check Context7 if unsure about an API.
3. Run tests and linters.

## Rules

- Never skip the research phase — it's the point of this workflow.
- Always run both Claude and Codex research. Two perspectives are better than one.
- Always cross-validate — feed findings into each other before synthesizing.
- Always present research findings to the user before planning.
- Always include sources for claims and recommendations.
- If research reveals the problem is simpler than expected, say so and suggest a simpler approach.
- If research reveals the problem is harder than expected, say so and discuss scope with the user.
- Don't over-research. 3-5 good sources per researcher is enough. Move to planning once you have a clear picture.
- Use the same Codex session throughout — always resume with `resume --last`.
