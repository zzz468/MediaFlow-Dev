# X / Twitter 路线研究（2026-10-03）

结论：Dart 公开 syndication 路线已匿名解析并完整下载用户单视频、单图、双图，以及上游图+视频混合样本。2026-10-03 用户确认 Windows 与 Android 全部正常通过，当前约定样本范围等级为 **A PASS**，阶段 `V0.6.0 INSTAGRAM/X FEASIBILITY READY`。汇总人工反馈见 `evidence/user-validation-2026-10-03.json`；不能泛化为所有公开/敏感/受限帖子。下文早期待验收描述保留为历史记录。

| 项目 | 维护证据、许可 | 入口与实际范围 | 采用判断 |
|---|---|---|---|
| [gallery-dl](https://github.com/mikf/gallery-dl) | 2026-09-27 1.32.14；GPL-2.0 | `twitter.py` TweetResultByRestId / TweetDetail GraphQL、guest activation 与账号会话；有序 media、图片、MP4/视频、混合；匿名对照真实取得用户双图 2 项 | Python；视频合并可需 FFmpeg；参数、GraphQL ID、transaction 与登录路径复杂，仅参考设计和字段，不搬运模块。不能将它的默认 Cookie 配置视为 MediaFlow授权 |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | 实际 2026.08.19；源码 master，HEAD未核实；核心 Unlicense | GraphQL/legacy/syndication 选择；视频、GIF和多视频。图片列表不是核心输出。syndication 显式提示可能缺失媒体/元数据 | 本次强制 syndication、无 Cookie：用户视频 metadataSucceeded=true、5 formats；不下载、不运行 FFmpeg。radix36 数值函数翻译复用，来源见 THIRD-PARTY |
| [Koishi Twitter Fetcher](https://github.com/WhiteBr1ck/koishi-plugin-twitter-fetcher) | 2026-09-26 `43f6b26…`；package.json声明MIT，独立LICENSE未确认 | `src/index.ts` 默认 API=`api.vxtwitter.com`/`api.fxtwitter.com`；另有 Puppeteer DOM+网络观察，文本与媒体可各选来源；浏览器可注入 auth_token，话题搜索复制 Cookie 至 scraper | 第三方解析 API 被排除、不运行。可借鉴限定目标 article、拒绝未获 DOM 确认的头像/图标；资源抓取到达顺序不能当原帖顺序。Node/Puppeteer、Cookie 注入不可照搬；未复用代码 |
| [AstrBot Parser](https://github.com/Zhalslar/astrbot_plugin_parser) | 2026-09-29 `4d8bf1c…`；MIT | `core/parsers/twitter.py` 调用 `https://xdown.app/api/ajaxSearch`，有 xdown Cookie配置 | 外部解析服务器路线，不运行，不采用；成功界面不能证明平台原生匿名接口可用 |

近期风险证据：[gallery-dl #9783](https://github.com/mikf/gallery-dl/issues/9783) 2026-09-28 client-web 404、[#9767](https://github.com/mikf/gallery-dl/issues/9767) quoted tweet 判 deleted；[yt-dlp #17738](https://github.com/yt-dlp/yt-dlp/issues/17738) 2026-09-25 JSON解析失败。引用帖子、长文、敏感内容与页面改版需要独立覆盖，不能从普通帖子成功推断。

PoC：规范化 X/Twitter status URL → 平台自有 `https://cdn.syndication.twimg.com/tweet-result?id=…&lang=en&token=…` → 本作品 `mediaDetails` 原始顺序 → photo 或 video_info 的 MP4 候选 → 选择最大 bitrate → 现有 MediaContent/MediaResource。token 是公开嵌入的数值转换参数，不是账号令牌；不记录值。忽略 quoted_tweet，避免把引用作品混入当前作品。

旧响应无 mediaDetails 时，只允许单 video 或纯 photos 数组并标记“完整性未证实”；photos 和 video 分开返回时拒绝猜混合顺序。不把 HLS当MP4，不安装FFmpeg，HLS-only明确失败。403、429、登录/安全要求停止，无自动换路或重试。

## Windows 实际下载

| status ID | 作者/类型/顺序 | 全量下载结果 |
|---|---|---|
| 2102857143263085031 | JakeStateFarm / 单视频 | video.twimg.com，MP4 200，499123 字节 |
| 2106263058905813231 | DrYlurvhn / 两图 | pbs.twimg.com，两 JPEG 200，86462 / 67902 字节；数组顺序不变 |
| 2106209623682453836 | fly3nn / 单图 | pbs.twimg.com，PNG 200，16134 字节；已按实际 MIME 使用 .png |
| 1577924293023133696（上游） | carrotsprout_ / 图片→视频 | JPEG 200，264770 字节 → MP4 200，146756 字节 |

每个文件大小等于下载响应 Content-Length。所有图片 Windows 解码成功；不同图片 SHA256 不同。元数据 gzip传输长度与解压后 body 字节数不同属于正常现象，不能把元数据 body 当媒体文件完整性证据。

Android及人工验收见 [validation](social-validation.md)。本次样本无登录；匿名整体范围未证实。系统播放器、音轨、肉眼对照顺序尚待反馈。主要风险是 syndication 范围/字段/可访问性变化、最高 bitrate 非完整画质集合、媒体 URL过期、混合/引用/敏感类型差异。仅已有足够双端证据的平台才建议下一阶段讨论 production。
