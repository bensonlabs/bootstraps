---
name: handoff
description: Write or update a handoff note so a fresh session (a new chat, the other account, tomorrow) can pick the work up without re-deriving it. Use at the end of a work day, before switching accounts or machines, when a long session is running out of room, or when the person asks for one.
---

# Handoff

A handoff note is a working note for the next session, not documentation: it holds where the work
stands and what to do next, which nothing else records. Lasting facts go where they belong instead
(project rules, starter docs, decision records, memory).

## Where

`~/.claude/handoffs/<yyyy-mm-dd>-<short-name>.md`, in the home folder, never in the repo: it names
people and unreleased work. Update today's note for the same work rather than starting another.

## What goes in it

Write for a reader who has none of this conversation. Exact names: branches, commit hashes, PR
numbers, file paths, commands.

1. **Goal:** the work in one or two sentences, and who asked for it.
2. **State:** branch, last commit, what's pushed and what's only local, open PRs and their review
   and CI state, scripts run and where (and which haven't run).
3. **Done since the last note:** short, with commit hashes.
4. **Next:** the first concrete step, then the rest in order.
5. **Decisions in force:** what the person decided and when, so it isn't asked again. Open
   questions, each with your recommendation.
6. **Watch out:** traps found along the way, things not to touch, people waiting on something.
7. **How to check it works:** the commands, pages or test steps.

## Then

Tell the person the note's full path. A new session starts by reading the newest note for the work
(the `kickoff` skill says so).
