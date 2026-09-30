# Douyin gallery 横向审计 — 2026-09-28

决策：**H2 — Web detail + local session/signature is the industry-consistent route**。

下一轮唯一目标：设计 `anonymous where possible → local session/signature for gallery → Web detail` 的平台隔离工程方案（local session、license-safe / clean-room signer、detail adapter）。停止继续寻找匿名旁路，不重启已关闭的 UIFID bootstrap、旧 Local Context Provider、Mobile Feed 或 Browser Observation。Browser 后续只可作为用户主动授权的登录/context provider；本报告不授权登录实验或生产修改。

这是源码收敛的工程决策，**不是四个项目已经在本机成功解析当前目标图文的结论**。所有路线当前图文端到端可用性仍未由本轮验证。安全拒绝必须停止，不能把安全头占位、合成指纹或高频重签重试当成正常协议兼容。

## 范围与基线

- cwd / Git top-level：`D:\projects\mediaflow-v040` / `D:/projects/mediaflow-v040`。
- branch：`feature/v0.4.0`；HEAD：`e2ea89d4e156c843af09b4c491984a2206f1135b`。
- 开始及结束 Git status：` M AGENTS.md`、`?? v0.4.0/`。AGENTS 修改与整个研究目录均已存在；保留。
- 已重新读取根 AGENTS.md、当前 gallery 研究 Markdown 记录，重点复核 generic-feed-once-result、mobile-feed-target-result、web-detail-signer-route-audit、local-session-audit。历史结论以各原记录为准。
- 本轮仅源码、许可证、公开维护信息审计，五个项目固定 SHA；不运行第三方程序。完整公共元数据、文件路径及 SHA256 见 `douyin-gallery-horizontal-sources.json`。源文件临时缓存：`D:\dev\tmp\mediaflow-v040-horizontal-audit`，未复制进产品。
- 平台请求 **1 次**；源码检索 / GitHub 请求另计。无 Cookie、Token、signer、代理、浏览器、WAF 脚本执行、媒体下载。

## 证据口径

“使用”= 当前固定源码有可达调用链；“成功”= 当前真实 gallery 响应证据。二者分别统计。五个仓库 GitHub 元数据均非 fork、未归档，但这不能证明算法完全独立。以下数量统计不同项目的独立应用控制流，不把同项目 Python/Dart 两份实现算两票，也不把共用 signer 当独立密码算法证据。

本轮审计：DLWangSan/douyin_parse（DL）、ucmao/media-parser（UC）、jiji262/douyin-downloader（JJ）、Johnserf-Seed/f2（F2）、jackwoo725-ux/douyin-downloader（JW）。JJ 当前 CLI 明确失败仍纳入，因为它提供现行入口和失效证据；JW 七月新项目维护证据较弱，但有实际本地 Dart 图文控制流和 MIT。

## Route A — Web detail

**采用数 4：DL、UC、JJ、F2。** 都把单个作品数据最终映射为 `aweme_detail` 与图片字段，endpoint 为 `https://www.douyin.com/aweme/v1/web/aweme/detail/`。未发现另一个可达的 note/slides 专用主接口。

- DL：[固定源码](https://github.com/DLWangSan/douyin_parse/blob/0896c74d1e9368af8ad0b85449a8039b1b3010bd/douyin_video_parser.py#L177)，`get_aweme_detail` → Web detail → A-Bogus 优先、X-Bogus fallback（约 177–230），图文类型及数组（234+）。共享同一 detail 路径，没有 Share SSR gallery fallback。A signer 对象缺失会提前退出，不能把 X fallback 当完全独立匿名方案。
- UC：[固定源码](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/src/parsers/douyin_parser.py#L823)，明确 note/slides 分支 **Web detail → Share SSR**，跳过 Mobile Feed。`_try_share_ssr_detail` 注释称“重试之前”，实际图文控制流却在 Web 请求失败之后；以控制流为准。
- JJ：[固定源码](https://github.com/jiji262/douyin-downloader/blob/9874f413b2c1f8ad6e731b26e3e05f402fc964f8/core/api_client.py#L906)，`get_aweme_detail` → `_request_json_gated` → HTTP signer 或注入 page bridge。当前[README](https://github.com/jiji262/douyin-downloader/blob/9874f413b2c1f8ad6e731b26e3e05f402fc964f8/README.md#L35)明确单视频/图片 CLI 被验证阻断，不能计为当前 CLI 可用成功。公开树没有注释中的 `core/page_bridge.py`，不能仅凭注释把桌面成功或其实现细节当已审计。
- F2：[handler](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/f2/apps/douyin/handler.py#L390) → `PostDetail` → [crawler](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/f2/apps/douyin/crawler.py#L221) → signed `POST_DETAIL` → `PostDetailFilter.images/images_video` → gallery downloader。当前默认开发分支不是稳定发布证明。[GatewayHeaderManager](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/f2/apps/douyin/utils.py#L611)添加 `x-tt-argus` 占位值，并按 Cookie 提取 UIFID；其注释的“实测”不是本轮复现。该占位策略及生成浏览器指纹不采用。[Issue 443](https://github.com/Johnserf-Seed/f2/issues/443)仍 Open，标记开发分支修复待发布，不能据此宣布稳定版已恢复。

### 共同依赖矩阵：代码携带 ≠ 服务端必需

| 条件 | DL | UC | JJ | F2 | 共识与边界 |
| --- | --- | --- | --- | --- | --- |
| Cookie/session | 可选 Cookie 文件 | 用户/Session Cookie + ttwid fallback | cookies + aiohttp session | 配置 Cookie 注入 crawler | 4 有会话能力；不是 4 证明必须登录 |
| ttwid | Cookie 透传，未专门要求 | 主动获取/缓存/固定 fallback | Cookie 透传 | TokenManager 可生成，detail 不单独调用 | 非统一明确硬门槛；固定 fallback 不采用 |
| UIFID | detail 无显式处理 | 有值时 header + query | query 默认空；bridge 注释 SDK 补 | Cookie UIFID 或 UIFID_TEMP → header | 3 处理/承认，不是共同必需证明；无合法初始化共识 |
| msToken | detail query 未显式添加 | signer 生成后追加 | Cookie 或获取后追加 | BaseRequestModel 按需获取/缓存 | 3 显式使用，来源不同；不能复制随机 fallback |
| A-Bogus | 优先 | 当前 detail 路径 | 优先，有依赖才启用 | 默认配置 ab | 4 使用，是最强 signer 收敛 |
| X-Bogus | A 失败 fallback | 存在 signer 工具，当前 note 请求非 X 路径 | A 不可用 fallback | 配置替代 A | 3 备选，不需 A+X 同时携带 |
| x-secsdk-web-signature | 无显式处理 | UIFID 可用才本地追加 | bridge 注释声明 SDK 补；实现缺失 | 本次 detail 链未见 | 不是 4 个项目共同条件 |
| x-tt-argus | 未见 | 未见 | 本次公开 detail 链未见 | 固定占位值 | 单项目 workaround，不采纳、不实验 |
| Referer / UA | desktop UA + note/video Referer | Web UA + note Referer | Web headers | conf Web headers | 4 使用；具体浏览器版本不一致，也无服务器必要性消融 |

当前真实可用性仍有缺口：MediaFlow 旧 baseline 有明确 Argus 403；JJ 承认 CLI 阻断；F2/UC 有更新应对门禁；DL 旧维护说明不能证明九月图文成功。结论是同一入口持续被维护，工程上应实现合法 session/signature 边界并验证，而非声称组合字段即可绕过拒绝。

## Route B — Share SSR

**采用数 2：UC fallback、JW primary。** HTML 嵌入数据的本地提取，不执行页面 JavaScript，不属于 Browser Observation。

- UC `fetch_html_content`（104–146）把普通作品包括 note 改写为 `https://www.iesdouyin.com/share/video/<id>`；附移动 Web UA、Referer、ttwid/Cookie、可选 UIFID。`_parse_ssr_data`（624+）支持 `__UNIVERSAL_DATA_FOR_REHYDRATION__`、URL 编码 `RENDER_DATA`、`_ROUTER_DATA`、`_SSR_DATA`、`__INIT_PROPS__`；递归提取 `videoInfoRes.item_list` / `aweme_detail` / `itemStruct`，并比对目标 ID。随后图片数组可含 `image_post_info`。这些是当前可达代码能力，不证明所有模板当前都由服务器发送。
- JW [Dart 主入口](https://github.com/jackwoo725-ux/douyin-downloader/blob/fa02b75823ed6137879dbf8dd4392dcc34c852b1/app/lib/douyin.dart#L68)：share → iteminfo；[SSR 路径](https://github.com/jackwoo725-ux/douyin-downloader/blob/fa02b75823ed6137879dbf8dd4392dcc34c852b1/app/lib/douyin.dart#L178)依次 `iesdouyin/share/video`、`share/slides`、`share/note`。`_ROUTER_DATA` 对象/字符串解码 → `item_list/aweme_list/aweme_detail/aweme` 或递归对象 → `images[*].url_list`。Dart 无 Cookie provider；Python 可选 DOUYIN_COOKIE。源码确实处理 gallery，但提交说明只声称真实**视频**验证；[测试](https://github.com/jackwoo725-ux/douyin-downloader/blob/fa02b75823ed6137879dbf8dd4392dcc34c852b1/backend/test_douyin.py)是合成图片 fixture，不是当前图文 live response。
- JW `findItem` 不严格匹配目标 ID，不能用它返回第一个作品就算目标成功；MediaFlow 必须精确校验。JW 固定 iPhone OS/Mobile Build、UC 固定 Android 手机/Build UA 均未被本轮照用。
- `share/note`、`share/slides` 是 JW 当前实际循环中的路径，不能一概称旧 README；但 MediaFlow 已有匿名阴性记录，本轮不重复。PC `/note` / `/video` 路由壳不等于 SSR 数据源。未发现第三种当前分享页图文入口的独立成功证据。

**Share SSR 当前判断：有活跃代码，尚无本轮可复现的图文成功。** 新路径一次 generic-UA 请求只是 302，不能证明所有 UA/session 下 SSR 永久失效，也不能证明绕开 Argus 后就有 images。它不足以提升为主候选 H1。

## Route C — Mobile / other direct API

- Gallery Mobile Feed **0 个可达主实现**；UC Feed 是视频路径。已关闭，不再请求。
- JW 的旧 `https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids=<id>` 当前仍可达 fallback（1 项目），但 MediaFlow 已测空正文；README “可用”不能覆盖该阴性记录。不重复。
- F2 api.py:46 声明 `.../web/api/v2/aweme/slidesinfo/`。在本轮检查的 handler/crawler/model/filter/dl/utils gallery 链中没有调用，单作品图文仍走 POST_DETAIL。**定义常量不是正在使用的新 gallery endpoint**，不符合真实请求条件；不做 probing，不断言整个仓库所有历史分支都未用过。
- 未发现可达且有当前 gallery 数据来源证据的 note detail、image post detail、GraphQL 或新 share JSON API。用户列表/search 等其他业务 API 不当成目标作品的新主入口。

## Route D — Browser / JS extraction

本次五项目中 **0 个源码完整且证明 Browser extraction 为 gallery 唯一主路线**。DL 的 Playwright 是可选登录 Cookie 获取；JJ 是注入页面发 Web detail 请求的签名/context 通道（完整实现不在公开树），不是发现独立 DOM gallery 数据源；F2 有 Cookie 获取相关工具，不改变 detail 主入口；UC/JW SSR 是 HTML JSON 解码。不能选择 H4；不运行 Browser。

## Route E — Other / server fallback

JW Python `HYBRID_API_BASE /api/hybrid/video_data?url=...` 是可选外部/自部署服务 fallback（1 项目），Dart App 没该步骤。它不暴露当前所依赖服务的 gallery 解析控制流，不是独立 endpoint 成功证据。MediaFlow 不使用，不请求，不上传链接。

## 同一组 19 项问题

“无”指所审计 gallery 链未见；“可选/条件”不等于必需；所有当前运行成功均未独立复现。

| 问题 | DL | UC | JJ | F2 | JW |
| --- | --- | --- | --- | --- | --- |
| 1 图文识别 | /note，返回类型 2/68 或 images | note/slides/share 路径 is_note | note/gallery/slides 判 gallery | /note ID；返回 aweme_type/images | note/share-slides/share-note ID，images 非空判图文 |
| 2 aweme_id | URL/query，短链 Location/HTML fallback | UrlParser 末段/modal_id | URLParser regex，短链解析上游 | redirect final video/note/vid regex | URL/query/数字 ID，短链最终 URL |
| 3 主数据入口 | signed detail | signed detail → SSR | gated detail | signed detail | Share SSR → iteminfo；Python 另有 hybrid |
| 4 endpoint | Web detail | Web detail + ies share/video | Web detail | Web detail | ies share/{video,slides,note}；iteminfo |
| 5 Web detail | 是 | 是 | 是 | 是 | 否 |
| 6 share SSR | 非 gallery 路线 | fallback | 非 gallery 路线 | 非已审计单作品路线 | primary |
| 7 移动接口 | 无 | Feed 仅视频，gallery 跳过 | 无 | slidesinfo 常量非该调用链 | 旧 iteminfo fallback，非 Mobile Feed |
| 8 Cookie/session | 可选 | ttwid/用户/Session | Cookie session | 配置 Cookie | Dart 无；Python 可选 |
| 9 A-Bogus | 优先 | detail 是 | 优先 | 默认 ab | 无 |
| 10 X-Bogus | fallback | gallery detail 非当前路径 | fallback | 配置可选 | 无 |
| 11 UIFID | 无显式 | 可用时附带 | 空参数/bridge 注释 | Cookie UIFID/TEMP header | 无专门处理 |
| 12 其他签名 | 未见 | 条件 secsdk | bridge 条件 secsdk 注释 | Argus 占位头不是正常 signer | 无 |
| 13 页面 JS 取数据 | ID HTML 搜索，非 gallery 数据源 | 嵌入 JSON 静态解析 | bridge 执行 SDK 发 API（实现缺失） | 非单作品 gallery 数据源 | 静态嵌入 JSON，不执行 JS |
| 14 浏览器 | 可选登录工具 | 非 gallery 主调用 | 可注入桌面 bridge | Cookie 工具/配置与请求链分离 | 无 |
| 15 图片数组 | aweme_detail.images，url_list/嵌套图 | image_post_info.images/image_list；images/image_list/image_infos/original_images | image_post_info.images/image_list；images/image_list | aweme_detail.images[*].url_list[0] | images[*].url_list；不支持 image_post_info fallback |
| 16 Live Photo | live_photo_type/clip_type/video/动态 URL | images.video / video_play_addr / video_download_addr → live_photo_url | gallery item.video 各 play_addr / video_play_addr 等 | images[*].video.play_addr.url_list[0] → images_video | 未见专门 Live Photo 提取 |
| 17 维护 | HEAD 8/14；parser 7/17；签名修复说明主要视频 | HEAD 9/28；parser 9/25；gallery 分支现行 | HEAD 9/22；API 9/16；明确 CLI limitations | HEAD 9/27；utils 9/26；网关修复待发布 | HEAD/parser 7/9；新项目，只有视频真实验证说明 |
| 18 License | 缺 LICENSE；README MIT 不能消除 signer 来源风险 | 根 MIT；signer 子文件限制待核实，既有审计记录风险 | 根 MIT；复用 signer 需模块来源审计 | 根及 abogus.py 头 Apache-2.0；进一步依赖/来源审计仍需 | 根 MIT |
| 19 本地化 | 思路可参考；不复制指纹/高风险 signer | 路线可本地；去掉不合规重试/固定状态/UA | HTTP 可本地，桌面 bridge 不共用 Android | detail 边界可本地；不采用 Argus 占位/生成指纹 | Dart HTTP 可五端抽象；当前 gallery 可用未证实 |

DL SHA `0896c74d1e9368af8ad0b85449a8039b1b3010bd`；UC `ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6`；JJ `9874f413b2c1f8ad6e731b26e3e05f402fc964f8`；F2 `a30feaf92a40f421273b01b6ef36aa83a93f63c0`（默认分支 v0.0.1.8-pw3）；JW `fa02b75823ed6137879dbf8dd4392dcc34c852b1`。更新时间为 UTC，非 gallery 成功时间，HEAD 的文档更新不等于解析修复。

## 路线评分与决策

| 路线 | 当前代码项目数 | images | 登录 | signer | 跨平台 | 稳定性 | 成本 | MediaFlow 适配性 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A Web detail | 4 应用控制流 | 4 有字段处理；本轮成功未验证 | Cookie/context 普遍支持，账号必要性未证实 | A 收敛；X/secsdk 条件不同 | HTTP/算法可共用；session 需 Adapter | 平台网关变动风险高，但持续维护最强 | 中高 | **最高，H2**；合法状态来源与安全停止是门槛 |
| B Share SSR | 2 | 代码可取；当前目标未取得 | JW Dart 无；UC 带状态；必要性未知 | SSR 提取无 bogus | HTTP+JSON 可共用 | HTML/UA/跳转变化；当前 gallery 成功缺证 | 低中 | 不提升为主候选；不继续匿名变体搜索 |
| C direct other | iteminfo fallback 1；slidesinfo 可达 gallery 0 | 旧字段/常量，没有新当前成功 | 不明 | 不明 | 理论 HTTP 可共用 | 旧 iteminfo 已空；新入口未发现 | 看似低但实效不足 | 不采用 H3；Feed 保持关闭 |
| D Browser/JS | 完整独立主提取证据 0 | 未证明唯一可用 | 状态提供可需用户登录 | 页面 SDK 可代发 detail | 五端 Adapter 成本高 | 浏览器/SDK/生命周期风险 | 高 | 不符合 H4 条件；仅未来 provider |
| E remote fallback | 1 可选 | 依赖服务声称 | 依赖服务 | 依赖服务 | 网络服务本身跨端 | 不可控 | 与项目目标冲突 | 排除 |

H2 的理由不是“4 大于 2”：A 有持续维护的可达 gallery/Live Photo 数据映射与一致接口，B 无当前 gallery live proof 且新一次响应无数据，C 无真正新调用链，D 缺唯一性证据，E 违反本地/零服务器约束。因此结束本轮入口搜索，进入合法 session + license-safe signer + detail 的设计；不按单项目照搬参数包，不使用 F2 占位头，不重放他人凭据，不合成浏览器/设备身份，不尝试通过明确安全拒绝。

## 真实请求

资格：UC 与 JW 当前代码实际请求 iesdouyin share/video，而 MediaFlow 历史主要测 share/note/slides，未测此确切路径。本轮使用诚实 `MediaFlow/0.4.0` UA，不严格复现任一参考设备/Build UA；仅检验通用匿名响应。

2026-09-28T12:21:00.109839Z，GET `https://www.iesdouyin.com/share/video/7690029886242009957/`：**302**, `text/html; charset=utf-8`, **183 bytes**；目标 ID 文本存在，script=0，JSON roots=0，目标 aweme 对象=0，图片字段=0；五种命名 hydration marker 均=0。无 Cookie/Token/signer/proxy，自动跳转关闭，未跟随跳转。Location 未记录，不能推断最终目的页面。原始正文未落盘；仅保存脱敏统计 `poc/horizontal-share-video-once.json`。一次请求额度消耗 1，剩余额度未用，不再追加。

该结果不是完整 SSR fallback 复现，也不证明所有合法会话都无 SSR。仅证明本轮新路径的通用匿名首响应未提供 gallery 数据。历史所有关闭入口继续关闭。

## 交付、验证与风险

- 修改：`v0.4.0/README.md`、`v0.4.0/research/README.md` 追加最新索引；没有修改 AGENTS.md。
- 新增：本报告、`douyin-gallery-horizontal-sources.json`、`poc/horizontal-share-video-once.json`；删除：无。
- 核心实现逻辑：研究记录按入口聚类 + 同组问题 + 来源清单；没有产品实现。本轮仅设计/控制流参考，**无第三方代码复用**，无需新增 attribution；以后实际复用必须单独审计模块许可及依赖。
- 新依赖：无；运行临时请求统计脚本用本机 Python 标准库，不引入产品运行时。
- 自动化 tests / Flutter analyze / lint / Windows build / Android build：**未运行**，本轮没有 Dart/Flutter production 变化。临时 one-shot Python `py_compile` 通过；这不是 gallery 功能测试。
- 文档/清单核验：五项目 SHA/许可证/源文件 hash 清单齐全；结果 JSON 可解析；19 项问题、5 类路线、单一 H2 决策已记录。`git diff --check` 通过（只覆盖 tracked 修改）；新增研究报告另检查空白/JSON。
- Windows：实际运行本轮 HTTP/源码审计；不代表应用图文验收。Android：未安装、未构建、未真机测试；iOS/macOS/Linux：未构建、未实测。
- 真实场景：1 次 HTML GET 未取得目标图片；图片资源 URL 可访问性、图文/Live Photo 完整性、下载、安全 session 初始化与 signer 正确性均未验证。
- 已知风险：活跃源码可能仍失效；共同控制流不证明状态必要性；许可要按模块来源核查；合法 context 获取可能遭安全停止。H2 不承诺既有会话入口能恢复，也不授权绕过门禁。
- Git 写操作：无 commit/push/merge/tag/stage/reset；HEAD/branch 不变。
- `git diff --stat`：既有 `AGENTS.md | 31 +23 -8`，共 1 tracked 文件。整个 v0.4.0 未跟踪，所以普通 stat 不包含本轮研究文件；不能把它说成工作区干净。

## 【项目目标兼容性检查】

| 平台 | 本轮状态 | 后续 H2 风险/路径 |
| --- | --- | --- |
| Windows | 已实际测试研究 HTTP；产品图文未测试/未构建 | 自有 profile provider + 公共 detail/signer；不得重启旧 Observation |
| Android | 未实际测试、未构建、未安装 | 同等验收；自有 WebView/session Adapter，不绑定 Electron/Windows |
| iOS | 理论兼容，未构建/未实测 | WKWebView/安全存储 Provider 与本地 HTTP/signer 需验证 |
| macOS | 理论兼容，未构建/未实测 | 平台 Provider 生命周期待实现；参考 Dart 项目支持声明不是 MediaFlow 验收 |
| Linux | 理论兼容，有平台 Provider 风险 | 浏览器运行时/安全存储选择待确认，不引入核心系统 API 耦合 |

| 目标/模块 | 本轮核查与后续约束 |
| --- | --- |
| Bilibili | 本轮未改其源码，未回归；以后 ParserService 契约变更须回归 |
| Douyin | 仅研究路线决策，gallery production 仍 BLOCKED/NOT VERIFIED |
| Xiaohongshu / YouTube / X / Instagram / 其他未来平台 | 未实现/未测试；session/signing 应平台隔离，不制造公共 if-platform 分支 |
| PlatformDetector / ParserService / UI | 没有本轮代码变更；后续仅经稳定 Application/Domain 接口调用 |
| Parser / Adapter / Browser Adapter | H2 detail 与 provider 分离；Browser 只提供合法本地状态，不作为主观察解析器 |
| Unified Content Model / MediaContent / MediaResource | 不带 Cookie/Token；图集保留顺序、重复位置、静态图与 Live Photo 成对，不能复制 set 去重 |
| Downloader / Media Processing | 本轮未下载/处理；未来只接资源元数据/受控上下文引用，平台协议留在 Adapter |
| History / Settings / Logging / 本地存储 | 本轮仅公开源码与脱敏响应统计；后续会话不得进入历史、公共日志、Crash report |
| 隐私 / 本地处理 / 零服务器 | 仅向所属平台一次受控匿名请求；无远程解析/同步/媒体上传，JW hybrid 不采用 |
| 第三方依赖 / 安装包体积 / 性能 | 产品依赖未新增、无包体性能测量；未来 JS/crypto 运行时不能默认引入，需五端/体积评估 |
| 后续维护 / 正式发布 | Web detail 风控/签名更新风险明确；合法 provider 与 signer 未工程化，不能标记 v0.4.0 gallery 正式完成 |

完成后暂停；下一轮只做 H2 工程设计，不继续本轮入口或匿名实验。
