# LineWise Platform Contract

Date: 2026-07-13
Status: Historical for the current iPhone-only scope (PRD v1.1). Re-read before Watch or HealthKit work (PRD Demo 5).

## 1. Purpose

This contract defines what LineWise may claim, collect, infer, and rely on across Apple Watch, iPhone, HealthKit, Core Motion, WatchConnectivity, and future AI features.

It is written to prevent a common failure mode: building a product that looks smart in a demo but fails in a real climbing gym because of battery, privacy, sensor, sync, or trust issues.

## 2. Platform Split

| Surface | Owns | Does Not Own |
| --- | --- | --- |
| Apple Watch | Optional start/end workout capture, try/send/fail/undo, rest timer, sparse haptic | Product eligibility, route editing, photo annotation, AI route reading, long text, social flow |
| iPhone | RouteCard, quick/review/history capture, import preview, MoveCue, NextSessionCue, ProofCheck, photo/annotation, export, privacy controls | Real-time on-wall coaching |
| HealthKit | System workout record, heart rate/time/energy support | Route, attempt, send/fail, failure reason, movement truth |
| Core Motion | Suggested timeline evidence and future experiments | Guaranteed attempt detection |
| WatchConnectivity | Eventual sync between Watch and iPhone | Strong real-time truth layer |
| Cloud/AI | Future opt-in enrichment | P0 dependency or HealthKit upload target |

## 3. Watch P0 Contract

Watch must support:

- `Start Session`;
- `End Session`;
- elapsed time;
- current rest timer;
- `Try`;
- `Send`;
- `Fail`;
- `Undo`;
- sparse haptic cue;
- local persistence when iPhone is absent;
- eventual sync to iPhone.

Watch is an optional capture mode. The same product loop must remain available through iPhone quick capture or review-only entry when the user does not own a Watch, does not want to wear it, or the gym does not permit it.

Watch should avoid:

- scroll-heavy forms;
- text entry;
- route photo handling;
- failure taxonomy selection;
- route annotation;
- complex project management;
- dense charts;
- medical/safety suggestions.

## 4. Session Ownership

In `watch_capture` mode, the workout session owner should be Apple Watch.

Rationale:

- a workout session should start on Watch to access Watch workout data reliably;
- Watch is available during rest;
- iPhone may be away, locked, or in a bag;
- HealthKit climbing workout is best represented as a Watch workout.

iPhone may mirror state, but Watch must be able to record locally and sync later. In `iphone_quick_capture` and `review_only` modes, iPhone owns the local GymVisit and no Watch workout is required.

## 4.1 Wearability Contract

LineWise must not claim that wearing an Apple Watch while bouldering is universally safe or accepted.

Requirements:

- tell users to follow gym rules and their own comfort;
- allow the Watch mode to be disabled without losing product value;
- do not market a case, band, or sweatband as eliminating snag, impact, or breakage risk;
- test taps with chalk, sweat, fatigue, screen lock, gloves/tape, and different bands;
- record wearability separately from software usability in field studies;
- never encourage screen use while the user is on the wall or in a fall zone.

## 5. HealthKit Contract

HealthKit can be used for:

- creating a climbing workout;
- reading/writing workout duration;
- heart rate as supporting session context;
- active energy as non-core context;
- Apple Fitness/Health ecosystem integration.

HealthKit must not be used for:

- determining route completion;
- determining failure cause;
- precise fatigue/recovery claims;
- medical or safety advice;
- advertising, marketing, or profiling;
- cloud AI upload in P0.

Permission behavior:

- HealthKit is optional.
- Denying HealthKit must not block local RouteCard and attempt recording.
- Permission copy must explain exactly what data is used for.
- Failed HealthKit writes should preserve the app session and allow retry.
- Read permissions should be requested only when the user enters an import/review flow that needs them.
- Health records must not be sent to a third-party service or AI without a separate, explicit consent for that destination and purpose.

## 6. Heart Rate Contract

Heart rate is supporting evidence only.

Allowed:

- average HR;
- max HR;
- session-level intensity background;
- rough rest context;
- review chart if data quality is adequate.

Not allowed:

- "you are recovered";
- "you are safe/unsafe";
- "you should stop to avoid injury";
- precise fatigue score;
- single-attempt success/failure inference.

## 7. Core Motion Contract

Motion data may be collected for:

- suggested attempt/rest segmentation;
- debugging tap burden;
- future model experiments;
- rough active/rest rhythm.

Motion data must be treated as:

- noisy;
- user-specific;
- impacted by chalk, grip, wrist motion, and non-climbing actions;
- insufficient for full-body movement truth.

Any motion-derived result must be labeled as `suggested`.

No Core Motion result may be required to create an Attempt, FailureEpisode, MoveCue, or ProofCheck.

## 8. Core Location Contract

P0 should not require precise location.

Allowed:

- manual gym label;
- recent gym preset;
- optional future iPhone-side venue recall.

Not allowed in P0:

- required GPS;
- background location;
- safety tracking;
- outdoor route navigation;
- accident detection;
- automatic gym check-in as a core dependency.

## 9. Photo / Video Contract

P0 should not require full photo library access.

P0.5 may use:

- explicit camera capture;
- limited photo picker;
- single route photo import;
- local-only storage;
- user-initiated export.

Rules:

- default private;
- avoid unrelated people;
- crop/blur/discard if needed;
- respect gym rules;
- cloud AI requires explicit opt-in;
- video is optional and never required for the memory loop.

## 9.1 Historical Entry And Import Contract

LineWise must support records that did not originate in its own Watch app.

Allowed sources:

- `manual_history`;
- `health_import`;
- `fit_import`;
- `photo_import`;
- future partner imports with explicit provenance.

Every imported or historical object must preserve:

- source type;
- external source identifier or stable content hash when available;
- original timestamp and timezone if known;
- import timestamp;
- user review state;
- whether it is suggested, user-confirmed, edited, or rejected.

Rules:

- show an import preview before canonical commit;
- imported workout segments may suggest a timeline but cannot confirm Attempt, Send, Fail, FailureEpisode, or MoveCue;
- duplicate detection must be deterministic and reversible;
- re-import must be idempotent;
- import undo must remove only objects created by that import transaction;
- historical entry must allow partial truth and never invent missing sensor data;
- export must preserve provenance and correction history.

## 10. WatchConnectivity Contract

WatchConnectivity is an eventual sync layer.

Must support:

- Watch local event queue;
- iPhone receiving delayed events;
- idempotent sync;
- duplicate prevention;
- replay after disconnect;
- clear sync status in debug/review.

Canonical events must have app-generated durable IDs so Watch, iPhone quick capture, and review-only entry can share one idempotent model.

Must not assume:

- real-time delivery;
- simulator behavior equals paired-device behavior;
- phone is always nearby;
- network is available in the gym.

## 11. Low Power / Battery Contract

LineWise must degrade gracefully.

When battery or low-power conditions are detected or inferred:

- keep local event capture;
- reduce visual refresh;
- reduce haptic frequency;
- do not rely on continuous high-frequency HR;
- defer nonessential sync;
- preserve session end flow.

Do not build core value on continuous display, frequent haptics, or high-rate sensors.

## 12. AI Claim Contract

AI output must be:

- opt-in when using cloud services;
- editable;
- deletable;
- marked as suggested;
- accompanied by source/provenance;
- separate from user-confirmed facts.

AI output must not claim:

- official route truth;
- correct movement solution;
- routesetter intent unless setter-authored;
- safety advice;
- medical or injury-prevention advice;
- automatic send/fail truth.

## 13. App Store / Privacy Red Lines

P0 red lines:

- no precise location dependency;
- no full photo library dependency;
- no stranger matching;
- no HealthKit upload to cloud AI;
- no medical, safety, or recovery claims;
- no advertising use of health data;
- no open social feed;
- no account requirement unless deletion/export are designed.
- no silent import or automatic conversion from workout segment to confirmed climbing event;
- no color-only route identity;
- no inferred body/health profile from photos or video in P0/P0.5.

## 14. Required Disclaimers

LineWise copy and review notes should state:

- LineWise is not a medical device.
- LineWise is not a safety system or emergency service.
- LineWise does not replace a coach, spotter, or gym staff.
- AI suggestions are not official route information and may be inaccurate.
- Health data is used only for the user's own training record and review.
- Photos/videos are private by default and should follow gym rules and consent expectations.

## 15. Real-Device Validation

Must test on real paired Watch/iPhone:

- HKWorkoutSession lifecycle;
- screen-off and wrist lock behavior;
- heart rate missing/lagging;
- WatchConnectivity delay and replay;
- low-power mode;
- phone absent during session;
- local save after crash or app termination;
- battery drain over a full gym visit;
- haptic usefulness and annoyance.
- actual willingness to wear the Watch and any gym policy restrictions;
- no-Watch fallback completing the same RouteCard-to-ProofCheck loop.
- historical date, timezone, import preview, repeated import, undo, and export round-trip;
- route retrieval using non-color anchors.

## 16. Official Apple Sources

- [Apple Developer: Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
- [Apple Developer: Workouts HIG](https://developer.apple.com/design/human-interface-guidelines/workouts)
- [Apple Developer: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [Apple Developer: HKLiveWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder)
- [Apple Developer: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions)
- [Apple Developer: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple Developer: Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [Apple Developer: Core Motion](https://developer.apple.com/documentation/coremotion/)
- [Apple Developer: Core Location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [Apple Developer: WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity)
- [Apple Developer: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Developer: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple Support: Workout types on Apple Watch](https://support.apple.com/en-us/105089)
- [Apple Support: Apple Watch heart rate accuracy](https://support.apple.com/en-us/105002)
- [Apple Support: Low Power Mode on Apple Watch](https://support.apple.com/en-us/108320)
