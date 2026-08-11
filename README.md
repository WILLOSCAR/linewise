# LineWise Climb Watch App

Date: 2026-08-11
Status: P0 semantic contract settled; pure Swift domain foundation and parallel Intelligence Nursery prototypes started

## Naming

`抱石` in English is **Bouldering**.

This directory is named `climb` because the broader product lane is climbing. The current working product name is **LineWise**. The Chinese working name is **线感**. The current MVP opportunity is specifically indoor bouldering.

`LineWise` means the product is not only a workout recorder. It should eventually become a bouldering companion for route memory, line reading, movement explanation, training, and partner workflows.

## Current Product Thesis

The current external product thesis is:

> LineWise is a bouldering companion: use Apple Watch to capture low-interruption attempt/rest anchors, use iPhone to remember routes and movement cues, and eventually help the user read lines, understand movement, train deliberately, and climb with better partners.

The internal model remains useful, but should not replace the user-facing category:

> Rhythm Capture + Recall Retrieval + Proof/Trust: Watch owns low-interruption rhythm anchors; iPhone owns project memory, correction, and next-session recall.

The broader product vision now has five pillars:

1. 攀岩搭子: first as an AI/private companion, later maybe human partner workflows.
2. 自动读线: photo-based route reading and editable movement suggestions.
3. 趣味交互: stick-figure movement overlays and playful movement explanation.
4. 定线解析: routesetter-lens interpretation of movement, key difficulty, wall style, and training intent.
5. 教学与训练: route-failure-driven videos, drills, and functional training paths.

P0 remains deliberately narrower as a production contract, while Intelligence Nursery probes may run in parallel:

> Prove the manual-first `capture -> quick review -> next-session recall` loop as the reliable product core. Promote AI route reading, automated photo analysis, video, coach workflows, or training-platform expansion only through their own evidence gates.

## Active Docs

| File | Role |
| --- | --- |
| `CONTEXT.md` | Concise single-context product and domain source of truth for future agents |
| `docs/linewise_product_requirements_map_v0.md` | Cross-module ownership, dependencies, degradation, gates, and contract-resolution ledger |
| `docs/linewise_p0_domain_and_lifecycle_contract_v0.md` | Normative Attempt, GymVisit, RouteCard, Project, review, and cross-device event semantics |
| `docs/linewise_end_to_end_experience_contract_v0.md` | Normal and degraded iPhone/Watch journeys, recovery, Inbox, accessibility, and localization |
| `docs/linewise_physiology_data_contract_v0.md` | HealthKit, subjective fatigue/pump, load context, retention, deletion, provenance, and Research Mode boundaries |
| `docs/linewise_ai_route_rehearsal_requirements_v0.md` | Intelligence Nursery requirements for AI route reading, personalized body rehearsal, continuous animation, and single-step debugging |
| `docs/linewise_ai_route_rehearsal_evaluation_protocol_v0.md` | X0-X5 tasks, baselines, metrics, failure taxonomy, promotion rules, and claim ceilings |
| `docs/linewise_setter_lens_and_training_path_requirements_v0.md` | Inferred/authored route interpretation, MicroDrill, ProofCheck, and learning-loop requirements |
| `docs/project_background.md` | Project background, market gap, strategy, and product principles |
| `docs/climbing_bouldering_prd_v0_1.md` | Active P0/P0.5 requirements contract |
| `docs/climbing_bouldering_mvp_gate.md` | Go/No-Go gates and field validation metrics |
| `docs/climbing_bouldering_data_collection_plan.md` | Real-gym data collection and annotation protocol |
| `docs/climbing_bouldering_platform_contract.md` | Apple Watch, iPhone, HealthKit, privacy, and claim boundaries |
| `docs/climbing_bouldering_implementation_plan.md` | Module interfaces, delivery phases, issue-ready backlog, tests, and current toolchain boundary |
| `docs/product_initialization_v0.md` | Historical initialization snapshot; later focused contracts take precedence |
| `docs/adr/0004-attempt-anchor-and-project-cycles.md` | Durable one-tap Attempt, honest unresolved outcome, RouteCard axes, and repeatable Project-cycle decision |
| `docs/adr/0002-linewise-expanded-product-vision.md` | Durable decision: use LineWise / 线感 as the broader working frame while preserving Gym Visit Memory as P0 |
| `docs/adr/0003-canonical-p0-domain-model-and-terms.md` | Durable decision: canonical P0 entities, event vocabulary, and term aliases |
| `docs/adr/0001-gym-visit-memory-system.md` | Durable product decision: start from route/project-centered gym visit memory, not generic session logging |

## Historical Research

These files are source material. They do not override `CONTEXT.md`, the active PRD, or ADRs.

| File | Role |
| --- | --- |
| `docs/bouldering_field_research_v2.md` | Field-observation-oriented V2 research; reframed the product from training recorder to gym visit memory system |
| `docs/climbing_bouldering_research_report_v1.md` | Primary expanded five-PM research and product-direction report |
| `docs/bouldering_industry_history_business_report.md` | Bouldering industry history, Beijing/Shanghai brand landscape, business model, coaching mode, and trend report |
| `docs/bouldering_market_mvp_report.md` | Original broad market research and MVP opportunity report, kept as source material |

## Agent Workflow

This project uses a lightweight local adaptation of the Matt workflow:

- read `AGENTS.md` and `CONTEXT.md` before product or implementation work;
- use `docs/adr/` for decisions that should survive across sessions;
- track implementation issues in GitHub Issues after the PRD and validation gates are settled;
- cut production issues from the focused contracts and implementation slices only after their acceptance behavior is explicit;
- keep real-device Watch/HealthKit claims pending until a full Xcode SDK and paired-device evidence exist;
- run bounded Intelligence Nursery prototypes independently from P0 release dependencies.

## Executable Domain Foundation

The current environment can compile the platform-independent Swift domain module but does not expose a watchOS SDK. Run the public-interface behavior specifications with:

```sh
swift run LineWiseDomainSpec
```

The first implementation covers one-tap Attempt capture, honest unresolved outcomes, Mark Send without a second Attempt, exact-target Undo, idempotency, out-of-order dependencies, late-event review reopening, RouteCard successors, and repeatable Project cycles. Watch UI, persistence adapters, HealthKit, and WatchConnectivity remain later verified slices.

## Directory Layout

| Directory | Purpose |
| --- | --- |
| `docs/` | Product research, PRD, data collection plan, MVP gates |
| `docs/agents/` | Local Matt-style workflow configuration |
| `docs/adr/` | Durable product and architecture decisions |
| `Sources/LineWiseDomain/` | Platform-independent P0 domain interface and implementation |
| `Specs/LineWiseDomainSpec/` | Executable behavior specifications through the public interface |
| `prototypes/` | Explicitly throwaway, directly runnable product probes |
| `app/` | Future climbing Watch/iPhone implementation |
| `ui/` | Future climbing-specific Watch and iPhone UI design |
| `tests/` | Future simulator, real-device, adapter, field-test, and data-quality validation |

## Project Boundary

Climbing owns:

- bouldering Attempt/rest/result/Project semantics;
- climbing market and competitor research;
- climbing-specific Watch/iPhone UX;
- climbing-specific HealthKit/Core Motion data collection plan;
- future climbing PRD, validation gate, and implementation plan.

Climbing does not own:

- existing badminton `ShuttleCoachSpike` code;
- badminton overhead-drill algorithm;
- badminton release gate or coach-share promise.

## Shared Learnings From Badminton

Reusable:

- local-first recording before sync;
- uncertainty routes to review;
- motion data needs timestamp discipline and replay fixtures;
- HealthKit success must be explicit, not assumed;
- Watch UI must stay low-interruption.

Not reusable directly:

- rep counting;
- set boundary detection;
- high-clear drill copy;
- badminton validation metrics.

## Next Execution Steps

1. Review and commit the contract-alignment batch on `work/full-product-foundation`.
2. Add persistence and replay contract tests around the domain interface.
3. Install/select full Xcode before creating or claiming verification for Watch, HealthKit, or WatchConnectivity targets.
4. Run the manual P0 visit script and the X0 RouteRehearsal task set with real users.
5. Cut issue-backed vertical slices only after the branch is accepted.
