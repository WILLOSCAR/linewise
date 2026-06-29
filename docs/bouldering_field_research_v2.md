# 攀岩 / Bouldering 现场需求再调研 v2

Date: 2026-06-28  
Project: `watchapp/climb`  
Status: Field-observation-oriented research update after visiting climbing gyms  
Relationship to previous docs:

- `climbing_bouldering_research_report_v1.md`: 产品方向主报告，强调 Watch-backed training memory。
- `bouldering_industry_history_business_report.md`: 行业史、品牌、商业和教练模式背景。
- 本文档：在你最近去岩馆后，重新从“真实到店现场”出发，补充更细的需求地图，并重新判断 Watch App 的产品切口。

> 说明：你说“去研馆看了一下”，这里我按“岩馆”理解。因为你还没有提供具体现场笔记，这版先把“最可能在真实岩馆现场冒出来的新需求”系统拆开；如果你后面补充你看到的细节，可以继续做 v2.1。

---

## 0. Executive Summary

### 0.1 这次再调研后的最大变化

之前的 V1 判断是：

> 做一个 Apple Watch-backed bouldering training memory app：Watch 低干扰捕获训练锚点，iPhone 做复盘和下次训练前回忆。

这次从“你实际去岩馆看过”这个上下文重新审视后，我认为产品机会需要从单一的“训练记录”扩展成更完整的：

> **Gym Visit Memory System：面向室内抱石用户，围绕一次岩馆到访，把路线选择、attempt 记录、休息节奏、beta/视频、社交反馈、下次 project recall 串起来。**

也就是说，用户需求不是只发生在“爬完之后看复盘”，而是贯穿整个到店旅程：

```text
去之前想去哪家馆 / 今天爬什么
  -> 到店后不知道先爬哪条
  -> 新手不知道怎么判断难度和安全
  -> 进阶用户需要记住 project / beta
  -> 尝试之间需要休息和恢复
  -> 想拍视频但现场不方便
  -> 想问别人 beta 但不好意思
  -> 爬完后想知道自己有没有进步
  -> 下次来之前想找回上次那条线和失败原因
```

V2 的核心判断：

| 旧判断 | V2 修正 |
| --- | --- |
| 产品是训练记录器 | 产品更像一次岩馆到访的记忆系统。 |
| P0 记录 attempt/rest/send/fail | P0 还需要轻量记录 route/project 上下文，否则 attempt 没有对象。 |
| Watch 是主入口 | Watch 是训练中入口；iPhone 是路线记忆、视频、beta 和下次计划入口。 |
| 不做路线库 | 仍然不自建完整路线库，但要支持“个人路线卡 / project card”。 |
| 不做社交 | P0 不做 feed，但要承认 beta、搭子、求助、围观是现场强需求。 |
| 不做视频 | P0 不做复杂 AI 视频，但要为“视频锚点/尝试片段”预留接口。 |

### 0.2 最新外部信号

公开资料显示，攀岩热度仍在延续。新华网 2026 年 5 月报道提到，中国攀岩行业市场规模从 2020 年不足 10 亿元增长至 2024 年约 40 亿元，全国商业岩馆截至 2025 年 1 月达到 811 家；同时北京、上海、深圳、成都等城市的岩馆在工作日晚间和周末常出现“一墙难求”的现象。[新华网](https://www.news.cn/fortune/20260521/94ce433673eb4c3c8c50bcef6e76a5f4/c.html)

36 氪 / 中国企业家 2025 年报道中也出现两个关键现象：上海部分区域同一条街可见高密度岩馆；青少年业务正在成为部分高端或专业馆的营收支柱；同时成人用户喜欢攀岩的重要原因是趣味性、肩背训练和征服感。[36 氪](https://36kr.com/p/3439196259995268)

海外产品侧也有新信号：TopLogger、Pebble、KAYA、Griptonite 等不只是记录“我运动了多久”，而是在做路线目录、route logging、grade progress、new set notification、beta video、video analysis 和 gym/route feedback。Griptonite 2026 年推出的 Spray 功能尤其说明，视频复盘和动作理解已经成为成熟市场的付费方向之一。[Climbing Business Journal](https://climbingbusinessjournal.com/griptonite-launches-spray-a-new-pro-feature-for-movement-analysis-inside-the-griptonite-app/)

### 0.3 新需求总表

| 新需求 | 现场触发 | 用户原话式表达 | 产品含义 | 是否进 P0 |
| --- | --- | --- | --- | --- |
| 路线记忆 | 一家馆很多线、颜色/难度/墙面复杂 | “我上次卡的是哪条来着？” | 需要个人 route/project card，不依赖官方路线库。 | 是 |
| 下次计划 | 用户不是一次性玩，而是反复 project | “下次来先试那条。” | next-session recall 比训练后 summary 更重要。 | 是 |
| 轻量 beta 记录 | 试了几次后得到动作灵感 | “右脚应该先换上去。” | 需要 5 秒内记录 beta，不适合长文本。 | 是，简化 |
| 视频锚点 | 用户/朋友会拍 attempts | “我想看看哪里没发力。” | P0 可保存视频引用，P1 再做分析。 | P1 |
| 休息节奏 | 排队/聊天/刷手机导致休息失控 | “我到底休了多久？” | Watch rest timer 仍强，但要和 route/attempt 绑定。 | 是 |
| 排队和拥挤 | 热门线多人轮流试 | “这条太多人了，先去别的。” | 可做主观 crowd note，完整 queue 不做 P0。 | 否 |
| 安全和落地 | 新手怕摔、怕高、怕受伤 | “这条我能不能安全下来？” | 新手模式需要 fall/safety checklist。 | P0 边缘 |
| 难度校准 | 不同馆/不同颜色难度不统一 | “这 V3 怎么比别家 V5 还难？” | 需要个人体感难度，不只官方 grade。 | 是 |
| 社交/beta 求助 | 用户想问但不好意思 | “有没有人能讲一下这条？” | feed 不做，但可做 beta prompt / coach note。 | P1 |
| 教练反馈 | 上课后要记住教练说了什么 | “教练刚才说的我回家就忘了。” | 教练 note / correction list 是高价值方向。 | P1 |
| 青训/家长报告 | 青少年训练需要可解释进步 | “孩子今天练了什么？” | B2B/教练端机会，不是个人 P0。 | P2 |
| 岩馆运营反馈 | 定线质量、热门线、用户停留 | “哪条线最受欢迎？” | 岩馆 SaaS 机会，个人产品先不碰。 | P3 |

---

## 1. 为什么这次需要重新调研？

### 1.1 看过岩馆后，需求会从“抽象产品”变成“现场摩擦”

没有去岩馆时，很容易把产品想成：

```text
开始训练 -> 记录运动数据 -> 训练后 summary
```

但真正到店后，用户的脑内流程更复杂：

```text
我该从哪条开始？
这条是什么难度？
这条之前试过吗？
我刚才失败在哪？
要不要再试一次？
休息够了吗？
旁边那个人怎么做出来的？
我要不要请人帮我拍？
这条下周还在不在？
回家以后我还记得这条吗？
```

所以，真实需求不只是“记录训练量”，而是：

> 在路线密集、反馈即时、动作复杂、社交半开放的岩馆环境里，把短时记忆变成可取回的训练记忆。

### 1.2 旧报告的盲区

V1 已经抓到了 attempt、rest、send/fail、project，但仍有几个盲区：

| V1 盲区 | 为什么现在重要 |
| --- | --- |
| route/project 上下文不够具体 | 没有路线对象，attempt 只是一个计数。 |
| beta 过轻 | 进阶用户真正想记住的是动作解决方案，不只是 send/fail。 |
| 视频只放在后续 | 现场用户天然会拍视频，不能完全忽略。 |
| 社交需求被压太低 | 抱石现场强依赖围观、讨论、互相给 beta。 |
| 岩馆拥挤与排队 | 热门馆高峰期“一墙难求”，影响训练节奏。 |
| 新手安全心理 | 第一次体验者比例高，新手怕摔、怕丢脸、怕打扰别人。 |
| 教练/课程场景 | 课程是岩馆重要收入，用户会忘记教练建议。 |

---

## 2. 一次真实岩馆到访的需求拆解

### 2.1 到店前

| 用户问题 | 需求 | 当前常见解决方式 | 机会 |
| --- | --- | --- | --- |
| 今天去哪家馆？ | 位置、价格、开放时间、人多不多 | 大众点评、小红书、朋友推荐 | 可做“个人常去馆 + 最近训练目标”，不必做点评。 |
| 今天练什么？ | project、弱项、恢复状态 | 凭记忆或临时决定 | next-session recall。 |
| 要带什么？ | 鞋、镁粉、护具、手表、三脚架 | 新手常忘 | visit checklist。 |
| 这家馆适合新手吗？ | 新手线、教练、安全、氛围 | 看评论 | 未来可做 personal notes。 |

### 2.2 入场和热身

| 用户问题 | 需求 | 产品启发 |
| --- | --- | --- |
| 我先热身多久？ | 热身模板 | Watch 可给 5-8 分钟 warm-up timer，但不要复杂。 |
| 从哪条线开始？ | 难度递进 | iPhone 可显示上次完成的低难路线或 warm-up range。 |
| 今天状态好吗？ | 主观状态 | 开始时只问一个 1-5 readiness，不要长问卷。 |
| 新手不知道规则 | 安全提示 | 第一次用 App 可有 fall/safety checklist，但不要训练中弹窗。 |

### 2.3 找路线

这可能是 V2 最大新增点。

真实岩馆里，路线通常由颜色、标签、墙面区域、难度、set date、动作风格共同构成。对用户来说，痛点不是“路线太少”，而是：

1. 一眼看不出哪条适合自己；
2. 不知道哪条上次试过；
3. 不知道哪条线快被拆；
4. 不知道哪条线排队太久；
5. 不知道同难度里哪条偏动态、平衡、力量、柔韧；
6. 不同馆的 grade 不可比；
7. 不知道自己应该练弱项还是刷成就感。

产品启发：

| 功能 | 说明 | P0 判断 |
| --- | --- | --- |
| 个人路线卡 | 用户手动拍一张墙/路线，记录颜色、难度、区域、主观标签 | 应进 P0 |
| Project 标记 | 把某条线设为 project，下次训练前显示 | 应进 P0 |
| 主观难度 | 记录“比标称难/正常/偏软” | 应进 P0 |
| 风格标签 | slab、overhang、dyno、crimp、coordination、balance | P1 |
| 官方路线库 | 与岩馆合作同步路线 | 不进 P0 |
| 热门/排队 | 记录当前拥挤感 | P2 |

### 2.4 尝试和失败

抱石的核心不是“连续运动”，而是：

```text
观察 -> 尝试 -> 失败 -> 休息 -> 改 beta -> 再尝试 -> send 或放弃
```

每次失败都有信息量：

| 失败类型 | 用户真实意思 | 应该如何记录 |
| --- | --- | --- |
| 起步失败 | 起手/脚位不对、力量不够 | Fail at start |
| 中段失败 | 转移、换脚、平衡、动态没接住 | Fail mid |
| 顶部失败 | 体力、恐惧、最后动作不稳 | Fail top |
| 跳下 | 害怕、没有安全感、没想明白 | Bail / fear |
| 放弃 | 累了、排队、换线 | Abandoned |

P0 不需要让用户每次都填失败原因，但应该允许训练后补充。Watch 现场只保留极简：

```text
[Try] [Send]
[Fail] [Undo]
```

iPhone 训练后再问：

```text
失败主要原因：力量 / 脚法 / 平衡 / 读线 / 恐惧 / 疲劳 / 不知道
```

### 2.5 休息、排队和节奏

公开报道里已经出现“工作日晚间和周末常常一墙难求”的描述。[新华网](https://www.news.cn/fortune/20260521/94ce433673eb4c3c8c50bcef6e76a5f4/c.html)

这意味着 rest timer 的意义不只是生理恢复，也包括现场节奏：

| 场景 | 用户行为 | 产品机会 |
| --- | --- | --- |
| 一个人练 | 容易休太短或休太长 | Watch rest timer。 |
| 热门线排队 | 轮到自己时未必恢复好 | route-specific rest / queue note。 |
| 和朋友聊天 | 忘记上次尝试多久前 | haptic reminder。 |
| 练高强度线 | 需要更长恢复 | rest target by route intensity。 |
| 新手随便刷 | 体能消耗但没有结构 | session pacing summary。 |

P0 建议：

1. Watch 默认显示 `Rest 02:14`。
2. 每条 route/project 有平均 rest。
3. 提醒文案只做中性提示：`Rested 3 min`，不要说“你应该继续休息”。
4. 不要用心率做强医疗式疲劳判断。

### 2.6 Beta 和视频

Griptonite 在 2026 年推出 Spray，说明成熟市场已经把“视频 + 动作理解”视作付费能力。它强调用户会拍 attempts、回看动作、比较不同尝试，但大多数人仍然靠自己猜。[Climbing Business Journal](https://climbingbusinessjournal.com/griptonite-launches-spray-a-new-pro-feature-for-movement-analysis-inside-the-griptonite-app/)

这对我们有两个启发：

1. **视频是强需求，但不是 P0 的重 AI 功能**。
2. **用户需要的不是“AI 告诉你标准答案”，而是“帮我看清楚我到底怎么动的”。**

P0 可以只做：

| 功能 | 复杂度 | 价值 |
| --- | --- | --- |
| 训练后给某个 project 加视频链接/附件 | 中 | 把视频和 route/attempt 绑定。 |
| beta 快捷标签 | 低 | 记录脚法、重心、动态、匹配、换脚等关键词。 |
| 语音/短句备注 | 中 | 休息时说一句“右脚先上蓝点”。 |

P1/P2 再做：

1. 视频片段剪切；
2. 对比两次 attempt；
3. 姿态/重心/节奏分析；
4. 教练批注；
5. 公共 beta sharing。

### 2.7 训练后和下次到店前

训练后的 summary 只是第一步，真正有价值的是下次到店前的 recall：

| 时间 | 用户需求 | 产品输出 |
| --- | --- | --- |
| 训练刚结束 | 我今天练了什么？ | Session summary。 |
| 回家路上 | 哪几条值得记？ | Project inbox。 |
| 第二天 | 我有没有过量？ | 简单恢复/疲劳自评，不做医学判断。 |
| 下次去之前 | 上次卡在哪？ | Next session card。 |
| 到店后 | 先爬哪条？ | Today project list。 |

V2 因此把产品价值顺序改成：

```text
Record -> Clean up -> Remember -> Return -> Improve
```

而不是：

```text
Record -> Report
```

---

## 3. 重新定义目标用户

### 3.1 P0 首发用户

V2 仍建议首发用户是：

> 每周 1-3 次室内抱石、会重复 project、愿意用 Apple Watch、但不想训练中频繁掏手机的成人用户。

但要更细分：

| 用户 | 典型需求 | 产品价值 |
| --- | --- | --- |
| 独自训练的进阶新手 | 记住自己卡住哪条、下次怎么练 | Project memory。 |
| 下班后固定去岩馆的白领 | 低干扰记录、别浪费训练时间 | Watch rest + route recall。 |
| 喜欢拍视频的人 | 视频和路线绑定、训练后复盘 | Video anchor。 |
| 想突破 V3/V4/V5 的用户 | 弱项、失败原因、练习结构 | Attempt + failure reason。 |
| 不请长期私教但想自我进步的人 | 训练日志和轻量建议 | Personal coach-lite。 |

### 3.2 暂不作为 P0 的用户

| 用户 | 为什么不做 P0 |
| --- | --- |
| 第一次体验用户 | 需求主要是安全、教练、低恐惧，不一定愿意先装 App。 |
| 纯打卡用户 | 拍照发小红书即可，长期记录意愿弱。 |
| 青少儿家长 | 高价值，但需要教练端/家长报告，不适合个人 Watch P0。 |
| 岩馆老板/定线员 | SaaS 价值大，但销售和集成路径重。 |
| 户外攀岩用户 | route access、安全、天气、装备复杂度高，偏后期。 |
| 专业运动员 | 需要教练、视频、多传感器和专项训练，不适合 P0 小工具。 |

---

## 4. 竞品与替代方案更新

### 4.1 默认替代品

| 替代品 | 用户为什么用 | 我们不能硬碰什么 | 可切入空白 |
| --- | --- | --- | --- |
| Apple Workout | 免费、系统自带、关环 | 不要替代健康记录 | 补攀岩语义层。 |
| 备忘录/相册 | 无学习成本 | 不要让记录比备忘录麻烦 | 自动组织 route/attempt/video。 |
| 小红书/朋友圈 | 打卡、成就展示 | 不做泛社交 feed | 私密训练记忆。 |
| 教练口头指导 | 高信任 | 不替代教练 | 记住教练建议。 |
| 大众点评/美团 | 找馆和买券 | 不做点评平台 | 常去馆和个人训练历史。 |

### 4.2 海外 App 信号

| 产品 | 做了什么 | 对我们的启发 |
| --- | --- | --- |
| TopLogger | 室内 climbs logging、进度、排名、新路线提醒、互动 gym map | 官方路线层能大幅增强记录体验，但依赖岩馆接入。 |
| Pebble | gym route catalog、session tracking、grade pyramid、recommendations、leaderboard | route + progress + game 化是成熟方向。 |
| KAYA | route info、gym setting、beta/video、competition | 和大型岩馆/连锁合作后，路线数据价值很大。 |
| Griptonite / Spray | 视频 overlay、side-by-side compare、movement analysis | 视频复盘是高价值，但 P0 不宜重做。 |
| Redpoint / Climb Meter | Apple Watch/iPhone climbing tracking、HealthKit | Watch 记录已有竞品，差异必须在 route/project recall。 |

TopLogger 的 App Store 描述强调室内攀岩者可以记录已完成路线、查看未完成路线、跟踪进度、获取新路线和 reset 信息；这说明“路线对象 + 个人完成状态”是成熟室内岩馆 App 的核心结构。[TopLogger](https://apps.apple.com/us/app/toplogger/id1289479862)

Pebble 的公开说明也强调 gym routes、session tracking、progress dashboard 和 recommendations；这说明单纯记录 session 不够，用户需要把 session 绑定到 route/project 上。[Pebble](https://www.pebbleclimbing.com/)

### 4.3 中国市场空白

中国岩馆数字化仍较分散。很多馆有小程序、私域群、点评套餐和课表，但对成人个人训练的支持通常不系统：

1. 门票和课程购买有工具；
2. 私域社群有工具；
3. 青少年课程和家长沟通有工具；
4. 但成人自己记录 route/project/beta/attempt 的工具弱；
5. 各馆路线数据没有统一标准；
6. 常去多家馆的用户很难横向比较自己的状态。

这意味着，独立 C 端产品如果不依赖岩馆路线库，必须先做：

> **个人可控的 route/project memory，而不是完整公共 route database。**

---

## 5. 新需求优先级矩阵

评分口径：

- Frequency：用户每次训练是否都会遇到。
- Pain：不解决是否明显影响体验。
- Watch Fit：是否适合手表端低干扰完成。
- iPhone Fit：是否适合手机端整理。
- P0 Fit：是否值得进入首版。

| 需求 | Frequency | Pain | Watch Fit | iPhone Fit | P0 Fit | 结论 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Start session | 5 | 5 | 5 | 3 | 5 | 必须做。 |
| Rest timer | 5 | 4 | 5 | 2 | 5 | 必须做。 |
| Attempt result | 5 | 5 | 5 | 3 | 5 | 必须做。 |
| Route/project card | 4 | 5 | 2 | 5 | 5 | 必须做，否则 attempt 没对象。 |
| Next-session recall | 4 | 5 | 2 | 5 | 5 | V2 核心价值。 |
| Subjective grade | 4 | 4 | 2 | 5 | 4 | 应做。 |
| Failure reason | 4 | 4 | 2 | 5 | 4 | 训练后补充。 |
| Quick beta note | 3 | 5 | 3 | 5 | 4 | 简化做。 |
| Video anchor | 3 | 5 | 1 | 5 | 3 | P1，P0 预留。 |
| Safety/fall checklist | 2 | 5 | 2 | 4 | 3 | 新手 onboarding 做。 |
| Social/buddy | 3 | 3 | 1 | 4 | 2 | 不做 P0。 |
| Coach note | 2 | 4 | 1 | 5 | 2 | P1/P2。 |
| Gym route map | 4 | 5 | 1 | 5 | 1 | 需要岩馆合作，不做 P0。 |
| Queue/crowd | 3 | 3 | 2 | 3 | 1 | 先用备注，不做系统。 |
| Gym SaaS analytics | 2 | 5 | 0 | 5 | 0 | 远期。 |

---

## 6. V2 产品定位

### 6.1 新的一句话定位

> 一个面向室内抱石用户的 Apple Watch + iPhone 训练记忆系统：用 Watch 在训练中低干扰记录 attempt/rest/send/fail，用 iPhone 维护 route/project/beta/video 记忆，并在下次到店前帮用户找回上次没爬完的线和下一步策略。

### 6.2 产品不是

| 不是 | 原因 |
| --- | --- |
| 不只是 Apple Workout 皮肤 | 系统 Workout 已经能记时长/心率，差异必须是攀岩语义。 |
| 不做完整岩馆路线库 | 依赖岩馆合作，冷启动重。 |
| 不做小红书式 feed | 泛社交会稀释训练记忆核心。 |
| 不做全自动动作识别 | 单腕数据不足，误判会伤害信任。 |
| 不做 AI 教练承诺 | 技术和责任都过重。 |
| 不做青训家长端 P0 | 价值大但业务链路不同。 |

### 6.3 产品是

| 是什么 | 解释 |
| --- | --- |
| Visit memory | 记录一次到馆里真正发生过的路线、尝试、休息和结果。 |
| Project recall | 让用户下次来之前知道上次卡在哪、应该先试什么。 |
| Personal route card | 不等岩馆接入，用户自己创建最低成本路线对象。 |
| Low-interruption logger | Watch 只做训练中必须的 1-2 秒操作。 |
| Training notebook | iPhone 做复盘、补充失败原因、beta 和视频。 |
| Trust-first system | 所有自动候选都可改，用户修正比算法炫技更重要。 |

---

## 7. V2 P0 功能范围

### 7.1 Watch P0

Watch 只负责现场最短动作：

| 页面/状态 | 功能 | 设计要求 |
| --- | --- | --- |
| Start | 开始 Boulder Session | 默认进入最近常去馆，可跳过馆选择。 |
| Session | 总时长、心率、attempt 数、当前 rest | 大数字、低文字、低干扰。 |
| Attempt | Try / Send / Fail / Undo | 单击完成，误触可撤销。 |
| Rest | 休息计时、上次尝试结果、当前 project | 休息为主屏，不打断攀爬。 |
| Quick Project | 选择 Last Project / New / None | Watch 不做复杂路线编辑。 |
| End | 极简总结 | attempts、sends、projects、rest。 |

### 7.2 iPhone P0

iPhone 负责整理和记忆：

| 模块 | 功能 |
| --- | --- |
| Session Review | timeline、attempt list、rest、send/fail、心率参考。 |
| Project Inbox | 自动列出本次未完成/重点 route。 |
| Route Card | 照片、颜色、难度、墙区、主观难度、状态。 |
| Failure Reason | 力量、脚法、平衡、读线、恐惧、疲劳、未知。 |
| Beta Note | 文字/语音转文字/短标签。 |
| Next Session | 下次到馆前显示 3-5 个 project cue。 |
| HealthKit Sync | 写入 climbing workout，不把 HealthKit 当唯一价值。 |
| Data Export | 本地 JSON/CSV 导出，便于后续分析。 |

### 7.3 P0 数据模型修正

V1 的 session/attempt 已经不够，V2 需要加入 `RouteCard`。

```text
GymVisit
  - id
  - gymName
  - startedAt / endedAt
  - watchWorkoutId
  - readiness
  - notes

RouteCard
  - id
  - gymVisitId
  - gymName
  - wallArea
  - color
  - officialGrade
  - subjectiveGrade
  - photoRef
  - styleTags
  - projectStatus: new / project / sent / archived
  - resetRisk: unknown / soon / gone

Attempt
  - id
  - routeCardId?
  - timestamp
  - result: try / send / fail / flash / bail
  - failPoint: start / middle / top / unknown
  - perceivedEffort
  - fear
  - noteRef

RestInterval
  - afterAttemptId
  - duration
  - heartRateStart?
  - heartRateEnd?

BetaNote
  - routeCardId
  - text
  - tags
  - videoRef?
  - createdAt

NextSessionCue
  - routeCardId
  - reason
  - suggestedWarmup
  - lastKnownBeta
```

### 7.4 P0 交互预算

| 动作 | Watch 交互预算 | iPhone 交互预算 |
| --- | --- | --- |
| 开始训练 | <= 2 taps | 可选 |
| 标记一次 attempt | <= 1 tap | 训练后可修正 |
| 切换 project | <= 2 taps | 训练后细化 |
| 结束训练 | 长按或确认 | 可编辑 |
| 创建 route card | 不在 Watch 做 | <= 20 秒 |
| 加 beta note | 可选语音/跳过 | <= 15 秒 |

---

## 8. 新增场景：岩馆现场观察 checklist

你下次去岩馆，可以按这个清单记录。它比上一版更像“产品经理现场观察表”。

### 8.1 门店与空间

| 观察项 | 记录 |
| --- | --- |
| 岩馆名称 |  |
| 城市/区域 |  |
| 商场/社区/独立馆/体育中心 |  |
| 到店时间 | 工作日/周末，早/午/晚 |
| 人流密度 | 空 / 正常 / 拥挤 / 一墙难求 |
| 用户构成 | 新手、老手、儿童、亲子、白领、女性、教练课 |
| 墙面类型 | slab / vertical / overhang / cave / training board |
| 路线标识 | 色块、标签、难度、二维码、set date |
| 是否有路线地图 | 有 / 无 / 纸质 / App / 小程序 |

### 8.2 用户行为

| 观察项 | 记录 |
| --- | --- |
| 新手是否知道先爬哪条 |  |
| 用户是否排队看同一条线 |  |
| 用户是否互相给 beta |  |
| 用户是否拍视频 |  |
| 用户尝试失败后做什么 |  |
| 用户休息时看什么 | 手机 / 同伴 / 墙 / 手表 / 发呆 |
| 有多少人戴 Apple Watch / Garmin / COROS |  |
| 有多少人使用 App 记录 |  |
| 用户是否问教练问题 |  |

### 8.3 商业和运营

| 观察项 | 记录 |
| --- | --- |
| 单次/体验价 |  |
| 月卡/次卡 |  |
| 私教/团课 |  |
| 青少年课 |  |
| 是否加企业微信 |  |
| 是否有社群活动 |  |
| 是否有赛事/排行榜 |  |
| 是否卖装备/咖啡 |  |
| 是否主动推卡/推课 |  |
| 教练是否巡场 |  |

### 8.4 产品机会

| 现场摩擦 | 具体例子 | 是否可被 Watch/iPhone 解决 |
| --- | --- | --- |
| 不知道爬哪条 |  |  |
| 忘记上次 project |  |  |
| 不知道休息多久 |  |  |
| beta 记不住 |  |  |
| 想拍视频但麻烦 |  |  |
| 不知道为什么失败 |  |  |
| 训练后没有复盘 |  |  |
| 下次没有计划 |  |  |
| 课程建议忘记 |  |  |

---

## 9. 访谈问题 v2

### 9.1 成人用户

1. 你来岩馆之前，会提前想今天要练什么吗？
2. 你有没有固定 project？你怎么记住它？
3. 你会记录自己每条线尝试了几次吗？
4. 你通常怎么判断一条线适不适合自己？
5. 你失败后会记失败原因吗？
6. 你休息多久？靠感觉还是计时？
7. 你会拍视频吗？拍完会回看吗？
8. 你有没有因为忘记 beta 导致下次又重来？
9. 如果 Watch 能一键记录 Try/Send/Fail，你愿不愿意用？
10. 你最不愿意在训练中被 App 打扰的时刻是什么？

### 9.2 新手用户

1. 第一次来最害怕什么？
2. 教练讲了什么你最记得？
3. 哪些安全规则你听完仍然不确定？
4. 你觉得哪条线适合新手，为什么？
5. 你会想记录第一次完成的线吗？
6. 你会因为尴尬而不好意思问别人吗？

### 9.3 进阶用户

1. 你目前最想突破的 grade 是什么？
2. 你怎么管理 project？
3. 你会不会记录训练周期、弱项和失败原因？
4. 你最常见的失败类型是什么？
5. 你觉得视频复盘有用吗？为什么？
6. 你会为哪种训练记录付费？

### 9.4 教练/岩馆

1. 成人用户最常见的续费原因是什么？
2. 成人用户最常见的流失原因是什么？
3. 教练课后建议现在怎么留存？
4. 路线热度和用户反馈是否被记录？
5. 是否愿意让用户扫码记录 route？
6. 是否需要给会员生成训练报告？
7. 哪些数据你觉得有价值，哪些数据会增加运营负担？

---

## 10. V2 Go / No-Go 验证

### 10.1 原 P0 验证不够

V1 的 Go/No-Go 偏向：

1. 用户是否愿意戴表；
2. 是否愿意标记 attempt；
3. 是否看 session recap。

V2 需要加上：

1. 用户是否愿意创建 route/project card；
2. next-session recall 是否真的有用；
3. route card 是否让 attempt 记录变得更有意义；
4. beta note 是否被再次查看；
5. 视频是否是强需求还是少数人需求。

### 10.2 新验证指标

| 指标 | 目标 | 含义 |
| --- | ---: | --- |
| Route card 创建率 | >= 60% sessions 至少创建 1 个 | 没有路线对象，产品价值不成立。 |
| Project recall 使用率 | >= 40% 用户下次到店前打开 | 证明 recall 比 recap 更有价值。 |
| Attempt-route 绑定率 | >= 70% attempts 绑定 route 或 project | 证明记录不是空计数。 |
| Beta note 留存率 | >= 30% project 有 note | 判断 beta 是否进入 P0/P1。 |
| Watch 标记负担 | <= 20 taps/小时 | 训练中不能烦。 |
| 24h review rate | >= 60% sessions 被复盘 | 复盘行为成立。 |
| 4 周重复使用 | >= 35% 目标用户记录 >= 4 次 | 基础留存。 |

### 10.3 最小实测实验

不用先写完整 App，可以先用低保真方式验证：

| 实验 | 工具 | 方法 | 成功信号 |
| --- | --- | --- | --- |
| Route card 实验 | iPhone 备忘录/Notion/表格 | 每次训练拍 3 条线，记录颜色/难度/结果 | 下次到店前会主动查看。 |
| Watch tap 实验 | Apple Watch 快捷指令/计时器/纸面模拟 | 下墙后点 Try/Send/Fail | 不觉得烦，能坚持整场。 |
| Rest 实验 | Watch 计时器 | 每次尝试后计时 | 用户发现节奏变化。 |
| Beta note 实验 | 语音备忘录 | 休息时说一句 beta | 训练后仍能理解。 |
| Video anchor 实验 | 相册 + 命名 | 给 project 绑定视频 | 复盘比纯文字更有效。 |

---

## 11. 对 PRD 的修正建议

### 11.1 P0 必须新增

1. `RouteCard`：个人路线卡。
2. `ProjectInbox`：本次训练值得下次再看的路线。
3. `NextSessionCue`：下次到店前的 3-5 条提示。
4. `SubjectiveGrade`：用户自己的体感难度。
5. `FailureReason`：训练后补充失败原因。

### 11.2 P0 可以保留但降级

| 功能 | 处理 |
| --- | --- |
| 自动 attempt/rest 候选 | 保留为 suggested，不作为核心卖点。 |
| HR intensity | 只做参考，不做疲劳诊断。 |
| Session score | 不做单一分数，避免误导。 |
| AI summary | 不做 P0，先用规则模板。 |

### 11.3 P1 应提前预留

1. 视频引用和 clip；
2. 教练 note；
3. route style tags；
4. gym route import；
5. reset notification；
6. buddy/beta sharing；
7. grade pyramid；
8. simple weakness map。

### 11.4 更合理的路线图

| 阶段 | 目标 | 交付 |
| --- | --- | --- |
| Phase 0 | 手工验证需求 | 表格/备忘录/Watch 计时器记录 5-10 次真实训练。 |
| P0 App | 个人训练记忆闭环 | Watch attempt/rest + iPhone route/project/recall。 |
| P1 | 复盘增强 | 视频锚点、beta note、失败原因统计、weakness tags。 |
| P2 | 社群/教练 | 轻量 beta 分享、教练批注、训练计划。 |
| P3 | 岩馆合作 | route import、reset notice、route heatmap、gym dashboard。 |

---

## 12. 结论

这次重新调研后，我认为最大的新需求不是“再加一个功能”，而是产品定义要从：

> 训练记录

升级成：

> 岩馆到访记忆。

攀岩/抱石的现场并不是一个连续运动场景，而是一个高频短尝试、强路线对象、强 beta、强社交、强失败学习的场景。用户真正痛的不是“没有心率曲线”，而是：

1. 我忘了上次爬哪条；
2. 我忘了失败在哪里；
3. 我忘了别人/教练给我的 beta；
4. 我不知道这次是否真的比上次更好；
5. 我下次到店时又从零开始。

因此，V2 产品最值得验证的不是更复杂的自动识别，而是：

> **用最低成本把 route/project/attempt/rest/beta 绑定起来，并让用户下次到馆前真的用得上。**

最终建议：

1. 不要急着做完整路线库；
2. 不要急着做 AI 动作分析；
3. 不要急着做社交 feed；
4. 先做个人 route card；
5. 先做 Watch attempt/rest；
6. 先做 next-session recall；
7. 先用你自己的 5-10 次真实岩馆训练验证。

如果你最近在岩馆看到的新需求包括“排队、拍视频、找搭子、教练课、路线扫码、会员转化、儿童课、咖啡零售、装备销售、或者安全问题”，都可以继续补到这份 V2 里。现在最该做的是把你的现场观察从感觉变成结构化记录。

---

## 13. Sources

- [新华网：向上，再向上——攀岩消费“破圈”生长](https://www.news.cn/fortune/20260521/94ce433673eb4c3c8c50bcef6e76a5f4/c.html)
- [36 氪 / 中国企业家：小红书最热白领运动，有人靠它年入大几千万](https://36kr.com/p/3439196259995268)
- [21 经济网：50 万岩友掀起攀岩热潮，谁吃到了红利？](https://www.21jingji.com/article/20250905/herald/9bd5a1dc7fa1ad1fbad50b5332ec6020.html)
- [DataStory：岩点×数说故事×小红书发布《中国攀岩行业分析报告》](https://www.datastory.com.cn/details/1055)
- [Reddit: What do you use to log your climbs and sends?](https://www.reddit.com/r/bouldering/comments/1ia9jqe/what_do_you_use_to_log_your_climbs_and_sends/)
- [Climbing.com: The Best Climbing Apps](https://www.climbing.com/gear/6-best-climbing-apps/)
- [Climbing Business Journal: Apps for Routesetting Management](https://climbingbusinessjournal.com/apps-for-routesetting-management-in-2022/)
- [Climbing Business Journal: Griptonite launches Spray](https://climbingbusinessjournal.com/griptonite-launches-spray-a-new-pro-feature-for-movement-analysis-inside-the-griptonite-app/)
- [TopLogger for climbers](https://toplogger.nu/for-climbers)
- [TopLogger App Store](https://apps.apple.com/us/app/toplogger/id1289479862)
- [Pebble Climbing](https://www.pebbleclimbing.com/)
- [Pebble Climbing App Store](https://apps.apple.com/us/app/pebble-climbing/id1453943563)
- [Apple Developer: Track workouts with HealthKit on iOS and iPadOS](https://developer.apple.com/videos/play/wwdc2025/322/)
- [Apple Developer: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
