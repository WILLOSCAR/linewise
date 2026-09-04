# LineWise / 线感

LineWise is a local-first bouldering companion for Apple Watch and iPhone. The Watch captures low-interruption attempt, result, and rest anchors; the iPhone owns route/project memory, explicit review, correction, recall, rehearsal, and training follow-through.

The repository now contains an end-to-end implementation foundation. P0 remains manual-first: AI and deterministic analysis can suggest, but they cannot silently rewrite confirmed user history.

## Implemented Product Surface

### Manual P0 loop

- One-tap `Attempt`, explicit `Send` / `Not Sent`, exact-target `Undo`, and rest timing.
- Honest unresolved outcomes when a result has not been confirmed.
- Route cards, repeatable project cycles, gym visits, quick review, and next-session recall.
- Route rename, availability correction, archive/restore, merge/unmerge, attempt reassignment, and project archive with an audit trail.
- Late and out-of-order events reopen review instead of being silently discarded.

### Persistence and cross-device behavior

- Local-first Watch and iPhone capture with stable action IDs and deterministic replay.
- Replay work is compacted by a checkpointed incremental fold rather than by truncating the log, so a late event that sorts before a checkpoint still reopens review.
- Versioned JSON stores, migration, atomic file replacement, inbox/outbox, retry, and duplicate suppression.
- The experience archive decodes archives written by an older same-schema writer that omits newer collections, instead of rejecting them.
- A Watch event is acknowledged only after the reliable WatchConnectivity transfer completion callback; received payloads stay in a durable inbox until repository persistence succeeds.
- Ending a visit on Watch creates stable unresolved/unassigned Review Inbox work on iPhone and safely retries that reconciliation after restart or write failure.
- Full export and deletion APIs; redacted diagnostics omit route labels, health values, timestamps, and device IDs.
- Persistent experience state covers review, recall, training, physiology context, rehearsal, and active rest.

### Physiology context

- Subjective fatigue and pump are the primary user inputs.
- Health recording is an explicit user choice: starting a manual visit does not request HealthKit authorization, and denial or workout failure never blocks capture.
- HealthKit workout summaries are optional supporting context, including a heart-rate coverage fraction accumulated from the samples actually collected during the workout.
- Physiology output is explicitly non-diagnostic; raw sensor streams are not treated as proof of muscle state. Low coverage means an incomplete sensor stream, never a health judgment.

### Route rehearsal and learning

- Editable 2D route scenes and hold contacts for both hands and feet.
- Stick-figure pose solving, contact locks, keyframe add/duplicate/delete/reorder, downstream stale marking, and recompute.
- Plan and Actual timelines, continuous playback, looping, scrubbing, and single-step inspection.
- Per-step MovementIntent for purpose, movement family, rhythm, felt cue, and explicit uncertainty; related contact edits mark old guidance for review.
- One-to-three-step practice segments that can be pinned as a StickFigureCue, looped independently, and supplied to qualitative analysis.
- Deterministic Plan/Actual comparison across limb contacts, torso movement, and timing.
- Failure episode → move cue → next-session cue, plus approved micro-drills, training paths, and proof checks.
- Qualitative route analysis and routesetter-lens outputs use evidence pins and explicit provenance, and pin only the confirmed recall history belonging to the analyzed RouteCard.

### Media and replaceable AI adapters

- Consent-gated source/derived route media with lineage, hashes, annotations, correction revisions, retention, deletion tombstones, and manifest export.
- Local media loading is path-contained and does not expose filesystem paths to model requests.
- Replaceable HTTP adapters for route reading and rehearsal suggestions with runtime credential injection, cancellation, limits, and typed failures.
- Media consent and model execution are separate actions; a suggested route read can be attached to a RouteCard, edited as a rehearsal, reopened, and copied into an Attempt-linked Actual draft without pretending it was observed.
- Every remote model result is forced to `suggested + modelAdapter`; user confirmation remains a separate action.

### Apple surfaces

- SwiftUI Watch capture/rest surface and iPhone experience/review/rehearsal surfaces.
- Explicit Health recording enablement and HealthKit/WatchConnectivity unavailable, denied, pending, and failure states.
- Manual capture, review, and physiology remain the default surface; route intelligence is a user-opened optional workspace.
- Dynamic Type, VoiceOver labels, and text-plus-symbol status treatment in the main experience flow.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Sources/LineWiseDomain/` | Pure domain reducers, models, replay, rehearsal, comparison, dataset, and learning logic |
| `Sources/LineWiseApplication/` | App coordinators, durable experience archive, rehearsal orchestration, and opt-in field evidence |
| `Sources/LineWiseAppleAdapters/` | HealthKit, WatchConnectivity, Apple runtime, media library, and SwiftUI surfaces |
| `Sources/LineWiseAIAdapters/` | Replaceable HTTP model adapters and media-aware request boundary |
| `Apps/` | iPhone and watchOS app entry points, entitlements, and property lists |
| `LineWise.xcodeproj/` | iPhone plus single-target watchOS companion project and shared schemes |
| `Specs/` | Executable public-interface behavior specifications |
| `Sources/LineWiseDemo/` | End-to-end command-line scenario |
| `prototypes/` | Throwaway interaction probes; not production state |
| `docs/` | Product contracts, gates, data plan, ADRs, and research context |

## Run Locally

Swift 6 is required.

```sh
swift build
swift run LineWiseDomainSpec
swift run LineWiseApplicationSpec
swift run LineWiseAppleAdaptersSpec
swift run LineWiseAIAdaptersSpec
swift run linewise-demo
```

Run the same checks with `-c release` before shipping a branch.

The current executable-spec baseline is 181 passing behaviors in both Debug and Release: Domain 85, Application 39, Apple adapters 42, and AI adapters 15. The command-line demo additionally exercises a two-visit manual-to-learning loop.

For the Apple apps, open `LineWise.xcodeproj` in a full Xcode installation, choose the shared `LineWise` or `LineWise-Watch` scheme, configure signing, and run on a paired iPhone/Apple Watch. HealthKit and WatchConnectivity behavior must be verified on real signed devices; Swift Package tests alone do not establish that evidence.

Remote AI is optional. The iPhone composition reads `LINEWISE_ROUTE_READ_ENDPOINT`, `LINEWISE_ROUTE_READ_PROVIDER_ID`, and `LINEWISE_ROUTE_READ_PROVIDER_VERSION` from build settings and resolves `LINEWISE_ROUTE_READ_BEARER_TOKEN` at runtime. No endpoint or credential is committed, and the manual and deterministic-local flows remain usable when configuration is absent or a request fails.

## Product and Evidence Boundary

Implemented code is not the same as validated product value. The repository proves deterministic behavior through executable specifications, while these claims still require external evidence:

- real-device HealthKit authorization, workout capture, and WatchConnectivity recovery;
- remote model quality on representative route photos and videos;
- fatigue or hand-muscle usefulness beyond subjective, non-diagnostic context;
- completion time, tap burden, review completion, cue reuse, and retention in real gym visits.

A passing `swift build` on macOS does not cover the Apple integration code. The SwiftUI capture and rehearsal surfaces in `ExperienceSurfaces.swift` and `RehearsalSurfaces.swift` are gated only on `canImport(SwiftUI)`, which is true on macOS, so they do build here. What macOS skips is the code behind `os(iOS)`, `os(watchOS)`, `canImport(HealthKit)`, `canImport(WatchConnectivity)`, and `canImport(PhotosUI)`: the Watch and iPhone capture surfaces, the HealthKit workout recorder, the WatchConnectivity transport, the photo import surface, and both app entry points.

Most of that is reachable without a full Xcode installation, because the Command Line Tools macOS SDK bundles Catalyst iOSSupport (including HealthKit, WatchConnectivity, and PhotosUI). This makes `os(iOS)` true and compiles those paths:

```sh
SDK=$(xcrun --sdk macosx --show-sdk-path)
swift build --triple x86_64-apple-ios18.0-macabi \
  -Xswiftc -F -Xswiftc "$SDK/System/iOSSupport/System/Library/Frameworks" \
  -Xswiftc -I -Xswiftc "$SDK/System/iOSSupport/usr/lib/swift"
```

Run this before claiming an Apple-surface change is verified; plain `swift build` will not catch an error in it. No triple available here makes `os(watchOS)` true, so `#if os(watchOS)` branches remain uncompiled, and running on signed devices is still the only way to close the platform gate. Where a spec covers a gated path, it covers the platform-independent logic that path delegates to, not the gated code itself.

Field evidence recording is disabled by default and requires explicit session consent. It stores controlled event categories and aggregate numerators/denominators, not route labels, health payloads, media, free text, or stable user identity.

## Product Contracts

Start with [CONTEXT.md](CONTEXT.md), then use these focused contracts:

- [Product requirements map](docs/linewise_product_requirements_map_v0.md)
- [P0 domain and lifecycle](docs/linewise_p0_domain_and_lifecycle_contract_v0.md)
- [End-to-end experience](docs/linewise_end_to_end_experience_contract_v0.md)
- [Physiology data contract](docs/linewise_physiology_data_contract_v0.md)
- [AI route rehearsal requirements](docs/linewise_ai_route_rehearsal_requirements_v0.md)
- [Routesetter lens and training path](docs/linewise_setter_lens_and_training_path_requirements_v0.md)
- [MVP gate](docs/climbing_bouldering_mvp_gate.md)
- [Data collection plan](docs/climbing_bouldering_data_collection_plan.md)

The core rule is simple: manual capture must remain trustworthy and recoverable; automation may accelerate interpretation, but it must expose provenance, uncertainty, correction, and a safe fallback.
