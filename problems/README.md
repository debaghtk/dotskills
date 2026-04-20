# Problems Registry

A structured log of identified problems across the project. Skills like `/ds-shobhit` write here after framing; `/ds-vinay` reads here before scoping.

## Entry Format

Every problem entry follows this structure:

```markdown
### <short-title>
- **Filed:** YYYY-MM-DD
- **Filed-by:** shobhit | vinay | human
- **Status:** open | investigating | scoped | resolved | archived
- **Framing:** <1-2 sentence problem statement>
- **Context:** <optional link to spec, conversation, or commit>
```

## Categories

| File | Scope |
|------|-------|
| `engineering.md` | Architectural concerns, scaling issues, infrastructure gaps |
| `tech-debt.md` | Shortcuts, deferred cleanup, deprecated patterns |
| `bugs.md` | Confirmed defects with reproduction steps |
| `features.md` | Capability gaps, requested features |
| `ux.md` | Usability friction, accessibility issues |

## Status Lifecycle

```
open → investigating → scoped → resolved → archived
```

- **open** — problem identified, not yet being worked on
- **investigating** — actively gathering information
- **scoped** — acceptance criteria defined (usually via `/ds-vinay`)
- **resolved** — fix shipped
- **archived** — moved to `archive/` quarterly

## Filing Rules

- `/ds-shobhit` files after user confirms the category
- `/ds-vinay` may file during scoping if a gap is discovered
- Humans file directly in the appropriate category file
- One problem per entry — decompose compound problems
- When archiving, move the entry to `archive/YYYY-QN.md`
