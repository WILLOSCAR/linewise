# AGENTS.md

## Agent Skills

### Issue Tracker

This project is GitHub-backed as the public `WILLOSCAR/linewise` repo. Product and implementation work should be tracked in GitHub Issues once the PRD and validation gates are settled. See `docs/agents/issue-tracker.md`.

### Triage Labels

Use the five Matt workflow states as local issue status values: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain Docs

This is a single-context project. Read `CONTEXT.md` first, then ADRs in `docs/adr/` when product direction, platform claims, data model, or release gates matter. See `docs/agents/domain.md`.

## Development Workflow

- Stay in requirements discussion until the P0 contract is settled.
- Start fuzzy product work with `ask-matt` style routing and use `grill-with-docs` style questioning against the active docs before writing a PRD.
- For multi-session work, use `to-prd` -> `to-issues` -> one fresh `implement` run per issue.
- Use `prototype` only to answer a specific open question, such as the RouteCard state model or a Watch/iPhone UI flow. Mark prototype code as throwaway.
- For Apple platform details, verify against official Apple docs before implementation.
- For risky logic, use `tdd` before implementation and `review` before merging.
- Do not mix this climb project with badminton or RallyMate implementation code.
