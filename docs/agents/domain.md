# Domain Docs

Climb is a single-context project.

- Read `CONTEXT.md` before product, architecture, bug, or test work.
- Use `docs/adr/` for durable decisions that change product scope, sensor claims, data model, Apple platform contracts, or release gates.
- Treat the latest PRD (`docs/linewise_prd_v2_0.md`), `CONTEXT.md`, and ADRs as the product-requirements sources. `docs/linewise_ui_spec_v1.md` governs visuals and interaction.
- Once `to-spec` publishes a feature spec, that spec is the implementation contract for the feature and must link back to those sources.
- Historical exploration docs in `docs/` are useful context, but they do not override `CONTEXT.md`, active requirements, a feature spec, or ADRs.
