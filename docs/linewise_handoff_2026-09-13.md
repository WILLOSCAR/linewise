# 线感 LineWise · Handoff（2026-09-13 01:32）

> 本文保留凌晨中断时的历史快照。当天接手后的修复、验证和更正见 [接手验收](linewise_takeover_2026-09-13.md)；不要再把下文全部“未做”当成当前状态。

接手前读：`CONTEXT.md` → `docs/linewise_prd_v1_0.md` → `docs/linewise_ui_spec_v1.md` → 本文。
分支：`feat/ios-app-v1`。最后一次干净提交：`a0f939f`（MVP/M1/M2 功能齐全，134 测全绿）。
工作区有**未提交的第二轮打磨半成品**（约 +2200/−1150），四个并行 Agent 已中断，**未做编译/测试验收**。先 `xcodegen generate && xcodebuild test`，红了再决定保留或回退到 `a0f939f`。

四个 Agent 因额度中断（不是干净汇报）：[Home+Builder](8701286b-a701-4b59-b4af-90c252cea90b)、[Detail+Session](8bf882fd-8d8b-41b9-b584-40451bcd6d81)、[Sequence](f6726142-d45c-4127-9cd9-0474933cdfe8)、[Share+Settings](c0b3956b-2b30-4866-8329-2b7148f20593)。不要 resume 这四个 ID；下一轮开新会话按本文清单做。

演示：`-seedDemo -demoPhotosDir /tmp/linewise-demo-photos`；真实照不进仓库。直达：`-openLine 黄|白`、`-openBuilder`、`-openSequenceEditor`、`-openSettings`。

---

## 未提交改动里已经落地的（半成品，待验）

### 首页
- 卡片文字分层、筛选空态、排序缓存 `HomeLineOrdering.swift`
- 筛选胶囊 `matchedGeometryEffect` 滑动黄底（`HomeComponents.swift`）
- iOS 18 zoom 转场（`RootView` + `homeZoomDestination`）
- `IntroView` 抽到 `Features/Home/IntroView.swift`

### 建线
- `LightUpGeometry` / `LightUpView` 有小改（命中/缩放），**放大镜 loupe、工具条 disabled、首次提示、已有墙取景、Recognize 新旧线区分未做**

### 线路页 / 记这一次
- 头图 stretchy + 自动取景意图、标题叠图、全屏查看器捏合/双击
- `Session.fallText` 读写（不再把「掉在 大球」编码进 note）；旧数据解码兼容
- DEBUG：`Features/LineDetail/Debug/`

### 顺序
- 布局改为「图占满 + 底部胶片条」：`SequenceFilmstrip.swift`、`SequenceScene.swift`
- 拖动手感、播放、`focus` 几何集中到 Scene
- `SequencePanel` 缩略图取景

### 分享
- `SharePreviewSheet`（低清预览 → 高清渲染）
- 卡片 `scale` + `focus`、无照片 `fallText` 快照带
- DEBUG：`Features/Share/Debug/`

### 设置
- **本轮几乎没动**（删除岩馆确认、删除全部二次确认在第一轮已有）

---

## 打磨未完成（按优先级接）

P0 先让半成品可交：
1. 全量 `xcodegen generate` + build + 134+ 测；修跨 Agent 接口冲突。
2. 真实照片走主流程截图：首页 → 线路页 → 记这一次 → 顺序 → 分享预览。头图/卡片必须自动取景，不能再整图 fit 把线缩成一小块。
3. 未提交改动验收后单独 commit；不要带上会话开始前就脏的 13 个旧文档。

P1 首页+建线（规范 §4.1/4.2）：
- 点亮屏：拖动放大镜（2× loupe 跟手指）、底部毛玻璃条「N 个点 / 撤销 / 完成」、0 点完成 disabled、首次「点亮你要爬的点」
- 来源页已有墙缩略图 `focus` 到该墙所有线
- `RecognizeLinesView` 旧线淡、新点白描边
- 相机/相册权限被拒空态 + 去设置
- 相邻卡片预加载；页码更轻（点状或小字 `1/6`）
- Intro 聚光灯语义（深底发光点 + 唯一黄钮）未验视觉

P1 线路页+记录（§4.3/4.4）：
- 头图约 48% 屏高 + `focus`；副标题去重（「直壁 · 黄 · V3 · 直壁」）
- `+1` `contentTransition(.numericText())` + 触感；提醒四选一收起动画
- 「上了且没掉 → 提示复制计划为实际」
- 记这一次键盘滚到可见、`.scrollDismissesKeyboard`

P1 顺序（§4.5）：
- 明亮木板墙上火柴人描边对比度
- `groundY` = 最低点 + 余量（不是图底）
- 无照片线画布不崩（未截图验）
- `StickFigureSolver` 手高时髋贴墙偏置（共享层，未改）

P1 分享+设置（§4.6）：
- 真实照片 1080×1920 海报未渲染评审
- 设置：步进器长按连加、臂展比「恢复默认」仅非默认出现、导出 ProgressView、诊断中位数+复制、关于页一句话
- 删除全部二次确认文案/长按 2 秒未重做

P2 产品（PRD 未做）：
- FR-49 搜索（M2）
- FR-12 颜色建议点亮、FR-13 相似线（M3）
- FR-35 跨线短板、FR-36 通用提示库（M3）
- FR-64 iCloud、FR-65 Watch +1/上了（ADR 0004 草稿未落地）

P2 发布：
- 真机：相机 / OCR / 语音 / 导出 zip / 分享图性能
- SwiftData `VersionedSchema` V1（已加 `Session.fallText`）
- XCUITest 主路径；Dynamic Type；App Icon / TestFlight
- `CONTEXT.md` / `README.md` 术语未跟上（聚光灯、线、记这一次）

---

## 共享层已知建议（未改）

- `SpotlightImage`：浅色木板墙 `dim` 0.66 偏轻，可按平均亮度自适应
- `Store.updateReminder` 应返回撤销闭包（Detail 用了自己的 `updateReminderUndoable`）
- `SpotlightGeometry` 收纳 `isoPoint(fromView:)`
- `UndoCenter` 已 `@MainActor`；非 body 里延时更新用 `Task { @MainActor in }`

---

## 不要动

- 会话开始前就脏的 13 个文档：`AGENTS.md`、`CONTEXT.md`、`README.md`、`docs/adr/0001|0003`、`docs/agents/*`、`docs/climbing_bouldering_*`、`docs/project_background.md`，以及未跟踪的 `docs/adr/0004-*.md`。本轮没改它们。
- 真实墙照片不要进公开仓库。
- 不要和羽毛球 / RallyMate 混代码。

下一步：一个人清编译 → 验收未提交打磨 → commit → 按 P1 清单开一轮，不要再四路并行半成品。
