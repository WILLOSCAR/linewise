# Climb Context

Climb is a Watch + iPhone product exploration for indoor bouldering. The working product name is **LineWise** with the Chinese name **线感**: a bouldering companion that helps the user read lines, remember gym visits, understand movement, train deliberately, and eventually connect with climbing partners.

The current P0 frame is still a **Gym Visit Memory System**: Watch captures low-interruption training anchors, while iPhone maintains route/project memory, movement cues, review, and next-session recall.

## Product Rules

- `抱石` in English is **Bouldering**.
- `LineWise` / `线感` is the current working name, not yet a trademark, domain, or App Store availability conclusion.
- The P0 scope is indoor bouldering visits, not rope climbing, outdoor climbing, route guidebooks, social feeds, coach dashboards, or gym SaaS.
- Route/project identity is first-class. Attempt counts without a route or project context lose most of their product value.
- Watch owns short in-session actions: start, rest timer, `Record Attempt`, optional `Mark Send`, exact-target `Undo`, and minimal project switching. `not_sent` is confirmed during review when useful; P0 has no required Watch `Fail` action. `Flash` is a review/result attribute, not a required separate Watch button.
- iPhone owns route cards, subjective grade, failure reasons, movement cues, session review, and next-session recall.
- Automation must be phrased as `suggested`, not `detected`. User correction is part of the trust model.
- HealthKit, heart rate, and motion data are supporting evidence. Do not make medical, safety, fatigue, or precise calorie claims.
- P0 should prove the manual-first `route/project -> attempt/rest -> review -> next-session recall` loop before AI route reading, video analysis, partner matching, teaching content, or gym integration become production dependencies. Intelligence Nursery probes may run in parallel.
- The long-term product may include AI route reading, stick-figure movement visualization, routesetter-lens analysis, teaching/training, and climbing partner workflows, but these must remain separate modules until validated.
- Canonical P0 chain: `GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue`.

## Ubiquitous Language

| Term | Meaning |
| --- | --- |
| `LineWise` | Working English product name. It means line-reading wisdom: the product helps users see route logic, movement options, and training implications. |
| `线感` | Working Chinese product name. It points to route-reading intuition, movement feel, and the indoor bouldering habit of reading a line before trying it. |
| `GymVisit` | One real visit to a climbing gym, from start to finish. It may contain many routes, attempts, rest intervals, and notes. |
| `RouteCard` | The user's personal memory object for one believed physical gym-route incarnation. A material reset creates a successor RouteCard instead of rewriting the old history; no official gym route database is required. |
| `Project` | One time-bounded intention to revisit a RouteCard. A RouteCard may have several historical Project cycles, while at most one is active at a time. |
| `Attempt` | One user-declared try during a GymVisit. It begins `unresolved`, may be confirmed `sent` or `not_sent`, and may be retracted without treating retraction as an outcome. |
| `RestInterval` | The recovery window after an attempt. It is part of pacing and memory, not a medical prescription. |
| `FailureEpisode` | A user-confirmed or suggested explanation of where and why an Attempt broke down. A confirmed episode requires an explicitly `not_sent` Attempt; it should usually have one primary blocker and may link to a MoveCue. |
| `MoveCue` | A short cue about how to climb a route, such as foot sequence, body position, timing, or a coach/friend hint. Use this as the user-facing term instead of `beta`. |
| `NextSessionCue` | A small reminder shown before or during the next gym visit, telling the user what to try and what to remember. |
| `SubjectiveGrade` | The user's felt difficulty for a route, separate from the gym's official grade. |
| `SuggestedTimeline` | Any inferred or automatically proposed timeline. It is always editable and never treated as ground truth. |
| `SuggestionProvenance` | Thin metadata that records why something was suggested, such as source, confidence, and whether the user accepted, edited, or rejected it. |
| `CorrectionEvent` | A user correction to an event, annotation, route, or suggestion. Corrections are product trust data, not just cleanup. |
| `ReviewInbox` | The visit-level queue for resolving unassigned, unresolved, late, or conflicting records after capture. Review may complete while honest unknowns remain. |
| `RouteRead` | An AI-assisted interpretation of a route photo, including hold grouping, start/top candidates, movement hypotheses, and possible movement cues. It is a suggestion, not ground truth. |
| `StickFigureCue` | A short shareable visual excerpt, normally one to three movement steps, taken from an editable RouteRehearsal to explain one crux or movement idea. |
| `SetterLens` | An analysis view that explains a route from a routesetter's perspective: intended movement, key difficulty, constraint, wall style, and skill focus. |
| `TrainingPath` | A structured learning path that connects route failures to teaching videos, movement drills, strength/mobility work, and next-session practice. |
| `ProofCheck` | A small next-session validation prompt that asks whether a MoveCue or drill helped on the route. |
| `MicroDrill` | A short on-wall drill linked to a repeated FailureEpisode. It is not a generic course item. |
| `ClimbingBuddy` | A companion layer that may mean an AI assistant, a human climbing partner, or both. Do not collapse these into one feature without specifying which one is being designed. |
| `PersonalClimbingDataset` | The user's local-first collection of route photos, attempt outcomes, movement cues, Watch data, and optional videos. It exists to make future AI and training features more reliable. |

## AI Route Rehearsal Language

**RouteScene**:
An editable representation of a wall and selected route recovered from photos, video, or a future spatial scan. It contains holds, volumes, route roles, scale, geometry assumptions, and corrections.
_Avoid_: Route map, official route truth

**BodyProfile**:
A local-first description of the user's body proportions and optional movement preferences used to size a rehearsal skeleton. It is not a medical or capability assessment.
_Avoid_: Body diagnosis, fitness profile

**ClimberAvatar**:
The articulated visual body derived from a BodyProfile and placed into a RouteScene.
_Avoid_: Digital twin, exact body replica

**LimbContact**:
The explicit relationship between LH, RH, LF, or RF and a hold, volume, wall region, ground, free state, or unknown state at one moment.
_Avoid_: Grip point

**MoveSequence**:
The symbolic ordered plan of which limb changes to which contact target and which contacts stay locked. It does not by itself define a whole-body pose.
_Avoid_: Correct beta, final solution

**PoseKeyframe**:
A meaningful whole-body climbing pose with explicit limb contacts, torso placement, solver confidence, and unresolved constraint findings.
_Avoid_: Screenshot, animation frame

**MovementStep**:
The transition between two PoseKeyframes, including contacts gained, released, and retained plus a qualitative explanation.
_Avoid_: Frame

**MovementIntent**:
The purpose, movement family, expected rhythm, felt cue, and explicit uncertainty that a climber wants to try for one MovementStep. It is an editable rehearsal instruction, not proof of feasibility, safety, or official routesetter intent.
_Avoid_: Correct technique, prescribed movement

**MovementHypothesis**:
One candidate interpretation of how a person could climb a route. Several hypotheses may coexist for different body proportions, styles, or uncertainties.
_Avoid_: Solution, answer

**RouteRehearsal**:
An editable and playable sequence of PoseKeyframes and MovementSteps over a RouteScene for one BodyProfile.
_Avoid_: Simulation truth, guaranteed beta

**ConstraintFinding**:
A qualitative warning or unresolved assumption about reach, joint range, contact, collision, geometry, or downstream validity. It is not a safety judgment.
_Avoid_: Safety alert, injury risk

## Active Product Docs

- `docs/linewise_product_requirements_map_v0.md`: active navigation, module ownership, dependency, degradation, and requirements-settlement map.
- `docs/linewise_p0_domain_and_lifecycle_contract_v0.md`: normative P0 contract for Attempt semantics, RouteCard/Project lifecycle, review state, and cross-device event meaning.
- `docs/linewise_end_to_end_experience_contract_v0.md`: active experience contract for normal and degraded Watch/iPhone journeys.
- `docs/linewise_physiology_data_contract_v0.md`: active source, retention, derivation, consent, deletion, and claim contract for physiology context.
- `docs/linewise_ai_route_rehearsal_requirements_v0.md`: active Intelligence Nursery requirements for RouteRead, personalized avatar rehearsal, keyframes, animation, and single-step debugging; not a P0 release dependency.
- `docs/linewise_ai_route_rehearsal_evaluation_protocol_v0.md`: evaluation ladder, baselines, tasks, metrics, and claim ceilings for RouteRehearsal prototypes.
- `docs/linewise_setter_lens_and_training_path_requirements_v0.md`: active Intelligence Nursery contract for qualitative route interpretation and failure-linked practice.
- `docs/project_background.md`: active project background and strategic framing for new collaborators.
- `docs/climbing_bouldering_prd_v0_1.md`: active P0/P0.5 requirements contract.
- `docs/climbing_bouldering_mvp_gate.md`: active Go/No-Go gates and validation metrics.
- `docs/climbing_bouldering_data_collection_plan.md`: active real-gym data collection protocol.
- `docs/climbing_bouldering_platform_contract.md`: active Apple Watch/iPhone/HealthKit/privacy contract.
- `docs/product_initialization_v0.md`: current Matt-style initialization note, working name, expanded product pillars, and near-term settlement plan.
- `docs/climbing_bouldering_implementation_plan.md`: current implementation architecture, completed slices, verification commands, and remaining real-device/field evidence.
- `docs/adr/0004-attempt-anchor-and-project-cycles.md`: durable decision for one-tap Attempt capture, honest unresolved outcomes, separate RouteCard axes, and repeatable Project cycles.
- `docs/adr/0002-linewise-expanded-product-vision.md`: durable decision to keep Gym Visit Memory as P0 while naming the broader product `LineWise` / `线感`.
- `docs/adr/0003-canonical-p0-domain-model-and-terms.md`: durable decision for canonical P0 entities and terminology.
- `docs/adr/0001-gym-visit-memory-system.md`: durable decision that the product starts from gym visit memory rather than generic session logging.

## Historical Research Docs

- `docs/bouldering_field_research_v2.md`: field-observation-oriented V2 research and source material.
- `docs/climbing_bouldering_research_report_v1.md`: earlier five-PM product-direction baseline.
- `docs/bouldering_industry_history_business_report.md`: industry, brand, commercial, and coaching background.
- `docs/bouldering_market_mvp_report.md`: original broad MVP market report.

## Validation Principles

- Product validation comes first: real gym visits, RouteCard creation, Watch tap burden, next-session recall, and review usage.
- Data collection should start before complex AI promises: route photos, start/top labels, attempt outcomes, failure reasons, movement cues, and Watch timelines are the first useful dataset.
- Simulator validation will matter after implementation begins, but it cannot replace physical Apple Watch validation for motion recording, background behavior, HealthKit writes, WatchConnectivity, and in-gym usability.
- Any PRD must define Go/No-Go metrics before a feature is promoted from implementation to a product claim.
