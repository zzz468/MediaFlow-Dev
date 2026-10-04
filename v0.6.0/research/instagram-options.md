# Instagram 路线研究（2026-10-03）

结论：独立 Dart PoC 已匿名解析、完整下载真实 Reel、单图和 4 图 Carousel。2026-10-03 用户确认 Windows 与 Android 全部正常通过，当前约定样本范围等级为 **A PASS**，阶段 `V0.6.0 INSTAGRAM/X FEASIBILITY READY`。汇总人工反馈见 `evidence/user-validation-2026-10-03.json`；不代表全平台匿名可用，真实混合 Carousel 尚未单独验证。下文早期待验收描述保留为历史记录。

## 成熟方案审计

| 项目 | 最近维护证据 | 支持/入口/数据来源 | 身份、运行时、采用判断 |
|---|---|---|---|
| [gallery-dl](https://github.com/mikf/gallery-dl) | 2026-09-27 release 1.32.14，已运行该版；审计 instagram.py | Post/Reel、单图、Carousel、混合；REST `/v1/media/{pk}/info/`、GraphQL `shortcode_media`；遍历 `carousel_media` / `edge_sidecar_to_children.edges` | Python；部分视频合并才需 FFmpeg。匿名能力不可仅凭支持清单确认；大量登录配置与生成 CSRF 不照搬。GPL-2.0，仅设计参考 |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | 2026.08.19 发行版实际运行；master extractor 与发行版可能不同，HEAD API 未核实 | 视频/Reel、多视频；当前 master 的 `api/graphql` / `PolarisLoggedOutDesktopWWWPostRootContentQuery`，访问性检查及 HTML `data-sjs` hydration；登录路径 media info | Python；部分路径支持 curl-cffi impersonation，不能当作 Dart 自带能力；视频导向，不能单独满足图片/混合顺序。Unlicense 核心，不复制依赖 |
| [Instaloader](https://github.com/instaloader/instaloader) | 2026-09-06 commit `7efc78d…`；实际运行 4.15.3 | Post.from_shortcode；doc_id GraphQL 的 items；sidecar 节点、图片候选、video_versions；照片、Reel、Carousel/混合 | Python requests；本次无登录成功，完整媒体仍由 Dart 下载。MIT；最适合借鉴匿名初始化与统一列表转换，无须 FFmpeg/JS 才能做本 PoC |
| [AstrBot Parser](https://github.com/Zhalslar/astrbot_plugin_parser) | 2026-09-29 commit `4d8bf1c…` | `core/parsers/instagram.py` 视频调用 yt-dlp，图片调用 `python -m gallery_dl -j`，支持外部 Cookie 文件 | 不是新的 Dart 原生协议路线；Python runtime 和 Cookie 文件不可接入 MediaFlow。MIT，未复用代码 |

上游近期风险证据：[gallery-dl #9787](https://github.com/mikf/gallery-dl/issues/9787) 2026-09-30 的 429、[#9784](https://github.com/mikf/gallery-dl/issues/9784) 401/重定向、[#9762](https://github.com/mikf/gallery-dl/issues/9762) 音乐提取；[Instaloader #2748](https://github.com/instaloader/instaloader/issues/2748) 2026-09-29 的空/非 JSON 响应、[#2746](https://github.com/instaloader/instaloader/issues/2746) Carousel 音频、[#2726](https://github.com/instaloader/instaloader/issues/2726) 429；[yt-dlp #17755](https://github.com/yt-dlp/yt-dlp/issues/17755) 是 Stories/Cookie 问题，不能直接推断公开 Post 能力。issue 是风险线索，不代表本次样本结论。

## 实际对照与 PoC

`evidence/reference-*.json`：Instaloader 4.15.3 无登录取得 BoHk1haB5tM，GraphSidecar/5 项；yt-dlp Instagram 运行触及研究请求预算后受控停止（不是技术失败判定）；gallery-dl 单图对照运行抛 HttpError，未取得媒体。三个工具均未读取用户配置或外部 Cookie，未把第三方运行时打包。

HTML hydration 在用户两样本中返回 HTTP 200，但只找到匹配 shortcode 的路由参数，没有媒体实体。最初匹配到路由 map 导致“缺少子资源”，已收紧实体条件，不能把该结果解释为登录或网络失败。不能用页面脚本中的 captcha 字样判安全挑战，此误判已修正并测试。

裸 GraphQL：DdoJxTMFFgi、Dd_OJNzCVSU 均 403，立即停止，无登录/签名变更重试。独立正常上下文路线按 [最小条件矩阵](instagram-context-matrix.md)：首页 GET → 平台签发 csrftoken → 一次 GraphQL POST `doc_id=27128499623469141` → `items[0]` → 按 carousel 数组顺序映射现有模型。仍使用 MediaFlow UA，不复制浏览器/iPhone指纹、设备 ID 或窗口 Cookie。本轮 CSRF 只在 Adapter 内存、只回传所属平台，finally 丢弃，不进入诊断或模型。

## Windows 真实证据

| 样本 | 类型/作者 | 结果 |
|---|---|---|
| DdoJxTMFFgi（用户） | 4 图 Carousel / _yenacore | 元数据 200；4 个 CDN JPEG 全量 200，470290 / 405791 / 404187 / 486155 字节，各自与 Content-Length 一致 |
| Dd_OJNzCVSU（用户） | Reel / kitto.tw | 元数据 200；CDN MP4 200，15637515 字节，与 Content-Length 一致 |
| BqvsDleB3lV（上游） | 单图 / instagram | 元数据 200；JPEG 200，383468 字节，与 Content-Length 一致 |

所有 JPEG 已由 Windows 图像解码器实际加载；Carousel 为 3277×4096。图片哈希各不相同。系统应用打开、视频画面/声音、对照源页面确认顺序仍待用户反馈；不能把解码/全量下载写成播放验收。混合 Carousel 已有模型/fixture 测试，但本次未取得明确真实混合样本，未测试其附加音轨/音乐。

Android 结果和最终人工结论见 [validation](social-validation.md)。没有登录必要性的普遍结论：本次成功样本不需要登录，其他内容若要求账号则停止并记录为未来 App 自有会话候选。

风险：非官方 doc_id 变化、CSRF 初始化变化、IP/频率限制、CDN 临时地址、音轨/音乐不完整、图片候选不一定等于最高原图；需要小范围版本维护和真实样本矩阵。此阶段不建议直接接 production。
