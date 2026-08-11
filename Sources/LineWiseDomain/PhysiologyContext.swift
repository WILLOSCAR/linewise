public struct PhysiologyContextID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum ForearmPumpLevel: Int, Equatable, Codable, Sendable {
  case none = 0
  case light = 1
  case moderate = 2
  case strong = 3
  case maximal = 4
}

public struct SubjectivePhysiologyCheckIn: Equatable, Codable, Sendable {
  public let sessionEffort1To10: Int?
  public let wholeBodyFatigue0To10: Int?
  public let forearmPumpOverall: ForearmPumpLevel?

  public init(
    sessionEffort1To10: Int?,
    wholeBodyFatigue0To10: Int?,
    forearmPumpOverall: ForearmPumpLevel?
  ) {
    self.sessionEffort1To10 = sessionEffort1To10
    self.wholeBodyFatigue0To10 = wholeBodyFatigue0To10
    self.forearmPumpOverall = forearmPumpOverall
  }
}

public enum WorkoutEffortSource: String, Equatable, Codable, Sendable {
  case perceived
  case estimated
}

public struct HealthKitWorkoutSummary: Equatable, Codable, Sendable {
  public let durationSeconds: Double
  public let averageHeartRateBPM: Double?
  public let maximumHeartRateBPM: Double?
  public let heartRateCoverage: Double?
  public let activeEnergyKilocalories: Double?
  public let workoutEffortScore: Double?
  public let workoutEffortSource: WorkoutEffortSource?
  public let sourceVersion: String

  public init(
    durationSeconds: Double,
    averageHeartRateBPM: Double?,
    maximumHeartRateBPM: Double?,
    heartRateCoverage: Double?,
    activeEnergyKilocalories: Double?,
    workoutEffortScore: Double?,
    workoutEffortSource: WorkoutEffortSource?,
    sourceVersion: String
  ) {
    self.durationSeconds = durationSeconds
    self.averageHeartRateBPM = averageHeartRateBPM
    self.maximumHeartRateBPM = maximumHeartRateBPM
    self.heartRateCoverage = heartRateCoverage
    self.activeEnergyKilocalories = activeEnergyKilocalories
    self.workoutEffortScore = workoutEffortScore
    self.workoutEffortSource = workoutEffortSource
    self.sourceVersion = sourceVersion
  }
}

public enum PhysiologyPrimarySource: String, Equatable, Codable, Sendable {
  case subjectiveReport = "subjective_report"
  case none
}

public enum HealthKitContextRole: String, Equatable, Codable, Sendable {
  case optionalSupportingContext = "optional_supporting_context"
  case absent
}

public enum PhysiologyClaimBoundary: String, Equatable, Codable, Sendable {
  case contextOnlyNonDiagnostic = "context_only_non_diagnostic"
}

public struct PhysiologyContextSnapshot: Equatable, Codable, Sendable {
  public let id: PhysiologyContextID
  public let visitID: GymVisitID
  public let subjective: SubjectivePhysiologyCheckIn?
  public let healthKitSummary: HealthKitWorkoutSummary?
  public let primarySource: PhysiologyPrimarySource
  public let healthKitRole: HealthKitContextRole
  public let claimBoundary: PhysiologyClaimBoundary
  public let recordedAt: Instant

  public init(
    id: PhysiologyContextID,
    visitID: GymVisitID,
    subjective: SubjectivePhysiologyCheckIn?,
    healthKitSummary: HealthKitWorkoutSummary?,
    primarySource: PhysiologyPrimarySource,
    healthKitRole: HealthKitContextRole,
    claimBoundary: PhysiologyClaimBoundary,
    recordedAt: Instant
  ) {
    self.id = id
    self.visitID = visitID
    self.subjective = subjective
    self.healthKitSummary = healthKitSummary
    self.primarySource = primarySource
    self.healthKitRole = healthKitRole
    self.claimBoundary = claimBoundary
    self.recordedAt = recordedAt
  }

  public var reportedSessionEffort1To10: Int? {
    subjective?.sessionEffort1To10
  }

  public var reportedWholeBodyFatigue0To10: Int? {
    subjective?.wholeBodyFatigue0To10
  }

  public var reportedForearmPumpOverall: ForearmPumpLevel? {
    subjective?.forearmPumpOverall
  }
}

public enum PhysiologyContextRejection: Equatable, Sendable {
  case noContextProvided
  case sessionEffortOutOfRange
  case wholeBodyFatigueOutOfRange
  case invalidWorkoutDuration
  case invalidHeartRate
  case invalidHeartRateCoverage
  case invalidActiveEnergy
  case invalidWorkoutEffort
  case missingWorkoutEffortSource
  case emptyHealthKitSourceVersion
}

public enum PhysiologyContextBuildResult: Equatable, Sendable {
  case built(PhysiologyContextSnapshot)
  case rejected(PhysiologyContextRejection)

  public var isBuilt: Bool {
    if case .built = self {
      return true
    }
    return false
  }
}

public enum PhysiologyContextService {
  public static func build(
    contextID: PhysiologyContextID,
    visitID: GymVisitID,
    subjective: SubjectivePhysiologyCheckIn?,
    healthKitSummary: HealthKitWorkoutSummary?,
    recordedAt: Instant
  ) -> PhysiologyContextBuildResult {
    guard subjective != nil || healthKitSummary != nil else {
      return .rejected(.noContextProvided)
    }

    if let effort = subjective?.sessionEffort1To10, !(1...10).contains(effort) {
      return .rejected(.sessionEffortOutOfRange)
    }
    if let fatigue = subjective?.wholeBodyFatigue0To10, !(0...10).contains(fatigue) {
      return .rejected(.wholeBodyFatigueOutOfRange)
    }

    if let summary = healthKitSummary {
      guard summary.durationSeconds >= 0 else {
        return .rejected(.invalidWorkoutDuration)
      }
      if let average = summary.averageHeartRateBPM, average <= 0 {
        return .rejected(.invalidHeartRate)
      }
      if let maximum = summary.maximumHeartRateBPM, maximum <= 0 {
        return .rejected(.invalidHeartRate)
      }
      if let average = summary.averageHeartRateBPM,
        let maximum = summary.maximumHeartRateBPM,
        average > maximum
      {
        return .rejected(.invalidHeartRate)
      }
      if let coverage = summary.heartRateCoverage, !(0...1).contains(coverage) {
        return .rejected(.invalidHeartRateCoverage)
      }
      if let energy = summary.activeEnergyKilocalories, energy < 0 {
        return .rejected(.invalidActiveEnergy)
      }
      if let effort = summary.workoutEffortScore, !(1...10).contains(effort) {
        return .rejected(.invalidWorkoutEffort)
      }
      if summary.workoutEffortScore != nil && summary.workoutEffortSource == nil {
        return .rejected(.missingWorkoutEffortSource)
      }
      guard !summary.sourceVersion.isEmpty else {
        return .rejected(.emptyHealthKitSourceVersion)
      }
    }

    return .built(
      PhysiologyContextSnapshot(
        id: contextID,
        visitID: visitID,
        subjective: subjective,
        healthKitSummary: healthKitSummary,
        primarySource: subjective == nil ? .none : .subjectiveReport,
        healthKitRole: healthKitSummary == nil ? .absent : .optionalSupportingContext,
        claimBoundary: .contextOnlyNonDiagnostic,
        recordedAt: recordedAt
      )
    )
  }
}
