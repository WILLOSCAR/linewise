# LineWise Project Background

Date: 2026-07-13
Status: Historical background (July 2026). The product shape it describes (multi-mode capture, optional Watch, RouteCard chain) was replaced by PRD v1.1 and ADR 4; the market and competitor framing is still useful.

## 1. One-Line Summary

**LineWise / 线感** is a private attempt-memory and proof system for indoor bouldering. It helps a climber preserve the route, failure point, movement cue, and next experiment that matter after an attempt. iPhone owns route memory and review; Apple Watch is an optional low-interruption capture accelerator when the user is willing and the gym permits it.

## 2. Why This Project Exists

Indoor bouldering is not well served by generic workout products. Apple Watch, Apple Fitness, Strava, Garmin, and COROS can record a climbing workout, but the key questions after a bouldering session are not only "how long did I train?" or "what was my heart rate?"

The real questions are:

- Which route did I try?
- What color, wall area, grade, and style was it?
- How many times did I try it?
- Did I send it, fail it, flash it, or leave it as a project?
- Where did I fail?
- What did a friend, coach, or my own observation tell me to try next?
- Was the route reset or gone the next time I came back?
- What does this repeated failure say about my movement skill?

LineWise starts from those questions.

The product is not trying to become a route guidebook, a public video/Beta community, a gym operating system, a generic training course library, or an automatic AI coach. The first useful product is a private memory and next-attempt validation system for real gym visits.

The July 2026 research refresh materially changed the competitive framing. Chinese products already cover video auto-organization, photo-to-route search, frame-by-frame comparison, public solutions, gym pages, subscriptions, Apple Watch/FIT tracking, pose and center-of-mass analysis, 3D wall reconstruction, stick-figure Beta, training plans, route discovery, check-ins, and partner planning. Therefore, recording, Watch, video, pose, stick figures, community, and generic AI route reading are not sufficient differentiation.

## 3. Current Product Thesis

LineWise should prove this loop first:

```text
RouteCard -> meaningful Attempt -> FailureEpisode -> MoveCue -> NextSessionCue -> ProofCheck
```

The long-term product can grow into:

```text
PersonalClimbingDataset -> RouteRead -> StickFigureCue -> SetterLens -> TrainingPath -> private sharing
```

Capture may come from Watch, iPhone quick capture, or review-only entry. The important ordering is intentional: AI route reading should come after a reliable route memory, correction, and proof loop, not before it.

Manual history and future Health/FIT/Photos imports may also create or enrich the same objects. The source, real date/timezone, user review state, and corrections must survive; external segments are never silently converted into confirmed attempts.

## 4. Target Context

LineWise is currently scoped to:

- indoor bouldering;
- commercial climbing gyms;
- iPhone users, with an Apple Watch companion for eligible users;
- climbers who repeat projects and care about remembering routes;
- personal use first, then private sharing, then possible coach/gym collaboration.

LineWise is not currently scoped to:

- outdoor climbing guidebooks;
- rope climbing, lead, top-rope, trad, or multi-pitch;
- official gym route databases;
- public rankings or social feeds;
- medical, safety, or recovery advice;
- automatic send/fail judgment;
- real-time AI coaching on the wall.

## 5. What The Market Already Has

The market roughly splits into four product families:

| Family | Examples | Strength | Gap For LineWise |
| --- | --- | --- | --- |
| Guidebook / community graph | KAYA, Mountain Project, 27 Crags, Vertical-Life | Outdoor routes, topos, beta videos, sends, social graph | Weak private failure-to-next-attempt proof loop |
| Chinese video / route community | 磕磕、攀岩么、BetaBeta | Video organization, photo route search, route discovery, public solutions, check-ins, partner planning | Weak private cue validation and optional Watch-assisted capture |
| Gym OS / route map | TopLogger, Griptonite, Vertical-Life gym tools | Gym route inventory, rankings, challenges, setter/admin tools | Depends on gym adoption; weak cross-gym personal memory |
| Training system | Crimpd, board apps, hangboard tools | Structured workouts, training plans, timers | Does not know the user's exact failed gym route |
| Wearable tracker | Apple Workout, Redpoint, Pinnacle, Garmin, COROS | Workout session, heart rate, time, climbing activity modes | Lacks RouteCard, failure reason, MoveCue, NextSessionCue |

LineWise's opening is the overlap these products do not fully cover:

> Private route/project memory + failure reasoning + next-session recall and proof, with optional low-interruption Watch capture.

## 6. Why Indoor Bouldering First

Indoor bouldering is the best first scope because:

- sessions are frequent and repeatable;
- routes are short and attempt-based;
- users often project the same route across attempts or visits;
- route resets make memory fragile;
- phones are inconvenient during climbing, but Watch interactions can work during rest;
- AI route reading needs structured route photos and corrections, which are easier to collect indoors than outdoors.

Outdoor climbing and rope climbing have different problems: navigation, safety, guidebooks, protection, weather, rope management, partner risk, and longer route narratives. They should not drive the first PRD.

## 7. Brand Positioning

English name: **LineWise**  
Chinese name: **线感**

The name points to:

- reading the line;
- developing movement intuition;
- understanding what a route is asking;
- turning a failed attempt into a more intelligent next attempt.

LineWise should feel more like a precise bouldering memory and line-reading tool than a broad "climbing companion."

## 8. Product Pillars

| Pillar | Meaning | Phase |
| --- | --- | --- |
| Gym Visit Memory And Proof | RouteCard, attempts, failure, MoveCue, next-session recall, ProofCheck | P0 |
| PersonalClimbingDataset | Photos, annotations, attempts, failure reasons, movement cues, ProofChecks, optional Watch timelines | P0.5 |
| RouteRead | AI-assisted route photo interpretation with user correction | P1 |
| StickFigureCue | Playful movement explanation with editable keyframes | P1/P1.5 |
| SetterLens | Inferred or authored analysis of what a route is testing | P1/P2 |
| TrainingPath | Failure-driven drills and short learning content | P2 |
| ClimbingBuddy | AI companion first, private human sharing later | P2/P3 |

## 9. Product Principle

LineWise should follow nine rules:

1. **Recall beats recap.** A recap is useful only if it helps the next session.
2. **Route identity is first-class.** Attempts without RouteCard or Project context lose most of their meaning.
3. **Capture has multiple modes.** Watch should be low-interruption and optional. iPhone must support quick capture and review-only fallback.
4. **Suggested, not detected.** Automation is a candidate source, not ground truth.
5. **Private before social.** The earliest value is personal memory and self-improvement, not public feeds.
6. **Proof beats advice.** A MoveCue becomes valuable only when the next attempt records whether it helped.
7. **Reliability before automation.** Do not lose, mis-date, duplicate, or silently rewrite a user's climbing history.
8. **Identity is redundant.** Color is not enough; RouteCard supports wall area, start location, photo, number, or tag.
9. **Context is volunteered.** Optional body/experience context is user-authored and private, never inferred in P0/P0.5.

## 10. Strategic Bet

The strongest bet is:

> If LineWise can help one climber return to a route, remember one useful change, and verify whether it worked, it has found a sharper wedge than generic workout logging or video archiving.

The second bet is:

> If LineWise can collect corrected route photos, attempt outcomes, failure reasons, and movement cues over real gym visits, it can build the data foundation for credible AI route reading.

## 11. Key Risks

| Risk | Why It Matters | Product Response |
| --- | --- | --- |
| Input burden | If RouteCard creation is too slow, users will go back to photos and memory | Target a 10-second minimal RouteCard, with optional fields later |
| Watch eligibility | Some users dislike wearing a Watch, worry about damage/snags, or may face gym restrictions | Make Watch optional; test Watch, iPhone quick capture, and review-only modes |
| Watch interruption | If Watch asks too much during climbing, users will abandon it | Use Watch only during rest, allow sparse meaningful-attempt logging, and keep Undo immediate |
| AI overclaiming | Wrong route reads can damage trust or create safety risk | Keep AI suggestions editable, explain uncertainty, never promise correctness |
| Privacy | Health, photos, videos, location, and social data are sensitive | Local-first, minimum permissions, opt-in uploads only |
| Gym dependency | Requiring official gym integration slows adoption | Consumer-first, gym-agnostic RouteCards |
| Generic category | "Climbing app" is too broad | Own "indoor bouldering route memory + line reading" |
| Feature parity | Competitors already ship Watch, AI, pose, video, stick figures, and training | Differentiate through source, correction, ProofCheck, and data continuity |
| History/sync corruption | Wrong dates, duplicates, stale edits, and transfer ambiguity destroy trust | Historical-entry tests, import preview, idempotency, undo, and provenance |
| Accessibility | Color-only identity can confuse routes | Require a second route anchor and test color-independent retrieval |

## 12. Active Documents

| Document | Purpose |
| --- | --- |
| `docs/archive/legacy/climbing_bouldering_prd_v0_1.md` | Main P0/P0.5 product requirements |
| `docs/research/climbing_bouldering_research_report_v1.md` | Active July 2026 market, user, gym, Watch, AI, and capability research refresh |
| `docs/archive/legacy/project_background.md` | Project context and strategic framing |
| `docs/archive/legacy/climbing_bouldering_mvp_gate.md` | Go/No-Go gates and validation metrics |
| `docs/archive/legacy/climbing_bouldering_data_collection_plan.md` | Real gym visit data collection protocol |
| `docs/archive/legacy/climbing_bouldering_platform_contract.md` | Apple Watch, iPhone, HealthKit, privacy, and claim boundaries |
| `CONTEXT.md` | Canonical product language |
| `docs/adr/` | Durable decisions |

Historical research remains valuable, but it should not override the active PRD, `CONTEXT.md`, or ADRs.

## 13. Important Sources

- [Apple Support: Workout types on Apple Watch](https://support.apple.com/en-us/105089)
- [Apple Developer: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [Apple Developer: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [磕磕：攀岩记录与 Beta 社区](https://apps.apple.com/hk/app/%E7%A3%95%E7%A3%95-%E6%94%80%E5%B2%A9%E8%AE%B0%E5%BD%95%E4%B8%8E-beta-%E7%A4%BE%E5%8C%BA/id6760823408)
- [攀岩么：室内抱石线路与岩馆发现](https://apps.apple.com/tw/app/%E6%94%80%E5%B2%A9%E4%B9%88/id6775133615)
- [KAYA](https://kayaclimb.com/)
- [KAYA for gyms](https://kayaclimb.com/forgyms)
- [Mountain Project mobile app](https://www.mountainproject.com/mobile-app)
- [Vertical-Life gym app](https://gym.vertical-life.info/vertical-life-app/)
- [TopLogger](https://toplogger.nu/)
- [Griptonite](https://griptonite.io/)
- [Crimpd](https://www.crimpd.com/)
- [Redpoint](https://redpoint-app.com/)
- [Pinnacle Climb Log](https://pinnacleclimb.com/)
- [COROS Indoor Climb mode](https://support.coros.com/hc/en-us/articles/11216429256084-Indoor-Climb-mode)
- [Climbing Business Journal: Gyms and Trends 2025](https://climbingbusinessjournal.com/gyms-and-trends-2025/)
