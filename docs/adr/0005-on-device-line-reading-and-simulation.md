# ADR 5: On-Device Line Reading And Simulation

Date: 2026-10-03

## Decision

LineWise leads with line reading and movement simulation, and keeps the memory loop (log, reminder, check) as where they land. The line-first spotlight model from ADR 4 stays.

- Line reading runs on the phone with one lightweight model: Apple's Core ML conversion of SAM 2.1 Tiny (79.7 MB, Apache 2.0, iOS 17+). It is downloaded the first time the user reads a line. Models over 100 MB, cloud inference and accounts are out of scope.
- The primary flow segments the whole wall first, then lets the user pick a colour by tapping one hold. Single-tap segmentation is the fallback, and the manual circle is the last resort.
- Hold shapes are stored as normalised polygons on the wall. A line's holds reference them. Lines without a polygon keep drawing circles.
- Simulation uses the user's height and arm span (leg ratio optional). It may show reach limits but never scores or judges whether a route is climbable. Weight is not collected.
- The September feature freeze is lifted. Field validation runs with every demo instead of gating all work.

## Context

A throwaway prototype on two real wall photos (24 known holds) compared five methods:

- SAM 2.1 Tiny with a point prompt and an area cap fitted 21 of 24 holds. Its shape stayed most stable when the tap was off-centre (IoU 0.76, against 0.60 for circles).
- Colour flood fill reached 16/24 and was the least stable.
- Apple Vision foreground masks reached 16/24 and merged neighbouring holds.
- SAM 2.1 Small matched Tiny's count but lit a red volume, and it is larger.

Tap-one-find-same-colour worked for saturated colours. It failed for white: signs, volume faces and clothing were picked up, and shaded holds were missed.

SAM 3 can segment every "yellow climbing hold" from a text prompt. But it has about 848M parameters (about 3.4 GB). Apple has no official Core ML conversion, and Apple's on-device demo needs iOS 27 and a 623 MB asset. Lightweight SAM 3 distillations have no Core ML export yet. The product owner chose the lightest model that runs today.

Competitors already ship stick-figure beta, 3D walls and video AI. LineWise differentiates through:

- seconds-fast, on-device, editable line reading;
- simulation scaled to the user's own body;
- links to the user's own fall records;
- the feel of the interaction.

## Consequences

- PRD v2.0 replaces v1.1 and adds FR-70–91, delivered as Demo A (contours), B (line reading), C (simulation and playback) and D (move drafts).
- The data model gains wall-level detected holds, hold polygons and anchors, a line colour group and a body profile. SwiftData needs a versioned schema before this migration.
- White, black and grey colour groups do not expand automatically.
- If whole-wall segmentation misses the on-device time budget, the product degrades to single-tap segmentation rather than adopting a larger model.
- ADR 4's exclusion of AI route reading is narrowed. On-device segmentation and colour grouping are in. Cloud AI, video analysis and scoring stay out.
