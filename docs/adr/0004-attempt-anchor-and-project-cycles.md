# ADR 4: Use Attempt Anchors And Separate Project Cycles

Date: 2026-08-11

Status: Accepted

## Decision

LineWise P0 records one `Attempt` with one primary Watch action. A new Attempt begins with outcome `unresolved`.

`Mark Send` changes the outcome of an existing Attempt to `sent`; it does not create another Attempt. P0 does not require a Watch `Fail` action. An Attempt becomes `not_sent` only through explicit user confirmation, normally during iPhone review. An unresolved Attempt may remain unresolved without being treated as failure.

`FailureEpisode` explains a meaningful breakdown. It is separate from Attempt outcome and is user-confirmed or clearly suggested.

`RouteCard` identifies one believed physical route incarnation. `Project` is a time-bounded intention to revisit a RouteCard. RouteCard visibility, physical availability, and Project lifecycle are separate state axes. A RouteCard may therefore have several historical Project cycles.

Cross-device actions use stable identities and exact causal targets. Retries are idempotent, and delayed `Mark Send` or `Undo` actions target the original Attempt/action rather than the most recently received event.

The detailed normative behavior is defined by `docs/linewise_p0_domain_and_lifecycle_contract_v0.md`.

## Context

ADR 3 established a useful canonical object chain, but it also made `Try`, `Send`, `Fail`, and `Undo` separate Watch-owned events and allowed one RouteCard status to carry route availability, project intent, and result history.

The low-interruption Watch prototype and follow-up requirements work exposed four problems:

1. separate Try/Send/Fail actions make a frequent in-session interaction heavier than necessary;
2. `Send` can accidentally look like a second attempt instead of a result on one attempt;
3. an omitted `Fail` tap is not reliable evidence that an attempt failed, while unresolved data is honest and reviewable;
4. one RouteCard status cannot preserve repeated Project cycles, route resets, archive visibility, and historical sends without rewriting meaning.

The alternatives considered were:

- retain four Watch actions and require an outcome for every attempt;
- record only completed sends and omit unsuccessful attempts;
- infer non-send from the next attempt, rest, session end, or sensors;
- use one Attempt anchor and resolve only the outcomes that the user actually confirms.

The first option increases capture burden, the second destroys project/failure history, and the third overclaims uncertain evidence. The chosen model preserves one-tap capture and honest unknowns while keeping a review path for richer meaning.

## Consequences

- Watch P0 requires `Record Attempt`, optional `Mark Send`, and exact-target `Undo`; it does not require `Fail`.
- `not_sent` is a confirmed outcome, not a synonym for `FailureEpisode`.
- Starting rest, switching routes, starting another Attempt, ending a GymVisit, or receiving sensor evidence never resolves an Attempt automatically.
- `Mark Send` never increments attempt count.
- A missed Attempt or Send can be added or corrected during review with visible provenance.
- `RouteCard.status = new/active_project/sent/archived/gone` is retired as the canonical storage model. Presentation labels may still be derived.
- A material route reset creates a successor RouteCard; it does not rewrite the predecessor.
- Sending, archiving, or losing a route closes one Project cycle. Reopening starts another cycle unless the prior transition itself was mistaken and explicitly corrected.
- Sync and persistence designs must preserve stable event identity, causal targets, duplicates, delays, and conflicts.
- Active PRD, gate, platform, data-collection, and context documents must be updated to this vocabulary before implementation issues are cut.

## Superseded Parts Of Earlier Decisions

This ADR supersedes these parts of ADR 3:

- “Watch owns `Try`, `Send`, `Fail`, and `Undo`.”
- any implication that Project progress is stored only as RouteCard status.

ADR 3 remains active for the canonical P0 object chain, `MoveCue` terminology, `FailureEpisode` as the bridge to learning, and thin `SuggestionProvenance`.
