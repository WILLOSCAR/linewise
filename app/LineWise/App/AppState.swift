import Foundation
import SwiftUI

/// 首页筛选。
enum HomeFilter: String, CaseIterable, Identifiable {
    case projecting
    case today
    case sent
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projecting: "进行中"
        case .today: "今天"
        case .sent: "上了"
        case .all: "全部"
        }
    }
}

/// 轻量全局状态：当前岩馆、筛选、体型。持久化到 UserDefaults。
@Observable
final class AppState {
    private let defaults: UserDefaults

    var currentGymID: UUID? {
        didSet { defaults.set(currentGymID?.uuidString, forKey: "currentGymID") }
    }

    var filter: HomeFilter {
        didSet { defaults.set(filter.rawValue, forKey: "homeFilter") }
    }

    var bodyProfile: BodyProfile {
        didSet {
            if let data = try? JSONEncoder().encode(bodyProfile) { defaults.set(data, forKey: "bodyProfile") }
        }
    }

    var lastAreaName: String? {
        didSet { defaults.set(lastAreaName, forKey: "lastAreaName") }
    }

    var hasSeenIntro: Bool {
        didSet { defaults.set(hasSeenIntro, forKey: "hasSeenIntro") }
    }

    var hasSeenSharePrivacyHint: Bool {
        didSet { defaults.set(hasSeenSharePrivacyHint, forKey: "hasSeenSharePrivacyHint") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentGymID = defaults.string(forKey: "currentGymID").flatMap(UUID.init(uuidString:))
        filter = defaults.string(forKey: "homeFilter").flatMap(HomeFilter.init(rawValue:)) ?? .projecting
        bodyProfile = defaults.data(forKey: "bodyProfile").flatMap { try? JSONDecoder().decode(BodyProfile.self, from: $0) } ?? .default
        lastAreaName = defaults.string(forKey: "lastAreaName")
        hasSeenIntro = defaults.bool(forKey: "hasSeenIntro")
        hasSeenSharePrivacyHint = defaults.bool(forKey: "hasSeenSharePrivacyHint")
    }
}
