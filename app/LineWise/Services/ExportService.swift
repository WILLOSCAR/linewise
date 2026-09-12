import Foundation
import SwiftData

/// 导出：全量 JSON，或 JSON + 照片打成 zip。全部本地完成。
enum ExportService {
    struct Bundle: Codable {
        var exportedAt: Date
        var appVersion: String
        var schemaVersion: Int
        var gyms: [GymDTO]
    }

    struct GymDTO: Codable {
        var id: UUID
        var name: String
        var createdAt: Date
        var walls: [WallDTO]
    }

    struct WallDTO: Codable {
        var id: UUID
        var photoFileName: String?
        var imageWidth: Int
        var imageHeight: Int
        var areaName: String?
        var angle: String
        var shotAt: Date
        var resetAt: Date?
        var lines: [LineDTO]
    }

    struct LineDTO: Codable {
        var id: UUID
        var name: String
        var holds: [Hold]
        var startHoldIDs: [UUID]
        var finishHoldID: UUID?
        var gradeText: String?
        var gradeSource: String?
        var feltGrade: String?
        var status: String
        var cycle: Int
        var note: String?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
        var mergedIntoLineID: UUID?
        var reminderText: String?
        var reminderSessionID: UUID?
        var reminderVerified: Bool
        var planSequence: ClimbSequence?
        var actualSequence: ClimbSequence?
        var sessions: [SessionDTO]
    }

    struct SessionDTO: Codable {
        var id: UUID
        var date: Date
        var attemptCount: Int
        var sent: Bool
        var fallHoldID: UUID?
        var fallStepIndex: Int?
        var fallText: String?
        var reason: String?
        var note: String?
        var check: String?
        var source: String
        var cycle: Int
        var createdAt: Date
        var updatedAt: Date
        var attempts: [AttemptRecord]
    }

    static func makeBundle(gyms: [Gym]) -> Bundle {
        let version = (Foundation.Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        return Bundle(
            exportedAt: .now,
            appVersion: version,
            schemaVersion: 1,
            gyms: gyms.map { gym in
                GymDTO(id: gym.id, name: gym.name, createdAt: gym.createdAt, walls: gym.walls.map { wall in
                    WallDTO(
                        id: wall.id, photoFileName: wall.photoFileName, imageWidth: wall.imageWidth, imageHeight: wall.imageHeight,
                        areaName: wall.areaName, angle: wall.angleRaw, shotAt: wall.shotAt, resetAt: wall.resetAt,
                        lines: wall.lines.map { line in
                            LineDTO(
                                id: line.id, name: line.name, holds: line.holds, startHoldIDs: line.startHoldIDs,
                                finishHoldID: line.finishHoldID, gradeText: line.gradeText, gradeSource: line.gradeSourceRaw,
                                feltGrade: line.feltGradeRaw, status: line.statusRaw, cycle: line.cycle, note: line.note,
                                createdAt: line.createdAt, updatedAt: line.updatedAt, deletedAt: line.deletedAt,
                                mergedIntoLineID: line.mergedIntoLineID, reminderText: line.reminderText,
                                reminderSessionID: line.reminderSessionID, reminderVerified: line.reminderVerified,
                                planSequence: line.planSequence, actualSequence: line.actualSequence,
                                sessions: line.orderedSessions.map { s in
                                    SessionDTO(
                                        id: s.id, date: s.date, attemptCount: s.attemptCount, sent: s.sent,
                                        fallHoldID: s.fallHoldID, fallStepIndex: s.fallStepIndex, fallText: s.fallText, reason: s.reasonRaw,
                                        note: s.note, check: s.checkRaw, source: s.sourceRaw, cycle: s.cycle,
                                        createdAt: s.createdAt, updatedAt: s.updatedAt, attempts: s.attempts
                                    )
                                }
                            )
                        }
                    )
                })
            }
        )
    }

    private static func jsonData(_ bundle: Bundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: .now)
    }

    /// 只导出 JSON。
    static func exportJSON(gyms: [Gym]) throws -> URL {
        let data = try jsonData(makeBundle(gyms: gyms))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("linewise-\(stamp()).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 导出 JSON + 照片 zip（用系统文件协调器打包，无第三方依赖）。
    static func exportArchive(gyms: [Gym]) async throws -> URL {
        let data = try jsonData(makeBundle(gyms: gyms))
        let photoNames = gyms.flatMap { $0.walls.compactMap(\.photoFileName) }
        let stamp = stamp()
        return try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("linewise-\(stamp)", isDirectory: true)
            try? fm.removeItem(at: work)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            try data.write(to: work.appendingPathComponent("linewise.json"), options: .atomic)
            let photosDir = work.appendingPathComponent("photos", isDirectory: true)
            try fm.createDirectory(at: photosDir, withIntermediateDirectories: true)
            for name in photoNames {
                let src = ImageStore.url(for: name)
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: photosDir.appendingPathComponent(name))
                }
            }
            let zipURL = fm.temporaryDirectory.appendingPathComponent("linewise-\(stamp).zip")
            try? fm.removeItem(at: zipURL)
            var coordinatorError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: work, options: .forUploading, error: &coordinatorError) { tempZip in
                do {
                    try fm.copyItem(at: tempZip, to: zipURL)
                } catch {
                    copyError = error
                }
            }
            if let coordinatorError { throw coordinatorError }
            if let copyError { throw copyError }
            try? fm.removeItem(at: work)
            return zipURL
        }.value
    }
}
