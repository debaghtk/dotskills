---
name: linear-project
description: Coordinate durable, continuous work across repositories through Linear projects, issues, comments, documents, and project updates. Use only when the user invokes this skill, asks to track or update work in Linear, supplies a Linear project or issue for the work, or an applicable repository instruction explicitly opts the work into Linear. Do not use for ordinary one-off tasks.
---

# Linear Project

Use the Linear tools already connected to Conductor. Treat Linear as the durable asynchronous record, not as a live agent messaging or wake-up system.

## Resolve the scope

1. Resolve the named project or issue from the request or applicable repository instructions.
2. Read the project description, attached documents, recent updates, relevant open issues, dependencies, and current discussion before acting.
3. Inspect the current repository, workspace, and branch so updates identify where the work lives.
4. If the user explicitly asks to start a project, create it with the stated outcome, participating repositories, and scope boundaries. Seed only agreed work; do not invent a speculative backlog.
5. Otherwise, if no project can be resolved, ask for one. Never guess, silently create a project, or attach work to a merely similar project.

If the Linear connection is unavailable, report that blocker. Do not build or configure another Linear integration.

## Keep the model simple

- Use a project for the enduring cross-repository outcome.
- Use an issue for a concrete, independently actionable unit of work.
- Use comments for progress, findings, blockers, handoffs, and approach discussion.
- Use a project document for durable scope, repository ownership, architecture, or decisions that many issues need.
- Use a project update for material progress, risks, and next steps—not routine issue activity.

Reuse existing teams, statuses, labels, templates, and conventions. Do not create a new taxonomy for the skill.

## Work through an issue

Before starting:

1. Search the project for an issue that already owns the work.
2. Create an issue only when the opted-in work is not represented and is actionable.
3. Record the primary repository in the issue description or reuse an existing repository label.
4. For material work, comment with the repository, workspace or branch, goal, and proposed approach so another agent can avoid conflicting work.
5. Move the issue to the existing in-progress status only when work actually begins.

During work:

- Add a concise comment when progress, scope, a blocker, or the chosen approach materially changes.
- Put findings that affect the current work on its issue.
- Create and link a new issue when a finding requires separate action.
- Update the project document when a durable cross-issue decision changes.
- Read the latest comments before changing an approach shared with another agent. Never claim agreement that is not recorded.

At handoff or completion, leave one concise comment containing:

```text
Outcome: <what changed or was learned>
Location: <repository and branch, PR, or commit when available>
Validation: <checks run and result>
Risks/blockers: <remaining uncertainty, or none>
Next: <specific next action, or none>
```

Update status only when supported by the work. Mark blocked with the concrete dependency. Mark completed only when the requested outcome and proportionate validation are complete.

## Coordinate cross-repository work

- Keep one project as the shared view across participating repositories.
- Keep one issue when changes across repositories form one atomic outcome.
- Split issues when changes are independently deliverable, have different owners, or must be sequenced separately; link the dependency.
- Add a project update only for a milestone, changed risk, scope or timeline change, or an explicit request.

## Guardrails

- Do not write to Linear for work that was not opted in.
- Keep read-only requests read-only.
- Do not create duplicate issues as messages or status logs.
- Do not copy full terminal output, commit logs, or chat transcripts into Linear.
- Do not promise that a comment will wake or route another agent.
- Do not mark work complete without evidence.
