# Issue tracker: GitHub

Track implementation in the public `WILLOSCAR/linewise` repository. [Roadmap](../roadmap.md) links the active Demo A–D issues and gates. Each issue links the PRD requirements, explicit acceptance criteria, evidence and prerequisite Demo.

- Read: `gh issue view <number>`.
- List: `gh issue list --state open --json number,title,body,labels`.
- Create/update multiline descriptions with `--body-file`; preserve the existing body when adding context.
- Use [triage labels](triage-labels.md). A Demo can be ready for engineering while its human field validation remains outstanding. Later Demo issues stay blocked until the previous gate is settled.
- Close as completed only when the stated acceptance evidence exists. Superseded work closes as `not planned` with the reason and successor in its description; this is not evidence of delivery.
- Posting comments or messaging others requires explicit user authorization.

Old issues #1–11 belong to the archived GymVisit / Watch route. Do not use their former readiness labels to choose current work.
