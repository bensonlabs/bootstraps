# ADR 1: Use decision records for non-obvious choices

**Date:** 2026-11-08
**Status:** accepted

## Context

Without a place to record why a non-obvious choice was made, later work (by a person or an agent)
either re-derives the same reasoning from scratch or reverses the decision without realizing it
was deliberate.

## Decision

Record decisions in `docs/decisions/`, one per non-obvious decision, using `TEMPLATE.md`
(core rule 1 in CLAUDE.md).

## Alternatives considered

- Commit messages: too easy to miss, and not browsable as a set.
- A wiki: separate from the code, so it drifts from what's true.

## Consequences

A little writing at decision time, in exchange for not re-arguing the decision later.
