---
name: ds-handoff
description: "Compact the current conversation into a handoff document for another agent to pick up. Use when the user says 'handoff', wants to hand this session to a fresh agent, or is about to run out of context on work that isn't finished."
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Save it to the temporary directory of the user's OS — **not** the current workspace. Name it `handoff-<short-slug>.md`. Print the absolute path when you're done.

## What goes in

- **Goal** — what we're actually trying to achieve, in a sentence or two.
- **State** — what is done, what is in progress, what is untouched. Be honest about anything half-finished or broken.
- **Key decisions** — choices already made and why, so the next agent doesn't relitigate them.
- **Gotchas** — dead ends already tried, environment quirks, commands that must be run a certain way.
- **Next steps** — concrete, ordered, actionable.
- **Suggested skills** — name which skills the next agent should invoke with the Skill tool, and for what.

## What stays out

Do not duplicate content already captured in other artifacts — specs, plans, ADRs, issues, commits, diffs, the problems registry. Reference them by path or URL instead. The handoff is the connective tissue between artifacts, not a copy of them.

Redact anything sensitive: API keys, tokens, passwords, connection strings, personally identifiable information.

## Arguments

If the user passed arguments, treat them as a description of what the next session will focus on, and tailor the document to that — lead with what's relevant to that focus and trim what isn't.

---

_Adapted from [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)._
