# 攀岩 / Bouldering Apple Watch App 调研报告 v1

Date: 2026-05-24  
Project: `watchapp/climb`  
Status: Five-PM line-by-line reviewed primary report, revised after consensus veto fixes  
English naming: `抱石` = **Bouldering**

Reading path: 10-minute review should read `0 Executive Summary`, `2-17 主报告`, and `21 Final Consensus` first. Sections `1`, `18`, and `19` preserve the decision audit and are useful for tracing why the product was narrowed.

---

## 0. Executive Summary

### 0.1 最终判断

这个产品**有必要继续做独立验证**，但不能先假设它天然应该成长为一个独立平台。

最合理的当前对外定位不是“攀岩版 Strava”、不是“AI 自动识别攀岩动作”、不是“路线库/社区/岩馆 SaaS”，而是：

> **Apple Watch-backed bouldering training memory app：面向室内抱石用户，用 Watch 低干扰捕获训练锚点，用 iPhone 完成可修正复盘和下次训练前回忆。**

内部决策模型是：

> **Rhythm Capture + Recall Retrieval + Proof/Trust：手表管训练节奏，手机管可取回记忆，系统必须让记录可确认、可修正、可追溯。**

更产品化的一句话：

> 面向每周至少 2 次室内抱石、经常 project、且可能从低成本复盘中受益的 Apple Watch 用户，用最低交互成本记录 attempt、rest、send/fail 标签和 project 线索，并在 iPhone 上生成可修正、可在下次训练前取回的复盘。训练后复盘意愿本身是 P0 需要验证的假设。

这版报告经过 5 个产品经理视角重新讨论后，最终收敛为一个更克制但更可上线的方向：

| 结论 | 解释 |
| --- | --- |
| 可以做 | 室内抱石存在高频、重复、间歇、多尝试、多失败、重 project 的真实记录和复盘需求。 |
| 需要小切口验证 | 市场已有 Apple Workout、Strava、Redpoint、Pinnacle、Climb Meter、KAYA、Crimpd、Vertical-Life 等替代品，不是空白市场。 |
| Watch-first 成立 | 关键交互窗口在“下墙后的几秒休息期”，Watch 比 iPhone 更适合低干扰记录。 |
| Watch-only 不成立 | 复杂修正、project 管理、趋势解释和复盘必须放到 iPhone。 |
| Manual-first 是 P0 核心假设 | 即使自动候选很弱，产品也要先靠一键标记 + 训练后复盘成立。 |
| Recall-led 是留存假设 | 用户长期使用的理由不应只是“记录本身”，而应是下次训练前能用到的记忆和提示；这一点需要 beta 验证。 |
| Rhythm 是入口，不是付费理由 | 休息报时、触觉锚点和训练仪式能形成习惯，但 timer 本身容易商品化。 |
| Recall 比 recap 更值钱 | 训练后复盘是清洗层，下次训练前能否取回 project cue 才是产品价值层。 |
| Category 不是 timer，也不是 training OS | 内部战略假设是 `watch-backed training memory system for attempt-based sports`，但必须先从抱石 wedge 证明。 |
| Trust/Legitimacy 进入 Proof | 主观状态不是噪声，但也不是诊断；只有在解释行为并改善下一次尝试时才进入系统。 |
| 先验证，不先扩张 | P0 只验证室内抱石自由训练，不做 rope、户外、岩馆路线库、教练端、社交 feed。 |

### 0.2 投资论点

这个产品值得继续推进的理由是：

1. **攀岩不是连续周期运动**：跑步看配速、距离、心率；抱石更关心 attempt、rest、send/fail、project、失败原因和下次策略。
2. **默认工具缺语义层**：Apple Watch 原生支持 Climbing workout，但它不会告诉用户今天打了几次、哪条 project 卡住、休息是否影响后半段表现。
3. **手机不是训练现场好入口**：攀岩时手上有镁粉、手机可能放包里、下墙后用户只愿意做 1-3 秒操作。
4. **已有 Watch 攀岩 App 说明用户教育和供给尝试存在**：Redpoint、Pinnacle、Climb Meter 等说明“用表记录攀岩”不是陌生方向；但真实需求强度、留存和付费仍要由 beta 验证。
5. **真正价值应在复盘，不在传感器炫技**：需要验证用户是否会因为 next-session recall 持续使用，而不是只做一次性记录。

### 0.3 最大反对意见

5 个 PM 讨论后，一致认为最大风险不是算法，而是行为成本。以下阈值是内部 beta 假设，不是行业基准；第一次真实 beta 后必须校准：

| 反对意见 | 为什么危险 | 必须怎么验证 |
| --- | --- | --- |
| 用户不愿意抱石时戴表 | 磕碰、划伤、碍手、担心安全，都会让 Watch-first 失效。 | 目标用户中至少 60% 愿意整场戴表；低于 40% 直接 no-go。 |
| 用户不愿意每次下墙后点 | 抱石一场可能 15-40 次尝试，高频标记容易烦。 | 中位交互负担不超过 20 taps/小时，且“不打断训练”评分 >= 4/5。 |
| 用户训练后不看复盘 | 如果 recap 不能影响下次训练，记录就只是自嗨。 | 60% session 在 24 小时内被打开；40% 用户下次训练前会回看。 |
| Apple Workout + 备忘录已经够用 | 免费、无学习成本、无迁移成本，是最强替代品。 | 4 周内 35% 新用户记录 >= 4 次真实 session。 |
| 付费理由不足 | 垂直工具用户有限，免费替代多。 | 完成 >=3 次 session 的用户中，付费假门转化 >= 8%。 |

### 0.4 最终产品原则

| 原则 | 产品含义 |
| --- | --- |
| `Boulder only` | 首发只做室内抱石自由训练，不做绳攀、户外、训练课。 |
| `Record-enabled, recap-led` | 记录只是原料，复盘和下次记忆才是价值兑现。 |
| `Manual-first` | 先让用户的一键标记闭环成立，再用 motion/HR 降低成本。 |
| `Suggested, not detected` | 自动结果只叫 suggested timeline，不叫 detected truth。 |
| `Watch captures, iPhone explains` | Watch 做现场短操作，iPhone 做修正、解释和长期记忆。 |
| `Recap is plumbing, recall is product` | 复盘不是终点，它服务下次训练前的 project recall。 |
| `Time anchor is primitive, not product` | 报时/节奏是 Watch 侧状态切换原语，不是外部品类或付费理由。 |
| `Legitimacy protects trust` | Proof 不只是客观证据，也包括用户修正、候选来源；若启用 AI，再记录 AI provenance。 |
| `Low interruption over feature richness` | 少一个功能可以接受，多一次打扰可能毁掉产品。 |
| `Kill gates before roadmap` | 指标没过时不扩功能、不讲平台、不讲 AI 助手。 |

### 0.5 P0 范围

P0 只证明一个闭环：

> Watch 开始 session -> 低干扰记录时间、心率、rest、attempt 标签 -> iPhone 修正和复盘 -> 下次训练前能回看并产生行动。

| 模块 | P0 必须有 | P0 不做 |
| --- | --- | --- |
| Watch session | Start Boulder、Pause/Resume、End、长按结束、忘记结束后可裁剪。 | Boulder/Rope/Training 多入口复杂模式。 |
| Workout/Health | 启动 Climbing workout，记录时间、心率、活动能量，写入 HealthKit。 | 用 HealthKit 推断 send/fail。 |
| Manual event | 下墙后 `Try / Send / Fail / Undo`。 | Watch 上输入完整路线信息。 |
| Rest timer | 当前 rest 时间、柔和触觉提醒、可关闭。 | 医疗化疲劳判断或强制休息建议。 |
| P0b optional suggested candidates | motion + time + HR 生成 attempt/rest 候选，默认不作为事实。 | 自动判定路线完成、flash、动作技术。 |
| Local-first sync | Watch 本地先保存，iPhone 可用时补传、去重、确认。 | 默认云端上传。 |
| iPhone review | 修正 attempt、result、session 时间、project 绑定。 | 复杂路线库、社区、feed。 |
| Project basics | Recent / New / Unassigned，训练后可选补充。 | 岩馆路线库或 route database。 |
| Recap | 基础 session summary、待确认项、用户确认后的 next cue。 | 泛泛 calories summary、自动教练建议、AI 真相判断。 |

---

## 1. 五个产品经理决策过程摘要（可跳读）

### 1.1 角色设定

这次讨论模拟 5 个产品经理，从互相挑刺到最终收敛：

| PM | 角色 | 核心问题 |
| --- | --- | --- |
| PM-A 用户与 ICP | 谁真的需要它？谁只是看起来像用户？ |
| PM-B 市场与竞品 | 这是空白、机会，还是已被替代品吃掉？ |
| PM-C Watch 平台 | 为什么必须是 Watch？Watch 的边界在哪里？ |
| PM-D 数据与复盘 | 记录什么才会变成用户下次训练能用的价值？ |
| PM-E 商业化与增长 | 独立 App 能不能活？什么指标没过就该停？ |

### 1.2 Round 1: 这个产品到底有没有必要？

| PM | 观点 | 反驳 | 收敛 |
| --- | --- | --- | --- |
| PM-A | 有必要，但只对进阶室内抱石用户有强需求。 | 新手和轻量打卡用户可能只想拍照或用 Apple Workout。 | ICP 必须限定为每周至少 2 次、经常 project、可能有复盘需求且愿意参与验证的用户。 |
| PM-B | 市场有工具，不是空白。 | 竞品多反而说明用户有记录需求。 | 机会不是“没人做”，而是“还没人把低干扰记录 + next-session recall 做成默认习惯”。 |
| PM-C | Watch-first 有必要。 | Watch 容易磕碰、交互窄、电量有限。 | Watch 只承担现场短操作，不能承担完整 App。 |
| PM-D | 记录本身不够，需要转成复盘。 | 复盘如果只是漂亮统计也没用。 | Recap 至少帮助用户回忆；next cue 需要用户确认后展示。 |
| PM-E | 可做小而尖工具，不宜先讲平台。 | 小市场可能付费弱。 | 先做 B2C narrow beta，用留存和付费假门决定是否继续。 |

最终结论：

> 有必要做，但必要性不是“攀岩需要一个 App”，而是“室内抱石用户需要一个低成本、可复盘、能延续到下一次训练的 session memory layer”。

### 1.3 Round 2: 谁是用户，谁不是？

PM-A 提出用户必须被收窄，否则产品会同时讨好新手、进阶、户外、绳攀、教练和岩馆，最后什么都做浅。

最终 ICP:

| 条件 | 为什么必要 |
| --- | --- |
| 每周室内抱石 >= 2 次 | 高频才能形成记录习惯。 |
| 一场训练 >= 10 次 attempt | attempt/rest 事件层才有价值。 |
| 经常 project | 需要跨 session 的记忆。 |
| 已经戴 Apple Watch 或愿意尝试 | Watch-first 的前提。 |
| 可能愿意训练后花 30-60 秒 review | recap-led 的待验证前提。 |
| 对进步、训练质量或 project continuity 有明确关注 | 才会关心 rest pattern、send rate、project trend。 |

明确非首发用户：

| 用户 | 为什么不是 P0 |
| --- | --- |
| 纯新手体验用户 | 还不理解 grade、project、attempt 复盘，记录压力会过高。 |
| 轻社交打卡用户 | 小红书/朋友圈/照片已经满足主要需求。 |
| 户外攀岩用户 | topo、天气、GPS、离线、安全和路线信息比 Watch 标记更重要。 |
| 先锋/顶绳用户 | belay、fall、rope route、高度和安全语义不同。 |
| 训练板重度用户 | MoonBoard/Kilter 等已有标准化路线和训练生态。 |
| 不愿戴表用户 | 无法被 Watch-first 方案服务。 |

### 1.4 Round 3: 真正竞争对手是谁？

PM-B 认为旧报告最大问题是把竞品当功能列表，而没有按 job-to-be-done 分层。

真正的竞争层级：

| 层级 | 对手 | 抢什么 |
| --- | --- | --- |
| L0 默认替代品 | Apple Workout、Strava、备忘录、Excel、照片 | 抢用户习惯和最低成本。 |
| L1 Watch 记录器 | Redpoint、Pinnacle、Climb Meter、Garmin/COROS | 抢“用表记攀岩”的心智。 |
| L2 轻量 logbook / AI-adjacent logbook | GoClimbr、CrushLog、SendLog、SendSage、MyClimb | 抢训练后复盘和长期记录。 |
| L3 路线/岩馆/社区平台 | KAYA、Mountain Project、Vertical-Life、TopLogger、Griptonite | 抢分发、route identity、community network。 |
| L4 训练生态 | Crimpd、Lattice、MoonBoard、Kilter Board | 抢高付费、高训练意愿用户。 |

这个分层带来一个更尖锐的判断：

> Market proof 不是“有人下载攀岩 App”，而是“用户愿不愿意替换掉 Apple Workout + Notes/Excel/照片这套足够便宜的习惯”。

### 1.5 Round 4: 为什么必须是 Watch？

PM-C 把 Watch-first 论证压成一个定理：

> Watch-first 的必要性来自现场捕获窗口；Watch-only 的错误来自小屏和攀岩安全边界。

为什么 Watch 必须存在：

| 理由 | 解释 |
| --- | --- |
| 下墙后窗口很短 | 用户愿意点一下，但不愿意掏手机、解锁、找 App、填表。 |
| 休息计时天然在手腕上 | rest 是抱石训练的关键变量，Watch 是更自然的计时和提醒设备。 |
| 触觉比视觉更合适 | 休息提醒可以轻触觉，不需要用户盯屏。 |
| HealthKit/Workout 生态 | Apple Watch 原生 workout、心率、活动能量、Fitness 环闭环是底层价值。 |
| motion 可做候选分段 | 虽然不能做真相，但可以减少回看和修正成本。 |
| 离线场景 | iPhone 不在身边时，Watch 仍应记录 session。 |

为什么不能 Watch-only:

| 不适合 Watch 的事 | 原因 |
| --- | --- |
| project 管理 | 需要编辑名称、颜色、grade、墙面、备注，小屏太慢。 |
| 复杂纠错 | timeline 拖动、拆分、合并、改结果应在 iPhone。 |
| 趋势解释 | 图表、比较、长期复盘需要大屏。 |
| 路线库 | 搜索、地图、照片、评论都不适合训练中手表输入。 |
| 动作分析 | 单腕数据不足，需要视频或多传感器。 |

### 1.6 Round 5: 记录什么才有价值？

PM-D 认为产品不能叫“记录器”，而应叫“复盘副驾”。因为用户不是为了拥有数据而记录，而是为了下次训练更清楚。

有效 recap 必须同时满足四个条件：

| 条件 | 解释 |
| --- | --- |
| 可行动 | 能告诉用户下次先回到哪个 project，或本次后半段表现如何变化。 |
| 有上下文 | attempt 必须连到 project、grade、result、rest，而不是孤立计数。 |
| 可比较 | 用户需要看到今天和过去几次相比有什么变化。 |
| 可信 | 自动候选可修正，数据来源清楚，不把猜测说成事实。 |

因此 P0 recap 不是：

> “今天训练 78 分钟，消耗 420 kcal，平均心率 132。”

而应先是可编辑的复盘提示：

> “今天 78 分钟，18 次 attempt，5 次 send。Project A 连续 6 次未完成，后 3 次平均 rest 从 2:10 增加到 4:20，且 send rate 在后半段下降。若这条线仍是 active project，可保存一个 next cue：下次热身后先回到 Project A，关注前几次尝试节奏。”

注意：这种提示必须以“用户可确认/可编辑的训练复盘线索”呈现，不能写成教练处方、医疗恢复或安全诊断。

### 1.7 Round 6: 商业上能不能活？

PM-E 的判断最克制：

> 这可能是一个能养活小团队或独立产品的小而尖工具，但不能先按大平台估值逻辑做。

商业成立的前提：

| 前提 | 验证方式 |
| --- | --- |
| 高频目标用户真的存在 | 访谈 + 岩馆/社群招募 + 4 周 beta。 |
| 用户愿意替换现有习惯 | retention 和复盘回看，而不是下载量。 |
| 复盘能影响下次训练 | next-session recall 和用户主观反馈。 |
| 付费点不依赖路线库 | Pro 候选价值来自长期 project、趋势、复盘、导出、个性化；具体排序要通过假门验证。 |
| 有可重复获客渠道 | 岩馆教练、creator、App Store SEO、Reddit/小红书/B站。 |

不建议一开始做：

| 不建议 | 原因 |
| --- | --- |
| 月订阅优先 | 早期价值密度不足，用户会抗拒。 |
| 岩馆 SaaS | 销售慢、定制多、路线维护重，会拖垮 MVP。 |
| 社交平台 | 冷启动难，且不解决核心复盘问题。 |
| AI 大叙事 | 容易过度承诺，反而降低信任。 |

更现实的变现顺序：

1. 免费核心记录，验证行为习惯。
2. 早期一次性 / lifetime / founder unlock，测试付费意愿。
3. Pro 年付，放在长期趋势、project analytics、导出、个性化规则、视频关联之后。
4. 教练/岩馆只做分发和 beta 数据合作，不先做 B2B 产品。

### 1.8 五个 PM 的最终投票

| PM | 投票 | 条件 |
| --- | --- | --- |
| PM-A 用户 | Go | 必须只打室内抱石进阶用户，不做泛攀岩。 |
| PM-B 市场 | Go with proof | 必须把 Apple Workout + Notes 作为最大竞品验证。 |
| PM-C 平台 | Go | 必须写清 Watch-first not Watch-only，并设设备/电量/同步门禁。 |
| PM-D 复盘 | Go | 必须让 recap 成为主价值，不做普通运动 summary。 |
| PM-E 商业 | Conditional Go | 必须有 4-6 周 beta kill gates，指标不过就 pivot 或停。 |

最终委员会结论：

> **继续推进，但只作为室内抱石 P0 验证项目推进。先证明佩戴、低干扰标记、训练后复盘、下次回看和付费信号，再讨论 rope、AI、社交、岩馆合作和平台化。**

---

## 2. 调研方法和证据等级

### 2.1 调研范围

本次重研覆盖：

1. 攀岩市场和室内岩馆趋势；
2. Apple Watch / HealthKit / Workout / WatchConnectivity / Core Motion 能力；
3. 攀岩垂直 App、Watch 攀岩记录 App、运动平台、训练生态、logbook 工具；
4. 抱石真实训练场景；
5. 目标用户行为漏斗；
6. MVP 功能、平台门禁、商业化和 go/no-go 标准。

### 2.2 证据等级

| 类型 | 来源 | 可信度 | 使用方式 |
| --- | --- | --- | --- |
| 官方事实 | Apple Developer、Apple Support、App Store、竞品官网 | 高 | 确认平台能力、竞品功能、付费方式、系统边界。 |
| 市场事实 | Climbing Business Journal、竞品公开信息 | 中高 | 判断市场增长、生态成熟度和竞争强度。 |
| 用户反馈 | App Store 评论、社区讨论、Reddit、Mountain Project 等 | 中 | 发现痛点和 badcase，但样本偏差较大。 |
| 产品推断 | 基于攀岩场景和 Watch 交互限制 | 中 | 用于 MVP 收敛和验证假设。 |
| 待证假设 | 留存、付费、自动候选准确率、复盘价值 | 低到中 | 必须通过访谈、原型和真实训练 beta 验证。 |

### 2.3 这次和旧报告的区别

旧报告主要回答“这个方向看起来有什么机会”。  
这版报告重点回答：

1. **为什么这个产品有必要存在？**
2. **谁真的会用，而谁只是噪音用户？**
3. **为什么必须是 Watch，但又不能是 Watch-only？**
4. **如何证明它不是 Apple Workout + Notes 的重复品？**
5. **什么指标不过就应该停？**

---

## 3. 市场再判断

### 3.1 市场不是空白，也不是爆发红利

[Climbing Business Journal 的 2025 报告](https://climbingbusinessjournal.com/gyms-and-trends-2025/)显示，北美攀岩馆行业仍在增长，但增长是有约束的：2025 年净增长率约 4.7%，并且行业也面对经济和运营压力。这个信号很重要：

| 判断 | 产品含义 |
| --- | --- |
| 室内攀岩仍在增长 | 高频训练人群仍值得关注。 |
| 不是爆发式红利 | 不能用“市场自然增长”掩盖产品验证不足。 |
| 岩馆是线下渠道 | 可以作为种子用户和数据采集场景。 |
| 岩馆 SaaS 不适合 P0 | 销售周期、路线维护、运营成本都太重。 |

因此，这个产品不能靠“攀岩市场增长”本身成立。它必须靠一个更具体的行为价值成立：

> 高频抱石用户是否真的愿意用 Watch 留下训练记忆，并在下一次训练前回看。

### 3.2 默认替代品很强

最危险的竞争不是 Redpoint 或 KAYA，而是用户已经在用、并且足够便宜的组合：

| 默认替代品 | 优势 | 我们必须赢在哪里 |
| --- | --- | --- |
| Apple Workout | 免费、系统自带、能关环、能记心率和时间。 | 增加 attempt/rest/send/project 语义层。 |
| Strava | 支持 Rock Climb 类型，社交和运动历史强。 | 攀岩训练复盘更具体，而不是泛运动 feed。 |
| 备忘录/Excel | 灵活、无迁移成本。 | 现场记录更低成本，训练后自动形成结构化 recap。 |
| 照片/视频 | 能保存路线和动作。 | 把照片外的 attempt、rest、result 和时间线补上。 |
| 口头记忆 | 完全无成本。 | 解决“下次进馆忘了上次卡在哪”的问题。 |

如果产品只比这些替代品多一点统计，它就不值得独立存在。

### 3.3 竞品地图

| 类别 | 代表产品 | 已有能力 | 对我们的压力 | 我们不硬碰什么 |
| --- | --- | --- | --- | --- |
| Watch 攀岩记录 | Redpoint、Pinnacle、Climb Meter | Apple Watch 记录、HealthKit、climb count、grade、同步等能力，需逐产品核验。 | 说明“用表记录攀岩”已有用户教育和供给尝试。 | 不承诺全自动，不拼高度/路线自动识别。 |
| 原生/泛运动 | Apple Workout、Strava、Garmin、COROS | workout、HR、calories、运动历史、社交。 | 免费或硬件生态强。 | 不拼泛运动，不拼硬件训练负荷。 |
| 路线/社区/guidebook | KAYA、Mountain Project、Vertical-Life、27 Crags | route、topo、community、logbook、gym 数据。 | route identity 和分发强。 | 不做 route database，不做 topo。 |
| 训练内容 | Crimpd、Lattice、board apps | 训练计划、hangboard、board problems、训练体系。 | 抢高付费训练用户。 | 不做训练内容库。 |
| 轻量 logbook / AI-adjacent logbook | GoClimbr、CrushLog、SendLog、SendSage、MyClimb | route/project/logbook/analytics，部分产品声称 AI insight。 | 抢 recap 和长期记录心智。 | 不做纯手机填表；用 Watch 降低现场 capture friction。 |
| 岩馆 SaaS | TopLogger、Griptonite、Vertical-Life | route setting、gym TV、ranking、feedback、运营数据。 | 有岩馆渠道和路线数据。 | 不先做 B2B。 |

### 3.4 差异化必须这样说

不准确甚至危险的说法：

| 说法 | 问题 |
| --- | --- |
| 首个攀岩 Apple Watch App | 事实不成立，Redpoint/Pinnacle/Climb Meter 已存在。 |
| AI 自动识别攀岩动作 | 容易过度承诺，单腕数据不够。 |
| 攀岩版 Strava | 战场太大，Strava 已在泛运动和社交上强很多。 |
| 自动判断疲劳/恢复/安全 | 医疗与安全风险高，证据不足。 |
| 自动识别路线完成 | Watch 不知道路线身份，也看不到全身和墙面。 |

准确说法：

| 对象 | 说法 |
| --- | --- |
| 用户 | 不用掏手机，低干扰记住今天每条 project 怎么打，下次进馆前能快速回想。 |
| 产品 | 把抱石 session 变成可编辑的 attempt/rest/project 记忆。 |
| 竞品 | 不和 KAYA 拼内容，不和 Crimpd 拼训练计划，不和 Strava 拼泛运动；只拼 capture friction 更低、next-session recall 更强。 |
| 技术 | 自动候选只是减少整理成本，最终事实由用户确认。 |

---

## 4. 产品必要性论证

### 4.1 用户为什么需要它？

室内抱石训练有几个天然特征：

| 特征 | 导致的问题 | 产品机会 |
| --- | --- | --- |
| 短时间高强度 | 每次 attempt 时间短，训练节奏碎片化。 | Watch 记录 session、用户标记和传感器线索；系统生成 rest/attempt 候选。 |
| 多次尝试 | 用户会在同一条线反复失败。 | 记录 attempt count、result、project history。 |
| 长休息 | rest 直接影响后续表现。 | Watch 休息计时和触觉提醒有价值。 |
| grade/墙面/风格差异大 | 只看总时长和心率没意义。 | recap 需要连到 project 和主观标签。 |
| 训练中不方便拿手机 | 现场记录成本高。 | Watch 一键标记。 |
| 训练后记忆快速衰退 | 用户可能忘记哪条线卡住、试了几次。 | iPhone 整理成待确认 session，用户确认后成为 canonical record。 |

### 4.2 用户真正的 Jobs To Be Done

| JTBD | 当前替代方案 | 替代方案不足 | P0 验证目标 |
| --- | --- | --- | --- |
| 不掏手机也记录今天练了什么 | Apple Workout + 记忆 | 没有 attempt/project 语义 | Watch 下墙后一键标记。 |
| 知道一条 project 试了几次 | 备忘录/Excel | 训练中填表太麻烦 | 候选时间线 + 用户确认。 |
| 训练后 1 分钟看懂质量 | 心率/卡路里 summary | 和攀岩语义不匹配 | session recap 翻译成 attempt/rest/send。 |
| 下次进馆知道先打哪条 | 口头记忆/照片 | 容易忘、上下文缺失 | 用户确认后的 project cue。 |
| 长期看到进步 | 手写 logbook | 不结构化、不自动对比 | P1 再验证 send rate、attempt trend、rest pattern。 |

### 4.3 为什么 Apple Workout 不够？

Apple Watch 原生支持 Climbing workout，这是基础，不是终点。

| Apple Workout 能做 | 它做不了 | 我们补什么 |
| --- | --- | --- |
| 记录总时长 | 不知道一次次 attempt | attempt event layer。 |
| 记录心率 | 不知道哪次尝试对应心率变化 | attempt/rest timeline。 |
| 写入 Health/Fitness | 不知道 send/fail/project | 用户标签和 project 绑定。 |
| 关 Activity rings | 不知道训练质量 | recap 和下一次训练记忆。 |
| 低成本启动 | 不知道抱石特有结果 | session review。 |

因此产品不是替代 Apple Workout，而是在其上加一层攀岩语义：

> HealthKit 负责运动事实，App 负责攀岩意义。

### 4.4 为什么不是纯 iPhone App？

纯 iPhone logbook 可以做得更完整，但它无法解决最关键的 capture friction。

| 场景 | iPhone 问题 | Watch 优势 |
| --- | --- | --- |
| 下墙后 3 秒 | 掏手机、解锁、找 App 太慢。 | 手腕上直接点。 |
| 手上有镁粉 | 不想碰手机屏幕。 | Watch 触觉/少量按钮更可接受。 |
| 手机放包里 | 训练节奏被打断。 | Watch 一直在身上。 |
| rest 计时 | 手机不在视线内。 | Watch 一眼看到 rest。 |
| 心率/Workout | 手机无法直接采集腕上 HR。 | Watch 是传感器入口。 |

但纯 Watch 也不行。因此正确架构是：

> Watch 做 capture，iPhone 做 canonical review。

---

## 5. 目标用户和场景

### 5.1 首发 ICP

| 维度 | 标准 |
| --- | --- |
| 运动类型 | 室内抱石为主。 |
| 频率 | 每周 2 次以上，或每月至少 6 次。 |
| 训练方式 | 经常 project，同一条线会多次尝试。 |
| 数据态度 | 对进步、休息、尝试次数、send rate 有兴趣。 |
| 设备 | 有 Apple Watch，且愿意在岩馆佩戴。 |
| 复盘假设 | 训练后是否愿意完成 30 秒 quick save / 60-90 秒 detailed review，需验证。 |
| 商业假设 | 其中一部分用户可能为长期复盘、趋势、导出付费，需假门验证。 |

### 5.2 用户分层

| 用户 | 需求强度 | P0 是否服务 | 说明 |
| --- | --- | --- | --- |
| 进阶室内抱石用户 | 高 | 是 | 核心用户。 |
| 数据控 / Apple Watch 重度用户 | 高 | 是 | 对 Health/Fitness 生态敏感。 |
| Project 型用户 | 高 | 是 | 最需要跨 session 记忆。 |
| 轻量室内抱石用户 | 中 | 部分 | 可以使用基础 session，但不为其扩功能。 |
| 新手 | 中低 | 暂不优先 | 需要更强引导和安全教育，不适合 P0。 |
| 先锋/顶绳用户 | 中 | 否 | 后续独立场景。 |
| 户外攀岩用户 | 中 | 否 | route/topo/weather/safety 优先级更高。 |
| 教练 | 中高 | 否 | 后续作为分发和 P2/P3 功能。 |

### 5.3 首发场景剧本

1. 用户到室内岩馆，打开 Watch，点 `Start Boulder`。
2. App 开始 workout、session timer、HR、motion 记录。
3. 用户第一次尝试后下墙，Watch 显示 rest timer。
4. 用户点 `Fail` 或 `Try`，无需输入路线。
5. 用户 send 后点 `Send`，可 Undo。
6. 训练中 App 只做极简显示和可选触觉提醒。
7. 结束时长按 `End`，Watch 保存本地 session。
8. iPhone 收到 pending review。
9. 用户训练后补 project、grade/color、备注，确认 suggested timeline。
10. 下次进馆前，App 显示 active projects 和上次最后状态。

### 5.4 用户最不想被打扰的时刻

| 时刻 | 禁止做什么 | 可以做什么 |
| --- | --- | --- |
| 攀爬中 | 弹窗、读长文本、要求确认、强提醒。 | 后台记录。 |
| 刚落地还在喘 | 复杂输入、grade/project 选择。 | 一个大按钮标记结果。 |
| belay/保护他人时 | 多步骤操作。 | P0 不服务绳攀。 |
| 岩馆社交聊天时 | 频繁自动提醒。 | 可静默记录 rest。 |
| 训练结束疲劳时 | 长问卷。 | 30-60 秒 pending review。 |

---

## 6. 产品合同

### 6.1 产品不是

| 不是 | 原因 |
| --- | --- |
| 通用 climbing app | 攀岩场景过宽，P0 会失焦。 |
| 攀岩路线库 | 路线维护、冷启动、版权/合作成本高。 |
| 岩馆 SaaS | 销售和运营复杂，不适合 P0。 |
| AI 动作教练 | 单腕数据不足，视频/上下文缺失。 |
| 医疗恢复工具 | HR/fatigue 解释存在风险。 |
| 社交 feed | 不解决首个核心问题。 |
| Apple Workout 替代品 | 应该利用 HealthKit，而不是替代系统记录。 |

### 6.2 产品是

| 是什么 | 含义 |
| --- | --- |
| Watch-first capture layer | 在训练现场用最少交互捕获事件。 |
| iPhone review layer | 训练后修正和解释 session。 |
| Project memory layer | 记住用户下次训练前真正会用到的信息。 |
| Assisted logbook | 自动候选辅助整理，但事实可编辑。 |
| Fitness bridge | 把攀岩训练写入 Health/Fitness 生态，同时补足攀岩语义。 |

### 6.3 产品价值链路

```text
低干扰捕获
  -> 可修正事实
  -> 攀岩语义复盘
  -> 下次训练记忆
  -> 长期趋势
  -> 付费价值
```

任何功能如果不服务这条链路，就不进入 P0。

### 6.4 北极星指标

不建议用下载量、session 数、算法 F1 做北极星。更好的北极星是：

> **每周完成 quick review，并产生或使用用户确认 next cue 的 climbing sessions 数。**

拆解指标：

| 指标 | 含义 |
| --- | --- |
| Recorded sessions | 用户是否完成记录。 |
| Reviewed sessions | 用户是否训练后打开复盘。 |
| Corrected sessions | 用户是否愿意把数据修成可信事实。 |
| Recalled sessions | 用户下次训练前是否回看。 |
| Returned projects | 用户是否回到上次 project。 |

---

## 7. 功能优先级

### 7.1 P0: 证明核心闭环

| 模块 | 功能 | 验证标准 |
| --- | --- | --- |
| Watch start | Start Boulder 一键开始 | 5 秒内能开始。 |
| Workout | HKWorkoutSession 管 start/pause/resume/end；HKLiveWorkoutBuilder/HealthKit samples 构建并保存 workout | Health/Fitness 可见。 |
| Timer | session timer + rest timer | 训练中稳定显示。 |
| Manual result | Try / Send / Fail / Undo | 休息窗口 <= 3 秒完成。 |
| P0b suggested candidates | attempt/rest 候选 | 不作为事实，iPhone 可确认，且可关闭。 |
| Local save | Watch 本地 checkpoint | 断连/崩溃后最大限度保留已落盘核心事件。 |
| Sync | Watch -> iPhone 补传去重 | 重试后 session 不重复。 |
| iPhone review | timeline、result、可选 project 绑定 | 30 秒 quick save；可选 60-90 秒 detailed review。 |
| Recap | 一屏基础总结 + 用户确认后的 next cue | 用户觉得对下次训练有用。 |
| Privacy/failure | 权限、低电量、同步失败状态 | 失败可解释、可恢复。 |

### 7.2 P1: 证明长期价值

| 功能 | 为什么是 P1 |
| --- | --- |
| Project cards | 连接跨 session 记忆，是留存关键。 |
| Review reminders | 训练后轻提醒，帮助形成习惯。 |
| Grade/color/wall preset | 训练后更快补充路线身份。 |
| 4 周趋势 | 让用户看到 attempt、send、rest 的变化。 |
| Rest pattern display | 展示休息分布和后半段表现，不输出恢复判断。 |
| Export | 数据控和教练用户可能需要。 |

### 7.3 P2/P3: 只有 P0/P1 过关后再考虑

| 功能 | 阶段 | 条件 |
| --- | --- | --- |
| 视频关联 | P2 | 用户已经持续记录 project。 |
| Coach sharing | P2 | 教练 beta 证明有需求。 |
| Board integration | P2/P3 | 针对 MoonBoard/Kilter 等标准化路线。 |
| Rope modes | P3 | 单独调研 belay/fall/route semantics。 |
| Gym route integration | P3 | 有明确岩馆合作。 |
| Social sharing | P3 | 个人价值已经成立。 |
| Personal ML | P3 | 数据量和 correction log 足够。 |

### 7.4 明确删除的功能

| 功能 | 删除原因 |
| --- | --- |
| Watch 上选择 Rope / Training Timer | 首屏分散，P0 只做 Boulder。 |
| Watch 上完整输入 grade/project | 休息窗口不应变成填表。 |
| 自动 send/fail/flash | 无法从单腕数据可靠判断。 |
| 疲劳评分作为主功能 | 证据不足，容易医疗化。 |
| 户外 safety | 责任风险大，P0 不碰。 |
| 路线库和社区 | 冷启动重，不是核心闭环。 |

---

## 8. Watch / iPhone 分工

### 8.1 Watch-first, not Watch-only

| 层 | Watch | iPhone |
| --- | --- | --- |
| Capture | 开始、结束、计时、HR、motion、Try/Send/Fail/Undo。 | 可远程查看当前 session，但不是主入口。 |
| Truth | 只记录用户当下标记和 suggested candidate。 | 训练后确认 canonical truth。 |
| Review | 极简结束摘要。 | 完整 timeline、project 绑定和修正。 |
| Memory | 显示 last project shortcut。 | 管理 active projects 和长期历史。 |
| Rest context | 柔和 rest reminder。 | 长期 rest pattern 分析，不做恢复诊断。 |

### 8.2 Watch P0 信息架构

```text
Home
  Start Boulder
  Last Session
  Sync Status

Active Session
  Session Time
  Heart Rate
  Rest Time
  Attempts
  Try / Send / Fail
  Undo
  Pause
  End (long press)

End Summary
  Duration
  Attempts
  Sends
  Avg Rest
  Sync State
```

Watch 上不要出现复杂设置、长解释、路线搜索、趋势图、社区入口。

### 8.3 iPhone P0 信息架构

```text
Pending Review
  Session summary
  Manual timeline
  Optional suggested candidates
  Unconfirmed events
  Quick confirm

Session Detail
  Attempts timeline
  Send / fail list
  Rest pattern
  HR chart
  Edit duration

Project Basics
  Recent projects
  New project
  Unassigned attempts

History
  Recent sessions
```

### 8.4 交互预算

| 预算项 | P0 目标 |
| --- | --- |
| 开始训练 | <= 5 秒。 |
| 单次下墙标记 | <= 3 秒。 |
| 单小时点击量 | 中位 <= 20 taps/hour。 |
| End session | 长按确认，<= 5 秒。 |
| 训练后 review | 初次 <= 90 秒，熟练 <= 60 秒。 |
| Watch 页面层级 | 训练中不超过 2 层。 |
| 单屏文本 | 大数字 + 极短标签，不写解释性文案。 |

如果交互预算过不了，产品会比备忘录更烦。

---

## 9. 数据模型和复盘设计

### 9.1 关键实体

| 实体 | 字段 | 来源 |
| --- | --- | --- |
| Session | id、start/end、duration、source、workout id、sync state | Watch / HealthKit |
| Attempt | start/end、result、source、confidence、corrected、project_id | 用户标记 + suggested timeline |
| RestView | start/end、duration、before/after attempt、HR context | Watch timer + timeline 派生视图，不作为 P0 独立持久化对象 |
| Project | name/nickname、grade、color、wall、status、notes | iPhone 用户输入 |
| Correction | changed field、old/new、time、reason optional | iPhone review |
| Recap | generated summary、待确认项、用户确认后的 next-session cue | iPhone |

### 9.2 数据来源和真相等级

| 真相等级 | 来源 | 例子 | UI 话术 |
| --- | --- | --- | --- |
| User confirmed | 用户手动标记或 iPhone 确认 | Send、Fail、Project A | Confirmed |
| System recorded | Workout/HealthKit 事实 | session time、HR samples | Recorded |
| Suggested | motion/time/HR 候选 | possible attempt、possible rest | Suggested |
| Inferred | 规则派生 | possible flash only if user confirms first attempt + project identity | Inferred |
| Unknown | 数据不足 | unclear segment | Needs review |

原则：

> UI 里永远不要把 Suggested 写成 Detected。

### 9.3 Recap 层级

| 层级 | 回答的问题 | P0/P1 |
| --- | --- | --- |
| Session recap | 今天练了什么？训练节奏如何？ | P0 |
| Attempt recap | 哪些 attempt 是 send/fail？休息多久？ | P0 |
| Project recap | 哪条线推进了？哪条卡住了？ | P1 |
| Trend recap | 最近 4 周有什么变化？ | P1 |
| Next-session cue | 用户确认的下次回忆提示是什么？ | P0b 可手动保存，P1 起强化 |

### 9.4 P0 Recap 模板

P0 不要做泛泛总结，要尽量变成攀岩语言：

```text
78 min session
18 attempts, 5 sends
Avg rest 2:42

Your second half had longer rests and fewer sends.
3 attempts need review.
Project A: 6 attempts, no send yet.
Save as cue? Start with Project A after warmup.
```

中文版本：

```text
本次训练 78 分钟
18 次尝试，5 次完成
平均休息 2:42

后半段休息变长，send 率下降。
还有 3 个候选尝试需要确认。
Project A：6 次尝试，暂未完成。
可保存为下次回忆提示：热身后先回到 Project A。
```

### 9.5 Correction log 的战略价值

用户修正不是失败，而是数据飞轮：

| Correction 类型 | 能学到什么 |
| --- | --- |
| 删除 false attempt | 哪些 motion pattern 容易误报。 |
| 合并 attempt | 用户真实 attempt 时长边界。 |
| 修改 result | 用户下墙后标记习惯和错误率。 |
| 绑定 project | 哪些时间线需要 route identity。 |
| 修改 session end | 忘记结束的检测规则。 |

P0 应该把 correction log 做成轻量一等数据，而不是简单覆盖；但 UI 必须让用户感到“是在帮自己保存正确记忆”，不是在给模型打工。

---

## 10. 平台和技术合同

### 10.1 Apple 平台能力

| 能力 | 官方/平台事实 | 产品用途 | 风险 |
| --- | --- | --- | --- |
| Apple Watch Workout | Apple Watch 原生支持 Climbing workout。 | 系统运动入口、Health/Fitness 生态。 | 原生只给泛运动数据。 |
| HKWorkoutSession | Watch 上一次只能运行一个 workout session。 | P0 必须处理被其他 workout 抢占。 | lifecycle 复杂。 |
| HealthKit 权限 | 读写健康数据需要明确授权。 | HR、workout、energy、历史。 | 拒权后要降级。 |
| Core Motion | 可访问加速度、陀螺仪等 motion 数据。 | attempt/rest 候选。 | 单腕数据误报多。 |
| WatchConnectivity | Watch/iPhone 可传输用户数据。 | 离线后补传、review 同步。 | 乱序、重试、重复。 |
| WKBackgroundModes | workout-processing 支持 active workout session 相关后台运行。 | workout 期间后台记录。 | 必须配置正确并真机验证；系统仍可能因后台 CPU、内存、电量等因素限制 App。 |
| Haptics | 手腕触觉提醒。 | rest reminder。 | 不能频繁打扰。 |

### 10.2 Platform Gates

| Gate | 必须验证 |
| --- | --- |
| Workout lifecycle | start、pause、resume、end、discard、crash recovery、another workout started。 |
| Permission degrade | HealthKit、motion、HR 任一权限拒绝后，仍可手动记录 session。 |
| Local durability | iPhone 不在附近、断连、低电量、App 崩溃后，已 checkpoint 的 session 最大限度保留；断电/崩溃前未落盘数据不做绝对承诺。 |
| Sync integrity | retry、ack、去重、乱序、pending 状态、重复 session 防护。 |
| Battery | 90 分钟真实抱石 session 电量消耗在可接受范围；低电量进入 essential mode。具体阈值需真机 beta 校准。 |
| Device matrix | 不同 Watch 型号、watchOS、左右手佩戴、主力手差异。 |
| App Review | HealthKit 用途、隐私、非医疗声明、订阅说明。 |

### 10.3 Sync 状态机

```text
Recording on Watch
  -> Saved locally
  -> Pending transfer
  -> Transferred to iPhone
  -> Review pending
  -> User confirmed
  -> Canonical session
  -> Optional export / backup
```

失败状态：

| 状态 | 用户看到什么 | 系统做什么 |
| --- | --- | --- |
| iPhone unavailable | Saved on Watch | 等待连接后补传。 |
| transfer failed | Sync pending | retry + 保留本地。 |
| duplicate detected | Already synced | 去重，不重复显示。 |
| review not done | Needs review | 不生成强结论。 |
| HealthKit write failed | Workout not saved to Health | 允许重试，保留 App session。 |

### 10.4 Low Power / Essential Mode

当低电量或高耗能风险出现时：

| 正常模式 | Essential mode |
| --- | --- |
| HR + workout + motion candidates + haptics | workout + manual event + low-frequency checkpoint |
| suggested timeline | 关闭或降低采样 |
| rest haptics | 可保留少量 |
| rich display | 大数字简化 |

核心原则：

> 电量不足时可以牺牲智能候选，不能牺牲已落盘记录、用户手动标记和可恢复同步。

### 10.5 Claim Language Rules

| 可以说 | 不要说 |
| --- | --- |
| Suggested attempts | Automatically detects every climb |
| Helps review rest patterns | Measures fatigue accurately |
| Records user-marked sends/fails | Knows whether you sent the route |
| Apple Health compatible | Replaces medical or safety judgment |
| Low-interruption training log | Hands-free full climbing coach |
| Editable recap | AI truth engine |

---

## 11. 算法和数据验证

### 11.1 算法边界

P0 算法目标不是识别动作，而是减少复盘整理成本。

| 可以尝试 | 不应承诺 |
| --- | --- |
| climbing/resting/idle/uncertain segment candidate | hold、脚法、beta、动作类型。 |
| possible attempt start/end | route 完成百分比。 |
| rest duration | 疲劳医学判断。 |
| motion intensity proxy | 精确训练负荷。 |
| HR context | 安全建议、恢复判断或 readiness 评分。 |

### 11.2 P0 规则基线

| 模块 | 输入 | 输出 | 规则 |
| --- | --- | --- | --- |
| Activity burst | accelerometer/gyroscope variance | possible attempt | 运动强度超过个人 baseline 且持续一定窗口。 |
| Rest detection | low motion + elapsed time | rest segment | 用户标记后或 activity burst 后进入 rest。 |
| Attempt candidate | burst + rest boundary | candidate attempt | 只在 iPhone review 中展示。 |
| Session anomaly | 长时间低 motion、超长 session | forgot-to-end hint | 结束后提示裁剪。 |
| HR context | HR zone / post-attempt HR pattern | context only | 不下医学结论，不输出恢复/疲劳判断。 |

### 11.3 数据采集计划

旧版设想的 150-300 attempts 不够验证产品可用性。更合理的验证拆成 alpha 和 beta：

Alpha 先证明行为闭环，不把算法数据规模作为 MVP 前置门槛：

| 项目 | 目标 |
| --- | --- |
| 用户 | 5-10 位高意愿目标用户。 |
| sessions | 10-20 场真实抱石训练。 |
| 重点 | 戴表、下墙标记、quick save、训练后 review、下次 reopen。 |

Beta 再验证候选分段和跨设备稳定性：

| 项目 | 目标 |
| --- | --- |
| 用户 | 30-50 位目标用户。 |
| sessions | 60-100 场真实抱石训练。 |
| attempts | 1000-2000 次 attempt。 |
| ground truth | 部分 session 视频标注 + 用户 review correction。 |
| 设备 | 至少覆盖 3-4 类 Watch 型号。 |
| 佩戴 | 左右手、主力手/非主力手记录。 |
| 场景 | 热身、project、社交休息、走动、喝水、擦镁粉等。 |

### 11.4 标注体系

| 标签 | 定义 |
| --- | --- |
| attempt_start | 用户开始一次明确路线尝试。 |
| attempt_end | 用户落地、放弃或完成。 |
| result | Try / Send / Fail / Unknown。 |
| rest_start/end | 用户进入/结束休息。 |
| false_activity | 走动、喝水、聊天、整理装备、擦镁粉等。 |
| project_id | 用户确认的路线/project。 |
| correction_type | delete、merge、split、result_change、time_adjust。 |

### 11.5 算法成功指标

算法不是首个 market proof，但它决定产品能不能降本。
以下是初始 beta 假设，不是最终上线标准；需要按用户、Watch 型号、左右手、主力手/非主力手分层报告。

| 指标 | 初期目标 |
| --- | --- |
| Rest segmentation quality | IoU / boundary tolerance 达到可用，且不显著增加 review cost |
| Attempt candidate recall | > 80% |
| Attempt candidate precision | > 60%，但必须可快速删除 |
| False positives per hour | 中位可接受，目标 < 5 |
| Review correction time | 中位 < 60 秒 |
| User trust | 不把候选说成事实，主观信任 >= 4/5 |

如果算法没过，但手动闭环过了，可以继续做 manual-first 产品。  
如果手动闭环没过，算法再好也救不了。

---

## 12. UI/UX 原则

### 12.1 Watch 原则

| 原则 | 实现 |
| --- | --- |
| 一眼可读 | 大数字：Session、Rest、HR、Attempts。 |
| 休息时交互 | 攀爬中不弹窗。 |
| 少按钮 | Try / Send / Fail / Undo 是核心。 |
| 可撤销 | Undo 必须明显。 |
| 长按危险操作 | End session 长按确认。 |
| 默认静默 | 触觉提醒可开关。 |
| 不填表 | grade/project 训练后补。 |
| 状态清晰 | Sync pending、Saved on Watch、Low Battery。 |

### 12.2 iPhone 原则

| 原则 | 实现 |
| --- | --- |
| 先 review pending | 用户打开先看到待确认 session。 |
| 一屏看懂 | 先 summary，再 timeline。 |
| 修正低成本 | 合并/删除候选、改 result、绑定 project。 |
| 长期记忆 | active projects 放在首页明显位置。 |
| 数据可信 | 显示 source: user / suggested / confirmed。 |
| 不堆图表 | P0 不做复杂仪表盘。 |

### 12.3 P0 页面

Watch:

```text
Start Boulder
--------------
Active Session
  42:18
  Rest 02:14
  HR 138
  Attempts 9
  [Try] [Send] [Fail]
  [Undo] [Pause] [End]
--------------
Saved
  78 min
  18 attempts
  5 sends
  Sync pending
```

iPhone:

```text
Pending Review
  78 min session
  18 attempts suggested/confirmed
  3 need review
  Confirm all / Review timeline

Session Detail
  Timeline
  Rest pattern
  HR context
  Attempts list
  Bind projects

Project Memory
  Active projects
  Last attempts
  Next-session cue
```

---

## 13. 商业化和增长

### 13.1 商业判断

这个产品商业上可能成立，但不是大而全平台逻辑。

| 判断 | 说明 |
| --- | --- |
| 小而尖可能成立 | 高频训练用户可能愿意为长期复盘和 project memory 付费，但必须通过假门验证。 |
| 平台化不能先假设 | route/community/gym network 都需要更强分发和数据。 |
| 订阅需谨慎 | 早期价值密度未证明前，月订阅容易被拒绝。 |
| 一次性/终身更适合早期 | 降低心理门槛，测试付费意愿。 |
| Pro 候选应建立在长期价值上 | 趋势、project analytics、导出、可配置 rest pattern、视频关联；是否付费要继续验证。 |

### 13.2 免费/付费边界

| 免费版 | Pro 版候选 |
| --- | --- |
| Watch 记录基础 session | 无限历史。 |
| 最近 N 次 session | 长期趋势。 |
| 基础 attempt/rest/send 复盘 | Project analytics。 |
| HealthKit 写入 | 可配置 rest 提醒和 rest pattern 分析。 |
| 基础 project | 数据导出。 |
| 本地存储 | 视频关联、教练共享。 |

### 13.3 增长路径

| 渠道 | 用法 |
| --- | --- |
| 岩馆/教练 | 找种子用户和真实训练数据，不先卖 SaaS。 |
| 小红书/B站/YouTube | 展示“不掏手机记录抱石训练”和训练后复盘。 |
| Reddit/Mountain Project | 找数据控和早期 beta 用户。 |
| App Store SEO | bouldering tracker、climbing log、Apple Watch climbing。 |
| Apple Health/Fitness 用户 | 强调补足 Apple Workout 攀岩语义。 |
| Creator/教练合作 | 用 project review 和训练复盘做内容。 |

### 13.4 付费假门

在 beta 中可测试：

| 付费点 | 假门问题 |
| --- | --- |
| Lifetime unlock | 用户是否愿意一次性买断？ |
| Pro yearly | 用户是否认为长期趋势值得年付？ |
| Export | 数据控是否愿意为导出付费？ |
| Coach share | 教练/学员是否有真实协作需求？ |
| Video link | project 用户是否愿意把视频和 attempt timeline 绑定？ |

---

## 14. 验证计划和 Go/No-Go

### 14.1 4-6 周验证路线

| 周期 | 目标 | 交付/验证 |
| --- | --- | --- |
| Week 1 | 访谈和需求验证 | 12-15 位 ICP 访谈，确认佩戴、标记、复盘意愿。 |
| Week 2 | 原型验证 | Watch rest-window 操作原型，测试 3 秒标记。 |
| Week 3 | 技术 spike | Workout、HealthKit、local save、sync prototype。 |
| Week 4 | Internal dogfood / small alpha | 5-10 位高意愿用户，记录 10-20 场真实 session，先验证手动闭环和数据持久性。 |
| Week 5-6 | TestFlight beta | 若 alpha 通过，再扩到 30-50 位用户，记录 60-100 场真实 session。 |
| Week 6 | Go/No-Go | 用硬指标决定继续、pivot 或停止。 |

### 14.2 Go/No-Go 指标

以下阈值是内部 beta 假设，不是行业基准；第一次真实 beta 后需要校准。

| 类型 | Gate | Go | Pivot | No-go |
| --- | --- | --- | --- | --- |
| Product | Wearability | >= 60% ICP 愿意整场戴表 | 40-60% | < 40% |
| Product | Friction | 70% session 独立完成，<= 20 taps/hour，打断评分 >= 4/5 | 操作负担偏高但可优化 | 用户普遍觉得烦 |
| Product | Recall | 60% session 24h 内打开，40% 下次训练前回看 | 打开但不影响行为 | 用户不看 |
| Commercial | Retention | 4 周内 35% 用户记录 >= 4 次 | 20-35% | < 20% |
| Commercial | WTP | 完成 >=3 次 session 用户中假门转化 >= 8% | 3-8% | < 3% |
| Channel | Channel | 至少找到 1 条可重复 ICP 渠道 | 只有零散用户 | 无渠道 |
| Trust | Data trust | 修正时间 < 60 秒，主观信任 >= 4/5 | 需弱化自动候选 | 用户不信 |

### 14.3 访谈问题

1. 你现在如何记录抱石训练？
2. 最近一次训练后，你还记得哪条线试了几次吗？
3. 你是否在抱石时戴 Apple Watch？为什么戴/不戴？
4. 下墙后你愿意花 1-3 秒点一下结果吗？
5. 一场训练中最多愿意点多少次？
6. 训练后你愿意花 30-60 秒确认记录吗？
7. 什么样的 recap 会让你下次训练前打开？
8. 你现在用 Apple Workout / Strava / 备忘录 / Excel / 照片吗？
9. 这些工具哪里够用，哪里不够？
10. 你是否愿意为长期 project 追踪和复盘付费？
11. 你最怕这个 App 在训练中怎么打扰你？
12. 如果自动识别不准但可修正，你能接受到什么程度？
13. 你什么时候完全不想记录，为什么？
14. 记录 attempt/send/grade 会不会让训练变得更焦虑或没意思？
15. 什么样的提示会让你觉得是在帮你，而不是在评价你？

---

## 15. 风险和应对

| 风险 | 等级 | 应对 |
| --- | --- | --- |
| 用户不愿戴表 | 极高 | 先访谈和岩馆实测，不把不戴表用户纳入 P0。 |
| 下墙标记仍太烦 | 极高 | 压缩到 1-3 秒，减少按钮，训练后补信息。 |
| 复盘没有 aha moment | 极高 | recap 必须指向 project 和 next-session cue。 |
| 自动候选误报多 | 高 | Suggested only，可删可合并，manual-first 仍成立。 |
| HealthKit/Workout 复杂 | 高 | P0 前置平台 spike，真机验证 lifecycle。 |
| 同步丢数据 | 高 | local-first、checkpoint、ack/retry、pending state。 |
| 电量不可接受 | 高 | essential mode，降低 motion 采样。 |
| App Review 风险 | 中高 | 非医疗、非安全承诺，隐私和 HealthKit 用途清楚。 |
| 付费弱 | 中高 | 早期一次性/假门，指标不过不扩 Pro。 |
| 竞品快速复制 | 中 | 用 correction log、project memory、用户习惯建立深度。 |

---

## 16. 未来方向

### 16.1 近期方向

1. 把本报告转成 `climbing_bouldering_prd_v0_1.md`；
2. 写 `data_collection_plan`，定义真实抱石采集协议；
3. 写 `platform_contract`，明确 HealthKit、Workout、Motion、Sync、Privacy；
4. 做 Watch 低保真原型，验证休息窗口一键标记；
5. 找 12-15 位 ICP 做访谈；
6. 先组织 5-10 位 small alpha，过关后再扩 30-50 位 TestFlight beta。

### 16.2 中期方向

| 方向 | 触发条件 |
| --- | --- |
| Project analytics | 用户持续绑定 project。 |
| 4-week trend | 4 周留存过关。 |
| Rest pattern display | 有足够可信 correction/HR/rest 数据；只展示模式，不输出恢复判断。 |
| Coach sharing | 教练用户明确愿意采用。 |
| Video linking | project 用户高频使用且愿意管理视频。 |

### 16.3 远期方向

| 方向 | 注意事项 |
| --- | --- |
| Rope mode | 需要独立研究 belay、fall、route duration、高度和安全语义。 |
| Gym integration | 不做自建路线库，除非有明确岩馆合作。 |
| Board integration | MoonBoard/Kilter 这类标准化路线更适合精细记录。 |
| Social/community | 个人价值成立后再考虑分享，不先做 feed。 |
| ML personalization | correction log 和真实数据足够后再做。 |

---

## 17. 阶段结论：P0 立项判断

这个产品应该继续，但必须非常克制。

最值得做的不是一个“攀岩大平台”，而是：

> **一个面向室内抱石训练者的 Watch-first / iPhone-review session memory tool。**

它的核心不是传感器识别，而是三个行为是否成立：

1. 用户愿意抱石时戴表；
2. 用户愿意下墙后低成本标记；
3. 用户愿意训练后完成低成本 review，并在下次训练前回看。

如果这三件事成立，产品可以进入 P1 探索 project analytics、长期趋势等更深能力；coach、video、训练计划需要各自独立验证。  
如果任何一件事不成立，这个产品就不应该继续扩成平台，而应该 pivot 成更轻的 logbook、训练后 iPhone 工具，或作为其他攀岩生态的 feature。

最终一句话：

> **先证明“低干扰记录 + 可修正复盘 + 下次训练记忆”能替代 Apple Workout + Notes，再谈 AI、平台和商业化。**

---

## 18. Appendix A: 第二轮循环讨论：更深层产品认知

这一轮讨论故意不再只问“P0 怎么收窄”，而是让 5 个 PM 带着偏见、重叠和冲突重新调研。最终结论比上一轮更宽，但也更清楚：

> 上一版的 `session memory layer` 是对的，但还不够深。更完整的内部产品模型应该是 **Rhythm Capture + Recall Retrieval + Proof/Trust**。

中文一句话：

> **手表管节奏，手机管记忆；复盘不是终点，下次训练前能取回才是产品。**

### 18.1 第二轮 PM 争论摘要

| 争论 | 第一种观点 | 第二种观点 | 最终收敛 |
| --- | --- | --- | --- |
| `rest timer` 是不是核心？ | 休息报时和触觉锚点可能是最强现场 loop。 | Timer 极易商品化，Apple/Garmin/Strong/Hevy/Crimpd 都能做。 | Timer 不是 moat，但它是 habit wedge；要进 P0，但不能当主卖点。 |
| `session recap` 是否足够？ | 训练后 recap 能形成价值。 | 用户更关心下次训练前能否回想上次卡点。 | Recap 是清洗层，pre-session recall 才是产品层。 |
| 主观状态要不要做？ | 疼痛、恐惧、RPE、失败原因是深层训练变量。 | 这些很容易变成填表地狱。 | 后台按图谱设计，前台只暴露极少量高价值标签。 |
| Watch 能否承载更多？ | Watch 可以成为训练中的 rhythm layer。 | Watch 不能做知识图谱编辑器，也不能做复杂输入。 | Watch 只产出 low-entropy anchors，iPhone 才负责 identity、meaning、memory。 |
| 长期怎么扩？ | 继续扩 rope/outdoor/gym/community。 | 更应该扩 board/hangboard/strength 这些训练语法。 | 先扩训练语法，不先扩攀岩模式。 |
| AI 应该做什么？ | AI 可以做训练后整理和回忆辅助。 | AI 很容易变成伪智能和不可信结论，训练中实时 AI 还有电量、延迟、隐私和后台风险。 | P0 训练中只用本地轻量规则；AI 只做训练后 review/recall，且不做事实裁判和实时教练。 |

### 18.2 新的核心模型：Rhythm + Recall + Proof

| 层 | 核心问题 | 主要设备 | 产品价值 |
| --- | --- | --- | --- |
| Rhythm Capture | 训练现场怎么少打断地留下锚点？ | Watch | 开始、休息、尝试结果、稀疏触觉、状态切换。 |
| Recall Retrieval | 下次进馆前怎么取回上次最重要的信息？ | iPhone + Watch glance | 上次卡点、project cue、失败原因、下次先做什么。 |
| Proof / Trust layer | 这些记录为什么可信、可追溯、可复用？ | iPhone / data layer | correction log、project anchor、主观状态、长期趋势、教练/导出。 |

关键变化：

| 旧理解 | 新理解 |
| --- | --- |
| 记录一次 session | 留下能跨 session 复用的训练记忆。 |
| 训练后 recap 是价值兑现 | 训练后 review 是清洗层，下次 recall 才是价值兑现。 |
| rest timer 是一个功能 | rest anchor 是行为入口，但不是护城河。 |
| attempt/rest/send 是核心数据 | project anchor + blocker + next cue 才能把事件变成记忆。 |
| AI 生成总结 | AI 帮用户找回、归档、压缩和修正线索。 |

### 18.3 深层需求挖掘

| 深层需求 | 表层表达 | 更深的产品解释 | 应对方式 |
| --- | --- | --- | --- |
| 记忆 retrieval | “我忘了上次怎么爬的” | 用户不是要归档，而是要在正确时刻取回 beta / crux / next move。 | pre-session recall、project card、next cue。 |
| 控制感 | “我老是休息不够就上” | 训练现场会被挫败、社交、冲动和 grade 焦虑带走。 | rest anchor、稀疏 haptic、session intent。 |
| 身份和进步证明 | “我到底有没有进步” | 不只是 grade，还是成为更会训练的 climber。 | proof graph、非 grade 进步、project continuity。 |
| 主观状态可采纳 | “今天状态怪怪的” | 疼痛、恐惧、犹豫、皮肤、psych 不是噪声，但不能被产品诊断化。 | minimal blocker tags、session focus、optional RPE。 |
| 训练仪式 | “我每次都乱打一场” | 固定轻流程能帮助用户从随机尝试进入训练状态。 | warmup intent、rest cue、end closure。 |
| accountability | “我想给教练/搭子看” | 记录变成可协作、可追责、可讨论的证据。 | P1/P2 coach share、export、annotated recap。 |
| 避免焦虑放大 | “我不想被数据羞辱” | send rate、grade、公开排名可能制造更多焦虑。 | private-by-default，不做公开 feed，不把 grade 当唯一进步语言。 |

### 18.4 关于“报时 / 节奏 / 提醒”的最终判断

如果这里的“报时”指普通倒计时器，它不值得单独做；如果指训练中的节奏锚点，它非常值得做。

| 形态 | 是否值得做 | 原因 |
| --- | --- | --- |
| 普通 timer | 不作为主卖点 | 极易商品化，系统和训练 App 都能做。 |
| Rest anchor | P0 必须做 | 抱石最稳定、最高频、最适合 Watch 的状态切换。 |
| 稀疏 haptic cue | P0/P1 | 能减少看屏，但必须可关闭、低频。 |
| Continuous metronome | 拒绝 | 违背攀岩注意力，也有电量、触觉、心率采集风险。 |
| Warmup / end ritual | 可测 | 能形成训练仪式，但不能变成填表。 |
| Ready cue | 可测 | 只能说 “ready when you are”，不能说“你恢复好了”。 |

最终判断：

> Rhythm 是入口，Recall 是留存，Proof 是付费资产。

### 18.5 最小 P0 数据 schema

第二轮讨论后，数据模型被重新压缩。后台可以按 graph 想，但 P0 前台不能像图谱编辑器。

| 对象 | P0 必要字段 | 作用 |
| --- | --- | --- |
| `Session` | `id`, `start_at`, `end_at`, `modality=boulder_indoor`, `venue_label?`, `healthkit_workout_id?`, `review_state` | 记忆边界和 HealthKit 连接。 |
| `ProjectAnchor` | `id`, `status`, `label?`, `grade_text?`, `color_or_set?`, `sector?`, `next_cue_text?`, `next_cue_source?` | 把 attempt 挂到持续对象上。 |
| `Attempt` | `id`, `session_id`, `project_id?`, `start_at`, `end_at`, `outcome`, `source`, `confidence?`, `needs_review`, `blocker_tag?` | 现场最小语义单位。 |
| `Correction` | `id`, `entity_type`, `entity_id`, `field`, `old_value`, `new_value`, `created_at` | 可信度、可追溯和后续模型学习。 |

P0 暂不把 `RestBlock` 做成独立对象。  
Rest 先从 attempt 间隔和 session timeline 推导，等需要区分正常休息、社交、排队、中断时再升级。

P0 也不做通用 `Artifact` 大表。  
P0 只支持 `label / grade_text / color_or_set / sector / next_cue_text`。照片、视频、语音、丰富素材放 P1/P2。

### 18.6 P0 主观字段：只保留最少但最高信息密度

| 主观字段 | P0 形式 | 进入原因 |
| --- | --- | --- |
| `session_focus` | `project / volume / technique / mixed` | P0 默认字段，解释 session 目标，避免所有训练都被 send 率评判。 |
| `blocker_tag` | 每个活跃 project 可选 1 个主阻塞 | P0 可选字段，把 fail 变成下次可行动线索。 |
| `session_rpe` | 训练后 1 个分值 | P0.5/P1 可选字段，低成本但仍需验证负担。 |
| `mark_affected_training` | 用户主动标记“今天状态影响训练” | P1/P2；不在 P0 记录部位和强度。 |

建议的 `blocker_tag` 最小枚举：

| Tag | 含义 |
| --- | --- |
| `beta` | 读线或动作序列不清。 |
| `technique` | 脚法、身体位置、重心、节奏问题。 |
| `strength_power` | 纯发力不足。 |
| `power_endurance` | 后段掉强度。 |
| `commit_hesitation` | 不敢做、犹豫、动态动作 commit 不够。 |
| `skin` | 皮肤状态影响。 |
| `unknown` | 不确定。 |

明确不进 P0：

| 不进 P0 | 原因 |
| --- | --- |
| 每次 attempt 单独 RPE | 输入成本过高。 |
| fear / confidence / motivation / mood / stress / sleep 全量问卷 | 变成填表地狱。 |
| 每次失败写 beta 文本 | 训练现场成本太高。 |
| 每次都上传照片/视频 | 素材管理会拖垮 MVP。 |
| 精细 body map | 容易医疗化，且输入成本高。 |
| route angle / hold type / style taxonomy 完整表单 | 太像路线库和训练数据库。 |

### 18.7 Watch 端硬边界

Watch 端不是知识图谱端，也不是训练语法端。Watch 只负责：

1. 拥有 session；
2. 稳住节奏；
3. 留下锚点；
4. 触发回想。

硬规则：

| Rule | 说明 |
| --- | --- |
| 主流程不超过 `1 屏 + 1-2 手势` | 任何多层输入都转 iPhone。 |
| 任一时刻只暴露一个主对象 | 默认 active project，不做多项目浏览。 |
| 主观输入优先离散标签 | 自由文本只做兜底，不做主流程。 |
| Rich memory 在 iPhone resolve | Watch capture，iPhone 解释。 |

Watch 可承载：

| 需求 | Watch 形态 |
| --- | --- |
| 控制感 | Start / Rest / Resume / Send / Fail / Undo。 |
| 节奏管理 | rest timer、稀疏 haptic、Always-On glance。 |
| project 连续性 | 当前 active project / 最近 1-3 个 project。 |
| 主观状态 | `Mark for review` 或少量离散标签。 |
| pre-session recall | App 内一屏 last project cue；complication / Smart Stack 需平台 spike 后再进 P1。 |

Watch 不承载：

| 不承载 | 原因 |
| --- | --- |
| project management | 小屏不适合编辑。 |
| 图谱浏览和编辑 | 信息密度过高。 |
| 媒体归档 | iPhone 更适合。 |
| 技术动作分析 | 单腕数据不足。 |
| 连续触觉节拍 | 打扰、耗电、平台约束。 |

### 18.8 AI 介入边界

AI 的第一角色不是 coach，而是：

> **书记员 + 索引器 + 复盘助手。**

| 时机 | 可以做 | 不可以做 |
| --- | --- | --- |
| 训练前 | 找回 last project cue、上次 blocker、下次先做什么。 | 强行安排训练计划。 |
| 训练中 | 本地轻量规则生成 suggested segmentation、rest cue、低置信候选、必要时 mark for review。 | 实时 AI 技术指导、强提醒、恢复判断。 |
| 训练后 | 整理 timeline、抽取 blocker、生成待用户确认的 draft cue、提示待确认项。 | 把猜测当事实。 |
| 跨 session | pattern mining、context-conditioned insights。 | 单一 readiness score 决定该不该练。 |

AI 产品规则：

1. AI in P0 is not required for the manual-first loop; if enabled, it is only for post-session recall and review, not for truth or coaching.
2. AI 只能做 `suggested`，不能做 final judgment。
3. `send/fail/project identity` 优先来自用户确认。
4. 数据优先级固定为：`user correction > explicit tap > attached anchor > sensor inference > LLM summary`。
5. 所有 AI 输出必须可编辑、可删除、可覆盖。

### 18.9 更准确的路线图

上一版路线图的远期方向仍然有价值，但第二轮后应该改成“先扩训练语法，不先扩攀岩模式”。

| 阶段 | 产品定义 | 核心目标 |
| --- | --- | --- |
| P0 | Capture + Review | 成为一次室内抱石 session 的 user-confirmed source of record，并验证下次训练前是否会被重新打开。 |
| P1 | Memory -> Decision | 加入少量主观标签、project card、pre-session cue、最近 3 次对比、简单导出/share。 |
| P2-A | Training System | 扩 board / hangboard / accessory strength，形成 attempt/interval/rest/progression 统一训练语法。 |
| P2-B | Coach / Accountability | athlete share、coach comments、计划对照、训练群 review。 |
| P3 | Selective venue distribution | 只在有明确合作时做岩馆/教练分发，不做 gym OS。 |

更不推荐的路线：

| 路线 | 为什么不优先 |
| --- | --- |
| Rope-first | belay、fall、安全、route duration 是另一套语义。 |
| Outdoor-first | topo、天气、GPS、离线、风险更重要。 |
| Community feed | 过早做会放大比较焦虑。 |
| Gym SaaS | 已有重玩家，且销售/运营太重。 |
| General sports memory | 过早泛化会丢掉攀岩 wedge。 |

### 18.10 新的北极星和 kill gates

旧北极星“reviewed sessions”需要升级：

> **产生了可复用 next-session cue，并在下一次训练前被取回的 project sessions。**

新增指标：

| 指标 | 含义 |
| --- | --- |
| `project_anchor_rate` | 有多少 attempts/session 被绑定到 project anchor。 |
| `next_cue_created_rate` | 有多少 reviewed sessions 产生 next-session cue。 |
| `pre_session_reopen_rate` | 下一次训练前用户是否打开查看。 |
| `cue_used_rate` | 用户是否按 cue 回到 project 或修改训练决策。 |
| `subjective_tag_completion` | 用户是否愿意留下最少主观标签。 |
| `field_burden_score` | 新增字段是否让用户觉得烦。 |

新的 kill gates：

| Gate | No-go 触发 |
| --- | --- |
| Rhythm gate | 用户觉得 rest cue / haptic 打扰，或不愿在尝试后 1-2 秒标记。 |
| Recall gate | pre-session reopen 低于 30-35%。 |
| Project anchor gate | 多数 attempts 无法绑定到 project，导致回忆失效。 |
| Subjective burden gate | 主观标签使 review 完成率明显下降。 |
| Decision gate | 用户不认为 next cue 会影响下次训练。 |

### 18.11 第二轮最终结论

这轮讨论不是推翻上一版，而是把它往更深处推进：

| 上一版 | 第二轮后 |
| --- | --- |
| Watch-first session memory tool | Watch-backed rhythm capture + iPhone memory retrieval。 |
| Recap-led | Recall-led。 |
| Attempt/rest/send/project | Project anchor / blocker / next cue / correction log。 |
| P0 证明低干扰记录 | P0 证明低干扰锚点 + 下次可取回记忆。 |
| 未来做 project analytics / coach / board | 未来优先扩 board/hangboard/strength 训练语法，再考虑 coach/accountability。 |

最终产品口径：

> **不要把产品定义成攀岩 timer，也不要定义成攀岩记录器。把它定义成 Apple Watch 驱动的 attempt-based personal climbing memory system。**

最终 P0 只问三个问题：

1. 我练了哪些 project？
2. 我为什么没过，或者为什么过了？
3. 我下次进馆先打什么、先注意什么？

如果一个字段、页面、算法或提醒不能帮助回答这三个问题，就不该进入 P0。

---

## 19. Appendix B: 第三轮循环讨论：品类、可信性和长期 bets

第三轮继续让 5 个 PM 重新调研，并把观点互相反驳。与第二轮相比，这一轮不再增加功能，而是校准三个问题：

1. 这个产品到底属于什么 category？
2. `报时/节奏/状态切换` 在最终模型中是什么层级？
3. 主观状态、AI、隐私、长期商业路线应该如何进入主报告而不发散？

最终收敛：

> **Category 是 attempt-based training memory；time anchor 是交互原语；Proof 必须包含可信性/可采纳性；长期 bets 采用 3+2 结构。**

### 19.1 第三轮 PM 交叉结论

| 主题 | 争论 | 最终判断 |
| --- | --- | --- |
| Category | `climbing app`、`wearable journal`、`training OS`、`attempt-based sports memory` 哪个更准？ | 市场口径可说 Apple Watch 攀岩训练记忆 App；战略口径是 `watch-backed training memory system for attempt-based sports`。 |
| 报时 | 是不是可以成为独立产品？ | 否。报时是基础设施，状态切换是产品，跨 session recall 才是价值。 |
| Trust / Legitimacy | 是否应成为第四层？ | 不做 market-facing 独立层；并入 Proof，作为信任和主观状态可采纳性原则。 |
| 数据模型 | 是否要变成通用运动记忆平台？ | 否。P0 只服务抱石，新增 `Cue`；`AIProvenance` 延后到 P0.5/P1 或仅做内部审计。 |
| Journal Suggestions | 是否进 P0？ | 不进 P0；作为 P0.5/P1 隐私友好的 post-session enrichment。 |
| 长期路线 | 5 个 bets 是否并列？ | 否。主报告写 `3 个核心 bets + 2 个条件 bets`。 |

### 19.2 最终层级模型

第三轮把第二轮的 `Rhythm + Recall + Proof` 再次拆清楚：

| 层级 | 名称 | 解释 | 是否用户可见 |
| --- | --- | --- | --- |
| Category | `attempt-based training memory` | 产品所属战略类别：为离散尝试型训练保存可取回记忆。 | 部分可见 |
| Market wedge | `Apple Watch climbing training memory app` | 对外获客语言，用户能理解、能搜索。 | 可见 |
| Interaction primitive | `time anchor / state transition` | Watch 侧报时、休息锚点、try/rest/review 状态切换。 | 可见但不当卖点 |
| Value layer | `recall retrieval` | 下次训练前取回 active project、last blocker、next cue。 | 可见 |
| Trust layer | `Proof + Legitimacy` | correction log、manual override、suggestion provenance；若启用 AI，再扩展为 AI provenance。 | 部分可见 |
| Data implementation | `simple relational schema with future links` | P0 用简单关系模型，不做图谱系统；只保留未来可扩展关系。 | 不直接可见 |

最终中文定义：

> **面向离散尝试型训练的、由手表捕获低干扰锚点、由手机完成回忆取回、事实校正与可信复盘的训练记忆系统。**

### 19.3 报时 / 状态切换的最终位置

第三轮对“报时”的结论更硬：

| 判断 | 说明 |
| --- | --- |
| 报时不是 category | Apple Watch 原生 timer、Custom Workout、Garmin、Strong、Hevy、SmartWOD 都能覆盖大量 timer/interval 需求。 |
| 报时不是 moat | 用户不会为“能倒计时”长期付费。 |
| 报时是 P0 habit wedge | 休息锚点、稀疏触觉、状态切换能让用户在现场形成使用习惯。 |
| 状态切换才是产品 | `try -> rest -> retry -> switch project -> review -> recall` 是抱石训练的核心流程。 |
| 跨 session recall 才是价值 | 单场节奏没有复利；能被下次取回的 cue 才形成记忆资产。 |

P0 不做 timer app，而做：

```text
Start session
  -> Try / Send / Fail
  -> Rest anchor
  -> Sparse cue
  -> Review on iPhone
  -> Pre-session recall
```

要拒绝的方向：

| 拒绝 | 原因 |
| --- | --- |
| 连续触觉节拍器 | 打扰、耗电、破坏攀岩 flow，且平台能力不稳定。 |
| 复杂 interval builder | Apple Custom Workout 和大量 interval apps 已覆盖。 |
| ADHD/time-blindness 主定位 | 可借鉴外化时间原则，但不应病理化通用训练问题。 |
| “恢复好了，可以上” | 过度权威化，可能医疗化。 |

### 19.4 Trust / Legitimacy：主观状态如何进入 Proof

第三轮明确：`Legitimacy` 不做外部卖点，中文对外统一写“可信性/可采纳性”；它必须成为 Proof 的子层。

原因：

| 问题 | 如果没有 Legitimacy |
| --- | --- |
| 疼痛、恐惧、皮肤、犹豫 | 会被当成噪声，或被用户理解成“我太菜了”。 |
| AI 生成 recap | 可能变成不可追溯、不可质疑的权威结论。 |
| grade/send 统计 | 可能放大 plateau 焦虑。 |
| 教练分享 | 可能从自我调节工具变成监控工具。 |

新的 Proof 定义：

```text
Proof = objective trace
      + user correction
      + suggestion provenance
      + AI provenance when AI-generated outputs are enabled
      + subjective admissibility
```

主观状态采集原则：

| 原则 | 实现 |
| --- | --- |
| 只记录有后果的主观状态 | 只有影响 attempt、route choice、session end、next cue 时才记录。 |
| 用行为词，不用人格词 | 写 `fear/commitment`、`skin`、`pain`，不写“我不行”。 |
| event first, subjective second | 先有 attempt/project，再补一个 blocker。 |
| 一次只允许一个主阻塞 | 防止多标签堆叠。 |
| 默认可跳过 | 不让 review 卡在主观问题上。 |
| 不做趋势羞辱 | 不做 anxiety trend、confidence score、mental readiness score。 |
| 必须转成动作对象 | 主观标签要能形成 next cue、review bucket 或 coach discussion handle。 |
| 默认私有、可撤回 | coach/share 必须 item-level opt-in。 |

一句话原则：

> **Subjective state is allowed only when it explains behavior and improves the next attempt.**

### 19.5 P0 schema 第三轮修正

第二轮 P0 schema 为 `Session / ProjectAnchor / Attempt / Correction`。第三轮建议新增两个轻对象：

| 对象 | 是否进入 P0 | 理由 |
| --- | --- | --- |
| `Cue` | 进入 | next cue 是 recall 产品层，不应只是 `ProjectAnchor.next_cue_text` 字段。 |
| `SuggestionProvenance` | P0 进入但很薄 | 记录规则候选来源、置信度、接受/拒绝/覆盖。 |
| `AIProvenance` | P0.5/P1 或内部审计 | 只有 P0 真启用 AI-generated cue/recap 时才进入主 schema。 |
| `Governance` | 不作为业务主对象 | 保留隐私设置和授权记录即可，不做治理图谱。 |
| `JournalSuggestionArtifact` | P0.5/P1 | 作为用户显式选择的 post-session enrichment，不做事实来源。 |

P0 schema 更新建议：

| 对象 | 最小字段 |
| --- | --- |
| `Session` | `id`, `start_at`, `end_at`, `modality`, `venue_label?`, `healthkit_workout_id?`, `review_state` |
| `ProjectAnchor` | `id`, `status`, `label?`, `grade_text?`, `color_or_set?`, `sector?` |
| `Attempt` | `id`, `session_id`, `project_id?`, `start_at`, `end_at`, `outcome`, `source`, `confidence?`, `needs_review`, `blocker_tag?` |
| `Cue` | `id`, `project_id?`, `session_id?`, `text`, `cue_type`, `source`, `created_at`, `superseded_by?` |
| `Correction` | `id`, `entity_type`, `entity_id`, `field`, `old_value`, `new_value`, `created_at` |
| `SuggestionProvenance` | `id`, `target_type`, `target_id`, `producer=rule/manual`, `input_refs`, `confidence`, `status`, `created_at` |

`SuggestionProvenance.status` 只需要：

```text
suggested / accepted / rejected / superseded
```

防止 P0 变成数据平台的硬边界：

| 边界 | 说明 |
| --- | --- |
| 不用通用对象命名 | 避免 `Event / MemoryItem / Observation / Artifact / Entity` 这类过早泛化。 |
| 每个对象必须服务一个前台动作 | 不能回答“哪个页面/动作需要它”，就不进 P0。 |
| 不保留原始传感器仓库 | 原始 motion window 短期保留，review 后保留派生事实和 correction。 |
| 不做开放 ingestion | Journal Suggestions 必须用户显式附加到 session/project。 |
| 不为长期 bets 预留大而全 schema | 只留最小 extension point。 |

原始 motion window 的保留必须单独写隐私合同：默认本地短期保留、明确保留天数、默认不上云、用户可删除，debug export 必须显式开启。

### 19.6 Journal Suggestions 的位置

Apple Journal / Journaling Suggestions 值得写进报告，但只能写成 P0.5/P1。

| 判断 | 说明 |
| --- | --- |
| 值得关注 | Apple 已经把 workout、location、media、reflection 组织成用户显式选择的回忆入口。 |
| 不作为 P0 核心 | 它是 iPhone/iPad 侧补充，不是 Watch 侧现场 capture。 |
| 不作为事实来源 | 它提供 context，不决定 attempt/send/project truth。 |
| 隐私上有优势 | private access picker 方式比直接申请照片/位置权限更克制。 |

可写入路线：

```text
P0.5: Post-session enrichment
  -> Add context
  -> User selects workout/location/photo/reflection suggestion
  -> Attach to Session or ProjectAnchor
  -> Used only as recall cue evidence
```

### 19.7 长期 bets：从 5 个并列改成 3 + 2

第三轮认为 5 个 bets 不应平铺。应改成：

| 类型 | Bet | 是否写主线 |
| --- | --- | --- |
| Core Bet 1 | `Recall wedge / state-switch product` | 是，P0 主线。 |
| Core Bet 2 | `Trust / Apple-native proof layer` | 是，信任层。 |
| Conditional Bet 3 | `Training syntax expansion: board / hangboard / strength` | 条件成立后做，中长期扩张。 |
| Conditional Bet 4 | `Coach workflow / B2B2C` | 条件成立后做。 |
| Conditional Bet 5 | `Selective hardware partnerships` | 放 future options，不进主线。 |

每个 bet 的 gate：

| Bet | Kill gate |
| --- | --- |
| Recall wedge | `pre_session_reopen_rate < 35%` 或 `project_anchor_rate < 60%`。 |
| Proof layer | 用户不信 suggested/cue，或 suggestion override 后留存不提升。 |
| Training syntax expansion | 第二训练模态 8 周采用率 `< 25%`，或计划完成率 `< 40%`。 |
| Coach workflow | coach weekly review rate `< 20%`，或 athlete share opt-in `< 30%`。 |
| Hardware partnerships | 6 个月内没有 1 个数据型 partner + 1 个分发型 partner，或 partner signal 不提升转化/留存。 |

### 19.8 第三轮最终决策

| 决策 | 内容 |
| --- | --- |
| 决策 1 | 产品不定义为 timer、interval app、wearable journal、training OS。 |
| 决策 2 | 对外定义为 Apple Watch-backed private attempt-based climbing memory system。 |
| 决策 3 | 报时/状态切换属于 Watch-side interaction/control layer。 |
| 决策 4 | Watch 的价值不是会计时，而是在 try/rest/review 切换点低干扰地产生可信锚点。 |
| 决策 5 | 将 Proof 升级为 Trust/Legitimacy，包含 correction log、manual override、subjective cue、suggestion provenance；AI provenance 延后到启用 AI 后。 |
| 决策 6 | P0 前台暴露 `Session / ProjectAnchor / Attempt / Cue / Correction`；`SuggestionProvenance` 做薄支撑层。 |
| 决策 7 | Cue 进入 P0，必须 next-session oriented，不做泛 AI 总结。 |
| 决策 8 | P0 不依赖 AI；若使用 AI，只能用于训练后 review/recall，不做 truth 或 coaching。 |
| 决策 9 | roadmap 顺序固定为 `private bouldering memory wedge -> stronger recall/trust -> training system or coach workflow -> portability/partnerships`。 |
| 决策 10 | 新增 trust 指标：`pre_session_reopen_rate`, `cue_reuse_rate`, `project_anchor_rate`, `suggestion_accept_override_rate`, `review_completion_time`。 |

第三轮压轴结论：

> **报时不是这个产品的 category，也不是 moat；报时和状态切换是 Watch 侧低干扰控制层，用来为 attempt-based climbing memory 生产可信锚点。真正价值在下次训练前被重新打开的记忆，以及用户对这份记忆的信任感。**

---

## 20. Sources

### Apple / Platform

| Source | 用途 |
| --- | --- |
| [Apple Support: Workout types on Apple Watch](https://support.apple.com/en-euro/105089) | 确认 Apple Watch 原生支持 Climbing workout。 |
| [Apple Developer: HKWorkoutSession](https://developer.apple.com/documentation/HealthKit/HKWorkoutSession) | Workout lifecycle 和一次只运行一个 workout session 的平台约束。 |
| [Apple Developer: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions) | Workout session、builder、mirroring/recovery 等实现参考。 |
| [Apple Developer: Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) | HealthKit 权限原则。 |
| [Apple Developer: Core Motion](https://developer.apple.com/documentation/coremotion) | 加速度/陀螺仪等 motion 数据能力。 |
| [Apple Developer: WatchConnectivity transferUserInfo](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo%28_%3A%29) | Watch/iPhone 后台数据传输参考。 |
| [Apple Developer: WKBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes) | watchOS workout-processing 后台模式。 |
| [Apple Support: Apple Watch heart rate accuracy](https://support.apple.com/en-us/105002) | 心率准确性和佩戴/运动影响。 |
| [Apple Support: Low Power Mode](https://support.apple.com/en-nz/108320) | 低电量模式相关约束。 |
| [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Health、隐私、医疗/安全声明边界。 |
| [Apple Developer: Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos/) | Watch 应用应短交互、glanceable、低干扰。 |
| [Apple Developer: Always On](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state) | Always-On 适合静态状态和低频更新，不适合高频动画。 |
| [Apple Support: Smart Stack](https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/watchos) | pre-session recall / live state 的轻入口参考。 |
| [Apple Support: Custom workouts](https://support.apple.com/en-gb/guide/watch/apd66fcd5c5c/watchos) | work/recovery interval 已是系统能力，timer 本身不是 moat。 |
| [Apple Developer: Watch haptics](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play%28_%3A%29) | haptic 应稀疏使用，不能做连续高频节拍。 |
| [Apple Support: Timers on Apple Watch](https://support.apple.com/guide/watch/timers-apdf448955b2/watchos) | 纯 timer 已是系统能力，不构成独立 moat。 |
| [Apple Support: Mark workout segments](https://support.apple.com/en-ie/guide/watch/apd72879df4d/watchos) | workout 中可标记 segment，提示状态切换能力已部分平台化。 |
| [Apple Developer: WorkoutKit](https://developer.apple.com/documentation/WorkoutKit) | 创建、预览、同步 workout compositions 的长期平台能力；不是替代 HKWorkoutSession 的实时采集框架。 |
| [Apple Developer: Journaling Suggestions](https://developer.apple.com/documentation/journalingsuggestions) | P0.5/P1 post-session enrichment 和隐私友好 context picker 参考。 |
| [Apple Developer: Journaling Suggestions updates](https://developer.apple.com/documentation/updates/journalingsuggestions) | 2025 后 workout/location 等 suggestions 能力更新。 |
| [Apple: Journal app launch](https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments/) | Apple 对 workout、location、media、reflection 组合成回忆入口的产品方向。 |

### Market / Competitors

| Source | 用途 |
| --- | --- |
| [Climbing Business Journal: Gyms and Trends 2025](https://climbingbusinessjournal.com/gyms-and-trends-2025/) | 北美攀岩馆增长与市场背景。 |
| [Strava Supported Sport Types](https://support.strava.com/hc/en-us/articles/216919407-Supported-Sport-Types-on-Strava) | Strava 支持 Rock Climb 等活动类型。 |
| [Garmin: Recording a Bouldering Activity](https://www8.garmin.com/manuals/webhelp/GUID-EA668398-46E4-42E4-8163-12F6CB299F0E/EN-US/GUID-584D4C5D-8E09-4EB4-89FA-7FCA1B7F0B7A.html) | Bouldering 已有 completed/attempted/rest 循环，attempt-based 不是全新范式。 |
| [Garmin: Indoor Climbing Rest Timer](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-AU/GUID-D67857E8-04FB-44CA-9D58-B77AB8D50F83.html) | 攀岩中的 rest timer / 状态切换已是硬件厂商明确支持的模式。 |
| [Redpoint App Store](https://apps.apple.com/us/app/redpoint-bouldering-climbing/id1324072645?platform=watch) | Watch 攀岩记录、HealthKit、ML/barometer、订阅参考。 |
| [Pinnacle Climb Log](https://pinnacleclimb.com/) | Apple Watch 攀岩 log、离线 Watch 同步、attempt/undo 等参考。 |
| [Climb Meter](https://apps.apple.com/us/app/climb-meter-for-rock-climbing/id1592555877) | Apple Watch 自动 climb counting 和 grade logging 参考。 |
| [KAYA](https://kayaclimb.com/) | 路线、beta、社区、guidebook 竞品。 |
| [Mountain Project App Store](https://apps.apple.com/us/app/mountain-project/id452308783) | 户外路线库和 logbook 竞品。 |
| [Vertical-Life](https://www.vertical-life.info/) | 户外/室内/gym 生态竞品。 |
| [Crimpd](https://www.crimpd.com/) | 攀岩训练计划、计时和训练内容生态竞品。 |
| [TopLogger](https://toplogger.nu/) | 室内岩馆路线、ranking、gym 生态参考。 |
| [Griptonite](https://griptonite.io/) | 岩馆路线管理和 climber app 参考。 |
| [GoClimbr](https://goclimbr.com/) | 轻量 climbing logbook / achievement 竞品。 |
| [CrushLog App Store](https://apps.apple.com/us/app/crushlog/id6743440929) | 轻量攀岩 logbook 和 lifetime pricing 参考。 |
| [SendLog](https://www.sendlog.at/) | offline-first climbing notes/logbook、project tracking 参考。 |
| [SendSage](https://www.send-sage.com/) | logbook analytics / AI insight 参考。 |
| [MoonBoard](https://us.moonclimbing.com/pages/explore-the-moonboard) | 标准化训练板生态参考。 |
| [Kilter Board](https://kilterboard.io/) | 标准化训练板生态参考。 |
| [Hevy rest timer](https://www.hevyapp.com/features/workout-rest-timer/) | 力量训练中 set/rest/progression 与 Watch 记录习惯参考。 |
| [Strong Apple Watch workout](https://help.strongapp.io/article/224-workout-on-apple-watch) | Watch 端 set logging / rest timer / workout completion 参考。 |
| [Intervals Pro](https://intervalspro.com/index.html) | hands-free interval execution / haptics / Health 集成参考，说明 interval execution 是成熟品类。 |
| [WHOOP Journal](https://support.whoop.com/s/article/WHOOP-Journal-Overview) | 主观行为日志和生理数据关联参考。 |
| [WHOOP Coach](https://support.whoop.com/s/article/How-to-Use-the-AI-Powered-WHOOP-Coach) | wearable AI coach 方向参考，提醒不要做泛 AI 总结。 |
| [Oura Tags](https://support.ouraring.com/hc/en-us/articles/360038676993-Using-Tags) | 主观标签和生理数据关联参考。 |
| [TrainingPeaks workout logs](https://www.trainingpeaks.com/blog/workout-logs-track-training/) | 训练日志、计划和复盘的成熟形态参考。 |
| [TrainerRoad](https://www.trainerroad.com/) | adaptive training / training OS 参照，但不是当前阶段 category。 |
| [Future](https://future.co/about) | coach-led fitness platform 参照，coach workflow 应为条件 bet。 |
| [Lattice Training](https://support.latticetraining.com/which-plan) | 攀岩训练计划、教练和订阅模式参考。 |

### Research / Personal Informatics / Training Monitoring

| Source | 用途 |
| --- | --- |
| [Li et al.: A Stage-Based Model of Personal Informatics Systems](https://www.cs.cmu.edu/~jhm/Readings/2010-ianli-chi-stage-based-model.pdf) | personal informatics 的准备、采集、整合、反思、行动模型。 |
| [Epstein et al.: A Lived Informatics Model of Personal Informatics](https://pmc.ncbi.nlm.nih.gov/articles/PMC12435389/) | 个人数据如何在生活场景中形成意义。 |
| [Technology-Assisted Reconstruction](https://arxiv.org/abs/1207.1821) | 数字痕迹辅助回忆和复盘的研究脉络。 |
| [Supporting Human Memory by Reconstructing Personal Episodic Narratives](https://cdn.aaai.org/ojs/19306/19306-28-23319-1-2-20220531.pdf) | episodic memory / narrative reconstruction 与产品 recall 设计参考。 |
| [Saw et al.: Subjective self-reported measures in athlete monitoring](https://pmc.ncbi.nlm.nih.gov/articles/PMC4789708/) | 主观状态在训练监测中的价值。 |
| [Session-RPE review](https://pmc.ncbi.nlm.nih.gov/articles/PMC5673663/) | session RPE 作为低成本训练负荷指标的参考。 |
| [HRV-guided training review](https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/) | HRV/readiness 能力和边界参考。 |
| [Climbing anxiety scale CAS-20](https://www.sciencedirect.com/science/article/pii/S1469029224000463) | 攀岩焦虑具有运动特异性，不宜用泛心理标签简化。 |
| [Anxiety levels and physiological responses during climbing](https://pmc.ncbi.nlm.nih.gov/articles/PMC12859972/) | 攀岩心理/生理压力与表现、风险感知相关。 |
| [Route preview and climbing visual perception](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.903518/full) | route preview 本身包含记忆和 movement sequence 解释。 |
| [Deliberate practice review](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.02396/full) | 刻意练习需要具体问题、反馈和下一轮练习方法。 |
| [Habit formation](https://transformationweightcontrol.com/wp-content/uploads/2024/12/Lally-2010-How-Habits-are-Formed.pdf) | 稳定情境和重复对训练习惯形成的影响。 |
| [Exercise identity and behavior](https://pmc.ncbi.nlm.nih.gov/articles/PMC7901813/) | exercise identity 与行为维持相关，proof 不应只做 grade scoreboard。 |
| [Time perception in adult ADHD review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9962130/) | time blindness 方向用于借鉴“外化时间”原则，不用于产品主定位。 |

---

## 21. Final Consensus After Five-PM Line Review

基于五位 PM 对上一版主报告逐行审查后的 veto 和二次投票，最终共识是：

> **方向继续，但 P0 必须降回 manual-first 的 capture -> review -> recall 行为闭环。**

### 21.1 统一定位

对外统一说：

> **面向室内抱石用户的 Apple Watch-backed bouldering training memory app。**

内部模型可以继续使用 `Rhythm Capture + Recall Retrieval + Proof/Trust`，但它只解释产品为什么成立，不作为外部品类名。

### 21.2 P0 硬边界

| P0 保留 | P0 不做 |
| --- | --- |
| Watch 开始 Boulder session。 | Rope / outdoor / gym route database。 |
| 用户下墙后一键 `Try / Send / Fail / Undo`。 | 自动判断 send/fail/flash。 |
| Rest timer、柔和触觉、低干扰状态锚点。 | 连续触觉节拍、强制休息建议。 |
| HealthKit workout + App 私有 attempt timeline。 | 用 HealthKit 推断路线结果。 |
| iPhone quick save + 可选 detailed review。 | 训练中复杂输入。 |
| 用户确认后的 project cue。 | AI coach、训练处方、实时技术指导。 |
| `Session / ProjectAnchor / Attempt / Cue / Correction / SuggestionProvenance`。 | P0 主 schema 中引入 AIProvenance、照片、视频、Smart Stack、复杂 proof graph。 |

### 21.3 必须验证的核心假设

| 假设 | 验证方式 |
| --- | --- |
| 用户愿意抱石时戴表 | 访谈 + small alpha + 真实训练佩戴率。 |
| 用户愿意下墙后 1-3 秒标记 | Watch 原型和 alpha 训练 session。 |
| 用户愿意训练后 quick review | 30 秒 quick save 完成率。 |
| 用户会在下次训练前 reopen | `pre_session_reopen_rate`。 |
| next cue 有行动价值 | `cue_used_rate`、returned project、用户自报。 |
| 商业化有空间 | 完成 >=3 次 session 用户的付费假门。 |

所有百分比阈值都只是 beta 假设，不是行业基准。

### 21.4 最终 Go / No-Go

如果 P0 不能证明 `戴表 -> 低干扰标记 -> quick review -> 下次 recall`，产品不应扩成 AI、coach、video、平台或训练 OS。  
如果 P0 成立，再进入 P1 探索 project cards、4-week trend、rest pattern display、review reminders 和可选导出。  
如果 P1 仍成立，再分别验证 board/hangboard/strength、coach workflow、hardware partnership 等条件方向。
