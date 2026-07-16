# MediaFlow

MediaFlow 是一个面向 Windows、Android 和 iOS 的跨平台媒体链接处理工具。项目当前优先支持 Windows，并以可长期维护的开源项目标准构建。

## 当前阶段

阶段 4.1 已完成下载体验、持久化和稳定性增强：

- Material 3 主题、深色模式、声明式路由与自适应导航
- Riverpod 状态管理、统一错误处理和日志入口
- 平台检测、`ParserService` 与统一 `ParserInterface`
- Bilibili 普通链接和短链接的公开视频信息解析
- 抖音分享链接重定向与多来源公开元数据解析
- 标题、作者、封面、时长和视频信息的统一展示
- 顺序多任务下载队列、暂停、继续、删除和失败重试
- HTTP Range 断点续传与 .part 临时文件管理
- 下载历史、完成时间、设置和深色模式持久化
- 默认下载目录、完成通知和失败文件清理设置
- 解析、下载、网络和文件错误分类日志

仅当解析器提供可用的直接媒体地址时启用下载。任务按队列顺序执行，软件重启后可恢复历史并继续未完成任务。

## 技术栈

- Flutter / Dart
- Riverpod
- go_router
- http
- html
- logging
- path_provider
- Material 3

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

开发环境与缓存路径说明见 [`docs/开发计划.md`](docs/开发计划.md)，解析模块说明见 [`docs/解析模块.md`](docs/解析模块.md)，下载模块说明见 [`docs/下载模块.md`](docs/下载模块.md)，设置与持久化说明见 [`docs/设置与持久化.md`](docs/设置与持久化.md)。

## 分支策略

- `main`：稳定发布基线
- `dev`：日常开发与集成分支
- `feature/*`、`fix/*`、`docs/*`：短期工作分支

## 许可证

许可证将在首次公开发布前以 Apache-2.0 形式加入仓库。