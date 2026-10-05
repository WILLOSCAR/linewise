import Foundation
import SwiftData
import UIKit

extension Store {
    /// 当前岩馆里有照片的墙，最近拍的在前。
    func wallsWithPhoto(in gym: Gym) -> [Wall] {
        gym.walls.filter(\.hasPhoto).sorted { $0.shotAt > $1.shotAt }
    }

    /// 岩馆里用过的墙区名（去重，最近用的在前）。
    func areaNames(in gym: Gym) -> [String] {
        var seen: Set<String> = []
        return gym.walls
            .sorted { $0.shotAt > $1.shotAt }
            .compactMap { $0.areaName?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// 把建线草稿写进库：需要时新建 Wall，再建 Line。
    @MainActor
    func commitBuild(_ model: BuilderModel, gym: Gym, name: String? = nil) throws -> Line {
        let area = model.areaName.trimmingCharacters(in: .whitespaces)
        let wall: Wall
        if let existing = model.existingWall {
            wall = existing
            // 用户在点亮屏改了墙区 / 角度，就顺手同步到这面墙
            if !area.isEmpty, wall.areaName != area { wall.areaName = area }
            if model.angle != .unknown, wall.angle != model.angle { wall.angle = model.angle }
        } else {
            wall = try createWall(gym: gym, image: model.image, areaName: area.isEmpty ? nil : area, angle: model.angle)
        }
        if let version = model.draft.holds.compactMap(\.segmentationVersion).first { wall.segmentationVersion = version }
        let grade = model.gradeText.trimmingCharacters(in: .whitespaces)
        return createLine(
            wall: wall,
            holds: model.draft.holds,
            startHoldIDs: model.draft.startHoldIDs,
            finishHoldID: model.draft.finishHoldID,
            gradeText: grade.isEmpty ? nil : grade,
            gradeSource: grade.isEmpty ? nil : model.gradeSource,
            name: name
        )
    }
}
