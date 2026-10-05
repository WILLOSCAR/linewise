# 线感 LineWise

拍墙、读线、摆动作、回放；爬完记住掉在哪、下次试什么。面向室内抱石的 iPhone App。

**当前：v1.x 记忆与手动顺序流程已实现；v2.0 读线和模拟仍在原型阶段。下一步是 Demo A。** 2026-10-05 验证通过 169 项单元／集成测试及 3 条原生 UI 测试；真机与馆访验收仍待完成。

## 入口

- [执行路线与任务](docs/roadmap.md)：Demo A → D，当前只推进 A。
- [当前进度与证据](docs/linewise_status_2026-10-05.md)：App、原型、测试、缺口。
- [产品契约 v2.0](docs/linewise_prd_v2_0.md) · [UI 规范](docs/linewise_ui_spec_v1.md) · [术语](CONTEXT.md)。
- [全部文档](docs/README.md)：当前规范、研究、历史归档。
- [分割实验源码](experiments/hold-segmentation/README.md)：Mac 命令行与网页原型。

## 目录

| 目录 | 用途 |
| --- | --- |
| `app/` | SwiftUI / SwiftData iOS App、XcodeGen 配置和测试 |
| `experiments/` | 原型源码与汇总证据；未集成到 App |
| `docs/` | 活跃产品文档；`research/` 为研究，`archive/` 为历史 |
| `.scratch/` | 被忽略的私人输入、模型、实验输出和本机验证日志 |

## 构建与测试

需要 Xcode 和 XcodeGen。在仓库根目录执行：

```sh
(cd app && xcodegen generate)
xcodebuild -project app/LineWise.xcodeproj -scheme LineWise \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
xcodebuild -project app/LineWise.xcodeproj -scheme LineWise \
  -configuration Release -destination 'generic/platform=iOS Simulator' build
```

当前验证环境为 Xcode 27.0、iOS Simulator 26.5。设备名需与本机模拟器一致。真实墙照不进入公开仓库；馆访记录格式见 [v1.1 §10.4](docs/linewise_prd_v1_0.md#104-馆访反馈模板)。
