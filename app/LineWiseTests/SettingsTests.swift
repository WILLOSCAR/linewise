import Foundation
import Testing
@testable import LineWise

@Suite("设置 · 建线时长统计")
struct BuildDurationStatsTests {
    @Test("空数据")
    func empty() {
        let s = BuildDurationStats(samples: [])
        #expect(s.isEmpty)
        #expect(s.count == 0)
        #expect(s.median == nil)
        #expect(s.p90 == nil)
    }

    @Test("中位数：奇数取中间，偶数取平均")
    func median() {
        #expect(BuildDurationStats(samples: [30, 10, 20]).median == 20)
        #expect(BuildDurationStats(samples: [10, 20, 30, 40]).median == 25)
        #expect(BuildDurationStats(samples: [7]).median == 7)
    }

    @Test("P90 最近秩法")
    func p90() {
        let ten = BuildDurationStats(samples: Array(stride(from: 1.0, through: 10.0, by: 1)))
        #expect(ten.p90 == 9)
        #expect(ten.percentile(1.0) == 10)
        #expect(ten.percentile(0.0) == 1)
        #expect(BuildDurationStats(samples: [12]).p90 == 12)
        #expect(BuildDurationStats(samples: [5, 1, 3]).p90 == 5)
    }

    @Test("过滤非法值")
    func filtersInvalid() {
        let s = BuildDurationStats(samples: [12, -1, .nan, .infinity, 8])
        #expect(s.samples == [12, 8])
    }

    @Test("从 UserDefaults 读取")
    func loadsFromDefaults() throws {
        let suite = "BuildDurationStatsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(BuildDurationStats.load(from: defaults).isEmpty)
        defaults.set([12.0, 18.5, 9.2], forKey: BuildDurationStats.defaultsKey)
        let s = BuildDurationStats.load(from: defaults)
        #expect(s.count == 3)
        #expect(s.median == 12.0)
    }

    @Test("秒数显示")
    func format() {
        #expect(BuildDurationStats.format(seconds: 9.24) == "9.2 秒")
        #expect(BuildDurationStats.format(seconds: 14.6) == "15 秒")
        #expect(BuildDurationStats.format(seconds: 75) == "1 分 15 秒")
    }
}

@Suite("设置 · 删除全部确认")
struct DeleteAllConfirmationTests {
    @Test("只有输入「删除」才允许")
    func keyword() {
        #expect(DataSettingsSection.isDeleteConfirmed("删除"))
        #expect(DataSettingsSection.isDeleteConfirmed(" 删除 "))
        #expect(!DataSettingsSection.isDeleteConfirmed(""))
        #expect(!DataSettingsSection.isDeleteConfirmed("删"))
        #expect(!DataSettingsSection.isDeleteConfirmed("删除全部"))
    }
}

@Suite("设置 · 关于")
struct AboutTests {
    @Test("版本号非空")
    func version() {
        #expect(!AboutSettingsSection.versionText.isEmpty)
    }
}
