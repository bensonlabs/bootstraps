---
name: wrap-up
description: Finish the current branch - bring it up to date, run the project's tests and checks, try it, make sure docs and decision records moved with the code, write the PR description, and push only when the person says so.
---

# Wrap-up

Use this when a branch is ready to become a PR.

1. **Bring the branch up to date.** Fetch, then merge the target branch in (or rebase, if the
   project rules say so) and resolve any conflicts. Never trust a stale remote ref.
2. **Tests and checks.** Run what the project rules list under "Commands" and "Checks this project
   relies on". Fix failures; never skip hooks. A check that didn't run didn't pass. If this work
   fixed a mistake that has happened before, add a check that fails on it (core rule 6).
3. **Try it.** Run the change and use it the way a person would (for a web page, in a browser at
   phone and desktop widths). Passing tests aren't the same as working. Note what you tried for
   "How it was tested".
4. **Docs moved with the code** (core rule 2). Each change to something a doc describes has that
   doc updated in the same commit. Fix stale docs you came across in the area you worked in.
5. **Decision records** (core rule 1) for any decision made or reversed in this work.
6. **PR description**, in this order:
   1. **What anyone has to do**, if anything beyond reviewing: scripts to run (with where, in what
      order, dry run first), settings to change, behavior to approve. One numbered list.
   2. **What changed and why.**
   3. **Anything the project rules say goes in the PR**, if any (an app's product rules ask for
      invented rules and wider access to approve).
   4. **How it was tested**, one work state at a time (core rule 3): what was built, which checks
      ran and passed (and which didn't run), what was tried by hand.
7. **Push and open the PR only when the person says so.** Request review from the reviewer the
   project rules name, if any, and confirm the request landed
   (`gh pr view <n> --json reviewRequests`). With no second reviewer, the person reviews the whole
   diff before merging.
8. **CI.** Watch the runs the push started and report their conclusion. Read it
   (`gh run view <id> --json conclusion`): a watch command exiting 0 isn't a pass. Never start or
   re-run a CI run or a deploy without a go for that run (core rule 4).
9. **Report** where things stand, one state at a time (built, checked, approved, merged, live), what
   needs the person, and any follow-up work this change revealed.
