# Climb Context

Climb is a Watch + iPhone product exploration for indoor bouldering. The working product name is **LineWise** with the Chinese name **线感**: a bouldering companion that helps the user read lines, remember gym visits, understand movement, train deliberately, and eventually connect with climbing partners.

The current P0 frame is still a **Gym Visit Memory System**: Watch captures low-interruption training anchors, while iPhone maintains route/project memory, movement cues, review, and next-session recall.

## Product Rules

- `抱石` in English is **Bouldering**.
- `LineWise` / `线感` is the current working name, not yet a trademark, domain, or App Store availability conclusion.
- The P0 scope is indoor bouldering visits, not rope climbing, outdoor climbing, route guidebooks, social feeds, coach dashboards, or gym SaaS.
- Route/project identity is first-class. Attempt counts without a route or project context lose most of their product value.
- Watch owns short in-session actions: start, rest timer, Try/Send/Fail/Undo, and minimal project switching. `Flash` is a review/result attribute, not a required separate Watch button in P0.
- iPhone owns route cards, subjective grade, failure reasons, movement cues, session review, and next-session recall.
- Automation must be phrased as `suggested`, not `detected`. User correction is part of the trust model.
- HealthKit, heart rate, and motion data are supporting evidence. Do not make medical, safety, fatigue, or precise calorie claims.
- P0 should prove the manual-first `route/project -> attempt/rest -> review -> next-session recall` loop before AI route reading, video analysis, partner matching, teaching content, or gym integration.
- The long-term product may include AI route reading, stick-figure movement visualization, routesetter-lens analysis, teaching/training, and climbing partner workflows, but these must remain separate modules until validated.
- Canonical P0 chain: `GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue`.

## Ubiquitous Language

| Term | Meaning |
| --- | --- |
| `LineWise` | Working English product name. It means line-reading wisdom: the product helps users see route logic, movement options, and training implications. |
| `线感` | Working Chinese product name. It points to route-reading intuition, movement feel, and the indoor bouldering habit of reading a line before trying it. |
| `GymVisit` | One real visit to a climbing gym, from start to finish. It may contain many routes, attempts, rest intervals, and notes. |
| `RouteCard` | The user's personal memory object for one gym route. It can include color, wall area, official grade, subjective grade, photo, status, and notes. It does not require an official gym route database. |
| `Project` | A route the user cares about enough to revisit. A project can be unsent, sent, archived, or gone after a reset. |
| `Attempt` | One try on a route or project. It should be tied to a RouteCard when possible. |
| `RestInterval` | The recovery window after an attempt. It is part of pacing and memory, not a medical prescription. |
| `FailureEpisode` | A user-confirmed or suggested explanation of where and why an attempt failed. It should usually have one primary blocker and may link to a MoveCue. |
| `MoveCue` | A short cue about how to climb a route, such as foot sequence, body position, timing, or a coach/friend hint. Use this as the user-facing term instead of `beta`. |
| `NextSessionCue` | A small reminder shown before or during the next gym visit, telling the user what to try and what to remember. |
| `SubjectiveGrade` | The user's felt difficulty for a route, separate from the gym's official grade. |
| `SuggestedTimeline` | Any inferred or automatically proposed timeline. It is always editable and never treated as ground truth. |
| `SuggestionProvenance` | Thin metadata that records why something was suggested, such as source, confidence, and whether the user accepted, edited, or rejected it. |
| `CorrectionEvent` | A user correction to an event, annotation, route, or suggestion. Corrections are product trust data, not just cleanup. |
| `RouteRead` | An AI-assisted interpretation of a route photo, including hold grouping, start/top candidates, movement hypotheses, and possible movement cues. It is a suggestion, not ground truth. |
| `StickFigureCue` | A playful visual explanation that places a simple body model or motion path onto the route to explain sequencing and movement. |
| `SetterLens` | An analysis view that explains a route from a routesetter's perspective: intended movement, key difficulty, constraint, wall style, and skill focus. |
| `TrainingPath` | A structured learning path that connects route failures to teaching videos, movement drills, strength/mobility work, and next-session practice. |
| `ProofCheck` | A small next-session validation prompt that asks whether a MoveCue or drill helped on the route. |
| `MicroDrill` | A short on-wall drill linked to a repeated FailureEpisode. It is not a generic course item. |
| `ClimbingBuddy` | A companion layer that may mean an AI assistant, a human climbing partner, or both. Do not collapse these into one feature without specifying which one is being designed. |
| `PersonalClimbingDataset` | The user's local-first collection of route photos, attempt outcomes, movement cues, Watch data, and optional videos. It exists to make future AI and training features more reliable. |

## Active Product Docs

- `docs/project_background.md`: active project background and strategic framing for new collaborators.
- `docs/climbing_bouldering_prd_v0_1.md`: active P0/P0.5 requirements contract.
- `docs/climbing_bouldering_mvp_gate.md`: active Go/No-Go gates and validation metrics.
- `docs/climbing_bouldering_data_collection_plan.md`: active real-gym data collection protocol.
- `docs/climbing_bouldering_platform_contract.md`: active Apple Watch/iPhone/HealthKit/privacy contract.
- `docs/product_initialization_v0.md`: current Matt-style initialization note, working name, expanded product pillars, and near-term settlement plan.
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
- Any PRD must define Go/No-Go metrics before implementation issues are created.
