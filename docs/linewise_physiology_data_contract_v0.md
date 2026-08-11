# LineWise 生理与训练负荷数据契约 v0

Date: 2026-08-11

Status: Draft for P0 requirements settlement

Scope: HealthKit, Apple Watch sensor context, subjective fatigue/pump, derived summaries, Research Mode

## 1. 目的

这份契约回答四个问题：

1. LineWise 可以读取、产生和保留哪些生理或负荷数据？
2. 哪些数据能帮助用户回顾疲劳与前臂泵感，哪些不能？
3. 数据如何授权、留存、删除、导出和追溯？
4. 产品可以说什么，绝对不能说什么？

核心边界：

> LineWise 可以保存用户对疲劳和前臂泵感的主观记录，并用 Workout、心率、休息和 Attempt 提供训练负荷背景；Apple Watch 本身不能被 LineWise 当作前臂肌电或握力仪器，也不能据此给出医疗、安全或精确恢复结论。

## 2. 决策标签与规范用语

| 标签 | 含义 |
| --- | --- |
| **产品事实** | 已由当前领域文档、平台契约或 Apple 当前公开能力支持 |
| **建议默认值** | 首版推荐的数据与保留策略；可通过验证调整 |
| **待验证假设** | 可做低风险实验，但不能对用户写成已证实能力 |
| **禁止** | 不进入实验性用户文案；改变前需新的证据、合规和产品决定 |

文中 `raw` 指未经 LineWise 聚合的样本或传感器序列；`derived` 指由一个明确版本的转换产生的摘要；`user_reported` 指用户主动输入，不能被传感器覆盖。

## 3. 产品原则

| 原则 | 状态 | 约束 |
| --- | --- | --- |
| 攀岩语义是 App 私有事实，健康样本只是背景 | 产品事实 | HealthKit 不产生 RouteCard、Attempt、Send、FailureEpisode |
| HealthKit 完全可选 | 产品事实 | 拒绝、部分授权或后续撤销都不阻塞手工闭环 |
| 疲劳以主观记录为主语 | 建议默认值 | 文案说“你报告的疲劳”，不说“手表检测到疲劳” |
| 心率和 Workout 只提供负荷上下文 | 产品事实 | 不输出恢复、安全、伤病或停止训练结论 |
| 最小化复制原始健康数据 | 建议默认值 | 长期原始样本留在 HealthKit；App 保存必要摘要和 provenance |
| 高频 motion 仅 Research Mode | 建议默认值 | 单独说明、单独同意、短期保留、随时退出 |
| 所有派生值都可追溯和重算 | 建议默认值 | 保存输入来源、覆盖率、算法/规则版本和单位 |
| 缺失数据保持缺失 | 产品事实 | 不用 0、平均值或模型猜测填充 |
| 不向通用分析、广告或第三方 AI 发送健康/运动原始值 | 产品事实 | 未来任何共享需重新明确说明并取得许可 |

## 4. Apple 当前能力边界

以下是截至 2026-08-11 重新核验的 Apple 一手资料事实；实现时仍需按目标 OS 与硬件做 availability check。

### 4.1 HealthKit 授权

- HealthKit 按数据类型分别请求读取和写入；用户可以只授权部分类型或之后更改权限。
- 为保护隐私，App 通常不能可靠区分“某读权限被拒绝”和“该类型没有可读样本”；有限时间窗授权可以单独识别。
- 因此 LineWise 的用户状态应写“心率数据不可用/覆盖不足”，而不是断言“你拒绝了心率权限”。
- 写入授权可以检查；失败时 App 的 GymVisit 仍必须保存。

来源：[Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[HKAuthorizationStatus](https://developer.apple.com/documentation/healthkit/hkauthorizationstatus)。

### 4.2 Workout 与心率

- 活跃 Workout session 允许 watchOS App 在后台持续运行并收集活动数据；结束后可保存为 HealthKit Workout。
- Apple Watch 在 Workout 期间持续测量心率，但读数可能缺失或受佩戴、皮肤灌注和动作模式影响；Apple 明确指出不规则动作通常比跑步/骑车等节律动作更难获得稳定光学心率。
- 因此攀岩中的平均/最大心率必须同时显示覆盖率或质量状态，不能把短暂尖峰直接解释为动作强度或疲劳。

来源：[Workouts and activity rings](https://developer.apple.com/documentation/healthkit/workouts-and-activity-rings)、[Monitor your heart rate with Apple Watch](https://support.apple.com/en-la/120277)、[Get the most accurate measurements using your Apple Watch](https://support.apple.com/en-ca/105002)。

### 4.3 Workout effort 与 Apple Training Load

- HealthKit 提供 `workoutEffortScore` 和 `estimatedWorkoutEffortScore`，并支持把 effort 样本与 Workout 关联。
- Apple 的系统 Training Load 比较最近 7 天的 Workout 强度和时长与此前 28 天，并把结果呈现为相对负荷区间。
- 这些能力可作为系统来源的 effort/负荷背景，不等于 LineWise 对抱石疲劳、前臂恢复或训练安全的测量。

来源：[HealthKit updates](https://developer.apple.com/documentation/updates/healthkit)、[workoutEffortScore](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore)、[Track your training load on Apple Watch](https://support.apple.com/en-ie/guide/watch/apde4c07a6cf/watchos)。

### 4.4 HRV

HealthKit 的 `heartRateVariabilitySDNN` 是离散的 SDNN 心率变异性样本，系统可由 Apple Watch 自动记录。它不是每场抱石必然存在的实时流，也不能单独证明恢复或疲劳。P0 不请求 HRV；若未来实验使用，必须独立 opt-in、显示时间与覆盖，并禁止从单样本下结论。

来源：[heartRateVariabilitySDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn)。

### 4.5 高频 motion

Apple 的 `CMBatchedSensorManager` 可在支持的 Apple Watch/OS 上采集高频加速度计和 device-motion 批次；Apple 公开的更新说明给出最高 800 Hz 加速度计和 200 Hz device motion 的能力。能力取决于硬件、系统、授权、Workout 状态和运行条件，不能视为所有设备都可用。

来源：[Core Motion updates](https://developer.apple.com/documentation/updates/coremotion)、[CMBatchedSensorManager](https://developer.apple.com/documentation/coremotion/cmbatchedsensormanager)。

### 4.6 没有前臂肌电或握力测量

Apple Watch 当前公开传感器包括心率、温度、加速度计、陀螺仪等，但没有前臂表面肌电（sEMG）或握力/指尖力传感器。由此得到的产品结论是：

- Watch motion 最多描述佩戴手腕的运动；
- 光学心率描述心血管信号，不是局部前臂肌肉激活；
- LineWise 不得把这些信号转换成“前臂肌肉疲劳百分比”“握力剩余值”或具体肌群分析；
- 若未来要研究局部肌肉或握力，需要明确的外部硬件、校准、独立数据与新的合规契约。

这是基于 Apple 当前公开传感器目录的**能力边界推断**，不是对未来硬件的永久断言。来源：[Apple Watch Series 11 Technical Specifications](https://www.apple.com/apple-watch-series-11/specs/)。

## 5. 数据分级

LineWise 将相关数据分成六类，存储、权限和文案不能混用。

| 类别 | 例子 | 事实所有者 | P0 | 敏感级别 |
| --- | --- | --- | --- | --- |
| A. 攀岩语义 | GymVisit、RouteCard、Attempt、RestInterval、Send | 用户/LineWise | 必须 | 私密行为数据 |
| B. 用户主观报告 | session effort、整体疲劳、前臂泵感 | 用户 | 可选但推荐 | 敏感健康/感受数据 |
| C. HealthKit 原始/系统记录 | Workout、HR samples、active energy、effort relationship | HealthKit 来源 | 可选 | 健康/健身数据 |
| D. 常规传感器证据 | 低频/常规 motion 片段、传感器可用性 | 设备 | P0 不长期保存 raw | 健身/设备数据 |
| E. 派生摘要 | HR coverage、avg/max HR、attempt/rest summary、load index | LineWise 算法 | 可选 | 敏感派生数据 |
| F. Research raw | 高频 accelerometer/device motion、标注窗口 | 设备 + 研究同意 | 仅 Research Mode | 高敏感研究数据 |

任何从 B-F 产生的特征仍按其最敏感输入处理；聚合并不自动变成非敏感数据。

## 6. P0 采集清单

### 6.1 默认请求范围

| 数据 | 读取 | 写入 | 默认 | 用途 | 明确不用来做什么 |
| --- | --- | --- | --- | --- | --- |
| `HKWorkout` | 只读本 App 相关/用户授权范围 | 写 Climbing/Other workout，按最终技术选择 | 用户主动选择“同时记录到健康”后请求 | 系统 Workout 记录、关联 GymVisit | 路线或结果判断 |
| Heart rate | 可选读取 | 由 Workout builder/system 管理相关样本 | P0 可选 | session 级 HR 背景与覆盖 | 疲劳、恢复、Send/Fail 判断 |
| Active energy | 可选读取 | 随 Workout 能力产生 | 默认不突出 | 系统生态上下文 | 精确卡路里或产品核心价值 |
| Workout effort | 可选读取 | P0 默认不代用户写入 | 目标 OS 支持时可显示来源 | 与用户 effort 并列参考 | 抱石疲劳真值 |
| HRV SDNN | 否 | 否 | P0 不请求 | 后续独立研究候选 | 恢复评分 |
| Blood oxygen / ECG / temperature / sleep | 否 | 否 | P0 禁止请求 | 无 P0 必要性 | 任何训练建议或诊断 |
| Precise location | 否 | 否 | P0 不请求 | 无 | 自动到馆、安全追踪 |

HealthKit permission sheet 必须只包含当前功能实际使用的数据类型；不得为“以后可能有用”预请求。

### 6.2 App 私有生理记录

#### `SubjectiveCheckIn`

| 字段 | 类型 | 默认时机 | 说明 |
| --- | --- | --- | --- |
| `id` | UUID | 创建时 | 稳定标识 |
| `gym_visit_id` | UUID | 结束后 | 可关联某场 |
| `timing` | `pre_session` / `post_session` / `next_day` | P0 只启用 `post_session` | 防止混合不同时间的感受 |
| `session_effort_1_10` | optional integer | post-session | “这场整体有多费力？”；可与 Apple effort 并列但来源分开 |
| `whole_body_fatigue_0_10` | optional integer | post-session | “你现在整体有多疲劳？”；用户报告，不是传感器值 |
| `forearm_pump_overall_0_4` | optional enum | post-session | `none/light/moderate/strong/maximal` |
| `forearm_pump_left_0_4` | optional enum | P0.5 | 用户选择“分左右记录”后出现 |
| `forearm_pump_right_0_4` | optional enum | P0.5 | 同上 |
| `note` | optional text | iPhone review | 只用于用户自己的描述 |
| `created_at` | timestamp | 自动 | 原始记录时间 |
| `source` | `watch` / `iphone` / `import` | 自动 | provenance |

**建议默认值：** GymVisit 结束后最多问 `session_effort` 与 `forearm_pump_overall` 两项，均可跳过；整体疲劳放在 iPhone 回顾里，不阻塞结束。

**待验证假设：** 0-4 前臂泵感比 0-10 更容易在疲劳状态下快速回答，并且仍足以看个人趋势。alpha 应比较完成率、重测一致性和用户理解；未验证前不能称为标准量表。

### 6.3 `PhysiologySummary`

每个 GymVisit 最多有一个当前摘要；旧版本在重算日志中可追溯。

| 字段 | 来源 | 说明 |
| --- | --- | --- |
| `gym_visit_id` | LineWise | 关联 session |
| `duration_s` | GymVisit/HKWorkout | 同时保留选择了哪个来源 |
| `attempt_count` | Attempt | 用户确认 + 未决分开计数 |
| `rest_total_s` | RestInterval | 标注 exact/approximate/suggested |
| `heart_rate_coverage_ratio` | HR samples / session interval | 0-1；解释 avg/max 是否可展示 |
| `heart_rate_avg_bpm` | HR samples | 覆盖不足时为 null |
| `heart_rate_max_bpm` | HR samples | 覆盖不足时为 null；不解释峰值原因 |
| `workout_effort_score` | HealthKit | 保留 `perceived`/`estimated` 来源，若 API 可得 |
| `user_session_effort_1_10` | SubjectiveCheckIn | 与 HealthKit effort 不合并覆盖 |
| `reported_fatigue_0_10` | SubjectiveCheckIn | UI 必须带“你报告的” |
| `reported_forearm_pump` | SubjectiveCheckIn | 整体或左右 |
| `load_context` | derived | 见第 7 节，不叫 fatigue score |
| `quality_state` | derived | `complete` / `partial` / `unavailable` / `stale` |
| `provenance_id` | derived | 指向完整版本与输入清单 |

## 7. 疲劳与训练负荷产品语义

### 7.1 必须分开的三个概念

| 概念 | 用户问题 | 允许来源 | UI 名称 |
| --- | --- | --- | --- |
| 主观疲劳 | “我现在感觉多疲劳？” | 用户自评 | 你报告的疲劳 |
| 前臂泵感 | “我的前臂现在有多胀/泵？” | 用户自评，整体或左右 | 前臂泵感 |
| 训练负荷上下文 | “这场或这周做了多少、感觉多费力？” | 时长、Attempt、Rest、用户 effort、系统 effort | 训练负荷概览 / Load context |

它们不能合并成一个看似精确的“疲劳度 73”。

### 7.2 P0 展示

P0 review 可以展示：

```text
本次 92 分钟 · 18 次尝试 · 6 条路线
心率覆盖 72% · 平均 128 · 最高 167（仅供回顾）
你报告的用力 8/10 · 前臂泵感：强
```

如果 HR 覆盖不足：

```text
本次心率数据不足，攀岩记录不受影响。
```

不得展示：

```text
你已恢复 64%
前臂剩余力量 32%
再休息 3:20 即可安全尝试
今天受伤风险偏高
```

### 7.3 负荷摘要建议

首版只展示可解释的分量，不输出黑盒总分：

- 时长；
- Attempt 总数、已完成数、未决数；
- 总休息与中位休息（数据足够时）；
- 用户 session effort；
- HealthKit effort（若有，标明系统来源）；
- 过去 7 天与个人此前 28 天的上述分量对比，可选且必须使用“比你自己的近期基线”文案。

**待验证假设：** `session_minutes × user_session_effort` 可作为同一用户内部的简易 load index，帮助比较周趋势。若实验：

- 名称必须是“session load index”，无生理单位；
- 不跨用户比较，不映射到伤病或恢复建议；
- 缺少 user effort 时不插补；
- 需展示公式和算法版本；
- 先验证它是否比直接展示时长 + effort 更有理解价值，没有增益就删除。

LineWise 不复制或冒充 Apple Training Load。若展示 Apple 来源的 effort，只说明来源；系统 Training Load 的具体呈现和可访问范围以当前 OS/API 为准。

## 8. Research Mode：高频 motion

### 8.1 进入条件

Research Mode 默认关闭，并与普通 Workout/HealthKit 授权分开。开启前必须显示：

- 收集哪些信号（accelerometer/device motion）、可能频率和设备要求；
- 目的（例如验证 Attempt/Rest 候选分段），不是肌肉或握力分析；
- 预计电量和存储影响；
- 原始数据保留多久、在哪里；
- 是否会导出/上传、接收方和用途；
- 如何暂停、退出和删除历史数据。

如果研究被视为人体受试研究或向外部研究方共享，必须在功能上线前另行完成适用的伦理、法律与同意审查；普通产品 opt-in 不能替代研究同意。

### 8.2 采集契约

| 项目 | 建议默认值 |
| --- | --- |
| 启动 | 仅在用户明确开始 Research session 后 |
| 信号 | accelerometer + device motion；默认不额外采高频心率 |
| 频率 | 按设备支持和研究问题选择；记录实际频率，不把请求频率当实际频率 |
| 时间 | 只覆盖 active GymVisit；结束即停止 |
| 标注 | 与用户 Attempt/Undo/route binding 用稳定 event ID 关联 |
| 本地缓存 | Watch 加密 app container；成功传输并校验后清理 Watch 副本 |
| 电量降级 | 低电量、过热、空间不足时先停止 raw 采集，保留手工事件 |
| 数据质量 | 记录缺包、时间漂移、佩戴侧、设备/OS、实际 sample count |

### 8.3 允许的研究问题

- motion 是否能**建议**一个待确认的 Attempt/Rest 时间段；
- motion 候选能否降低漏记或回顾成本；
- 哪些动作/场景产生误报，例如拍粉、刷点、喝水、走动；
- 用户纠正是否足够形成可复现的个人模型评价集。

### 8.4 禁止的研究输出

- 前臂肌肉激活、肌肉疲劳百分比或具体肌群诊断；
- 握力、指尖力、肌腱负荷、关节负荷；
- 自动 Send/Fail 真值；
- 伤病风险、安全状态、恢复时间或继续训练建议；
- 未经单独同意把 raw motion 与身份、照片、视频或第三方 AI 组合。

## 9. 留存策略

以下时间都是**建议默认值**，上线前需结合目标市场法律、App Review、存储成本和实测调优。用户主动删除始终优先。

| 数据 | 主存储 | 默认留存 | 备份/同步 | 删除行为 |
| --- | --- | --- | --- | --- |
| GymVisit/RouteCard/Attempt 等语义 | LineWise 本地库 | 直到用户删除 | P0 不要求云；敏感字段不进通用分析 | 级联删除或按用户选择保留 RouteCard |
| SubjectiveCheckIn | LineWise 本地库 | 随 GymVisit，直到删除 | 不进通用 iCloud/CloudKit 健康备份 | 删除 GymVisit 时默认一起删 |
| 原始 HKWorkout/HR/energy/effort | HealthKit | 由用户和 HealthKit 管理 | LineWise 不长期复制样本流 | 用户可在 Health 删除；App 只可删自己写入对象且需授权 |
| HealthKit 查询缓存 | 内存/临时受保护文件 | 最长 24 小时 | 不备份 | 自动过期；权限撤销后清理 |
| PhysiologySummary | LineWise 本地库 | 随 GymVisit | 不进入广告/通用分析；未来账号同步需新契约 | 源删除或权限撤销后标 stale 并重算/删除 |
| Research raw motion（Watch） | Watch 受保护文件 | 传输校验后立即删；失败最多 24 小时 | 仅配对 iPhone | 到期自动删，保留删除审计不保留值 |
| Research raw motion（iPhone） | iPhone 受保护文件 | 7 天 rolling | 默认不备份、不上传 | 自动删除或用户立即删除 |
| Research derived features | LineWise 本地库 | 90 天或研究结束，取较早者 | 默认不上传 | raw 删除后可保留但仍按敏感数据处理；用户可一并删 |
| 诊断日志 | 本地 | 14 天 | 用户主动导出 | 默认不含 HR 值、主观评分和 raw motion |
| 用户导出文件 | 用户选择的位置 | 由用户控制 | 由目标位置决定 | App 只能删除自己仍有权限访问的副本 |

Apple 的 App Review Guidelines 要求隐私政策说明收集、用途、留存/删除和撤回同意；健康/健身数据不得用于广告、营销或不当数据挖掘，且不得把个人健康信息存入 iCloud。LineWise 因此必须把含健康信息的本地文件排除出普通 iCloud backup/CloudKit 路径，并在未来设计任何账号云同步前做独立审查。参见 [App Review Guidelines 5.1.1-5.1.3](https://developer.apple.com/app-store/review/guidelines/)。

## 10. 删除、撤销权限与重算

### 10.1 删除一场 GymVisit

默认确认页分开两个动作：

1. “删除 LineWise 中的本次记录”：删除 Attempt、RestInterval、SubjectiveCheckIn、PhysiologySummary、Research raw/derived 与相关 provenance；RouteCard 是否保留由用户选择。
2. “同时删除 LineWise 写入健康的 Workout”：仅在可识别为本 App 写入且仍有写入权限时提供；失败时说明可去健康 App 删除。

Apple 规定 App 只能删除自己此前写入 HealthKit 的对象；用户可以在健康 App 删除任何相关数据。参见 [delete(_:withCompletion:)](https://developer.apple.com/documentation/healthkit/hkhealthstore/delete%28_%3Awithcompletion%3A%29-78l1m)。

### 10.2 删除全部 LineWise 数据

- 可在 App 内完成，不要求发邮件；
- 先显示将删除的类别、设备位置和 HealthKit 例外；
- 本地删除必须覆盖 Watch 队列、iPhone 库、缓存、Research 文件和 tombstone 生命周期；
- 若未来有账号/服务器，删除流程必须覆盖服务端副本和备份保留说明；P0 不假装已有云删除能力。

### 10.3 撤销 HealthKit

- 不删除用户的 RouteCard、Attempt 或主观记录；
- 用户在 LineWise 内选择“断开健康数据”时，立即停止新查询/写入并清理短期查询缓存；
- 用户从系统设置撤销时，写入授权可检查或返回错误，读取侧却可能只表现为无可读样本；LineWise 在获知不可用后停止相关增强，但不能声称精确检测到了哪项读取撤销；
- 已保存的派生摘要保留时标记 `stale_due_to_permission_change`，给用户“保留摘要”或“删除健康摘要”选择；
- 不循环弹窗要求重新授权；仅在用户主动打开相关卡片时解释增强不可用；
- 因 HealthKit 隐私设计，LineWise 不能把所有“无可读数据”准确归因为撤销。

### 10.4 源数据删除与派生数据

- HealthKit 样本被删除时，相关摘要应在下一次查询时失效并重算；HealthKit 支持通过 anchored/observer query 感知新增和删除对象。
- 如果无法重算，摘要保留值但显示 stale 是不够的；默认应隐藏数值并说明来源已不可用。
- 用户修改主观评分时，新摘要引用新版本，旧值只保留在最小纠正审计中，不用于趋势。

来源：[About the HealthKit framework](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)、[HKDeletedObject](https://developer.apple.com/documentation/healthkit/hkdeletedobject)。

## 11. 导出契约

用户可导出自己的数据，默认包结构：

```text
linewise-export-YYYYMMDD/
  manifest.json
  gym_visits.jsonl
  route_cards.jsonl
  attempts.jsonl
  subjective_checkins.jsonl
  physiology_summaries.jsonl
  provenance.jsonl
  README.txt
```

规则：

- `manifest.json` 包含 export time、app/schema version、locale、时区和包含的数据类别。
- 所有数值带单位；null 与 0 分开。
- HealthKit raw sample 流默认不复制进导出；如未来支持，必须单独勾选、说明体积和敏感性。
- Research raw motion 不在普通导出中；单独导出时附实际采样率、轴、设备、缺包和 consent version。
- 导出前可预览类别和预计大小；分享后目标 App/位置的副本不再由 LineWise 控制。
- 调试导出默认去除健康值和用户文本，只保留 event ID、状态、版本和错误码；用户可明确选择完整数据。

## 12. Provenance 与版本

### 12.1 每个派生摘要的最小 provenance

| 字段 | 说明 |
| --- | --- |
| `provenance_id` | 稳定 ID |
| `output_object_id` | PhysiologySummary 或 feature ID |
| `source_kinds` | HealthKit / user_reported / watch_motion / climbing_semantics |
| `source_record_refs` | HK UUID 哈希/内部对象 ID；不在普通日志打印原始 UUID |
| `source_start_at`, `source_end_at` | 输入时间范围 |
| `source_device` | Watch model family、OS；只保留必要粒度 |
| `app_version`, `schema_version` | 生成环境 |
| `algorithm_name`, `algorithm_version` | 明确的转换版本 |
| `parameters` | 阈值、窗口、单位和质量门槛 |
| `coverage` | 实际样本覆盖、缺失、丢包 |
| `generated_at` | 生成时间 |
| `confirmation_state` | system_recorded / user_reported / suggested / user_corrected |
| `consent_version` | Research/共享相关时必填 |

### 12.2 版本规则

- schema 和算法版本分开；修改字段不等于修改算法。
- 同一输入 + 同一算法版本必须产生可复现结果，或记录不可复现原因。
- 模型/规则升级不得静默改写历史；先生成新摘要，比较后切换 current pointer。
- UI 必须能回答“这个数来自哪里、什么时候、覆盖多少、哪个版本”。
- 用户纠正是独立事实，不因重算丢失。

## 13. 数据共享与第三方

P0：

- 不把 HealthKit、SubjectiveCheckIn、PhysiologySummary 或 raw motion 发给广告、通用分析、崩溃附件或云端 AI。
- 产品分析只记录不含健康值的功能事件，例如“用户是否完成 check-in”，不记录分数本身。
- 不以“匿名/聚合”为理由把健康数据用于用户画像或广告。
- 照片/视频与生理数据默认不拼接上传。

未来若引入第三方 AI、教练分享或研究合作：

- 在发送前逐次或按清晰范围说明接收方、字段、目的、保留和删除；
- 获取可撤销的明确许可；默认关闭；
- 健康数据不能作为使用通用 AI 的隐形上下文；
- 第三方必须提供至少同等保护，并接受删除/撤销路径；
- 新用途不得沿用旧同意。

Apple 当前明确要求在与第三方（包括第三方 AI）共享个人数据前清楚披露并取得明确许可；健康/健身数据另受 5.1.3 的更严格限制。来源：[App Review Guidelines 5.1.2-5.1.3](https://developer.apple.com/app-store/review/guidelines/)。

### 13.1 中国区分发边界

若向中国境内自然人提供产品或分析其行为，本契约还必须进入中国区法律评审。根据《中华人民共和国个人信息保护法》当前官方文本：

- 医疗健康属于敏感个人信息；只有特定目的、充分必要并采取严格保护措施时方可处理（第二十八条）；
- 基于同意处理敏感个人信息通常需要单独同意，并应额外告知必要性及对个人权益的影响（第二十九、三十条）；
- 保存期限应为实现目的所必要的最短时间（第十九条）；
- 向境外提供个人信息有单独的条件与告知/同意要求，不能把第三方 AI 或账号同步视作普通传输（第三十八条及相关条款）；
- 撤回同意、目的完成或保存期限届满等情形需要进入删除流程（第四十七条）。

因此 SubjectiveCheckIn、PhysiologySummary、HealthKit 派生值和 Research raw 不能只依赖一份笼统隐私政策。中国区上线前必须由合格人员确认处理依据、单独同意、最短留存、受托方、跨境、删除和未成年人路径。本段是产品合规需求，不是法律意见。

官方来源：[中华人民共和国个人信息保护法（中国人大网）](https://www.npc.gov.cn/npc/c2/c30834/202108/t20210820_313088.html)。

## 14. 允许与禁止的产品文案

### 14.1 允许

- “你报告本次用力 8/10。”
- “你报告的前臂泵感：强。”
- “本次心率覆盖 72%，仅供训练回顾。”
- “过去 7 天记录的训练时长高于你此前 28 天的个人基线。”
- “手腕 motion 建议这里可能有一次尝试，请确认。”
- “数据不足，暂不显示心率摘要。”

### 14.2 禁止

- “Watch 检测到你的前臂疲劳 73%。”
- “你的握力还剩 32 kg / 40%。”
- “左侧屈指肌已过度使用。”
- “你已恢复，可以安全再试。”
- “继续训练的受伤概率为 12%。”
- “根据 HRV，今天不适合攀岩。”
- “这个休息时间能预防肌腱损伤。”
- “本产品可诊断过度训练、拉伤或心血管异常。”

### 14.3 固定说明

设置与生理卡片附近应提供可访问说明：

> LineWise 不是医疗设备，也不是安全或紧急服务。生理与负荷信息只用于个人训练记录和回顾，可能不完整或不准确，不能替代教练、医务人员或岩馆工作人员的判断。

## 15. 质量状态与 UI

| 状态 | 判定 | UI 行为 |
| --- | --- | --- |
| `complete` | 覆盖和来源满足该摘要的门槛 | 显示值 + 来源 |
| `partial` | 可展示但有明显缺失 | 显示值 + 覆盖百分比/缺失说明 |
| `unavailable` | 无权限、无能力或无样本，且无法区分 | 不归因，保留手工记录入口 |
| `stale` | 源数据/权限/算法已变化，未完成重算 | 隐藏旧结论，提示刷新 |
| `suggested` | motion/模型候选 | 必须确认、编辑或拒绝 |
| `user_reported` | 用户主动输入 | 永远标明主观来源 |

建议默认质量门槛：HR 覆盖低于 session 时长的 50% 时不显示 avg/max，只显示“覆盖不足”；50%-80% 显示 partial；>=80% 可显示 complete。此阈值是**待验证假设**，必须用真机攀岩数据检查采样间隔、缺失模式和误导风险。

## 16. 验收与停止条件

### 16.1 P0 验收

1. 拒绝全部 HealthKit 权限仍能完成 GymVisit 到 NextSessionCue。
2. 只授权 Workout、不授权 HR 时不显示错误结论，也不反复请求。
3. HealthKit 写入失败时 App session 已保存且可重试。
4. HR 缺失、间断、尖峰和删除都产生正确 quality state。
5. 用户主观评分可跳过、编辑、删除和导出。
6. 删除 GymVisit 会清理相关摘要、缓存和 Research 数据，不留下可继续展示的派生值。
7. 权限撤销后停止查询/写入，不删除攀岩语义，不循环 nag。
8. 普通分析和崩溃日志中没有 HR、effort、fatigue、pump 或 motion raw。
9. 所有摘要可追到 source、coverage、algorithm version 和单位。
10. 中英文文案都使用“报告/上下文/建议”，不使用检测、恢复、安全或诊断措辞。

### 16.2 Research Mode 验收

- 明确 opt-in 与退出；
- 实际频率、缺包、电量和存储均有记录；
- 手机不在时 raw 有上限且不影响手工事件；
- 7 天到期自动删除可被测试证明；
- 用户删除后 Watch 与 iPhone 副本都不可恢复进入产品；
- 候选 Attempt 只以 `suggested` 进入回顾；
- 误报按场景分类，未达到降低回顾成本的门槛就停止采集。

### 16.3 停止条件

停止某项生理/传感器功能，如果：

- 用户把它理解为医疗、安全或恢复建议；
- 为获得数据而增加的权限/问卷使手工闭环完成率显著下降；
- raw motion 的电量或存储影响破坏 GymVisit 可靠记录；
- 派生分数不能比原始可解释分量提供更清楚的决策价值；
- 无法提供删除、导出、provenance 或权限撤销路径；
- 数据需要进入第三方服务，但产品无法取得明确、具体、可撤销的同意。

## 17. 进入实现前必须结清

| 决策 | 当前建议 | 需要的证据/评审 |
| --- | --- | --- |
| P0 是否请求 heart rate read | 只在用户开启健康回顾时请求 | 真机可用性、用户价值、权限摩擦 |
| Workout activity type 与 effort 支持范围 | 技术 spike 后定 | 目标 watchOS/iOS API 和真机保存验证 |
| 主观疲劳/泵感量表 | effort 1-10，pump 0-4，可跳过 | 理解度、完成率、重测一致性 |
| HR coverage 门槛 | 50%/80% 暂定 | 真实抱石采样缺失分布 |
| 简易 load index | 不进默认 P0，仅做可解释实验 | 相对直接分量是否增加价值 |
| Research raw motion 留存 | Watch <=24h，iPhone 7 天 | 电量、传输、存储、合规和用户接受度 |
| 本地备份 | 健康/派生/Research 文件排除 iCloud | App Review 与目标市场法律评审 |
| 账号/云同步 | P0 不做 | 单独数据处理、删除和跨境契约 |

## 18. 相关文档与官方来源

项目文档：

- `CONTEXT.md`
- `docs/climbing_bouldering_platform_contract.md`
- `docs/climbing_bouldering_prd_v0_1.md`
- `docs/climbing_bouldering_data_collection_plan.md`
- `docs/linewise_end_to_end_experience_contract_v0.md`

Apple 官方来源：

- [HealthKit](https://developer.apple.com/documentation/healthkit)
- [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [HealthKit updates](https://developer.apple.com/documentation/updates/healthkit)
- [Core Motion updates](https://developer.apple.com/documentation/updates/coremotion)
- [CMBatchedSensorManager](https://developer.apple.com/documentation/coremotion/cmbatchedsensormanager)
- [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Watch Series 11 Technical Specifications](https://www.apple.com/apple-watch-series-11/specs/)
