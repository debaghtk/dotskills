---
name: deven
description: "End-to-end development workflow: plan → codex review → implement → codex review → PR → QA checklist. Use when given a problem statement, feature request, or bug report."
skills:
  - ds-codex
---

# Dev Workflow

You are running an end-to-end development workflow with automated peer review via OpenAI Codex CLI (`codex exec`). Follow these phases strictly and sequentially. Do NOT skip phases or combine them.

**CRITICAL: You MUST run `codex exec` commands using the Bash tool during Phase 2 and Phase 4. These are not optional. The Codex review is the core value of this workflow — without it, this is just a regular implementation. If you find yourself moving from Phase 1 to Phase 3 without running codex, you are doing it wrong. STOP and go back to Phase 2.**

## Input

The user provides: $ARGUMENTS

This may be a problem statement, feature request, bug report, or Linear issue reference. If unclear, ask for clarification before proceeding.

## Codex Session Management

The ds-codex skill is preloaded — follow it for command construction, flags, error handling, and session management.

**Default model: `gpt-5.4`**. Always use `-m gpt-5.4` unless the user explicitly requests a different model.

**Use a single Codex session throughout the entire workflow.** This ensures Codex retains full context of the plan, its prior feedback, and the implementation.

- **First Codex call**: Use `codex exec -m gpt-5.4 --skip-git-repo-check --sandbox read-only` to start a new session. Do NOT ask the user for model selection — use gpt-5.4.
- **All subsequent Codex calls**: Resume the same session per ds-codex skill resume syntax.
- Never start a new Codex session mid-workflow. Always resume.

## Phase 1: Planning

1. Explore the codebase to understand the relevant code, patterns, and architecture.
2. Write a detailed implementation plan:
   - **Problem**: What we're solving and why
   - **Approach**: How we'll solve it
   - **Files to modify**: List every file with a summary of changes
   - **Edge cases**: What could go wrong
   - **Testing strategy**: How we'll verify correctness
3. Save the plan to `.claude/plans/dev-workflow.md` so it persists.

## Phase 2: Plan Review (Codex)

**ACTION REQUIRED: You must use the Bash tool to run `codex exec` here. Do not skip this.**

1. Construct the codex command following the ds-codex skill (use `--sandbox read-only` for reviews). Execute it with the Bash tool. The prompt to Codex must include:

   - System context: "You are a senior engineer peer-reviewing an implementation plan written by Claude (another AI). You will be used throughout this entire development workflow — first to review the plan, then to review the implementation. Retain context across all interactions."
   - Instructions: "Review this implementation plan. Be critical. Look for: missed edge cases, simpler alternatives, potential bugs, architectural concerns, and scope creep. When Claude pushes back on your feedback, evaluate their reasoning honestly. If their argument is sound, accept it and move on. If you still believe there's a real issue, hold your ground with specifics. Don't cave just to be agreeable, and don't nitpick just to justify your role. Focus on things that actually matter. If the plan is solid, respond with APPROVED. If not, list specific concerns with clear reasoning."
   - The actual task description
   - The actual plan text
2. If Codex responds with concerns, **critically evaluate each one before acting**:
   - For each concern, decide: is this valid, or is Codex wrong/over-engineering/missing context?
   - **If you agree**: Fix it and note why.
   - **If you disagree**: Push back. Resume the session and explain why the concern is invalid, with evidence (code references, documentation, architectural rationale). Do NOT silently comply with feedback you believe is wrong.
     ```bash
     echo "I've reviewed your concerns. Here's my response:

     Concern 1 (missed null check): Agreed — fixed.
     Concern 2 (should use factory pattern): I disagree. This is a single-use case with no foreseeable need for polymorphism. A factory here adds indirection without value. The current approach is simpler and matches our existing patterns in <file>. Convince me otherwise or accept.
     Concern 3 (race condition): Agreed — fixed.

     Updated plan: <updated plan>. Review again — respond APPROVED if ready, or list remaining concerns." | codex exec --skip-git-repo-check resume --last 2>/dev/null
     ```
   - If Codex insists on a point you still disagree with, escalate to the user with both perspectives.
   - Repeat until Codex responds with APPROVED or the disagreement is escalated.
3. If the loop exceeds 3 iterations, present the remaining unresolved concerns to the user with both Claude's and Codex's positions, and ask how to proceed.

## Phase 3: Implementation

1. Create a new git branch: `git checkout -b <descriptive-branch-name>`
2. Implement the approved plan, file by file.
3. Run any existing tests after implementation.
4. Run the linter/formatter if configured in the project.

## Phase 4: Implementation Review (Codex)

**ACTION REQUIRED: You must use the Bash tool to run `codex exec resume` here. Do not skip this.**

1. Generate the diff using the Bash tool: `git diff main...HEAD`
2. Resume the Codex session following ds-codex skill resume syntax. The prompt to Codex must include:

   - Instructions: "Now review the implementation. Here's the diff. Check for: bugs, security issues, performance problems, missing error handling, code style, and whether the implementation matches the approved plan. Same rules as before: when Claude pushes back on your feedback, evaluate honestly. Accept valid arguments, hold firm on real issues. Don't nitpick, focus on what matters. Respond APPROVED if ready to merge, or list specific issues with file paths and line numbers."
   - The actual diff
3. If Codex raises concerns, **critically evaluate each one before acting**:
   - For each concern, decide: is this a real bug/issue, or is Codex being overly cautious/wrong?
   - **If you agree**: Fix it, re-run tests.
   - **If you disagree**: Push back with evidence. Resume the session and challenge the feedback:
     ```bash
     echo "I've reviewed your code review. Here's my response:

     Issue 1 (missing error handling on line 42): Agreed — fixed. Added try/catch with specific error types.
     Issue 2 (should extract helper function): I disagree. This logic is used once and is 6 lines. Extracting it adds indirection for no reuse benefit. Keeping it inline is clearer.
     Issue 3 (potential SQL injection): This is a false positive. We're using parameterized queries via the ORM — the input never touches raw SQL. See <file:line>.

     Updated diff: <new diff>. Review again." | codex exec --skip-git-repo-check resume --last 2>/dev/null
     ```
   - If Codex insists on a point you still disagree with, escalate to the user with both perspectives.
   - Repeat until Codex responds with APPROVED or the disagreement is escalated.
4. If the loop exceeds 3 iterations, present unresolved disagreements to the user with both positions and ask how to proceed.

## Phase 5: Pull Request

1. Push the branch: `git push -u origin HEAD`
2. Create a PR using `gh pr create` with:
   - A concise title
   - A body containing:
     - **Summary**: What changed and why
     - **Changes**: Bullet list of what was modified
     - **Codex Review**: Note that the plan and implementation were reviewed by Codex
     - **Test plan**: How to verify
3. Share the PR URL with the user.

## Phase 6: QA Checklist

Generate a manual QA checklist tailored to the specific changes:

```markdown
## Manual QA Checklist

### Happy Path
- [ ] <specific test step>
- [ ] <specific test step>

### Edge Cases
- [ ] <specific edge case to test>
- [ ] <specific edge case to test>

### Regression
- [ ] <area that could be affected by changes>
- [ ] <area that could be affected by changes>

### Accessibility (if UI changes)
- [ ] Keyboard navigation works
- [ ] Screen reader announces correctly
- [ ] Color contrast is sufficient
```

## Rules

- Always show the user what you're sending to Codex before sending it.
- After each Codex review, summarize the feedback for the user before acting on it.
- Never skip the review phases — they are the point of this workflow.
- If tests fail during implementation, fix them before proceeding to review.
- Ask the user before force-pushing or any destructive git operations.
- Always resume the same Codex session — never start a new one mid-workflow.
- **Never blindly accept feedback.** Evaluate every piece of feedback critically. If it's wrong, say so with evidence. This applies to both Claude evaluating Codex's feedback and the instructions given to Codex for evaluating Claude's pushback.
- When there's a genuine disagreement after one round of pushback, escalate to the user. Don't loop endlessly — the user is the tiebreaker.
