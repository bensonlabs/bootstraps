# Bootstraps: instructions for AI agents

<!-- Only the governance blocks below come from architectureOS; /sync-governance updates them. Everything outside them belongs to this project and is never changed by a sync. -->

<!-- BEGIN governance:scaffold -->
## How this file works

- **Personal preferences** come from the person's own `~/.claude/CLAUDE.md`, never from this file.
- **Core rules** (the next block) come from the architectureOS repo and are the same in every
  project. To change one, change it there; `/sync-governance` keeps this file in step.
- **Project rules** (at the bottom) belong to this project: what it owns, its commands, what must
  never move, and its own checks. Give a non-obvious one a date and who decided ("owner decision,
  2026-11-07").
- **Apps with users** add the product rules (architectureOS doc `product-rules.md`) to their
  project rules when they reach the "product" stage.
- **Background:** each core rule names a doc in the architectureOS repo (`source_repo` in
  `.governance-sync.json`). It's private; read a doc with
  `gh api repos/<owner>/<repo>/contents/docs/<name>.md -H "Accept: application/vnd.github.raw"`.
<!-- END governance:scaffold -->

<!-- BEGIN governance:core-rules -->
## Core rules

1. **Record decisions that aren't obvious.** A choice someone could reasonably have made the other
   way, or one that's costly to undo, gets `docs/decisions/NNNN-<slug>.md` from `TEMPLATE.md`.
   Reversing one is a new record that supersedes it; the old one gets only a "superseded by" line.
   Doc: `decision-records.md`.
2. **Docs change in the same commit as the code they describe,** so undoing the commit undoes both.
   When code, docs and memory disagree, the source wins (the running system, the spec, the data),
   then the code, then the docs: fix the lower one while you're there.
   Docs: `same-commit.md`, `trust-order.md`.
3. **Report each work state as its own fact:** built, checked (the check ran and passed, and you saw
   it), approved, merged, live. Never infer a later state from an earlier one.
   Doc: `work-states.md`.
4. **Never start or re-run a deploy or CI run without a go for that run.** A go to merge isn't a go
   to start a run. To find out whether something is reachable or allowed, use read-only calls.
   Doc: `conventions.md`.
5. **Secrets and people's data never go in git:** not in code, commits, PRs, issues, logs, test data
   or screenshots. Committed config holds placeholders. If one slips in, tell the person at once.
   Doc: `conventions.md`.
6. **A mistake that happens twice becomes a check that fails.** Mechanical facts (a path exists,
   copies match, a page is published) get a test or CI check, not a reminder. Judgment calls stay
   with people. Doc: `checks-over-reminders.md`.
<!-- END governance:core-rules -->

## Project rules

@AGENTS.md

The import above loads AGENTS.md, this repo's own rules for the scripts. Other coding tools read it
too, so rules about the scripts stay there; this section covers the page, its release and checks.

### About this project

- What it owns: the bootstrap scripts for Justin's workstations (Windows, WSL2 Ubuntu, macOS,
  Fedora, the HW laptop grader) and the page at https://bensonlabs.org/bootstraps/
  (`site/index.md`), which lists every bootstrap command on one page (owner decision, 2026-11-08).
- Lifecycle stage (experiment, project, maintained, product, archived): project. Personal
  workstations, one user.
- What must never move: the page's address, https://bensonlabs.org/bootstraps/ (people type it
  on fresh machines), the script paths the page's commands fetch from `main`, and the grader's
  `hw-laptop-grader-v*` tags. Moving one breaks the commands already written down or in use.

### Commands

On Windows, `python3` isn't on the PATH: run the same commands with `py`.

- Install: nothing for the page and its tools (Python 3 only).
- Run locally: `python3 tools/pack.py` packs the page into `dist/` as a release would.
- Tests and checks (wrap-up runs these): `python3 -m unittest discover -s tools -p 'test_*.py'`,
  `python3 tools/pack.py --version v0.0.0`, `python3 tools/check_shared.py`, and for the
  workstation spec `python3 scripts/verify_spec.py` and `python3 tests/test_workstation_spec.py`.

### Environments

- Sandbox for testing: the page, a local pack in `dist/`. The scripts: CI checks their static
  contracts only; a rebuild on a clean machine or VM is the real test (AGENTS.md).
- Live, and who changes it: the page's commands fetch five scripts straight from `main`, so a push
  to `main` changes what those commands run at once. The HW laptop grader is pinned to its
  `hw-laptop-grader-v*` tag. The page itself goes live when the blog pins its release.

### Branches, review and release

- PRs go to: `main`. Bring a branch up to date by merging.
- Reviewer: with no second reviewer, Justin reviews the whole diff before it merges.
- How changes reach users, and who runs it: nobody runs anything. A push to `main` that changes the
  page publishes the next `vX.Y.Z` release, and the blog (bensonlabs/blog) pins it, checks the whole
  site and deploys it: at its daily run (13:17 UTC), or within minutes once this repo has the
  `BLOG_DISPATCH_TOKEN` secret. Don't publish other GitHub releases here: the release workflow reads
  the latest one.

### Checks this project relies on

Each stops a mistake that happened once or would break something (core rule 6):

- `tools/pack.py` refuses a page without its layout, title or description, a page that claims
  another address (`permalink`, `redirect_from`), or a page over 750 KB.
- `tools/check_shared.py` (Site page workflow, job "Shared files match the other repos"): the files
  shared with bensonlabs/games and bensonlabs/projects match their copies.
- actionlint on the page's two workflows (Site page workflow).
- Workstation specification validation, Bootstrap platform validation and Fedora bootstrap
  validation (their workflows): the spec parses and the scripts pass their static checks.
- The blog's page check requires `bootstraps/index.html`, so a release without the page never
  deploys.

### Where things live

- The page: `site/index.md`. Its release tools: `tools/`.
- Desired state: `workstation.yaml`; docs: `docs/` (README "Documentation").
- Scripts and their configs: `scripts/`, `windows/`, `wsl2-ubuntu/`, `distributions/`, `ai/`,
  `exports/` (README).
