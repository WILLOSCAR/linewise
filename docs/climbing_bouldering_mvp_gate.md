# LineWise MVP Gate

Date: 2026-07-01  
Status: Active validation gate for P0/P0.5

## 1. Purpose

This document defines what must be proven before LineWise moves from requirements into implementation, and what must be proven before P0 expands into AI route reading, training content, partner workflows, or gym integrations.

LineWise should not scale complexity until it proves the private memory loop:

```text
capture -> review -> next-session recall
```

## 2. Gate Summary

| Gate | Question | Go Criteria | No-Go Signal |
| --- | --- | --- | --- |
| G1: Route memory | Can users create useful RouteCards quickly? | Minimal RouteCard <= 30 sec; user creates 3+ per session | User prefers camera roll/notes |
| G2: Watch burden | Does Watch capture help without interrupting climbing? | 1-2 taps per attempt; low annoyance | User stops tapping by session 2 |
| G3: Review value | Does review produce better next-session memory? | >= 60% sessions reviewed; clear NextSessionCue | Review feels like admin |
| G4: Recall value | Does the user reopen before next gym visit? | >= 50% next-visit reopen | User never checks old records |
| G5: Data quality | Can P0.5 produce useful AI training data? | 30 RouteCards + 100 attempts + corrections | Photos/labels too noisy |
| G6: Platform reliability | Does Watch/iPhone sync survive real gym conditions? | >= 95% session local-save success | Lost attempts or duplicate sync |
| G7: Trust | Are suggestions understood as editable? | User corrects without losing trust | User treats suggestions as wrong facts |

## 3. P0 Go/No-Go

P0 can proceed to implementation when the team can clearly specify:

- RouteCard minimum fields;
- Watch event vocabulary;
- iPhone review flow;
- NextSessionCue format;
- local storage and sync rules;
- HealthKit permission behavior;
- real-device validation plan.

P0 should not proceed if:

- the product is still framed as generic workout tracking;
- AI route reading is required for core value;
- the Watch UI requires complex route editing;
- the app depends on gym partnership;
- the route memory loop has no field test plan.

## 4. P0 Success Metrics

| Metric | Definition | Target |
| --- | --- | --- |
| `route_card_creation_time` | Time to create a minimum RouteCard | <= 30 sec |
| `route_card_per_session` | Meaningful RouteCards created per gym visit | >= 3 |
| `watch_action_taps` | Tap count after an attempt | <= 2 |
| `watch_annoyance_score` | User-rated interruption, 1-10 | <= 3 |
| `session_local_save_rate` | Sessions saved locally without data loss | >= 95% |
| `review_open_rate` | Completed sessions opened in review | >= 60% |
| `next_session_cue_rate` | Reviewed sessions with a cue saved | >= 50% |
| `pre_session_reopen_rate` | Next visit begins by reopening LineWise | >= 50% |
| `project_revisit_rate` | Active projects revisited in next two visits | >= 40% |
| `manual_correction_rate` | Suggested items requiring correction | Track only; high is acceptable early |
| `user_usefulness_score` | User rating after three visits | >= 7/10 |

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

### Visit 1: Manual Memory

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

### Visit 2: Watch Capture

Goal: Test Watch action burden.

Record:

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

## 9. Expansion Gate

Do not expand beyond P0/P0.5 unless:

- P0 recall loop passes field test;
- users create and reuse NextSessionCue;
- Watch tap burden is acceptable;
- dataset quality is good enough for controlled AI experiments;
- privacy red lines remain intact.

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
| Trust fails | Remove automation until manual loop works |
