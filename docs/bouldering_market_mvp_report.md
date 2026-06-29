# 攀岩 / Bouldering Apple Watch App 市场调研与 MVP 方案报告

Date moved into project: 2026-05-24  
Project: `climb`  
Naming note: `抱石` 的英文是 **Bouldering**。This file was moved from the old root `baoshi.md` to `climb/docs/bouldering_market_mvp_report.md`.

> Status update, 2026-05-24: This is the original broad market/MVP report. The current primary multi-agent review and product-direction report is `docs/climbing_bouldering_research_report_v1.md`. Use that file first for the latest scope, risks, MVP gates, and next-step decisions.

> 目标：设计一款**接近可上线标准、真正有市场价值**的攀岩 Apple Watch App，而不是泛泛堆功能。你的原始需求明确要求覆盖市场调研、用户需求、竞品、Apple Watch 数据能力、产品定位、MVP、风险和验证，并回答“只做一个 MVP 应该做什么”这个核心问题。
> 结论先行：**最值得做的 MVP 是「Attempt Copilot」——一个面向室内抱石与训练型攀岩者的 Apple Watch 低干扰训练记录与复盘助手。**

---

## 1. Executive Summary

### 最终判断

**不要先做路线库、社区、户外 guidebook、完整训练计划、视频 AI、自动动作诊断，也不要承诺“自动识别每条路线是否完成”。**

最值得先做的是：

> **一款 Watch-first 的攀岩 session 记录器：低干扰记录训练时长、心率、攀爬/休息节奏、attempt 数、send/fail 状态，并在 iPhone 上生成可修正、可复盘的训练摘要。**

它的核心闭环是：

**开始训练 → Watch 被动采集 → 休息时一键标记 attempt/send/fail → 结束后 iPhone 复盘 → 下次训练看到 project 与进步趋势。**

### 为什么是这个 MVP

| 问题                   | 判断                                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| 攀岩用户真正痛点             | 不是“没有 App”，而是现有工具要么太偏路线库/社区，要么太偏训练计划，要么只给泛运动指标；用户很难低成本记录 attempt、休息、send、project 和训练质量。         |
| Apple Watch 真正适合解决什么 | 适合做**低干扰、贴身、实时、短操作、触觉提醒、HealthKit 同步**；不适合做复杂路线输入、完整动作识别、hold 识别、beta 推荐。                       |
| 差异化在哪里               | 把攀岩独有的 **attempt/rest/send/project** 和 Apple Watch 的 **心率/时长/触觉/HealthKit** 结合，而不是复制路线库或普通运动记录。 |
| MVP 场景               | 首选**室内抱石 + 进阶训练用户**；频次高、attempt 多、休息重要、手机不方便、路线库依赖低。                                            |
| 核心产品原则               | **半自动、可修正、低干扰、不过度承诺。** 自动识别只作为候选，不作为绝对事实。                                                       |

### 最高优先级功能

| MVP 功能                             |   是否必须 | 原因                                                                                           |
| ---------------------------------- | -----: | -------------------------------------------------------------------------------------------- |
| Watch 开始/暂停/结束攀岩训练                 |     必须 | 基础入口，支持 HealthKit/Fitness 闭环。Apple Watch 已支持 Climbing workout 类型。([苹果支持][1])                 |
| 训练时长、心率、休息计时                       |     必须 | 数据可靠性相对最高，且能直接服务复盘。Workout session 可让 Apple Watch 传感器针对运动优化，并生成高频心率样本。([Apple Developer][2]) |
| 一键记录 attempt / send / fail / flash |     必须 | 这是攀岩区别于跑步、骑行的关键事件。不能只记录 calories 和 duration。                                                 |
| 休息提醒与触觉反馈                          |     必须 | 攀岩是多次高强度尝试 + 间歇恢复，触觉比视觉更适合训练中提醒。watchOS 设计也强调 glanceable 和短交互。([Apple Developer][3])         |
| iPhone 端 session 复盘与可编辑            |     必须 | 自动识别会误判；必须允许用户训练后修正 attempt、grade、结果和备注。                                                     |
| 自动 attempt/rest 候选识别               |  应做但谨慎 | 作为“辅助分段”，不是核心承诺。单腕 IMU 无法可靠还原全身动作。                                                           |
| 路线库、社区、户外 guidebook                | 不做 MVP | 已有强竞品，维护成本高，Watch 端价值弱。                                                                      |

---

## 2. 调研方法与证据等级

本报告将信息分为四类，这也符合你要求的证据标准：事实证据、用户反馈、合理推断、待验证假设。

| 类型    | 来源                                           | 可信度 | 使用方式                    |
| ----- | -------------------------------------------- | --: | ----------------------- |
| 事实证据  | Apple 官方文档、App Store、竞品官网、开发者文档              |   高 | 用于确认技术能力、竞品功能、付费模式、平台限制 |
| 用户反馈  | App Store 评论、Reddit、Mountain Project 论坛、产品评论 |   中 | 用于发现痛点，但样本有偏，需要后续访谈验证   |
| 合理推断  | 基于攀岩场景、Watch 交互限制、竞品空白                       |   中 | 用于产品方向、MVP 收敛           |
| 待验证假设 | 用户付费意愿、自动分段准确率、留存                            | 低-中 | 必须通过原型、传感器实验和 beta 测试验证 |

### 关键结论证据表

| 结论                                       | 证据类型            | 可信度 | 是否需验证 | 产品影响 |
| ---------------------------------------- | --------------- | --: | ----: | ---: |
| 攀岩记录 App 已很多，但大多围绕路线库、社区、训练计划或 guidebook | 竞品官网/App Store  |   高 |     否 |    高 |
| 用户对“记录麻烦、泛运动指标不够攀岩化、自动识别不准”有明显吐槽         | 社区与评论           |   中 |     是 |    高 |
| Apple Watch 适合记录时长、心率、休息、触觉提醒和快速标记       | Apple 官方文档 + 推断 |   高 |    部分 |    高 |
| 自动识别 bouldering attempt 不能作为 MVP 核心承诺    | 用户反馈 + 技术推断     | 中-高 |     是 |    高 |
| 室内抱石是最适合 MVP 的首发场景                       | 市场数据 + 场景推断     |   中 |     是 |    高 |
| 付费潜力主要来自复盘、长期趋势、project 管理、训练负荷，而不是单次打卡  | 竞品付费边界 + 推断     |   中 |     是 |    高 |

---

## 3. 市场与竞品分析

### 3.1 市场背景

北美商业攀岩馆数量仍在增长。Climbing Business Journal 统计显示，2024 年北美攀岩馆数量超过 870 家，且抱石馆占新增岩馆的 73%；到 2025 年底，北美攀岩馆总数已超过 900 家。([Climbing Business Journal][4])

这说明两个对产品重要的事实：

1. **室内攀岩，尤其抱石，训练频次高、用户行为重复、适合做软件习惯。**
2. **路线维护、岩馆合作、社区网络效应很难冷启动；MVP 不宜一开始依赖完整岩馆路线库。**

---

## 4. 竞品矩阵

### 4.1 攀岩垂直 App / 路线库 / 社区类

| 产品                                   | 定位                      | 核心能力                                                                                                                               | Watch 支持        | 复盘能力                       | 付费/商业模式                                               | 高频启发                  | 明显短板                                                        |
| ------------------------------------ | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------- | -------------------------- | ----------------------------------------------------- | --------------------- | ----------------------------------------------------------- |
| **KAYA**                             | 户外/室内路线、beta、社区、logbook | GPS/offline maps、beta 视频、log sends、progress、gym/community；官方称有大量 beta 视频、户外 climbs 和合作 gyms。([KAYA][5])                            | 非核心             | 偏 sends/history/statistics | KAYA Pro，guidebook 作者分成；媒体报道 Pro 为月订阅。([Climbing][6]) | guidebook、beta、社区强    | Watch-first 训练过程弱；用户也吐槽过 buggy、定位不清。([Mountain Project][7]) |
| **Mountain Project**                 | 户外路线数据库                 | 155k+ routes、offline route beta/photos/topos、attempts/sends/to-do、论坛，免费无广告。([App Store][8])                                        | 无明显 Watch-first | 户外 logbook 较基础             | 免费                                                    | 户外信息密度强               | 不解决室内训练中的 attempt/rest/强度复盘                                 |
| **27 Crags / The Topo**              | 户外 premium topo         | Verified topos、offline、GPS、grade/rating/style filter、3D map、log sends，订阅收入回流作者。([The Topo][9])                                     | 非核心             | 偏 sends                    | Premium topo 订阅                                       | 专业 topo 与作者生态         | 不是训练过程记录器                                                   |
| **Vertical-Life**                    | 户外 topo + 室内 gym + 训练   | 室内关注 gym、新路线、log ascents、排名、训练计划；gym 端有 route feedback 与 routesetter 数据。([App Store][10])                                          | 非核心             | 有 logbook/training         | Premium 订阅，公开页面显示月费/年付信息。([8a.nu][11])                | 室内/户外/gym B2B 结合      | 复杂生态，MVP 不宜复制                                               |
| **MyClimb**                          | 攀岩记录、社区、训练、gym leagues  | 官方称 3M+ climbs、100+ countries、3,500+ gyms；支持 log climbs/hangboard、goals、training、graphs。([Climbing Business Journal][12])          | 非核心             | 有 goals/graphs             | gym/competition/community                             | 记录与目标系统值得借鉴           | 范围太广，用户反馈中有人觉得启动/社交体验不佳。([Reddit][13])                      |
| **Crimpd**                           | 专业攀岩训练                  | Tom Randall/Ollie Torr 设计训练，覆盖 endurance、power endurance、strength、conditioning、mobility；内置 hangboard/interval timer。([Crimpd][14]) | 非核心             | 偏训练计划/完成度                  | Free + Crimpd+                                        | 训练内容专业                | 不解决普通攀岩 session 的低成本记录                                      |
| **TopLogger**                        | 室内岩馆 route/log/ranking  | log indoor climbs、dashboard、progress、rankings、新路线；gym 端 route popularity、setter、grade 数据。([App Store][15])                         | 非核心             | grade/progress             | gym SaaS / competitions                               | 岩馆数据闭环强               | 依赖 gym 接入，冷启动难                                              |
| **Griptonite**                       | 室内岩馆软件 + climber app    | Route Manager、GymTV、smart tags、logbook、video betas、notes、progress。([Griptonite][16])                                               | 非核心             | 有进步可视化                     | gym SaaS                                              | route 与 gym 运营强       | 对独立 Watch MVP 不是直接路径                                        |
| **MoonBoard / Kilter / Tension**     | 标准化训练板                  | 搜索/创建 problems、log ascents、LED 联动、排行榜、beta 视频。([MoonClimbing][17])                                                                 | 非核心             | board-specific             | 硬件生态                                                  | 标准化路线让记录更准确           | 只适合训练板，不覆盖普通岩馆                                              |
| **Retro Flash / Stōkt / BoulderBot** | spray wall / home wall  | 创建、分享、记录 spray wall problems；BoulderBot 支持生成 problems、组织 climbs、track progress。([Google Play][18])                                 | 非核心             | wall-specific              | app/社区/墙体生态                                           | project/logbook 思路可借鉴 | 场景窄，Watch 价值仍弱                                              |

### 4.2 Watch / 运动记录 / 攀岩记录类

| 产品                             | 定位                           | Watch 支持                                                                                                                            | 数据能力                      | 用户反馈/短板                                                                          | 对本产品启发                    |
| ------------------------------ | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------- | ------------------------- |
| **Apple Fitness / Workout**    | 泛运动记录                        | Apple Watch 原生支持 Climbing workout。([苹果支持][1])                                                                                       | 心率、时长、能量、Workout 记录       | 无 route、attempt、send、project、休息复盘                                                | 可作为底层记录，但不是攀岩产品           |
| **Redpoint**                   | Apple Watch 攀岩 tracker       | Watch/iPhone，使用气压传感器和 HealthKit，自动 logbook；App Store 页面也声称用 ML 分类攀岩运动。([Redpoint][19])                                              | ascent、高度、grade、HealthKit | 有用户评论称自动 tracking 误判，一次 session 变成 70+ ascents；暂停 belay 时仍随机计数。([App Store][20]) | 自动化必须可修正，不能过度承诺           |
| **Climb Meter**                | Apple Watch climbing tracker | Apple Watch + Apple Health，自动 climb counting、grade logging、elevation、HR cooldown。([App Store][21])                                  | barometer、高度、HR           | 开发者反馈：适合绳索攀，bouldering 高度太低，无法可靠检测。([App Store][21])                             | bouldering 不应依赖高度自动计数     |
| **Pinnacle Climb Log**         | Watch/iPhone 攀岩 log          | one-tap log climb、long-tap attempt、HR/calories、离线 watch 后同步。([App Store][22])                                                       | 手动/半手动 log + Health       | 有用户喜欢 indoor watch logging；也有忘记停止导致异常记录的 badcase。([Mountain Project][23])        | 低干扰手动标记方向正确，但需强兜底         |
| **COROS Climb / Garmin Climb** | 运动手表攀岩模式                     | Garmin 可记录 bouldering routes 与 grading system；COROS Indoor Climb 支持 route count、grade、falls、route HR、training load 等。([Garmin][24]) | 运动表强项：电量、户外、训练负荷          | Garmin 用户反馈过自动 start/finish 不准且分心。([Mountain Project][25])                       | Apple Watch App 需避免复杂中途操作 |
| **Strava**                     | 泛运动社交记录                      | 支持 rock climbing 作为运动类型，但许多高级功能仍集中在 ride/run/swim 等核心运动。([Strava][26])                                                              | 社交、路线、运动历史                | 对攀岩的 attempt/rest/route 完成度支持不足                                                  | 可做分享目的地，不应当做核心            |

### 竞品结论

现有市场已经覆盖了四大方向：

1. **路线库 / guidebook / topo**：KAYA、Mountain Project、27 Crags、Vertical-Life。
2. **岩馆路线与社区**：TopLogger、Griptonite、Vertical-Life、MyClimb。
3. **训练计划**：Crimpd、board apps、训练板生态。
4. **Watch 攀岩记录**：Redpoint、Climb Meter、Pinnacle、Apple Workout。

但明显空白是：

> **一个真正围绕“攀岩训练过程中的 attempt / rest / intensity / send / project”设计的低干扰 Apple Watch 伴侣。**

---

## 5. 用户反馈与 badcase 总结

### 5.1 高频痛点

| 痛点                      | 用户反馈证据                                                                                                                 | 产品含义                       |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 记录太麻烦                   | 有用户询问如何记录 workouts/sends，并在 app、Excel、analog 之间犹豫，希望能 graph/analyze data。([Reddit][27])                                | MVP 必须减少输入；训练中只能一键标记       |
| 现有 app 太路线库化，不像个人训练 log | 有用户寻找“像 Strava 一样的 personal climbing log”，希望记录 personal growth/goals/videos，而不是被 crag/route listing 限制。([Reddit][28])  | 不要先做大型路线库；先做个人训练闭环         |
| 普通运动指标对攀岩不足             | Mountain Project 用户从跑步/骑行训练负荷视角评价 climbing tracking underwhelming，想要 effort/training tracking。([Mountain Project][29]) | 不能只显示 calories、HR、duration |
| 自动识别不准会毁体验              | Redpoint 用户反馈误计大量 ascents；Climb Meter 开发者也承认 bouldering 高度太低不可靠。([App Store][20])                                      | 自动化必须是“候选 + 校正”，不是卖点承诺     |
| 过度记录会分心                 | 有用户讨论 tracking 时指出，有些人会 log everything，有些人不想被 phone/remembering climbs 干扰。([Reddit][30])                               | 训练中交互应极简；复杂输入放 iPhone      |
| 训练复盘需要“刚好足够”            | 用户希望优雅、简单、颗粒度足够的 log，包括 success/failure、wall angle、holds、techniques 等。([Reddit][31])                                   | 提供可选字段，不强迫填写               |
| 休息时间重要但因人而异             | 社区关于 bouldering rest interval 的讨论显示，用户对休息有需求，但答案依难度、体能、动作类型变化。([Reddit][32])                                           | 休息提醒要可配置，不能强制“科学答案”        |
| 心率/卡路里信任度有限             | Apple 明确说明心率传感器受佩戴、皮肤、动作影响，且不规则运动比有节奏运动更难测；攀岩社区也有人质疑 climbing calories 准确性。([苹果支持][33])                                | calories 只作为附属，不做核心价值      |

### 5.2 badcase 转产品原则

| badcase    | MVP 是否必须解决 | 产品原则                                     |
| ---------- | ---------: | ---------------------------------------- |
| 记录太麻烦      |         必须 | Watch 上每次操作不超过 1-2 步                     |
| 自动识别误判     |         必须 | 自动识别只做候选，默认可撤销、可编辑                       |
| 看不到有价值复盘   |         必须 | 结束后必须给出 session summary                  |
| 普通运动指标没意义  |         必须 | 指标必须转译为攀岩语言：attempt、send、rest、project、强度 |
| 心率/卡路里不可信  |       必须规避 | 展示趋势与区间，不给医疗或精确能耗承诺                      |
| 室内路线更新快    | MVP 不解决路线库 | 用手动 grade/color/project 替代完整 route DB    |
| Watch 操作复杂 |         必须 | 休息时交互，攀爬时不看屏                             |
| 户外能力门槛高    |        暂不做 | 不把户外 safety 当 MVP                        |
| 缺少长期趋势     |      P1/P2 | MVP 可做基础趋势，Pro 做高级分析                     |
| 社交不够       |      P2/P3 | 先证明个人价值，再做分享                             |

---

## 6. 用户画像与核心需求

用户需求不能按“攀岩者”一刀切。你的需求中明确要求按新手、室内抱石、进阶训练、先锋/顶绳、户外、教练、数据控、轻量打卡拆分。

| 用户类型    | 核心目标                    | 当前方案                               | 当前痛点                   | Watch 接受度 | 手动输入接受度 | 付费可能 | MVP 重要性 |
| ------- | ----------------------- | ---------------------------------- | ---------------------- | --------: | ------: | ---: | ------: |
| 新手      | 安全感、成就感、知道自己练了什么        | Apple Workout、拍照、朋友记录              | 不懂 grade，不知道是否进步       |         中 |       低 |  低-中 |       中 |
| 室内抱石用户  | 记录多次尝试、send、flash、rest  | 纸笔、备忘录、Pinnacle、MyClimb、岩馆 app     | attempt 多，训练中不想拿手机     |         高 |       中 |    中 |   **高** |
| 进阶训练用户  | 训练负荷、弱项、恢复、project      | Crimpd、Excel、视频、教练                 | 数据分散，复盘难               |         高 |     中-高 |    高 |   **高** |
| 先锋/顶绳用户 | route 完成、单次攀爬时长、心理压力、恢复 | Apple Workout、Redpoint、Climb Meter | belay/rest 与 climb 难区分 |         中 |       中 |    中 |       中 |
| 户外攀岩用户  | 地点、路线、天气、离线、安全          | Mountain Project、KAYA、27 Crags     | Watch 小屏不适合 topo       |         中 |       低 |    中 |       低 |
| 教练/私教   | 学员训练负荷、动作问题、计划执行        | 口头记录、表格、视频                         | 数据结构化不足                |         中 |       高 |    高 |      P2 |
| 数据控     | 心率、趋势、HealthKit、恢复      | Apple Health、Whoop、Garmin、COROS    | 缺攀岩语义层                 |         高 |       中 |    高 |       高 |
| 轻量打卡    | 好看、成就感、分享               | 小红书/朋友圈/Strava                     | 不想复杂                   |         中 |       低 |    低 |       中 |

### MVP 首选用户

**首选：室内抱石 + 进阶训练 + Apple Watch 用户。**

原因：

1. 高频使用，每周 2-4 次训练更容易形成习惯。
2. attempt/rest/send 是强需求，普通 Fitness 无法满足。
3. 不依赖户外路线库，降低冷启动难度。
4. Watch 的低干扰记录和触觉提醒价值最大。
5. 这类用户更愿意为复盘、趋势、project 管理付费。

---

## 7. 攀岩场景拆解

攀岩不是单一运动。抱石、先锋、顶绳、户外、训练课、路线复盘的交互窗口和数据价值完全不同。

| 场景      | 用户当下在做什么       | 最关心什么                            | Watch 是否适合 | 自动数据                            | 必须手动                          | 最小功能                    | 高阶功能                    | MVP 适配 |
| ------- | -------------- | -------------------------------- | ---------- | ------------------------------- | ----------------------------- | ----------------------- | ----------------------- | -----: |
| 抱石      | 短尝试、多次失败、休息    | attempt、send、flash、休息够不够         | **高**      | HR、时间、motion、候选休息段              | grade/color、send/fail、project | 一键 attempt + rest timer | attempt 自动候选、project 趋势 | **最高** |
| 先锋 Lead | 长路线、belay、心理压力 | climb duration、fall、route result | 中          | HR、时间、气压高度可能有用                  | route、grade、fall/send         | 开始/结束 + route result    | rope-specific segment   |      中 |
| 顶绳      | 入门/练习          | 完成度、练习强度                         | 中          | HR、时间                           | route/result                  | 训练记录                    | 新手引导                    |      中 |
| Trad/户外 | 导航、天气、装备、安全    | topo、位置、离线                       | 低-中        | GPS、海拔、时间                       | route、risk、gear               | 记录地点和 session           | emergency info、weather  |      低 |
| 室内岩馆    | 路线更新快          | 快速记录颜色、区域、grade                  | 高          | 时间、HR                           | color/grade/wall              | preset + quick mark     | gym integration         |      高 |
| 训练课     | 计划执行、休息、强度     | 教练安排、负荷                          | 中-高        | HR、时间、rest                      | workout item result           | timer + intensity       | coach dashboard         |     P2 |
| 路线复盘    | 训练后回顾          | 哪条卡住、下次怎么练                       | iPhone 更适合 | session data                    | 备注、原因、视频                      | summary                 | project journal         |      高 |
| 疲劳管理    | 休息/结束判断        | 是否过量                             | 中          | HR recovery、rest ratio、duration | 主观疲劳                          | soft hint               | readiness/load          |  P1/P2 |

### 场景结论

**MVP 不应做“攀岩全场景 App”。**

首发应聚焦：

> **室内抱石 session：attempt 记录 + 休息计时 + 心率/强度 + 训练后复盘。**

---

## 8. Apple Watch 数据能力分析

### 8.1 官方能力基础

Apple Watch 可以通过 Workout/HealthKit 记录运动，并写入 HealthKit。HealthKit 权限是细粒度授权，App 需要分别请求读取和写入健康数据权限。([Apple Developer][34])

Workout session 会让 Apple Watch 针对指定运动优化传感器，并生成高频心率样本。([Apple Developer][2]) Core Motion 能提供 watchOS 上的运动/环境传感器数据；device motion 融合 accelerometer 与 gyroscope，最大支持频率可达 100 Hz。([Apple Developer][35]) Core Location 可提供地理位置、海拔、方向等，但需要定位授权。([Apple Developer][36])

### 8.2 数据能力表

| 数据                | 能拿到什么                          |            授权 | 攀岩价值                        | 不能推断什么                | 误判风险                                                      | 实时/复盘   |     MVP |
| ----------------- | ------------------------------ | ------------: | --------------------------- | --------------------- | --------------------------------------------------------- | ------- | ------: |
| 心率                | 实时/平均/最高/恢复心率、HR zones         |     HealthKit | 强度、恢复、休息是否足够的参考             | 不能证明动作质量、不能精确表示疲劳     | 佩戴、汗水、镁粉、手腕弯曲、动作不规则影响；Apple 也说明不规则运动比节奏运动更难测。([苹果支持][33]) | 实时 + 复盘 |       是 |
| 运动时长              | session 总时长、attempt 时间、rest 时间 |       Workout | 最可靠基础指标                     | 不能知道 route 难度         | 用户忘记结束会异常                                                 | 实时 + 复盘 |       是 |
| 活动能量/卡路里          | active energy、total energy     |     HealthKit | 可附属显示                       | 不适合作核心价值              | 攀岩间歇、静态发力、心理压力导致估算偏差                                      | 复盘      |      附属 |
| 加速度计              | 手腕加速度、运动强度                     |   Core Motion | 识别活动/休息候选、突然移动、节奏变化         | 不能识别 hold、脚法、全身姿态     | 手腕不是身体整体；喝水、整理装备、聊天会误判                                    | 复盘为主    |    是，谨慎 |
| 陀螺仪               | 手腕角速度、方向变化                     |   Core Motion | 手部动作节奏、attempt 候选           | 不能识别具体技术动作            | 动作多样，个人差异大                                                | 复盘为主    |    是，谨慎 |
| 气压计/海拔            | 高度变化                           |    设备传感器/系统数据 | 绳索攀、户外、多 pitch 可能有用         | bouldering 高度太小，不可靠   | 室内气压漂移、楼层、电梯、短高度                                          | 复盘      | 不作为抱石核心 |
| GPS/位置            | crag/gym 位置、户外轨迹               | Core Location | 户外 session、地点历史             | 室内路线、具体墙面             | 室内定位差、电量消耗                                                | 复盘      |      P2 |
| HealthKit Workout | 写入 Climbing workout、能量、心率、历史   |     HealthKit | 与 Apple Fitness/Health 生态整合 | 不包含攀岩 attempt 语义      | 权限/同步失败                                                   | 复盘      |       是 |
| 手腕 motion 轨迹      | 单腕 motion pattern              |   Core Motion | attempt/rest 候选、运动量 proxy   | 不能还原全身动作、hold、beta、脚法 | 戴表手/非戴表手差异，双手动作不对称                                        | 复盘      |     仅辅助 |
| 设备状态              | 电量、后台、触觉、AOD、通知                |       watchOS | 低电量提示、触觉提醒、低干扰              | 不能保证无限后台              | workout 结束/锁屏/电量                                          | 实时      |       是 |

### 关键技术判断

**Apple Watch 可以可靠做：**

1. session 级记录；
2. 心率和时间趋势；
3. 休息计时；
4. 低干扰触觉提醒；
5. HealthKit/Fitness 同步；
6. 基于 motion 的 attempt/rest 候选分段。

**Apple Watch 不应承诺：**

1. 自动识别具体 hold；
2. 自动判断脚法、drop knee、flag、heel hook；
3. 自动还原完整动作；
4. 自动判断路线完成百分比；
5. 精确攀岩 calories；
6. 医疗级疲劳/安全预警。

---

## 9. 攀岩与跑步/骑行/健身的本质区别

| 维度       | 跑步/骑行                       | 攀岩                                   |
| -------- | --------------------------- | ------------------------------------ |
| 运动结构     | 周期性、连续、路径明确                 | 非周期性、间歇、高强度、多尝试                      |
| 关键事件     | pace、distance、lap、elevation | attempt、send、fall、rest、project、grade |
| 主要数据     | 距离、速度、配速、功率                 | 尝试次数、完成状态、休息、局部疲劳、主观难度               |
| 自动识别难度   | 中等，轨迹/速度强相关                 | 高，动作多样且单腕不可见全身                       |
| 复盘问题     | 我跑得快了吗？                     | 我哪条线卡住？休息够吗？是否过度尝试？最近是否进步？           |
| Watch 交互 | 运动中可看屏                      | 攀爬中不应看屏，休息时才适合交互                     |

攀岩研究也表明，sport climbing 具有高强度、局部肌肉需求和短间歇恢复特征，这和跑步、骑行这种连续周期运动不同。([Springer][37])

---

## 10. 产品机会点

### 核心机会

> **把 Apple Watch 从“泛运动记录器”变成“攀岩 attempt/rest 事件记录器”。**

现有产品要么强在路线库，要么强在训练内容，要么强在泛运动数据。真正的机会在中间：

**攀岩 session 中发生了什么？**

* 练了多久？
* 做了几次有效 attempt？
* 哪些 send / fail / flash？
* 休息是否越来越长？
* 心率恢复是否变差？
* 哪个 project 反复失败？
* 下次训练应该先做什么？

### 差异化产品切口

| 差异化点                        | 为什么有价值                              |
| --------------------------- | ----------------------------------- |
| Watch-first，而不是 phone-first | 攀岩时手机不方便，Watch 在手腕上，适合短操作           |
| 半自动 attempt/rest            | 自动化降低记录成本，可修正确保可信                   |
| 以 rest 为核心 UI               | 抱石训练中休息时间比“运动中看屏”更适合介入              |
| HealthKit + 攀岩语义层           | 不只是写入 Workout，而是把数据转译为攀岩复盘          |
| project journal             | 连接 session 与长期进步                    |
| 不依赖路线库                      | 降低冷启动，避开 KAYA/MP/Vertical-Life 等强竞品 |

---

## 11. 候选产品方向评估

| 方向             | 目标用户      | 核心价值                        | Watch 可行性 | 技术风险 | 长期使用 | 付费潜力 | 是否进 MVP |   优先级 |
| -------------- | --------- | --------------------------- | --------: | ---: | ---: | ---: | ------: | ----: |
| 攀岩训练记录器        | 抱石/进阶/数据控 | 记录 session、HR、rest、attempt  |         高 |    中 |    高 |  中-高 |       是 |    P0 |
| 抱石 attempt 追踪器 | 室内抱石      | attempt/send/fail/flash     |         高 |    中 |    高 |    中 |       是 |    P0 |
| 休息与疲劳管理        | 训练用户      | rest timer、HR recovery hint |         高 |    中 |    高 |    中 |       是 | P0/P1 |
| 攀岩复盘助手         | 进阶/数据控    | session summary、趋势、建议       |         中 |    中 |    高 |    高 |       是 | P0/P1 |
| project 管理     | 进阶用户      | 记录卡点、下次目标                   |         中 |    低 |    高 |    高 |      P1 |    P1 |
| 室内岩馆伴侣         | 室内用户      | color/grade/wall 快速记录       |         中 |    低 |    中 |    中 |      部分 |    P1 |
| 户外安全辅助         | 户外用户      | GPS、海拔、天气、紧急信息              |         中 |    高 |    中 |    中 |       否 |    P3 |
| 社交/成就系统        | 轻量用户      | 分享、streak、好友                |         中 |    中 |    中 |  低-中 |       否 |    P2 |
| 教练/训练计划        | 教练/进阶     | 计划、学员、周期                    |       低-中 |    中 |    中 |    高 |       否 | P2/P3 |

### 推荐方向

**P0：Attempt Copilot**

不是“攀岩版 Strava”，也不是“路线库”，而是：

> **攀岩训练过程中的 attempt/rest/强度记录与复盘助手。**

---

## 12. MVP 建议

### 12.1 一句话定位

**这不是一个泛运动记录 App，而是一个面向室内抱石与训练型攀岩者的 Apple Watch 伴侣，用最低干扰记录 attempt、send、rest、心率和训练状态，并在 iPhone 上生成可修正的攀岩复盘。**

### 12.2 MVP 核心用户

| 主用户              | 描述                                     |
| ---------------- | -------------------------------------- |
| 室内抱石用户           | 每周 1-4 次训练，经常 project，想知道尝试次数和 send 进展 |
| 进阶训练用户           | 关注强度、恢复、长期进步，愿意看数据                     |
| Apple Watch 重度用户 | 已经使用 Apple Fitness/Health，想把攀岩纳入健康数据   |
| 轻训练型用户           | 不想写复杂笔记，但愿意休息时点一下                      |

### 12.3 MVP 核心闭环

1. **Watch 端开始 Climbing Session**

   * Boulder / Rope / Training Timer 三种模式，MVP 可先保留 Boulder。
2. **训练中被动采集**

   * 时长、心率、motion、休息计时。
3. **休息时一键标记**

   * Attempt、Send、Fail、Flash、Undo。
4. **Watch 端即时反馈**

   * 当前休息时间、上次 attempt、心率趋势、建议休息提示。
5. **iPhone 端复盘**

   * 总时长、active/rest、attempt 数、send 数、flash、最长 project、心率区间、休息趋势、可编辑记录。
6. **下次训练继续 project**

   * 上次卡住的 project、建议先尝试、历史尝试次数。

### 12.4 MVP 功能列表

| 模块          | 功能                                              | 说明                                       |
| ----------- | ----------------------------------------------- | ---------------------------------------- |
| Watch 训练入口  | Start Boulder Session                           | 默认开始 Workout + HealthKit 记录              |
| Watch 实时页   | session timer、HR、rest timer、attempt count       | 信息一眼可读                                   |
| Attempt 标记  | Send / Fail / Flash / Try / Undo                | 休息时一键操作                                  |
| Rest 计时     | 自动/手动进入 rest，触觉提醒                               | 默认柔和提醒，不打断                               |
| 自动候选        | motion + HR + 时间窗口识别 climbing/resting/uncertain | 只做建议，不强制                                 |
| End Summary | Watch 上极简总结                                     | “12 attempts / 4 sends / best rest 2:30” |
| iPhone 复盘   | session detail、timeline、HR、rest、attempt list    | 可编辑、可补 grade/color/project               |
| HealthKit   | 写入 Climbing workout                             | 与 Fitness/Health 生态连接                    |
| 隐私与权限       | 健康数据、定位可选、透明说明                                  | local-first 优先                           |
| 同步兜底        | Watch 离线缓存，iPhone 后同步                           | 防止丢数据                                    |

### 12.5 明确不做

| 不做                       | 原因                   |
| ------------------------ | -------------------- |
| 完整路线库 / guidebook        | 竞品强、维护重、冷启动难         |
| 岩馆 SaaS                  | 销售周期长，不适合独立 MVP      |
| 自动识别 route / hold / beta | 单腕 Watch 数据不足        |
| 自动技术动作诊断                 | 高误判，需视频/外设           |
| 户外安全/救援承诺                | 高风险，App Store 与安全责任重 |
| 医疗级疲劳/异常心率建议             | 不能夸大健康能力             |
| 精确 calories 卖点           | 攀岩估算误差大              |
| 强社交 feed                 | 会分散核心训练价值            |

---

## 13. 功能优先级：RICE + Kano + MoSCoW

### 13.1 RICE 表

评分口径：Reach/Impact/Confidence/Effort 均为 1-5 或信心系数，RICE = Reach × Impact × Confidence / Effort。

| 功能                           | 用户价值   | 使用频率 | 技术可行性 | Watch 适配 | 风险      | 差异化 | RICE | Kano   | MoSCoW |    MVP |
| ---------------------------- | ------ | ---: | ----: | -------: | ------- | --- | ---: | ------ | ------ | -----: |
| Watch 开始/结束 Climbing workout | 基础记录   |   每次 |     高 |        高 | 忘记结束    | 中   |  9.0 | 基础型    | Must   |      是 |
| 心率/时长/休息计时                   | 训练强度基础 |   每次 |     高 |        高 | HR 噪声   | 中   |  8.5 | 期望型    | Must   |      是 |
| 一键 Send/Fail/Flash           | 攀岩核心事件 |   高频 |     高 |        高 | 误触      | 高   |  8.0 | 期望型    | Must   |      是 |
| Undo/编辑                      | 提升可信度  |   高频 |     高 |        高 | 无       | 高   |  7.2 | 基础型    | Must   |      是 |
| iPhone session 复盘            | 形成价值闭环 |   每次 |     高 |        中 | 复盘不够有用  | 高   |  5.3 | 期望型    | Must   |      是 |
| HealthKit 同步                 | 生态价值   |   每次 |     高 |        中 | 权限      | 中   |  5.0 | 基础型    | Must   |      是 |
| 自动 attempt/rest 候选           | 降低输入   |   高频 |     中 |        高 | 误判      | 高   |  2.6 | 兴奋型    | Should | 是，但弱承诺 |
| Project 卡片                   | 长期进步   |    中 |     高 |      低-中 | 输入成本    | 高   |  2.8 | 期望型    | Should |     P1 |
| Grade/color/wall preset      | 室内实用   |    中 |     高 |        中 | 输入复杂    | 中   |  3.2 | 期望型    | Should |     P1 |
| HR recovery / rest hint      | 训练建议   |    中 |     中 |        高 | 过度解释    | 高   |  2.5 | 兴奋型    | Should |     P1 |
| 视频片段关联                       | 复盘增强   |    中 |     中 |        低 | 隐私/存储   | 中   |  1.8 | 兴奋型    | Could  |     P2 |
| Strava 分享                    | 社交传播   |  低-中 |     中 |        低 | API/价值弱 | 低   |  1.5 | 兴奋型    | Could  |     P2 |
| 岩馆路线库                        | 路线管理   |    中 |     低 |        低 | 冷启动     | 中   |  0.8 | 期望型    | Won’t  |      否 |
| 自动技术诊断                       | 看起来酷   |    低 |     低 |        低 | 高误判     | 高   |  0.4 | 兴奋型    | Won’t  |      否 |
| 户外安全辅助                       | 户外用户   |    低 |     中 |        中 | 安全责任    | 中   |  0.5 | 基础/风险型 | Won’t  |      否 |

### 13.2 Kano 总结

| 类型    | 功能                                                                |
| ----- | ----------------------------------------------------------------- |
| 基础型需求 | 训练不丢、同步可靠、权限清晰、可撤销、可编辑、低电量提示、隐私说明                                 |
| 期望型需求 | attempt/send/fail、rest timer、HealthKit、session summary、project 历史 |
| 兴奋型需求 | 自动 attempt 候选、HR recovery hint、训练质量摘要、project trend、视频自动切片        |
| 反向需求  | 攀爬中频繁提醒、强制填写路线、误判后不能改、夸大安全/医疗能力                                   |

---

## 14. Watch / iPhone / 云端分工

你的需求中特别要求判断哪些放 Watch，哪些放 iPhone，哪些放云端。

| 功能                  |     Watch | iPhone |        云端 |
| ------------------- | --------: | -----: | --------: |
| 开始/结束训练             |         是 |     可选 |         否 |
| 实时 HR/计时/rest       |         是 |   镜像可选 |         否 |
| Send/Fail/Flash 标记  |         是 |    可编辑 |         否 |
| Attempt 候选识别        |    是，轻量规则 |   复盘修正 |  后续 ML 可选 |
| Grade/color/project | 简化 preset |   详细编辑 |       可同步 |
| Session summary     |        极简 |     完整 |       可备份 |
| 长期趋势                |         否 |      是 |        可选 |
| 视频/照片/备注            |         否 |      是 |        可选 |
| 社区/分享               |         否 |      是 |        可选 |
| 订阅/账号               |         否 |      是 |         是 |
| 岩馆路线库               |         否 |     后续 | 是，但不做 MVP |

### Watch 端设计原则

1. **训练中不要复杂输入。**
2. **攀爬中不诱导看屏。**
3. **休息时才交互。**
4. **大数字、少文字、强对比。**
5. **触觉优先于视觉。**
6. **所有操作可撤销。**
7. **低电量时自动降级。**
8. **同步失败不丢 session。**

Apple 的 watchOS 人机界面指南也强调 watch app 应该 glanceable，交互短，并适配 Always On 等手表场景。([Apple Developer][3])

---

## 15. UI/UX 方案

你的需求明确要求 Watch 首页、训练中页、休息页、尝试记录页、结束训练页、iPhone 复盘页、错误状态和核心交互流程。

### 15.1 Watch 首页

```
[Start Boulder]
[Start Rope]
[Training Timer]
[Last Project]
```

默认突出 **Start Boulder**。
二级入口才放设置、历史、同步状态。

### 15.2 训练中页面

显示：

```
Session  42:18
HR       138
Attempts  9
Rest     02:14
```

按钮：

* Mark Attempt
* Pause
* End 长按确认

原则：攀爬中不做弹窗，不做复杂通知。

### 15.3 休息页面

```
Rest 02:36
Last: Fail / V5 / Project A
[Send] [Fail]
[Try]  [Undo]
```

触觉提醒：

* 休息 2 分钟：轻触觉；
* 休息 4 分钟：可选提醒；
* 心率未恢复：只提示“consider more rest”，不做医学判断。

### 15.4 尝试记录页面

最小输入：

```
Result: Send / Fail / Flash / Try
Grade: V? / V3 / V4 / V5 / Custom
Project: None / Last / New
```

训练中只填结果；grade/project 可训练后补。

### 15.5 结束训练页面

Watch 极简：

```
Session saved
78 min
18 attempts
5 sends
Avg rest 2:42
```

iPhone 完整：

* timeline；
* heart rate chart；
* active/rest ratio；
* attempt list；
* send rate；
* project progress；
* “下次建议先看这些 project”。

### 15.6 状态设计

| 状态      | UI                                                                  |
| ------- | ------------------------------------------------------------------- |
| 空状态     | “Start your first climbing session. You can edit everything later.” |
| 权限未开启   | 解释 HealthKit 权限用途，只请求必要权限                                           |
| 低电量     | “Low battery: recording essential metrics only.”                    |
| 同步失败    | “Saved on Watch. Will sync when iPhone reconnects.”                 |
| 数据不足    | “Not enough data for rest insight yet.”                             |
| 自动识别不确定 | 用 “Suggested attempt” 而不是 “Detected climb”                          |
| 忘记结束    | iPhone 端提示异常 session，可裁剪结束时间                                        |

### 15.7 核心交互流程

```
首次使用
  → HealthKit 权限
  → 选择默认场景：Boulder / Rope
  → 设置 rest reminder
  → Start Session

训练中
  → Watch 被动记录 HR/time/motion
  → 用户攀爬
  → 回到休息
  → Watch 显示 rest timer
  → 用户一键 Send/Fail/Try
  → 可 Undo

结束
  → End Session
  → Watch 保存
  → iPhone 自动同步
  → iPhone 复盘与编辑
  → 形成 project/history
```

---

## 16. 数据推断与算法可行性

你的需求要求对攀爬/休息识别、尝试次数、强度评分、疲劳估计、复盘摘要和进步趋势做算法方案，并明确误判风险。

### 16.1 算法原则

**不要从“动作还原”开始，而要从“事件分割”开始。**

这与你上传的另一份材料中的判断一致：Phase 0 应先收集 20-30 人真实抱石数据，用视频做 ground truth，验证 attempt start/end、rest segmentation、fall/drop detection 等，而不是直接宣称动作还原。

### 16.2 攀爬/休息阶段识别

| 项目     | 方案                                                                                   |
| ------ | ------------------------------------------------------------------------------------ |
| 输入     | HR、accelerometer variance、gyroscope variance、时间窗口、用户标记                               |
| 输出     | climbing / resting / idle / uncertain                                                |
| MVP 规则 | 30-90 秒高 motion + HR 上升 → climbing candidate；motion 低 + 时间延续 → rest；低置信度 → uncertain |
| 可解释性   | 显示为“suggested attempt”，不直接写死                                                         |
| 误判     | 喝水、整理装备、聊天手势、belay、走路、热身                                                             |
| 用户校正   | Send/Fail/Try/Undo；iPhone timeline 拖动修改                                              |
| 验证     | 视频 ground truth，计算 segment accuracy、precision/recall                                 |
| 是否核心卖点 | 是，但话术必须是“assisted tracking”                                                          |

### 16.3 尝试次数估计

| 项目     | 方案                                                   |
| ------ | ---------------------------------------------------- |
| 输入     | climbing/resting 切换、motion burst、持续时间、用户确认           |
| 输出     | attempt count                                        |
| MVP    | 用户标记为主，自动候选为辅                                        |
| 后续 ML  | 个人化模型：学习用户佩戴手、动作幅度、墙型                                |
| 误判     | 短暂热身、换鞋、拿水、擦镁粉、belay                                 |
| 校正     | 每个 candidate 可接受/删除                                  |
| 准确率目标  | beta 阶段候选 recall 优先于 precision；最终 false positive 要可控 |
| 是否核心卖点 | 是，但不是“全自动”                                           |

### 16.4 强度评分

| 项目     | 方案                                                    |
| ------ | ----------------------------------------------------- |
| 输入     | HR zone、active/rest ratio、attempt 数、session 时长、主观 RPE |
| 输出     | Session Intensity Score 1-10                          |
| MVP    | 规则评分：HR zone + attempt density + rest ratio           |
| 可解释性   | “高强度：attempt 密度高且后半段 HR 恢复较慢”                         |
| 误判     | 咖啡因、紧张、睡眠差、传感器漂移                                      |
| 校正     | 用户填写 RPE，调整模型                                         |
| 是否核心卖点 | P1，不能医疗化                                              |

### 16.5 疲劳估计 / 休息建议

| 项目     | 方案                                                 |
| ------ | -------------------------------------------------- |
| 输入     | HR recovery、连续失败 attempt、休息时长、session 总时长、RPE      |
| 输出     | “consider longer rest” / “session getting intense” |
| MVP    | 只给 soft hint，不给强安全结论                               |
| 误判     | 心率受心理压力、环境温度、佩戴影响                                  |
| 校正     | 允许关闭提醒；用户选择 rest target                            |
| 是否核心卖点 | P1，谨慎使用                                            |

### 16.6 训练复盘摘要

| 项目     | 方案                                                   |
| ------ | ---------------------------------------------------- |
| 输入     | session、attempts、send/fail、rest、HR、grade、notes       |
| 输出     | 训练总结、亮点、风险、下次建议                                      |
| MVP 示例 | “今天 78 分钟，18 次 attempt，5 次 send；后半段平均休息变长，send 率下降。” |
| 误判     | 数据不完整时建议不可靠                                          |
| 校正     | 用户编辑 attempt/result/project                          |
| 是否核心卖点 | 是                                                    |

### 16.7 进步趋势分析

| 项目     | 方案                                                          |
| ------ | ----------------------------------------------------------- |
| 输入     | 历史 session、grade、attempt、send rate、project                  |
| 输出     | grade pyramid、send rate、project attempts、training frequency |
| MVP    | 最近 4 周趋势                                                    |
| 后续     | 弱项分类、周期建议、coach sharing                                     |
| 误判     | 岩馆 grade 不统一、路线类型差异                                         |
| 校正     | 手动标记风格/墙面/主观难度                                              |
| 是否核心卖点 | P1/P2                                                       |

---

## 17. MVP 产品定义

### 17.1 产品名方向

| 方向         | 名称                                |
| ---------- | --------------------------------- |
| Attempt 主题 | Attempt, Attempt Copilot, TryLog  |
| Rest 主题    | RestPoint, SendRest               |
| 攀岩语义       | CruxLog, SendTrack, Project Pulse |
| Watch 感    | WristCrux, ClimbPulse             |
| 中文方向       | 岩刻、岩迹、攀迹、Send 记录、Project 手表       |

### 17.2 App Store 卖点文案方向

> **Track every climbing session without pulling out your phone.**
> Record attempts, sends, fails, rest time, heart rate, and project progress from your Apple Watch. Review your session on iPhone and understand how you trained — not just how long you exercised.

中文方向：

> **不用掏手机，也能记录每一次攀岩训练。**
> 用 Apple Watch 低干扰记录 attempt、send、fail、休息、心率和 project 进展；训练后在 iPhone 上复盘今天练得是否有效。

### 17.3 P0 / P1 / P2 / P3

| 优先级 | 功能                                                                                 |
| --- | ---------------------------------------------------------------------------------- |
| P0  | Watch session、HealthKit、HR/time/rest、attempt result、Undo、iPhone summary、离线缓存、权限与隐私 |
| P1  | 自动 attempt/rest 候选、project cards、grade/color preset、rest hint、4 周趋势                |
| P2  | 视频关联、coach sharing、Strava/share、训练计划模板、Action Button 优化                            |
| P3  | 岩馆路线库、社交 feed、户外 topo、weather/safety、ML 技术诊断                                       |

---

## 18. 商业化与增长

### 18.1 商业模式假设

| 模式      | 建议                                                         |
| ------- | ---------------------------------------------------------- |
| 免费版     | Watch 记录、HealthKit、最近 N 次 session、基础 summary               |
| Pro 订阅  | 无限历史、project analytics、长期趋势、训练负荷、可定制 rest/HR rules、视频关联、导出 |
| 一次性购买   | 可作为早期独立开发者策略，降低订阅抗拒                                        |
| 教练版     | P2/P3，支持学员共享 session                                       |
| 岩馆合作    | 不做 MVP，后续可用 project/gym templates 切入                       |
| 社区/路线网络 | 不作为初期商业核心                                                  |

竞品中 KAYA、Vertical-Life、Crimpd 等都有订阅或 premium 边界，说明攀岩用户并非完全不付费，但它们多依赖 guidebook、训练计划或内容价值；本产品付费点应落在**长期复盘、project analytics、训练负荷与节省记录成本**上。([Climbing][6])

### 18.2 用户为什么愿意付费

| 付费功能                | 付费理由          |
| ------------------- | ------------- |
| 长期 project 追踪       | 进阶用户长期需要      |
| 训练趋势                | 看到是否进步        |
| 自定义 rest/HR rules   | 数据控和训练用户需要    |
| 高级复盘摘要              | 训练后节省思考成本     |
| 视频/attempt timeline | project 用户价值高 |
| 教练共享                | B2B/B2C 都可能   |

### 18.3 用户为什么会卸载

| 原因                   | 预防                       |
| -------------------- | ------------------------ |
| 记录太麻烦                | 一键 + 自动候选 + 训练后补         |
| 自动识别不准               | 不承诺全自动，强编辑能力             |
| 复盘没价值                | session summary 必须一屏看到收获 |
| 和 Apple Workout 差异不大 | 必须突出 attempt/rest/send   |
| 训练中打扰                | 攀爬中不弹窗                   |
| 付费过早                 | 免费版保留完整基础闭环              |

### 18.4 增长渠道

| 渠道                        | 策略                                                   |
| ------------------------- | ---------------------------------------------------- |
| App Store SEO             | climbing Apple Watch、bouldering tracker、climbing log |
| Reddit / Mountain Project | 面向数据控和训练用户征集 beta                                    |
| 岩馆教练                      | 用 project/复盘打动训练课用户                                  |
| YouTube/B站/小红书            | “不用掏手机记录攀岩训练”短视频                                     |
| Apple Health/Fitness 用户   | 强调补齐 Apple Workout 的攀岩语义                             |
| 训练内容合作                    | 后续接 Crimpd-style 训练计划，但不自建内容库                        |

---

## 19. 验证方案

你的需求要求桌面调研、用户访谈、问卷、原型、技术、算法和 MVP 成功指标。

### 19.1 访谈问题

1. 你现在如何记录攀岩训练？
2. 最近一次训练结束后，你最想知道什么？
3. 你会记录 attempt、send、fail、grade、休息时间吗？
4. 训练中你什么时候愿意看手表？
5. 攀爬中你最不能接受什么打扰？
6. 你对 Apple Watch 心率、卡路里、运动记录信任吗？
7. 你用过哪些攀岩 App？为什么继续用或放弃？
8. 你是否愿意每次 attempt 后点一下 Send/Fail？
9. 你是否愿意训练后补 grade/project/备注？
10. 什么样的复盘会让你第二天还想打开 App？
11. 你愿意为哪些功能付费？
12. 如果是教练，你希望看到学员哪些数据？

### 19.2 验证计划表

| 验证对象            | 方法                    | 成功标准                                                 |               样本 | 风险     | 失败后调整           |
| --------------- | --------------------- | ---------------------------------------------------- | ---------------: | ------ | --------------- |
| 市场空白            | 桌面竞品 + 用户访谈           | 70% 目标用户认可“记录/复盘不足”                                  |          20-30 人 | 样本偏数据控 | 扩大新手/轻量用户       |
| Watch 交互        | Figma/原型/纸面流程         | 90% 用户能在休息时 5 秒内完成标记                                 |          10-15 人 | 手表尺寸差异 | 减少按钮/使用 presets |
| 手动记录接受度         | 可用性测试                 | 每次 session 平均手动操作 < 30 次且不烦                          |         10 次真实训练 | 输入仍多   | 改为训练后补          |
| 技术采集            | TestFlight + Watch 记录 | session 不丢失，HR/time/motion 稳定保存                      |          20-30 人 | 电量/后台  | 降低采样/增强缓存       |
| Attempt/rest 算法 | 视频 ground truth 对齐    | rest segmentation >85%；attempt candidate F1 初期 >0.70 | 150-300 attempts | 个体差异   | 只保留候选，不自动写死     |
| 复盘价值            | beta 训练后访谈            | 60% 用户认为 summary 有助于下次训练                             |             30 人 | 摘要泛泛   | 增加 project/趋势   |
| 留存              | 4 周 beta              | 目标用户 4 周内记录 ≥4 次                                     |         50-100 人 | 新鲜感衰减  | 加 project 和提醒   |
| 付费意愿            | 问卷 + 假门测试             | 20-30% 目标用户愿意为 Pro 留邮箱/点击                            |             100+ | 价格敏感   | 一次性购买/低价年付      |

### 19.3 MVP 成功指标

| 指标            |          建议目标 |
| ------------- | ------------: |
| session 完成率   |          >70% |
| session 数据完整率 |          >80% |
| attempt 标记率   |          >60% |
| 复盘查看率         |          >60% |
| 7 日留存         |          >30% |
| 4 周重复使用       |   目标用户平均 ≥4 次 |
| 手动修正率         | <30%，否则自动候选太差 |
| 用户主观有用度       |         ≥7/10 |
| 训练中打扰投诉       |          <10% |

---

## 20. 风险与限制

| 风险类型         | 描述                          | 影响 | 概率 | 预防                         | 兜底                 | 是否影响 MVP |
| ------------ | --------------------------- | -: | -: | -------------------------- | ------------------ | -------: |
| 技术风险         | motion/HR 误判、后台、同步、电量       |  高 |  中 | Workout session、离线缓存、低采样策略 | 自动候选降级为手动          |        是 |
| 产品风险         | 记录成本高，用户坚持不下来               |  高 |  高 | 一键、默认少填、训练后补               | 降低字段，突出 rest timer |        是 |
| 数据风险         | HR/calories 不够可靠            |  中 |  高 | 只做趋势，不做精确承诺                | 隐藏 calories 核心位置   |        是 |
| 安全风险         | 攀爬中看屏分心                     |  高 |  中 | 不在攀爬中弹窗；休息时交互              | 关闭实时提醒             |        是 |
| 隐私风险         | Health、location、video 数据敏感  |  高 |  中 | 明确授权、local-first、最小化收集     | 不启用云端默认上传          |        是 |
| 商业风险         | 用户规模有限、付费不确定                |  高 |  中 | 先验证进阶/数据控                  | 一次性购买或低价 Pro       |        是 |
| App Store 风险 | 健康/安全/订阅/定位说明               |  中 |  中 | 避免医疗、安全救援话术；隐私政策           | 调整文案与权限            |        是 |
| 竞品风险         | Redpoint/Pinnacle/COROS 已存在 |  中 |  高 | 聚焦 attempt/rest 复盘差异       | 与 Health/Strava 集成 |        是 |
| 运营风险         | 路线库维护成本                     |  高 |  高 | MVP 不做路线库                  | 使用用户自定义 project    |    否，因不做 |

Apple 的 App Review Guidelines 对可能提供不准确信息或用于诊断/治疗的医疗健康类 App 审查更严格；HealthKit 数据也不能被用于广告等用途，并需要清晰的隐私说明。([Apple Developer][38])

---

## 21. 最终结论：只做一个 MVP，应该做什么？

### 应该做什么

**做「Attempt Copilot」：一个 Apple Watch-first 的攀岩训练记录与复盘助手。**

MVP 包含：

1. Watch 端 Climbing Session；
2. HR、时长、休息计时；
3. 一键 attempt / send / fail / flash；
4. 自动 attempt/rest 候选，但可撤销、可编辑；
5. iPhone 端 session summary；
6. project/grade/color 的训练后补充；
7. HealthKit/Fitness 同步；
8. local-first 隐私与离线缓存。

### 为什么做它

因为它正好落在三者交集：

| 维度        | 说明                                                |
| --------- | ------------------------------------------------- |
| 用户痛点强     | 攀岩用户缺低成本记录 attempt、rest、send、project 的工具          |
| Watch 适配强 | Apple Watch 擅长贴身记录、短交互、触觉提醒、HealthKit             |
| 竞品空白明显    | 现有路线库/社区/训练计划强，但 session-level Watch-first 复盘仍不充分 |

### 为什么现在做

1. 室内攀岩馆和抱石馆仍增长，训练型用户群体扩大。([Climbing Business Journal][4])
2. Apple Watch 已支持 Climbing workout，HealthKit、Core Motion、Workout session 能力足够做底层记录。([苹果支持][1])
3. 竞品已证明用户愿意用数字工具记录攀岩，但也暴露自动识别不准、路线库冷启动、训练复盘不足等问题。([App Store][20])

### 为什么 Apple Watch 适合

Apple Watch 的优势不是“看见路线”，而是：

* 它在用户手腕上；
* 可以在不掏手机的情况下记录；
* 可以用触觉做休息提醒；
* 可以记录心率、时长、运动变化；
* 可以写入 Apple Health/Fitness；
* 可以在休息窗口完成一键交互。

### 它和现有产品相比强在哪里

| 现有产品                   | 强项                  | 我们不硬碰       | 我们的强项                       |
| ---------------------- | ------------------- | ----------- | --------------------------- |
| KAYA / MP / 27 Crags   | guidebook、topo、路线信息 | 不做路线库       | 做训练过程记录                     |
| Crimpd                 | 训练计划                | 不先做内容库      | 做真实 session 数据              |
| TopLogger / Griptonite | 岩馆路线系统              | 不依赖 gym 接入  | 独立用户也能用                     |
| Apple Workout          | 泛运动数据               | 不替代 Fitness | 增加攀岩语义                      |
| Redpoint / Climb Meter | 自动攀岩记录              | 不承诺全自动      | 半自动 + 可修正 + attempt/rest 复盘 |
| Pinnacle               | Watch log           | 借鉴低干扰       | 强化复盘、rest、project、算法候选      |

---

## 22. 下一步行动计划

| 阶段         | 目标               | 交付物                                       |
| ---------- | ---------------- | ----------------------------------------- |
| Week 1     | 明确 MVP PRD       | 用户画像、核心流程、字段模型、权限设计                       |
| Week 2     | Watch 原型         | Start / Rest / Attempt / End 四页原型         |
| Week 3     | 访谈与原型测试          | 15-20 位攀岩用户，验证交互和需求强度                     |
| Week 4-5   | 技术 spike         | HealthKit、WorkoutSession、Core Motion、离线缓存 |
| Week 6-8   | TestFlight alpha | P0 功能可用，真实训练记录                            |
| Week 9-10  | 算法验证             | 视频 ground truth，对比 attempt/rest 候选        |
| Week 11-12 | Beta 优化          | 修正同步、复盘、误触、低电量、权限                         |
| 上线前        | App Store 准备     | 隐私政策、免责声明、订阅说明、QA 回归                      |

---

# 最后的产品判断

**这款 App 的成败不在于“能不能自动识别攀岩动作”，而在于能不能让用户在训练中几乎不被打扰，却在训练后第一次真正看懂：今天我尝试了什么、休息得怎样、哪条线卡住了、我的训练质量是否在变好。**

所以 MVP 最值得做的是：

> **低干扰 Watch 记录 + attempt/rest/send 事件层 + iPhone 可修正复盘。**

这是一个克制但有市场价值的切口：足够小，可以上线；足够具体，有差异化；足够贴近攀岩真实训练过程，不只是“Apple Watch 又多了一个运动类型”。

[1]: https://support.apple.com/en-us/105089 "https://support.apple.com/en-us/105089"
[2]: https://developer.apple.com/documentation/healthkit/hkworkoutsession "https://developer.apple.com/documentation/healthkit/hkworkoutsession"
[3]: https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos "https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos"
[4]: https://climbingbusinessjournal.com/gyms-and-trends-2024/ "https://climbingbusinessjournal.com/gyms-and-trends-2024/"
[5]: https://kayaclimb.com/ "https://kayaclimb.com/"
[6]: https://www.climbing.com/culture-climbing/can-climbing-guidebooks-survive-the-digital-age/ "https://www.climbing.com/culture-climbing/can-climbing-guidebooks-survive-the-digital-age/"
[7]: https://www.mountainproject.com/forum/topic/120779301/does-anyone-like-kaya-app "https://www.mountainproject.com/forum/topic/120779301/does-anyone-like-kaya-app"
[8]: https://apps.apple.com/us/app/mountain-project/id452308783 "https://apps.apple.com/us/app/mountain-project/id452308783"
[9]: https://thetopo.com/premium "https://thetopo.com/premium"
[10]: https://apps.apple.com/mm/app/vertical-life-climbing/id710386774 "https://apps.apple.com/mm/app/vertical-life-climbing/id710386774"
[11]: https://www.8a.nu/premium "https://www.8a.nu/premium"
[12]: https://climbingbusinessjournal.com/myclimb-the-climbing-training-app/ "https://climbingbusinessjournal.com/myclimb-the-climbing-training-app/"
[13]: https://www.reddit.com/r/climbing/comments/3nn3h9/climbing_app_myclimb/ "https://www.reddit.com/r/climbing/comments/3nn3h9/climbing_app_myclimb/"
[14]: https://www.crimpd.com/ "https://www.crimpd.com/"
[15]: https://apps.apple.com/us/app/toplogger/id1289479862 "https://apps.apple.com/us/app/toplogger/id1289479862"
[16]: https://griptonite.io/?srsltid=AfmBOorEQWlNJVQj6fchWJ9WBnnsoaBUMZ8doPiiL4WMqlLVhPIILOxH "https://griptonite.io/?srsltid=AfmBOorEQWlNJVQj6fchWJ9WBnnsoaBUMZ8doPiiL4WMqlLVhPIILOxH"
[17]: https://moonclimbing.com/using-moonboard-app "https://moonclimbing.com/using-moonboard-app"
[18]: https://play.google.com/store/apps/details?hl=en_US&id=com.arcadebouldering.system_wall "https://play.google.com/store/apps/details?hl=en_US&id=com.arcadebouldering.system_wall"
[19]: https://redpoint-app.com/ "https://redpoint-app.com/"
[20]: https://apps.apple.com/us/app/redpoint-bouldering-climbing/id1324072645?platform=iphone&see-all=reviews "https://apps.apple.com/us/app/redpoint-bouldering-climbing/id1324072645?platform=iphone&see-all=reviews"
[21]: https://apps.apple.com/us/app/climb-meter-for-rock-climbing/id1592555877 "https://apps.apple.com/us/app/climb-meter-for-rock-climbing/id1592555877"
[22]: https://apps.apple.com/id/app/pinnacle-climb-log/id1271954104 "https://apps.apple.com/id/app/pinnacle-climb-log/id1271954104"
[23]: https://www.mountainproject.com/forum/topic/125369022/myclimb-app-closing "https://www.mountainproject.com/forum/topic/125369022/myclimb-app-closing"
[24]: https://www8.garmin.com/manuals/webhelp/GUID-C001C335-A8EC-4A41-AB0E-BAC434259F92/EN-US/GUID-584D4C5D-8E09-4EB4-89FA-7FCA1B7F0B7A.html "https://www8.garmin.com/manuals/webhelp/GUID-C001C335-A8EC-4A41-AB0E-BAC434259F92/EN-US/GUID-584D4C5D-8E09-4EB4-89FA-7FCA1B7F0B7A.html"
[25]: https://www.mountainproject.com/forum/topic/202226383/dont-buy-a-garmin-for-climbing "https://www.mountainproject.com/forum/topic/202226383/dont-buy-a-garmin-for-climbing"
[26]: https://www.strava.com/ "https://www.strava.com/"
[27]: https://www.reddit.com/r/climbharder/comments/an0m13/how_do_you_log_your_workouts_sends_etc/ "https://www.reddit.com/r/climbharder/comments/an0m13/how_do_you_log_your_workouts_sends_etc/"
[28]: https://www.reddit.com/r/bouldering/comments/1ia9jqe/what_do_you_use_to_log_your_climbs_and_sends/ "https://www.reddit.com/r/bouldering/comments/1ia9jqe/what_do_you_use_to_log_your_climbs_and_sends/"
[29]: https://www.mountainproject.com/forum/topic/123006788/best-app-tracking-training-climbing-effort "https://www.mountainproject.com/forum/topic/123006788/best-app-tracking-training-climbing-effort"
[30]: https://www.reddit.com/r/bouldering/comments/1edawdp/is_logging_worth_it/ "https://www.reddit.com/r/bouldering/comments/1edawdp/is_logging_worth_it/"
[31]: https://www.reddit.com/r/climbharder/comments/1yarwf/has_anyone_ever_kept_a_climbing_log/ "https://www.reddit.com/r/climbharder/comments/1yarwf/has_anyone_ever_kept_a_climbing_log/"
[32]: https://www.reddit.com/r/bouldering/comments/1ckbug5/how_long_do_you_rest_between_attempts/ "https://www.reddit.com/r/bouldering/comments/1ckbug5/how_long_do_you_rest_between_attempts/"
[33]: https://support.apple.com/en-us/105002 "https://support.apple.com/en-us/105002"
[34]: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data "https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data"
[35]: https://developer.apple.com/documentation/coremotion/ "https://developer.apple.com/documentation/coremotion/"
[36]: https://developer.apple.com/documentation/corelocation "https://developer.apple.com/documentation/corelocation"
[37]: https://link.springer.com/article/10.1007/s42978-021-00139-9 "https://link.springer.com/article/10.1007/s42978-021-00139-9"
[38]: https://developer.apple.com/app-store/review/guidelines/ "https://developer.apple.com/app-store/review/guidelines/"
