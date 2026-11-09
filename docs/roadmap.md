# Roadmap

What's planned for __PROJECT_NAME__, in priority order. Each item is sized to be one pull request, and `/ship` builds straight from it:

| Command | What it does |
| --- | --- |
| `/ship R-003` | Builds item R-003, using its **What** and **Acceptance** as the start of the shared spec |
| `/ship next` | Builds the first item in **Up next** whose dependencies are done and that has no open PR |
| `/ship R-003 --merge` | The same, then merges once checks pass |

The `product-planner` agent adds and reorders items from decisions agreed with the user (see [product.md](product.md)). `/ship` marks an item **Done** on the item's own branch, so it reaches `main` when that PR merges. [feature-parity.md](feature-parity.md) tracks what each app actually has; this file tracks what's next.

## Format

Each item is a `###` heading with a stable ID and a short title, then these fields:

```
### R-001 Short title
- **Apps:** iOS + Android | iOS only | Android only | Website
- **Type:** feature | fix | chore
- **Depends on:** R-000, or —
- **Why:** one line on the user need
- **What:** the behavior a tester can check, as bullets
- **Acceptance:** cases with setup and expected result, including numbers, limits and exact wording
- **Notes:** design decisions, platform differences, open questions
- **PR:** — (set by /ship)
```

Rules:
- IDs are `R-` plus three digits, in the order items were added. Never reuse or renumber one.
- An item moves between sections; it's never deleted. **Dropped** items keep a one-line reason.
- An item that depends on one not merged yet is built as a stacked PR on that item's branch.
- **Type** sets the branch: `feature/`, `fix/` or `chore/` (see the branching policy in [CLAUDE.md](../CLAUDE.md)).

## Up next

<!-- Highest priority first. Ask the product-planner agent to draft the first items. -->

## Ideas

Not shaped yet: no acceptance criteria, not ready for `/ship`. One line each.

<!-- - Idea, and who asked for it -->

## Done

<!-- Items move here with their PR link when /ship opens the PR. -->

## Dropped

<!-- - R-000 Title: why it was dropped -->
