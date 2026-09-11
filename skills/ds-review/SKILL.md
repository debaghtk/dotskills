---
name: ds-review
description: "Spec-driven code review of a PR or worktree that hunts for issues a real user would witness in production. P0 = user-facing production breakage, P1 = misses against the engineering standard. Every finding explains why it's a problem, how and when it happens in prod, how to fix it, and cites docs or a web source. Use when user says 'review this PR', 'review my branch/worktree', 'ds-review', or asks whether a change is ready to ship."
argument-hint: "[PR number/URL | branch | worktree path] [spec path/URL]"
---

# DS Review

Review a change the way production will: through the eyes of a real user, on real data, during a real deploy. The output is a ranked list of verified issues — not a diff summary, not style nits.

**This review is read-only.** Do not edit, commit, push, or comment on the PR. Offer to do those afterwards; only act on an explicit yes.

## Phase 1 — Resolve the target

Work out what is being reviewed from the arguments, in this order:

| Argument | Target | How to get the change |
|---|---|---|
| PR number or URL | GitHub PR | `gh pr view <pr> --json title,body,baseRefName,headRefName,files,url,closingIssuesReferences` and `gh pr diff <pr>`. Check out the head (`gh pr checkout` in a scratch worktree, never over the user's uncommitted work) if you need to run anything. |
| Branch name | Branch vs its base | `git diff $(git merge-base <default-branch> <branch>)...<branch>` |
| Path | That worktree | Run the "nothing" row from inside that path. |
| Nothing | Current worktree | Committed-but-unmerged (`git diff $(git merge-base <default-branch> HEAD)`), plus staged, unstaged, and untracked files (`git status --porcelain`). |

Find the default branch with `gh repo view --json defaultBranchRef` or `git symbolic-ref refs/remotes/origin/HEAD`; don't assume `main`.

If the diff is empty, say so and stop.

Read the **full files** the diff touches, not just the hunks — most production bugs live in the interaction between changed lines and unchanged ones. Follow callers and callees of changed functions far enough to know how the change is actually reached.

## Phase 2 — Find the specification

A spec is whatever defines what this change is *supposed* to do. Look before asking:

1. A spec path or URL passed as an argument.
2. The PR description, and any issues it closes or links (`gh issue view`, Linear issue IDs like `ABC-123` via the Linear tools if available).
3. Spec-like files the change references or that sit near it: `docs/`, `specs/`, `rfcs/`, `adr/`, `PRD*`, `SPEC*`, `*.spec.md`, `plan*.md`, `problems/` registry entries, `Product.md`.
4. Commit messages on the branch.

If you find one, state which source you are using and quote the requirements you'll check against.

If you find nothing, **stop and ask the user for one** (use the AskUserQuestion tool when available). Offer: paste the spec, give a path or URL, point to a ticket, or proceed without one. If they proceed without, say clearly in the report that spec conformance was not checked and the review is limited to production-safety and engineering standards — and infer intent only from the PR title/description, labelled as inferred.

Break the spec into a numbered list of concrete, checkable requirements (including acceptance criteria, edge cases it names, and non-functional requirements like performance, accessibility, or rollout). You will mark each one in the report.

## Phase 3 — Establish the engineering standard

P1 is judged against *this repo's* standard first, general industry standard second. Collect:

- Written rules: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING*`, `ARCHITECTURE.md`, `docs/` conventions, ADRs, PR templates.
- Enforced rules: linter/formatter/type-checker configs, CI workflows, test setup, commit hooks.
- Implicit rules: how neighbouring code already handles errors, logging, validation, data access, tests, naming. A change that ignores an established local pattern is a finding; a change that merely differs from your taste is not.

Run the project's own checks where it's cheap and safe (type-check, lint, the test files covering changed code). Record failures as findings with the actual output.

## Phase 4 — Hunt for issues

Review with two lenses. Use subagents in parallel for large diffs if your harness supports them (e.g. one per lens or per area of the change), then merge and dedupe.

### Lens A — What will a real user witness? (P0 candidates)

Walk every user-reachable path the change touches as an actual user would: first-time user, returning user with old data, user on a slow network or old device, user in another locale/timezone, user without permission, two users at once. For each, ask what they see.

- **Spec conformance** — a requirement that is missing, partially implemented, or behaves differently from the spec in a way the user sees.
- **Broken states** — crashes, blank screens, infinite spinners, unhandled promise rejections surfacing as errors, 500s, dead buttons, missing empty/error/loading states.
- **Wrong data** — incorrect totals, stale cache, off-by-one pagination, timezone/DST shifts, rounding and currency errors, lost or duplicated writes, data shown to the wrong user.
- **Input edge cases** — empty, null, very long, unicode/emoji/RTL, zero/negative, max values, unexpected types from real APIs.
- **Concurrency** — double submit, retries without idempotency, race between tabs/devices/workers, optimistic UI that never reconciles.
- **Deploy and rollout** — migrations that lock or break old code during a rolling deploy, removed/renamed fields old clients still send or read, missing env vars/secrets/feature-flag defaults in prod, cache keys that collide with the previous version, irreversible migrations without a path back.
- **Scale** — N+1 queries, unbounded lists/loops, missing indexes, payloads that are fine on seed data and fatal on production volume, missing timeouts on external calls.
- **Security and privacy that users feel** — auth bypass, IDOR, leaked PII in responses/logs/URLs, XSS/injection, CSRF, open redirects.
- **Access** — accessibility failures that block a task (no keyboard path, unlabeled controls, focus traps), browser/device support gaps for supported targets.
- **Failure of dependencies** — third-party API down/slow/rate-limited, partial failures in multi-step writes with no rollback or compensation.

### Lens B — Does it meet the engineering standard? (P1 candidates)

- Violations of the rules gathered in Phase 3.
- Changed behaviour without tests, or tests that don't actually assert the behaviour (always-pass, over-mocked, snapshot-only).
- Swallowed errors, catch-all handlers, missing logging/metrics/tracing on new failure paths, so the next prod incident is invisible.
- Type holes (`any`, unchecked casts, non-null assertions on data from outside the process), missing validation at trust boundaries.
- Duplication of existing utilities, dead code, leftover debug output, TODOs that mask unfinished spec requirements.
- Poor naming, leaky abstractions, wrong layer, tight coupling that makes the change hard to test or roll back.
- Security or performance hygiene that is not currently exploitable or user-visible but will become so under a plausible change.

### Severity rules

- **P0** — can break in production **and** a user can witness it (directly, or later as a consequence, such as corrupted data they'll see or a charge they'll dispute). Includes user-visible spec violations.
- **P1** — does not meet the engineering standard, or breaks something no user can observe (internal tooling, logs, dev experience).
- When unsure between the two, ask: "Is there a concrete, realistic sequence of events in production that ends with a user seeing something wrong?" If you can write that sequence down, it's P0. If you can't, it's P1.
- Not an issue: personal style preferences not backed by the repo standard, speculative "what ifs" with no plausible trigger, and anything already handled elsewhere in the code (check before reporting).

## Phase 5 — Verify every finding

A review full of false positives trains people to ignore reviews. Before a finding goes in the report:

1. **Re-read the code path** end to end and confirm the problem isn't handled upstream, downstream, by a framework default, middleware, DB constraint, or a feature flag.
2. **Reproduce when feasible** — a failing test in a scratch location, a script, a `curl` against a dev server, a query against a local DB. Don't modify the user's working tree; use the scratch/temp directory. Note in the finding whether it was reproduced or reasoned.
3. **Back it with a source.** For any claim about how a library, framework, runtime, browser, database, or protocol behaves, fetch the current documentation — use the `find-docs` skill / Context7 (`ctx7`) for libraries, and web search/fetch for specs, RFCs, MDN, OWASP, vendor docs, CVEs, or well-known engineering write-ups. Prefer primary sources (official docs, RFCs, standards) over blog posts. Quote the relevant sentence.
4. **Never fabricate a citation.** Only cite a URL you actually opened in this session, and only quote text that is actually on that page. If no source was found, write `Source: none found — reasoning from the code above` rather than inventing one. For spec violations, the spec itself is the source — quote it.

Drop findings that fail verification. If something is plausible but you couldn't confirm it, keep it only if the impact would be severe, and mark it `Unconfirmed`.

## Phase 6 — Report

Output the report in the conversation using this structure. Keep it scannable; the detail lives in each finding.

```markdown
# Review: <PR title or branch> 

**Target:** <PR URL | branch | worktree path> · <base>...<head> · <N files, +A/−D>
**Spec:** <source and link/path> | Not provided — spec conformance not checked
**Verdict:** Block | Ship after P0 fixes | Ship — <one sentence why>

| # | Sev | Issue | Location |
|---|-----|-------|----------|
| 1 | P0 | <short title> | `path/to/file.ts:42` |
| 2 | P1 | <short title> | `path/to/other.py:10` |

## P0 — User-facing production breakage

### 1. <Short, specific title>
**Location:** `path/to/file.ts:42` (and any related lines)
**Status:** Reproduced | Verified by reading | Unconfirmed

**What's wrong**
<One or two sentences, with the offending snippet if it helps.>

**Why it's an issue**
<The broken expectation — the spec requirement, correct behaviour, or contract being violated.>

**How and when it happens in production**
- **Trigger:** <the concrete sequence of events / input / environment>
- **Who sees it and what they see:** <user type, exact visible symptom>
- **Likelihood & blast radius:** <every request / only during deploy / users with >1000 items / Safari only …; how many users, is data recoverable>

**Fix**
<Specific change, with a code snippet or diff. Mention the test that should lock it down.>

**Source**
> "<quoted sentence>"
> — [<Doc/page title>](<url you actually opened>)

## P1 — Engineering standard

### 2. <Short, specific title>
<Same fields as above. For "how and when it happens in production", describe the concrete future cost: the incident that goes undetected, the regression that slips through, the change that becomes risky.>

## Spec coverage

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| R1 | <requirement> | Met / Partial / Missing / Contradicted | <finding # or evidence> |

## Checks run
- `<command>` — pass/fail (<short excerpt of failure>)

## Not reviewed
<Anything out of scope or not inspected: generated files, lockfiles, areas you couldn't run, and why.>
```

Rules for the report:

- Order findings P0 first, then P1; within a severity, by likelihood × blast radius.
- Every finding needs a real `file:line`. No finding without a location.
- If there are no P0s, say so explicitly — that's useful information, not an omission.
- If a finding is in code the PR didn't touch but the PR newly makes reachable, it counts; say how the PR exposes it.
- Don't pad. Five real issues beat twenty weak ones.

After the report, offer next steps in one line: fix the P0s, post the review as a PR comment, or write it to a file. Do none of these without a yes.
