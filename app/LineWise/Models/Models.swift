import Foundation
import SwiftData

// MARK: - Gym

@Model
final class Gym {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Wall.gym) var walls: [Wall]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.walls = []
    }
}

// MARK: - Wall

@Model
final class Wall {
    @Attribute(.unique) var id: UUID
    var gym: Gym?
    /// 本地照片文件名；无照片墙为 nil。
    var photoFileName: String?
    var imageWidth: Int
    var imageHeight: Int
    var areaName: String?
    var angleRaw: String
    var shotAt: Date
    var resetAt: Date?
    /// Model revision used for accepted hold contours; nil for legacy/manual walls.
    var segmentationVersion: String?
    @Relationship(deleteRule: .cascade, inverse: \Line.wall) var lines: [Line]

    init(id: UUID = UUID(), gym: Gym?, photoFileName: String?, imageWidth: Int, imageHeight: Int,
         areaName: String? = nil, angle: WallAngle = .unknown, shotAt: Date = .now) {
        self.id = id
        self.gym = gym
        self.photoFileName = photoFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.areaName = areaName
        self.angleRaw = angle.rawValue
        self.shotAt = shotAt
        self.lines = []
    }

    var angle: WallAngle {
        get { WallAngle(rawValue: angleRaw) ?? .unknown }
        set { angleRaw = newValue.rawValue }
    }

    var hasPhoto: Bool { photoFileName != nil }

    /// 宽高比（宽/高）；无照片按 3:4。
    var aspectRatio: Double {
        guard imageWidth > 0, imageHeight > 0 else { return 0.75 }
        return Double(imageWidth) / Double(imageHeight)
    }

    var displayArea: String { areaName?.isEmpty == false ? areaName! : "未命名墙区" }

    var activeLines: [Line] { lines.filter { $0.deletedAt == nil && $0.mergedIntoLineID == nil } }
}

// MARK: - Line

@Model
final class Line {
    @Attribute(.unique) var id: UUID
    var wall: Wall?
    var holdsData: Data
    var startHoldIDs: [UUID]
    var finishHoldID: UUID?
    var gradeText: String?
    var gradeSourceRaw: String?
    var feltGradeRaw: String?
    var statusRaw: String
    var cycle: Int
    var name: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var mergedIntoLineID: UUID?
    var reminderText: String?
    var reminderSessionID: UUID?
    var reminderVerified: Bool
    var planSequenceData: Data?
    var actualSequenceData: Data?
    @Relationship(deleteRule: .cascade, inverse: \Session.line) var sessions: [Session]

    init(id: UUID = UUID(), wall: Wall?, holds: [Hold], startHoldIDs: [UUID], finishHoldID: UUID?,
         gradeText: String? = nil, gradeSource: GradeSource? = nil, name: String, createdAt: Date = .now) {
        self.id = id
        self.wall = wall
        self.holdsData = (try? JSONEncoder().encode(holds)) ?? Data()
        self.startHoldIDs = startHoldIDs
        self.finishHoldID = finishHoldID
        self.gradeText = gradeText
        self.gradeSourceRaw = gradeSource?.rawValue
        self.statusRaw = LineStatus.projecting.rawValue
        self.cycle = 1
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.reminderVerified = false
        self.sessions = []
    }

    // MARK: 派生属性

    var holds: [Hold] {
        get { (try? JSONDecoder().decode([Hold].self, from: holdsData)) ?? [] }
        set { holdsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var status: LineStatus {
        get { LineStatus(rawValue: statusRaw) ?? .projecting }
        set { statusRaw = newValue.rawValue }
    }

    var gradeSource: GradeSource? {
        get { gradeSourceRaw.flatMap(GradeSource.init(rawValue:)) }
        set { gradeSourceRaw = newValue?.rawValue }
    }

    var feltGrade: FeltGrade? {
        get { feltGradeRaw.flatMap(FeltGrade.init(rawValue:)) }
        set { feltGradeRaw = newValue?.rawValue }
    }

    var planSequence: ClimbSequence? {
        get { planSequenceData.flatMap { try? JSONDecoder().decode(ClimbSequence.self, from: $0) } }
        set { planSequenceData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var actualSequence: ClimbSequence? {
        get { actualSequenceData.flatMap { try? JSONDecoder().decode(ClimbSequence.self, from: $0) } }
        set { actualSequenceData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var hasPhoto: Bool { wall?.hasPhoto == true && !holds.isEmpty }

    var holdNumbers: [UUID: Int] { HoldNumbering.numbers(for: holds) }

    func label(for holdID: UUID?) -> String? {
        guard let holdID, let n = holdNumbers[holdID] else { return nil }
        return HoldLabel.circled(n)
    }

    var isVisible: Bool { deletedAt == nil && mergedIntoLineID == nil }

    /// 有效记录（未删除），按日期升序。
    var orderedSessions: [Session] {
        sessions.sorted { a, b in a.date == b.date ? a.createdAt < b.createdAt : a.date < b.date }
    }

    var currentCycleSessions: [Session] { orderedSessions.filter { $0.cycle == cycle } }

    var latestSession: Session? { orderedSessions.last }

    var visitCount: Int { orderedSessions.count }

    var totalAttempts: Int { orderedSessions.reduce(0) { $0 + $1.attemptCount } }

    var gradeDisplay: String { gradeText?.isEmpty == false ? gradeText! : "难度？" }

    var subtitle: String {
        var parts: [String] = []
        if let area = wall?.areaName, !area.isEmpty { parts.append(area) }
        if let g = gradeText, !g.isEmpty { parts.append(g) }
        return parts.joined(separator: " · ")
    }

    /// 最近一次记了掉在哪、原因或上了的记录。
    var lastFallSession: Session? {
        orderedSessions.last(where: { $0.fallHoldID != nil || $0.fallText?.isEmpty == false || $0.reason != nil || $0.sent })
    }

    /// 最新一次“掉在哪 · 原因”的短句。
    var lastFallLine: String? {
        guard let s = lastFallSession else { return nil }
        if s.sent, s.fallHoldID == nil, s.fallText?.isEmpty != false { return "上次上了" }
        var parts: [String] = []
        if let l = label(for: s.fallHoldID) { parts.append("上次掉在 \(l)") }
        else if let t = s.fallText, !t.isEmpty { parts.append("上次掉在 \(t)") }
        if let r = s.reason { parts.append(r.title) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func digest() -> LineDigest {
        let numbers = holdNumbers
        let sessions = orderedSessions.map { s in
            SessionDigest(
                date: s.date, attemptCount: s.attemptCount, sent: s.sent,
                fallNumber: s.fallHoldID.flatMap { numbers[$0] },
                reason: s.reason, note: s.note, check: s.check, cycle: s.cycle
            )
        }
        // “没回答”只指提醒之后已经有新记录在等回答；刚由最新记录拼出的提醒还没机会被验证。
        return LineDigest(sessions: sessions, reminder: reminderText, reminderVerified: reminderVerified,
                          reminderAnswered: pendingCheckSession == nil, status: status, cycle: cycle)
    }

    /// 是否需要在线路页问“上次这句有用吗？”：有提醒，且提醒之后出现了新的记录尚未回答。
    var pendingCheckSession: Session? {
        guard let reminderText, !reminderText.isEmpty, let rid = reminderSessionID else { return nil }
        let ordered = orderedSessions
        guard let reminderIndex = ordered.firstIndex(where: { $0.id == rid }) else { return nil }
        return ordered.dropFirst(reminderIndex + 1).first(where: { $0.check == nil })
    }
}

// MARK: - Session

struct AttemptRecord: Codable, Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    var sent: Bool = false
    var fallHoldID: UUID?
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var line: Line?
    /// 用户选择的日期（本地零点）。
    var date: Date
    var attemptCount: Int
    var sent: Bool
    var fallHoldID: UUID?
    var fallStepIndex: Int?
    /// 无照片线的“掉在哪”文字版（有照片时为 nil，用 fallHoldID）。
    var fallText: String?
    var reasonRaw: String?
    var note: String?
    var checkRaw: String?
    var reminderSnapshot: String?
    var sourceRaw: String
    var cycle: Int
    var createdAt: Date
    var updatedAt: Date
    var attemptsData: Data?

    init(id: UUID = UUID(), line: Line?, date: Date, cycle: Int, source: SessionSource, createdAt: Date = .now) {
        self.id = id
        self.line = line
        self.date = Calendar.current.startOfDay(for: date)
        self.attemptCount = 0
        self.sent = false
        self.sourceRaw = source.rawValue
        self.cycle = cycle
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var reason: FailReason? {
        get { reasonRaw.flatMap(FailReason.init(rawValue:)) }
        set { reasonRaw = newValue?.rawValue }
    }

    var check: ReminderCheck? {
        get { checkRaw.flatMap(ReminderCheck.init(rawValue:)) }
        set { checkRaw = newValue?.rawValue }
    }

    var source: SessionSource {
        get { SessionSource(rawValue: sourceRaw) ?? .after }
        set { sourceRaw = newValue.rawValue }
    }

    var attempts: [AttemptRecord] {
        get { attemptsData.flatMap { try? JSONDecoder().decode([AttemptRecord].self, from: $0) } ?? [] }
        set { attemptsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }

    var hasContent: Bool {
        fallHoldID != nil || (fallText?.isEmpty == false) || reason != nil || (note?.isEmpty == false)
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }
}
