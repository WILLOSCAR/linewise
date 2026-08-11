# LineWise P0 Domain And Lifecycle Contract v0

Date: 2026-08-11
Status: P0 requirements contract; field validation still required
Scope: `GymVisit`, `RouteCard`, `Project`, `Attempt`, `FailureEpisode`, and the cross-device events that preserve their meaning

## 1. Purpose

This document settles the minimum manual-first domain contract needed to prove the LineWise P0 loop:

```text
GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue
```

It answers four questions that the existing active documents leave ambiguous or contradictory:

1. What does one Watch tap record?
2. When is an Attempt a `Send`, a confirmed non-send, or still unresolved?
3. How do RouteCard and Project differ as routes are revisited, sent, reset, archived, duplicated, or rediscovered?
4. How do the same user actions keep their meaning when Watch and iPhone are offline, delayed, duplicated, or out of order?

This is a product/domain contract, not an implementation design. It does not choose a database, synchronization framework, API, or UI layout.

## 2. Normative Language And Decision Summary

`MUST`, `MUST NOT`, `SHOULD`, and `MAY` are requirement words in this document.

The P0 decisions are:

- The primary Watch action is **Record Attempt**. One intentional tap records exactly one Attempt.
- **Mark Send** is an optional result action on an existing Attempt. It never creates a second Attempt.
- **Undo** retracts the exact user action that was the undo target when the user tapped it. It must not mean "whatever event arrived last on iPhone."
- P0 has no required Watch `Fail` action.
- A newly recorded Attempt has outcome `unresolved`.
- Ending a GymVisit, starting another Attempt, starting rest, or leaving a route does not convert an unresolved Attempt into a failure.
- `not_sent` is an explicit user-confirmed Attempt outcome. It is not a synonym for `FailureEpisode`.
- A FailureEpisode is created during review by the user, or is presented as an editable suggestion. It is never silently asserted from Watch or sensor data.
- RouteCard represents the user's memory of one physical route incarnation. Project represents a time-bounded intention to revisit that RouteCard.
- Route availability, record visibility, and project progress are separate state axes. They must not be collapsed into one `RouteCard.status` value.
- Every retry across Watch and iPhone preserves the original event identity. Duplicate delivery must not create duplicate Attempts.

## 3. Canonical Relationships

```text
GymVisit 1 ---------------------- * Attempt
                                           |
                                           | 0..1 during capture/review,
                                           | exactly 1 when route identity is resolved
                                           v
RouteCard 0..1 ------------------ * Attempt
    |
    +---------------------------- * Project
    |
    +---------------------------- * FailureEpisode
    |
    +---------------------------- * MoveCue
    |
    +---------------------------- * NextSessionCue

Attempt 1 ----------------------- 0..* FailureEpisode
Project 1 ----------------------- 1 RouteCard
```

Rules behind this diagram:

- Every non-retracted Attempt belongs to exactly one GymVisit.
- An Attempt SHOULD be bound to one RouteCard at capture time. It MAY remain `unassigned` temporarily when the user forgot to switch routes or route identity is unclear.
- Before a GymVisit is considered fully reviewed, every meaningful Attempt must either be assigned to one RouteCard or be explicitly left `unassigned` for later correction.
- Every Project refers to exactly one RouteCard.
- A RouteCard may never become a Project, may have at most one active Project, and may have several historical Project cycles.
- An Attempt is always route history first. Its connection to a Project is contextual and must not replace its RouteCard link.

## 4. Refined P0 Language

### 4.1 Attempt

An `Attempt` is one user-declared try on one route during one GymVisit. It records that a try occurred; by default it makes no claim about the result or cause.

An Attempt has two independent aspects:

| Aspect | Allowed values | Meaning |
| --- | --- | --- |
| Record state | `active`, `retracted` | Whether the Attempt should count in the user's session history |
| Outcome | `unresolved`, `sent`, `not_sent` | What the user has confirmed about completion |

`retracted` is not an outcome. It means the Attempt was recorded by mistake or later removed by an explicit correction.

### 4.2 Send

`Send` is the user-confirmed outcome that the route was completed on a specific Attempt. `Mark Send` changes that Attempt's outcome to `sent`; it does not record a new try.

### 4.3 Not Sent

`not_sent` means the user explicitly confirmed that a specific Attempt did not complete the route. It does not say why the Attempt ended and does not require a FailureEpisode.

The user-facing copy may say "未完成" or equivalent. The canonical domain value is `not_sent`; `Fail` is not the P0 Watch action or Attempt state.

### 4.4 FailureEpisode

A `FailureEpisode` explains a meaningful point at which an Attempt broke down, including one primary blocker and optional location/MoveCue context.

- A user-confirmed FailureEpisode MUST be linked to an active Attempt whose outcome is `not_sent`.
- A suggested FailureEpisode MAY be linked to an unresolved Attempt, but it remains a suggestion and cannot change the Attempt outcome.
- Confirming `not_sent` MUST NOT create a FailureEpisode automatically.
- A single Attempt MAY have no FailureEpisode or several distinct FailureEpisodes. P0 review only needs one primary meaningful episode, not exhaustive annotation.
- Watch, heart rate, and motion data MUST NOT create a user-confirmed FailureEpisode.

### 4.5 RouteCard

A `RouteCard` is the user's durable memory record for one believed physical route incarnation at one gym. It is version-bounded: a material reset or material change creates a successor RouteCard instead of rewriting the old route's history.

### 4.6 Project

A `Project` is one time-bounded commitment to revisit a RouteCard. It is not a second route identity and it is not a status field on RouteCard.

Examples:

- A user may create a RouteCard for a warm-up without creating a Project.
- Starting to work a route across visits creates an active Project linked to that RouteCard.
- Sending the route closes that Project cycle as `sent`; the RouteCard remains available history.
- Returning months later for refinement starts a new Project cycle rather than erasing the old send.

### 4.7 RouteCard Revision And Successor

- A **RouteCard revision** corrects descriptive memory without changing physical route identity: label, photo, grade text, wall-area wording, or notes.
- A **successor RouteCard** represents a new physical route incarnation after a reset or material hold/start/top change. It links back to the prior RouteCard for continuity but has its own Attempts and Project cycles.

P0 does not require a separate public `RouteVersion` object. The identity boundary above is sufficient for field validation.

## 5. Watch Capture Contract

### 5.1 Required Actions

| Watch action | Domain effect | Tap burden |
| --- | --- | --- |
| Record Attempt | Create one active Attempt with outcome `unresolved` in the current GymVisit and current route context | One intentional tap |
| Mark Send | Mark the selected or just-recorded Attempt as `sent` | Optional second action |
| Undo | Retract the exact last reversible Watch action in this GymVisit | One action |

Start/End GymVisit, rest visibility, sparse haptics, and minimal route switching remain P0 Watch responsibilities, but they do not change Attempt outcome semantics.

### 5.2 Attempt State Transitions

```text
Record Attempt
      |
      v
  unresolved -------- Mark Send --------> sent
      |
      +------ Confirm Not Sent ----------> not_sent

unresolved / sent / not_sent
      |
      +------ Retract Attempt -----------> retracted

sent -------- Undo Mark Send ------------> unresolved
```

Review corrections may explicitly change `sent`, `not_sent`, and `unresolved` when the user fixes a mistake. Every correction preserves what was changed and does not rewrite history silently.

### 5.3 Actions That Must Not Imply Failure

None of the following changes an Attempt from `unresolved` to `not_sent`:

- another Attempt is recorded;
- rest starts or ends;
- the user switches RouteCard;
- the GymVisit ends;
- the Watch loses connection;
- a later Attempt is sent;
- motion or heart-rate evidence looks like a fall, stop, or rest;
- the review window expires.

An unresolved Attempt may stay unresolved permanently. Honest unknown data is valid P0 data.

### 5.4 Undo Semantics

Undo is a retraction of one identified action, not a destructive deletion and not a global "last write wins" operation.

- If Undo targets `Mark Send`, the Attempt returns to its prior outcome, normally `unresolved`.
- If Undo targets `Record Attempt`, that Attempt becomes `retracted` and is excluded from counts and rest summaries.
- If the Attempt already has later review annotations, Watch Undo MUST NOT silently orphan or delete them; review must surface the conflict.
- Retrying delivery of the same Undo has no additional effect.
- A delayed Undo must still target its original action even if newer iPhone actions already exist.

### 5.5 Flash

`Flash` remains a review/result attribute, not a Watch action. It applies only when the first known, non-retracted Attempt on that RouteCard incarnation is sent. If the user's earlier history is incomplete, Flash remains user-confirmed rather than inferred as truth.

## 6. GymVisit Lifecycle

GymVisit has two orthogonal lifecycles: capture and review.

### 6.1 Capture State

| State | Meaning |
| --- | --- |
| `open` | The real gym visit is ongoing and capture actions are accepted |
| `ended` | The user has ended the real gym visit; late review corrections are still allowed |
| `voided` | The record was a false start/test and is excluded from normal history |

Allowed transitions:

```text
open ------ End Visit ------> ended
  |                              |
  +------ Void False Start -----> voided
                                 |
ended -- Retract Accidental End -+--> open
```

Rules:

- `End Visit` does not resolve any Attempt outcome.
- An accidental end MAY be retracted only when the user is still in the same real gym visit and no different GymVisit has started.
- Leaving and later returning to the gym is a new GymVisit, even on the same day.
- A missed Attempt added after `ended` is a late-added Attempt; it does not reopen capture state.
- A false-start GymVisit may be voided only through explicit user action. It is not silently deleted.

### 6.2 Review State

| State | Meaning |
| --- | --- |
| `pending_review` | Visit ended and has not been reviewed |
| `reviewing` | User is actively resolving route links, outcomes, failures, cues, or next actions |
| `reviewed` | User explicitly completed the current review pass |
| `needs_recheck` | A material late event or conflict arrived after review |

Allowed transitions:

```text
pending_review -> reviewing -> reviewed
                         ^          |
                         |          +-- material late event --> needs_recheck
                         +---------------- reopen review -------+
```

Rules:

- An `open` GymVisit cannot be finalized as `reviewed`.
- Review completion does not require inventing outcomes for unresolved Attempts.
- A reviewed GymVisit remains editable.
- A late duplicate event does not cause `needs_recheck`; a genuinely new Attempt, retraction, outcome, or route conflict does.

## 7. RouteCard Lifecycle

RouteCard uses separate axes for record visibility and physical availability.

### 7.1 Record Visibility

| State | Meaning |
| --- | --- |
| `active` | Appears in normal route memory and selection |
| `archived` | Hidden from normal selection but retained in history/search |
| `merged` | Confirmed duplicate whose identity redirects to a surviving RouteCard |

Allowed transitions:

```text
active <------ Restore ------ archived
   |                             |
   +------ Confirm Duplicate ----+----> merged
```

An incorrect merge MUST be recoverable through an explicit correction. Merge never hard-deletes attempts, projects, cues, photos, or provenance.

### 7.2 Physical Availability

| State | Meaning |
| --- | --- |
| `unknown` | User does not know whether the route is currently on the wall |
| `present` | User currently believes the same physical route incarnation is available |
| `gone` | User believes this physical route incarnation was removed or materially reset |

Allowed transitions:

```text
unknown <------ explicit correction ------> present
   |                                         |
   +--------------- Mark Gone ---------------+----> gone

gone -- Correct Mistaken Gone --> present or unknown
```

Rules:

- `gone` is a claim about wall availability, not a deletion command.
- Marking a RouteCard `gone` does not archive it and does not erase its history.
- Archiving a RouteCard does not imply it is gone.
- Reopening an archived RouteCard restores visibility only; it does not change availability.
- If the physical route was materially reset, the old RouteCard stays `gone` and a successor RouteCard is created.

### 7.3 RouteCard Presentation Labels

`new`, `active project`, and `sent` may be useful UI labels, but they are derived from Attempts and Project state. They MUST NOT be the only stored lifecycle of RouteCard because they conflate route identity, personal intent, and availability.

## 8. Project Lifecycle

Each Project is one revisit cycle linked to one RouteCard.

| State | Meaning |
| --- | --- |
| `active` | The user intends to revisit the route; it is currently unsent in this Project cycle |
| `sent` | The route was sent and this Project cycle is complete |
| `archived` | The user stopped prioritizing this Project without claiming a send |
| `gone` | The Project closed because its RouteCard incarnation is gone |

Allowed transitions:

```text
                 +------> sent
                 |
active ----------+------> archived
                 |
                 +------> gone
```

Rules:

- A RouteCard may have at most one `active` Project at a time.
- `sent`, `archived`, and `gone` are terminal for that Project cycle.
- Reopen means starting a new `active` Project linked to the same RouteCard, not erasing a prior terminal state.
- Correcting a mistaken terminal action is not a reopen: it retracts that mistaken action, restores the Project's prior state, and preserves the correction history.
- A Project can start only on an active, non-merged RouteCard whose availability is not `gone`.
- A Project becomes `sent` only when it references an active `sent` Attempt on the same RouteCard. If the user missed Watch capture, review first adds the missing Attempt and then marks it sent.
- If the only supporting sent Attempt is corrected or retracted, the Project cannot remain `sent`; the linked Project-sent action must be corrected in the same review.
- When a RouteCard becomes `gone`, any active Project on it closes as `gone`; sent and archived historical Projects remain unchanged.
- A successor RouteCard does not inherit an active Project automatically. The user explicitly chooses whether the new route is a new Project.

## 9. Reset, Gone, Archive, Reopen, Duplicate, And Versioning Rules

| Situation | Required domain behavior |
| --- | --- |
| Route is temporarily not seen | Set availability to `unknown`; do not claim `gone` automatically |
| Gym confirms route was removed/reset | Mark old RouteCard `gone`; close only its active Project as `gone` |
| Grade tag, label, photo, or wall wording changes | Revise the same RouteCard and preserve correction provenance |
| Holds/start/top change materially | Preserve old RouteCard as `gone`; create a successor RouteCard |
| User wants old sent/archived route in normal lists | Restore the RouteCard visibility; do not rewrite Project history |
| User wants to work a previously sent/archived route again | Start a new Project cycle on the same present RouteCard |
| Two cards are the same physical incarnation | User confirms a duplicate merge; preserve one canonical card plus the merged identity/provenance; resolve two active Projects before finalizing |
| Two cards look similar but identity is uncertain | Keep both and optionally suggest a duplicate; never auto-merge |
| A duplicate merge was wrong | Explicitly unmerge/recover both identities and surface relationship conflicts for review |
| A reset route resembles its predecessor | Link as successor; do not merge just because color, wall area, or grade matches |

Route identity is intentionally user-owned in P0. Gym database identity, computer vision, timestamps, color, and wall area may support a suggestion later, but none is sufficient to merge or version routes without user confirmation.

## 10. Domain Event Contract

### 10.1 Event Identity

Every capture or correction action that can cross devices MUST carry:

| Element | Domain requirement |
| --- | --- |
| `event_id` | Stable identity created once at the action source and preserved across every retry |
| Subject identity | Exact GymVisit, Attempt, RouteCard, Project, or action affected |
| `occurred_at` | When the real-world action or attempt occurred, if known |
| `recorded_at` | When LineWise recorded it |
| Source | Watch, iPhone, user late-add, import, or suggestion |
| Confirmation | User-confirmed, suggested, corrected, or unknown |
| Causal target | Exact prior event/action when this event marks, corrects, or retracts it |

`occurred_at` and `recorded_at` MUST remain distinct. A late-added Attempt may have an approximate occurrence time, but its uncertainty must not be hidden.

### 10.2 Canonical P0 Event Families

| Event family | Examples | Rule |
| --- | --- | --- |
| GymVisit | Visit started, ended, end retracted, voided, review completed/reopened | Always identifies one GymVisit |
| Route context | Route selected, Attempt route reassigned, route left unassigned | Attempt carries the route context used at capture; receiver state does not reinterpret it |
| Attempt | Attempt recorded, outcome marked, Attempt retracted, Attempt late-added | Outcome changes always identify the exact Attempt |
| Failure | FailureEpisode suggested, confirmed, edited, rejected | Suggested and confirmed states never collapse |
| RouteCard | Created, revised, archived, restored, availability changed, merged, unmerged, successor linked | History survives every lifecycle change |
| Project | Started, sent, archived, closed gone, new cycle started | Terminal Project cycles are preserved |
| Correction | Action retracted, route reassigned, outcome corrected, time corrected | Before/after meaning and actor remain inspectable |

### 10.3 Idempotency Rules

- Receiving the same `event_id` with the same meaning more than once has the same result as receiving it once.
- A retry MUST reuse its original `event_id`; it must not masquerade as a new user action.
- The same `event_id` with different meaning is a conflict and MUST NOT be accepted as two actions or silently overwritten.
- Two separately intentional taps have different event identities and remain two Attempts, even if their timestamps are close.
- Suggestions and user corrections use distinct event identities. A suggestion retry cannot overwrite a user correction.

### 10.4 Ordering Rules

Arrival order is not business order.

- `Mark Send` names the Attempt it affects; it does not mean "mark the most recently received Attempt."
- Undo names the action it retracts; it does not mean "remove the most recently received event."
- An Attempt carries its captured RouteCard or `unassigned` context; a delayed route-selection event cannot rebind it accidentally.
- If a dependent event arrives before its target, it remains unresolved until the target appears; it must not be applied to a different target.
- A dependent event targeting a retracted subject does not restore that subject; it becomes a review conflict.
- If two offline, user-confirmed corrections conflict and their intended order is unknowable, LineWise preserves both and asks for review instead of silently applying last arrival.

## 11. Offline And Cross-Device Behavior

### 11.1 Offline Capture

- Watch capture remains valid while iPhone is absent or unreachable.
- Loss of connectivity does not change Attempt outcome, route context, GymVisit identity, or action time.
- Ending a GymVisit offline does not prevent later delivery of earlier Attempt events.
- The user must be able to distinguish locally recorded, pending, synchronized, and conflicting actions during review/debugging.

### 11.2 Duplicate Delivery

- Duplicate delivery of `Attempt recorded` produces one Attempt.
- Duplicate delivery of `Mark Send` marks the same Attempt once and never increments attempt count.
- Duplicate delivery of Undo retracts one target once.
- Duplicate delivery of `End Visit` ends one GymVisit once.

### 11.3 Out-Of-Order Delivery

- `Mark Send` arriving before its Attempt waits for that exact Attempt.
- Undo arriving before its target waits for that exact target.
- A late Attempt arriving after review moves the GymVisit to `needs_recheck` unless it is a known duplicate.
- A route merge or successor link arriving before an Attempt does not erase the Attempt's original route provenance.

## 12. Human Error And Recovery

| Error case | P0 recovery contract |
| --- | --- |
| Accidental Attempt tap | Undo retracts that exact Attempt; review can also retract it later |
| Accidental Mark Send | Undo restores the Attempt's previous outcome; review can correct it later |
| Double tap | Keep two Attempts because two event identities exist; user retracts the extra one |
| Missed Attempt tap | Add a late Attempt during review with known or approximate occurrence time |
| Missed Send tap | Mark the existing Attempt `sent` during review |
| Sent route but no Attempt was captured | Add one late Attempt and mark that Attempt `sent`; do not create an orphan Send |
| Forgot to switch routes | Reassign affected Attempt(s) to the correct RouteCard through explicit correction |
| Route unknown during Watch capture | Keep Attempt `unassigned`; resolve during review without inventing a route |
| Accidental End Visit | Retract the end while still in the same real visit; otherwise keep it ended and create a new GymVisit |
| Visit never ended | Recover the open GymVisit and ask the user to end, continue, or void it; do not guess attempt outcomes |
| Late Watch data after iPhone review | Preserve the late data and mark the visit `needs_recheck` |
| Wrong duplicate merge | Recover both RouteCards and surface ambiguous relationships for user correction |

Automatic time-based deduplication is forbidden for Attempt taps in P0. It risks erasing real tries. A future system may suggest likely duplicates, but only the user confirms retraction or merge.

## 13. Illegal Transitions And Rejected Meanings

| Illegal transition or inference | Reason |
| --- | --- |
| `unresolved -> not_sent` because GymVisit ended | Session closure does not establish outcome |
| `unresolved -> not_sent` because another Attempt began | A new try does not prove the prior result |
| Any sensor signal -> user-confirmed Send/Not Sent/FailureEpisode | Automation is suggested, not detected |
| Mark Send on a missing or retracted Attempt | A result must belong to an active Attempt |
| Confirm FailureEpisode on a `sent` Attempt | A confirmed failure explanation conflicts with confirmed completion for that Attempt |
| Project `active -> sent` without a sent Attempt on the same RouteCard | Project completion must retain its supporting climb event |
| Start Project on a merged or `gone` RouteCard | It is not a currently workable route identity |
| RouteCard `gone` -> new physical incarnation by editing the old card | This rewrites historical route identity; create a successor instead |
| Archive RouteCard -> erase Attempts/Projects/Cues | Archive controls visibility, not existence |
| Duplicate suggestion -> automatic merge | Similarity is not identity proof |
| Successor creation -> silently move old Attempts/Project | A new physical route has new history and intent |
| Retry -> new event identity | This creates duplicate user actions |
| Delayed Undo -> retract newest received action | It changes user intent under out-of-order delivery |
| Review complete -> force all unresolved Attempts to not-sent | Unknown is a valid state |

## 14. Core Invariants

1. One intentional Record Attempt action produces one Attempt identity.
2. Mark Send never increases attempt count.
3. Every active Attempt belongs to exactly one GymVisit.
4. At most one non-voided GymVisit is open for the user at a time.
5. An Attempt has at most one current RouteCard binding; `unassigned` is explicit, not a hidden null interpreted as the current route.
6. The default Attempt outcome is `unresolved`.
7. No passage of time or unrelated event resolves an Attempt outcome.
8. Every `sent` Project references a non-retracted sent Attempt on the same RouteCard.
9. A user-confirmed FailureEpisode requires a non-retracted `not_sent` Attempt.
10. Suggested data never overwrites user-confirmed or corrected data.
11. A RouteCard identifies one physical route incarnation; material reset creates a successor.
12. Route availability, RouteCard visibility, and Project lifecycle remain independent.
13. At most one active Project exists per RouteCard, while historical Project cycles remain durable.
14. Archive, gone, merge, versioning, correction, and Undo do not silently destroy historical provenance.
15. Re-delivery of an event identity never produces an additional domain action.
16. Cross-device arrival order never changes the target of Send, Undo, route assignment, or correction.
17. Review may leave honest unknowns; completion of review is not completion of every field.

## 15. Acceptance Scenarios

These are product acceptance scenarios, independent of storage or UI implementation.

### A1. One-Tap Attempt

Given an open GymVisit and selected RouteCard, when the user taps Record Attempt once, then one active Attempt exists for that GymVisit and RouteCard with outcome `unresolved`.

### A2. Optional Send Is Not A Second Attempt

Given one unresolved Attempt, when the user marks it Send, then attempt count remains one and that Attempt becomes `sent`.

### A3. Unresolved Remains Unknown

Given an unresolved Attempt, when the user rests, switches routes, records another Attempt, and ends the GymVisit, then the original Attempt remains `unresolved`.

### A4. Undo Send

Given a user marked an Attempt Send by mistake, when Undo targets that Mark Send action, then the Attempt returns to its prior outcome and remains one active Attempt.

### A5. Undo Accidental Attempt

Given an accidental Record Attempt tap, when Undo targets it, then that Attempt is retracted, excluded from counts, and not converted to any failure state.

### A6. Duplicate Synchronization

Given an offline Watch Attempt event delivered three times, when iPhone reconciles all deliveries, then exactly one Attempt exists and sync shows no unresolved conflict.

### A7. Out-Of-Order Send

Given Mark Send arrives before its target Attempt, when the target later arrives, then that exact Attempt becomes sent and no extra Attempt is created.

### A8. Out-Of-Order Undo

Given Undo arrives before its target while newer events already exist, when the target later arrives, then only the named target is retracted.

### A9. Double Tap

Given two separate Watch taps each have a different event identity, when they synchronize, then two Attempts appear until the user explicitly retracts one.

### A10. Missed Attempt And Late Send

Given the user sent a route without tapping Watch, when review adds one late Attempt and marks it sent, then Project may close as sent and the approximate occurrence time remains labeled as such.

### A11. Forgotten Route Switch

Given three Attempts were captured under the wrong RouteCard, when the user reassigns two during review, then both their original binding and correction are inspectable, while the third remains on the original RouteCard.

### A12. Suggested Failure

Given an unresolved Attempt and a suggested `body_position` blocker, when the user does nothing, then the Attempt remains unresolved and the suggestion cannot count as a confirmed FailureEpisode or training fact.

### A13. Confirmed Failure Without Explanation

Given an unresolved Attempt, when the user confirms `not_sent` but skips blocker selection, then no FailureEpisode is required and review may still complete.

### A14. Confirmed FailureEpisode

Given a `not_sent` Attempt, when the user confirms one `footwork` FailureEpisode and links a MoveCue, then both remain tied to that Attempt and RouteCard.

### A15. Route Becomes A Project

Given a present RouteCard with no active Project, when the user decides to revisit it, then one active Project begins without changing RouteCard identity.

### A16. Reopen A Sent Route

Given a historical sent Project and the same physical RouteCard still present, when the user chooses to work it again, then a new active Project cycle begins and the earlier sent cycle stays intact.

### A17. Route Reset

Given an active Project and a materially reset physical route, when the user records the reset, then the old RouteCard becomes gone, its active Project closes gone, a successor RouteCard may be created, and old Attempts/Cues remain attached to the old card.

### A18. Archive Versus Gone

Given a present RouteCard, when the user archives it, then it disappears from normal selection but remains physically `present`; restoring it does not change Project history.

### A19. Duplicate Merge

Given two RouteCards are confirmed as the same physical route incarnation, when the user merges them, then one canonical RouteCard is used, all history remains reachable, and retrying the merge creates no additional change.

### A20. Late Event After Review

Given a reviewed GymVisit, when a genuinely new offline Attempt arrives, then the Attempt is preserved and the GymVisit becomes `needs_recheck`; a duplicate arrival leaves it reviewed.

### A21. Accidental Visit End

Given the user ends a GymVisit while still in the gym and no later GymVisit exists, when the end is retracted, then the same GymVisit returns to open without changing any Attempt outcomes.

## 16. Active-Document Migration Ledger

These conflicts existed when this contract was drafted and were resolved in the same requirements-settlement batch.

| Document | Prior conflict | Resolution |
| --- | --- | --- |
| `docs/adr/0003-canonical-p0-domain-model-and-terms.md` | Watch owned `Try`, `Send`, `Fail`, and `Undo` | ADR 4 explicitly supersedes that sentence; ADR 3 keeps the historical wording with a superseded note |
| `CONTEXT.md` Product Rules | Required `Try/Send/Fail/Undo` | Migrated to Record Attempt, optional Mark Send, exact-target Undo, and explicit `not_sent` review |
| `docs/climbing_bouldering_prd_v0_1.md` | Separate Try/Send/Fail events and one mixed RouteCard status | Migrated to this Attempt model plus separate RouteCard visibility, availability, and Project cycles |
| `docs/climbing_bouldering_mvp_gate.md` | Field gate expected four Watch actions | Migrated to one primary tap, optional Send, unresolved review, and exact-target error recovery |
| `docs/climbing_bouldering_platform_contract.md` | Platform contract required try/send/fail/undo and conflated session ownership | Migrated to the revised actions and separate GymVisit/HealthKit workout ownership |
| `docs/climbing_bouldering_data_collection_plan.md` | Attempt required result at capture | Migrated to default `unresolved` plus explicit later confirmation |

Historical research documents remain unchanged evidence and do not override ADR 4, `CONTEXT.md`, or the focused active contracts.

## 17. Field Validation Still Required

The domain boundaries above are settled enough to prototype and test, but these product questions remain empirical:

| Question | Observe in real visits | Simplification signal |
| --- | --- | --- |
| Does one Attempt tap fit the natural post-climb moment? | Tap completion rate, annoyance, missed taps across at least three visits | User stops tapping by visit two or records only at review |
| Is optional Mark Send worth a second Watch action? | How often it is used correctly and how often review changes it | Send is usually entered later on iPhone |
| Do users need an in-session Not Sent action? | Whether unresolved review creates real burden | Keep it out if users tolerate unresolved/batch review |
| Is Undo's target understandable? | Accidental tap recovery without checking iPhone | Move recovery to a clearer recent-actions surface if users fear Undo |
| How often is route context wrong? | Unassigned/reassigned Attempts and route-switch burden | Reduce Watch switching or allow stronger batch assignment |
| Does one Project cycle per revisit intent match behavior? | Reopening sent/archived routes and repeated project periods | Use a simpler single current state only if history has no recall value |
| Can users distinguish archive from gone? | Terminology mistakes during route resets and cleanup | Change user-facing copy while retaining separate domain meanings |
| Can users recognize a reset versus a revision? | Ambiguous partial resets, hold tweaks, tag changes | Keep an `unknown change` path and defer successor creation to review |
| Are duplicate cards common and safely resolvable? | Duplicate rate, false merges, unmerge needs | Prefer suggestions only; delay merge UI if rare |
| Are approximate late times sufficient? | Whether sequence and rest remain useful after late-add | Let users order Attempts without requiring exact timestamps |
| Does offline replay preserve trust? | Lost, duplicated, delayed, and out-of-order actions on real paired devices | Block release if a retry can duplicate or retarget an action |
| Does review preserve useful unknowns? | Unresolved rate, review completion, NextSessionCue creation | Reduce required annotations before inventing automatic outcomes |

Real-device validation must include phone absent, delayed reconnection, Watch restart, app termination, accidental double tap, accidental End Visit, late Send, missed route switch, and review completed before late Watch delivery.

## 18. Implementation Readiness And P0 Validation

This document is ready to be used as implementation-planning input. Before implementation issues call the vocabulary formally settled, the conflicting ADR/PRD/platform wording must be explicitly superseded or updated.

The P0 release gate then requires:

- the Watch flow demonstrates one-tap Attempt, optional Send, and exact-target Undo;
- RouteCard/Project state examples are understandable across at least three real gym visits;
- cross-device acceptance scenarios A6-A8 and A20 pass on a real paired Watch/iPhone;
- field review can leave Attempts unresolved without breaking FailureEpisode, MoveCue, Project, or NextSessionCue creation.

P0 is not required to solve AI RouteRead, automatic fatigue, video reconstruction, or TrainingPath before this manual contract is proven.
