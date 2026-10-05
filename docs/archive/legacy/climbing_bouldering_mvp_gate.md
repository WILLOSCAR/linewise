# LineWise MVP Gate

Date: 2026-07-13
Status: Historical. Demo exit criteria and metrics now live in PRD v1.1 §10–§12. Kept for reference.

## 1. Purpose

This document defines what must be proven before LineWise moves from requirements into implementation, and what must be proven before P0 expands into AI route reading, training content, partner workflows, or gym integrations.

LineWise should not scale complexity until it proves the private memory loop:

```text
capture -> failure -> cue -> next-session recall -> proof
```

## 2. Gate Summary

| Gate | Question | Go Criteria | No-Go Signal |
| --- | --- | --- | --- |
| G1: Route memory | Can users create useful RouteCards quickly? | Median <= 10 sec, P90 <= 20 sec; user saves 2+ meaningful routes per visit | User prefers camera roll/notes |
| G2: Capture fit | Which capture mode helps without interrupting climbing? | Watch, iPhone quick, or review-only produces usable events with low annoyance | All modes feel like admin |
| G3: Review value | Does review produce better next-session memory? | >= 60% sessions reviewed; clear NextSessionCue | Review feels like admin |
| G4: Recall value | Does the user reopen before next gym visit? | >= 50% next-visit reopen | User never checks old records |
| G5: Data quality | Can P0.5 produce useful AI training data? | 30 RouteCards + 100 attempts + corrections | Photos/labels too noisy |
| G6: Platform reliability | Does local persistence and Watch/iPhone sync survive real gym conditions? | >= 99% core-event local-save success; delayed sync does not duplicate | Lost attempts or duplicate sync |
| G7: Trust | Are suggestions understood as editable? | User corrects without losing trust | User treats suggestions as wrong facts |
| G8: Proof | Does a saved cue change a later attempt? | >= 30% reused cues receive a ProofCheck | Cues are never tested or updated |
| G9: Data integrity | Can users backfill, import, correct, and export without silent corruption? | Dates/sources preserved; re-import is idempotent; import preview creates no confirmed Attempt | Wrong dates, duplicates, stale sync, or untraceable facts |
| G10: Inclusive identity | Can a route be found without relying on color alone? | Every active Project has at least two usable anchors | Color ambiguity causes wrong RouteCard/Attempt |

## 3. P0 Go/No-Go

P0 can proceed to implementation when the team can clearly specify:

- RouteCard minimum fields;
- canonical event vocabulary across Watch, iPhone quick capture, and review-only modes;
- iPhone review flow;
- NextSessionCue format;
- local storage and sync rules;
- HealthKit permission behavior;
- historical-entry date/source behavior;
- import preview, idempotency, undo, and export rules;
- route identity fallback when color is missing or ambiguous;
- real-device validation plan.

P0 should not proceed if:

- the product is still framed as generic workout tracking;
- AI route reading is required for core value;
- the Watch UI requires complex route editing;
- the core product requires wearing a Watch;
- the app depends on gym partnership;
- the route memory loop has no field test plan.

## 4. P0 Success Metrics

| Metric | Definition | Target |
| --- | --- | --- |
| `route_card_creation_time` | Time to create a minimum RouteCard | median <= 10 sec; P90 <= 20 sec |
| `route_card_per_session` | Meaningful RouteCards created per gym visit | >= 2 |
| `watch_action_taps` | Tap count after an attempt | <= 2 |
| `watch_annoyance_score` | User-rated interruption, 1-10 | <= 3 |
| `core_event_local_save_rate` | Core events saved locally without data loss | >= 99% |
| `review_open_rate` | Completed sessions opened in review | >= 60% |
| `next_session_cue_rate` | Reviewed sessions with a cue saved | >= 50% |
| `pre_session_reopen_rate` | Next visit begins by reopening LineWise | >= 50% |
| `project_revisit_rate` | Active projects revisited in next two visits | >= 40% |
| `manual_correction_rate` | Suggested items requiring correction | Track only; high is acceptable early |
| `user_usefulness_score` | User rating after three visits | >= 7/10 |
| `proof_check_rate` | Reused cues explicitly evaluated on a later attempt | >= 30% |
| `watch_eligibility` | Willingness, gym permission, comfort, and protection | Measure separately; not a product-wide gate |
| `historical_entry_integrity` | Selected date/timezone/source survive save and reopen | 100% in test matrix |
| `import_duplicate_rate` | Duplicate canonical visits after same import is repeated | 0% |
| `route_anchor_coverage` | Active projects with two usable identity anchors | 100% |
| `suggestion_correction_time` | Time to correct an automatic/import suggestion | Must be faster than manual reconstruction before default automation |

## 5. P0.5 Dataset Gate

Do not start serious AI route-reading work until the dataset gate is met.

Minimum dataset:

| Data | Minimum |
| --- | --- |
| RouteCards | 30 |
| Attempts | 100 |
| Sessions | 3-5 real gym visits |
| Route photos | 30, with at least 10 difficult cases |
| Start/top annotations | 20 routes |
| Hold/route grouping annotations | 20 routes |
| FailureEpisodes | 30 |
| MoveCues | 20 |
| Watch timelines | 3+ full sessions |
| CorrectionEvents | Every model/user correction captured once P0.5 begins |

Better target before P1:

- 100 RouteCards;
- 500 attempts;
- 200 corrected route photos;
- 50 routes with start/top/hold annotations;
- 20 short attempt videos with explicit consent and no unrelated people visible.

## 6. Field Test Protocol

Run at least 3 real gym visits before declaring P0 design valid.

### Visit 1: Review-Only Memory

Goal: Test RouteCard and review value without relying on Watch.

Record:

- 3-5 RouteCards;
- route label, color, wall area, grade if visible;
- status after session;
- one MoveCue for at least two projects;
- one NextSessionCue.

Pass if:

- creating RouteCards does not feel worse than camera roll/notes;
- next-session cue feels useful the next day.

### Visit 2: Watch Or iPhone Quick Capture

Goal: Test Watch action burden.

If the user is willing and the gym permits Watch wear, record:

- Start/End session;
- Try/Send/Fail/Undo;
- rest timer;
- local save behavior;
- battery impact;
- sync behavior after phone reconnection.

Pass if:

- Watch does not feel intrusive;
- no attempt data is lost;
- user still wants to use it next session.

If Watch is not eligible, run the same visit with iPhone quick capture. In either case, the canonical objects and review output must match.

### Visit 3: Dataset Mode

Goal: Test P0.5 photo/annotation friction.

Record:

- wall-context photo;
- route-focused photo;
- hold/route grouping for 3 routes;
- start/top annotations;
- failure point or FailureEpisode;
- correction time.

Pass if:

- correcting a suggested/blank route is faster than starting over in notes;
- photo capture does not violate gym comfort, privacy, or rules.

### Visit 4: Proof Loop

Goal: Test whether the product changes a later attempt.

Record:

- reopen one active Project;
- show exactly one NextSessionCue;
- ask the user to try it when appropriate;
- record `worked`, `no_change`, `different_problem`, or `not_tested`;
- allow the MoveCue to be edited.

Pass if:

- the user can recall the prior context without opening old media manually;
- the ProofCheck feels useful rather than like a survey;
- at least one cue is confirmed or meaningfully revised.

### Visit 5: Integrity And Accessibility

Goal: Test the boring requirements that determine long-term trust.

Record:

- one past visit with an explicitly selected historical date;
- one cross-midnight or timezone fixture;
- one Apple Health/FIT/Photos import preview fixture when available;
- repeat the same import;
- one route identified without color, using wall area + start/photo/tag;
- export the full local record and reopen it in the debug viewer.

Pass if:

- dates and sources remain correct;
- repeated import creates no duplicate visit;
- no imported segment becomes a confirmed Attempt before review;
- the project can be found even when route colors are hidden or ambiguous;
- exported facts, suggestions and corrections remain distinguishable.

## 7. Watch-Specific Validation

Must test on a real Apple Watch paired with a real iPhone.

Simulator is not enough for:

- HKWorkoutSession lifecycle;
- heart rate behavior;
- wrist lock and screen-off behavior;
- Low Power Mode;
- haptic timing;
- WatchConnectivity background delivery;
- phone absent or network-poor gym conditions;
- battery drain.

## 8. Trust Gate

LineWise must preserve trust by making every uncertain output editable.

Trust requirements:

- AI/sensor/motion outputs are labeled `suggested`.
- User-confirmed data visibly overrides suggested data.
- Correction history is preserved enough for debugging.
- The UI never implies automatic send/fail truth.
- App copy avoids medical, safety, or recovery claims.
- Imported, inferred, coach-authored, setter-authored, and user-confirmed facts remain distinguishable.

## 9. Expansion Gate

Do not expand beyond P0/P0.5 unless:

- P0 recall loop passes field test;
- users create and reuse NextSessionCue;
- Watch tap burden is acceptable;
- dataset quality is good enough for controlled AI experiments;
- privacy red lines remain intact.
- G9 data integrity and G10 inclusive identity pass before any large import or gym integration.

Expansion is blocked if the product still cannot answer:

```text
What did I try, where did I fail, and what should I try next time?
```

## 10. Decision After Gate

| Outcome | Action |
| --- | --- |
| P0 passes, P0.5 not ready | Build private alpha without AI |
| P0 passes, P0.5 passes | Start RouteRead prototype |
| P0 fails due to Watch burden | Try iPhone-only or fewer Watch actions |
| P0 fails due to RouteCard burden | Reduce fields or postpone photo |
| Recall fails | Rework NextSessionCue before adding features |
| Proof fails | Do not add AI advice; improve cue quality and retrieval first |
| Trust fails | Remove automation until manual loop works |
| Integrity fails | Freeze imports/sync expansion and fix provenance, date, idempotency, and recovery |
| Color-only identity fails | Require a second route anchor before expanding route automation |
