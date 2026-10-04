# 来源与许可

2026-10-03，参考文件保存在 `reference/`，保留上游版权声明和 LICENSE。它们不参与 Flutter 构建。`.reference-runtime/` 是被忽略的一次性 Python 对照目录，不属于应用运行时。

| 项目 | 已核对许可 | 使用方式 |
|---|---|---|
| [gallery-dl](https://github.com/mikf/gallery-dl) | GPL-2.0；源码明确 GPL v2 | Instagram/Twitter extractor 的协议与有序列表设计参考；未搬运进 Dart。完整参考文件与许可证成对保存，不可当作可任意复制的生产模块 |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | 本次仓库 LICENSE 为 Unlicense；二进制/依赖许可须另审 | Twitter syndication 协议参考；`jsinterp.py::js_number_to_string` 的 radix 36 数值算法翻译为 Dart `syndicationToken`，属于实际代码改写复用。保留来源注释、许可证；4 个固定 ID 与上游函数结果一致。其余 parser 为独立实现 |
| [Instaloader](https://github.com/instaloader/instaloader) | MIT，版权 Alexander Graf / André Koch-Kramer | `structures.py::Post._obtain_metadata` 与 `instaloadercontext.py::doc_id_graphql_query` 的公开字段、doc_id 和本地匿名初始化设计参考。没有搬运 Python 模块；如未来搬运，必须保留 MIT 声明 |
| [Koishi Twitter Fetcher](https://github.com/WhiteBr1ck/koishi-plugin-twitter-fetcher) | package.json 声明 MIT；根目录未发现独立 LICENSE，完整许可文本未确认 | 仅设计审计，未复用代码。不能仅凭 manifest 直接搬运实现 |
| [AstrBot Parser](https://github.com/Zhalslar/astrbot_plugin_parser) | MIT，版权 Les Freire | 仅审计设计与数据来源，未复制代码 |

MediaFlow 的适配：纯 Dart，现有 MediaContent/MediaResource 快照；仅平台所属 HTTPS；匿名 CSRF 本轮内存隔离与明确丢弃；无账号 Cookie、外部解析服务器或浏览器 Cookie 导入；403/429/安全验证停止；Windows/Android 存储和打开通过独立 research adapter。Python、FFmpeg、Node、Koishi、AstrBot 不加入正式项目或 APK/EXE。

源码获取的是各仓库当时 master/main 快照；`reference/*commits.json` 记录已查到的分支提交，不能保证每个 master 文件与该提交原子一致。yt-dlp GitHub commits API 多次超时，当前 HEAD 未核实；已实际运行的发行版为 2026.08.19。最终采用前应锁定具体版本并再核对许可。源码 SHA-256 清单用于追溯本次实际读取内容。
