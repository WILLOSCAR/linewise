# 线感 LineWise · 实现状态与待办（2026-09-13 收尾记录）

分支 `feat/ios-app-v1`。本文记录 iOS App 第一轮实现 + 第二轮 UI 打磨收尾时的状态：做了什么、没做什么、下一步从哪接。

> 当天下午已接手第二轮打磨并修复回归；当前验证与优先级以 [接手验收](linewise_takeover_2026-09-13.md) 为准。

> 当前代码提交 `2e3a964`：156 项单元／集成测试与 2 条原生 UI 测试通过，Release 模拟器构建通过。新增讨论的[岩点分割提案](linewise_hold_segmentation_proposal_2026-09-13.md)尚未实现，建议先验证点选分割的效果与操作负担。

## 1. 现状一句话

iPhone 原生 App（iOS 17+，SwiftUI + SwiftData，无第三方依赖）已实现 MVP / M1 / M2 的主体流程，M2 的搜索和完成后复制计划提示仍缺。现已集成第二轮打磨、修复回归并通过模拟器测试；真机相机 / OCR / 语音尚未验证。

## 2. 怎么跑

```
cd app && xcodegen generate
xcodebuild -project LineWise.xcodeproj -scheme LineWise -destination "platform=iOS Simulator,name=iPhone 17" build
```

演示数据（DEBUG 启动参数）：
- `-seedDemo`：库为空时写入合成墙 + 5 条线 + 记录。
- `-seedDemo -demoPhotosDir <目录>`：额外用目录里的真实墙照片建墙；已知文件名 `wall-yellow.jpg`（直壁黄线 9 点）、`wall-white.jpg`（大斜板白线 8 点 + 紫线 7 点）带对准好的点位。照片**不进仓库**（公开仓库，照片里有人），本机放在 `/tmp/linewise-demo-photos/`。
- 直达页面：`-openFirstLine`、`-openLine <名字包含>`、`-openBuilder`、`-openSettings`、`-demoUndo`；顺序编辑器自带 `-openSequenceEditor [actual]`、`-openSequencePanel`、`-sequenceScript "..."`（`Features/Sequence/Debug/`）。各功能目录下的 `Debug/` 还有各自的截图入口。

测试：`xcodebuild ... test`（Swift Testing）。基线提交 `a0f939f` 时 134 个用例全绿。

## 3. 已完成（按 PRD §7 功能清单）

- 首页横滑卡片、筛选（进行中 / 今天 / 上了 / 全部）、岩馆切换、空态、首次引导。
- 建线：拍照 / 相册 / 已有的墙 / 不拍照四种来源；点亮屏（点亮、拖动微调、捏合缩放、长按菜单、起步 / 结束默认）；扫描揭示；难度 OCR 预填（FR-10）；墙区 / 角度默认上次（FR-11）。
- 线路页：聚光灯图（历史掉落点、筛选联动）、状态机（上了 / 拆了 / 新一轮）、提醒与四选一验证（FR-32/33）、教练几句（FR-34）、历史筛选（FR-43）、整面墙置 gone（FR-46）、合并重复卡（FR-47）、改信息、全屏查看器。
- 记这一次：点图选掉落点、点顺序第几步（FR-28）、次数、上了、8 个原因、一句话 + 语音（FR-25）、逐次展开（FR-27）、补记过去日期、保存后提醒卡。无照片线用 `Session.fallText`。
- 顺序（火柴人）：FR-50 ～ FR-57 全部；计划 / 实际两份 + 差异；体型比例。
- 分享图 1080×1920（FR-60，含快照带）；设置（岩馆、体型、导出 JSON / zip、删除全部、诊断、关于）。
- 共享层：聚光灯渲染（暗墙 + 光晕 + 双环 + 扫描光带 + 火柴人）、自动取景 `focus`、大画布 `scale`、窗口级撤销条、触感、图片降采样缓存、软删除 24h 清理。

## 4. 第二轮 UI 打磨（收尾时状态）

规范见 `docs/linewise_ui_spec_v1.md`。凌晨四个方向中断时的状态见 `docs/linewise_handoff_2026-09-13.md`；下午接手后的集成与验收见 `docs/linewise_takeover_2026-09-13.md`。

## 5. 未做（明确留到下一步）

PRD 中未实现的功能：
- FR-49 搜索（M2）：按名字 / 墙区 / 难度 / 备注。
- FR-12 颜色识别建议点亮、FR-13 相似线提示（M3）。
- FR-35 跨线短板统计、FR-36 通用提示库（M3）。
- FR-64 iCloud 私有同步、FR-65 Apple Watch `+1` / `上了`（M3；ADR 0004 草稿在 `docs/adr/`，未落地）。
- "上了且没掉 → 提示把计划顺序复制为实际"（M2 细节）。

工程 / 发布相关：
- 未在真机验证：相机拍摄、相册权限、Vision OCR 识别率、SFSpeech 中文识别、导出 zip 分享、ImageRenderer 分享图性能。
- SwiftData 尚未使用 `VersionedSchema`；正式发布前需要把当前模型定为 V1 并建立迁移计划。`Session.fallText` 在接手基线 `a0f939f` 中已存在，本轮接手修复没有新增此模型字段。
- 仅中文文案，未做本地化；未做 Dynamic Type 大字号回归。
- 已增加原生 XCUITest，覆盖无照片建线／记录重开，以及顺序真实拖动／撤销；仍需扩展相机与完整照片建线路径。
- App Icon 为脚本生成的占位图；无启动页；未配置 TestFlight。
- 性能：未在真机 profile；聚光灯 Canvas 在 50 点线上的重绘、首页相邻卡片预加载需要实测。

共享层的已知建议（来自各 Agent，未全部落地）：
- `StickFigureSolver`：手很高时髋部应更贴墙（偏置），当前姿态偶尔"挂得太直"。
- `SpotlightImage`：明亮照片（浅色木板墙）上 `dim` 0.66 略轻，可按图像平均亮度自适应。
- `Store.updateReminder` 改为返回撤销闭包（LineDetail 目前用自己的 `updateReminderUndoable`）。
- `SpotlightGeometry` 收纳 `isoPoint(fromView:)` 等火柴人坐标辅助方法。

仓库卫生：
- 工作区有 13 个文档文件（`AGENTS.md`、`CONTEXT.md`、`README.md`、`docs/adr/0001|0003`、`docs/agents/*`、`docs/climbing_bouldering_*`、`docs/project_background.md`）在本轮开始前就已有未提交修改，以及未跟踪的 `docs/adr/0004-watch-assisted-memory-and-proof.md`。本轮**没有**动它们，也没有提交，请自行决定。
- `CONTEXT.md` / `README.md` 尚未按新 App 的术语（聚光灯、线、记这一次）更新。

## 6. 下一步建议

1. 真机跑一遍主流程（拍墙 → 点亮 → 扫描 → +1 → 记这一次 → 分享），记录建线用时（PRD 目标为中位 ≤15 秒、P90 ≤25 秒，当前尚无现场测量）。
2. 按 §4 各方向的"未完成"清单补齐打磨项，再做一轮真实照片截图评审。
3. 定 SwiftData V1 schema，接 TestFlight。
