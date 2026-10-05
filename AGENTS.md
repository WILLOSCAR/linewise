# LineWise working guide

## Read first

- [CONTEXT.md](CONTEXT.md): domain vocabulary.
- [PRD v2.0](docs/linewise_prd_v2_0.md): product contract; its §5.4 retains the specified v1.1 memory-loop sections.
- [Roadmap](docs/roadmap.md): Demo A → D order and active GitHub issues.
- [Current audit](docs/linewise_status_2026-10-05.md): implementation and validation evidence. [Docs index](docs/README.md) routes all other reading.

## Work and verification

- Implement in `app/`. Follow the PRD and [UI spec](docs/linewise_ui_spec_v1.md). Change product behaviour only with the corresponding PRD edit and a §15 change-log row.
- Keep each change bounded. Verify it with the relevant build, logic tests or UI flow; commands are in [README](README.md). Use `diagnosing-bugs` for difficult failures and `code-review` for substantive changes when those skills are available.
- A Demo is complete only after its exit criteria and real-gym evidence are met. Record visits using v1.1 §10.4 in `docs/field-notes/YYYY-MM-DD.md`; simulator success does not count as field validation.
- Verify Apple platform claims against official Apple documentation before implementation.
- Track work using [GitHub issue conventions](docs/agents/issue-tracker.md); do not revive archived requirements without a current PRD decision.

## Boundaries

- This is the public `WILLOSCAR/linewise` repository. Keep real wall photos, personal fixtures, model weights and generated media in ignored local directories. `experiments/` contains reusable source and aggregate evidence only.
- Preserve user records. Models suggest editable holds or drafts; they do not score ability or route feasibility.
- Work on the current development branch. Merging to main, publishing and deleting historical branches require explicit scope.
- Do not mix LineWise with badminton, ShuttleCoachSpike or RallyMate code.
