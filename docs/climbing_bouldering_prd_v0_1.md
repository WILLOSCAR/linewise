# LineWise PRD v0.1

Date: 2026-07-01  
Status: Active P0/P0.5 product requirements draft  
Product: LineWise / 线感  
Scope: Indoor bouldering, Apple Watch + iPhone

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

LineWise solves the memory gap between a real bouldering session and the next attempt.

## 2. Solution

LineWise is an indoor bouldering line-reading and training companion.

P0 proves a manual-first memory loop:

```text
RouteCard -> Watch attempt/rest capture -> iPhone review -> NextSessionCue -> next gym visit
```

P0.5 turns that loop into a structured personal dataset:

```text
Route photos + user corrections + attempts + failure reasons + MoveCues + Watch timeline
```

Later phases can use this dataset for AI-assisted `RouteRead`, `StickFigureCue`, `SetterLens`, and `TrainingPath`, but P0 must work without AI.

## 3. Target Users

| Persona | Description | Primary Need | P0 Value |
| --- | --- | --- | --- |
| Frequent indoor boulderer | Goes to the gym 1-3 times per week and repeats projects | Remember what to try next | RouteCard + NextSessionCue |
| Progress-focused beginner/intermediate | Wants to understand why they fail | Convert failed attempts into simple movement cues | FailureEpisode + MoveCue |
| Apple Watch boulderer | Already records workouts but wants bouldering semantics | Add attempt/rest/project layer over workout data | Watch capture + iPhone review |
| Data/AI early adopter | Willing to label routes to enable future AI | Build a personal climbing dataset | P0.5 annotation protocol |
| Coach/friend observer | Gives short advice or records video | Preserve useful guidance | Private sharing later, not P0 |

Primary P0 user:

> A weekly indoor boulderer who wears Apple Watch, projects routes, and wants to remember what failed and what to try next without turning training into admin work.

## 4. Product Principles

1. **Recall over recap.** A session summary matters only if it helps the next visit.
2. **RouteCard first.** Attempt counts detached from route/project context are weak data.
3. **Low-interruption Watch.** Watch is a capture surface, not a route editor.
4. **iPhone owns review.** Photos, route details, failure reasons, and movement cues belong on iPhone.
5. **Manual-first, AI-later.** P0 does not depend on automatic route reading.
6. **Suggested, not detected.** Sensor or AI outputs are editable suggestions.
7. **Private by default.** Personal route memory comes before public social or partner matching.

## 5. Core User Journey

| Stage | User Job | LineWise Behavior | P0/P0.5 |
| --- | --- | --- | --- |
| Before gym | Remember last projects | Show recent Project cards and NextSessionCue | P0 |
| Start session | Begin recording without friction | Start Watch climbing session and local app session | P0 |
| Find route | Create or select RouteCard | Minimal route identity: label, color, wall area, grade, optional photo | P0/P0.5 |
| Attempt | Record that one try happened with low interruption | Watch one-tap Attempt anchor; optional Send result | P0 |
| Rest | Pace next attempt | Rest timer and sparse haptic cue | P0 |
| Review | Resolve only what is known and convert useful failures into memory | Review Inbox, explicit result, FailureEpisode, MoveCue, Project cycle | P0 |
| Leave gym | Preserve next action | Save NextSessionCue | P0 |
| Next visit | Resume project intelligently | Show what to try first and what cue to remember | P0 |
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
| `grade_text` | optional | Keep as text because gyms use varied systems |
| `subjective_grade` | optional | User's felt difficulty |
| `record_visibility` | yes | `active`, `archived`, or `merged` |
| `availability` | yes | `unknown`, `present`, or `gone` |
| `successor_route_card_id` | optional | New physical route incarnation after a material reset; old history remains unchanged |
| `photo_ref` | optional P0 / important P0.5 | Use explicit user-selected/captured photo only |
| `created_at`, `updated_at` | yes | Local auditing |

Route identity must not require an official gym database. Project progress and send history are separate from RouteCard visibility and availability; user-facing labels such as "active project" or "sent" are derived.

P0 must also support repeatable Project cycles:

| Field | Required | Notes |
| --- | --- | --- |
| `id` | yes | Durable Project-cycle identity |
| `route_card_id` | yes | Exactly one RouteCard incarnation |
| `state` | yes | `active`, `sent`, `archived`, or `gone` |
| `started_at` | yes | Start of this revisit intention |
| `closed_at` | optional | Required for a terminal cycle |
| `supporting_attempt_id` | required when sent | Active sent Attempt on the same RouteCard |

A RouteCard may have several historical Project cycles but at most one active Project.

### 6.2 Watch: Session Capture

Watch P0 actions:

- Start session
- End session
- Select or continue current project
- `Record Attempt` with one primary tap
- optionally `Mark Send` on the selected or just-recorded Attempt
- exact-target `Undo` for the last reversible Watch action
- See current rest timer
- Receive sparse rest haptic if enabled

Watch P0 non-actions:

- no route photo editing;
- no long text;
- no failure taxonomy selection;
- no AI route reading;
- no detailed HealthKit troubleshooting;
- no social or coach workflow.

### 6.3 Attempt And Result Events

Canonical P0 event vocabulary:

| Event | Meaning | Capture Surface |
| --- | --- | --- |
| `Record Attempt` | Create one Attempt with outcome `unresolved` | Watch or iPhone degraded path |
| `Mark Send` | Change one existing Attempt to user-confirmed `sent`; never create another Attempt | Watch or iPhone review |
| `Confirm Not Sent` | Change one existing Attempt to user-confirmed `not_sent` | iPhone review; no required P0 Watch action |
| `Undo` | Retract the exact action selected when Undo was invoked; preserve audit history | Watch or iPhone review |
| `Flash` | Sent on first attempt | iPhone review or optional quick result, not required as a separate Watch button |

Starting rest, recording another Attempt, switching routes, ending the visit, or receiving sensor evidence must not resolve an Attempt automatically. `Flash` is valuable but should not add Watch UI burden unless field tests prove it is needed.

### 6.4 iPhone: Review

P0 review should answer:

- What did I try today?
- Which RouteCards became projects?
- Where did I fail?
- What MoveCue should I remember?
- What is the next action when I return?

Review must support:

- edit attempt timeline;
- attach attempt to RouteCard;
- leave honest unresolved outcomes or explicitly confirm `sent` / `not_sent`;
- start or close a Project cycle;
- add one primary FailureEpisode per meaningful failure;
- add one short MoveCue;
- create or update NextSessionCue.

### 6.5 FailureEpisode

`FailureEpisode` converts an explicitly confirmed meaningful breakdown into learning. Confirming `not_sent` does not require or automatically create a FailureEpisode.

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

### 6.6 MoveCue

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

### 6.7 NextSessionCue

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

1. As a boulderer, I want to create a route card in under 30 seconds, so that I can remember the route without interrupting training.
2. As a boulderer, I want one Watch tap to record one Attempt and an optional second action to mark a Send, so that unknown outcomes do not create extra work or false failures.
3. As a boulderer, I want to undo the exact Watch action I just made, so that accidental taps do not pollute my session or affect a newer event after delayed sync.
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
15. As a user whose route has been reset, I want to mark the old RouteCard gone and create a successor without rewriting old attempts, so that my Project history stays meaningful.

## 10. Implementation Decisions

No production implementation has started yet. These decisions define the first implementation direction.

- Use a local-first data model. Cloud sync can come later.
- Watch owns optional workout start and low-interruption capture; the app-domain GymVisit remains valid in an iPhone-only or HealthKit-denied path.
- iPhone owns RouteCards, review, corrections, movement cues, and dataset annotation.
- HealthKit workout data is a supporting system record. App-private objects are the source of truth for bouldering semantics.
- Sensor inference must produce `SuggestedTimeline` or `SuggestionProvenance`, never ground truth.
- The P0 model should include `GymVisit`, `RouteCard`, `Project`, `Attempt`, `RestInterval`, `FailureEpisode`, `MoveCue`, `NextSessionCue`, `CorrectionEvent`, and thin `SuggestionProvenance`.
- Attempt outcome is `unresolved`, `sent`, or `not_sent`; retraction is a separate record state. `Mark Send` never increments attempt count.
- RouteCard visibility, route availability, and Project-cycle state are separate. A material reset creates a successor RouteCard.
- `Photo`, `HoldInstance`, `RouteGroup`, `RouteRole`, and `MoveSequence` belong to P0.5 dataset mode, not the minimum P0 loop.
- `Flash` is a result attribute, not a required Watch button.
- No open social graph, public feed, or stranger matching in P0/P1.

## 11. Testing Decisions

Testing should verify behavior from user-visible outcomes, not internal implementation details.

P0 tests should cover:

- RouteCard can be created, revised, archived/restored, marked gone, merged/unmerged, and linked to a successor without losing history.
- Project cycles can start, close sent/archived/gone, and restart later without overwriting prior cycles.
- Watch event stream can record one Attempt, optionally mark its Send result, and apply exact-target Undo.
- Unresolved Attempt outcomes remain unresolved across rest, route switch, another Attempt, visit end, and sync delay.
- Attempt events survive temporary phone disconnection.
- Review can attach attempts to RouteCards and create NextSessionCue.
- HealthKit denied state still allows local session recording.
- Sync retries do not duplicate attempts.
- Low-power or disconnected states preserve local data.
- User corrections override suggestions.
- Export/debug view exposes enough data for field validation.

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
| Minimal RouteCard creation time | <= 30 seconds |
| Watch action burden | 1 primary tap per Attempt; optional second action for Send; <= 2 total |
| Session local save success | >= 95% |
| Review open rate | >= 60% of completed sessions |
| NextSessionCue creation | >= 50% of reviewed sessions |
| NextSessionCue reuse | >= 50% of next gym visits |
| Project revisit rate | >= 40% within next two visits |
| User-rated usefulness | >= 7/10 after 3 sessions |
| P0.5 field-start evidence | 30 RouteCards and 100 Attempts before model-development claims; bounded manual/fixture-based Intelligence Nursery probes may run earlier |

## 13. Out Of Scope For P0

- Full automatic route reading.
- Automatic send/not-sent judgment.
- Real-time technique coaching.
- Medical, safety, recovery, or injury-prevention advice.
- Public feed, ranking, or open social matching.
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

## 15. Open Questions

These questions should be resolved by prototype or field testing:

- Is a minimal RouteCard useful without a photo, or is optional photo capture needed immediately?
- Does the user reliably tap Watch after every attempt, or only after meaningful attempts?
- Is optional Mark Send useful enough on Watch, or should all result confirmation move to Review Inbox?
- Does leaving `unresolved` outcomes honest create acceptable review burden without an in-session Not Sent action?
- Should NextSessionCue appear on Watch before a session or only on iPhone?
- How many FailureEpisode categories can users tolerate?
- Should MoveCue start as text, voice, tags, or all three?
- Should P0 include data export from day one?
- Can photo annotation be made faster than writing a note?
- How often do gyms restrict route photography?
- What is the first paid boundary, if any?

## 16. References

- `docs/project_background.md`
- `docs/climbing_bouldering_mvp_gate.md`
- `docs/climbing_bouldering_data_collection_plan.md`
- `docs/climbing_bouldering_platform_contract.md`
- `CONTEXT.md`
- `docs/adr/0001-gym-visit-memory-system.md`
- `docs/adr/0002-linewise-expanded-product-vision.md`
- `docs/adr/0003-canonical-p0-domain-model-and-terms.md`
- `docs/adr/0004-attempt-anchor-and-project-cycles.md`
- `docs/linewise_p0_domain_and_lifecycle_contract_v0.md`
