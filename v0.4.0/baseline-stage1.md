# 第一阶段：v0.4.0 正式能力基线（2026-09-25）

本记录是对当前 `feature/v0.4.0` / `e2ea89d4e156c843af09b4c491984a2206f1135b` 源码及 [v0.3.0 发布说明](../v0.3.0/release.md)的**结构核对**。v0.3.0 Release 的真实验收属于上一版本历史证据；本阶段没有重新运行、构建或验收 v0.4.0。

| 能力 | 当前正式代码位置与合同 | 本阶段须保护的行为 |
| --- | --- | --- |
| 平台检测与调度 | `lib/features/parser/data/url_platform_detector.dart`、`lib/features/parser/application/parser_service.dart`；默认顺序 Bilibili opus、Bilibili 视频、Douyin 视频 | 新入口须是独立 Parser/Adapter；旧 `supports` 分发与失败语义不能被图文误匹配破坏 |
| Bilibili 视频 | `lib/features/parser/data/bilibili/bilibili_parser.dart`；旧 `ParserSuccess(VideoInfo)` | 已发布视频解析与画质/下载行为保留 |
| Bilibili 图文 | `lib/features/parser/data/bilibili/bilibili_opus_parser.dart`；`ParserContentSuccess(MediaContent)` | 公开 opus 的有序图片、重复 URL 的不同出现位置、双端资源选择和保存行为保留 |
| Douyin 视频 | `lib/features/parser/data/douyin/douyin_parser.dart`，SSR → 匿名移动 feed → detail session → 可选 Browser Observation；成功仍为 `VideoInfo` | 现有视频 URL 提取、匿名会话与安全停止逻辑不因图文研究而放宽；当前代码不能据此宣称 `/note/` 图文已支持 |
| 统一内容模型 | `lib/features/parser/domain/media_content.dart`；`MediaContent` 持有有序 `MediaResource`，类型涵盖 video/image/gallery/article/audio/mixed；资源请求头拒绝 Cookie/Authorization | 图文须映射到该模型；资源 ID 以作品内位置稳定区分，不能把所有作品强制成 `videoUrl` |
| 多资源任务映射 | `lib/features/downloader/application/media_content_download_mapper.dart`；每资源一 `DownloadTask`，按资源顺序编号，操作 ID 区分重复保存 | 下载器不理解平台字段；单资源失败不丢其他已成功资源 |
| DownloadTask 与持久化 | `lib/features/downloader/domain/download_task.dart` 的可选 `contentId/resourceId/resourceType/mimeType` 等；`lib/features/downloader/data/json_download_task_repository.dart` 使用本地 JSON | 保持旧记录兼容，不清空历史；凭据请求头不落盘；任务状态、文件路径与资源关系不被研究改动 |
| 下载队列和文件 | `lib/features/downloader/application/download_manager.dart`、`data/http_download_service.dart`、`data/local_download_file_store.dart` | 暂停/继续/删除/单任务重试、Range、断点续传、`.part` 文件保护、启动恢复不降级 |
| History | `lib/features/history/application/download_history_projection.dart` 只聚合有图片关系字段且同平台/作品/操作 ID 的任务；旧视频保持独立 | 多图部分成功状态和重启后的聚合显示保持；不能以标题或短期 URL 推断作品关系 |
| Windows | Flutter Windows runner；`lib/core/browser/infrastructure/windows/` 的独立 Browser 能力；本地文件路径 | v0.3.0 Release 的 Bilibili 视频/双图、Douyin 视频、文件打开与 History 曾验收；v0.4.0 尚未重测 |
| Android | `android/app/build.gradle.kts` 的 `com.mediaflow.mediaflow`；`lib/features/downloader/data/android_media_store_publisher.dart` 与 `lib/core/browser/infrastructure/android/` | v0.3.0 Release 真机的相同核心链路曾验收；安装前须检查现有应用、签名与数据安全，本阶段不安装 APK |
| 隐私与部署 | 核心链路本地解析/下载/存储；无 MediaFlow 第三方解析服务器 | 不上传用户链接、Cookie、Token、设置、日志、历史或媒体；不导入用户账号态、不代理流量、不绕过访问控制 |

现有代码与发布证据分别支持“**v0.3.0 已发布能力**”和“**v0.4.0 当前结构未改**”，不能推断 v0.4.0 的实时平台可用性。iOS、macOS、Linux 尚未形成正式发布支持；新增平台代码必须保留 Adapter 路径。当前第一阶段只写研究文档，不修改 Flutter/Dart、Android 或 Windows production 文件。
