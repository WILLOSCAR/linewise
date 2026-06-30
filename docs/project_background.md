# LineWise Project Background

Date: 2026-07-01  
Status: Active product background. Read this before the PRD if you are new to the project.

## 1. One-Line Summary

**LineWise / 线感** is an indoor bouldering companion for Apple Watch and iPhone. It helps a climber remember gym routes, capture attempts with minimal interruption, review failure points, preserve movement cues, and build a personal dataset for future AI-assisted line reading.

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

The product is not trying to become a route guidebook, a public social feed, a generic training course library, or an automatic AI coach. The first useful product is a private memory system for real gym visits.

## 3. Current Product Thesis

LineWise should prove this loop first:

```text
RouteCard -> Watch attempt/rest capture -> iPhone review -> NextSessionCue -> next gym visit
```

The long-term product can grow into:

```text
PersonalClimbingDataset -> RouteRead -> StickFigureCue -> SetterLens -> TrainingPath -> private sharing
```

The important ordering is intentional. AI route reading should come after a reliable route memory and data collection loop, not before it.

## 4. Target Context

LineWise is currently scoped to:

- indoor bouldering;
- commercial climbing gyms;
- Apple Watch + iPhone users;
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
| Guidebook / community graph | KAYA, Mountain Project, 27 Crags, Vertical-Life | Outdoor routes, topos, beta videos, sends, social graph | Not Watch-first, not personal indoor route memory first |
| Gym OS / route map | TopLogger, Griptonite, Vertical-Life gym tools | Gym route inventory, rankings, challenges, setter/admin tools | Depends on gym adoption; weak cross-gym personal memory |
| Training system | Crimpd, board apps, hangboard tools | Structured workouts, training plans, timers | Does not know the user's exact failed gym route |
| Wearable tracker | Apple Workout, Redpoint, Pinnacle, Garmin, COROS | Workout session, heart rate, time, climbing activity modes | Lacks RouteCard, failure reason, MoveCue, NextSessionCue |

LineWise's opening is the overlap these products do not fully cover:

> Low-interruption Watch capture + route/project memory + failure/movement cue review + next-session recall.

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
| Gym Visit Memory | RouteCard, attempts, rest, review, next-session recall | P0 |
| PersonalClimbingDataset | Photos, annotations, attempts, failure reasons, movement cues, Watch timelines | P0.5 |
| RouteRead | AI-assisted route photo interpretation with user correction | P1 |
| StickFigureCue | Playful movement explanation with editable keyframes | P1/P1.5 |
| SetterLens | Inferred or authored analysis of what a route is testing | P1/P2 |
| TrainingPath | Failure-driven drills and short learning content | P2 |
| ClimbingBuddy | AI companion first, private human sharing later | P2/P3 |

## 9. Product Principle

LineWise should follow five rules:

1. **Recall beats recap.** A recap is useful only if it helps the next session.
2. **Route identity is first-class.** Attempts without RouteCard or Project context lose most of their meaning.
3. **Watch captures; iPhone explains.** Watch should be low-interruption. iPhone should own route details, review, photos, and learning.
4. **Suggested, not detected.** Automation is a candidate source, not ground truth.
5. **Private before social.** The earliest value is personal memory and self-improvement, not public feeds.

## 10. Strategic Bet

The strongest bet is:

> If LineWise can help one climber return to the gym and immediately remember what to try next, it has found a sharper wedge than generic workout logging.

The second bet is:

> If LineWise can collect corrected route photos, attempt outcomes, failure reasons, and movement cues over real gym visits, it can build the data foundation for credible AI route reading.

## 11. Key Risks

| Risk | Why It Matters | Product Response |
| --- | --- | --- |
| Input burden | If RouteCard creation is too slow, users will go back to photos and memory | 30-second minimum RouteCard, optional fields later |
| Watch interruption | If Watch asks too much during climbing, users will abandon it | Use Watch only during rest and with one-tap actions |
| AI overclaiming | Wrong route reads can damage trust or create safety risk | Keep AI suggestions editable, explain uncertainty, never promise correctness |
| Privacy | Health, photos, videos, location, and social data are sensitive | Local-first, minimum permissions, opt-in uploads only |
| Gym dependency | Requiring official gym integration slows adoption | Consumer-first, gym-agnostic RouteCards |
| Generic category | "Climbing app" is too broad | Own "indoor bouldering route memory + line reading" |

## 12. Active Documents

| Document | Purpose |
| --- | --- |
| `docs/climbing_bouldering_prd_v0_1.md` | Main P0/P0.5 product requirements |
| `docs/project_background.md` | Project context and strategic framing |
| `docs/climbing_bouldering_mvp_gate.md` | Go/No-Go gates and validation metrics |
| `docs/climbing_bouldering_data_collection_plan.md` | Real gym visit data collection protocol |
| `docs/climbing_bouldering_platform_contract.md` | Apple Watch, iPhone, HealthKit, privacy, and claim boundaries |
| `CONTEXT.md` | Canonical product language |
| `docs/adr/` | Durable decisions |

Historical research remains valuable, but it should not override the active PRD, `CONTEXT.md`, or ADRs.

## 13. Important Sources

- [Apple Support: Workout types on Apple Watch](https://support.apple.com/en-us/105089)
- [Apple Developer: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [Apple Developer: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
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
