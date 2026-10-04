# Climb Context

**线感 / LineWise** is an iPhone app for indoor bouldering. You photograph a wall; the phone segments every hold; you tap one and the whole same-colour line lights up (the spotlight). You can then pose a stick figure scaled to your body on the line, play the moves back, and keep where you fell, why, and what to try next. The product contract is `docs/linewise_prd_v2_0.md`. Visuals and interaction follow `docs/linewise_ui_spec_v1.md`.

## Product Rules

- `抱石` in English is **Bouldering**. `LineWise` / `线感` is a working name, not a trademark or App Store conclusion.
- Scope: indoor bouldering, one person, iPhone, local-first, no account, no network needed. Not rope, outdoor, coaches, gyms, community, or video.
- Everything is organised by **line**. There is no day or gym-visit view; dates are a field and a history filter.
- The spotlight is the only visual motif. Every screen is that image plus one thing. Holds are drawn as their real contours; a hold that could not be segmented falls back to a circle.
- A line's identity is its lit holds on a wall photo. Colour is only how the user picks them. Lines without a photo are allowed but lose the spotlight and sequence.
- Only on-device models of 100 MB or less (currently SAM 2.1 Tiny, Core ML). No cloud inference, no uploads, no account.
- The system suggests, never scores: detected holds, colour groups, start/finish and move drafts are editable suggestions. The simulation respects body size and joint limits and may show a reach gap, but never says whether a route is climbable.
- Summaries quote only the user's own records on that line. Nothing is inferred about the user's ability from photos or body size. Weight is never asked.
- Operation budget is a hard requirement: build a colour line in ≤ 10 s, log a session in ≤ 4 taps, zero taps needed while climbing.
- Motion explains cause and effect: animations start from the user's finger, waiting is carried by the scan band, and reduce-motion is respected. No button panels to move limbs; no side-by-side split in portrait.
- Work follows PRD v2.0 Demo order A → D, each with a real gym visit. Apple Watch, imports, video analysis, scoring, cloud AI, search and iPad layouts are out of scope.

## Language

| Term | Code | Meaning |
| --- | --- | --- |
| 岩馆 | `Gym` | A name. No GPS. |
| 墙 | `Wall` | One wall photo (optional) in a gym, with optional area name and angle. Can carry many lines. |
| 线 | `Line` | A set of lit holds on a wall, with start, finish, grade text, felt grade, status and cycle. |
| 点 | `Hold` | One hold on the line: normalised position and radius, plus an optional contour polygon and hand/foot anchor. Numbered bottom to top as ①…; the shared language for fall point, sequence and notes. |
| 识别出的岩点 | `DetectedHold` | A hold found by whole-wall segmentation on a wall photo (polygon, centre, colour). Lines pick from these. |
| 颜色组 | `colorGroup` | The set of detected holds sharing the tapped hold's colour. Saturated colours expand automatically; white, black and grey do not. |
| 读线 | — | Photograph → scan → contours → tap one → colour group lights up → correct → start/finish. |
| 记录 / 记这一次 | `Session` | One day on one line: attempts, sent, fall point (or fall text), one reason, and 下次试什么. `source` is `in_gym`, `after` or `backfill`. |
| 尝试 | `AttemptRecord` | Optional per-attempt row inside a session. |
| 为什么掉 | `FailReason` | One of 顺序 / 脚 / 身体 / 时机 / 够不着 / 不敢 / 没力 / 不知道. |
| 下次试什么 | `Session.note` | The user's own sentence. Replaces the old terms MoveCue and beta. |
| 提醒 | `Line.reminderText` | Built from the most recent session with content: 掉哪 · 原因 · 下次试什么. Editable. |
| 验证 | `Session.check` | 有用 / 没变化 / 问题变了 / 没试, stored on the next session with `reminderSnapshot` (the reminder text it judged). Asked in 记这一次. |
| 顺序 / 快照 | `ClimbSequence` | Stick-figure steps dragged onto holds, kept as a plan and an actual; played back with smooth interpolation. |
| 体型 | `BodyProfile` | Height (asked once), arm span and optional leg ratio. Only used to draw and pose the figure. |
| 分享图 | ShareCard | A rendered 1080×1920 image. Exported, never uploaded. |
| 状态 | `LineStatus` | `projecting` / `sent` / `dropped` / `gone`; 再磕一轮 starts a new cycle. |

Old terms (GymVisit, RouteCard, FailureEpisode, MoveCue, NextSessionCue, ProofCheck, capture modes) map to these in PRD §16. Use the new terms in new docs, code and issues.

## Docs

- Active: `CONTEXT.md`, the PRD v2.0, the UI spec, `docs/linewise_status_2026-09-13.md` (implementation state, build and test commands), `docs/linewise_hold_segmentation_proposal_2026-09-13.md` (segmentation evidence), `docs/adr/`.
- Evidence: `docs/climbing_bouldering_research_report_v1.md` (July 2026 competitor and needs research; its product recommendations are superseded by the PRD).
- History: `docs/linewise_prd_v1_0.md` (v1.1; v2.0 still cites its memory-loop sections), `docs/climbing_bouldering_prd_v0_1.md`, `…_mvp_gate.md`, `…_platform_contract.md`, `…_data_collection_plan.md`, `docs/project_background.md`, `docs/product_initialization_v0.md`, and the older research reports. Read the platform contract again when Watch or HealthKit come back.

## Validation

- Product questions are answered in real gyms, not in the simulator. Each gym visit ends with the PRD §10.4 field note in `docs/field-notes/YYYY-MM-DD.md`.
- Simulator tests cover logic and UI flows. Camera, OCR, speech, share and performance still need a physical iPhone.
- Real wall photos stay out of the public repo (people appear in them).
