# LineWise PRD v0.1

Date: 2026-07-13
Status: Historical. Superseded by `docs/linewise_prd_v1_0.md` (v1.0 on 2026-09-12, now v1.1) and ADR 4. Kept as the record of the July 2026 thinking; do not implement from it.
Product: LineWise / 线感  
Scope: Indoor bouldering, iPhone + optional Apple Watch capture

## 1. Problem Statement

Indoor bouldering users do not only need a workout log. They need a way to remember routes, attempts, failure points, movement cues, and what to try next time.

Today, the user's real workflow is fragmented:

- Apple Watch records time, heart rate, and workout completion.
- The gym app, if one exists, may show route inventory or rankings.
- Photos and videos live in the camera roll.
- movement cues from friends or coaches disappear in chat or memory.
- repeated projects are tracked mentally, in notes, or not at all.

This means the user often leaves a gym knowing they trained, but cannot reliably answer:

- Which route did I project?
- What did I try?
- Where did I fail?
- What should I remember next time?
- Which failure pattern keeps repeating?

LineWise solves the memory gap between a real bouldering session and the next attempt. The July 2026 research refresh also establishes that route/video logging, public Beta, photo search, and generic AI analysis are already active competitive categories. P0 must therefore prove a more specific value: a failure becomes one retrievable MoveCue and an explicit next-attempt ProofCheck.

## 2. Solution

LineWise is an indoor bouldering line-reading and training companion.

P0 proves a manual-first memory and proof loop:

```text
RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue -> ProofCheck
```

Capture can come from Apple Watch, iPhone quick capture, or review-only entry. P0.5 turns that loop into a structured personal dataset:

```text
Route photos + user corrections + attempts + failure reasons + MoveCues + Watch timeline
```

Later phases can use this dataset for AI-assisted `RouteRead`, `StickFigureCue`, `SetterLens`, and `TrainingPath`, but P0 must work without AI.

## 3. Target Users

| Persona | Description | Primary Need | P0 Value |
| --- | --- | --- | --- |
| Frequent indoor boulderer | Goes to the gym 1-3 times per week and repeats projects | Remember what to try next | RouteCard + NextSessionCue |
| Progress-focused beginner/intermediate | Wants to understand why they fail | Convert failed attempts into simple movement cues | FailureEpisode + MoveCue |
| Apple Watch boulderer | Already records workouts, is willing to wear a Watch, and the gym permits it | Reduce attempt/rest capture friction | Optional Watch capture + iPhone review |
| No-Watch boulderer | Does not wear a Watch because of comfort, damage, snag, or gym-policy concerns | Preserve the same route/failure memory without live wrist capture | iPhone quick capture or review-only mode |
| Data/AI early adopter | Willing to label routes to enable future AI | Build a personal climbing dataset | P0.5 annotation protocol |
| Coach/friend observer | Gives short advice or records video | Preserve useful guidance | Private sharing later, not P0 |

Primary P0 user:

> A weekly indoor boulderer who projects routes and wants to remember what failed and what to try next without turning training into admin work. Apple Watch is an optional advantage, not an eligibility requirement.

## 4. Product Principles

1. **Recall over recap.** A session summary matters only if it helps the next visit.
2. **RouteCard first.** Attempt counts detached from route/project context are weak data.
3. **Multi-mode capture.** Watch is an optional low-interruption surface, not a route editor or a required device.
4. **iPhone owns review.** Photos, route details, failure reasons, and movement cues belong on iPhone.
5. **Manual-first, AI-later.** P0 does not depend on automatic route reading.
6. **Suggested, not detected.** Sensor or AI outputs are editable suggestions.
7. **Private by default.** Personal route memory comes before public social or partner matching.
8. **Proof over advice.** A cue is not treated as useful until the user can test and update it on a later attempt.

## 5. Core User Journey

| Stage | User Job | LineWise Behavior | P0/P0.5 |
| --- | --- | --- | --- |
| Before gym | Remember last projects | Show recent Project cards and NextSessionCue | P0 |
| Start session | Begin recording without friction | Start Watch workout when eligible, or begin an iPhone/review-only local visit | P0 |
| Find route | Create or select RouteCard | Minimal route identity: label, color, wall area, grade, optional photo | P0/P0.5 |
| Attempt | Preserve meaningful attempts without mandatory per-attempt admin | Watch one-tap, iPhone quick capture, or review-only batch entry | P0 |
| Rest | Pace next attempt | Rest timer and sparse haptic cue | P0 |
| Review | Convert attempt into memory | iPhone timeline, FailureEpisode, MoveCue, project status | P0 |
| Leave gym | Preserve next action | Save NextSessionCue | P0 |
| Next visit | Resume project intelligently | Show what to try first and what cue to remember | P0 |
| Proof | Decide whether the remembered cue helped | `worked`, `no_change`, `different_problem`, or edited cue | P0 |
| Dataset mode | Build AI foundation | Add route photo annotations and correction events | P0.5 |

## 6. P0 Scope

### 6.1 iPhone: Route Memory

P0 must support RouteCards with these fields:

| Field | Required | Notes |
| --- | --- | --- |
| `id` | yes | Local durable ID |
| `label` | yes | User-facing name, e.g. "blue slab left" |
| `gym_label` | optional | Manual text or recent gym preset; no GPS dependency |
| `wall_area` | optional | e.g. "slab wall", "cave", "front left" |
| `route_color` | optional | Color or tag style |
| `route_number_or_tag` | optional | Official/user-visible number, symbol, or tape label |
| `start_anchor` | optional | Short start-location description when color is ambiguous |
| `grade_text` | optional | Keep as text because gyms use varied systems |
| `subjective_grade` | optional | User's felt difficulty |
| `status` | yes | `new`, `active_project`, `sent`, `archived`, `gone` |
| `photo_ref` | optional P0 / important P0.5 | Use explicit user-selected/captured photo only |
| `created_at`, `updated_at` | yes | Local auditing |
| `recorded_for_date` | yes | Actual gym date; must support historical entry and cross-midnight visits |
| `source` | yes | `watch`, `iphone`, `review`, `health_import`, `fit_import`, `photo_import`, or `manual_history` |

Route identity must not require an official gym database.

Route identity must not depend on color alone. The UI should make at least two anchors available from label, wall area, start location, photo, official/user tag, or color name.

### 6.2 Capture Modes

P0 must use one canonical event model across three modes:

| Mode | Use Case | Contract |
| --- | --- | --- |
| `watch_capture` | User is willing to wear a Watch and the gym permits it | Workout, rest timer, one-tap outcome, local queue, eventual sync |
| `iphone_quick_capture` | User does not wear a Watch but can access the phone between attempts | Large controls, short voice/text cue, no long form |
| `review_only` | User wants zero in-session interaction | Batch attempts and one representative failure after the session |

No domain object may require a Watch-only identifier or sensor sample.

`manual_history` is a record origin, not a fourth in-session capture mode. It lets the user reconstruct a past visit, choose the true date, and save incomplete but explicit facts through the iPhone review surface.

### 6.3 Watch: Session Capture

Watch P0 actions when this mode is used:

- Start session
- End session
- Select or continue current project
- Mark `Try`
- Mark `Send`
- Mark `Fail`
- Undo last event
- See current rest timer
- Receive sparse rest haptic if enabled

Watch must also show a concise reminder to follow gym rules and stop using the Watch if it interferes with climbing. Product copy must not claim that wearing a Watch while bouldering is universally safe.

Watch P0 non-actions:

- no route photo editing;
- no long text;
- no failure taxonomy selection;
- no AI route reading;
- no detailed HealthKit troubleshooting;
- no social or coach workflow.

### 6.3.1 External Record Import

P0 data modeling must leave room for Apple Health, FIT, and Photos imports. Import UI may ship in P0.5, but the canonical model must not assume every GymVisit originated in LineWise.

Import contract:

- preview before committing;
- preserve source and source ID/hash;
- never convert an imported workout segment directly into a confirmed Attempt;
- detect likely duplicates without deleting user data automatically;
- allow the user to attach imported session/media to RouteCards afterward;
- support undoing an import as one operation;
- do not upload HealthKit data to cloud AI.

### 6.4 Attempt Events

Canonical P0 event vocabulary:

| Event | Meaning | Capture Surface |
| --- | --- | --- |
| `Try` | User made an attempt without specifying outcome yet | Watch |
| `Send` | User completed the route | Watch |
| `Fail` | User did not complete the route | Watch |
| `Undo` | Remove or reverse last event | Watch |
| `Flash` | Sent on first attempt | iPhone review or optional quick result, not required as a separate Watch button |

`Flash` is valuable but should not add Watch UI burden unless field tests prove it is needed.

Users may log only meaningful attempts. P0 must test whether `Try` is useful or redundant with `Fail`; the data model may retain `Try`, but the final Watch layout is not settled until field testing.

### 6.5 iPhone: Review

P0 review should answer:

- What did I try today?
- Which RouteCards became projects?
- Where did I fail?
- What MoveCue should I remember?
- What is the next action when I return?

Review must support:

- edit attempt timeline;
- attach attempt to RouteCard;
- mark Project status;
- add one primary FailureEpisode per meaningful failure;
- add one short MoveCue;
- create or update NextSessionCue.
- complete a ProofCheck when a prior cue is retried.

### 6.6 FailureEpisode

`FailureEpisode` converts a failed attempt into learning.

P0 fields:

| Field | Meaning |
| --- | --- |
| `route_card_id` | Route where failure happened |
| `attempt_id` | Attempt that produced the failure |
| `primary_blocker` | One main reason, selected from a short taxonomy |
| `location_note` | Optional text or route/photo position |
| `move_cue_id` | Optional cue linked to this failure |
| `confidence` | `user_confirmed`, `suggested`, or `unknown` |

P0 blocker taxonomy should stay short:

- `sequence`
- `footwork`
- `body_position`
- `body_tension`
- `dynamic_timing`
- `reach_or_lockoff`
- `hook_or_compression`
- `topout_or_finish`
- `fear_or_commitment`
- `endurance_or_pacing`
- `unknown`

Only one primary blocker is required. Secondary tags can wait.

### 6.7 MoveCue

`MoveCue` is the user-facing replacement for "beta."

Good examples:

- "Left foot high before right hand."
- "Keep hip close before moving."
- "Wait for swing to settle."
- "Flag right foot instead of cutting."

MoveCue can be:

- user-written text;
- voice-to-text later;
- friend/coach note;
- future AI-suggested and user-confirmed cue.

### 6.8 NextSessionCue And ProofCheck

NextSessionCue is the product's strongest recall object.

It should include:

- RouteCard reference;
- project status;
- one remembered blocker;
- one MoveCue;
- one next action;
- optional "route may be gone" state.

Example:

```text
Blue slab left, V3-ish.
Last blocker: foot trust.
Try: left foot high, shift hip before right hand.
```

`ProofCheck` closes the loop after the user retries the route:

| Result | Meaning |
| --- | --- |
| `worked` | The cue materially improved the attempt |
| `no_change` | The cue was tried but did not help |
| `different_problem` | The original blocker changed or another blocker became primary |
| `not_tested` | The route was gone, skipped, or not retried |

The user may edit the MoveCue after the check. This acceptance/edit/rejection trail is more valuable for future personalization than an unverified AI suggestion.

## 7. P0.5 Scope: PersonalClimbingDataset

P0.5 begins structured data collection for future AI.

It adds:

- route photo import or capture with explicit user action;
- wall-context photo and route-focused photo;
- hold/volume annotation;
- route color or tag mode;
- start/top/zone roles;
- failure point marking;
- correction events;
- optional short attempt video with consent;
- data quality state.

P0.5 does not promise automatic route reading. It makes route reading possible later.

## 8. P1/P2 Future Scope

| Phase | Feature | Boundary |
| --- | --- | --- |
| P1 | RouteRead | Suggested route read from photo, always editable |
| P1 | StickFigureCue | 3 keyframes or editable movement cards, not physical truth |
| P1/P2 | SetterLens | Inferred unless setter-authored |
| P2 | TrainingPath | Triggered by repeated FailureEpisodes, not a browsable course library first |
| P2/P3 | ClimbingBuddy | AI/private friend sharing first; no open matching until safety and moderation exist |

## 9. User Stories

1. As a boulderer, I want to create a minimal route card in about 10 seconds, so that I can remember the route without interrupting training.
2. As a boulderer who can wear a Watch, I want to mark meaningful try/send/fail events from my wrist, so that I do not need to take out my phone.
3. As a boulderer, I want to undo the last Watch event, so that accidental taps do not pollute my session.
4. As a boulderer, I want to see a rest timer after an attempt, so that I can pace retries without opening another timer app.
5. As a boulderer, I want to review my attempts on iPhone, so that I can correct mistakes after training.
6. As a boulderer, I want to add a short movement cue, so that I remember what to try next time.
7. As a boulderer, I want to mark where I failed, so that repeated failures can become training signals.
8. As a project-focused user, I want active project cards, so that I can return to unfinished routes.
9. As a returning user, I want next-session cues, so that I know what to try first when I arrive.
10. As a privacy-conscious user, I want my records local by default, so that my gym behavior and health data are not exposed.
11. As a user who denies HealthKit permissions, I still want to record RouteCards and attempts, so that the app remains useful.
12. As a data-focused user, I want exportable structured records, so that I can inspect my own dataset.
13. As a future AI user, I want to correct route photo suggestions, so that LineWise learns from trustworthy data.
14. As a coach-assisted user, I want to save a coach's note to a route, so that advice survives beyond the session.
15. As a user whose route has been reset, I want to archive it as gone, so that my project history stays meaningful.
16. As a boulderer who does not wear a Watch, I want quick-capture and review-only modes, so that the product remains useful and safe for my situation.
17. As a returning user, I want to mark whether a previous MoveCue worked, so that LineWise learns from results instead of accumulating unverified advice.

## 10. Implementation Decisions

No production implementation has started yet. These decisions define the first implementation direction.

- Use a local-first data model. Cloud sync can come later.
- Watch owns workout/session start and low-interruption event capture only in `watch_capture` mode.
- iPhone quick capture and review-only entry must create the same canonical Attempt and FailureEpisode objects.
- iPhone owns RouteCards, review, corrections, movement cues, and dataset annotation.
- HealthKit workout data is a supporting system record. App-private objects are the source of truth for bouldering semantics.
- Sensor inference must produce `SuggestedTimeline` or `SuggestionProvenance`, never ground truth.
- The P0 model should include `GymVisit`, `RouteCard`, `Project`, `Attempt`, `RestInterval`, `FailureEpisode`, `MoveCue`, `NextSessionCue`, `ProofCheck`, `CorrectionEvent`, and thin `SuggestionProvenance`.
- `Photo`, `HoldInstance`, `RouteGroup`, `RouteRole`, and `MoveSequence` belong to P0.5 dataset mode, not the minimum P0 loop.
- `ClimberContext` is optional P1 context, not required profile setup. It may store self-reported height/reach ranges, experience, preferences, and constraints only with explicit user action.
- `Flash` is a result attribute, not a required Watch button.
- No open social graph, public feed, or stranger matching in P0/P1.

## 11. Testing Decisions

Testing should verify behavior from user-visible outcomes, not internal implementation details.

P0 tests should cover:

- RouteCard can be created, edited, archived, and marked gone.
- RouteCard remains identifiable when color is unavailable or ambiguous.
- Historical entry preserves the selected date, timezone, and source across midnight boundaries.
- Watch event stream can create try/send/fail/undo events.
- iPhone quick capture and review-only flows can create equivalent canonical events.
- Attempt events survive temporary phone disconnection.
- Review can attach attempts to RouteCards and create NextSessionCue.
- HealthKit denied state still allows local session recording.
- Sync retries do not duplicate attempts.
- Low-power or disconnected states preserve local data.
- User corrections override suggestions.
- ProofCheck can accept, reject, or revise a MoveCue without losing provenance.
- Export/debug view exposes enough data for field validation.
- Health/FIT/Photos import preview does not create confirmed Attempt events before user approval.
- Re-importing the same external record does not duplicate a GymVisit.
- Undo import restores the prior local state.

Field tests must cover:

- at least 3 real gym visits by the primary user;
- Watch tap burden during actual attempts/rests;
- RouteCard creation time;
- next-session reopen behavior;
- battery use and sync reliability;
- photo/annotation friction if P0.5 is enabled.

## 12. Success Metrics

| Metric | Target |
| --- | --- |
| Minimal RouteCard creation time | median <= 10 seconds; P90 <= 20 seconds |
| Watch action burden | 1-2 taps after a meaningful attempt when Watch mode is used |
| Core event local save success | >= 99% |
| Review open rate | >= 60% of completed sessions |
| NextSessionCue creation | >= 50% of reviewed sessions |
| NextSessionCue reuse | >= 50% of next gym visits |
| Project revisit rate | >= 40% within next two visits |
| User-rated usefulness | >= 7/10 after 3 sessions |
| Data quality for P0.5 | 30 RouteCards and 100 attempts before AI work |
| ProofCheck completion | >= 30% of reused NextSessionCues |
| Watch eligibility | Measure willingness, gym permission, comfort, and protection separately; not a product-wide hard gate |
| Historical entry integrity | 100% of test records preserve selected date/timezone and source |
| Route identity redundancy | 100% of field-test projects can be found using two non-exclusive anchors |
| Import idempotency | Re-import creates 0 duplicate canonical visits |
| Suggested correction cost | Median correction must be faster than manual reconstruction before automation graduates |

## 13. Out Of Scope For P0

- Full automatic route reading.
- Automatic send/fail judgment.
- Real-time technique coaching.
- Medical, safety, recovery, or injury-prevention advice.
- Public feed, ranking, or open social matching.
- Public Beta/video community or general-purpose media cloud.
- Official gym route database.
- Coach dashboard.
- Gym SaaS.
- Outdoor guidebook or topo.
- Rope climbing modes.
- Complex video analysis.
- Automatic routesetter intent.
- Monthly subscription.

## 14. P0 Red Lines

- Do not require precise location.
- Do not require full photo library access.
- Do not upload HealthKit data to cloud AI.
- Do not use health data for ads or profiling.
- Do not make safety or medical claims.
- Do not present AI output as official route truth.
- Do not require gym partnership for core value.
- Do not let Watch UI become a route editor.
- Do not use color as the only route identifier.
- Do not infer sex, body capability, injury state, or reach from media without an explicit future consented feature.
- Do not turn imported workout segments into confirmed attempts automatically.
- Do not require real-time recording; historical and review-only entry are first-class.

## 15. Open Questions

These questions should be resolved by prototype or field testing:

- Is a minimal RouteCard useful without a photo, or is optional photo capture needed immediately?
- Does the user reliably tap Watch after every attempt, or only after meaningful attempts?
- Which capture mode wins for each user: Watch, iPhone quick capture, or review-only?
- Is `Try` useful as a separate action, or should Watch only expose outcome-first `Fail`, `Send`, and `Undo`?
- Should NextSessionCue appear on Watch before a session or only on iPhone?
- How many FailureEpisode categories can users tolerate?
- Should MoveCue start as text, voice, tags, or all three?
- Should P0 include data export from day one?
- Which import should ship first after the model is ready: Apple Health, FIT, or Photos timeline?
- Which two route anchors are fastest in the primary user's real gyms when colors overlap?
- Does optional height/reach context improve cue relevance enough to justify collecting it?
- Can photo annotation be made faster than writing a note?
- How often do gyms restrict route photography?
- What is the first paid boundary, if any?
- Does ProofCheck create enough repeat value to differentiate LineWise from video/logbook competitors?

## 16. References

- `docs/project_background.md`
- `docs/climbing_bouldering_mvp_gate.md`
- `docs/climbing_bouldering_data_collection_plan.md`
- `docs/climbing_bouldering_platform_contract.md`
- `CONTEXT.md`
- `docs/adr/0001-gym-visit-memory-system.md`
- `docs/adr/0002-linewise-expanded-product-vision.md`
