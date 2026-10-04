# ADR 4: Line-First Spotlight Memory

Date: 2026-09-23 (decision taken in PRD v1.0 on 2026-09-12; recorded here)

## Decision

LineWise is an iPhone app organised by **line**, not by gym visit or day. A line is a set of holds lit on a wall photo (the spotlight). Everything the user records hangs off that line:

```text
Gym -> Wall (photo) -> Line (holds) -> Session (one per day) -> Reminder -> Check
```

- The spotlight image is the only visual motif and the shared identity of a line. Hold numbers are the common language for fall point, sequence and notes.
- A Session is one day on one line. It records attempts, sent, fall point, one reason, and "下次试什么". It stores its origin as `source` (`in_gym` / `after` / `backfill`). This is a record of where it came from, not a capture mode.
- The Reminder is always built from the most recent Session with content. A Check (有用 / 没变化 / 问题变了 / 没试) is stored on the next Session together with the reminder text it judged, so a new reminder never erases the evidence about the old one.
- Apple Watch, imports (Health, FIT, Photos), AI route reading, video, community and gym integrations are out of scope until field validation says otherwise.

## Context

ADRs 1 and 3 modelled P0 as a GymVisit-centred chain with Watch capture (`GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue`). A July 2026 draft then proposed three capture modes (Watch, iPhone quick capture, review-only) plus provenance-rich imports. That draft was never adopted.

The September grilling replaced both with a simpler shape for three reasons:

- The main user's real pains were "I can't tell which line is mine in a photo", "adjacent same-colour lines get confused" and "I forgot where I fell". Hold-level identity on a photo answers all three. A colour or route-card label does not.
- Watch wearability in gyms is mixed, and in-session phone use is near zero, so the main path is after-the-climb review on iPhone. Capture modes add model and UI surface without adding memory value.
- Competitors already ship Watch capture, video AI, pose analysis, stick-figure beta and community (research report, 2026-07). What is left to own is the private loop: your line, your words, checked on your next attempt.

Kept from the earlier ADRs and the draft: route identity must not depend on colour alone; suggestions are never ground truth; a check on a previous cue is first-class; the app must work with no Watch, no account and no network.

## Consequences

- No top-level GymVisit or day view. Dates are a field and a history filter.
- RouteCard, FailureEpisode, MoveCue and NextSessionCue collapse into Line, Session fields and Reminder (PRD v1.1 §16).
- A line without a photo is allowed but loses the spotlight and sequence features.
- Watch returns only as `+1` / `上了` (FR-65) after the in-gym `+1` usage rate justifies it.
- Any future AI (hold suggestion, similar-line hints) must write into the same Line/Hold model and stay editable.
