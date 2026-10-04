# v0.6.0 架构落地

URL → PlatformDetector → 独立 Instagram/X Adapter → 现有 MediaContent / ordered MediaResource → 通用资源选择 → Downloader → History。

Instagram 的单次 CSRF 上下文只在 Adapter 内存；X 使用已通过 feasibility 的原生 syndication 数值协议，非账号 token。平台身份/协议不进入公共模型、UI 或 History。

MediaContent/MediaResource 无扩展、无第二套模型。每个原始媒体项选一个直接资源；视频选已验证策略的直接 MP4，不按类型重排。选择保留原任务序号。

DownloadTask 最小兼容增加可选 groupResources，旧数据默认 false；History 按作品/操作聚合并恢复原序号，旧视频展示不变。临时 CDN URL 不入库；完成文件可打开，失效未完成任务需重新解析稳定源链接。

UI 经 ParserService/Application 使用既有资源选择页面。Downloader 不认识平台页面；Media Processing/Browser Adapter 边界保留。没有新依赖、FFmpeg、外部解析服务或外部 Cookie 导入。

Windows/Android production 已实际验收，最终正式 Release 最小 smoke 独立记录。其他三端理论兼容，未构建/实测；协议和 CDN 生命周期为维护风险。
