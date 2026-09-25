# 第八阶段：抖音图文匿名入口调查（2026-09-24）

状态：**阻断；未接入 production Parser；未确认任何作品的真实图片数量、顺序或 MIME。** 本记录只含公开作品 ID、请求结果和响应结构摘要；不保存响应正文、媒体 URL、Cookie、Token 或会话数据。

## 现有代码基线

- `DouyinParser` 现按单视频处理。页面 SSR、匿名移动 feed、Web detail 和可选 Browser Observation 都要求最终得到视频 URL，成功时返回 `ParserSuccess(VideoInfo)`。`_extractVideoId` 仅识别 `/video/<id>` 或 `modal_id`；`/note/<id>` 尚无独立图文分支。
- `DouyinMobileFeedSession` 使用无 Cookie 的本地 `HttpNetworkClient` 请求 `api5-normal-c-hl.amemv.com/aweme/v1/feed/`，要求 `aweme_list` 中恰有一个目标 ID、作者及视频地址；目标不存在时返回 `targetMissing`。这是已发布的视频路线，不能为图文直接放宽它的既有合同。
- `DouyinDetailSession` 有平台下发、限时且仅内存使用的匿名 Cookie 逻辑。本轮图文探测**没有调用它**；只对同一官方 detail URL 发起不带 Cookie 的有限请求。既有视频行为未修改。

## Windows 匿名探测

工具：`tool/v030_douyin_gallery_probe.dart`，复用仓库 `HttpNetworkClient` 和现有 feed session。每个候选只做有限探测；工具只输出状态、结构键和布尔字段。

| 公开候选 ID | 来源 | feed 目标 | `/note/` 页面 | 移动分享页 | 无 Cookie Web detail |
| --- | --- | --- | --- | --- | --- |
| `7384081802173943076` | [公开样本链接所在页面](https://ksh7.com/posts/wl-dy-parse/index.html) | `targetMissing`，HTTP 200 JSON | HTTP 200，但含安全验证标记，无目标 ID/图片字段 | `/share/video/`、`/share/note/` 及 `m.douyin.com/share/note/` 均为路由壳，只有 `itemId` 等路由参数，无 `videoInfoRes`、`images`、`image_post_info` | HTTP 403 |
| `7298193217713933595` | [公开抖音页面的 note 链接](https://www.douyin.com/video/7298193907966332186) | `targetMissing`，HTTP 200 JSON | 同上 | `/share/video/` 为路由壳，未得到图片 | HTTP 403 |
| `7616399587141737704` | [media-parser 的公开样本表](https://github.com/ucmao/media-parser/blob/main/tests/live_parser_samples.json) | `targetMissing`，HTTP 200 JSON | 同上 | `/share/video/`、`/share/note/` 为路由壳，未得到图片 | HTTP 403 |

对照：既有视频 ID `7682375032253180345` 经同一 feed 两次均匹配目标，包含视频字段。这说明探测器能观察到现有视频成功路线，但**不能证明**三个 note 候选仍公开、仍为多图作品，或其图片 URL 能匿名访问。移动分享页中的 `itemId` 只是路由参数，不能算作品媒体数据。验证码、403 和目标缺失均为安全停止条件；没有请求验证码解法、登录凭据或第三方解析服务器。

## Android 状态与决策

本轮 `adb devices` 没有列出设备，PJZ110 / Android 16 未能独立执行匿名网络探测或真机 GUI 验收。未构建或安装 APK，未触碰设备已有应用。即使 Windows 获得单个样本，也必须在 Android 取得同等匿名访问、资源 URL 和 MIME 证据后才可接入 production。

目前没有取得一个由 MediaFlow 自身确认的 2 张以上真实抖音图片作品。故不修改 `DouyinParser`、`ParserService`、图文 GUI、Downloader 或 History，不建立以第三方字段猜测驱动的生产分支。

## 第三方资料与取舍

- [ucmao/media-parser](https://github.com/ucmao/media-parser)，[MIT License](https://github.com/ucmao/media-parser/blob/main/LICENSE)：文档将 `image_post_info.images` / `image_post_info.image_list` 与顶层 `images` 列为图集字段，提出移动分享页 SSR 备选，并在样本表列出上述 note ID。项目包含 Web 服务与部分场景的登录 Cookie/签名路线；MediaFlow 仅将其字段和样本当研究线索，**未复用代码、未调用其服务**。在本机匿名实测中该样本的分享页未返回媒体数据，第三方“已验证”不能转为 MediaFlow 验收结论。
- [DLWangSan/douyin_parse](https://github.com/DLWangSan/douyin_parse)：README 声称 MIT License，但未核实到独立 LICENSE 文件，若将来考虑代码复用须先核实许可证。其代码说明 `aweme_type` 与 `images` 可用于区分视频/图集；签名、自动 Cookie 等路线与本阶段边界不合。仅作字段交叉参考，**未复用代码或算法**。

如果后续取得可公开访问的样本，应先记录目标 `aweme_id`、`aweme_type`、实际 `images`/`image_post_info` 结构、每个出现位置的候选图片、匿名 GET/MIME/扩展名及明显时效参数，再在 Windows 和 Android 使用同一独立探测合同验证。一个逻辑图片对应一个资源；资源 ID 按出现位置生成，不按 URL 去重。若再次遇安全验证或权限限制，应停止该入口。

## 第九阶段：指定开源项目请求链复核（2026-09-24）

以下是**源码或仓库文档给出的线索**，不是 MediaFlow 的实时成功结果。公开仓库可能随时改变；凡未读到对应源码的细节均标为“未核实”。本阶段没有复制代码、算法、正则或测试数据到生产实现。

### 路线矩阵

| 项目 / 许可 / 维护线索 | 实际入口与图文字段 | 身份、签名与环境 | MediaFlow 判断 |
| --- | --- | --- | --- |
| [DLWangSan/douyin_parse](https://github.com/DLWangSan/douyin_parse)，README 声称 MIT，仓库根目录未见独立 LICENSE；README 列 2026-07/08 更新 | [解析源码](https://github.com/DLWangSan/douyin_parse/blob/master/douyin_video_parser.py)：`/note/<id>` 或短链重定向提取 ID → `GET https://www.douyin.com/aweme/v1/web/aweme/detail/` → `aweme_detail`；`aweme_type` 2/68 或存在 `images` 判图集，取顶层 `images`，LivePhoto 检查图片内 `video` 等标记。没有把 `image_post_info` 当该实现主入口。 | query 含 `aweme_id`、`aid=6383`、`device_platform=webapp`、`channel=channel_pc_web` 及一组固定 PC 浏览器参数；UA 固定 Chrome 130，Referer 按 `/note/` 或 `/video/` 选；先 A-Bogus 后 X-Bogus。代码中 Cookie 是有值才加请求头，但 README 的正常使用流程要求登录 Cookie，**不能由可选分支推断匿名实际可用**。无外部解析服务器；完整版本用 Playwright 获取登录 Cookie。 | 详情入口和字段可参考；固定设备参数、登录 Cookie 路线不采用。签名可研究但缺少无 Cookie 成功证据。 |
| [zhanghoude/resource-resolve](https://github.com/zhanghoude/resource-resolve)，仓库有 [Apache-2.0 LICENSE](https://github.com/zhanghoude/resource-resolve/blob/main/LICENSE)，主页显示 11 commits | 仓库说明 `src` 有实现，要求 Java 17、ChromeDriver，声明 Selenium 浏览器采集抖音等。当前源码子目录无法通过研究环境读取，**具体 endpoint、query、Cookie、图片字段、LivePhoto 未核实**。 | 浏览器环境必需；是否登录、是否依赖浏览器匿名 Cookie 未核实。README 未声明第三方解析服务器。 | 是 Browser Adapter 方向的线索；不能声称存在与上一项目不同的详情 API。 |
| [ta867070117/video-analyse](https://github.com/ta867070117/video-analyse)，仓库没有看到 LICENSE 文件，2026-09-16 更新接口文档 | 仓库根目录只有 README，展示其远程 API 的 `type=2`、`pics[]`、`cover`、`videos[]` 返回结构和样例 CDN URL，**没有平台请求与解析源码**。 | 调用 `proxy.layzz.cn` 需要 token 且上传作品链接。 | **仅参考公开返回结构和样本，不将其远程 API 接入 MediaFlow。** 样例图片带 `x-expires`/`x-signature`，且样例未给作品 ID，不能用于当前作品验证。 |
| [kemomi/bilibili-freevoice](https://github.com/kemomi/bilibili-freevoice)，未见 LICENSE 文件；仓库为 README 加用户脚本 | 用户脚本围绕会员、地区、第三方视频解析等；没有核实到 Douyin 图文详情源码。 | 浏览器扩展/用户脚本，部分能力与项目访问控制边界冲突。 | **已调查，但对本轮 Douyin gallery 数据入口帮助有限，未采用。** |
| [ucmao/media-parser](https://github.com/ucmao/media-parser)，[MIT](https://github.com/ucmao/media-parser/blob/main/LICENSE)；近期文档仍更新 | [实现说明](https://github.com/ucmao/media-parser/blob/main/docs/parsers/douyin.md)列 `image_post_info.images` / `image_list`、顶层 `images`、分享页 SSR 和 Web detail；LivePhoto 指向 `images[i].video.play_addr`。 | 普通图文宣称可匿名 SSR；LivePhoto 完整数据说明要求登录 Cookie、UIFID、SecSDK。它是 Web 服务实现，MediaFlow 不调用其服务。上一阶段其公开 note 样本在本机只得到路由壳。 | 字段交叉线索；匿名 SSR 需要 MediaFlow 自行复证。UIFID/登录路线不采用。 |
| [qgeng1465/douyin-watermark-free-downloader](https://github.com/qgeng1465/douyin-watermark-free-downloader)，README 声称 MIT；近期可检索 | README 声称图文可由 requests、无签名/浏览器/登录解析；本阶段未核实到请求源码与成功响应。 | 匿名声明，真实 endpoint 和 Cookie 未核实。 | 候选独立思路，不能当作已验证路线。 |
| [vacacia/astrbot_plugin_link_resolver](https://github.com/vacacia/astrbot_plugin_link_resolver)，许可未核实 | README 声称支持无 Cookie 图文与 LivePhoto；实际请求源码未核实。 | 身份、签名、服务器依赖未核实。 | 仅作为字段线索，不采信成功声明。 |

### `douyin_parse` 可确认的完整调用链

分享文本 URL → 正则匹配 `/note/<数字>`、`/video/<数字>` 等；短链则 GET 跟随重定向，必要时从 HTML 找 ID → 复制 `BASE_PARAMS` 并加入 `aweme_id` → 按原链接选 `/note/{id}` 或 `/video/{id}` Referer → 用 A-Bogus 签完整 query → GET Web detail；若无有效 `status_code=0` 且有 `aweme_detail`，改用 X-Bogus 再 GET → 按 `aweme_type` 或顶层 `images` 分流 → 遍历 `images` 的 URL 与 LivePhoto 字段。关键源码：[解析与请求](https://github.com/DLWangSan/douyin_parse/blob/master/douyin_video_parser.py)、[A-Bogus](https://github.com/DLWangSan/douyin_parse/blob/master/abogus.py)、[X-Bogus](https://github.com/DLWangSan/douyin_parse/blob/master/xbogus.py)。该链**只能证明实现方式，不能证明本机无 Cookie 成功**。其 README 要求用户登录 Cookie，且固定 `Windows/Win32/Edge` query 与 Chrome UA 不一致，不适合直接移入五端客户端。

### 签名与边界

- **A-Bogus**：该项目的主接口接受 query 字典或字符串、HTTP 方法、时间与随机数；实现含哈希/RC4，Python 本地计算，不需要浏览器 JS 或账号作为算法输入。[源码](https://github.com/DLWangSan/douyin_parse/blob/master/abogus.py)。理论上可独立写 Dart 并在 Windows/Android 运行，但请求能否只凭签名通过当前网关**未验证**，也不能复制其无独立 LICENSE 的实现。
- **X-Bogus**：接口接受 URL/query 与构造时的 UA；实现可本地运行，无 JS 引擎。[源码](https://github.com/DLWangSan/douyin_parse/blob/master/xbogus.py)。它只是 A-Bogus 失败后的备选，匿名成功尚无证据。
- **SecSDK / UIFID**：[media-parser 文档](https://github.com/ucmao/media-parser/blob/main/docs/parsers/douyin.md)将 LivePhoto Web detail 完整取数与登录 Cookie、UIFID、`x-secsdk-web-signature` 联系在一起。签名可计算不等于 UIFID 可由匿名、短期、无身份会话合法取得。依赖用户登录 Cookie/UIFID 的具体路线**不符合当前匿名、本地、隐私边界**；遇 403 或安全验证应停止。

### 新候选、独立 PoC 与未取得的证据

- 新候选：[公开帖子引用的 `https://www.douyin.com/note/7659275356428852849`](https://www.reddit.com/r/RevengedLoveCP/comments/1uoqet7/20260706_ziyu_studio_weibo_update_douyin_photos/)（2026-07 图片帖）。它是一个**待确认的公开图文候选**，目前未由 MediaFlow 确认仍可访问、图片数或是否 LivePhoto。README 中的 `7341234567890123456` 是占位 ID，不能作样本。`video-analyse` 的返回样例没有作品 ID。
- Windows：尝试 `dart run tool/v030_douyin_gallery_probe.dart 7659275356428852849` 和 `dart tool/v030_douyin_gallery_probe.dart 7659275356428852849`，两次都超过 60 秒且**没有任何输出**，主动终止；随后 `dart --version` 也超过 10 秒无输出。这表明本轮 Dart 命令启动/运行环境阻断了实测，不能归因为平台返回或候选失效。既有探针没有写出 Cookie、Token 或响应正文。
- Android：`adb devices` 为空，未构建、安装或替换设备应用；applicationId、已有安装、签名状态均未核实。按照真机安全规则不执行安装。
- 本阶段没有自己的 `aweme_detail` 响应，故 `aweme_type`、`images`/`image_post_info`/`image_list`、作者、图片数/顺序/尺寸/MIME、两个图片 URL 的匿名 GET/HEAD、LivePhoto 视频均**未验证**。不把第三方字段当作实时平台事实。

**优先候选**：一是既有匿名分享页 SSR/Browser Adapter 对新真实 note 样本做有界观察；二是仅在无用户 Cookie/UIFID、无挑战条件下验证 Web detail + 本地 A-Bogus 或 X-Bogus。两者均需 Windows 与 Android 自身取得同一作品的结构化数据和至少两张可匿名下载图片后，才可考虑 production。

**本阶段结论：仍未能独立复现。** 没有改 production Parser；不能据此宣布 Douyin 图文可上线。

## v0.3.0 范围决定

**`v0.3.0 researched but not production-supported`。** 已进行匿名数据入口和第三方实现研究，但当前未取得 Windows + Android 双端独立匿名验证，故 v0.3.0 不接入 production，也不作为本版 Release 阻断项。本版 Release 只回归 Douyin 视频；以后若有新的匿名双端证据，再重新评估图文。此决定不把研究、PoC 或 Debug 结果表述为正式支持。
