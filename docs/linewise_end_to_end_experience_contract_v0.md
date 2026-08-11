# LineWise 端到端体验契约 v0

Date: 2026-08-11

Status: Active P0 experience contract; recommendations and timing thresholds remain field-testable

Scope: Indoor bouldering, iPhone + optional Apple Watch

## 1. 目的

这份契约把 LineWise 的 P0 从功能清单整理为一条可恢复、可降级、可验证的真实到馆体验：

```text
首次使用
-> 到馆 / 恢复上次项目
-> 创建或选择 RouteCard
-> 低干扰记录 Attempt 与 RestInterval
-> 离馆并可靠保存
-> 待整理 Inbox
-> 批量回顾
-> 生成 NextSessionCue
-> 下次到馆重新使用
```

它不替代主 PRD、平台契约或 ADR。发生冲突时，以最新已接受 ADR 和其指向的规范契约为当前事实；本文件会显式登记尚未迁移的旧文档，不静默混用两套语义。

## 2. 决策标签

| 标签 | 含义 | 如何使用 |
| --- | --- | --- |
| **产品事实** | 已由 `CONTEXT.md`、现行 ADR 或活跃 PRD 确立 | 实现不得自行改变；改变前先更新领域决定 |
| **建议默认值** | 本契约推荐的首版行为 | 可通过原型或真机测试调整，但需要记录原因 |
| **待验证假设** | 尚无足够现场证据 | 必须有指标、场景或访谈验证，不能写成已证明需求 |
| **待决策冲突** | 活跃文档之间或新建议与 ADR 之间存在不一致 | 在进入实现 issue 前必须解决 |

文中的“必须”表示体验不变量；“默认”表示建议默认值；“可以”表示不阻塞主闭环的可选能力。

## 3. P0 用户承诺

### 3.1 必须成立的体验不变量

| 不变量 | 状态 | 验收含义 |
| --- | --- | --- |
| 不登录也能完成完整手工闭环 | 产品事实 | 无账号可创建 RouteCard、记录 Attempt、回顾并看到 NextSessionCue |
| 没有 Apple Watch 仍可使用 | 产品事实 | iPhone 提供完整但不强调的手工记录入口 |
| 拒绝或撤销 HealthKit 不阻塞攀岩语义记录 | 产品事实 | GymVisit、RouteCard、Attempt 和回顾继续工作 |
| 没有照片仍可创建可复用 RouteCard | 产品事实 | 最小 RouteCard 只要求用户可识别的 label |
| Watch 上确认的操作先本地保存，再尝试同步 | 产品事实 | 手机不在、无网或暂时不可达时不丢记录 |
| 不确定结果保持未决，不自动等同于失败 | 产品事实（ADR 0004） | `unresolved` 只进入回顾，不自动创建 FailureEpisode |
| 用户确认或纠正高于任何系统建议 | 产品事实 | 建议不能覆盖用户已确认的数据 |
| 技术失败与待回顾内容分开 | 建议默认值 | “尚未整理”不显示成“同步失败”，反之亦然 |
| 结束 GymVisit 不依赖 HealthKit 成功 | 产品事实 | App 记录先结束；HealthKit 写入可异步重试 |
| 用户可知道记录保存在哪里、是否已同步 | 建议默认值 | 每个关键状态有简短、可理解、可恢复的文案 |

### 3.2 不承诺

- 不自动判断 Send、Fail、Flash 或失败原因。
- 不把心率、动作或休息时长解释为“已恢复”“该停止”或安全结论。
- 不要求岩馆数据库、定位、照片、账号或云服务来识别路线。
- 不要求用户在每一次尝试后填写失败分类或长文本。
- 不把 AI 读线、动作还原、SetterLens 或 TrainingPath 作为 P0 闭环依赖。

## 4. 体验表面与职责

| 表面 | 负责 | 不负责 | 状态 |
| --- | --- | --- | --- |
| Apple Watch | GymVisit 开始/结束、当前路线切换、一次 Attempt、可选 Send、Undo、休息计时、离线队列 | RouteCard 详细编辑、照片、失败分类、长文本 | 产品事实（ADR 0004） |
| iPhone | 首次使用、RouteCard、无 Watch 记录、回顾 Inbox、FailureEpisode、MoveCue、NextSessionCue、权限和导出 | 要求用户攀爬中持续操作 | 产品事实 |
| HealthKit | 经授权后的系统 Workout 与健康/健身样本 | 路线、Attempt、结果和失败原因真相 | 产品事实 |
| WatchConnectivity | Watch 与 iPhone 之间的后台/即时数据传输 | 强实时一致性或唯一真相 | 产品事实；Apple 的后台传输可排队，真机行为必须验证 |

Apple 官方将 WatchConnectivity 的后台 user-info 传输定义为排队并保证交付的传输方式，同时即时消息要求对端可达；因此 P0 必须把“本地已保存”和“已到达 iPhone”显示为不同状态，而不能用一个模糊的“已保存”。参见 [Transferring data with Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity) 和 [WCSession](https://developer.apple.com/documentation/watchconnectivity/wcsession)。

## 5. 体验状态模型

### 5.1 GymVisit 状态

体验层把“采集中”和“回顾完成”分开，避免用户为了结束 Workout 被迫填表。下表是两个正交领域轴的组合展示；`archived` 只控制历史列表可见性，不是第三套 GymVisit 领域状态。

| 状态 | 含义 | 可进入方式 | 可离开方式 | 状态 |
| --- | --- | --- | --- | --- |
| `not_started` | 当前没有 GymVisit | 首次打开或上一场已结束 | 开始记录 | 建议默认值 |
| `active` | 正在记录，到馆主状态 | Watch 或 iPhone 开始 | 结束、异常恢复 | 产品事实 |
| `ended_pending_review` | 已可靠结束，但仍有可整理内容 | 用户结束或恢复后补结束 | 开始回顾、直接归档 | 建议默认值 |
| `review_in_progress` | 用户已进入回顾，可分次完成 | 打开 Inbox 项目 | 完成、稍后继续 | 建议默认值 |
| `reviewed` | 已完成本次必要整理 | 保存或明确跳过所有待办 | 重新编辑 | 建议默认值 |
| `archived` | 历史记录，默认不在 Inbox | 用户归档或按策略折叠 | 重新打开 | 建议默认值 |

异常退出不产生第二个 GymVisit。Watch 或 iPhone 恢复时必须先查找未结束的本地记录，并提供“继续”“结束于上次活动时间”“放弃空记录”三种恢复动作；删除已有 Attempt 的异常 session 必须再次确认。

### 5.2 Attempt 语义

`Attempt` 是一次实际尝试，不等同于结果按钮。建议首版模型：

| 字段 | 建议值 | 说明 |
| --- | --- | --- |
| `route_binding` | `route_card_id` / `provisional_route_id` / `unassigned` | 路线尽量绑定，但不因当下无法建卡而丢 Attempt |
| `outcome` | `unresolved` / `sent` / `not_sent` | 新记录默认为 `unresolved` |
| `capture_source` | `watch` / `iphone` / `review` / `import` | 保留来源 |
| `capture_at` | 用户动作时间 | 与接收/同步时间分开 |
| `confirmation_state` | `user_recorded` / `user_corrected` / `suggested` | 用户动作与系统建议不混淆 |
| `sync_state` | 见 5.5 | 不写进攀岩结果字段 |

规则：

- 记录一次 Attempt 后，休息计时可以自动从 0 开始；这是计时便利，不代表生理恢复建议。
- `Send` 是对一个明确存在的 Attempt 的结果确认，绝不增加次数。如果 Watch 没有可选目标，应先提示“记一次尝试”；若用户确实漏记，iPhone 回顾先新增一条带来源/近似时间的 Attempt，再将该 Attempt 标记为 `sent`。
- 未记录 `Send` 不等于 `not_sent`；只有用户主动确认或在回顾中修改才成为 `not_sent`。
- `FailureEpisode` 只可来自用户确认的 `not_sent` Attempt，或明确标为 `suggested` 且等待用户确认的候选。
- `Flash` 由“该 RouteCard 的首个有效 Attempt 为 sent”在回顾中确认，是结果属性，不是必需的 Watch 主按钮。

### 5.3 Attempt Anchor 迁移与验证

**产品事实：** ADR 0004 已接受“一键 Record Attempt + 可选 Mark Send + exact-target Undo”，并明确 P0 不要求 Watch `Fail`。它取代 ADR 0003 中四个 Watch 事件按钮的部分；任何活跃文档如果仍出现旧语义，都属于切 implementation issue 前必须消除的迁移债务。

首版 Watch 主界面因此必须遵守：

- `记一次尝试 / Record Attempt` 是唯一高频主操作；
- `刚才完成了 / Mark Send` 修改一个已存在 Attempt，不增加次数；
- `Undo` 撤销用户点击时锁定的精确 action target，不是撤销 iPhone 最晚收到的事件；
- `not_sent` 只能由用户明确确认，通常在 iPhone 回顾完成；
- 新 Attempt、开始休息、换线、结束 GymVisit 或传感器证据都不能自动把旧 Attempt 变为 `not_sent`。

**待验证假设：** 该模型在不降低 Send 纠正准确率的前提下，可以把中断感控制在 3/10 以下，并让用户连续三场仍愿意记录。真馆测试仍决定文案、布局和次操作时机，但不重新引入“未知自动等于失败”。

### 5.4 路线绑定与换线

| 场景 | 默认行为 | 恢复/纠正 |
| --- | --- | --- |
| 已有 RouteCard | 选为当前路线，后续新 Attempt 绑定它 | 回顾中可逐条或批量改绑 |
| 临时看到新路线 | Watch 建立“临时路线”槽位，不要求输入名称 | iPhone Inbox 补 label、颜色、墙区或合并已有卡 |
| 当下不想选路线 | 允许记录为 `unassigned` | 结束后按时间段批量分配 |
| 换线 | 明确选择另一个最近 RouteCard 或新临时槽位 | 切换只影响切换后的事件，不追溯改绑 |
| 切回之前路线 | 最近路线列表保留至少 3 个 | 不创建重复 RouteCard |
| 路线重置/消失 | 旧 RouteCard 标为 `gone`，历史仍保留 | 物理路线实质变化时创建 successor RouteCard；NextSessionCue 可关闭或转为归档 |

**产品事实：** ADR 0004 将 `Project` 定义为关联一个 RouteCard、具有开始和结束的一次重试周期；RouteCard 的可见性、物理可用性与 Project 进度是三条独立状态轴。同一 RouteCard 可以有多个历史 Project cycle，但同一时刻最多一个 active Project。旧 PRD 的单一 `RouteCard.status` 不再是规范存储模型。

### 5.5 保存与同步状态

用户可见状态只描述可行动事实，不暴露内部网络术语。

| 内部状态 | 中文文案 | English copy | 用户动作 |
| --- | --- | --- | --- |
| `saving_local` | 正在保存到本机… | Saving on this device… | 通常无需操作；超过 2 秒显示重试 |
| `saved_on_watch` | 已存手表，等待同步 | Saved on Watch · Waiting to sync | 可继续攀爬 |
| `queued` | 已排队，将在连接后同步 | Queued · Syncs when connected | 可查看待同步数量 |
| `transferring` | 正在同步… | Syncing… | 可离开页面，不阻塞结束 |
| `synced` | 已同步到 iPhone | Synced to iPhone | 无 |
| `needs_attention` | 记录还在本机，需要处理 | Saved locally · Needs attention | 打开诊断、重试或导出 |
| `conflict` | 两端都有修改，请选择 | Changes on both devices | 比较并确认，不静默覆盖 |

默认不使用“云端已保存”，除非未来真的有账号和云存储。Watch 与 iPhone 都应显示最后成功同步时间和仍待同步的事件数。

## 6. 端到端场景契约

### 6.1 首次使用

默认流程最多包含三步，权限按需出现：

1. 用一句话解释价值：“记住今天爬了哪条、卡在哪里、下次先试什么。”
2. 选择“直接使用”或“连接 Apple Watch”；不出现强制注册。
3. 进入空的首页，主操作是“开始到馆记录”，次操作是“先建一张路线卡”。

首次启动不得一次性请求 HealthKit、通知、照片、相机、麦克风和定位。权限必须在相关动作前解释用途，并提供“暂不”。Apple 要求 HealthKit 按数据类型细粒度授权，也允许用户随后更改权限；应用不能把拒绝读取简单识别成一个可靠的“拒绝”状态。参见 [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)。

### 6.2 降级路径

| 条件 | 必须保留的主价值 | 不应出现的阻塞 |
| --- | --- | --- |
| 无账号 | 本地 RouteCard、GymVisit、Attempt、回顾、导出/删除 | 登录墙、试用倒计时 |
| 无 Watch 或 Watch App 未安装 | iPhone 一键 Attempt、Send、Undo、休息计时 | “设备不支持，无法开始” |
| Watch 未连接/手机不在 | Watch 独立开始、记录、结束并排队同步 | 要求把手机带到墙边 |
| HealthKit 未授权/部分授权 | App 私有 GymVisit 与完整手工闭环 | 反复弹权限；把无数据说成“你没有心率” |
| 无照片/相机被拒 | label + gym + wall area + color/grade 任意组合 | RouteCard 创建失败 |
| 通知被拒 | App 内 NextSessionCue | 强制开启通知 |
| 无网络 | 全部 P0 本地操作 | 登录刷新、AI 或远程服务超时阻塞记录 |

### 6.3 到馆前与入馆

首页优先级：

1. 若存在未完成的异常 GymVisit，先给出恢复卡。
2. 若存在上次 NextSessionCue，显示最多 3 条“今天先试”。
3. 显示“开始到馆记录”。
4. 显示最近项目和最近岩馆，不要求定位。

开始记录时：

- 默认沿用最近 gym label，允许“本次不填”。
- 如果 Watch 可用，明确显示将在哪个设备记录。
- HealthKit 尚未授权时，只在用户选择“同时记录到健康”后请求。
- 启动成功的判据是本地 GymVisit 已创建；HealthKit 或同步仍可处于 pending。

### 6.4 新路线与选择路线

最小 RouteCard 必须在 30 秒内可建成：

- 必填：用户可辨认的 `label`；
- 快选：最近 gym、墙区、颜色、原始等级文本；
- 可选：照片、主观等级、备注；
- 稍后补：所有非 label 字段。

若用户只在 Watch 上操作，允许建立 `临时路线 1/2/3`。这不是永久 label；回顾 Inbox 必须突出待命名和可合并状态。

### 6.5 一次尝试

建议默认交互：

1. 当前路线和主操作始终在同一屏。
2. 点“记一次尝试”后立即本地落盘并给一次轻触觉反馈。
3. 界面显示 `本路线 4 次 · 休息 00:00`，并给出次操作“刚才完成了”。
4. 5 秒内提供可见 Undo；之后仍可从最近事件撤销。

不得要求在 Attempt 后选择失败原因。不得因心率缺失、同步延迟或手机不可达让主按钮失效。

### 6.6 休息

- 休息计时从最近一次 Attempt 的用户动作时间开始。
- 用户可以暂停、重置或关闭提示；计时本身仍可作为 RestInterval 草稿。
- 触觉提醒是用户设置的固定时间提示，不是“恢复完成”。
- 换线不自动结束休息；下一次 Attempt 或用户重置才结束当前区间。
- 忘记记录 Attempt 时，用户可在 iPhone 回顾中补记大致时间，不需要伪造精确秒数。

**待验证假设：** 一个固定的默认提醒是否有价值尚未证明。P0 alpha 应默认关闭或只在用户主动设置后开启，并记录关闭率和打扰评分。

### 6.7 误触、漏记与 Undo

| 问题 | 默认恢复 |
| --- | --- |
| 刚刚误触 | Watch 一键 Undo，并显示被撤销事件摘要 |
| 连续误触多次 | 最近事件列表支持逐条撤销，不只保留最后一次 |
| 漏记一次 | iPhone 回顾补 Attempt，时间标为 `approximate` |
| 错路线 | 回顾中改绑 RouteCard，产生 CorrectionEvent |
| 错把 Send 标到上一条 | 选择目标 Attempt；若无目标则新建并提示确认 |
| 撤销已同步事件 | 发送 tombstone/CorrectionEvent，同步端不把旧事件复活 |

### 6.8 Watch 重启、App 被终止与手机不在

Watch 必须在每个用户事件后持久化最小 checkpoint：当前 GymVisit、当前路线、本地事件序号、最近同步确认点和计时基准。

重启后：

- 若 GymVisit 仍 active，首屏显示“恢复今天的记录”而不是新建一场；
- 若 Workout 已结束但 App GymVisit 未结束，允许补结束并把不确定结束时间标出；
- 若手机仍不在，继续记录并增加待同步计数；
- 队列重放必须按稳定 `event_id` 去重，接收两次不能生成两个 Attempt；
- 自动合并失败时保留两端副本并进入 `conflict`，不以“较新设备”静默覆盖。

### 6.9 结束 GymVisit

“结束”是可靠保存动作，不是表单入口：

1. 用户确认结束；避免一个无确认的破坏性大按钮。
2. Watch 先把 App GymVisit 标为 ended 并保存本地 checkpoint。
3. HealthKit Workout 和跨设备同步异步收尾。
4. 立即显示：尝试数、路线数、待同步数和“稍后回顾”。
5. 可选提供两个不阻塞问题：本次主观用力、前臂泵感；详细规则见生理数据契约。

如果 HealthKit 保存失败，文案应为“LineWise 记录已保存；健康 Workout 尚未写入”，并给出重试。不得让用户重新结束整场。

### 6.10 待整理 Inbox

Inbox 只承载需要用户判断的内容：

- 未绑定路线的 Attempt；
- 临时路线待命名或待合并；
- 未决 Attempt 结果（可整组跳过）；
- 用户选择记录的关键失败待补 primary blocker；
- 缺少 NextSessionCue 的 active project；
- 系统建议等待接受、编辑或拒绝。

技术同步错误放在独立的“记录状态”，但在 Inbox 顶部可显示一个非阻塞摘要。

Inbox 条目状态：`pending`、`snoozed`、`resolved`、`dismissed`。`dismissed` 表示用户明确不整理，不能被后台规则重新创建；以后新证据产生新条目时必须使用新 ID。

### 6.11 批量回顾

默认按 RouteCard 分组，而不是按分钟展示长时间线：

1. 批量把一段 unassigned Attempt 绑定到一条路线。
2. 显示每条路线的 Attempt 数和已确认 Send。
3. 用户只为“值得记住的失败”创建 FailureEpisode，不强迫逐次分类。
4. 每个 active project 最多突出一个 MoveCue 和一个 next action。
5. 一键保存为 NextSessionCue；允许“这次不写”。

批量操作必须支持撤销，且不能覆盖逐条已确认的不同值。用户退出中途时保留进度，不重新从第一条开始。

### 6.12 下次到馆

NextSessionCue 在下一次到馆前/开始时展示：

- RouteCard 的可辨认 label、颜色/墙区/照片缩略图（如有）；
- 上次一个 blocker；
- 一个 MoveCue；
- 一个下一步动作；
- `开始这条`、`稍后`、`已完成`、`路线没了`。

选择“开始这条”只把它设为当前 RouteCard，不自动创建 Attempt。选择“路线没了”将 RouteCard 标为 `gone` 并保留历史。未使用的 Cue 不自动视为无效；ProofCheck 属于后续训练闭环。

## 7. 空状态、错误与超时

### 7.1 空状态

| 页面 | 空状态文案要回答 | 主操作 |
| --- | --- | --- |
| 首页无历史 | 这是什么、第一步是什么 | 开始到馆记录 |
| 路线列表为空 | 不需要照片或岩馆数据库 | 新建 RouteCard |
| Inbox 为空 | 当前已整理完成 | 回到项目 / 查看历史 |
| NextSessionCue 为空 | 不代表失败，可从 active project 创建 | 选择一个项目 |
| 无生理数据 | 权限、设备或覆盖不足都可能导致 | 继续查看攀岩记录 |

### 7.2 错误分类

| 类别 | 示例 | 用户信息 | 恢复原则 |
| --- | --- | --- | --- |
| 可重试外部错误 | HealthKit 写入、Watch 传输暂时失败 | 核心记录是否安全 + 下一步 | 自动退避，可手动重试 |
| 本地保存错误 | 磁盘/数据库写入失败 | 明确尚未可靠保存 | 停止新增写入、导出诊断、避免虚假成功 |
| 权限/能力不可用 | HealthKit、照片、通知 | 哪项增强不可用 | 提供不依赖该权限的路径 |
| 数据冲突 | 两端都编辑同一对象 | 两个版本及来源 | 用户选择或合并 |
| 数据不完整 | HR 覆盖不足、结束时间未知 | 标 `partial`/`approximate` | 不补造精确值 |

### 7.3 超时

- 主记录动作 300 ms 内应有本地确认反馈；这是体验目标，不是服务器 SLA。
- 本地保存超过 2 秒显示“仍在保存”，并禁用会造成重复的再次提交。
- 即时 Watch 消息超时后自动降级为后台队列，不把它显示成记录丢失。
- 同步超过 60 秒仍未确认时显示 `queued`，而不是永久旋转加载。
- 健康数据查询和统计超过 10 秒时先展示攀岩回顾，生理卡片独立显示“稍后重试”。

以上阈值均为**建议默认值**，需要在真机和真实岩馆网络条件下验证。

## 8. 冲突与纠正规则

优先级不是简单的“最后写入者胜出”：

```text
用户明确纠正
> 用户明确记录
> 用户接受的建议
> 尚未确认的系统建议
```

- 同一层级的并发修改必须比较对象版本和字段，不整对象覆盖。
- 每次纠正保留 `object_id`、字段、旧值、新值、来源设备和时间。
- 删除通过 tombstone 传播，至少保留到所有已知设备确认。
- 系统建议被拒绝后，除非输入或模型版本发生实质变化，否则不重复出现。
- 调整设备时间或跨时区不改变事件因果顺序；保留设备时间、UTC 时间和本地序号。

## 9. 可访问性契约

P0 必须覆盖：

- 支持系统文字大小；关键按钮不得因放大截断核心动词。
- 所有状态不能只靠红/绿或路线颜色表达；同时使用文字、形状或图标。
- VoiceOver 能读出当前 RouteCard、Attempt 次数、休息时长、按钮后果和同步状态。
- Watch 主操作有清晰可区分的触觉，但触觉可以关闭，关闭后仍有视觉确认。
- 支持 Reduce Motion；计时和状态变化不依赖动画理解。
- 大触控区域、戴粉袋/手抖场景下可操作；关键事件提供 Undo。
- 不把左右滑动作为唯一入口；同一动作可从可见按钮或菜单完成。
- 结果、同步、权限和警告文案使用短句，不用 `HK`、`WCSession` 等内部缩写面对用户。

**待验证假设：** 戴手套不是室内抱石主场景，但手指有粉、心率高和视线短暂是主场景；可用性测试应在真实休息窗口而不是桌面完成。

## 10. 中文、英文与等级体系

### 10.1 核心文案词汇

| Domain term | 简体中文 | English | 禁用或谨慎使用 |
| --- | --- | --- | --- |
| `GymVisit` | 到馆记录 / 本次攀爬 | Gym visit / Session | Workout 不能代替整个语义对象 |
| `RouteCard` | 路线卡 | Route card | 官方路线 |
| `Attempt` | 尝试 | Attempt | 未确认时不要叫 Fail |
| `Send` | 完成 | Send | 新手界面不能只出现圈内词 |
| `FailureEpisode` | 关键失败 / 卡点 | Failure episode / Blocker | 诊断 |
| `MoveCue` | 动作提示 | Move cue | `beta` 只可作为解释性别名 |
| `NextSessionCue` | 下次提示 | Next-session cue | 训练处方 |
| `RestInterval` | 休息计时 / 休息区间 | Rest timer / Rest interval | 已恢复 |
| `unresolved` | 待确认 | Unresolved | Failed |
| `saved_on_watch` | 已存手表 | Saved on Watch | 已同步 |

系统语言默认跟随设备。用户可以在 App 内切换中文/英文；用户自己输入的 RouteCard label、MoveCue 和备注不自动翻译。

### 10.2 等级

- `grade_text` 永远保留用户/岩馆原始文本，是 P0 显示真相。
- 用户可设置默认等级体系：V-scale、Font、岩馆自定义色带/数字，或自由文本。
- 单条 RouteCard 可以覆盖默认体系。
- P0 不自动把 V 与 Font 互相换算为“等价真值”；如未来展示换算，必须标为近似并可关闭。
- `SubjectiveGrade` 与岩馆标注分开展示，不能覆盖官方/原始文本。
- 排序未知、自定义或混合等级时回退到创建时间，不伪造难度顺序。
- 数字、日期、24/12 小时制和单位跟随 locale；路线颜色不能承担唯一身份。

## 11. 埋点与现场验收

P0 只采最小产品验证事件，不采健康值到通用分析 SDK：

| 目标 | 最小事件/指标 | 通过信号 |
| --- | --- | --- |
| 首次价值 | 首次开始、首张 RouteCard、首个 Attempt | 不登录且无权限也能完成 |
| 输入负担 | RouteCard 创建耗时、Watch 每次 taps、Undo 率 | RouteCard <= 30 秒；每次 1-2 taps |
| 可靠性 | 本地保存成功、待同步量、重复去重、异常恢复 | 本地 session 保存率 >= 95%，无已知静默丢失 |
| 回顾价值 | Inbox 打开、批量完成、跳过原因 | 完成 session 中 >= 60% 打开回顾 |
| 召回价值 | Cue 创建、下次打开、`开始这条` | 下次到馆打开率和 Cue 复用率各 >= 50% |
| 降级价值 | 无 Watch、HealthKit 拒绝、无照片的闭环完成 | 每条降级路径都通过任务测试 |
| 打扰 | Watch annoyance 1-10、第二/三场继续使用 | <= 3/10 且第三场仍使用 |

必须做的场景测试：

1. 新用户无账号、跳过全部权限，完成一次 iPhone-only 闭环。
2. Watch 开始后把 iPhone 留在储物柜，记录 10+ 次并结束，再恢复同步。
3. 一次误触、一次漏记、一次错路线、一次跨设备并发修改。
4. Watch App 被终止或设备重启后恢复 active GymVisit。
5. HealthKit 写入失败但 App GymVisit 正常保存和回顾。
6. 中英文各完成一次；V、Font、自定义文本各创建一张 RouteCard。
7. VoiceOver、较大文字、Reduce Motion、关闭触觉各完成关键路径。

## 12. 进入实现前必须结清

| 决策 | 当前状态 | 结清方式 |
| --- | --- | --- |
| 活跃文档的 `Try/Send/Fail` 与单一 `RouteCard.status` 迁移 | ADR 0004 与聚焦契约已同步；ADR 0003 保留带 superseded 注记的历史原文 | CI/审阅持续全文检索，历史研究和被取代 ADR 不作为冲突 |
| Attempt Anchor 的 Watch 文案与次操作时机 | 领域语义已定，交互待验证 | 三场真馆测试，不得改变 unknown 语义 |
| active GymVisit 的唯一 owner 与双端启动冲突 | App-domain GymVisit 唯一；HealthKit Workout 独立且 Watch 优先 | 领域状态机已覆盖“一次最多一场”；平台技术 spike 验证双端恢复 |
| 本地数据是否进入系统设备备份 | 攀岩语义可按普通本地数据策略；健康/派生/Research 文件排除普通 iCloud/CloudKit | 上线前隐私与备份恢复评审 |
| P0 是否首日支持完整结构化导出 | 外部 alpha 前必须有用户数据导出；内部 alpha 先有可复现 debug bundle | P0-012 验收，不阻塞最早纯领域 slice |
| 固定 rest haptic 默认开启还是 opt-in | alpha 默认关闭，用户显式设置后启用 | 两场真馆测试决定是否调整默认值 |

## 13. 相关文档

- `CONTEXT.md`
- `docs/adr/0001-gym-visit-memory-system.md`
- `docs/adr/0003-canonical-p0-domain-model-and-terms.md`
- `docs/adr/0004-attempt-anchor-and-project-cycles.md`
- `docs/linewise_p0_domain_and_lifecycle_contract_v0.md`
- `docs/climbing_bouldering_prd_v0_1.md`
- `docs/climbing_bouldering_mvp_gate.md`
- `docs/climbing_bouldering_platform_contract.md`
- `docs/linewise_physiology_data_contract_v0.md`
