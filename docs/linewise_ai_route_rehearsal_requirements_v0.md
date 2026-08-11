# LineWise AI Route Rehearsal Requirements v0

Date: 2026-08-11

Status: Active Intelligence Nursery requirements draft; not a P0 release dependency

Product: LineWise / 线感

Scope: AI route reading, personalized climber avatar, editable movement keyframes, continuous animation, and step debugging

## 1. Why This Document Exists

LineWise should not reduce its AI vision to a generated text answer or a static stick figure.

The intended experience is:

1. recover an editable route scene from ordinary gym media;
2. place a generic or personalized climber body onto that scene;
3. generate one or more candidate movement sequences;
4. let the user move each limb between holds one step at a time;
5. solve and explain the resulting body pose;
6. play the keyframes as a continuous animation;
7. compare the plan with a reconstructed real attempt later.

This is an independent AI mainline. It begins exploration now, but it does not become a dependency for the manual P0 Gym Visit Memory loop.

## 2. Product Outcome

The user should be able to answer:

> Given this route and my body proportions, what are several plausible ways I could move through it, how does each limb contact change step by step, and what should I pay attention to when I try it?

The product should behave like an editable rehearsal tool, not an oracle.

It should support:

- exploration before climbing;
- explanation after a failed attempt;
- reconstruction after a recorded attempt;
- comparison between a planned sequence and what actually happened;
- saving a short visual excerpt as a MoveCue;
- validating the idea during the next real attempt.

## 3. Three User Modes

### 3.1 Plan Mode

Input:

- one or more route photos;
- confirmed route holds and start/top roles;
- a generic or personal BodyProfile;
- optional style preference, such as static, dynamic, or show alternatives.

Output:

- one to three MovementHypotheses;
- an editable MoveSequence;
- PoseKeyframes and qualitative explanations;
- a playable RouteRehearsal.

Plan Mode generates a possible future movement. It does not reconstruct an observed fact.

### 3.2 Replay Mode

Input:

- a real climbing video;
- the confirmed RouteScene;
- optional user corrections when joints or contacts are occluded.

Output:

- a reconstructed sequence of observed body poses;
- observed or inferred limb-to-hold contacts;
- uncertainty and missing-frame markers;
- an editable RouteRehearsal sourced from video.

Replay Mode reconstructs an actual attempt. It must keep observed, inferred, and user-corrected data separate.

### 3.3 Compare Mode

Input:

- one planned RouteRehearsal;
- one reconstructed actual attempt.

Output:

- step alignment;
- planned versus actual contacts;
- changed sequence, timing, or body position;
- a candidate explanation for where the plan diverged;
- a ProofCheck for the next attempt.

Compare Mode is the bridge from visual novelty to training value.

## 4. Canonical Experience

~~~text
Route photo or scan
  -> editable RouteScene
  -> confirmed route and scale
  -> BodyProfile / ClimberAvatar
  -> MovementHypotheses
  -> MoveSequence
  -> PoseKeyframes
  -> step-by-step editor
  -> continuous RouteRehearsal animation
  -> real attempt
  -> Replay / Compare
  -> MoveCue / ProofCheck / TrainingPath
~~~

## 5. Domain Model

### 5.1 RouteScene

An editable representation of the wall and route recovered from one or more photos, video frames, or a future spatial scan.

Required data:

- source media references;
- wall plane or approximate wall geometry;
- visible HoldInstances and volumes;
- selected RouteGroup;
- start, top, zone, and unknown roles;
- image-to-scene transform;
- scale source and confidence;
- occluded or unresolved areas;
- correction history.

RouteScene is not an official gym route database.

### 5.2 HoldInstance

One visible contact surface on the wall.

It may represent:

- a normal hold;
- a volume;
- a wall smear region;
- a partly occluded hold;
- an unresolved candidate.

A HoldInstance is not just a center point. It should support a 2D region first and optional 2.5D or 3D geometry later.

### 5.3 BodyProfile

A local-first set of body proportions and optional mobility preferences used to size the rehearsal skeleton.

Minimum profile:

- height;
- wingspan or arm span;
- optional inseam;
- optional shoulder and hip width;
- dominant side;
- profile confidence.

Optional later profile:

- measured upper/lower arm and leg lengths;
- user-set comfortable joint ranges;
- preferred static or dynamic style;
- an explicitly captured calibration image or motion.

BodyProfile must not infer injury, disability, safety, or medical capability.

### 5.4 ClimberAvatar

The rendered articulated body derived from a BodyProfile.

Initial presentation may be:

- a simple stick figure;
- a proportioned 2D skeleton;
- a neutral 3D mannequin;
- a future user-selected visual skin.

The first product value comes from consistent joints and contacts, not photorealistic identity.

### 5.5 LimbContact

An explicit relationship between one limb and one contact target at a point in the sequence.

Each of LH, RH, LF, and RF must be in one state:

- contacting a HoldInstance;
- contacting a volume;
- smearing on the wall;
- contacting the ground;
- free;
- unknown.

Contact mode may further describe hand, foot, heel, toe, hook, compression, or match.

### 5.6 MoveSequence

The symbolic ordered plan of which limb changes to which contact target.

MoveSequence answers:

- which limb moves;
- where it moves;
- what contacts stay locked;
- whether the move is static, coordinated, or dynamic;
- which alternative branch it belongs to.

It does not by itself define a complete body pose.

### 5.7 PoseKeyframe

A whole-body pose at one meaningful climbing state.

It includes:

- joint positions or rotations;
- all LimbContacts;
- torso and pelvis placement;
- facing or orientation;
- optional center-of-mass estimate;
- solver confidence;
- unresolved ConstraintFindings.

### 5.8 MovementStep

The transition between two PoseKeyframes.

A MovementStep includes:

- source and destination keyframes;
- primary moving limb or coordinated limb set;
- contacts gained, released, and retained;
- expected duration;
- movement family;
- qualitative explanation;
- uncertainty and alternatives.

### 5.9 MovementHypothesis

One complete candidate interpretation of how a person could climb the route.

Examples:

- static and controlled;
- shorter-reach alternative;
- dynamic deadpoint;
- left-leading versus right-leading.

Multiple hypotheses are preferred to false certainty.

### 5.10 RouteRehearsal

An editable, personalized, and playable sequence of PoseKeyframes and MovementSteps over a RouteScene.

It owns:

- selected BodyProfile;
- chosen MovementHypothesis;
- keyframe timeline;
- branch alternatives;
- edit and correction history;
- animation settings;
- source and provenance;
- validation state.

### 5.11 StickFigureCue

A short shareable excerpt from a RouteRehearsal, normally one to three MovementSteps.

StickFigureCue explains one crux or movement idea. It is not the full route simulator.

### 5.12 ConstraintFinding

A qualitative warning or unresolved assumption produced by the solver.

Candidate types:

- reach limit;
- joint-range tension;
- contact conflict;
- likely wall or body collision;
- scale uncertainty;
- wall-angle uncertainty;
- balance or support concern;
- occluded hold;
- downstream step invalidated;
- dynamic move requires a different model.

A ConstraintFinding is not a safety diagnosis.

## 6. AI Mainline

### 6.1 Scene Understanding

Responsibilities:

- identify visible holds and volumes;
- group the selected route;
- suggest start/top/zone roles;
- estimate wall plane, angle, perspective, and scale;
- expose low-confidence and occluded regions;
- accept user corrections without regenerating unrelated work.

Minimum viable approach:

- one route-focused photo;
- manual scale hint or known hold distance;
- AI-suggested hold regions;
- user-confirmed RouteGroup.

Better inputs:

- second angled photo;
- short wall scan;
- route tag or grade marker;
- optional depth or spatial data.

Single-photo reconstruction must be called 2D or 2.5D when depth is not observed.

### 6.2 Personal Body Model

Responsibilities:

- create a skeleton from BodyProfile;
- maintain segment lengths across every keyframe;
- expose uncertain or default proportions;
- allow a generic avatar when the user provides no body data;
- keep profile data local by default.

The first version should use explicit measurements rather than promise automatic body scanning.

### 6.3 Contact Planner

Responsibilities:

- generate candidate limb-to-hold sequences;
- represent matches, crosses, flags, smears, hooks, and free limbs;
- respect confirmed start and top rules;
- propose alternatives rather than one official solution;
- separate static and dynamic movement families.

The planner should first generate a symbolic MoveSequence. Pose solving comes afterward.

### 6.4 Pose Solver

Responsibilities:

- place hands and feet on their target contacts;
- preserve locked contacts;
- solve elbows, knees, shoulders, hips, and torso placement;
- respect BodyProfile segment lengths;
- expose infeasible or strained candidates;
- never silently detach or teleport a locked limb.

The initial solver is qualitative inverse kinematics, not a full biomechanical simulator.

### 6.5 Qualitative Interpreter

For each MovementStep, generate:

- **Action**: what moves where;
- **Body position**: hip, torso, knee, flag, or tension cue;
- **Why**: the route constraint this move may address;
- **What to feel**: a short user-facing movement cue;
- **Uncertainty**: missing geometry, contact, or body assumptions;
- **Alternative**: another plausible step when useful.

SetterLens may additionally describe:

- wall style;
- movement family;
- likely crux;
- skill focus;
- body-size sensitivity;
- likely intended constraint.

Unless a real setter provides it, SetterLens remains inferred.

### 6.6 Motion Synthesizer

Responsibilities:

- interpolate between PoseKeyframes;
- keep retained contacts visually locked;
- honor per-step duration and easing;
- avoid obvious joint discontinuities;
- produce a continuous timeline;
- preserve the exact discrete keyframes used by the editor.

Static and dynamic moves need separate handling:

- static moves can begin with contact-constrained interpolation;
- dynamic moves may include coordinated release, flight, and recapture;
- dynamic playback must show higher uncertainty until a physics-aware model exists.

### 6.7 Reconstructor

Replay Mode responsibilities:

- detect an observed person in video;
- estimate body joints per frame;
- align the person with the RouteScene;
- infer candidate contacts;
- mark occlusion and lost tracking;
- let the user correct joints and contacts;
- convert a long video into meaningful PoseKeyframes.

Reconstructor output must never be mixed with generated Plan Mode output without provenance.

## 7. Step Editor And Single-Step Debugger

Single-step editing is a first-class product surface.

### 7.1 Canvas

The main canvas shows:

- route photo or scene;
- hold regions and role overlays;
- current ClimberAvatar;
- retained-contact indicators;
- previous and next pose ghosts;
- uncertainty and ConstraintFinding markers.

### 7.2 Timeline

The timeline shows:

- one tile per PoseKeyframe;
- the primary moving limb between tiles;
- warnings on invalid or stale downstream steps;
- alternative branches;
- planned, observed, and user-corrected provenance.

### 7.3 Limb Editing

The user can:

- select LH, RH, LF, or RF;
- drag the selected limb to a HoldInstance;
- set the contact mode;
- lock or unlock a contact;
- drag the pelvis or torso;
- adjust elbow or knee direction;
- mark a flag, smear, hook, match, or free limb;
- request an alternative pose for the same contacts.

When one limb moves, other locked contacts must not change silently.

### 7.4 Step Operations

The user can:

- insert a step;
- delete a step;
- duplicate a step;
- reorder steps;
- split a coordinated move;
- merge adjacent moves;
- branch an alternative;
- undo and redo;
- regenerate only the current step;
- regenerate downstream steps from the current edit.

An upstream edit marks affected downstream steps stale until they are accepted or recomputed.

### 7.5 Debug Controls

Required controls:

- previous keyframe;
- next keyframe;
- play only this transition;
- pause;
- scrub within the transition;
- continuous play;
- playback speed;
- loop current step;
- show before/after ghosts;
- show contact diff;
- show constraint explanation.

The user must be able to understand exactly which contact changed at every step.

## 8. Continuous Animation

### 8.1 Deterministic Playback

Given the same RouteRehearsal version, playback must use the same keyframes, contacts, timing, and branch.

### 8.2 Contact Preservation

During a transition:

- retained hand/foot contacts remain visually attached;
- released contacts are explicitly marked;
- new contacts become active only at the intended moment;
- a limb cannot switch targets without a MovementStep.

### 8.3 Transition Quality

The animation should avoid:

- joint popping;
- limb teleportation;
- foot or hand sliding on a locked hold;
- body-scale changes;
- passing through the wall without warning;
- unexplained simultaneous contact changes.

### 8.4 Output

Initial output:

- interactive in-app playback;
- saved RouteRehearsal.

Later optional output:

- a short video;
- GIF or Live Photo;
- shareable StickFigureCue;
- side-by-side planned and actual playback.

## 9. Interaction Wireframe

~~~text
┌──────────────────────── Route canvas ────────────────────────┬──────── Analysis ────────┐
│ Route photo / scene                                          │ Step 4 of 9              │
│                                                             │ Action: RH -> hold 12     │
│         LH●        RH○                                       │ Why: keep hips right      │
│            \      /                                          │ Confidence: medium        │
│             avatar                                           │ Warning: wall angle guess │
│            /      \                                          │ Alternative: deadpoint    │
│         LF●        RF●                                       │                          │
├─────────────────────────────────────────────────────────────┴──────────────────────────┤
│ [◀] [Step] [▶] [Play transition] [Play all] [Loop] [0.5x] [1x]                         │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ K1 ─ RH→4 ─ K2 ─ LF→7 ─ K3 ─ LH→9 ─ K4! ─ RF→10 ─ K5        [+ branch]                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ Limb: [LH] [RH] [LF] [RF]  Contact: [hold] [smear] [hook] [free]  [lock] [regenerate] │
└────────────────────────────────────────────────────────────────────────────────────────┘
~~~

## 10. Data And Provenance

Every suggested object should record:

- source: user, model, video observation, coach, setter, or imported;
- source media;
- model and algorithm version;
- confidence;
- accepted, edited, rejected, or unresolved state;
- correction events;
- parent RouteRehearsal version;
- body profile used;
- scene version used.

Required rule:

> User-confirmed contact and pose edits override model suggestions without deleting the original suggestion.

## 11. Privacy

- BodyProfile is local-first.
- A generic avatar must remain available without body measurements or photos.
- Calibration photos or videos require explicit opt-in.
- Route and body media are not uploaded to cloud AI without a separate action and clear explanation.
- Export and deletion apply to source media, BodyProfile, generated rehearsals, and derived data.
- No face model is required for the core experience.
- Do not infer injury, medical condition, disability, or safety from body proportions or movement.

## 12. Claim Contract

Allowed:

- suggested route;
- candidate movement sequence;
- personalized rehearsal;
- qualitative reach or contact warning;
- inferred SetterLens;
- editable animation;
- planned versus observed comparison.

Not allowed:

- correct solution;
- physically guaranteed move;
- safe or unsafe move;
- official setter intent without setter authorship;
- injury-prevention or medical advice;
- precise force, fatigue, or joint-load claim from animation alone;
- automatic proof that the user can execute the move.

## 13. Manual Baseline

The product must support a useful manual RouteRehearsal without AI:

1. user confirms holds;
2. user chooses four starting contacts;
3. user moves one limb at a time;
4. the pose solver fills the remaining joints;
5. the app plays the sequence;
6. the user saves a StickFigureCue.

If this manual editor is not useful, more automatic generation is unlikely to rescue the product.

## 14. Prototype Ladder

### X0: Manual 2D Rehearsal

- one route image;
- manual hold points/regions;
- generic proportioned stick figure;
- four explicit limb contacts;
- manual steps;
- constrained 2D pose solving;
- continuous interpolation;
- single-step debugger.

Question:

> Is manipulating the body on holds genuinely useful and enjoyable?

### X1: Assisted RouteScene

- suggested holds and route grouping;
- user correction;
- wall angle and scale hints;
- corrected scene reuse.

Question:

> Does assistance reduce setup time without damaging trust?

### X2: Personalized Plan Mode

- BodyProfile;
- generated MovementHypotheses;
- alternative sequences;
- qualitative explanation;
- correction capture.

Question:

> Does personalization produce meaningfully different and more useful rehearsals?

### X3: Replay Mode

- video pose reconstruction;
- hold-contact inference;
- occlusion repair;
- observed keyframe extraction.

Question:

> Can the user recover a useful attempt narrative faster than reviewing raw video?

### X4: Compare And Training

- planned versus observed alignment;
- divergence explanation;
- MoveCue and MicroDrill;
- next-session ProofCheck.

Question:

> Does rehearsal change a later attempt rather than only create an attractive animation?

### X5: 2.5D / 3D And Dynamic Motion

- multi-view or spatial wall capture;
- volumes and overhang geometry;
- physics-aware dynamic transitions;
- richer body model.

Question:

> Does extra geometric and physical complexity improve decisions enough to justify capture burden?

## 15. Prototype Hypotheses

These are initial hypotheses to calibrate, not industry benchmarks.

| Hypothesis | Measurement | Weak Signal |
| --- | --- | --- |
| Manual value | User completes a five-step rehearsal and reopens it before climbing | User treats it as a one-time toy |
| Editing leverage | Moving one limb preserves other contacts and yields a usable pose quickly | Every step requires full-body repair |
| AI assistance | Correcting the suggested route/sequence is faster than authoring manually | User deletes and restarts suggestions |
| Explanation value | User can state what changed and why after step playback | Animation is understandable only with expert narration |
| Personalization | BodyProfile changes at least one useful reach or sequence decision | Personalized and generic outputs feel identical |
| Field consequence | At least one cue is tried and evaluated in a real attempt | Users watch but never act |
| Trust | Users distinguish planned, inferred, observed, and confirmed data | Generated motion is treated as ground truth |

## 16. Technical Acceptance Criteria For X0

- A user can create a RouteScene manually from one image.
- Every PoseKeyframe explicitly represents LH, RH, LF, and RF contacts.
- Moving one limb does not silently change a locked limb.
- The same contact plan produces a deterministic solved pose.
- Insert, delete, reorder, branch, undo, and redo work without losing source history.
- An upstream edit marks downstream poses stale.
- The user can recompute only the current or downstream steps.
- Continuous playback preserves keyframe order and visible contact locks.
- The user can play and loop one transition.
- The UI shows contact differences and ConstraintFindings per step.
- A complete manual route can be saved and reopened without AI.

## 17. Edge Cases

Route scene:

- holds share the same color;
- colored tags, not holds, identify the route;
- volumes belong to multiple routes;
- start/top are occluded;
- two start holds or a matched start;
- wall is slab, overhang, cave, or compound angle;
- photo perspective severely distorts reach;
- route has been reset or changed.

Movement:

- both hands match one hold;
- hand swap or foot swap;
- heel hook, toe hook, knee bar, compression, or mantle;
- flag foot has no hold;
- smear uses a wall region;
- cross-through changes limb ordering;
- simultaneous coordination move;
- dyno releases several contacts;
- topout moves out of the image plane;
- the user intentionally chooses a pose the solver rates strained.

Body:

- generic profile only;
- missing or uncertain measurements;
- unusually short or long reach;
- left/right asymmetry;
- user rejects inferred proportions;
- clothing or camera angle distorts body reconstruction.

Data:

- AI generation times out;
- model output references a deleted hold;
- source photo is replaced;
- a corrected route invalidates every downstream pose;
- video loses the climber behind another person;
- planned and actual sequences contain different numbers of steps.

## 18. Open Product Decisions

- Should X0 begin as a pure 2D editor or a 3D mannequin projected onto the image?
- Is BodyProfile entered through measurements, a calibration pose, or both?
- Should Plan Mode first generate one conservative sequence or several diverse alternatives?
- How should the user express body-size or style preferences without stereotyping?
- Which moves are supported before dynamic coordination?
- Does a free flag count as a contact state or a visual pose property?
- How should hand/foot contact regions represent large volumes and smears?
- Is the main first-use entry RouteCard, camera capture, or a standalone route-reading lab?
- Which edits are local to one keyframe and which should propagate?
- What is the minimum evidence before a RouteRehearsal can drive TrainingPath?

## 19. Evidence And Feasibility Notes

- Apple Vision can detect observed human body points in images and provide 3D body-pose observations; ARKit can track an observed body skeleton. These capabilities help Replay Mode and optional BodyProfile calibration, but they do not generate a climbing plan on their own.
- Parametric body models such as SMPL demonstrate that body shape and pose can share one articulated representation. Licensing and on-device feasibility must be evaluated before choosing a production body model.
- CIMI4D shows that climbing motion capture requires explicit human-scene interaction and frame-level hold contacts, and that climbing remains challenging for general pose methods.
- Contact-aware motion research supports modeling body-scene contacts explicitly to reduce visually inconsistent motion.
- Humanoid climbing research shows the usefulness of contact-state planning and balance/torque constraints, but robot feasibility is not evidence that a human climbing solution is correct or safe.

Primary references:

- [Apple Vision: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/Vision/detecting-human-body-poses-in-images)
- [Apple Vision: HumanBodyPose3DObservation](https://developer.apple.com/documentation/vision/humanbodypose3dobservation)
- [Apple ARKit: ARSkeleton](https://developer.apple.com/documentation/arkit/arskeleton)
- [SMPL: A Skinned Multi-Person Linear Model](https://smpl.is.tue.mpg.de/)
- [CIMI4D: climbing motion and human-scene contacts](https://openaccess.thecvf.com/content/CVPR2023/html/Yan_CIMI4D_A_Large_Multimodal_Climbing_Motion_Dataset_Under_Human-Scene_Interactions_CVPR_2023_paper.html)
- [Contact-aware Human Motion Forecasting](https://papers.neurips.cc/paper_files/paper/2022/hash/3018804d037cc101b73624f381bed0cb-Abstract-Conference.html)
- [Whole-body climbing motion generation with mechanical constraints](https://www.jstage.jst.go.jp/article/jsmermd/2013/0/2013__2P1-B03_1/_article/-char/en)

## 20. Promotion Rule

No Intelligence Nursery prototype becomes a production promise merely because it looks convincing.

A capability is promoted only when:

1. the manual baseline is useful;
2. AI reduces user work or adds a decision the baseline cannot;
3. uncertainty and correction remain understandable;
4. at least one real-gym consequence is demonstrated;
5. privacy and claim contracts remain intact.
