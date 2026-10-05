# 线感 LineWise

Date: 2026-10-05
Status: PRD v2.0 targets on-device line reading, simulation and playback. The current iOS app implements the v1.x core flow; 169 unit/integration tests and 3 native UI tests passed again on October 5. Segmentation and upgraded interaction exist as local Mac/web prototypes and are not integrated into the app. Physical iPhone and real-gym validation remain outstanding. Next: Demo A (hold contours with SAM 2.1 Tiny). See the [current progress audit](docs/linewise_status_2026-10-05.md).

`抱石` in English is **Bouldering**. LineWise focuses on indoor bouldering.

## What It Is

> 拍一面墙，扫一下，整面墙的岩点被抠出来；点一个，同色的整条线亮起来；按自己的身材把动作摆一遍、播一遍；爬完记住掉在哪、下次试什么。

The v2.0 design runs on the phone with one lightweight model (SAM 2.1 Tiny, about 80 MB, to be downloaded on first use). Model download and inference are not yet in the app. Competitors already ship stick-figure beta, 3D walls and video AI; LineWise aims to compete on seconds-fast editable line reading on device, simulation scaled to your own body and linked to your own falls, and the feel of the interaction.

## Docs

| File | Role |
| --- | --- |
| `CONTEXT.md` | Domain language and product rules; read first |
| `docs/linewise_prd_v2_0.md` | Product contract (v2.0) |
| `docs/linewise_prd_v1_0.md` | v1.1; still the detail spec for the memory loop that v2.0 §5.4 cites |
| `docs/linewise_ui_spec_v1.md` | Visual and interaction spec |
| `docs/linewise_status_2026-10-05.md` | Current implementation/prototype audit, tests, branches, known gaps and next steps |
| `docs/linewise_status_2026-09-13.md` | Historical implementation log with September updates |
| `docs/linewise_takeover_2026-09-13.md` | September 13 takeover verification record |
| `docs/linewise_hold_segmentation_proposal_2026-09-13.md` | Segmentation prototype evidence behind v2.0 |
| `docs/adr/` | Durable decisions; ADR 4 (line-first model) and ADR 5 (on-device reading and simulation) are current |
| `docs/climbing_bouldering_research_report_v1.md` | July 2026 competitor and needs research (evidence) |

Everything else in `docs/` is history: the v0.1 PRD with its gate, platform and data-collection docs, the project background, and the earlier research reports. It does not override the documents above.

## Layout

| Directory | Purpose |
| --- | --- |
| `app/` | iOS app (XcodeGen `project.yml`, SwiftUI, SwiftData, no third-party dependencies) and its tests |
| `docs/` | Product, decisions, research |
| `docs/field-notes/` | One note per gym visit (PRD §10.4); created with the first visit |

## Build

```sh
cd app && xcodegen generate
xcodebuild -project LineWise.xcodeproj -scheme LineWise \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
```

Demo data and deep-link launch arguments are listed in the status doc.

## Boundaries

- Do not mix this project with the badminton `ShuttleCoachSpike` or RallyMate code.
- Real wall photos never go into this public repo.
