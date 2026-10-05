# LineWise domain vocabulary

**LineWise / 线感** — 面向室内抱石（Bouldering）的个人读线、模拟与记忆工具。

**岩馆（Gym）** — 用户命名的攀爬场所。

**墙（Wall）** — 岩馆内承载线路的一面墙，可关联一张照片、区域名和角度。

**线（Line）** — 墙上由用户选定的一组岩点，包含起步、结束、难度、状态和周期。Avoid: RouteCard。

**点（Hold）** — 一条线中的岩点；可用圆圈或轮廓表示。编号是掉落位置、顺序与备注的共同参照。

**轮廓（Polygon）** — 岩点外缘在墙照中的归一化多边形。

**手脚落点（Anchor）** — 肢体与岩点接触的位置，与岩点轮廓中心是不同概念。

**识别出的岩点（DetectedHold）** — 整墙识别产生的候选岩点，供用户选入线路。

**颜色组（Color Group）** — 以所点岩点为种子、按颜色相似性形成的候选集合。

**读线** — 从墙照中找岩点、选同色组、校正并指定起步和结束的过程。

**聚光灯（Spotlight）** — 保留线路岩点亮区、压暗墙照其余部分的视觉表达。

**记录 / 记这一次（Session）** — 同一天在同一条线上的尝试、完成情况、掉落位置、原因与下次打算；可以现场记、离场后记或补记。Avoid: GymVisit、FailureEpisode。

**尝试（AttemptRecord）** — 一次 Session 内可选的单次尝试明细。

**为什么掉（FailReason）** — 用户自选的原因：顺序、脚、身体、时机、够不着、不敢、没力或不知道。

**下次试什么** — 用户为下一次尝试留下的一句话。Avoid: MoveCue、beta。

**提醒（Reminder）** — 某条线下一次打开时带回的“掉哪 · 原因 · 下次试什么”。Avoid: NextSessionCue。

**验证（Check）** — 对上次提醒的回答：有用、没变化、问题变了或没试；回答关联当时的提醒原文（reminderSnapshot）。Avoid: ProofCheck。

**顺序（ClimbSequence）** — 肢体逐步落在岩点上的姿态序列；计划和实际是两份可比较的顺序。

**体型（BodyProfile）** — 用于模拟的身高、臂展与可选腿长比例。

**分享图（Share Card）** — 将线路与用户记录渲染为可导出的静态图片。

**线路状态（LineStatus）** — 在磕（projecting）、上了（sent）、先放下（dropped）或已换线（gone）。

**周期（Cycle）** — 同一条线“再磕一轮”后开启的新一轮记录。
