import Foundation
import SwiftData
import Testing
@testable import LineWise

@MainActor
@Suite("Demo A · 持久数据迁移", .serialized)
struct SchemaMigrationTests {
    @Test("未版本化旧库升级后保留记录、UUID 引用和顺序")
    func unversionedStoreToV2() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let gymID = UUID(), wallID = UUID(), lineID = UUID(), reminderID = UUID(), answerID = UUID()
        let low = Hold(x: 0.3, y: 0.8), high = Hold(x: 0.5, y: 0.2)
        // This is the exact pre-contour JSON shape, not today's Hold encoder.
        let oldHolds = Data("[{\"id\":\"\(low.id)\",\"x\":0.3,\"y\":0.8,\"r\":0.04},{\"id\":\"\(high.id)\",\"x\":0.5,\"y\":0.2,\"r\":0.04}]".utf8)
        let plan = ClimbSequence(steps: [.init(limb: .leftHand, holdID: high.id)])
        let actual = ClimbSequence(steps: [.init(limb: .rightHand, holdID: high.id)])
        let planData = try JSONEncoder().encode(plan), actualData = try JSONEncoder().encode(actual)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        try autoreleasepool {
            let schema = Schema(LineWiseSchemaV1.models)
            let config = ModelConfiguration("LineWise", schema: schema, url: url, cloudKitDatabase: .none)
            let legacy = try ModelContainer(for: schema, configurations: [config])
            let context = legacy.mainContext
            let gym = LineWiseSchemaV1.Gym(id: gymID, name: "迁移测试馆", createdAt: date)
            let wall = LineWiseSchemaV1.Wall(id: wallID, gym: gym, photoFileName: "synthetic.jpg",
                                            imageWidth: 1200, imageHeight: 1600, areaName: "旧墙", shotAt: date)
            let line = LineWiseSchemaV1.Line(id: lineID, wall: wall, holdsData: oldHolds,
                                            startHoldIDs: [low.id], finishHoldID: high.id, name: "旧线", createdAt: date)
            let reminder = LineWiseSchemaV1.Session(id: reminderID, line: line, date: date, cycle: 1, source: .after)
            reminder.fallHoldID = low.id; reminder.reasonRaw = FailReason.feet.rawValue; reminder.note = "右脚先踩高"
            let answer = LineWiseSchemaV1.Session(id: answerID, line: line, date: date.addingTimeInterval(86400),
                                                cycle: 1, source: .inGym)
            answer.attemptCount = 3; answer.fallHoldID = high.id; answer.fallStepIndex = 0
            answer.checkRaw = ReminderCheck.worked.rawValue; answer.reminderSnapshot = "掉在 ① · 脚 · 右脚先踩高"
            line.reminderText = answer.reminderSnapshot; line.reminderSessionID = reminderID; line.reminderVerified = true
            line.planSequenceData = planData; line.actualSequenceData = actualData
            context.insert(gym); context.insert(wall); context.insert(line); context.insert(reminder); context.insert(answer)
            try context.save()
        }

        let upgraded = try LineWisePersistence.container(url: url)
        let context = upgraded.mainContext
        let gyms = try context.fetch(FetchDescriptor<Gym>()), walls = try context.fetch(FetchDescriptor<Wall>())
        let lines = try context.fetch(FetchDescriptor<Line>()), sessions = try context.fetch(FetchDescriptor<Session>())
        let line = try #require(lines.first)
        #expect(gyms.count == 1 && gyms.first?.id == gymID)
        #expect(walls.count == 1 && walls.first?.id == wallID && walls.first?.gym?.id == gymID)
        #expect(line.id == lineID && line.wall?.id == wallID)
        #expect(line.holdsData == oldHolds && line.holds.map(\.id) == [low.id, high.id])
        #expect(line.holds.allSatisfy { $0.polygon == nil && $0.anchor == nil })
        #expect(line.startHoldIDs == [low.id] && line.finishHoldID == high.id)
        #expect(line.reminderVerified && line.reminderSessionID == reminderID)
        #expect(line.planSequenceData == planData && line.actualSequenceData == actualData)
        #expect(line.planSequence == plan && line.actualSequence == actual)
        let answer = try #require(sessions.first { $0.id == answerID })
        #expect(sessions.count == 2 && line.sessions.count == 2 && gyms[0].walls.count == 1)
        #expect(answer.line?.id == lineID && answer.attemptCount == 3 && answer.fallHoldID == high.id)
        #expect(answer.check == .worked && answer.reminderSnapshot == "掉在 ① · 脚 · 右脚先踩高")
        #expect(walls[0].segmentationVersion == nil)
    }

    @Test("打不开的持久库抛出错误，不创建假空库")
    func invalidStoreFailsExplicitly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("broken.store"), bytes = Data("not a SQLite store".utf8)
        try bytes.write(to: url)
        do {
            _ = try LineWisePersistence.container(url: url)
            Issue.record("An invalid store must not turn into an empty in-memory container")
        } catch {
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
}
