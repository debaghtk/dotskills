---
name: mountain
description: "Plan and drive a project or long-running effort that outlives one session, using a Linear project as the durable home and a single ordered queue in its description as the answer to 'what's next'. Use when the user hands you a big initiative, a multi-week effort, or anything that needs to survive across sessions — not for one-off tasks ds-align or a normal session can close out."
disable-model-invocation: true
---

# Mountain

`ds-align` settles one conversation. Mountain is for the work that outlives the conversation: it gives the effort a durable home in Linear and, every time anyone opens it, one unambiguous next step. No map, no ticket taxonomy, no blocking graph — a project whose description is both the problem statement and the queue.

## Step 1 — Frame the problem

Decide whether the ask is already crisp or still loose.

- **Loose** ("our onboarding feels off," "we should think about scaling") — invoke `ds-inception` to frame it. Let it run its own premise-challenge and filing to `problems/`.
- **Crisp** ("add payments and billing") — invoke `ds-align`, but stop as soon as its **Phase 1 (Problem)** is confirmed. Do not enter its Phase 2 (Approach) — approach is decided per queue item later, not for the whole effort up front.

Either way, step 1 ends with one confirmed 1-2 sentence problem statement. That's the project's destination — don't proceed without it.

## Step 2 — Create the Linear project and its queue

Follow `linear-project`'s conventions: resolve the team, search for an existing project covering this problem before creating one.

Title the project from the problem statement. Its **description** carries everything — no separate document:

```markdown
## Destination
<the problem statement from Step 1 — one paragraph, no solutioning>

## Next
<the single task to work on right now — link to its issue>

## Then
1. <task> — <issue link>
2. <task> — <issue link>

## Done
- <task> — <issue link> — <one-line outcome>
```

`Next`/`Then` start with only the tasks you can name with confidence right now — a handful of concrete, ordered near-term items, not a speculative full backlog. Each queue entry is a Linear issue (title + one-line scope) in the project, linked from the description. Order by dependency and priority.

## Step 3 — Work the queue

- Every session opens the project and reads `Next` in its description — that's the whole answer to "what do I work on."
- Do the task, using whatever fits (a skill, a subagent, a plain session) — narrate progress as issue comments, not in the description.
- On completion: close the issue, move its line from `Next`/`Then` into `Done` with a one-line outcome, promote the next `Then` item into `Next`. Edit the project description in place.
- New tasks discovered mid-work get appended to `Then` in the right position. If a discovered task sits outside the destination, drop it — don't file it.
- Re-run Step 1 only if the destination itself changes. Otherwise the project persists untouched, session to session, until `Then` and `Next` are both empty.

## Keep it small

One project, its description as the only queue, plain issues. No label taxonomy, no ticket-type ontology, no HITL/AFK split, no native-blocking graph, no fog-of-war section, no second document to keep in sync. If you're about to invent another artifact to track order or status, stop — the project description is what that's for.
