# ADR 1: Start From Gym Visit Memory

Date: 2026-06-30

## Decision

The climbing product starts as a **Gym Visit Memory System** for indoor bouldering, not as a generic workout logger.

P0 should prove a manual-first loop:

```text
Route/project identity -> Watch attempt/rest capture -> iPhone review -> next-session recall
```

The first durable domain objects are:

- `GymVisit`
- `RouteCard`
- `Attempt`
- `RestInterval`
- `MoveCue`
- `NextSessionCue`

## Context

The earlier product framing focused on an Apple Watch-backed bouldering training memory app. After field-oriented V2 research, the strongest unmet need is broader than session recap: users need to remember which route they tried, what movement cue they learned, why they failed, and what to try next time.

External workout tools already cover duration, heart rate, and calories. Those metrics are useful but insufficient for bouldering because the sport is organized around route identity, attempts, rest, failure points, movement cues, and project memory.

## Consequences

- Attempt counts must be tied to a route or project whenever possible.
- A route/project card is part of P0, even if official gym route imports are out of scope.
- Watch UI remains minimal and should not become a route editor.
- iPhone owns route cards, subjective grade, failure reason, movement cues, and next-session cue cards.
- Automation remains `suggested`, not `detected`, until real field data proves reliability.
- Full route databases, social feeds, video AI, coach dashboards, and gym SaaS are out of P0.
