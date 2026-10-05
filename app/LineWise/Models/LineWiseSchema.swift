import Foundation
import SwiftData

/// Frozen persistent layout of the unversioned app at 95a8522. Do not add fields here.
enum LineWiseSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Gym.self, Wall.self, Line.self, Session.self] }

    @Model final class Gym {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        @Relationship(deleteRule: .cascade, inverse: \Wall.gym) var walls: [Wall]

        init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
            self.id = id; self.name = name; self.createdAt = createdAt; self.walls = []
        }
    }

    @Model final class Wall {
        @Attribute(.unique) var id: UUID
        var gym: Gym?
        var photoFileName: String?
        var imageWidth: Int
        var imageHeight: Int
        var areaName: String?
        var angleRaw: String
        var shotAt: Date
        var resetAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \Line.wall) var lines: [Line]

        init(id: UUID = UUID(), gym: Gym?, photoFileName: String?, imageWidth: Int, imageHeight: Int,
             areaName: String? = nil, angle: WallAngle = .unknown, shotAt: Date = .now) {
            self.id = id; self.gym = gym; self.photoFileName = photoFileName
            self.imageWidth = imageWidth; self.imageHeight = imageHeight; self.areaName = areaName
            self.angleRaw = angle.rawValue; self.shotAt = shotAt; self.lines = []
        }
    }

    @Model final class Line {
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

        init(id: UUID = UUID(), wall: Wall?, holdsData: Data, startHoldIDs: [UUID], finishHoldID: UUID?,
             name: String, createdAt: Date = .now) {
            self.id = id; self.wall = wall; self.holdsData = holdsData
            self.startHoldIDs = startHoldIDs; self.finishHoldID = finishHoldID
            self.statusRaw = LineStatus.projecting.rawValue; self.cycle = 1; self.name = name
            self.createdAt = createdAt; self.updatedAt = createdAt; self.reminderVerified = false; self.sessions = []
        }
    }

    @Model final class Session {
        @Attribute(.unique) var id: UUID
        var line: Line?
        var date: Date
        var attemptCount: Int
        var sent: Bool
        var fallHoldID: UUID?
        var fallStepIndex: Int?
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
            self.id = id; self.line = line; self.date = Calendar.current.startOfDay(for: date)
            self.attemptCount = 0; self.sent = false; self.sourceRaw = source.rawValue
            self.cycle = cycle; self.createdAt = createdAt; self.updatedAt = createdAt
        }
    }
}

enum LineWiseSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Gym.self, Wall.self, Line.self, Session.self] }
}

enum LineWiseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LineWiseSchemaV1.self, LineWiseSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: LineWiseSchemaV1.self, toVersion: LineWiseSchemaV2.self)]
    }
}

enum LineWisePersistence {
    static var schema: Schema { Schema(versionedSchema: LineWiseSchemaV2.self) }

    static func container(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let current = schema
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration("LineWise", schema: current, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration("LineWise", schema: current, isStoredInMemoryOnly: inMemory,
                                        cloudKitDatabase: .none)
        }
        return try ModelContainer(for: current, migrationPlan: LineWiseMigrationPlan.self, configurations: [config])
    }
}
