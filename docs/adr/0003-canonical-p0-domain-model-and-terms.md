# ADR 3: Canonical P0 Domain Model And Terms

Date: 2026-07-01

Status: Accepted; Watch action vocabulary and Project-status implications superseded by ADR 4

## Decision

LineWise P0 uses this canonical domain model:

```text
GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue
```

Watch owns `Try`, `Send`, `Fail`, and `Undo`. `Flash` is a useful result attribute but is not a required separate Watch button in P0.

This Watch-action sentence is retained as historical context and is superseded by `0004-attempt-anchor-and-project-cycles.md`: P0 records one Attempt, optionally marks Send on that Attempt, and has no required Watch Fail action.

`MoveCue` is the user-facing term for route-specific movement advice. Older terms such as `BetaNote`, `Cue`, and generic `beta` should be treated as historical aliases in older research documents, not active product language.

## Context

Earlier research used several overlapping terms: `BetaNote`, `Cue`, `ProjectAnchor`, `Attempt Copilot`, and `training memory app`. After naming the product LineWise / 线感, the product scope became more precise: indoor bouldering route memory and line-reading support.

The active product needs one vocabulary so future PRDs, issues, and implementations do not split the data model.

## Consequences

- Active docs should use `MoveCue` instead of `BetaNote`.
- `FailureEpisode` is the bridge between a failed attempt and later training/reading suggestions.
- `SuggestionProvenance` records source and confidence for suggested timelines or future AI outputs.
- P0 data must remain simple enough for field validation.
- P0.5 dataset objects such as `Photo`, `HoldInstance`, `RouteGroup`, `RouteRole`, and `MoveSequence` are not required for the minimum P0 loop.
- Historical research documents may keep old names, but the active PRD, `CONTEXT.md`, and new issues should use canonical terms.
