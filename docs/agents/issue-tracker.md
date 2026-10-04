# Issue Tracker: GitHub

Specs, decision maps, and tickets live in GitHub Issues in the public `WILLOSCAR/linewise` repository. Use `gh` from this clone for all operations.

## Operations

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,assignees`
- Comment: `gh issue comment <number> --body "..."`
- Label: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- Claim: `gh issue edit <number> --add-assignee @me`
- Resolve: comment with the result, then `gh issue close <number>`.

Create implementation tickets only after the P0 requirements, validation gates, and feature spec are settled. Prefer one independently verifiable tracer bullet per ticket and represent blocking edges with GitHub's native issue dependencies. Link product-sensitive work to `CONTEXT.md`, the relevant PRD, or an ADR. Tickets created by `to-tickets` are already agent-ready and do not go through `triage`.

## Wayfinding Operations

- Map: one issue labelled `wayfinder:map`, holding Notes, Decisions-so-far, and Fog.
- Child: a linked sub-issue labelled `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`.
- If sub-issues or dependencies are unavailable, put `Part of #<map>` and `Blocked by: #<n>, #<n>` at the top of the child body.
- Frontier: the first open, unblocked, unassigned child in map order.
- Resolve: post the answer, close the child, and append a gist plus link to the map's Decisions-so-far.

Use the triage labels documented in `docs/agents/triage-labels.md`. External PRs are not currently treated as a request surface.
