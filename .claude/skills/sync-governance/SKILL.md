---
name: sync-governance
description: Bring this project's governance files (the governance blocks in CLAUDE.md, the .claude skills, the doc templates) up to date with the architectureOS repo, without changing anything the project owns. Then offer to send improvements back.
---

# Sync governance

## Bring changes in

1. Read `.governance-sync.json` in the project root: `source_repo` and `synced_commit`.
2. Clone the source repo into a new temporary folder. It must be a full clone, because the sync
   needs the old commit too: `gh repo clone <owner>/<repo> <tmp>/architectureOS` for a GitHub repo,
   otherwise `git clone <source_repo> <tmp>/architectureOS`.
3. Run `node <tmp>/architectureOS/scripts/sync.mjs --project <project root>`. It applies what's
   safe and prints a report. It opens with the architectureOS commits since the last sync: read the
   ones behind any item that needs judgment or is a suggestion
   (`git -C <tmp>/architectureOS show <hash>`), so you know what the change was for. Then:
   - **Applied:** files and blocks this project hadn't changed, replaced with the new version.
     Nothing to do.
   - **Merged:** changed here and upstream in different places, merged by git. Read
     `git diff -- <path>` and confirm it reads right.
   - **Needs judgment:** changed here and upstream in the same place, so it was left as it was.
     Open the files the report names (base, upstream, and a merge with conflict markers) and write
     a version that keeps this project's intent and adopts the upstream change. If the right answer
     isn't clear, ask the person; don't guess.
   - **Suggestions:** files the project owns (seed files), new governance blocks, and things the
     template removed. Show each one to the person and apply only what they agree to.
   - **Notes:** for information, including a file whose ownership mode the template changed (ask
     the person before changing it in `.governance-sync.json`).
4. When every item is dealt with, run the finish command the report printed
   (`... sync.mjs --project <root> --finish`). It records the new commit in `.governance-sync.json`.
   When nothing needed a decision, the script has already recorded it.
5. Show the person `git diff` and a short summary. Don't commit or push unless they ask.

## Send improvements back

6. **Governance improvements.** If this project improved a core rule, a skill or a template in a
   way other projects should get, propose the same change to the architectureOS repo for the
   person to approve, rather than letting this project's copy drift.

## Never

- Change text outside a governance block, or a file set to `"project"` in `.governance-sync.json`.
- Delete a file, except one the template removed, once the person agrees to that suggestion.
- Push.
