# LineWise 室内抱石产品重新调研报告

Date: 2026-07-13

Status: Research evidence (July 2026). Competitor and user findings are current; its product recommendations (Watch-assisted three capture modes, imports, ClimberContext) are superseded by PRD v1.1 and ADR 4.

Project: LineWise / 线感

Scope: Indoor Bouldering, iPhone + optional Apple Watch capture

Note: 为避免继续增加 Markdown，保留原文件路径并整体重写；旧版五 PM 讨论结论已被本报告取代。

---

## 0. 十分钟结论

### 0.1 结论先行

LineWise 值得继续做，但产品理由必须重新表述。

截至 2026 年，国内外市场已经不缺以下能力，而且国内独立产品的覆盖速度比上一版报告假设得更快：

- 攀岩 workout、心率、时长和卡路里；
- 线路、完攀、尝试和 Project 记录；
- 视频自动整理、逐帧对比、公开解法与社区；
- 拍墙搜线、岩馆主页、线路更新通知；
- AI 训练建议、训练计划和数据看板。
- 姿态骨架、关节角度、重心轨迹、视频叠图和动作评价；
- 3D 岩壁、虚拟姿态和用“火柴人”表达脑中 Beta；
- Apple Watch 自动记录、Project、FIT 导入和攀爬能力指标。

特别是国内产品“磕磕”已经把视频整理、拍墙搜线、逐帧对比、社区解法、岩馆入驻和订阅串成了较完整的链路；“攀岩科学”已经公开提供姿态、重心、3D 场景、自定义线路和火柴人 Beta；ClimbPin 已覆盖 iPhone + Apple Watch、自动检测、Project、心率、FIT 导入和量化指标；GoTop、壁记、岩究生分别覆盖视频自动整理、动作分析和训练日志。LineWise 不能再把“攀岩记录 + Watch + AI 读线 + 火柴人 + 社区”当作天然差异化。[攀岩科学 App Store](https://apps.apple.com/cn/app/%E6%94%80%E5%B2%A9%E7%A7%91%E5%AD%A6/id6738903694) [ClimbPin App Store](https://apps.apple.com/cn/app/climbpin-%E5%B2%A9%E9%92%89/id6755990150) [GoTop App Store](https://apps.apple.com/cn/app/gotop/id6757733784)

本轮重新调研后，最有价值、仍未被充分解决的问题是：

> 用户如何以极低成本保留“我在这条线上卡在哪里、我当时为什么失败、别人建议我怎么改、下一次要验证什么”，并在下一次到馆时自动取回，而不是只得到一份完攀档案或视频相册。

因此，当前更准确的定位是：

> **LineWise 是一个面向室内抱石的私人尝试记忆与验证系统。iPhone 管路线、视频、失败与复盘；Apple Watch 在用户愿意佩戴且岩馆允许时，提供低干扰的尝试、结果和休息锚点。**

### 0.2 本轮最重要的五个判断

| 判断 | 结论 | 对产品的影响 |
| --- | --- | --- |
| Watch 是否是核心 | 是重要能力，但不是唯一入口 | 从 `Watch-first` 修正为 `Watch-assisted`；必须有无表模式 |
| 记录是否是差异化 | 不是 | RouteCard、attempt、video 都是基础能力，价值在失败推理和下次验证 |
| AI 读线是否应先做 | 不应 | 先做照片/视频整理、手动校正、MoveCue 与 ProofCheck，积累可训练数据 |
| 岩馆是否是首发客户 | 不是 | P0 仍做个人用户；岩馆是场景、渠道和未来数据合作方 |
| 真正北极星是什么 | 下一次尝试被改善 | 追踪 `NextSessionCue 被取回并完成 ProofCheck`，而非单纯记录量 |
| 功能新颖性能否成立 | 不能 | 国内竞品已逐项覆盖原设想；只能靠更完整的学习闭环、可信度和可靠性竞争 |
| 岩馆最缺的是否是新 App | 不是 | 岩馆更缺稳定客流、优质线路、运营人才、即时教学反馈和低维护数字化 |

### 0.3 产品真正需要具备的能力

1. **多入口采集**：Watch、iPhone、相机、视频、语音都能进入同一条 RouteCard。
2. **可修正事实层**：系统建议和用户事实分开；所有自动结果可编辑、可撤销、可追溯。
3. **路线身份与生命周期**：识别同一条线、跨天关联、换线后归档，不依赖官方岩馆数据库。
4. **失败结构化**：将一次失败压缩成位置、主要阻碍和一个 MoveCue，而不是填写十几个训练标签。
5. **下次验证**：把 MoveCue 变成下次可执行的 ProofCheck，记录是否真的有帮助。
6. **低干扰现场体验**：用户可以只记录有意义的尝试，不强迫每次下墙都操作。
7. **私人数据资产**：本地优先、可导出、视频和健康数据不默认上传。
8. **平台可靠性**：Watch 断连、低电量、无 HealthKit 权限、无网络时仍不丢核心事件。
9. **历史补录与互操作**：允许训练后补记，能导入 HealthKit/FIT/照片并导出个人数据，不强迫用户重建过去。
10. **个体差异上下文**：可选保存身高、臂展、经验、惯用动作和限制，任何建议都说明适用条件，不以性别或等级替代身体事实。
11. **可访问性**：路线不能只靠颜色识别；照片、标签和线路身份应支持颜色名称、位置、形状或编号等冗余信息。

### 0.4 现在不应做什么

- 不做另一个公开 Beta 视频社区；
- 不做岩馆路线管理 SaaS；
- 不做泛化“AI 攀岩教练”；
- 不承诺单张照片自动给出正确动作；
- 不用单腕 IMU 判断完整技术、send/fail 或安全风险；
- 不把心率、卡路里、疲劳分数当作主要产品价值；
- 不要求用户每次尝试后填写路线、难度、动作和主观状态；
- 不要求岩馆先入驻才能使用。
- 不把“功能比别人多”当作产品策略；
- 不先做需要持续运营的公开内容、教练市场和岩馆后台。

---

## 1. 调研问题、方法与局限

### 1.1 本轮要回答的问题

本轮不是继续堆功能，而是重新回答：

1. 中国室内抱石发展到什么阶段？
2. 抱石者、岩馆、教练和定线员真正需要什么？
3. 当前产品已经把哪些需求解决得足够好？
4. Apple Watch 在真实岩馆里到底是优势还是限制？
5. AI 读线、动作识别和训练建议需要什么数据与前置能力？
6. LineWise 应凭什么存在，并以什么顺序验证？

### 1.2 证据等级

| 等级 | 证据 | 用法 |
| --- | --- | --- |
| A | Apple、国家标准平台、体育总局、竞品官方/App Store、正式论文 | 确认平台、法规、产品与技术事实 |
| B | 行业报告、政府报道、行业软件官网 | 判断市场和经营方向，避免直接外推精确商业结论 |
| C | Reddit、App Store 评论、社区讨论 | 提取痛点和 badcase，不当作总体比例 |
| D | 本报告推断 | 明确标为待验证假设，必须通过访谈或实地测试证明 |

### 1.3 局限

- 小红书和大众点评内容难以稳定、完整地公开检索，不能把搜索结果当作系统样本。
- 国内岩馆经营数据多来自行业报告和品牌自述，精确营收、复购和单店模型需要一手访谈。
- App Store 不少新产品评价样本不足，因此更新日志只能证明产品做了什么，不能证明用户满意。
- 海外社区反馈能说明行为摩擦，但不能直接代表北京、上海用户。
- Apple Watch 佩戴风险、岩馆政策和用户习惯差异很大，必须逐馆验证。

---

## 2. 市场、经营与场景背景

### 2.1 中国室内攀岩进入扩张后的精细化阶段

中国登山协会指导的《2024 中国攀岩行业发展报告》公开摘要显示，截至 2025 年 1 月，国内攀岩场馆约 811 家，同比增长 27.5%；报告估算 2024 年行业规模约 40 亿元。这个数据说明供给仍在扩张，但并不等于每个 App 都有自然红利。[数说故事报告介绍](https://www.datastory.com.cn/details/1219.html) [中华全国体育总会摘要](https://www.sport.org.cn/shouye/tycy/2026/0611/698997.html)

香蕉攀岩官方称已在北京、上海、深圳、成都、武汉、长沙、珠海等城市拥有 20 多家门店；上海长宁的第二家门店在 2025 年落地，说明连锁化、商圈化和体验消费正在增强。[Banana Climbing](https://bananaclimbing.com/) [上海市政府报道](https://english.shanghai.gov.cn/en-Fitness/20250721/e484c72d3646431cb5a8201eb2ba0dfc.html)

这带来三个产品背景：

1. 用户会跨馆、跨店、跨城市，单一岩馆 App 无法完整保存个人记忆。
2. 路线频繁更换，路线身份天然有生命周期，不能按永久路线数据库设计。
3. 竞争从“有没有岩馆”逐渐转向线路质量、新手转化、社区氛围、教练服务和复购。

### 2.2 岩馆不是单纯场地，而是持续更新的内容业务

岩馆的核心商品不是墙本身，而是持续更新的线路体验、社群和教学服务。国际岩馆软件将以下能力放在产品中心：

- 路线库存、区域、颜色、难度、定线员和上墙时间；
- 换线计划、路线寿命和 Last Chance 通知；
- 难度分布、动作风格分布和线路受欢迎程度；
- 用户尝试、完攀、评级与反馈；
- 比赛、挑战、会员留存和召回。

TopLogger、Griptonite、Crux 都把线路反馈、换线计划和用户参与度作为岩馆端核心价值，而不是把“做个路线列表”当作终点。[TopLogger Gym Owners](https://toplogger.nu/gym-owners) [Griptonite Route Manager](https://griptonite.io/gyms/route-manager/) [Crux Official Climbs](https://docs.cruxapp.ca/documentation-for-gym-staff/about-crux/optional-feature-gym-set-climbs)

### 2.3 岩馆收入结构决定它优先购买什么

《2024 中国攀岩行业发展报告》的公开摘要显示，常规门票、私教、团课仍是最普遍的业务，同时企业团建、户外活动、装备销售和训练营也已广泛存在。36 氪对香蕉攀岩与 GOAT 的采访给出一个更具体但应谨慎看待的单点样本：受访者称门票约占成熟岩馆收入的 80%，次卡和月卡因跨馆消费而常见，课程收入占比不高但绝对值可观，零售约占 10%。这些数字不是行业审计结果，但足以说明岩馆首先关心稳定到店、复访、课程转化与运营效率，而不是“再多一个曝光渠道”。[数说故事报告介绍](https://www.datastory.com.cn/details/1219.html) [36 氪岩馆商业采访](https://36kr.com/p/3721557299689861)

| 收入/成本项 | 经营逻辑 | 对产品的真实要求 |
| --- | --- | --- |
| 单次票、次卡、月卡、年卡 | 高频到店与稳定客流是现金流基础 | 能否形成 Project 回访和换线前召回 |
| 私教、团课 | 新手买安全感，进阶用户买即时反馈和突破 | 能否把重复失败整理成可教学的上下文 |
| 活动、比赛、女性主题活动 | 获客、品牌、社群与复访，不一定直接盈利 | 能否降低报名、挑战记录和内容维护成本 |
| 零售与周边 | 延长体验，但通常不是主收入 | 不应成为 LineWise 早期重点 |
| 定线与换线 | 线路质量直接影响复访，且成本高 | 反馈必须可解释、抗刷量、能对应具体线路生命周期 |
| 房租、保洁、通风、前台、设备 | 空间体验和基础运营持续消耗现金 | 数字产品不能增加现场录入和培训负担 |

该采访还称，主流场馆约 300-800 平方米，回本常需 3-5 年；香蕉攀岩受访者称其一年更换约 1 万条线路并在线路设计投入数百万元。这里最值得相信的不是精确金额，而是经营者把线路新鲜度和体验服务视为持续成本与竞争力。[36 氪岩馆商业采访](https://36kr.com/p/3721557299689861)

### 2.4 经营压力使“留存”比“拉新故事”更重要

Climbing Business Journal 对 240 家场馆的 2025 年调查显示，北美新馆增长放缓，许多既有岩馆面临流量、收入和成本压力。该样本不能直接代表中国，但它提示成熟阶段的关键问题会从扩张转向会员价值、复访和运营效率。[CBJ Gyms and Trends 2025](https://climbingbusinessjournal.com/gyms-and-trends-2025/)

对 LineWise 的含义不是立刻做 B2B，而是：未来若与岩馆合作，必须证明能促进“回到某条线、回到某家馆、参与课程或活动”，而不只是增加内容浏览量。

### 2.5 安全与合规是岩馆的硬边界

中国强制性国家标准 `GB 19079.4-2025` 覆盖从业人员资格、岩壁与装备、环境、安全制度、应急预案、检查、监控和公众责任保险，已于 2026 年 7 月 1 日实施。[全国标准信息公共服务平台](https://openstd.samr.gov.cn/bzgk/std/newGbInfo?hcno=7610EFE44A5347A8E0F6102B7D748C42) [国家体育总局安全管理提示](https://www.sport.gov.cn/dszx/n5414/c29427787/content.html)

产品边界必须清楚：

- LineWise 不能替代岩馆安全制度、教练、保护员或应急服务；
- AI 不应给出“安全”“可避免受伤”“已经恢复”等结论；
- 岩馆合作中的照片、视频、监控和用户行为数据必须单独授权；
- 用户佩戴 Watch 是否符合场馆规定，必须由用户遵守现场要求。

### 2.6 岩馆不是一个同质市场

LineWise 后续调研必须区分场馆类型，否则“岩馆需要什么”会变成无效平均数。

| 岩馆类型 | 主要竞争点 | 数字化接受度假设 | 最可能合作切口 |
| --- | --- | --- | --- |
| 全国/区域连锁 | 品牌一致性、活动、跨店、运营效率 | 高，但已有系统且采购复杂 | 跨店个人 Project、官方线路身份、活动 ProofCheck |
| 精品单店/社区馆 | 线路、氛围、主理人关系、复购 | 中，决策快但人手少 | 零维护换线提醒、轻量反馈、课程线索 |
| 训练型馆/Board 馆 | 难度、训练质量、进阶人群 | 中高，用户更数据化 | 失败模式、训练作业、教练交接 |
| 商场体验型馆 | 新手转化、空间、拍照、团建 | 中，重体验与客流 | 新手引导、课程入口，不适合复杂训练数据 |
| 青训/综合攀岩中心 | 课程、安全、家长信任、长期培养 | 高但合规要求更高 | 课程作业和家长摘要，远期且需单独产品设计 |

P0 不为这些场馆分别开发产品；该分层只用于避免未来拿一个合作方案套所有馆。

---

## 3. 五类主体的真实需求

### 3.1 抱石用户

#### 功能需求背后的深层任务

| 表面诉求 | 深层任务 | 现有替代 | 仍未满足之处 |
| --- | --- | --- | --- |
| 记录完攀 | 证明自己在进步 | 相册、App、打卡 | 成功被记录，失败过程被丢失 |
| 找 Beta | 降低卡线成本 | 朋友、公开视频、定线员视频 | 不同身高/力量下解法未必适用 |
| 记录 attempt | 控制训练量、理解 project | 表格、记忆、日志 App | 高频操作麻烦，跨天关联困难 |
| 休息计时 | 让下一次尝试更完整 | 手机计时器、Watch | 很少与具体路线和结果关联 |
| 看视频 | 发现动作差异 | 相册慢放、逐帧 App | 看见差异不等于知道下次改什么 |
| 找搭子 | 社交、拍摄、反馈、陪伴 | 群聊、小红书、岩馆现场 | 匹配安全、水平、时间和边界复杂 |
| 学动作 | 建立动作语言和身体感觉 | 教练、短视频、课程 | 泛化教程难映射到眼前这条线 |

#### 用户真正愿意保存的信息

社区反馈反复提到：用户想记录 Project、attempt、视频、语音 MoveCue、墙面角度、握点风格、主观感受和休息，但不愿维护复杂表格；很多人最终回到纸笔、备忘录或 Google Sheets。[Climbing journal 讨论](https://www.reddit.com/r/climbharder/comments/1kydfn6) [Session tracking 讨论](https://www.reddit.com/r/climbharder/comments/s342cw) [轻量日志反馈](https://www.reddit.com/r/climbharder/comments/1iirzz5)

由此可推断，最小有用记录不是所有字段，而是：

```text
哪条线 + 这次结果 + 卡点 + 一个下次动作
```

时间、心率、休息和视频是上下文，不是核心结论。

#### 需求优先级不是功能优先级

| 层级 | 用户需要完成的任务 | 产品含义 |
| --- | --- | --- |
| 卫生层 | 数据不丢、能补录、能撤销、路线不串、日期正确 | 先于任何 AI；失败一次就会破坏长期记录意愿 |
| 降摩擦层 | 不在攀爬中操作，训练后也能恢复事实 | `review_only` 与历史补录必须是 P0，不是降级方案 |
| 记忆层 | 下次快速想起卡点、建议与路线状态 | RouteCard、FailureEpisode、NextSessionCue |
| 学习层 | 验证某个提示是否对自己、这条线有效 | ProofCheck 和提示来源 |
| 个性化层 | 区分身高、臂展、力量、经验和偏好 | 可选 `ClimberContext`，不做未经同意的人体推断 |
| 社交层 | 与朋友/教练交换上下文而不是扔一堆视频 | 结构化分享包，晚于私人闭环 |

#### 两个容易被忽视的深层需求

1. **用户要保存的是“自己的可行解”，不是唯一标准答案。** 路线预读研究显示，视觉预规划会影响后续动作执行，专家和新手的视觉搜索与运动经验不同；同一张线路图因此不应只输出一条确定序列。[Embodied planning in climbing](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1337878/full) [Bouldering route preview cognition](https://pubmed.ncbi.nlm.nih.gov/38740079/)
2. **用户需要允许“之后再记”。** 岩究生的公开评论明确要求历史补录，并抱怨记录被写到错误日期。实时记录并不是所有用户的首选，`review_only` 必须能完整建立事实，而不是只能写一条备注。[岩究生 App Store](https://apps.apple.com/cn/app/%E5%B2%A9%E7%A9%B6%E7%94%9F/id6740552981)

#### 个体差异与可访问性

岩馆受访者主动提到男性定线员占多数、身高和力量差异，以及通过女性定线员和不同试爬者校准线路的问题。产品不应把“官方 Beta”默认成每个人的最优解，也不应只保存性别这种粗粒度标签。[岩馆群访](https://www.sohu.com/a/989252629_121124646)

P1 可选 `ClimberContext` 应只保存用户自愿提供且直接有用的信息：

- 身高与臂展区间，而非精确身体档案；
- 攀爬经验和主观等级区间；
- 惯用/不擅长动作、伤病限制的用户自述；
- 本次建议来自本人、朋友、教练、定线员还是 AI；
- 用户是否认为该建议适合自己的身体条件。

颜色也不能成为路线唯一身份。色觉用户反馈显示，相邻的蓝/紫、红/绿、粉/红线路会被混淆，粉尘和灯光会进一步降低辨识。路线卡应同时支持颜色名称、墙区、起点位置、照片、编号/标签等冗余标识；未来岩馆合作可建议使用形状、纹理或编号增强识别。[视觉障碍岩馆可访问性清单](https://climbingbusinessjournal.com/justin-salas-on-visual-impairment-accessibility-in-climbing-gyms-checklist-included/) [色觉用户讨论](https://www.reddit.com/r/bouldering/comments/1119n3k/bouldering_with_colour_blindness/)

#### 用户不想做的事

- 每次尝试后解锁手机并填表；
- 每条线先建立完整档案再开始爬；
- 训练结束后做长问卷；
- 被迫公开视频或位置；
- 被 AI 用确定语气解释身体和技术；
- 在只想爬得开心时被训练计划绑架。

### 3.2 岩馆经营者

#### 岩馆真正关心的业务结果

| 需求 | 业务原因 | LineWise 未来可能贡献 | P0 是否做 |
| --- | --- | --- | --- |
| 新手快速上手 | 降低第一次体验的恐惧和流失 | 新手线路提示、基础术语、课程入口 | 否 |
| 提升复访 | 会员与次卡收入依赖持续到馆 | Project recall、换线前提醒 | 仅验证个人侧 |
| 路线反馈 | 路线是核心内容，需要知道冷热和误定级 | 匿名聚合尝试/主观难度/失败点 | 否，需合作与授权 |
| 换线沟通 | 用户 Project 被拆会产生挫败 | 路线生命周期、Last Chance | P1 可做个人标记 |
| 教练转化 | 课程是重要增值收入 | 将重复失败转为教练咨询入口 | 否 |
| 社区和活动 | 形成归属感与挑战感 | 私密小组、活动 ProofCheck | 否 |
| 运营低负担 | 定线和前台已经忙 | 自动/用户生成数据、零重复录入 | 所有合作前置条件 |
| 安全合规 | 高危险性体育场所的底线 | 仅做提示和流程边界，不做安全判断 | 必须遵守 |

#### 经营者的需求有明确先后关系

1. 场馆安全、卫生、通风、设备和前台体验不出问题；
2. 新手能顺利完成第一次体验并理解规则；
3. 线路持续有趣、分布合理、换线频率可感知；
4. 次卡/月卡用户持续复访，年卡用户形成归属；
5. 教练和活动能承接明确目标，不破坏普通用户体验；
6. 数据能帮助决策，但采集和维护成本不能超过价值。

因此，LineWise 未来向岩馆展示的不是“AI 很先进”，而应是：

```text
不用定线员重复录入 -> 用户能回到 Project -> 岩馆能看懂匿名反馈 -> 课程/换线触达更准确
```

#### 岩馆不会接受的产品

- 要求定线员为每条线额外录入大量字段；
- 让未经确认的 AI 内容看起来像官方解法；
- 公开负面线路评价但不给管理和申诉机制；
- 在垫区鼓励用户频繁看屏或拍摄影响他人；
- 采集用户健康、位置、视频却没有明确用途和权限；
- 需要复杂硬件改造或与现有会员系统深度绑定才能启动。

#### 岩馆合作的最低交换

未来合作必须形成清楚交换：

```text
岩馆提供：官方线路身份、换线周期、定线员演示或课程入口
LineWise 提供：用户回访、Project 召回、匿名线路反馈、低维护的内容触达
```

如果不能降低岩馆工作量或提升复访，岩馆没有理由接入。

### 3.3 教练

教练的价值不只是提供一个动作答案，而是观察、追问、筛选主要问题、设计练习、校正执行，并根据用户的情绪和身体状态调整。

教练需要：

- 看到用户在同一条线的多次尝试，而不是只看最好的一次；
- 知道用户自认为的问题与实际动作差异；
- 给出一个足够短、能在下一次尝试验证的 MoveCue；
- 记录哪个提示对哪个身体条件和线路类型有效；
- 在课后保留作业与下一次复查点；
- 避免被大量无上下文视频淹没。

36 氪采访中的学员把课程价值概括为“即时反馈”：进阶班会全程录像，再由教练针对个人动作一对一调整；岩馆在筛选教练时还关注沟通、教学经验、服务、同理心和责任心。这个事实反对“AI 给出更多指标就等于教练”的假设。教练真正出售的是观察后的取舍、表达、信任和连续校正。[36 氪岩馆商业采访](https://36kr.com/p/3721557299689861)

| 教练工作环节 | 当前成本 | LineWise 可帮助 | 不能替代 |
| --- | --- | --- | --- |
| 课前了解 | 询问历史、目标、伤病、近期 Project | 一页结构化交接包 | 教练风险判断与问诊边界 |
| 现场观察 | 多次尝试、找主要问题 | 自动定位代表性视频和失败时间点 | 教练现场注意力与动作判断 |
| 给提示 | 信息太多，学员记不住 | 只保存一个可执行 MoveCue | 教练选择哪一个提示 |
| 课后作业 | 微信文字、视频分散 | NextSessionCue + MicroDrill | 个体化训练处方 |
| 下次复查 | 很难记住上次细节 | ProofCheck 与前后视频 | 教练对新问题的解释 |

LineWise 对教练最有价值的未来形态不是“教练后台”，而是结构化的教练交接包：

```text
RouteCard + 代表性失败视频 + 用户主观卡点 + 教练 MoveCue + 下次 ProofCheck
```

### 3.4 定线员

定线员关心的不是用户有没有拍到好看视频，而是路线是否实现了预期体验：

- 目标难度与实际难度是否偏离；
- 不同身高、臂展和水平的人是否有合理解法；
- 哪一动作成为意外瓶颈；
- 线路是否被跳过、过度拥挤或频繁寻求帮助；
- 风格、动作、墙角度和难度分布是否均衡；
- 线路下架后经验能否进入下一轮定线。

Griptonite 和 TopLogger 已经证明 B2B 路线分析是独立、复杂的产品领域。LineWise 不应在 P0 复制它，而应先保留未来有价值的数据原语：路线生命周期、主观难度、尝试、失败位置、MoveCue 来源和用户校正。

定线反馈还必须区分“难度”“体验”“安全”和“可访问性”。一条线被大量失败，可能是目标难度正确，也可能是起步歧义、跨度对部分身体条件不友好、标签不清、关键岩点脏污，或现场拥挤导致尝试不足。简单的 send rate 不能直接评价定线员。

| 定线问题 | 需要的数据 | 误用风险 |
| --- | --- | --- |
| 难度是否偏离 | 官方/主观等级、经验区间、尝试结果 | 把不同人群混成一个平均值 |
| 动作意图是否被感知 | MoveCue、失败位置、代表性解法 | 公开 AI 猜测冒充官方意图 |
| 是否存在身体适配问题 | 自愿的身高/臂展区间、替代解法 | 以性别标签替代身体事实 |
| 路线是否值得保留/复刻 | 回访、收藏、Project、体验反馈 | 只看流量鼓励简单或网红线 |
| 颜色/标签是否可辨 | 色觉反馈、照片、墙区与路线交叠 | 把识别失败当作攀爬失败 |

路线预读研究支持“预规划与动作执行互相影响”，但也说明能力受经验和运动技能调节。SetterLens 应展示意图、约束和多种可能，而不是生成唯一标准动作。[Route preview efficacy](https://pubmed.ncbi.nlm.nih.gov/20561271/) [Embodied planning in climbing](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1337878/full)

### 3.5 前台、场务与现场员工

此前报告漏掉了最常接触新手、投诉和现场异常的一组人。其需求与老板、教练不同：

- 快速说明规则、落地区域、鞋/粉/储物和拍摄边界；
- 处理高峰拥挤、借鞋不足、签到/闸机异常和物品遗失；
- 回答线路颜色、难度、换线和课程问题；
- 发现设备、垫区、墙面或用户行为问题并升级；
- 不想再维护一套与票务、会员和现场 SOP 无关的系统。

LineWise P0 不服务这类员工。未来岩馆合作若需要员工每天帮用户建路线、解释 AI 或处理内容纠纷，应直接判为高运营成本方案。

---

## 4. 竞品重新分层

### 4.1 中国本地直接竞品

| 产品 | 当前公开能力 | 公开评价/版本日志暴露的问题 | 对 LineWise 的结论 |
| --- | --- | --- | --- |
| 磕磕 | 视频自动整理、拍墙搜线、逐帧对比、公开解法、岩馆主页、搭子、会员卡、云空间 | 版本日志持续修复后台整理、重复队列、旧设备崩溃、来电打断、线路评分和同步问题；评价样本不足 | “视频档案 + 岩馆 + 社区”已被占位，可靠性比功能数量更难 |
| 攀岩科学 | 姿态分类、关节角度、重心轨迹、视频叠图、AI 分析、3D 岩壁、3D pose、自定义线路、火柴人 Beta、指力训练 | 有用户认可叠图，也有定线功能闪退反馈；安装包约 806 MB | 原设想中的 AI、火柴人、定线解析都不是新概念 |
| ClimbPin 岩钉 | iPhone + Apple Watch、自动检测、Project、心率、CPG/CEG、完攀金字塔、Health/FIT 导入、AI 识图、iCloud | 手动保存闪退、图片点击无响应；日志持续修复 Watch 传输确认、同步卡死、云端残留和编辑不回传 | Watch 与指标已是直接竞争，LineWise 必须把事实可靠性和 ProofCheck 做得更深 |
| GoTop | 自动裁剪、线路/颜色分组、尝试与完攀识别、训练摘要、本地视频 | 评价样本仅 7 个，产品宣称准确性尚缺独立验证 | 自动整理可作为导入能力，不应成为唯一价值 |
| 壁记 | 尝试/结果/线路/视频、姿态、锁臂、重心、三点平衡、统计、多难度系统 | 仅 6 个评分，缺少长期使用证据 | 记录、相册和姿态分析已商品化 |
| 岩究生 | 自定义日志、训练计划、休息、视频、结果 | 评论要求历史补录并反馈日期错误；用户要求开放自建岩馆 | 离线、补录、正确日期和用户自建身份是硬需求 |
| 攀岩么 | 城市/岩馆/线路、打卡、收藏、公开内容、约爬和搭子 | 评价不足 | 本地发现和社交不是 LineWise P0 空白 |
| 攀岩笔记等轻日志 | 路线、特征、未完攀筛选、月度摘要 | 多为轻量记录，数据深度有限 | 基础日志门槛很低，迁移价值必须在下一次学习 |

来源：[磕磕 App Store](https://apps.apple.com/hk/app/%E7%A3%95%E7%A3%95-%E6%94%80%E5%B2%A9%E8%AE%B0%E5%BD%95%E4%B8%8E-beta-%E7%A4%BE%E5%8C%BA/id6760823408) [攀岩科学 App Store](https://apps.apple.com/cn/app/%E6%94%80%E5%B2%A9%E7%A7%91%E5%AD%A6/id6738903694) [ClimbPin App Store](https://apps.apple.com/cn/app/climbpin-%E5%B2%A9%E9%92%89/id6755990150) [GoTop App Store](https://apps.apple.com/cn/app/gotop/id6757733784) [壁记 App Store](https://apps.apple.com/cn/app/%E5%A3%81%E8%AE%B0-%E8%AE%B0%E5%BD%95%E4%BD%A0%E7%9A%84%E6%AF%8F%E4%B8%80%E6%AC%A1%E6%94%80%E7%99%BB/id6749840034) [岩究生 App Store](https://apps.apple.com/cn/app/%E5%B2%A9%E7%A9%B6%E7%94%9F/id6740552981) [攀岩么 App Store](https://apps.apple.com/tw/app/%E6%94%80%E5%B2%A9%E4%B9%88/id6775133615) [攀岩笔记 App Store](https://apps.apple.com/cn/app/%E6%94%80%E5%B2%A9%E7%AC%94%E8%AE%B0/id6471394121)

### 4.2 已有能力版图：原五大愿景均已有直接实现

| LineWise 原愿景 | 市场已有实现 | 还能做出的差异 |
| --- | --- | --- |
| 攀岩搭子 | 攀岩么、磕磕、微信群、小红书、岩馆现场 | 先做私人 AI/记忆伴侣；真人匹配必须解决时间、水平、拍摄、社交边界和安全 |
| 自动读线 | 磕磕拍墙搜线、ClimbPin AI 识图、多款海外 AI App | 结合个人历史和 ProofCheck，输出多假设而非一条答案 |
| 火柴人趣味交互 | 攀岩科学已有 3D pose 和虚拟火柴人 Beta | 用于解释一个 MoveCue，并在真实尝试后验证，不做孤立特效 |
| 定线解析 | 攀岩科学自定义线路、岩馆 OS、定线工具 | 区分官方意图、用户解法和 AI 推断；引入身体适配和可访问性 |
| 教学与训练 | 岩究生、攀岩科学、Crimpd、教练课程 | 从重复 FailureEpisode 触发一个 MicroDrill，不先建泛内容库 |

由此得到新的竞争原则：

```text
Feature novelty is gone.
The defensible unit is: route identity + meaningful failure + one cue + later proof.
```

### 4.3 评价与更新日志反复暴露的是可靠性债务

当前竞品的负面信号高度一致：

- 自动识别会把无效片段、环境变化或短线路误算成攀爬；
- Watch 与手机传输完成状态不清楚；
- 云同步卡住、删除残留、编辑不回传；
- 图片/视频添加失败、后台处理队列重复、来电中断后片段丢失；
- 用户不能在训练后补录，或日期、路线、尝试被写错；
- AI/姿态功能能演示，但崩溃、体积和解释可信度影响持续使用。

因此，P0 的产品质量顺序必须是：

```text
不丢 -> 不串 -> 可补 -> 可改 -> 可解释 -> 才自动化
```

任何自动功能若让用户花更多时间校正，或无法说明来源，都不应进入默认流程。

### 4.4 Apple Watch 与运动记录

| 产品 | 强项 | 公开问题/限制 | LineWise 应吸收的教训 |
| --- | --- | --- | --- |
| Apple Workout | 系统原生、Workout/Health/Fitness | 没有路线、失败和 Project 语义 | 用作底层记录，不重复造泛运动摘要 |
| Redpoint | Watch、HealthKit、多攀岩类型、自动高度 | 气压受空调/门窗影响；评论要求更好编辑和数据解释 | 自动化必须可修正，抱石不依赖高度 |
| Pinnacle | Watch 离线、一键记录、难度体系 | 仍偏 grade/attempt log | 离线和极简操作是基线能力 |
| Garmin/COROS | 硬件生态、路线/训练负荷 | 用户需要专用设备且交互模型不同 | 不和硬件平台拼泛训练负荷 |

Redpoint 的用户评论直接暴露了两个问题：室内气压变化会造成错误高度/攀爬记录；如果记录不能方便地删除、编辑、合并并转成有用洞察，用户不会为高级版付费。[Redpoint App Store Reviews](https://apps.apple.com/us/app/redpoint-bouldering-climbing/id1324072645?platform=watch&see-all=reviews)

Pinnacle 已提供 Watch 独立离线工作和一键记录，这意味着“Watch 能记攀岩”不是产品护城河，只是入场券。[Pinnacle App Store](https://apps.apple.com/us/app/pinnacle-climb-log/id1271954104)

### 4.5 岩馆、路线与社区系统

| 产品族 | 代表 | 已解决的问题 | LineWise 不应复制 |
| --- | --- | --- | --- |
| 岩馆 OS | TopLogger、Griptonite、Vertical-Life | 官方路线、换线、比赛、排行榜、反馈、定线分析 | 岩馆后台、路线库存、比赛计分 |
| Guidebook/社区 | KAYA、Mountain Project、27 Crags | 户外路线、地图、公开解法、社交图谱 | 公共路线数据库和内容冷启动 |
| Spray/Board | MoonBoard、Kilter、Crux | 标准墙/喷点墙、共享线路、训练记录 | 标准化硬件生态 |
| 训练系统 | Crimpd、Lattice、训练计划 App | 课程、周期、力量训练 | 泛训练内容库和无上下文 AI 计划 |

### 4.6 最强竞争对手仍是用户现有习惯

```text
照片/视频 + 微信群/朋友 + Apple Workout + 记忆
```

这个组合免费、灵活、没有学习成本。LineWise 必须让用户在下一次到馆时明显感到“我真的更快想起来并做了更好的下一次尝试”，否则再完整的档案都不足以迁移习惯。

### 4.7 数据可持续性也是竞争维度

2026 年 Kilter Board 旧 App 的数据和服务迁移事件引发用户对多年训练记录消失的担忧。对个人训练系统而言，可导出、可迁移和离线可读不是附加功能，而是信任合同。[Climbing 对 Kilter App 事件的报道](https://www.climbing.com/news/why-the-kilter-board-app-suddenly-disappeared/)

---

## 5. Apple Watch 适配重新判断

### 5.1 官方平台能力

Apple 的 workout session 可以在后台继续运行并产生高频心率样本；系统要求开始/停止明确、保存反馈清楚，并限制后台 CPU 使用。[Running Workout Sessions](https://developer.apple.com/documentation/HealthKit/running-workout-sessions)

WatchConnectivity 的接口适合不同语义：

- `sendMessage`：设备可达时即时请求；
- `updateApplicationContext`：只保留最新状态；
- `transferUserInfo`：排队、按序、最终交付；
- `transferFile`：照片/大文件等后台传输。

Apple 明确要求 `transferUserInfo` 在真实配对设备测试，Simulator 不支持完整行为。[WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity) [transferUserInfo](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo%28_%3A%29)

### 5.2 Watch 的真实价值

Watch 最适合：

- 开始/结束 workout；
- 自动记录时间和心率上下文；
- 下墙后单次轻触记录结果；
- 显示 rest timer；
- 用轻触觉做可关闭的时间提示；
- 手机不在旁边时本地保存事件；
- 下一次到馆时显示一个极短的 NextSessionCue。

Watch 不适合：

- 选取照片、画线路或标注岩点；
- 填写失败 taxonomy；
- 阅读详细动作解释；
- 浏览公开视频和社区；
- 实时做动作指导；
- 展示复杂趋势图。

### 5.3 佩戴本身是产品门槛

社区中既有长期戴表并使用保护套的用户，也有因划伤、磕碰、腕部不适、担心勾挂而拒绝佩戴的人；还有用户提到个别岩馆不允许佩戴手表或首饰。这些是用户反馈，不是普遍安全标准，但足以否定“所有目标用户都能戴表”的假设。[Bouldering smart watch 讨论](https://www.reddit.com/r/bouldering/comments/1fljsbo/does_anyone_use_fitness_trackers_smart_watches/) [是否戴表讨论](https://www.reddit.com/r/bouldering/comments/105t4kt) [Climbing watch 讨论](https://www.reddit.com/r/bouldering/comments/16kaz8n/bouldering_with_a_smart_watch/)

因此必须提供三种采集模式：

| 模式 | 适用用户 | 现场交互 |
| --- | --- | --- |
| Watch capture | 愿意戴表且场馆允许 | Fail/Send/Undo 或简化事件 |
| iPhone quick capture | 不戴表但手机在垫区外可取 | 锁屏/大按钮/语音短记 |
| Review-only capture | 训练中不想操作 | 结束后按路线批量记尝试与代表性失败 |

核心数据模型必须兼容三种模式，不能把 Watch 事件流写死成唯一事实来源。

### 5.4 传感器能做什么

| 数据 | 可支持 | 不应声称 |
| --- | --- | --- |
| Heart rate | session 背景、粗略强度和休息趋势 | 恢复、疲劳、安全、动作质量 |
| Accelerometer/Gyroscope | suggested active/rest window、实验性候选 | 全身技术、路线、send/fail |
| Barometer | 绳攀或较大高度变化的实验 | 抱石 attempt 可靠计数 |
| GPS/Location | 可选场馆回忆 | 室内线路定位、精确墙区 |
| Workout duration | 可靠 session 边界 | 有效攀爬时间的自动真相 |
| Energy | Apple 生态附属信息 | 精确训练负荷和付费价值 |

### 5.5 Watch P0 的正确目标

不是“自动识别每次攀爬”，而是：

> 当用户愿意戴表时，把一次有意义的记录从十几秒降到一两秒，并且即使断连也不丢。

### 5.6 Watch 不是数据孤岛，导入比排他更重要

ClimbPin 已经支持 Health 中其他 App 的攀岩记录和 Garmin/COROS FIT 文件导入，并允许用户入库前预览、逐段定级。这意味着用户可能已经在多个设备上积累 workout；LineWise 若要求必须由自家 Watch App 开始记录，会人为缩小市场。[ClimbPin App Store](https://apps.apple.com/cn/app/climbpin-%E5%B2%A9%E9%92%89/id6755990150)

P0/P0.5 的平台策略应是：

| 来源 | 导入内容 | LineWise 补充的语义 |
| --- | --- | --- |
| LineWise Watch | session、事件锚点、rest、可选 HR | RouteCard、FailureEpisode、MoveCue、ProofCheck |
| Apple Health | workout 边界、时长、可授权样本 | 训练后按路线补录，不假装拥有 attempt 真相 |
| FIT | 设备记录的段落与生理/高度数据 | 用户预览、合并、逐段确认 |
| Photos/视频 | 时间、地点、媒体 | 路线身份、代表性尝试、失败位置 |
| 手动历史 | 日期、岩馆、线路、结果、笔记 | 允许不完整事实，标记来源而非强迫补齐 |

Apple HealthKit 权限必须按使用场景逐项请求；健康数据不能用于广告，向第三方或第三方 AI 发送前必须取得明确同意。[HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## 6. AI 读线与动作分析的能力边界

### 6.1 单张照片能可靠做的层级

从低到高：

1. 检测可能的岩点和 volume；
2. 按颜色/纹理形成路线候选；
3. 标注 start/top/zone 候选；
4. 用户校正路线集合；
5. 基于几何与常见动作生成多个 MoveCue 假设；
6. 结合用户身体参数、历史视频和结果进行个性化排序；
7. 推断唯一正确解法或定线员意图。

P1 最多应承诺 1-4；第 5 项只能是可编辑假设；6-7 需要大量个体与路线数据，不能作为短期承诺。

### 6.2 为什么“自动读线”比看起来难

照片缺失的信息包括：

- 岩点真实深度、摩擦、可抓方向和遮挡；
- 墙面倾角与透视畸变；
- 脚点是否允许、起步规则和定线标签；
- 用户身高、臂展、力量、柔韧、惯用侧与恐惧；
- 动态动作的时序、速度和接触质量；
- 定线员真实意图与替代解法。

CVPR 2025 Workshop 的 `The Way Up` 只使用 22 段标注视频、940 次手脚岩点使用来研究 hold usage，并强调攀岩姿态估计仍有专门挑战。这说明公开研究正在建立基础数据集，而不是已经解决通用 AI 教练。[The Way Up](https://openaccess.thecvf.com/content/CVPR2025W/CVSPORTS/html/Maschek_The_Way_Up_A_Dataset_for_Hold_Usage_Detection_in_CVPRW_2025_paper.html)

`augKlimb` 的用户中心研究也更接近“轻量记录、加速度和视频关联”，而不是从单腕或单图直接给出正确技术诊断。[augKlimb](https://arxiv.org/abs/2001.07944)

### 6.3 LineWise 应先建立的数据链

```text
RoutePhoto
  -> user-corrected RouteGroup
  -> Attempt outcome
  -> Failure location
  -> MoveCue and provenance
  -> next-attempt ProofCheck
  -> accepted / edited / rejected
```

最稀缺的数据不是路线照片本身，而是“某个建议对某个用户在下一次尝试是否有效”。这比大量没有结果标签的公开视频更接近个性化训练价值。

### 6.4 AI 输出的四级信任模型

| 级别 | 输出 | 产品语言 |
| --- | --- | --- |
| L0 | 用户事实 | `Recorded` / `Confirmed` |
| L1 | 规则建议 | `Suggested from your last note` |
| L2 | 模型候选 | `AI suggestion, needs review` |
| L3 | 教练/定线员内容 | 显示作者与身份，不冒充系统真相 |

任何 L1/L2 输出都必须保存来源、置信度、编辑和拒绝事件。

### 6.5 AI 产品价值不在“看起来像懂了”，而在能被证伪

路线预读实验表明，预览可减少和缩短攀爬中的停顿，但不必然提高是否完攀；经验更丰富的攀爬者也表现出不同的视觉搜索和动作规划。这给产品两个约束：[Route preview efficacy](https://pubmed.ncbi.nlm.nih.gov/20561271/) [Bouldering preview cognition](https://pubmed.ncbi.nlm.nih.gov/38740079/)

1. 不能把“生成了一条顺序”直接等同于提高 send 率；
2. 同一个建议必须放进用户、路线、尝试和结果上下文中检验。

所以每个 AI MoveCue 都必须回答：

- 它依据了哪张照片、哪段视频、哪次失败或哪位作者？
- 它假设了什么身高/臂展、手脚顺序或墙面条件？
- 用户接受、编辑还是拒绝？
- 下一次是否执行？结果是 `worked`、`no_change`、`different_problem` 还是 `not_tested`？

这套可证伪结构才可能逐步形成 LineWise 的个人学习资产。

---

## 7. 重新定义产品问题

### 7.1 旧问题

> 如何用 Watch 记录攀岩 session，并在手机上复盘？

这个问题太接近 Redpoint、Pinnacle 和通用 logbook，也容易陷入 attempt 计数和传感器准确率。

### 7.2 新问题

> 如何让抱石者从一次失败中只保存最必要的信息，并在下一次尝试时取回、验证和更新，让个人对路线与身体的理解持续积累？

### 7.3 核心闭环

```text
Capture meaningful attempt
  -> compress failure into one blocker
  -> preserve one MoveCue
  -> retrieve before next attempt/visit
  -> run ProofCheck
  -> update personal climbing memory
```

### 7.4 Canonical domain chain

原有领域模型仍成立，但需要强调结果层：

```text
GymVisit
  -> RouteCard
  -> Attempt
  -> FailureEpisode
  -> MoveCue
  -> NextSessionCue
  -> ProofCheck
```

`ProofCheck` 不是附属字段，而是 LineWise 与普通日志、视频社区之间的关键差异。

### 7.5 真正可能积累的护城河

不是照片数量、视频数量或 workout 数量，而是：

```text
在什么路线约束下
什么身体与经验上下文的人
在什么失败位置
接受了什么来源的 MoveCue
下一次发生了什么
```

这个“建议到结果”的图谱既能服务个人记忆，也能在用户明确同意、匿名阈值足够时支持教练和定线研究。P0 仍只构建私人单用户图谱，不宣称网络效应。

---

## 8. 严格需求合同

### 8.1 P0 Must Have

| 能力 | 具体要求 | 验证方式 |
| --- | --- | --- |
| RouteCard | 10 秒内建立最小路线锚点；可仅照片或短标签 | 真实岩馆计时 |
| 多入口采集 | Watch、iPhone quick capture、review-only 共用事件模型 | 三种模式回放测试 |
| Attempt | 支持有意义尝试、结果、时间和路线绑定 | 现场与复盘纠错 |
| Local-first | 无账号、无网、无 HealthKit 仍可完成核心闭环 | 飞行模式/拒权测试 |
| Historical entry | 训练后可选择真实日期补录，不要求实时开启 App | 历史日期/时区/跨午夜测试 |
| Interoperability | 至少预留 Health/FIT/Photos 导入与版本化导出模型 | 导入预览、去重与往返测试 |
| Undo/Correction | 用户能撤销、改路线、合并/拆分事件 | 用户任务测试 |
| FailureEpisode | 一次复盘只要求一个主要阻碍 | 30 秒 review 测试 |
| MoveCue | 文本优先，语音可作为快速输入 | 次日可理解性测试 |
| NextSessionCue | 到馆或打开项目时自动取回一个动作 | 下一次实地测试 |
| ProofCheck | 记录提示是否帮助、无效或需要修改 | 连续两次尝试验证 |
| Export | 能导出用户自己的结构化记录 | JSON/CSV 验证 |
| Trust | AI/规则/人类来源清楚，建议与事实分离 | 认知访谈 |
| Accessible identity | 路线不只用颜色识别；支持墙区、照片、位置或编号 | 色觉模拟与用户测试 |

### 8.2 Watch Must Have

- 开始、暂停、结束 workout；
- 当前 session 与 rest 时间；
- 最少的结果按钮与 Undo；
- 本地事件队列和幂等同步；
- 低电量、断连和保存状态；
- 可关闭触觉；
- 明确提示遵守岩馆佩戴规则；
- 不戴表时不破坏整个产品。

### 8.3 Should Have

- RouteCard 相似照片/日期辅助关联；
- 语音转短 MoveCue；
- 代表性失败视频和最好尝试对比；
- 路线 `active / sent / gone / archived` 生命周期；
- “该路线可能已换线”的弱提醒；
- 同一 MoveCue 的历史 ProofCheck；
- 私密分享给搭子或教练；
- 用户自定义失败标签，而不是无限系统 taxonomy。
- 可选 `ClimberContext`，只存用户主动提供的身高/臂展区间、经验和限制；
- 导入 Apple Health、FIT 或 Photos 后先预览再入库；
- 所有导入、建议和人工事实保留来源。

### 8.4 P1 条件能力

- 照片岩点候选和路线分组；
- start/top 候选；
- 视频自动裁剪和 attempt 对齐；
- StickFigureCue 三帧解释；
- SetterLens，但必须标记“系统推断”或“定线员提供”；
- 基于重复 FailureEpisode 推荐 MicroDrill；
- 岩馆官方路线和换线周期接入。

### 8.5 Won't Have Now

- 唯一正确解法；
- 自动判断安全、恢复和受伤风险；
- 陌生人开放匹配；
- 岩馆后台、会员 CRM、比赛系统；
- 泛内容 feed；
- 强制云端；
- 用健康数据做广告或推荐画像；
- 自动公开用户拍摄的他人。

---

## 9. 关键交互设计原则

### 9.1 训练中

- 攀爬中不弹窗、不要求确认；
- 下墙后优先显示结果和 rest，不显示长文本；
- 用户可以跳过普通尝试，只记关键失败或 send；
- 所有误触一步撤销；
- 镁粉、汗水、疲劳和单手操作要纳入实机测试；
- 触觉是提示，不是命令。

### 9.2 训练后

Quick Review 目标在 30 秒内：

1. 今天最想记住哪条线？
2. 主要卡点是什么？
3. 下次只试哪一个改变？

Detailed Review 是可选的：视频、时间线、心率、多个 MoveCue、主观状态和训练标签不应阻塞保存。

### 9.3 下一次到馆

不要先展示统计仪表盘，先展示：

```text
上次 Project
卡点
要试的一个动作
[Worked] [No change] [Different problem]
```

这才是 Recall beats Recap 的产品化表达。

---

## 10. 岩馆合作方向，但不进入 P0

### 10.1 可以探索的最轻合作

1. 岩馆官方名称、区域和换线日；
2. 公开的路线颜色/难度/定线员；
3. 换线前 Project 提醒；
4. 定线员自愿发布一个官方 MoveCue；
5. 教练课程或公开工作坊入口；
6. 匿名、聚合后的主观难度和路线热度。
7. 路线的颜色名称、编号/标签和可访问性说明；
8. 教练提供的课后 MoveCue 与下一次作业。

合作顺序应从最轻的数据交换开始：

| 阶段 | 岩馆投入 | 用户价值 | 停止条件 |
| --- | --- | --- | --- |
| A. 用户自建 | 0 | 跨馆私人记忆 | RouteCard 本身无使用价值 |
| B. 公开元数据 | 每次换线批量导入或二维码 | 官方身份、换线日、路线不串 | 每周维护超过 15 分钟 |
| C. 官方内容 | 定线员/教练自愿给少量 cue | 来源可信、课程承接 | 内容产出成为额外 KPI |
| D. 匿名反馈 | 同意、阈值与治理 | 主观难度、适配和体验洞察 | 样本不足或引发对立 |
| E. 运营转化 | 活动/课程入口 | Project 回访和课程线索 | 无法证明增量复访 |

### 10.2 合作前置条件

- 岩馆每周维护时间应接近零；
- 用户数据默认不交给岩馆；
- 健康数据不进入岩馆分析；
- 负面反馈需要聚合阈值和管理机制；
- 官方内容与 AI 推断明显区分；
- 路线撤除后，用户个人历史仍可保留；
- 不做安全事故自动判责或承诺。
- 不把 send rate 直接当作线路好坏；
- 不把用户身高、健康或视频默认提供给岩馆；
- 不允许 AI 内容使用岩馆/定线员口吻却没有官方来源。

### 10.3 岩馆价值验证指标

| 指标 | 意义 |
| --- | --- |
| Project return | 用户是否因提示回到线路/岩馆 |
| Last-chance conversion | 换线前提醒是否带来到馆 |
| Official cue open/use | 定线员内容是否真的被使用 |
| Course lead | 重复失败是否转成课程咨询 |
| Maintenance minutes | 岩馆每周需要投入多少录入时间 |
| Feedback coverage | 有多少线路获得足够样本，而非少量极端意见 |

---

## 11. 商业化重新判断

### 11.1 用户不会为基础记录长期付费

基础 RouteCard、attempt、HealthKit 和少量历史已经被多种产品提供。若 LineWise 订阅只解锁“更多统计”，很难形成持续价值。

### 11.2 可能的付费价值

| 价值 | 付费理由 | 何时验证 |
| --- | --- | --- |
| 长期 Project memory | 跨馆、跨月、换线后仍可查 | P0/P1 |
| 视频/尝试智能对齐 | 节省整理时间 | P1 |
| 个性化 Proof history | 知道什么提示对自己有效 | P1 |
| 私人 AI RouteRead | 基于个人数据而非通用答案 | P1/P2 |
| 教练交接包 | 减少教练筛视频和问背景的时间 | P2 |
| 可靠导出与备份 | 保护长期数据资产 | P0/P1 |

### 11.3 商业化顺序

1. 免费验证 3-5 次真实到馆闭环；
2. 一次性 Founder unlock 测试支付意愿；
3. 年付 Pro 只放在持续计算/云存储/AI 或长期分析之后；
4. 岩馆合作先做小范围数据/内容试点，不先售卖完整 SaaS；
5. 不靠健康数据广告变现。

---

## 12. 验证计划

### 12.1 第一阶段：需求真实性

样本建议：

- 8-10 名每周两次以上的 Project 型抱石者；
- 5 名新手/轻量用户；
- 3-5 名教练；
- 3-5 名定线员或馆长；
- 3-5 名前台/场务或运营人员；
- 北京、上海至少各一家连锁馆和一家独立馆。

关键问题：

- 最近一次忘掉的 Project 细节是什么？
- 训练中愿意记录哪一次，为什么？
- 你为什么不使用现有攀岩 App？
- 你是否愿意戴表，岩馆是否允许？
- 朋友/教练给的哪类提示最容易忘？
- 下次到馆前会不会看旧视频或笔记？
- 什么信息真的改变了下一次尝试？
- 现在使用过哪些 App，为什么停用或继续？
- 是否需要历史补录、跨设备导入或退出时导出？
- 是否会混淆相近颜色线路，通常如何确认？
- 对不同身高/臂展的 Beta，用户如何判断是否适合自己？

岩馆访谈还要分别问：

- 老板：收入结构、复访、线路投入、活动与数字化维护成本；
- 教练：课前上下文、即时反馈、课后作业和复查；
- 定线员：难度校准、试爬、换线、身体适配和反馈噪声；
- 前台/场务：新手 SOP、拥挤、装备、拍摄、投诉和现场系统负担。

### 12.2 第二阶段：三种采集模式对比

每个用户分别试：

1. Watch capture；
2. iPhone quick capture；
3. Review-only。

记录：

- 每小时操作次数；
- 丢失/错绑事件；
- 是否中途放弃；
- 训练后 review 时间；
- 次日能否说出 cue；
- 下次是否执行 ProofCheck。

### 12.3 第三阶段：AI 数据准备

先收集并人工标注：

- 50-100 条 RouteCard；
- 200-500 次尝试；
- 100 张校正后的路线照片；
- 50 个失败位置；
- 50 个 MoveCue；
- 30 个跨尝试 ProofCheck；
- 不同墙角度、光照、岩点颜色、遮挡和多人背景 badcase。

只有当人工校正流程本身有价值，才开始模型开发。

### 12.4 Go / Pivot / Stop

| 结果 | 决策 |
| --- | --- |
| 用户保存并在下次使用 cue | 继续 Gym Visit Memory + Proof |
| 用户只看/整理视频，不用 cue | 转向私人视频工作流，重新评估与磕磕差异 |
| Watch 使用率低但 review 有价值 | 保留 Watch companion，主产品转 iPhone-first |
| RouteCard 创建持续太慢 | 改成照片/视频先行，路线身份后补 |
| 用户不回看、不验证 | 停止扩展 AI、训练和岩馆合作 |
| 岩馆维护成本高 | 放弃官方路线接入，保持消费者自建 |

---

## 13. 量化门槛

这些是 alpha 决策阈值，不是行业标准：

| Gate | 目标 |
| --- | --- |
| Minimal RouteCard | 中位 <= 10 秒；P90 <= 20 秒 |
| Meaningful capture | 每次到馆至少保存 2 条真正想继续的路线 |
| Quick Review | 中位 <= 30 秒 |
| NextSessionCue | >= 50% reviewed visits 产生 cue |
| Recall | >= 50% 下一次到馆打开或接收 cue |
| ProofCheck | >= 30% cue 在下一次被明确评价 |
| Platform save | >= 99% 核心事件本地保存；同步可延迟但不重复 |
| Watch burden | 使用 Watch 的用户中，干扰评分 <= 3/10 |
| Watch eligibility | 单独记录愿意佩戴、场馆允许、保护方案；不设为全产品硬门槛 |
| Trust | 用户能分辨事实、建议和教练内容；误认率接近 0 |
| Export | 100% 用户可导出自己的核心数据 |
| Historical entry | 100% 可补录真实日期；跨时区/跨午夜不串日 |
| Import review | 外部 workout/FIT/Photos 未经用户确认不写入 canonical Attempt |
| Correction burden | 自动建议的中位修正时间必须短于完全手工建立 |
| Accessibility | 路线即使不依赖颜色，也能通过至少两种锚点重新找到 |

---

## 14. 风险清单

| 风险 | 早期信号 | 应对 |
| --- | --- | --- |
| 竞品快速复制 | 视频/社区产品加入 Watch 或 cue | 深化 Proof history 和个人数据可迁移性 |
| Watch 佩戴受限 | 用户不愿戴、岩馆禁止 | 三模式采集，不将 Watch 写死为前提 |
| 记录负担 | 第二次到馆停止使用 | 只记 meaningful attempts，批量补录 |
| AI 错误 | 颜色、岩点、动作建议频繁错 | 先检测/分组，再建议；默认可编辑 |
| 数据太少 | 模型只能记住单个用户/岩馆 | 不急于训练；先证明人工链路价值 |
| 视频隐私 | 拍到他人或儿童 | 默认私有、裁剪/模糊、明确同意 |
| 健康误导 | 用户把 HR 当恢复结论 | 降级为上下文，不给处方 |
| 岩馆依赖 | 官方线路维护中断 | 用户自建 RouteCard 始终可用 |
| 数据锁定 | 服务迁移导致历史丢失 | 本地优先、版本化导出、迁移文档 |
| 产品过宽 | 同时做搭子、AI、课程、SaaS | 所有模块必须回到 ProofCheck 闭环 |
| 功能同质化 | 竞品已覆盖 Watch、AI、姿态和火柴人 | 不以功能数量定位，持续验证学习闭环 |
| 历史/同步错误 | 日期错、重复、删除残留、Watch 状态不清 | 来源、幂等、导入预览、审计和恢复测试 |
| 身体适配偏见 | AI 把单一 Beta 当标准答案 | 可选 ClimberContext、多假设、ProofCheck |
| 色觉与路线混淆 | 只靠颜色造成错线、错记录 | 颜色名称 + 墙区 + 起点位置 + 照片/编号 |
| 岩馆反馈误伤 | 低 send 率被误解为坏线 | 分层样本、定性原因、阈值和申诉机制 |

---

## 15. 最终产品方向

### 15.1 一句话定位

> **LineWise 帮助室内抱石者记住一次失败真正值得保留的东西，并在下一次上墙时验证它。**

它不是“功能最全的攀岩 App”，而是“把一次尝试变成个人学习证据的 App”。

### 15.2 P0 产品

```text
Private Route Memory
+ Multi-mode Capture
+ FailureEpisode
+ MoveCue
+ NextSessionCue
+ ProofCheck
```

### 15.3 Watch 的角色

> Apple Watch 是低干扰 capture accelerator，不是产品存在的唯一理由，也不是每个用户必须佩戴的硬件。

### 15.4 AI 的角色

> AI 先减少整理和标注成本，再生成多个可校正假设；它不代替用户、教练或定线员定义真相。

### 15.5 岩馆的角色

> 岩馆先是验证场景和分发渠道，之后才可能成为官方路线、换线信息、教练服务与匿名反馈的合作方。

### 15.6 最值得做的下一步

先做一个不依赖生产代码的真实岩馆实验：连续三次到馆，分别使用 Watch、iPhone quick capture、review-only，验证同一条 Project 的 `FailureEpisode -> MoveCue -> NextSessionCue -> ProofCheck`。

如果这个闭环不能帮助用户做出更好的下一次尝试，就不应继续扩展 AI 读线、搭子、课程或岩馆合作。

### 15.7 本轮重新调研后的决策清单

| 决策 | 状态 |
| --- | --- |
| 保留 LineWise / 线感 | 保留，名称仍贴合“读线与形成线感” |
| P0 做私人学习闭环 | 确认 |
| Watch 为可选采集器 | 确认，并增加 Health/FIT/Photos 导入策略 |
| 火柴人、姿态、重心作为差异化 | 否决，已有直接竞品 |
| AI 自动读线直接进入 MVP | 否决，先建立可校正路线与 ProofCheck 数据 |
| P0 做搭子和社区 | 否决，先区分 AI 私人伴侣与真人匹配 |
| P0 做岩馆 SaaS | 否决，先用户自建，再测低维护元数据合作 |
| 新增历史补录与数据来源 | 确认，是可靠性硬需求 |
| 新增个体差异与可访问性 | 确认，P0 做路线冗余身份，P1 做可选 ClimberContext |
| 核心指标采用记录量 | 否决，采用 cue recall、ProofCheck 和修正成本 |

---

## 16. 核心资料

### 中国市场与岩馆

- [2024 中国攀岩行业发展报告介绍](https://www.datastory.com.cn/details/1219.html)
- [中华全国体育总会：岩点经济](https://www.sport.org.cn/shouye/tycy/2026/0611/698997.html)
- [Banana Climbing](https://bananaclimbing.com/)
- [上海市政府：香蕉攀岩上海第二家门店](https://english.shanghai.gov.cn/en-Fitness/20250721/e484c72d3646431cb5a8201eb2ba0dfc.html)
- [GB 19079.4-2025 国家标准](https://openstd.samr.gov.cn/bzgk/std/newGbInfo?hcno=7610EFE44A5347A8E0F6102B7D748C42)
- [体育总局：攀岩场馆安全管理](https://www.sport.gov.cn/dszx/n5414/c29427787/content.html)
- [36 氪：攀岩馆商业模式、教练与定线投入](https://36kr.com/p/3721557299689861)
- [岩馆群访：线路、空间、女性适配与试爬](https://www.sohu.com/a/989252629_121124646)
- [小宇宙：香蕉攀岩经营、教练与定线讨论](https://www.xiaoyuzhoufm.com/episode/67d5a44b0766616acd30cc9e)
- [视觉障碍岩馆可访问性清单](https://climbingbusinessjournal.com/justin-salas-on-visual-impairment-accessibility-in-climbing-gyms-checklist-included/)

### 当前竞品

- [磕磕 App Store](https://apps.apple.com/hk/app/%E7%A3%95%E7%A3%95-%E6%94%80%E5%B2%A9%E8%AE%B0%E5%BD%95%E4%B8%8E-beta-%E7%A4%BE%E5%8C%BA/id6760823408)
- [攀岩么 App Store](https://apps.apple.com/tw/app/%E6%94%80%E5%B2%A9%E4%B9%88/id6775133615)
- [攀岩科学 App Store](https://apps.apple.com/cn/app/%E6%94%80%E5%B2%A9%E7%A7%91%E5%AD%A6/id6738903694)
- [ClimbPin 岩钉 App Store](https://apps.apple.com/cn/app/climbpin-%E5%B2%A9%E9%92%89/id6755990150)
- [GoTop App Store](https://apps.apple.com/cn/app/gotop/id6757733784)
- [壁记 App Store](https://apps.apple.com/cn/app/%E5%A3%81%E8%AE%B0-%E8%AE%B0%E5%BD%95%E4%BD%A0%E7%9A%84%E6%AF%8F%E4%B8%80%E6%AC%A1%E6%94%80%E7%99%BB/id6749840034)
- [岩究生 App Store](https://apps.apple.com/cn/app/%E5%B2%A9%E7%A9%B6%E7%94%9F/id6740552981)
- [攀岩笔记 App Store](https://apps.apple.com/cn/app/%E6%94%80%E5%B2%A9%E7%AC%94%E8%AE%B0/id6471394121)
- [Redpoint Reviews](https://apps.apple.com/us/app/redpoint-bouldering-climbing/id1324072645?platform=watch&see-all=reviews)
- [Pinnacle Climb Log](https://apps.apple.com/us/app/pinnacle-climb-log/id1271954104)
- [TopLogger for Gym Owners](https://toplogger.nu/gym-owners)
- [Griptonite Route Manager](https://griptonite.io/gyms/route-manager/)
- [Crux Official Climbs](https://docs.cruxapp.ca/documentation-for-gym-staff/about-crux/optional-feature-gym-set-climbs)

### Apple 平台

- [Apple: Running workout sessions](https://developer.apple.com/documentation/HealthKit/running-workout-sessions)
- [Apple: WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity)
- [Apple: Health and Fitness apps](https://developer.apple.com/health-fitness/)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [Apple: Core Motion](https://developer.apple.com/documentation/coremotion/)

### 研究与用户反馈

- [The Way Up: Hold Usage Detection](https://openaccess.thecvf.com/content/CVPR2025W/CVSPORTS/html/Maschek_The_Way_Up_A_Dataset_for_Hold_Usage_Detection_in_CVPRW_2025_paper.html)
- [augKlimb](https://arxiv.org/abs/2001.07944)
- [Efficacy of route visual inspection](https://pubmed.ncbi.nlm.nih.gov/20561271/)
- [Embodied planning in climbing](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1337878/full)
- [Cognitive-behavioural processes during boulder previewing](https://pubmed.ncbi.nlm.nih.gov/38740079/)
- [On-sight and red-point route-finding ability](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2020.00902/full)
- [Climbing journal and logger discussion](https://www.reddit.com/r/climbharder/comments/1kydfn6)
- [Smart watches during bouldering](https://www.reddit.com/r/bouldering/comments/1fljsbo/does_anyone_use_fitness_trackers_smart_watches/)
- [Bouldering with colour blindness](https://www.reddit.com/r/bouldering/comments/1119n3k/bouldering_with_colour_blindness/)
- [Kilter App data continuity incident](https://www.climbing.com/news/why-the-kilter-board-app-suddenly-disappeared/)
