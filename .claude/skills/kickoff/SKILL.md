---
name: kickoff
description: Start new work - a fresh branch, read what applies (the handoff note, project rules, starter docs, decision records), then a short plan before any code.
---

# Kickoff

Use this before starting any non-trivial piece of work.

1. **Branch.** Fetch, then create a fresh branch from the up-to-date target branch the project
   rules name under "Branches, review and release" (default name `feature/<short-name>`). If other
   work is in progress in this checkout, use a new git worktree under `.claude/worktrees/` instead
   of switching branches.
2. **Read first.**
   - The newest handoff note for this work, if there is one (`~/.claude/handoffs/`).
   - The project rules in CLAUDE.md that cover this area. An app at the "product" stage has its
     product rules there too; follow them.
   - The starter doc for each module you'll touch, if the project has them (see
     `docs/STARTER_DOC_TEMPLATE.md` for the shape).
   - Decision records in `docs/decisions/` that touch it, so a settled call isn't re-argued
     (core rule 1).
3. **Plan.** For anything beyond a trivial change: what changes, which files, the main risk, which
   docs change with it (core rule 2), and which test or check will show it works. Show the plan and
   wait for a yes before writing code.
