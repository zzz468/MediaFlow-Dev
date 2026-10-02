# YouTube 第二阶段证据

状态：**尚未满足双端可行性完成门槛；不能判定Y-A/Y-B，也不足以断言Y-C。**

## 参考与PoC选择

四项目源码、版本、Issues、许可和机制见 `reference-project-comparison.md`。优先实际运行本机可用的yt-dlp固定源码；仅匿名WEB、无代理/JS runtime/挑战求解、零重试，两个样本都在watch网络请求失败，见 `yt-dlp-real-results.json`。这不是yt-dlp默认策略失败证明。

YoutubeExplode因本机无.NET SDK未运行；NewPipe未建立JVM研究构建，且非本版打包路线；均 `NOT RUN / SOURCE VERIFIED`。Dart 3.1.0只成为隔离PoC依赖：共享HTTP/格式类型，绕开WatchPage合成Cookie/年龄参数及默认TV fallback，用普通watch观察的WEB context。首次请求已经失败，尚未调用StreamClient，所以不能声称该库manifest失效或可用。

## 同一批样本、两端结果

| 样本 | 普通公开候选/频道 | Windows | Android真机 | metadata/thumbnail | manifest/质量/三种role | 下载/系统播放 |
|---|---|---|---|---|---|---|
| jNQXAC9IVRw | Me at the zoo / jawed | 约12秒连接失败，networkFailure | 约12秒连接失败，networkFailure | 未取得 | 未取得 | NOT RUN |
| aqz-KE-bpKQ | Big Buck Bunny / Blender | 约12秒连接失败，networkFailure | 约12秒连接失败，networkFailure | 未取得 | 未取得 | NOT RUN |

本轮未取得当前metadata，频道和普通公开视频属性只是选样背景，不能当成当期权限核验。没有HTTP拒绝状态、没有player响应、没有403，更没有安全挑战或登录要求证据。环境连接问题与提取方案有效性分开记录。未使用代理改变地区/权限。

原始脱敏证据：`poc/windows-real-results.json`、`poc/android-real-results.json`；Android研究包 `com.mediaflow.research.v050.feasibility`，真机PJZ110、Android17。两端同样在连接层停止，stream集合差异尚不可比较。

## Streams与停止条件

预设观测字段由真实对象填充：itag、role、container、audio/video codec、quality、width/height、bitrate、size、hasAudio/hasVideo、transport；实际URL仅在内存，证据记录host/hash。字段缺失必须保持缺失。HLS/fragmented不冒称单文件progressive。

本轮无法观察progressive覆盖，因此不写FORMAT UNAVAILABLE，也不为此反复换样本。恢复正常合法直连环境后，用原两样本再次核验；只有manifest实际缺合流时才有界补一个普通样本。未取得文件，文件大小、格式、音视频track、声音及系统播放器均未验证；不做FFmpeg mux。

## 模型 / Downloader / History源码判断

现有MediaContent有video/audio/imageGallery/mixed类型，MediaResource有video/audio/image/cover和URL/MIME/安全headers，但无trackRole/quality/codec/宽高等。小步候选：选择阶段用Adapter内部stream descriptor；如果确需持久化视频是否有音频，才给公开资源增加通用role或hasAudio/hasVideo。当前没有真实manifest，**不批准任何字段扩展，不修改模型**。

三层推荐：discovered manifest → Application选择视图的selectable descriptor（过滤传输/格式/能力）→用户明确selected resources →MediaContent/download mapper。现有mapper会给content.resources每项建任务，因此绝不能直接放完整manifest。

DownloadTask可保存contentId/resourceId/resourceType/URL/filename/title/MIME/platform，audio resourceType可表达。resourceIndex没有独立字段，现有Gallery History从download任务ID序号恢复顺序。trackRole未保存，video-only与muxed同为video时无法可靠恢复角色；不能仅靠文件名推断。MediaPlatform当前仅unknown/douyin/bilibili，新平台身份需要未来小步登记；本阶段未改PlatformDetector或ParserService。

Downloader已接受audio MIME，文件store支持m4a/mp3/webm等，但音频实际下载/系统打开、过期URL刷新及冷启动角色恢复未实测；不能写已兼容通过。History仅源码兼容性判断，未用production创建或恢复新平台任务。

## 决策

当前为**环境阻断 / 待验证**，不强行归入Y-C。继续第二阶段：先正常网络条件下核验同样本，再决定Dart共享Adapter、正常player JS本地处理或其他成熟路线。production接入门槛尚未满足。

## 连接诊断补充

用户确认官方页面可打开，同时确认“浏览器有独立配置或两端使用不同网络”。所以浏览器成功访问不能直接作为研究程序系统直连成功的对照。待补充各端具体配置类型和成功的平台，不收集凭据，不改系统网络设置。

`poc/windows-network-diagnostic.json`：系统默认DNS返回YouTube69.171.235.22，TCP6秒超时，尚未TLS；相邻Windows解析曾返回174.132.167.252及2001::1。登记证据见 `dns-registration-evidence.json`（ARIN官方）。这是DNS/网络异常线索，未证明库故障或安全/地区拒绝。小红书两主机在同次TCP/TLS检查可连接且证书校验成功。未使用备用解析器、硬编码IP或代理绕过限制。

## 本轮固定样本更新

最新事实以network-matrix-phase2.md和phase2-progress-report.md续跑章节为准。YouTube两个用户固定样本双端连接失败，未取得metadata/manifest；Android小红书视频、第二5图作品真实下载与MediaStore成功，用户确认视频画面/声音及两图打开/顺序。8图PASS保留未重复。WindowsXHS本轮302登录安全停止。整体均NOT YET CLASSIFIED，不判production接入完成。

## 2026-10-01 最新状态（覆盖旧“网络阻塞开发”结论）

用户允许实现验证独立继续。隔离prototype双端测试构建已生成，23项offline/typed stream/UI测试通过。状态 `Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING`，联网仍 `REAL-WORLD VALIDATION BLOCKED BY ENVIRONMENT`，尚不判Y-A/B/C。操作/限制/真实反馈清单见youtube-prototype-guide.md，SHA256/交付路径见youtube-prototype-build.json。完成构建后暂停，不接production。
