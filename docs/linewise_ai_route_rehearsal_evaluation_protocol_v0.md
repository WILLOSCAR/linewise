# LineWise AI Route Rehearsal Evaluation Protocol v0

Date: 2026-08-11

Status: Intelligence Nursery evaluation contract; not a P0 release gate

Companion requirements: `docs/linewise_ai_route_rehearsal_requirements_v0.md`

Prototype under test: `prototypes/PROTOTYPE-route-rehearsal-x0.html`

## 1. Decision This Protocol Supports

This protocol decides whether RouteRehearsal deserves progressively more automation and geometric complexity.

It does **not** decide whether the P0 Gym Visit Memory System ships. P0 remains independently judged by its manual loop:

~~~text
GymVisit -> RouteCard -> Attempt -> FailureEpisode -> MoveCue -> NextSessionCue
~~~

The AI route mainline may be explored in parallel, but no X0-X5 result changes the P0 contract unless a separate product decision explicitly does so.

## 2. Core Evaluation Question

> Can an editable representation of route contacts and body poses help a climber form, inspect, try, and revise a movement idea — or is it only an attractive animation?

The evidence chain is intentionally cumulative:

~~~text
manipulable manually
  -> faster with assistance
  -> meaningfully personalized
  -> reconstructs an actual attempt
  -> changes a later decision or attempt
  -> benefits enough from 2.5D/3D to justify capture cost
~~~

Later stages cannot repair missing manual value. A technically impressive later prototype may still be stopped when the earlier value hypothesis fails.

## 3. Evaluation Principles

1. **Plans are hypotheses, not ground truth.** A planned sequence has no “correct beta” label.
2. **Observed, inferred, suggested, and confirmed remain separate.** Evaluation records must not collapse these provenances.
3. **Interaction correctness precedes visual preference.** Contact preservation, edit locality, and understandable state are measured before animation polish.
4. **A field consequence is stronger than stated enthusiasm.** “Looks useful” is weaker evidence than reopening a rehearsal, trying a cue, or changing a next attempt.
5. **No medical or safety inference.** Reach, joint, balance, fatigue, force, and injury statements remain qualitative and non-diagnostic.
6. **Compare against the cheapest baseline.** Each automated stage is compared with the preceding manual workflow and, where applicable, raw photo or raw video review.
7. **Report failures, corrections, and abandonment.** Do not report only completed rehearsals or attractive examples.
8. **Prototype findings do not imply production feasibility.** X0 in particular is a 2D state-model probe with a deterministic placeholder solver.

## 4. Evaluation Units

Keep these units distinct in every dataset and report:

| Unit | Meaning | Minimum identifier |
| --- | --- | --- |
| Participant | One climber or evaluator | `participant_id` |
| RouteScene | One route representation and its revision | `route_scene_id`, `scene_revision` |
| Route task | One participant working on one route in one mode | `task_run_id` |
| RouteRehearsal | One versioned plan or reconstruction | `rehearsal_id`, `rehearsal_version` |
| PoseKeyframe | One meaningful pose with four explicit contacts | `keyframe_id` |
| MovementStep | One transition between two keyframes | `from_keyframe_id`, `to_keyframe_id` |
| Suggestion | One model or deterministic-stub proposal | `suggestion_id`, `model_version` |
| CorrectionEvent | One user correction to scene, contact, pose, or provenance | `correction_id` |
| Field attempt | One later real attempt linked to a rehearsal or cue | `attempt_id` |
| ProofCheck | One user evaluation of whether the idea helped | `proof_check_id` |

Do not use animation exports, screenshots, or generated frames as independent successful samples. They inherit the evaluation status of the RouteRehearsal that produced them.

## 5. Prototype Ladder And Stage Decisions

| Stage | Capability under test | Required baseline | Main decision | Maximum allowed claim |
| --- | --- | --- | --- | --- |
| X0 | Manual 2D RouteScene, contacts, keyframes, debugger, animation | Photo + paper/text sequence | Is contact-first manual rehearsal understandable and useful enough to continue? | Users can manually express and inspect a candidate 2D sequence in tested tasks. |
| X1 | Suggested holds, route group, scale/wall hints | X0 manual setup | Does assistance reduce setup work without reducing correction clarity or trust? | Assistance was faster or required fewer actions on tested images. |
| X2 | BodyProfile and candidate Plan Mode sequences | Generic avatar and manual sequence | Does personalization change useful decisions, rather than only avatar appearance? | Tested profiles produced user-recognized differences in candidate rehearsals. |
| X3 | Video Replay reconstruction and contact inference | Raw video review + manual keyframe marking | Can users recover an attempt narrative faster and with usable provenance? | The system assisted reconstruction on tested videos with measured correction burden. |
| X4 | Plan/Actual alignment, MoveCue, MicroDrill, ProofCheck | Side-by-side manual review | Does the workflow change a later action and produce testable learning? | A cue was tried and users reported or exhibited a measured change; causality remains bounded by study design. |
| X5 | 2.5D/3D scene and dynamic motion | Best 2D workflow | Does added geometry improve a decision enough to justify capture and compute burden? | Extra geometry improved specified task metrics on tested routes and capture conditions. |

Stages are evidence labels, not release milestones. It is valid to stop at a useful X0/X1 tool or to run a bounded X3 probe while X2 remains unresolved, provided the missing evidence is stated.

## 6. Shared Test Corpus

Build a small, intentionally awkward corpus before broad recruitment. Every release of the corpus receives a version and keeps retired examples for regression comparison.

### 6.1 Route categories

Include at least:

- vertical or slight overhang with clear isolated holds;
- slab with smears or a free flag;
- steep wall with foreshortening;
- a large shared volume;
- matched start or two-hand start;
- hand swap or foot swap;
- cross-through;
- one coordination or dynamic move that the current model should decline or mark uncertain;
- topout or terminal move partly outside the image plane;
- same-color distractor holds or tag-based route identity;
- an occluded start/top or partially hidden hold;
- a reset/version-change case.

### 6.2 Participant variation

At minimum, record self-described experience band and whether the route is familiar. For X2+, include varied height and wingspan inputs, including generic/no-profile use.

Do not infer ability, health, injury, or safety from body measurements.

### 6.3 Media conditions

For X1-X5, include:

- well-framed source media;
- perspective distortion;
- partial occlusion;
- low light or motion blur;
- another person entering frame;
- source replacement after corrections exist.

Third-party faces and bodies require consent or test media created for evaluation.

## 7. X0 Task Set

The same task wording should be used across sessions. Facilitators may clarify terminology but must log every intervention.

### T0 — Orient without teaching the solution

Prompt:

> “请用这个页面表示你觉得可能的一套爬法。这里没有正确答案；如果哪里不可信，请把它留下或说出来。”

Observe whether the participant distinguishes RouteScene, current pose, timeline, and Plan/Actual without being told what to click.

### T1 — Build or correct the RouteScene

1. Inspect the synthetic route or supplied photo reference.
2. Add one missing hold manually.
3. Identify start and top verbally; X0 may not yet persist all roles.
4. State one geometry assumption that the 2D scene cannot know.

Record scene setup time, incorrect additions, facilitator help, and whether the 2D limitation is understood.

### T2 — Establish four starting contacts

1. Select each of LH, RH, LF, and RF.
2. Put each on a hold, ground, free, or smear state.
3. Lock the contacts that should remain fixed.
4. Explain what a lock means.

Success requires four explicit contact states. A visually plausible stick figure with missing semantic contacts is not success.

### T3 — Author a five-keyframe sequence

1. Add or duplicate keyframes.
2. Move one limb at a time for at least three steps.
3. Include one match, swap, flag, or smear if the route calls for it.
4. Reorder one keyframe.
5. Delete one mistaken keyframe.

Record total time, action count, undo count, invalid actions, and full-body repair burden after each contact change.

### T4 — Debug a locked contact conflict

1. Attempt to move a locked limb.
2. Explain why the action was rejected.
3. Unlock it deliberately.
4. Move and re-lock it.

Critical invariant: the locked target never changes silently.

### T5 — Edit upstream and inspect stale downstream state

1. Change a contact in an early keyframe.
2. Identify every downstream keyframe marked stale.
3. Generate a current-only deterministic candidate.
4. Reject or accept it.
5. Generate downstream candidates.
6. Distinguish `suggested` from user-confirmed.

Critical invariant: current-only regeneration must not clear unrelated downstream stale state.

### T6 — Step, scrub, loop, and play continuously

1. Move Prev/Next through all keyframes.
2. Play one transition and scrub to its midpoint.
3. Enable loop for one transition.
4. Play the full sequence.
5. Name which contact changes in two selected transitions.

Record contact sliding, unexplained simultaneous changes, keyframe skipping, or loss of orientation.

### T7 — Compare Plan and Actual

1. Switch between Plan and Actual.
2. Enable the overlay.
3. Find one contact difference.
4. Reach a point where one track has no index-matched frame.
5. Explain why index equality is not semantic step alignment.

X0 success is understanding the limitation, not solving alignment.

### T8 — Produce a useful takeaway

Ask the participant to state:

- the candidate movement idea;
- one uncertainty;
- one thing they would try on the wall;
- whether a one-to-three-step StickFigureCue would be worth reopening.

Do not count generic praise such as “动画挺酷” as a useful takeaway.

## 8. Built-In Awkward Scenarios

The X0 HTML provides deterministic walkthroughs for regression and moderated sessions:

| Scenario | Invariant under pressure | Expected result |
| --- | --- | --- |
| Locked match | Two hands share a hold; one is moved while locked | Move is rejected; no contact silently changes. |
| Upstream stale chain | An early contact changes before several downstream frames | Downstream frames become stale; scoped stub regeneration stays suggested. |
| Reorder during playback | A keyframe reorder is requested mid-transition | Reorder is rejected until Pause; stable frame IDs remain. |
| Plan/Actual length mismatch | Actual has fewer frames than Plan | Navigation stays in bounds; unmatched tail is shown as unresolved, not auto-aligned. |

These scenarios validate reducer behavior, not usability by themselves.

## 9. Annotation Contract

### 9.1 Provenance labels

Every evaluated scene element, contact, keyframe, and comparison statement uses one of:

| Label | Meaning |
| --- | --- |
| `user-authored` | Entered manually without a suggestion. |
| `suggested` | Proposed by a model or deterministic stub and not confirmed. |
| `accepted-suggestion` | Accepted into the rehearsal but still visibly model-sourced. |
| `user-corrected` | A suggestion changed by the user; original remains recoverable. |
| `user-confirmed` | Explicitly confirmed by the user. |
| `observed` | Directly visible in source video at usable confidence. |
| `inferred-from-video` | Filled across occlusion or ambiguous contact. |
| `unknown` | Evidence is insufficient; not silently imputed. |

For X0, `deterministic-stub-v0` is a suggestion source, never AI evidence.

### 9.2 Interaction labels

Annotate each task event as:

- `successful-action`;
- `rejected-as-designed`;
- `wrong-target`;
- `wrong-limb`;
- `mode-confusion`;
- `provenance-confusion`;
- `timeline-confusion`;
- `facilitator-intervention`;
- `undo-recovery`;
- `abandoned`.

### 9.3 Qualitative observation labels

Use short evidence-linked notes:

- `movement-idea-articulated`;
- `constraint-articulated`;
- `uncertainty-articulated`;
- `full-body-repair-required`;
- `animation-only-delight`;
- `field-action-intended`;
- `field-action-tried`;
- `field-action-changed`;
- `tool-distracted-from-route-reading`.

Annotators should quote no more participant speech than consent allows and should distinguish observation from interpretation.

### 9.4 Suggested record shape

~~~json
{
  "protocol_version": "route-rehearsal-eval/v0",
  "stage": "X0",
  "participant_id": "local-pseudonym",
  "task_run_id": "run-id",
  "route_scene_id": "scene-id",
  "scene_revision": 1,
  "task_id": "T5",
  "event": "contact_changed",
  "object_id": "P2.LF",
  "provenance": "user-authored",
  "outcome": "successful-action",
  "elapsed_ms": 1840,
  "facilitator_intervention": false,
  "claim_boundary_acknowledged": true,
  "note": "Downstream stale state identified without prompting"
}
~~~

## 10. Metrics

### 10.1 X0 primary metrics

| Metric | Definition | Why it matters |
| --- | --- | --- |
| Five-keyframe completion | Participant completes T2-T3 with four explicit contacts per frame | Tests whether the manual representation is operable. |
| Independent completion | Completion without facilitator action-level instruction | Separates learnability from coached demonstration. |
| Locked-contact violations | Number of times a locked contact changes without an explicit unlock | Must remain zero; this is an invariant, not an average KPI. |
| Contact interpretation accuracy | Participant correctly names changed/retained contacts in sampled steps | Tests whether animation is legible. |
| Authoring time | T2-T3 elapsed time, reported with route complexity | Measures burden; never report without task context. |
| Repair burden | Keyframes requiring manual torso/joint repair after a limb change | Tests whether contact editing has leverage. |
| Undo recovery rate | Mistakes recovered without restart | Tests whether exploration is reversible. |
| Stale-state comprehension | Participant predicts what an upstream edit invalidates | Tests single-step debugger trust. |
| Provenance comprehension | Participant distinguishes suggested, observed, and confirmed | Required before introducing real AI. |
| Actionable takeaway | Participant states a specific move/cue and uncertainty | Separates movement value from visual novelty. |

### 10.2 Later-stage comparative metrics

| Stage | Compare | Primary deltas |
| --- | --- | --- |
| X1 | Assisted vs manual RouteScene setup on matched images | Time, actions, correction count, restart rate, low-confidence recovery. |
| X2 | Generic vs BodyProfile plan, order balanced | Blind usefulness preference, meaningful sequence/contact difference, correction burden. |
| X3 | Raw video vs assisted Replay | Time to meaningful keyframes, contact precision/recall against human annotation, occlusion correction burden. |
| X4 | Review-only vs rehearsal/cue workflow where feasible | Cue attempted, sequence change, perceived/observed divergence, ProofCheck completion, next-visit recall. |
| X5 | 2D vs 2.5D/3D for routes selected to need geometry | Decision change, error reduction, capture time, failure rate, compute/latency, user preference with reason. |

### 10.3 Reporting rules

- Report numerator and denominator, not percentage alone.
- Report median, range, and individual failures for small formative samples.
- Separate familiar and unfamiliar routes.
- Separate route-level failures from participant-level failures.
- Report every facilitator intervention.
- Keep planned-sequence preference separate from real attempt outcome.
- Keep subjective usefulness separate from observed field action.
- Treat repeated tasks by one participant as correlated, not independent samples.
- Do not pool X0 synthetic-wall results with X1+ real-photo results.

## 11. Failure Taxonomy

Each failed or abandoned task receives one primary category and optional contributing categories.

| Code | Category | Examples | Likely response |
| --- | --- | --- | --- |
| `F-SCENE` | RouteScene representation | Wrong route group, missing/occluded hold, perspective makes contact meaningless | Improve correction/scale or narrow supported captures. |
| `F-CONTACT` | Contact semantics | Wrong limb, match/smear/free cannot be expressed, lock misunderstood | Deepen contact model or simplify editor language. |
| `F-POSE` | Pose solving | Full-body repair, limb stretch, teleport, implausible torso | Improve constrained solver or pivot to contact-only visualization. |
| `F-TIME` | Timeline model | Keyframe/step distinction unclear, reorder loses intent | Redesign sequence operations and labels. |
| `F-PLAY` | Playback integrity | Locked sliding, skipped frame, unexplained simultaneous move | Stop animation claims until deterministic playback is fixed. |
| `F-STALE` | Dependency invalidation | Upstream edit leaves false-valid downstream state | Fix model before adding automation. |
| `F-PROV` | Provenance/trust | Suggested treated as observed or correct | Stop AI expansion; redesign source/status display. |
| `F-COMPARE` | Plan/Actual alignment | Index alignment presented as semantic match, unmatched steps hidden | Keep comparison manual or build explicit alignment. |
| `F-EXPLAIN` | Qualitative interpretation | User cannot say what changed or why | Reduce visual complexity; expose contact diffs and cues. |
| `F-VALUE` | Product value | Enjoyed animation but no route decision, cue, or later reuse | Pivot or stop the mainline. |
| `F-CAPTURE` | Media burden | Photo/video setup too slow, privacy concerns, unusable occlusion | Narrow capture flow or avoid that modality. |
| `F-DYNAMIC` | Model boundary | Dyno/coordination represented as static interpolation | Mark unsupported; do not conceal with polish. |
| `F-PRIVACY` | Consent/data boundary | Third party captured, body media destination unclear | Stop test and repair protocol/data handling. |

Crashes and UI defects also receive an engineering bug identifier. They do not replace the product-failure label when both occurred.

## 12. X0 Decision Rules

These are explicit calibration rules for the first bounded study, not industry benchmarks. Review them after a small pilot, freeze them before the decision sample, and report any change.

### 12.1 Continue to X1 when all are true

- locked-contact violations are `0` across completed tasks;
- at least `7/10` participants complete a five-keyframe rehearsal after one short orientation, with at least `5/10` completing without action-level facilitator instruction;
- at least `7/10` correctly identify changed contacts in two sampled MovementSteps;
- at least `7/10` distinguish a deterministic `suggested` result from user-confirmed state;
- at least `6/10` produce a route-specific cue or uncertainty they say they would use, rather than only praising the animation;
- median full-body repair affects no more than one of five authored keyframes;
- no unresolved P0 dependency is introduced.

### 12.2 Pivot rather than add AI when any is true

- users value the contact sequence but not the solved body pose: pivot toward a simpler contact-path or StickFigureCue editor;
- users understand steps but authoring is too slow: test templates, duplication, or assisted scene setup before generation;
- pose repair is high but contact semantics remain valuable: improve or remove the solver before X1/X2;
- route reading happens verbally or through annotations more naturally than through full-body manipulation: pivot to cue-first rehearsal;
- Plan is useful but Plan/Actual overlay confuses: keep the modes separate and delay Compare.

### 12.3 Kill or park the RouteRehearsal mainline when either is true

- fewer than `3/10` participants can produce a route-specific cue or decision after completing the guided workflow; or
- across at least three real-gym follow-ups, participants repeatedly choose a photo/text note over reopening even a short rehearsal, and interviews identify no correctable interaction or capture problem.

A kill/park result does not delete collected knowledge and does not block Gym Visit Memory P0. It means no more model, 3D, or motion investment until a materially different hypothesis exists.

### 12.4 Mandatory engineering stop conditions

Stop the relevant test build before broader study if:

- a locked contact changes silently;
- undo/redo corrupts or drops semantic contacts;
- playback changes discrete keyframe order or identity;
- current-only regeneration modifies unrelated frames;
- suggested output loses its provenance label;
- comparison hides an unmatched Plan or Actual step;
- source media or body data crosses the stated privacy boundary.

These are defects, not participant outcomes.

## 13. X1-X5 Promotion, Pivot, And Kill Rules

### X1 — Assisted RouteScene

Promote when assistance produces a meaningful median setup-time or action-count reduction on the same images, while route-critical correction errors and provenance confusion do not increase.

Pivot when suggestions are useful only as visual highlighting; retain that narrower assistance instead of claiming scene recovery.

Kill automation for unsupported media classes when users usually delete/restart rather than correct, or when low-confidence regions are not recoverable.

### X2 — Personalized Plan Mode

Promote when generic and personalized conditions are compared in balanced order and a majority of tested participants identify at least one useful, body-related contact or sequence difference that survives correction.

Pivot to explicit reach filters or user-selected style constraints when full BodyProfile generation adds little beyond one or two measurements.

Kill personalization claims when outputs differ visually but not in a decision the participant understands or uses.

### X3 — Replay Mode

Promote when assisted reconstruction is faster than raw-video/manual marking for meaningful keyframes, and observed versus inferred contacts remain distinguishable under occlusion.

Pivot to user-marked keyframes with pose assistance when end-to-end tracking is brittle.

Kill automatic-contact claims for capture classes where correction takes as long as or longer than manual annotation, or provenance is routinely misunderstood.

### X4 — Compare And Training

Promote when participants take at least one specific cue into a later attempt, complete a ProofCheck, and the workflow yields a measurable difference worth investigating. A route send alone does not prove causality.

Pivot to recall and reflection when cues aid memory but do not produce a stable performance effect.

Kill TrainingPath coupling when content recommendations remain generic, are not tried, or cannot be traced to a user-confirmed FailureEpisode.

### X5 — 2.5D/3D And Dynamic Motion

Promote only on route classes where added geometry changes a useful decision or materially reduces a known 2D error, after capture time, failure rate, latency, and privacy burden are included.

Pivot to selective depth hints or multi-photo calibration when full reconstruction is unnecessary.

Kill broad 3D/dynamic scope when its benefit is mainly visual fidelity, when capture burden prevents field use, or when physics-like presentation causes users to over-trust feasibility or safety.

## 14. Claim Ceiling

### 14.1 X0 allowed conclusion

An acceptable X0 report may say:

> “In this bounded formative test, participants could/could not manually author and inspect candidate 2D contact sequences with the measured burden and failure modes.”

It may not say:

- the move is physically feasible;
- the sequence is correct or setter-intended;
- animation predicts real movement;
- the user can execute the move;
- reach or joint findings are safety judgments;
- a deterministic stub demonstrates AI quality;
- field performance improved without field evidence.

### 14.2 X1-X3 allowed conclusion

Assistance may be described as reducing measured work or aiding reconstruction on the tested corpus. Do not generalize to unseen gyms, camera conditions, bodies, route styles, or dynamic movement without corresponding evidence.

### 14.3 X4 allowed conclusion

Without a suitable controlled design, report that the workflow was followed by a tried cue, reported usefulness, or observed change. Do not claim the rehearsal caused a send or prevented injury.

### 14.4 X5 allowed conclusion

Report the route classes and decisions where geometry helped. Do not call a visually plausible dynamic motion physically guaranteed, safe, or biomechanically accurate.

## 15. Session Procedure

### Before

1. Record prototype commit/file hash, browser/device, protocol version, and corpus version.
2. Confirm consent for screen, audio, route photo, and body/video data separately.
3. Explain that there is no correct movement answer and no safety advice.
4. Randomize condition order where the stage has a baseline comparison.
5. Verify the full-state and provenance panels are visible to the facilitator.

### During

1. Read task prompts consistently.
2. Let the participant think aloud, but do not lead them to a sequence.
3. Timestamp interventions and defects.
4. Capture state before and after every critical invariant test.
5. Ask what the participant believes each suggested/observed/confirmed label means.
6. Stop immediately for privacy or consent violations.

### After

1. Ask for one movement takeaway, one uncertainty, and one rejected idea.
2. Ask whether they would reopen a full rehearsal, a short StickFigureCue, text, or the original photo before climbing.
3. Export or copy the final state only under the agreed data handling plan.
4. Link any later field attempt and ProofCheck without overwriting the original plan.
5. Classify abandonment and failures before discussing feature preferences.

## 16. Review Template

Every stage review should contain:

1. **Decision sought** and frozen thresholds.
2. **Build and corpus provenance**.
3. **Participants and exclusions**, with reasons.
4. **Task completion table**, including interventions.
5. **Invariant results** and engineering defects.
6. **Metric distributions**, not only averages.
7. **Failure taxonomy counts** with representative state snapshots.
8. **Provenance/trust findings**.
9. **Field consequence**, if any.
10. **Claim ceiling** for the evidence collected.
11. **Decision**: continue, pivot, park/kill, or repeat after a named defect fix.
12. **P0 independence check** confirming that no Gym Visit Memory dependency was introduced.

## 17. X0 Prototype Coverage And Known Gaps

The current single-file X0 prototype directly covers:

- synthetic editable RouteScene with manual hold addition;
- explicit LH, RH, LF, and RF contacts;
- click or drag-to-hold editing;
- explicit contact locks;
- add, duplicate, delete, and reorder keyframes;
- Prev/Next, transition playback, full playback, Pause, scrub, speed, and loop;
- previous/next ghosts and contact diff;
- Undo/Redo;
- deterministic current/downstream regeneration placeholders marked `suggested`;
- Plan/Actual switching and index-based comparison placeholder;
- visible complete current state and invariants;
- four awkward guided walkthroughs.

It intentionally does **not** establish:

- real-photo RouteScene recovery;
- a biomechanical, collision, balance, or physics solver;
- persistence or reopening across launches;
- semantic Plan/Actual alignment;
- branches, split/merge coordinated moves, or dynamic motion;
- production accessibility, localization, latency, or privacy implementation;
- any AI model quality;
- any real-gym training effect.

These gaps must remain visible when interpreting X0 results. They are not silently converted into roadmap commitments.

## 18. P0 Independence Contract

RouteRehearsal remains an Intelligence Nursery module under these rules:

- P0 onboarding must not require route photos, BodyProfile, video, or rehearsal authoring.
- P0 attempt logging, review, MoveCue, and NextSessionCue must work when every X-stage service is absent.
- A RouteRehearsal may produce a MoveCue later, but MoveCue must remain manually authorable.
- P0 storage and sync schemas must not wait for RouteScene, skeleton, or animation schemas.
- X-stage failure, cost, latency, privacy refusal, or model unavailability must not block a GymVisit.
- P0 success metrics and release gates are reported separately from X0-X5 evidence.
- Shared identifiers or exports require an explicit interface decision, not an implicit cross-module dependency.

The final promotion question is therefore not “Can the demo animate?” It is:

> “Does this module add a trusted, correctable movement decision to a manual product that already works without it?”
