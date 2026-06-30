# LineWise Data Collection Plan

Date: 2026-07-01  
Status: Active plan for real indoor bouldering data collection

## 1. Purpose

LineWise needs real gym data before it can credibly build AI-assisted route reading, stick-figure movement cues, SetterLens, or TrainingPath.

The goal is not to collect a huge dataset first. The goal is to collect a small, high-quality, corrected personal dataset that proves whether the product loop is useful and whether route photos can support future AI.

## 2. Data Collection Principles

1. **User correction is the asset.** A corrected route photo is more valuable than many unverified photos.
2. **Collect ordinary gym photos.** The dataset should reflect how a real user will shoot, not lab-perfect images only.
3. **Privacy first.** Avoid unrelated people in photos/videos. Crop or discard when needed.
4. **No official truth claims.** User labels are personal memory, not official gym route data.
5. **Capture why failure happened.** Attempt outcome alone is not enough.
6. **Link everything to RouteCard.** Photos, attempts, cues, and failures need route identity.

## 3. Field Session Checklist

Before entering the gym:

- Apple Watch charged.
- iPhone storage available.
- Decide whether this is a normal session, Watch test, or dataset session.
- Check whether the gym allows route photos/videos.

During the gym visit:

- Create RouteCards for meaningful routes.
- Mark attempts on Watch when practical.
- Record one MoveCue when a route produces a useful lesson.
- Avoid photographing unrelated people.
- If a wall is crowded, wait, crop, or skip photo capture.

After the visit:

- Review the session within 24 hours.
- Attach attempts to RouteCards.
- Add FailureEpisodes and NextSessionCue.
- Mark data quality.
- Export/debug if needed.

## 4. P0 Required Data

| Object | Required Fields | Optional Fields |
| --- | --- | --- |
| `GymVisit` | start_at, end_at, modality=indoor_bouldering, review_state | gym_label, session_focus |
| `RouteCard` | label, status | gym_label, wall_area, color, grade_text, subjective_grade, photo_ref |
| `Attempt` | route_card_id?, result, timestamp | duration, rest_after, source |
| `RestInterval` | start_at, end_at | route_card_id, reason |
| `FailureEpisode` | route_card_id, primary_blocker | attempt_id, location_note, confidence |
| `MoveCue` | route_card_id, text | source, linked_failure_episode |
| `NextSessionCue` | route_card_id, cue_text | reminder_context |
| `CorrectionEvent` | object_type, event_type, timestamp | before, after, latency_ms |

## 5. P0.5 Photo Data

For each route selected for dataset mode, collect:

| Data | Rule |
| --- | --- |
| `wall_context_photo` | Wider shot showing where the route sits on the wall |
| `route_focused_photo` | Closer shot where holds/tags are clear |
| `shot_type` | `wall_context` or `route_focused` |
| `angle_bucket` | `front`, `slight_side`, `steep_side` |
| `lighting_bucket` | `good`, `glare`, `dim`, `mixed` |
| `occlusion_bucket` | `clear`, `partial_person`, `crowded`, `blocked` |
| `route_display_color` | User-labeled color or tag color |
| `color_mode` | `hold_color`, `tag_color`, `mixed`, `unknown` |
| `start/top` | User tap if visible |
| `quality_state` | `complete`, `partial`, `noisy`, `discard` |

Photo rules:

- Prefer 1x lens.
- Include the full route when possible.
- Avoid heavy angle distortion.
- Avoid unrelated people.
- If someone is in frame, crop, blur, ask consent, or discard.
- Do not upload photos to cloud AI without explicit opt-in.

## 6. Optional Video Data

Video is not required for P0.

Use video only when:

- the gym allows it;
- no unrelated person is identifiable or consent is clear;
- the route is valuable for future movement analysis;
- the user accepts that video is private by default.

Video fields:

| Field | Meaning |
| --- | --- |
| `video_ref` | Local reference |
| `route_card_id` | Linked route |
| `attempt_id` | Linked attempt if known |
| `viewpoint` | `front`, `side`, `diagonal`, `unknown` |
| `contains_other_people` | boolean |
| `consent_state` | `self_only`, `consented`, `cropped`, `discard` |

Do not build P0 around video analysis.

## 7. Annotation Schema For AI Preparation

P0.5 should introduce these dataset objects.

### Photo

| Field | Meaning |
| --- | --- |
| `id` | Photo ID |
| `route_card_id` | Linked RouteCard |
| `shot_type` | `wall_context` or `route_focused` |
| `timestamp` | Capture time |
| `angle_bucket` | Camera angle quality |
| `lighting_bucket` | Lighting quality |
| `occlusion_bucket` | Occlusion quality |
| `quality_state` | `complete`, `partial`, `noisy`, `discard` |

### HoldInstance

| Field | Meaning |
| --- | --- |
| `id` | Hold ID |
| `photo_id` | Source photo |
| `mask_or_polygon` | Segmentation or user outline |
| `bbox` | Bounding box fallback |
| `is_volume` | Large volume flag |
| `partial_visibility` | Partial hold visible |
| `dominant_color` | User/model color |
| `source` | `user`, `model`, `verified` |

### RouteGroup

| Field | Meaning |
| --- | --- |
| `id` | Route group ID |
| `photo_id` | Source photo |
| `hold_ids` | Holds belonging to route |
| `route_display_color` | Route color/tag |
| `color_mode` | `hold_color`, `tag_color`, `mixed`, `unknown` |
| `grade_text` | Visible or user-entered grade |
| `source` | `user`, `model`, `verified` |

### RouteRole

| Role | Meaning |
| --- | --- |
| `start_hand` | Start hand hold |
| `start_foot` | Start foot hold |
| `intermediate` | Normal hold |
| `zone` | Zone/intermediate target if used by gym |
| `top` | Finish hold |
| `unknown` | Role unclear |

### MoveSequence

| Field | Meaning |
| --- | --- |
| `step_index` | Sequence order |
| `limb` | `LH`, `RH`, `LF`, `RF` |
| `target_hold_id` | Target hold |
| `sequence_source` | `user_authored`, `video_observed`, `model_suggested` |
| `body_mode` | `short`, `medium`, `tall`, `unknown` |

### CorrectionEvent

| Event Type | Meaning |
| --- | --- |
| `add` | Add missing hold/role/cue |
| `remove` | Remove wrong item |
| `split` | Split merged mask |
| `merge` | Merge fragmented mask |
| `recolor` | Correct color |
| `reorder` | Correct sequence |
| `re_role` | Correct start/top/zone |
| `override` | User replaces suggestion |

CorrectionEvent is important because it records what the model or UI got wrong.

## 8. FailureEpisode Taxonomy

Use one primary blocker per failure.

| Blocker | Meaning |
| --- | --- |
| `sequence` | Wrong order, wrong read, missed foot |
| `footwork` | Poor foot placement or trust |
| `body_position` | Hip, balance, center of mass |
| `body_tension` | Cut loose, swing, core tension |
| `dynamic_timing` | Timing, coordination, deadpoint/dyno |
| `reach_or_lockoff` | Reach, lock-off, contact strength |
| `hook_or_compression` | Heel/toe hook, squeezing, opposition |
| `topout_or_finish` | Finish, mantle, match, top stability |
| `fear_or_commitment` | Hesitation, fall fear, high move |
| `endurance_or_pacing` | Too tired or rest too short |
| `unknown` | Not sure |

Do not require secondary tags in P0.

## 9. Dataset Quality States

| State | Meaning | Use For AI? |
| --- | --- | --- |
| `complete` | Route and key labels are clear | Yes |
| `partial` | Useful but missing some labels | Maybe |
| `noisy` | Occluded, blurry, ambiguous, or heavily angled | Evaluation only |
| `discard` | Privacy, bad image, route unclear | No |

## 10. First 5 Gym Visits Plan

| Visit | Goal | Minimum Output |
| --- | --- | --- |
| 1 | Memory baseline | 3 RouteCards, 3 attempts, 1 NextSessionCue |
| 2 | Watch burden | 1 full Watch session, 10+ attempt events |
| 3 | Route photo quality | 5 route-focused photos, 5 wall-context photos |
| 4 | Failure taxonomy | 10 FailureEpisodes, 5 MoveCues |
| 5 | Dataset correction | 5 annotated routes, correction time recorded |

After 5 visits, answer:

- Is this easier than notes/photos?
- Are the fields too many?
- Which photos are usable?
- Does Watch capture survive the gym?
- Is NextSessionCue actually reopened?

## 11. Privacy Rules

- Do not collect precise location in P0.
- Do not require full photo library access.
- Prefer explicit photo capture or limited picker.
- Do not upload health data to cloud AI.
- Do not upload photos/videos without explicit opt-in.
- Crop/blur/discard photos with unrelated people.
- Respect gym photo/video rules.
- Keep export/delete paths clear once accounts exist.

## 12. Stop Conditions

Stop collecting a data type if:

- it creates social discomfort in the gym;
- it interrupts climbing flow;
- it violates gym rules;
- it requires unsafe phone handling near the wall;
- it produces data too noisy to review;
- it makes the user avoid using LineWise.

The product exists to improve climbing memory, not to make training feel like annotation labor.
