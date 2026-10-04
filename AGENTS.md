# AGENTS.md

## Agent skills

### Issue tracker

This project is GitHub-backed as the public `WILLOSCAR/linewise` repo. Track product and implementation work in GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five Matt workflow labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context project. Read `CONTEXT.md` first, then the PRD (`docs/linewise_prd_v2_0.md`) and ADRs in `docs/adr/` when product direction, data model, or release gates matter. See `docs/agents/domain.md`.

## Development workflow

- The PRD is the contract and the app exists in `app/`. Build in PRD v2.0 Demo order (A → D); a demo is done only when its exit criteria and a real gym visit are met.
- Change product behaviour by editing the PRD section and adding a §17 row in the same change.
- In this repo, start bounded fuzzy work with `grill-with-docs` against the active docs; use `ask-matt` only when the route is unclear.
- For multi-session work, keep `grill-with-docs -> to-spec -> to-tickets` in one context, then clear context and start one fresh `implement` run per frontier ticket.
- Use `wayfinder` only when the product effort is too large and foggy to settle in one session; when its decision map is clear, return to `to-spec`.
- Use `handoff -> prototype -> handoff` only to answer a specific runnable question, such as the RouteCard state model or a Watch/iPhone UI flow. Write the prototype as throwaway code, retain it as evidence, and carry the decision back.
- For Apple platform details, verify against official Apple docs before implementation.
- For a hard bug use `diagnosing-bugs`. `implement` drives `tdd`, project verification, and `code-review` before commit.
- Use `triage` only for raw incoming bugs and requests; tickets created by `to-tickets` are already agent-ready.
- Do not mix this climb project with badminton or RallyMate implementation code.
