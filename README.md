# 线感 LineWise

Date: 2026-10-03
Status: Direction reset to PRD v2.0 (on-device line reading, simulation, playback). The iOS app implements the v1.x feature set and is green in the simulator; it has not run on a physical iPhone or in a real gym. Next: Demo A (hold contours with SAM 2.1 Tiny).

`抱石` in English is **Bouldering**. The folder is called `climb` because the wider lane is climbing; the product is indoor bouldering only.

## What It Is

> 拍一面墙，扫一下，整面墙的岩点被抠出来；点一个，同色的整条线亮起来；按自己的身材把动作摆一遍、播一遍；爬完记住掉在哪、下次试什么。

Everything runs on the phone with one lightweight model (SAM 2.1 Tiny, 80 MB, downloaded on first use). Competitors already ship stick-figure beta, 3D walls and video AI; LineWise competes on seconds-fast editable line reading on device, simulation scaled to your own body and linked to your own falls, and the feel of the interaction.

## Docs

| File | Role |
| --- | --- |
| `CONTEXT.md` | Domain language and product rules; read first |
| `docs/linewise_prd_v2_0.md` | Product contract (v2.0) |
| `docs/linewise_prd_v1_0.md` | v1.1; still the detail spec for the memory loop that v2.0 §5.4 cites |
| `docs/linewise_ui_spec_v1.md` | Visual and interaction spec |
| `docs/linewise_status_2026-09-13.md` | Implementation state, build and test commands, known gaps |
| `docs/linewise_takeover_2026-09-13.md` | Last verification record |
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
