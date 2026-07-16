# MediaFlow

MediaFlow 是一个面向 Windows、Android 和 iOS 的跨平台媒体链接处理工具。项目当前优先支持 Windows，并以可长期维护的开源项目标准构建。

## 当前阶段

阶段 3.5 已完成真实媒体信息解析基础能力：

- Material 3 主题、深色模式、声明式路由与自适应导航
- Riverpod 状态管理、统一错误处理和日志入口
- 平台检测、`ParserService` 与统一 `ParserInterface`
- Bilibili 普通链接和短链接的公开视频信息解析
- 抖音分享链接重定向与多来源公开元数据解析
- 标题、作者、封面、时长和视频信息的统一展示
- 多任务模拟下载管理与下载记录展示

当前下载流程仍为模拟实现，不请求视频资源、不保存真实文件。真实下载引擎将在后续阶段通过独立接口接入。

## 技术栈

- Flutter / Dart
- Riverpod
- go_router
- http
- html
- logging
- Material 3

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

开发环境与缓存路径说明见 [`docs/开发计划.md`](docs/开发计划.md)，解析模块说明见 [`docs/解析模块.md`](docs/解析模块.md)。

## 分支策略

- `main`：稳定发布基线
- `dev`：日常开发与集成分支
- `feature/*`、`fix/*`、`docs/*`：短期工作分支

## 许可证

许可证将在首次公开发布前以 Apache-2.0 形式加入仓库。