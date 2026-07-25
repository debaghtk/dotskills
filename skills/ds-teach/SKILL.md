---
name: ds-teach
description: Teach Deba a new skill or concept through a persistent, mission-driven learning workspace. Use when Deba asks to learn, study, practice, or be taught a topic over one or more sessions.
---

# DS Teach

Treat the current directory as a teaching workspace whose state persists across sessions.

## Set up the workspace

Use these files, creating each only when needed:

- `MISSION.md`: the concrete reason for learning. Follow [references/MISSION-FORMAT.md](references/MISSION-FORMAT.md).
- `RESOURCES.md`: trusted knowledge sources and communities. Follow [references/RESOURCES-FORMAT.md](references/RESOURCES-FORMAT.md).
- `GLOSSARY.md`: terminology the user has demonstrated they understand. Follow [references/GLOSSARY-FORMAT.md](references/GLOSSARY-FORMAT.md).
- `learning-records/NNNN-slug.md`: durable evidence of learning or prior knowledge. Follow [references/LEARNING-RECORD-FORMAT.md](references/LEARNING-RECORD-FORMAT.md).
- `lessons/NNNN-slug.html`: short, self-contained lessons.
- `reference/*.html`: printable cheat sheets, algorithms, syntax, poses, and other quick-reference material.
- `assets/*`: shared lesson stylesheets, widgets, simulators, and diagram helpers.
- `NOTES.md`: teaching preferences and working notes.

Read existing workspace state before teaching. If `MISSION.md` is absent or vague, first ask why the user wants to learn the topic. Keep one mission per workspace; suggest a separate workspace for an unrelated topic. Confirm before changing an established mission, then record the change.

## Choose what to teach

Ground every lesson in the mission. Estimate the user's zone of proximal development from their learning records, demonstrated knowledge, and questions. Teach one thing that is challenging but achievable and produces a tangible win.

Never treat coverage as learning. Record prior knowledge, corrected misconceptions, mission changes, or demonstrated non-trivial understanding—not session activity.

## Research first

Build `RESOURCES.md` from high-trust primary sources, recognized experts, peer-reviewed work, and well-moderated communities. Do not rely on parametric knowledge for factual teaching material. Annotate what each source covers and when to use it; remove weak or off-mission sources.

Use communities for questions that require practitioner wisdom. Respect the user's preference if they do not want community participation.

## Create lessons

Create the next sequential `lessons/NNNN-slug.html`. Keep it beautiful, focused, accessible, printable, and quick to complete.

Each lesson must:

1. Teach only the knowledge required for one skill.
2. Cite claims and recommend one high-quality primary source.
3. Include immediate practice with a tight feedback loop.
4. Use retrieval practice; add spacing and interleaving when useful.
5. Link to relevant lessons and reference documents.
6. Invite follow-up questions.

For multiple-choice quizzes, keep answer choices similar in length so formatting does not reveal the answer.

Reuse `assets/` before adding lesson-specific code. The first lesson earns one shared stylesheet; add another component only when a second lesson can reuse it. Open the generated lesson with the platform's normal file-opening command when available.

## Build durable knowledge

Distinguish momentary fluency from long-term storage strength. Prefer desirable difficulty—effortful recall, spaced review, and mixed practice—over passive rereading.

Create or update concise `reference/*.html` documents when a lesson yields reusable knowledge. Add a glossary term only after the user demonstrates understanding, then use that terminology consistently. Revise stale definitions as understanding deepens.

After evidence of learning, write the smallest useful learning record and use it to choose the next lesson.
