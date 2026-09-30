# v0.4.0 架构边界与现状

本页是 `e2ea89d4e156c843af09b4c491984a2206f1135b` 的规划快照，不是 v0.4.0 实现记录。以根目录 `AGENTS.md` 为最高项目约束。

| 位置 | 已有能力 | v0.4.0 需验证的限制 |
| --- | --- | --- |
| `lib/features/parser/domain/media_content.dart` | `MediaContent` 与有序 `MediaResource`，涵盖 video/image/gallery/article/audio/mixed 类型；拒绝凭证请求头 | 类型存在不等于各种内容已由 production Parser 支持；资源 URL 可过期 |
| `lib/features/parser/application/parser_service.dart` | 按 `supports` 调度 Bilibili opus、Bilibili 视频与 Douyin 视频 Parser | 新入口应在独立平台 Parser/Adapter；不得在服务层堆页面字段或平台特例 |
| `lib/features/downloader/application/media_content_download_mapper.dart` | 每个资源映射独立 `DownloadTask`，携带作品/资源标识和顺序 | 多资源部分失败、重试及重启的作品操作语义需用真实场景复核 |
| `lib/features/history/application/download_history_projection.dart` | 仅将带图片关系字段的任务按平台、作品、操作 ID 聚合；旧视频独立 | 当前从任务 ID 恢复操作 ID。若新混合资源确需聚合，先设计向后兼容的显式关系字段，再决定是否迁移 |
| `lib/core/browser/` | 有抽象和 Windows/Android 平台能力 | Douyin 视频现有观察路径不证明图文可用；不得导入用户浏览器登录态或绕过挑战 |

目标链路保持：URL/分享链接 → PlatformDetector → 独立 Parser/Adapter → `MediaContent`/`MediaResource` → 可选独立 Processor → 通用下载任务 → History。UI 经 Application/Domain 接口访问核心能力。当前没有 v0.4.0 Processor 实现计划。

Windows 与 Android 同为核心平台。平台文件发布、WebView/Browser 及系统打开能力保留在 Adapter/Infrastructure；领域模型和上层下载接口不依赖 Win32、Android API。iOS/macOS/Linux 本版未列入正式支持，但设计不能封死其 Adapter 路径。

不引入自建或第三方解析服务器，不上传用户链接、媒体、设置、历史、日志或 Cookie；不依赖用户登录。遇到验证码、登录、付费、地区、权限或额外安全验证要明确停止。新依赖和第三方代码复用必须先核实五端适配、维护与许可证。
