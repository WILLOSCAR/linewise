# LineWise Platform Contract

Date: 2026-07-01  
Status: Active Apple Watch / iPhone / HealthKit contract for P0

## 1. Purpose

This contract defines what LineWise may claim, collect, infer, and rely on across Apple Watch, iPhone, HealthKit, Core Motion, WatchConnectivity, and future AI features.

It is written to prevent a common failure mode: building a product that looks smart in a demo but fails in a real climbing gym because of battery, privacy, sensor, sync, or trust issues.

## 2. Platform Split

| Surface | Owns | Does Not Own |
| --- | --- | --- |
| Apple Watch | Optional workout start/end, one-tap Attempt, optional Send, exact-target Undo, rest timer, sparse haptic | Route editing, Not Sent/failure interpretation, photo annotation, AI route reading, long text, social flow |
| iPhone | RouteCard, review, MoveCue, NextSessionCue, photo/annotation, export, privacy controls | Real-time on-wall coaching |
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
- `Record Attempt` as one primary action;
- optional `Mark Send` on one existing Attempt;
- exact-target `Undo`;
- sparse haptic cue;
- local persistence when iPhone is absent;
- eventual sync to iPhone.

Watch should avoid:

- scroll-heavy forms;
- text entry;
- route photo handling;
- failure taxonomy selection;
- route annotation;
- complex project management;
- dense charts;
- medical/safety suggestions.

## 4. GymVisit And Workout Ownership

The app-domain `GymVisit` and the optional HealthKit workout have separate ownership.

- LineWise app-private storage owns GymVisit identity and bouldering semantics.
- Apple Watch owns an authorized HealthKit workout session when the user starts one on Watch.
- iPhone-only use creates a valid GymVisit without fabricating a Watch or HealthKit workout.
- HealthKit denial, workout failure, or phone-only capture must not block RouteCard, Attempt, review, or recall.

Why Watch remains the preferred workout surface:

- a workout session should start on Watch to access Watch workout data reliably;
- Watch is available during rest;
- iPhone may be away, locked, or in a bag;
- HealthKit climbing workout is best represented as a Watch workout.

iPhone may mirror state, but Watch must be able to record locally and sync later. A GymVisit may also begin on iPhone when Watch is absent; that degraded path has no requirement to create a HealthKit workout.

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

## 10. WatchConnectivity Contract

WatchConnectivity is an eventual sync layer.

Must support:

- Watch local event queue;
- iPhone receiving delayed events;
- idempotent sync;
- duplicate prevention;
- replay after disconnect;
- stable event identities and exact causal targets for Send, Undo, route assignment, and corrections;
- unresolved dependent events when a target arrives later;
- clear sync status in debug/review.

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

The normative Attempt, Project, review, and cross-device event meanings are defined by `docs/linewise_p0_domain_and_lifecycle_contract_v0.md` and ADR 4. Platform adapters must preserve those meanings rather than reinterpret delayed events from arrival order.

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
