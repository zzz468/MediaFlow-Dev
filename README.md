# MediaFlow

MediaFlow 是一个面向 Windows、Android 和 iOS 的跨平台媒体链接处理工具。项目当前优先支持 Windows，并以可长期维护的开源项目标准构建。

## 当前阶段

阶段 2 已完成基础应用框架：

- Material 3 主题与深色模式切换
- 声明式路由与自适应导航布局
- 首页链接输入工作区
- 下载记录空状态与领域模型预留
- 设置页与基础应用信息
- Riverpod 状态管理、错误处理和日志入口

视频解析、媒体信息获取和下载任务尚未实现，将在后续阶段通过独立的领域用例、平台解析器和下载引擎接入。

## 技术栈

- Flutter / Dart
- Riverpod
- go_router
- logging
- Material 3

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

开发环境与缓存路径说明见 [`docs/开发计划.md`](docs/开发计划.md)。

## 分支策略

- `main`：稳定发布基线
- `dev`：日常开发与集成分支
- `feature/*`、`fix/*`、`docs/*`：短期工作分支

## 许可证

许可证将在首次公开发布前以 Apache-2.0 形式加入仓库。