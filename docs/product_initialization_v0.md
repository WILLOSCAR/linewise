# LineWise Product Initialization v0

Date: 2026-06-30  
Status: Requirements settlement, market research, naming, and data-collection design. No implementation PRD yet.

## 1. Why This Doc Exists

This document initializes the climbing product lane using the local Matt-style workflow already present in this directory. It is meant to give future agents and collaborators a clear starting point before PRD writing, issue splitting, or implementation.

Current workflow contract:

- Read `AGENTS.md` first for process rules.
- Read `CONTEXT.md` for domain language and product boundaries.
- Use `docs/adr/` for durable product and architecture decisions.
- Track implementation issues in GitHub Issues only after a P0 PRD and validation gates exist.
- Do not mix this climbing product with badminton, RallyMate, or other Watch App experiments.

## 2. Working Product Name

Recommended working names:

> **LineWise**  
> **线感**

Why this naming pair works:

- `LineWise` carries the core idea: route-reading wisdom, line interpretation, and movement judgment.
- `线感` is short, memorable, and close to the indoor bouldering mindset: read the line, feel the movement, solve the route.
- The pair avoids overly broad "climbing companion" language and feels more specific to gym bouldering.
- It does not rely on circle-only words such as `beta`.
- It leaves room for Watch capture, AI route reading, stick-figure movement explanation, routesetter analysis, training, and partner workflows.

Rejected prior direction:

> A generic "climbing companion" name.

Reason: it is understandable, but too broad and less differentiated as a product brand.

This is only a working brand decision. It should not be treated as trademark, domain, App Store, or social account availability.

### Naming Shortlist

| Name | Strength | Concern | Verdict |
| --- | --- | --- | --- |
| LineWise / 线感 | Strongest fit for reading lines, movement feel, and route interpretation | Needs formal availability check | Recommended |
| RouteMind / 岩解 | Strong analytical feel | More tool-like, less elegant | Backup |
| HoldWise / 岩眼 | Good for AI visual hold analysis | Too focused on visual detection | Feature/module candidate |
| LineCue / 线索 | Clever, memorable, hint-oriented | Slightly lighter and less premium | Backup |
| ProblemLab / 石题 | Ties to boulder problems and solving | More niche and lab-like | Research/training module candidate |
| WallWise / 岩识 | Good for reading the wall | Broader and less route-specific | Backup |

## 3. Product Positioning

LineWise should not be framed as a generic sports tracker. It should become:

> A bouldering line-reading and training companion that remembers your gym visits, helps you read routes, explains movement, connects training to failures, and gradually becomes your personal bouldering memory and learning system.

The product should start with the narrowest reliable loop:

```text
Route/project memory -> Watch attempt/rest capture -> iPhone review -> next-session recall
```

Then it can expand into:

```text
Route photo -> AI route reading -> stick-figure movement cue -> setter-lens explanation -> training path -> partner/share loop
```

## 4. Product Pillars

### 4.1 Gym Visit Memory

This is still P0.

The user often remembers a route visually but forgets details after leaving the gym: which color, which wall, what grade, what move failed, who gave the movement cue, whether the rest interval was too short, and what to try next time.

Core objects:

- `GymVisit`
- `RouteCard`
- `Project`
- `Attempt`
- `RestInterval`
- `MoveCue`
- `NextSessionCue`

Why it matters:

- It creates immediate value before AI works.
- It produces the user's first `PersonalClimbingDataset`.
- It gives future route-reading and training features ground truth.

### 4.2 攀岩搭子

This pillar has two meanings and must be separated during design:

| Layer | Meaning | When to build |
| --- | --- | --- |
| AI 搭子 | Helps remember routes, summarize movement cues, suggest next practice, ask reflective questions | Early, after RouteCard loop exists |
| 真人搭子 | Helps find partners, share projects, coordinate gym visits, compare movement ideas | Later, after retention and privacy model are clear |

Initial direction:

- Start with AI companion behavior inside review and next-session recall.
- Do not start from open social matching; it brings moderation, privacy, trust, and cold-start problems.
- Human buddy flows can begin as private sharing with an existing friend, not public discovery.

### 4.3 自动读线

The user takes a photo of a route. The system analyzes it and generates a route-reading draft.

Possible outputs:

- detect or let user tap holds;
- group holds by color;
- infer start/top holds when visible;
- ask the user to confirm route identity;
- propose likely hand/foot sequence;
- identify likely key difficulty candidates;
- explain movement style;
- generate movement alternatives for different body types;
- connect the route to training drills.

Important product language:

- Use `suggested route read`, not `detected solution`.
- Ask for user correction: start hold, finish hold, color, wall angle, grade, missing holds.
- Treat every AI output as editable and explainable.

### 4.4 趣味交互: 火柴人动作提示

The stick-figure idea is valuable because route solving is spatial and embodied. A text-only answer often fails to explain body position.

Possible interaction:

- user uploads or captures a route photo;
- app overlays key holds;
- user confirms start/top/route color;
- app places a simple stick figure or motion skeleton;
- user drags hands/feet to sketch the sequence;
- app generates a short movement animation or step card;
- app stores the sequence as a `MoveCue`.

Why it should be playful:

- It lowers the intimidation barrier for beginners.
- It makes movement cues shareable.
- It turns route reading into a habit, not a serious analysis chore.

Risk:

- If the overlay is inaccurate, users will lose trust quickly.
- MVP should support manual placement before promising full automatic pose or movement generation.

### 4.5 定线解析

Setter-lens analysis is a deeper differentiator. Instead of only asking "how do I climb this?", the product can ask "what is this route trying to teach?"

Possible dimensions:

- wall angle: slab, vertical, overhang, cave;
- movement family: balance, compression, tension, coordination, dynamic, mantle, toe hook, heel hook, flag, drop knee;
- constraint: bad feet, far move, volume use, body tension, sequencing trap;
- key difficulty: where users likely fail;
- intended skill: what the route rewards;
- alternative movement ideas: tall user, short user, static, dynamic.

Product value:

- Makes the app feel like a learning companion, not just a tracker.
- Helps users understand why they failed.
- Creates better training recommendations.

Boundary:

- Unless the actual setter contributes, `SetterLens` is an inferred analysis, not the official route setter intent.

### 4.6 教学与训练

Teaching and training should connect to real failures rather than becoming a generic video library.

Example loop:

```text
User fails a slab route due to foot trust
-> RouteCard records failure reason
-> SetterLens identifies balance/weight-shift theme
-> TrainingPath suggests 2 videos and 2 drills
-> next gym visit shows a tiny reminder
```

Good training content should be:

- short;
- movement-specific;
- tied to a route or project;
- usable before the next gym visit;
- measurable through future attempts.

Avoid:

- dumping a large disconnected course library;
- turning the Watch into a teaching screen;
- promising medical or injury-prevention claims.

## 5. Personal Data Collection Strategy

The most useful near-term move is to build a thin app or workflow that helps the user collect structured personal bouldering data.

### What To Collect At The Gym

| Data | Capture Method | Why It Matters |
| --- | --- | --- |
| Route photo | iPhone camera | Foundation for route reading and stick-figure movement cues |
| Wall area | quick manual tag | Helps find the route later |
| Hold color | manual tag or AI suggestion | Route identity without full gym database |
| Official grade | manual tag | Baseline difficulty |
| Subjective grade | quick rating | Personal progression and mismatch detection |
| Start/top holds | tap on photo | Training data for future AI |
| Attempt result | Watch Try/Send/Fail/Flash | Core bouldering event |
| Failure point | tap hold or select reason | Turns failure into training signal |
| MoveCue | short text/voice/photo annotation | Memory and next-session recall |
| Rest interval | Watch timer | Pacing and intensity context |
| Heart rate | HealthKit workout | Supporting intensity signal |
| Motion timeline | Watch/Core Motion | Candidate attempt/rest segmentation |
| Optional video | iPhone, only with consent | Future movement analysis |

### Minimum Viable Dataset

Before building advanced AI, collect at least:

- 50-100 RouteCards from real gym visits;
- 200-500 Attempts with result labels;
- 50+ routes with start/top/hold annotations;
- 20+ routes with written movement cues;
- several sessions with Watch timeline and user-corrected attempt/rest boundaries.

This dataset can answer:

- whether users can tolerate the capture flow;
- whether route photo + manual tags are enough for recall;
- whether AI route reading is feasible from normal gym photos;
- whether Watch attempt/rest signals are useful enough to assist, not replace, user input.

## 6. Recommended Scope Ladder

| Phase | Product Goal | Main Features | Key Risk |
| --- | --- | --- | --- |
| P0 | Prove gym visit memory | RouteCard, Watch attempt/rest, Send/Fail, iPhone review, next-session cues | Too much manual input |
| P0.5 | Build personal dataset | Route photos, hold taps, failure reasons, movement cues, corrected timelines | Data quality |
| P1 | AI-assisted route reading | photo-to-route draft, start/top suggestions, movement hypotheses | AI trust |
| P1.5 | Stick-figure movement cue | manual/assisted skeleton overlay, step cards, movement replay | Visual accuracy |
| P2 | Training path | failure-to-drill mapping, short videos, movement curriculum | Content quality |
| P2.5 | SetterLens | inferred routesetter intent and movement analysis | Overclaiming intent |
| P3 | Climbing buddy | private sharing, partner recall, social/project collaboration | Privacy and moderation |

## 7. Immediate Decisions

Settled for now:

- Product working name: **LineWise**.
- Chinese working name: **线感**.
- P0 remains Gym Visit Memory, not full AI route reading.
- AI outputs are suggestions and must be editable.
- The first real asset is a clean personal climbing dataset.
- Watch is for low-interruption capture, not complex route editing.
- iPhone is for photo, route memory, movement cues, review, teaching, and AI explanation.

Open questions before PRD:

- Should the first user-facing prototype be Watch-first or iPhone-first?
- How much route photo annotation can the user tolerate after a climb?
- Is AI route reading a P1 feature or only a data-collection experiment first?
- Should `攀岩搭子` mean AI assistant first, human partner first, or private friend-sharing first?
- What kind of stick-figure movement cue is useful: static pose cards, animated sequence, or manual sketching?
- Which training taxonomy should be used: movement family, wall angle, failure reason, or grade progression?

## 8. Next Recommended Work

1. Write `docs/climbing_bouldering_prd_v0_1.md` around P0 and P0.5 only.
2. Write `docs/climbing_bouldering_data_collection_plan.md` for the user's next 3-5 gym visits.
3. Define the first RouteCard schema and photo annotation model.
4. Prototype the iPhone route photo capture + manual hold tapping flow.
5. Prototype the Watch attempt/rest capture flow.
6. Only then evaluate AI route reading and stick-figure movement cues.

## 9. Name Usage Guidance

Use:

- **LineWise** for English product discussions and GitHub naming.
- **线感** for Chinese product discussions.
- `RouteRead` for AI route-reading outputs.
- `StickFigureCue` for the playful visual movement module.
- `SetterLens` for routesetter-style analysis.
- `TrainingPath` for teaching/training linkage.

Avoid:

- calling the P0 product an AI coach;
- calling AI outputs detection or diagnosis;
- treating human partner matching as part of the first MVP;
- turning the project into a generic fitness app or a generic video course.
