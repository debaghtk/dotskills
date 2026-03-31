---
name: dev
description: "End-to-end development workflow: plan → codex review → implement → codex review → PR → QA checklist. Use when given a problem statement, feature request, or bug report."
---

# Dev Workflow

You are running an end-to-end development workflow with automated peer review via OpenAI Codex. Follow these phases strictly and sequentially. Do NOT skip phases or combine them.

## Input

The user provides: $ARGUMENTS

This may be a problem statement, feature request, bug report, or Linear issue reference. If unclear, ask for clarification before proceeding.

## Codex Session Management

**Use a single Codex session throughout the entire workflow.** This ensures Codex retains full context of the plan, its prior feedback, and the implementation.

- **First Codex call**: Use `codex exec` to start a new session.
- **All subsequent Codex calls**: Use `echo "<prompt>" | codex exec --skip-git-repo-check resume --last 2>/dev/null` to continue the same session.
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

1. Start the Codex session with the plan review:
   ```bash
   codex exec --skip-git-repo-check -m gpt-5.3-codex --config model_reasoning_effort="high" --sandbox read-only "You are a senior engineer peer-reviewing an implementation plan written by Claude (another AI). You will be used throughout this entire development workflow — first to review the plan, then to review the implementation. Retain context across all interactions.

   Review this implementation plan. Be critical. Look for: missed edge cases, simpler alternatives, potential bugs, architectural concerns, and scope creep.

   Important: When Claude pushes back on your feedback, evaluate their reasoning honestly. If their argument is sound, accept it and move on. If you still believe there's a real issue, hold your ground and explain why with specifics. Don't cave just to be agreeable, and don't nitpick just to justify your role. Focus on things that actually matter.

   If the plan is solid, respond with APPROVED. If not, list specific concerns with clear reasoning.

   Task: <the user's original request>

   Plan:
   <the full plan>" 2>/dev/null
   ```
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

1. Generate a diff: `git diff main...HEAD`
2. Resume the Codex session with the diff for code review:
   ```bash
   echo "Now review the implementation. Here's the diff. Check for: bugs, security issues, performance problems, missing error handling, code style, and whether the implementation matches the approved plan.

   Same rules as before: when Claude pushes back on your feedback, evaluate honestly. Accept valid arguments, hold firm on real issues. Don't nitpick, focus on what matters.

   Respond APPROVED if ready to merge, or list specific issues with file paths and line numbers.

   Diff:
   <the diff>" | codex exec --skip-git-repo-check resume --last 2>/dev/null
   ```
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
