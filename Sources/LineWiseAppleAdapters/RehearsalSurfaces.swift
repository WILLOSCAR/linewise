#if canImport(SwiftUI)
  import Combine
  import Foundation
  import LineWiseApplication
  import LineWiseDomain
  import SwiftUI

  @MainActor
  public final class LineWiseRehearsalViewModel: ObservableObject {
    @Published public private(set) var projection: LineWiseRehearsalProjection
    @Published public private(set) var lastOutcome: LineWiseRehearsalOutcome?
    @Published public private(set) var qualitativeAnalysis: QualitativeRouteAnalysisResult?
    @Published public private(set) var qualitativeAnalysisError: String?
    @Published public private(set) var currentPracticeCue: StickFigureCue?

    private var coordinator: LineWiseRehearsalCoordinator
    private var lastPlaybackDate: Date?
    private var confirmedFailureEpisodes: [FailureEpisodeSnapshot] = []
    private var confirmedMoveCues: [MoveCueSnapshot] = []

    public init(coordinator: LineWiseRehearsalCoordinator) {
      self.coordinator = coordinator
      projection = coordinator.projection
    }

    /// Supplies the user-confirmed recall history that qualitative analysis may
    /// pin as evidence. The coordinator further restricts it to this route, so
    /// callers can pass the whole confirmed history without leaking other routes.
    public func updateConfirmedHistory(
      failureEpisodes: [FailureEpisodeSnapshot],
      moveCues: [MoveCueSnapshot]
    ) {
      confirmedFailureEpisodes = failureEpisodes
      confirmedMoveCues = moveCues
    }

    @discardableResult
    public func handle(_ intent: LineWiseRehearsalIntent) -> LineWiseRehearsalFeedback {
      let feedback = coordinator.handle(intent)
      lastOutcome = feedback.outcome
      projection = feedback.projection
      if feedback.isSuccess, invalidatesQualitativeAnalysis(intent) {
        qualitativeAnalysis = nil
        qualitativeAnalysisError = nil
        currentPracticeCue = nil
      }
      if !feedback.projection.isPlaying {
        lastPlaybackDate = nil
      }
      return feedback
    }

    public func runQualitativeAnalysis(
      using provider: any QualitativeRouteAnalysisProvider
    ) async {
      qualitativeAnalysisError = nil
      do {
        qualitativeAnalysis = try await provider.analyze(qualitativeAnalysisRequest())
      } catch is CancellationError {
        return
      } catch {
        qualitativeAnalysis = nil
        qualitativeAnalysisError = String(describing: error)
      }
    }

    public func runLocalQualitativeAnalysis() async {
      await runQualitativeAnalysis(
        using: DeterministicLocalQualitativeRouteAnalysisProvider(
          algorithmVersion: "x0"
        )
      )
    }

    public func assignNearestHold(at location: CGPoint, in canvasSize: CGSize) {
      guard
        let scenePoint = RehearsalSceneMapper.scenePoint(
          from: location,
          canvasSize: canvasSize,
          sceneSize: projection.scene.size
        )
      else { return }
      let nearest = projection.scene.holds.min {
        $0.center.distance(to: scenePoint) < $1.center.distance(to: scenePoint)
      }
      guard let nearest else { return }
      let selectionRadius = max(
        nearest.radius * 2.5,
        min(projection.scene.size.width, projection.scene.size.height) * 0.055
      )
      guard nearest.center.distance(to: scenePoint) <= selectionRadius else { return }
      handle(.assignHold(holdID: nearest.id))
    }

    public func addKeyframe() {
      let count = projection.keyframes.count + 1
      handle(
        .addKeyframe(
          id: PoseKeyframeID(UUID().uuidString),
          label: "Move \(count)",
          after: projection.selectedKeyframeID
        ))
    }

    public func duplicateSelectedKeyframe() {
      guard let selected = projection.selectedKeyframe else { return }
      handle(
        .duplicateKeyframe(
          selected.id,
          as: PoseKeyframeID(UUID().uuidString),
          label: "\(selected.label) copy"
        ))
    }

    public func deleteSelectedKeyframe() {
      guard let selectedKeyframeID = projection.selectedKeyframeID else { return }
      handle(.deleteKeyframe(selectedKeyframeID))
    }

    public func moveSelectedKeyframe(by offset: Int) {
      guard let index = projection.selectedKeyframeIndex else { return }
      let destination = index + offset
      guard projection.keyframes.indices.contains(destination),
        let keyframeID = projection.selectedKeyframeID
      else { return }
      handle(.moveKeyframe(keyframeID, to: destination))
    }

    public func importCurrentScene(using provider: RehearsalImportProvider) {
      let scene = projection.scene
      handle(
        .importRoute(
          request: RouteReadRequest(
            sceneID: scene.id,
            name: scene.name,
            size: scene.size,
            metersPerSceneUnit: scene.metersPerSceneUnit,
            candidateHolds: scene.holds
          ),
          provider: provider
        ))
    }

    public func importCurrentTimeline(
      using provider: RehearsalImportProvider,
      maximumKeyframeCount: Int
    ) {
      handle(
        .importTimeline(
          track: projection.activeTrack,
          seedKeyframes: projection.keyframes,
          maximumKeyframeCount: maximumKeyframeCount,
          provider: provider
        ))
    }

    public func copyPlanIntoActualDraft() {
      handle(.copyPlanIntoActualDraft)
    }

    @discardableResult
    public func setCurrentMovementIntent(
      purpose: MovementPurpose,
      family: MovementFamily,
      durationSeconds: Double,
      cue: String,
      uncertainty: String? = nil
    ) -> Bool {
      let cue = cue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cue.isEmpty else {
        lastOutcome = .rejected(.unexpected("Movement cue cannot be empty"))
        return false
      }
      let uncertainty = uncertainty?.trimmingCharacters(in: .whitespacesAndNewlines)
      return handle(
        .setCurrentMovementIntent(
          MovementIntent(
            purpose: purpose,
            family: family,
            expectedDurationSeconds: durationSeconds,
            cue: cue,
            uncertainty: uncertainty?.isEmpty == false ? uncertainty : nil,
            provenance: .manual
          )
        )
      ).isSuccess
    }

    public func clearCurrentMovementIntent() {
      handle(.clearCurrentMovementIntent)
    }

    @discardableResult
    public func pinCurrentPracticeSegment(stepCount: Int) -> Bool {
      do {
        currentPracticeCue = try coordinator.makeCurrentStickFigureCue(
          id: StickFigureCueID(UUID().uuidString),
          stepCount: stepCount
        )
        qualitativeAnalysis = nil
        qualitativeAnalysisError = nil
        lastOutcome = .accepted
        return true
      } catch {
        currentPracticeCue = nil
        lastOutcome = .rejected(.unexpected(String(describing: error)))
        return false
      }
    }

    public func playPracticeSegment(stepCount: Int, loop: Bool) {
      handle(.playPracticeSegment(stepCount: stepCount, loop: loop))
    }

    public var rehearsalSnapshot: RouteRehearsal {
      coordinator.engine.rehearsal
    }

    @available(*, deprecated, renamed: "copyPlanIntoActualDraft")
    public func seedActualFromPlan() {
      copyPlanIntoActualDraft()
    }

    public func scrub(to timelinePosition: Double) {
      let stepCount = projection.movementSteps.count
      guard stepCount > 0 else { return }
      let clamped = min(max(timelinePosition, 0), Double(stepCount))
      if clamped >= Double(stepCount) {
        handle(.scrub(transitionIndex: stepCount - 1, progress: 1))
      } else {
        let transition = min(Int(clamped.rounded(.down)), stepCount - 1)
        handle(
          .scrub(
            transitionIndex: transition,
            progress: clamped - Double(transition)
          ))
      }
    }

    public func tick(at date: Date) {
      guard projection.isPlaying else {
        lastPlaybackDate = nil
        return
      }
      guard let previous = lastPlaybackDate else {
        lastPlaybackDate = date
        return
      }
      lastPlaybackDate = date
      let elapsed = min(max(date.timeIntervalSince(previous), 0), 0.25)
      handle(.tick(elapsedSeconds: elapsed))
    }

    public var timelinePosition: Double {
      Double(projection.playback.cursor.transitionIndex) + projection.playback.cursor.progress
    }

    func qualitativeAnalysisRequest() -> QualitativeRouteAnalysisRequest {
      coordinator.qualitativeAnalysisRequest(
        confirmedFailureEpisodes: confirmedFailureEpisodes,
        confirmedMoveCues: confirmedMoveCues,
        stickFigureCue: currentPracticeCue
      )
    }

    private func invalidatesQualitativeAnalysis(_ intent: LineWiseRehearsalIntent) -> Bool {
      switch intent {
      case .assignHold, .clearContact, .setContactLock, .addKeyframe, .duplicateKeyframe,
        .deleteKeyframe, .moveKeyframe, .recomputeKeyframe, .recomputeDownstream, .importRoute,
        .importTimeline, .copyPlanIntoActualDraft, .setCurrentMovementIntent,
        .clearCurrentMovementIntent:
        true
      case .selectTrack, .selectKeyframe, .selectLimb, .stepForward, .stepBackward, .scrub,
        .play, .playPracticeSegment, .pause, .tick:
        false
      }
    }
  }

  /// The route-rehearsal editor is a large-screen surface. It uses `GroupBox`,
  /// `.pickerStyle(.segmented)` and `Stepper`, which SwiftUI marks
  /// `@available(watchOS, unavailable)` or watchOS-9-only, and referencing an
  /// unavailable symbol is a hard compile error rather than a deployment-target
  /// warning. Declaring the view itself watchOS-unavailable is what makes this
  /// file compile for the Watch target; the Watch surface stays capture-only.
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
  @available(watchOS, unavailable)
  @MainActor
  public struct LineWiseRehearsalEditorView: View {
    @StateObject private var model: LineWiseRehearsalViewModel
    @State private var shouldLoop = false
    @State private var maximumSuggestedFrames = 8
    @State private var movementPurpose = MovementPurpose.progress
    @State private var movementFamily = MovementFamily.staticMove
    @State private var movementDurationSeconds = 1.0
    @State private var movementCueDraft = ""
    @State private var movementUncertaintyDraft = ""
    @State private var practiceStepCount = 1

    private let playbackTimer = Timer.publish(
      every: 1.0 / 30.0,
      on: .main,
      in: .common
    ).autoconnect()

    public init(model: @autoclosure @escaping () -> LineWiseRehearsalViewModel) {
      _model = StateObject(wrappedValue: model())
    }

    public var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          header
          sceneCanvas
          trackAndLimbControls
          timeline
          playbackControls
          movementFocus
          importControls
          findingsAndProvenance
        }
        .padding()
      }
      .navigationTitle(model.projection.scene.name)
      .onReceive(playbackTimer) { date in
        model.tick(at: date)
      }
      .onAppear { loadMovementIntentDraft() }
      .onChange(of: movementSelectionKey) { _ in
        loadMovementIntentDraft()
      }
    }

    private var header: some View {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(model.projection.scene.name)
            .font(.title2.bold())
          Text("RouteCard · \(model.projection.routeCardID.rawValue)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        confidenceBadge
      }
    }

    private var confidenceBadge: some View {
      let confidence = model.projection.selectedKeyframe?.confidence ?? .low
      return Text(confidenceLabel(confidence))
        .font(.caption.bold())
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(confidenceColor(confidence).opacity(0.16), in: Capsule())
        .foregroundStyle(confidenceColor(confidence))
    }

    private var sceneCanvas: some View {
      GeometryReader { proxy in
        Canvas { context, size in
          RehearsalCanvasRenderer.draw(
            projection: model.projection,
            context: &context,
            canvasSize: size
          )
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onEnded { value in
              model.assignNearestHold(at: value.location, in: proxy.size)
            }
        )
        .accessibilityLabel("Route wall and climber rehearsal")
        .accessibilityHint("Choose a limb, then tap a hold to move that contact")
      }
      .frame(minHeight: 420)
      .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
      .overlay(alignment: .topLeading) {
        Text("Tap a hold for \(limbName(model.projection.selectedLimb))")
          .font(.caption.bold())
          .padding(8)
          .background(.ultraThinMaterial, in: Capsule())
          .padding(10)
      }
    }

    private var trackAndLimbControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        Picker(
          "Track",
          selection: Binding(
            get: { model.projection.activeTrack },
            set: { model.handle(.selectTrack($0)) }
          )
        ) {
          ForEach(RehearsalTrack.allCases, id: \.self) { track in
            Text(trackName(track)).tag(track)
          }
        }
        .pickerStyle(.segmented)

        HStack(spacing: 8) {
          ForEach(Limb.allCases, id: \.self) { limb in
            Button {
              model.handle(.selectLimb(limb))
            } label: {
              Text(limb.label)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
              RehearsalSelectionButtonStyle(
                selected: model.projection.selectedLimb == limb
              ))
          }
        }

        HStack {
          Button(model.projection.selectedContactIsLocked ? "Unlock contact" : "Lock contact") {
            model.handle(.setContactLock(!model.projection.selectedContactIsLocked))
          }
          .disabled(model.projection.selectedKeyframeID == nil)
          Button("Release contact") {
            model.handle(.clearContact())
          }
          .disabled(model.projection.selectedKeyframeID == nil)
          Spacer()
          if let holdID = model.projection.selectedHoldID {
            Text("\(model.projection.selectedLimb.label) → \(holdID.rawValue)")
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.bordered)
      }
    }

    private var timeline: some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Timeline")
            .font(.headline)
          Spacer()
          Button("Add", systemImage: "plus") { model.addKeyframe() }
          Button("Duplicate", systemImage: "square.on.square") {
            model.duplicateSelectedKeyframe()
          }
          Button("Delete", systemImage: "trash", role: .destructive) {
            model.deleteSelectedKeyframe()
          }
          .disabled(model.projection.keyframes.count <= 1)
        }
        .labelStyle(.iconOnly)

        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(Array(model.projection.keyframes.enumerated()), id: \.element.id) {
              index,
              frame in
              Button {
                model.handle(.selectKeyframe(frame.id))
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  Text("\(index + 1)")
                    .font(.caption2.bold())
                  Text(frame.label)
                    .font(.caption)
                    .lineLimit(1)
                  if frame.validity.isStale {
                    Label("Stale", systemImage: "exclamationmark.triangle.fill")
                      .font(.caption2)
                      .foregroundStyle(.orange)
                  }
                }
                .frame(width: 92, alignment: .leading)
              }
              .buttonStyle(
                RehearsalFrameButtonStyle(
                  selected: model.projection.selectedKeyframeID == frame.id
                ))
            }
          }
        }

        HStack {
          Button("Move earlier", systemImage: "arrow.left") {
            model.moveSelectedKeyframe(by: -1)
          }
          .disabled(model.projection.selectedKeyframeIndex == 0)
          Button("Move later", systemImage: "arrow.right") {
            model.moveSelectedKeyframe(by: 1)
          }
          .disabled(
            model.projection.selectedKeyframeIndex == nil
              || model.projection.selectedKeyframeIndex == model.projection.keyframes.count - 1
          )
          Spacer()
          if let selectedID = model.projection.selectedKeyframeID {
            Button("Recompute pose") {
              model.handle(.recomputeKeyframe(selectedID))
            }
            Button("Recompute downstream") {
              model.handle(.recomputeDownstream(after: selectedID))
            }
          }
        }
        .buttonStyle(.bordered)
      }
    }

    private var playbackControls: some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Button("Previous", systemImage: "backward.frame.fill") {
            model.handle(.stepBackward)
          }
          .labelStyle(.iconOnly)
          .disabled(model.projection.keyframes.isEmpty)

          Button("Next", systemImage: "forward.frame.fill") {
            model.handle(.stepForward)
          }
          .labelStyle(.iconOnly)
          .disabled(model.projection.keyframes.isEmpty)

          if model.projection.isPlaying {
            Button("Pause", systemImage: "pause.fill") { model.handle(.pause) }
          } else {
            Button("Play all", systemImage: "play.fill") {
              model.handle(.play(scope: .fullTimeline, loop: shouldLoop))
            }
            .disabled(model.projection.movementSteps.isEmpty)
          }

          Button("Play this move") {
            model.handle(.play(scope: .currentStep, loop: shouldLoop))
          }
          .disabled(model.projection.movementSteps.isEmpty)
          Toggle("Loop", isOn: $shouldLoop)
            .toggleStyle(.switch)
          Spacer()
          Text("\(Int(model.projection.playback.cursor.progress * 100))%")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)

        Slider(
          value: Binding(
            get: { model.timelinePosition },
            set: { model.scrub(to: $0) }
          ),
          in: 0...Double(max(model.projection.movementSteps.count, 1))
        )
        .disabled(model.projection.movementSteps.isEmpty)

        if let step = model.projection.currentMovementStep {
          Text(step.explanation)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }

    @ViewBuilder
    private var movementFocus: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Movement focus")
            .font(.headline)
          Spacer()
          if model.projection.currentMovementStep?.intent?.validity == .needsReview {
            Label("Review after contact edit", systemImage: "arrow.triangle.2.circlepath")
              .font(.caption.bold())
              .foregroundStyle(.orange)
          }
        }

        if let step = model.projection.currentMovementStep {
          GroupBox("What changes") {
            VStack(alignment: .leading, spacing: 6) {
              Text(step.explanation)
              if !step.retainedLimbs.isEmpty {
                Text("Keep: \(step.retainedLimbs.map(\.label).joined(separator: ", "))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Text(
                "This is a rehearsal instruction, not a feasibility or safety judgment."
              )
              .font(.caption2)
              .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading) {
            Picker("Purpose", selection: $movementPurpose) {
              ForEach(MovementPurpose.allCases, id: \.self) { purpose in
                Text(movementPurposeName(purpose)).tag(purpose)
              }
            }
            Picker("Movement", selection: $movementFamily) {
              ForEach(MovementFamily.allCases, id: \.self) { family in
                Text(movementFamilyName(family)).tag(family)
              }
            }
          }

          Stepper(
            "Rhythm: \(movementDurationSeconds, specifier: "%.2f") seconds",
            value: $movementDurationSeconds,
            in: 0.25...6,
            step: 0.25
          )
          TextField("What should I feel or remember?", text: $movementCueDraft)
          TextField("What is still uncertain? (optional)", text: $movementUncertaintyDraft)

          HStack {
            Button("Save movement intent") {
              model.setCurrentMovementIntent(
                purpose: movementPurpose,
                family: movementFamily,
                durationSeconds: movementDurationSeconds,
                cue: movementCueDraft,
                uncertainty: movementUncertaintyDraft
              )
            }
            .buttonStyle(.borderedProminent)
            .disabled(
              movementCueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            if step.intent != nil {
              Button("Clear intent", role: .destructive) {
                model.clearCurrentMovementIntent()
                loadMovementIntentDraft()
              }
              .buttonStyle(.bordered)
            }
          }

          Divider()
          HStack {
            Stepper(
              "Practice \(practiceStepCount) step\(practiceStepCount == 1 ? "" : "s")",
              value: $practiceStepCount,
              in: 1...availablePracticeStepCount
            )
            Spacer()
            Button("Pin segment") {
              model.pinCurrentPracticeSegment(stepCount: practiceStepCount)
            }
            Button("Loop segment") {
              model.playPracticeSegment(stepCount: practiceStepCount, loop: true)
            }
          }
          .buttonStyle(.bordered)

          if let cue = model.currentPracticeCue {
            Label(
              "Pinned \(cue.steps.count)-step StickFigureCue for focused analysis",
              systemImage: "pin.fill"
            )
            .font(.caption.bold())
          }

          focusedComparison
        } else {
          Label(
            "Add or duplicate a keyframe to create a MovementStep.",
            systemImage: "figure.climbing"
          )
          .foregroundStyle(.secondary)
        }
      }
    }

    @ViewBuilder
    private var focusedComparison: some View {
      if let comparison = model.projection.focusedComparisonStep {
        GroupBox("Plan / Actual at this move") {
          VStack(alignment: .leading, spacing: 6) {
            if comparison.alignmentState != .aligned {
              Label(
                comparison.alignmentState == .missingActual
                  ? "No matched Actual step yet" : "No matched Plan step",
                systemImage: "questionmark.diamond"
              )
              .foregroundStyle(.secondary)
            }
            let changedLimbs = comparison.limbDivergences.filter {
              $0.state == .different || $0.state == .uncertain
            }
            if changedLimbs.isEmpty && comparison.alignmentState == .aligned {
              Label("Contact choices align", systemImage: "checkmark.circle")
            } else if !changedLimbs.isEmpty {
              Text(
                "Contact difference: \(changedLimbs.map { $0.limb.label }.joined(separator: ", "))"
              )
            }
            if let distance = comparison.torsoDivergence.distance {
              Text("Torso path delta: \(distance, specifier: "%.2f") scene units")
            }
            if let delta = comparison.timingDivergence.deltaSeconds {
              Text("Rhythm delta: \(delta, specifier: "%+.2f") seconds")
            }
            Text("Observed, inferred, and manual evidence remain separately labeled.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }

    private var movementSelectionKey: String {
      guard let step = model.projection.currentMovementStep else {
        return "\(model.projection.activeTrack.rawValue)/none"
      }
      return
        "\(model.projection.activeTrack.rawValue)/\(step.fromKeyframeID.rawValue)/\(step.toKeyframeID.rawValue)"
    }

    private var availablePracticeStepCount: Int {
      let start = model.projection.playback.cursor.transitionIndex
      return max(1, min(3, model.projection.movementSteps.count - start))
    }

    private func loadMovementIntentDraft() {
      guard let step = model.projection.currentMovementStep else {
        movementPurpose = .progress
        movementFamily = .staticMove
        movementDurationSeconds = 1
        movementCueDraft = ""
        movementUncertaintyDraft = ""
        practiceStepCount = 1
        return
      }
      movementPurpose = step.intent?.purpose ?? inferredPurpose(for: step)
      movementFamily = step.intent?.family ?? step.family
      movementDurationSeconds = step.effectiveDurationSeconds
      movementCueDraft = step.intent?.cue ?? ""
      movementUncertaintyDraft = step.intent?.uncertainty ?? ""
      practiceStepCount = min(practiceStepCount, availablePracticeStepCount)
    }

    private func inferredPurpose(for step: MovementStep) -> MovementPurpose {
      guard
        let destination = model.projection.keyframes.first(where: {
          $0.id == step.toKeyframeID
        })
      else { return .investigate }
      let reachesTop = destination.contacts.contains { contact in
        guard let holdID = contact.target.holdID else { return false }
        return model.projection.scene.hold(id: holdID)?.routeRole == .top
      }
      return reachesTop ? .finish : .progress
    }

    private func movementPurposeName(_ purpose: MovementPurpose) -> String {
      switch purpose {
      case .setup: "Set up contacts"
      case .progress: "Gain height or reach"
      case .reposition: "Reposition body"
      case .stabilize: "Create stability"
      case .commit: "Commit through crux"
      case .finish: "Finish or top"
      case .investigate: "Test an idea"
      }
    }

    private func movementFamilyName(_ family: MovementFamily) -> String {
      switch family {
      case .staticMove: "Static / controlled"
      case .coordinated: "Coordinated"
      case .dynamic: "Dynamic · uncertain model"
      case .observed: "Observed from Attempt"
      }
    }

    private var importControls: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("Route read & movement source")
          .font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], alignment: .leading) {
          Button("Use manual route") {
            model.importCurrentScene(using: .manual)
          }
          Button("Run local route read") {
            model.importCurrentScene(using: .deterministicLocal(version: "x0"))
          }
          Button("Keep timeline as manual") {
            model.importCurrentTimeline(
              using: .manual,
              maximumKeyframeCount: max(model.projection.keyframes.count, 1)
            )
          }
          .disabled(model.projection.keyframes.isEmpty)
          Button("Suggest local moves") {
            model.importCurrentTimeline(
              using: .deterministicLocal(version: "x0"),
              maximumKeyframeCount: maximumSuggestedFrames
            )
          }
          Button("Copy Plan into Actual draft") {
            model.copyPlanIntoActualDraft()
          }
          .disabled(!model.projection.canCreateActualDraft)
        }
        .buttonStyle(.bordered)

        Stepper(
          "Suggested frames: \(maximumSuggestedFrames)",
          value: $maximumSuggestedFrames,
          in: 2...20
        )
      }
    }

    private var findingsAndProvenance: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Qualitative findings")
          .font(.headline)
        Button("Run local qualitative analysis") {
          Task { await model.runLocalQualitativeAnalysis() }
        }
        .buttonStyle(.bordered)

        if let analysis = model.qualitativeAnalysis {
          GroupBox("Suggested route reading") {
            VStack(alignment: .leading, spacing: 6) {
              Text(
                "Theme: \(humanized(analysis.candidateMovementFamily.rawValue))"
              )
              Text(
                "Constraint: \(humanized(analysis.candidateConstraint.rawValue))"
              )
              if let crux = analysis.candidateCrux {
                Text("Crux candidate: \(crux.location) — \(crux.explanation)")
              }
              Text("Alternative: \(analysis.alternative.explanation)")
              ForEach(Array(analysis.uncertainties.enumerated()), id: \.offset) { _, item in
                Label(item.text, systemImage: "questionmark.circle")
                  .foregroundStyle(.secondary)
              }
              Text(
                "Suggested · inferred · \(Int(analysis.confidence * 100))% · \(analysis.provenance.providerIdentifier) v\(analysis.provenance.version)"
              )
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        if let error = model.qualitativeAnalysisError {
          Text("Qualitative analysis did not complete: \(error)")
            .font(.caption)
            .foregroundStyle(.red)
        }
        if model.projection.findings.isEmpty {
          Text("No qualitative constraint findings for this pose.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(model.projection.findings.enumerated()), id: \.offset) { _, finding in
            Label {
              Text(finding.message)
            } icon: {
              Image(systemName: findingIcon(finding.severity))
                .foregroundStyle(findingColor(finding.severity))
            }
            .font(.callout)
          }
        }

        Divider()
        provenanceRow("Route", model.projection.routeReadProvenance)
        if let timeline = model.projection.timelineImportProvenance {
          provenanceRow(trackName(model.projection.activeTrack), timeline)
        }
        if let frame = model.projection.selectedKeyframe {
          provenanceRow("Frame", frame.provenance)
        }
        if model.projection.selectedFrameWasManuallyEdited {
          Label("This frame was edited manually after import", systemImage: "hand.draw")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text("2D qualitative rehearsal only — not a safety or injury-risk judgment.")
          .font(.caption.bold())
          .foregroundStyle(.secondary)

        if let outcome = model.lastOutcome, case .rejected(let failure) = outcome {
          Text("Could not apply edit: \(String(describing: failure))")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }

    private func humanized(_ rawValue: String) -> String {
      rawValue.replacingOccurrences(of: "_", with: " ")
    }

    private func provenanceRow(
      _ title: String,
      _ provenance: RehearsalProvenance
    ) -> some View {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.caption.bold())
        Spacer()
        Text(
          "\(provenance.displayLabel) · \(provenance.providerIdentifier) v\(provenance.version)"
        )
        .font(.caption.monospaced())
        .multilineTextAlignment(.trailing)
      }
    }

    private func trackName(_ track: RehearsalTrack) -> String {
      track == .plan ? "Plan" : "Actual"
    }

    private func limbName(_ limb: Limb) -> String {
      switch limb {
      case .leftHand: "left hand"
      case .rightHand: "right hand"
      case .leftFoot: "left foot"
      case .rightFoot: "right foot"
      }
    }

    private func confidenceLabel(_ confidence: SolverConfidence) -> String {
      switch confidence {
      case .low: "Low confidence"
      case .medium: "Medium confidence"
      case .high: "High confidence"
      }
    }

    private func confidenceColor(_ confidence: SolverConfidence) -> Color {
      switch confidence {
      case .low: .orange
      case .medium: .blue
      case .high: .green
      }
    }

    private func findingIcon(_ severity: ConstraintFindingSeverity) -> String {
      switch severity {
      case .information: "info.circle"
      case .unresolved: "questionmark.circle"
      case .warning: "exclamationmark.triangle"
      }
    }

    private func findingColor(_ severity: ConstraintFindingSeverity) -> Color {
      switch severity {
      case .information: .secondary
      case .unresolved: .orange
      case .warning: .red
      }
    }
  }

  private struct RehearsalSelectionButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .font(.caption.bold())
        .padding(.vertical, 8)
        .background(
          selected ? Color.accentColor : Color.secondary.opacity(0.10),
          in: RoundedRectangle(cornerRadius: 9)
        )
        .foregroundStyle(selected ? Color.white : Color.primary)
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }

  private struct RehearsalFrameButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .padding(9)
        .background(
          selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08),
          in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        }
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }

  private enum RehearsalSceneMapper {
    static func canvasPoint(
      from point: Point2D,
      canvasSize: CGSize,
      sceneSize: SceneSize
    ) -> CGPoint? {
      guard sceneSize.width > 0, sceneSize.height > 0 else { return nil }
      return CGPoint(
        x: (point.x / sceneSize.width) * canvasSize.width,
        y: canvasSize.height - ((point.y / sceneSize.height) * canvasSize.height)
      )
    }

    static func scenePoint(
      from point: CGPoint,
      canvasSize: CGSize,
      sceneSize: SceneSize
    ) -> Point2D? {
      guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
      return Point2D(
        x: (Double(point.x / canvasSize.width)) * sceneSize.width,
        y: (Double((canvasSize.height - point.y) / canvasSize.height)) * sceneSize.height
      )
    }
  }

  private enum RehearsalCanvasRenderer {
    static func draw(
      projection: LineWiseRehearsalProjection,
      context: inout GraphicsContext,
      canvasSize: CGSize
    ) {
      drawGrid(context: &context, canvasSize: canvasSize)
      drawHolds(projection: projection, context: &context, canvasSize: canvasSize)
      if let avatar = projection.avatar {
        drawAvatar(
          avatar,
          projection: projection,
          context: &context,
          canvasSize: canvasSize
        )
      }
    }

    private static func drawGrid(context: inout GraphicsContext, canvasSize: CGSize) {
      var grid = Path()
      for fraction in 1..<5 {
        let x = canvasSize.width * CGFloat(fraction) / 5
        let y = canvasSize.height * CGFloat(fraction) / 5
        grid.move(to: CGPoint(x: x, y: 0))
        grid.addLine(to: CGPoint(x: x, y: canvasSize.height))
        grid.move(to: CGPoint(x: 0, y: y))
        grid.addLine(to: CGPoint(x: canvasSize.width, y: y))
      }
      context.stroke(grid, with: .color(.secondary.opacity(0.10)), lineWidth: 0.5)
    }

    private static func drawHolds(
      projection: LineWiseRehearsalProjection,
      context: inout GraphicsContext,
      canvasSize: CGSize
    ) {
      for hold in projection.scene.holds {
        guard
          let center = RehearsalSceneMapper.canvasPoint(
            from: hold.center,
            canvasSize: canvasSize,
            sceneSize: projection.scene.size
          )
        else { continue }
        let scaledRadius = CGFloat(hold.radius / projection.scene.size.width) * canvasSize.width
        let radius = max(scaledRadius, 6)
        let rect = CGRect(
          x: center.x - radius,
          y: center.y - radius,
          width: radius * 2,
          height: radius * 2
        )
        let path = Path(ellipseIn: rect)
        let selected = projection.selectedHoldID == hold.id
        context.fill(path, with: .color(holdColor(hold).opacity(selected ? 1 : 0.72)))
        if selected {
          context.stroke(path, with: .color(.accentColor), lineWidth: 4)
        } else if hold.routeRole == .start || hold.routeRole == .top {
          context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: 1.5)
        }
      }
    }

    private static func drawAvatar(
      _ avatar: ClimberAvatar,
      projection: LineWiseRehearsalProjection,
      context: inout GraphicsContext,
      canvasSize: CGSize
    ) {
      let segments: [(AvatarJoint, AvatarJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftHand),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightHand),
        (.torso, .pelvis),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftFoot),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightFoot),
      ]
      var skeleton = Path()
      for (fromJoint, toJoint) in segments {
        guard
          let from = avatar.joints[fromJoint],
          let to = avatar.joints[toJoint],
          let start = RehearsalSceneMapper.canvasPoint(
            from: from,
            canvasSize: canvasSize,
            sceneSize: projection.scene.size
          ),
          let end = RehearsalSceneMapper.canvasPoint(
            from: to,
            canvasSize: canvasSize,
            sceneSize: projection.scene.size
          )
        else { continue }
        skeleton.move(to: start)
        skeleton.addLine(to: end)
      }
      context.stroke(
        skeleton,
        with: .color(projection.activeTrack == .plan ? .blue : .green),
        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
      )

      if let torso = avatar.joints[.torso],
        let center = RehearsalSceneMapper.canvasPoint(
          from: torso,
          canvasSize: canvasSize,
          sceneSize: projection.scene.size
        )
      {
        let heightInSceneUnits =
          projection.scene.metersPerSceneUnit.map {
            projection.bodyProfile.heightMeters / $0
          } ?? (projection.scene.size.height * 0.32)
        let heightInCanvas =
          CGFloat(heightInSceneUnits / projection.scene.size.height)
          * canvasSize.height
        let radius = max(heightInCanvas * 0.045, 7)
        let headCenter = CGPoint(x: center.x, y: center.y - radius * 2.3)
        let head = Path(
          ellipseIn: CGRect(
            x: headCenter.x - radius,
            y: headCenter.y - radius,
            width: radius * 2,
            height: radius * 2
          ))
        context.fill(head, with: .color(.primary.opacity(0.85)))
      }

      for limb in Limb.allCases {
        let joint = avatarJoint(for: limb)
        guard
          let point = avatar.joints[joint],
          let center = RehearsalSceneMapper.canvasPoint(
            from: point,
            canvasSize: canvasSize,
            sceneSize: projection.scene.size
          )
        else { continue }
        let marker = Path(
          ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
        )
        context.fill(
          marker,
          with: .color(limb == projection.selectedLimb ? .accentColor : .primary)
        )
      }
    }

    private static func avatarJoint(for limb: Limb) -> AvatarJoint {
      switch limb {
      case .leftHand: .leftHand
      case .rightHand: .rightHand
      case .leftFoot: .leftFoot
      case .rightFoot: .rightFoot
      }
    }

    private static func holdColor(_ hold: Hold) -> Color {
      switch hold.routeRole {
      case .start: .green
      case .zone: .yellow
      case .top: .red
      case .route: .indigo
      case .unknown: .gray
      }
    }
  }
#endif
