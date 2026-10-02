# 第二阶段：成功项目对照与采用边界

核查日期：2026-09-30。这里的“源码可验证”表示已阅读固定 commit 的链路；不能替代当期下载成功。最近提交、Releases、Issues、license 原始证据见 `reference-project-evidence.json`，逐文件 URL、commit、SHA256 见 `reference-source-index.json`，Dart 发布证据见 `youtube-dart-package-evidence.json`。

## YouTube

| 项目 | 当前状态 | 技术入口 | 匿名 | Runtime | JS/Challenge | Cookie/Session | 资源能力 | License | MediaFlow价值 |
|---|---|---|---|---|---|---|---|---|---|
| yt-dlp/yt-dlp | 9月27日提交；release 2026.08.19；本次运行因连接失败停止 | URL→ID→watch/player，默认 visionos/web→formats/adaptiveFormats→媒体 URL | 源码有匿名路径，本次未证明可用 | Python；可选 JS runtime | n/s player JS，EJS 与 PO-token provider；本次均不执行 | 支持匿名及账号 Cookie，本次无外部 Cookie | muxed/分离流，itag、codec、container、bitrate、宽高来自 player | 源码 Unlicense；打包程序另含 GPL/ISC/MIT 等 | 格式枚举、失败分类和资源选择参考；不打包 Python，不直接用默认客户端组合 |
| Tyrrrz/YoutubeExplode | 9月1日提交，6.6.2（8月25日）；NOT RUN / SOURCE VERIFIED | ID→sw.js_data visitor→VisionOS，Android fallback→player→StreamClient→URL | 有匿名源码路线，未实测 | .NET；本机无 SDK | player signature/cipher；TV fallback 带年龄限制相关策略，排除 | visitor 与可选会话；不能据此认定普通视频必须账号 | muxed/video/audio；字段来自 PlayerResponse | MIT | 清晰类型和 stream/download 边界；Flutter双端桥接成本高，不直接成为依赖 |
| TeamNewPipe/NewPipeExtractor | 9月27日提交，0.26.5（8月15日）；NOT RUN / SOURCE VERIFIED | URL→ID→VisionOS player+WEB metadata→ItagItem→streams | 有匿名路径，未实测 | Java/JVM；JS执行工具在库内 | YoutubeJavaScriptPlayerManager 处理 s/n；PoTokenProvider 当前NOOP，并非所有token问题已解决 | 正常客户端 context；不导入账号 | formats 为合流，adaptiveFormats 为音频/纯视频，itag补充格式属性 | GPL-3.0-or-later | 协议和架构参考；不复制GPL实现，不打包JVM；Android较自然，Windows成本高 |
| Hexer10/youtube_explode_dart | 5月9日commit；pub.dev 3.1.0同日；GitHub release仍2.5.0；本次Dart路径连接失败 | ID→WatchPage/Player→StreamClient→manifest；默认androidSdkless，空结果可TV | 有匿名路径，未证明当前双端下载 | Dart；可选Deno/EJS | 可选n/s solver；本次不启用；默认fallback不能自动采用 | WatchPage合成PREF/SOCS/GPS/CONSENT等；PoC绕开此方法，用普通页面观察的WEB context | 明确Muxed/VideoOnly/AudioOnly类；字段来自player | BSD-3-Clause | 最低共享语言成本；仅隔离PoC依赖，不能因Dart就宣布采用 |

**共同链路**：video ID → player 的 `videoDetails` / streamingData → `formats` 与 `adaptiveFormats` → itag、MIME/codecs、bitrate、width/height/quality → direct URL或cipher处理 →资源GET。发现流与下载选择分开；progressive覆盖、签名失效及媒体403必须当期验证。平台player JS的正常签名转换与安全挑战求解须分别评估。

NewPipe的 `utils/JavaScript.java` 当前直接使用 `org.mozilla.javascript.Context`（Rhino）解释执行signature/n函数；因此不是“完全不需要JS执行”的Java方案。该固定文件已补入source-index。

固定源码：[yt-dlp](https://github.com/yt-dlp/yt-dlp/tree/51bab8a0116f4d8004c315706d809782607d5847)、[YoutubeExplode](https://github.com/Tyrrrz/YoutubeExplode/tree/5d7f8343e73ee8361474a9113e983dce2e8af2f3)、[NewPipeExtractor](https://github.com/TeamNewPipe/NewPipeExtractor/tree/eb53b79e6242d52f0ee2c2614e04e5a9dc2b6a64)、[Dart库](https://github.com/Hexer10/youtube_explode_dart/tree/44a39a65d8e274806247d52af8f0bacd77691d38)。Issues里有6.6.2回归、VisionOS400、Dart媒体403及设备/网络限制报告；这是风险证据，不是本机复现。

## 小红书

| 项目 | 当前状态 | 技术入口 | 匿名 | Login/Session | Token/签名 | Browser | 视频 | 多图 | License | MediaFlow价值 |
|---|---|---|---|---|---|---|---|---|---|---|
| Andy-SoulShell/xhs-downloader | 7月28日commit，无release；NOT RUN / SOURCE VERIFIED | 分享/作品ID→带token的explore页→initialState目标note | HTTP读取路线存在；“免登录”能力未运行核实 | 私有same-origin HTTP Cookie或managed page session；检测登录页并报错 | detail输入含xsec_token；页面路径不直接调用X-S feed signer | Python/本地Chromium/CDP及TS扩展 | video.media.stream master/backup，另有originVideoKey派生 | imageList保持顺序；urlDefault/urlPre及原图CDN变换 | MIT | 平台Provider分层、目标校验和受限读取参考；不复制CDN签名变换/外部浏览器会话 |
| JoeanAmier/XHS-Downloader | 9月16日commit，2.8（9月12日）；NOT RUN / SOURCE VERIFIED | HTTP作品页→note info，或用户脚本推送已加载note→下载 | 无Cookie请求分支存在，不等于全部样本匿名可读 | 配置Cookie/脚本已加载页面；release移除外部浏览器Cookie读取 | 分享token上下文；所读下载链没有证明需X-S API | Python/curl_cffi；可选本地用户脚本WebSocket | originVideoKey或video.media.stream master/backup | 有序imageList，原图/格式URL变换 | GPL-3.0 | 资源来源、顺序、错误行为参考；不复制代码；verify=False路径及0.0.0.0脚本服务不采用 |
| xpzouying/xiaohongshu-mcp | 9月22日commit/release2.5.5；NOT RUN / SOURCE VERIFIED | ID+xsec_token→浏览器explore→window.__INITIAL_STATE__.note.noteDetailMap | 完整应用面向登录，匿名覆盖未证明 | 自有cookies.json；登录工具；不是必须外部Cookie | xsec_token/xsec_source；页面执行平台JS，所读detail不手动X-S | Go/Rod+自有Chromium；当前browser.go启用WithFingerprint，故不运行其完整默认浏览器 | 返回video.media.stream实际URL，含过期签名 | imageList数组，urlDefault/封面 | Apache-2.0 | 已加载页面读取与Browser Adapter边界参考；指纹配置排除；Windows已有发布，Android需重新Adapter化 |
| NanmiCoder/MediaCrawler | 9月19日commit；NOT RUN / SOURCE VERIFIED | 自有浏览器初始化/登录→签名POST /api/sns/web/v1/feed→note_card→media | 不从登录流程反推全部公开内容必须登录 | cookie_str输入签名；web_session变化作为登录判断 | X-S/X-T/X-S-Common/traceid，由xhshow算法；a1具体必要性本阶段未运行证明 | Playwright+登录上下文；含stealth组件，不运行 | API视频stream/sourceKey | API有序image_list，普通图/原图派生 | 非商业学习使用许可证1.1 | 仅协议条件、机制对照；不复制、不依赖、不迁移其反检测设置 |

固定源码：[Andy](https://github.com/Andy-SoulShell/xhs-downloader/tree/cc2bb34036acb12f5a722c95af7bad53ec696d03)、[Joe](https://github.com/JoeanAmier/XHS-Downloader/tree/3261312721f0b37c705ba6515885bc7f34349f2f)、[MCP](https://github.com/xpzouying/xiaohongshu-mcp/tree/a5c8f7799980ba1fdd501999843eb2d17e4c9a9f)、[MediaCrawler](https://github.com/NanmiCoder/MediaCrawler/tree/380b426000aac3d612837ed72c99808347dc94c9a9f)。MCP Issues包含登录检测/页面变化问题；版本发布不是当前样本成功证据。

**共同链路**：分享重定向给note ID及xsec_token → HTTP页面、API或已加载浏览器状态 → 目标note detail → `imageList`/`image_list`顺序、视频stream URL →下载。封面通常来自作品图片/cover字段；原图与普通图不能只凭尺寸或CDN路径认定。PoC仅使用实际返回URL，不改host、不去签名、不宣称已取得原图。

Joe完整HTML链已补齐：`app.py::_get_html_data` → `Html.request_url` → `Converter.run` → `Explore/Video/Image` →Download。`source/expansion/converter.py`明确包含PHONE_KEYS_LINK=`noteData/data/noteData`与PC_KEYS_LINK=`note/noteDetailMap/[-1]/note`，与Android真实移动页一致。初始PoC只处理桌面字段，移动页遗漏已修正；没有复制其GPL Converter/YAML解析实现，Dart使用自写JSON扫描及严格目标ID校验。

## 最小必要条件矩阵

| 条件 | 源码线索 | 本次验证状态 | 可接受的后续边界 |
|---|---|---|---|
| xsec_token | 分享链及Andy/MCP detail输入 | 分享重定向有该query键，值不持久化 | 只使用所属平台正常签发的目标上下文 |
| a1 | signer通常使用Cookie上下文；本次未核查xhshow全部依赖实现 | 必要性未验证 | 先逐字段来源/许可审计，再有界单变量实验；不合成身份 |
| web_session | MediaCrawler登录检查、MCP自有Cookie | 未使用/未证明必要 | 用户在App自有隔离profile主动登录，内部使用，不导出 |
| 匿名Cookie | Andy私有HTTP上下文；平台302有Set-Cookie | Level0忽略Cookie，无法据此判定Level1效果 | 生命周期、清除、隔离可验证后再试 |
| Browser/JS | Andy managed session/MCP读取已加载状态 | 本次未运行，正常Browser路线仍待验证 | 正常WebView2/Android WebView，不注入stealth或指纹 |
| X-S/X-T | MediaCrawler signed feed API | 未运行，不能解释普通302或403全部原因 | 本地正常签名可研究，安全拒绝后停止 |
| 第三方服务 | 已审计核心链条都是本地至所属平台 | PoC无解析服务器 | 不引入外部解析/日志/代理服务 |

## 实际采用与依赖评估

仅研究包依赖 `youtube_explode_dart 3.1.0`（BSD-3-Clause）、http、crypto及Flutter正常传递依赖，固定研究pubspec.lock。Dart核心五端有合理路径，但依赖 `dart:io` 的PoC不适用Web；Android保存/打开是独立Infrastructure。Deno solver模块存在于库内，本次不初始化、不打包Deno/Python/JVM/FFmpeg。正式依赖为零。

其他项目仅设计/公开数据结构参考，未搬运实现。GPL/custom代码不进入MediaFlow；MIT/BSD/Apache潜在复用仍需保留原版权/license/NOTICE并另行审批具体文件。source-index保留Repository/File/Commit/License关联及用途。本机现有Python仅用于审计和运行参考源码，缓存不进入发布包。

维护替代：StreamClient应藏在YouTube Adapter内，可替换为其他经过双端验证的本地实现；Browser接口与session保管独立。非官方API/player变化、签名失效、登录页差异和解码器差异需明确失败分类。当前不能把任何项目的源码路线写成已验证双端成功。

## 固定样本续跑对照补充（2026-09-30）

已有源码/提交/Issues/许可证审计继续作为设计证据，不能当成本环境运行成功。Dart研究依赖实际跑用户两个YT样本，尚受连接层阻断；Shorts分享URL需先按URI抽出11位ID再交VideoId，已由自写规范化及测试验证，不复制其他项目算法。当前没有启用Deno/Python/JVM/FFmpeg作为App运行时。

Joe Converter的PHONE_KEYS_LINK与Android本轮视频、5图真实移动schema再次一致；自写Dart扫描保持目标ID和顺序。实际无Cookie取得HTML与媒体，证明这三个固定Android公开作品不需要预设账号登录，不能推广所有作品。Windows相同分享链接收到login跳转，匿名session/browser/UA/网络条件必要性尚未确定。参考项目所用Cookie、TLS关闭、stealth、WithFingerprint或原图URL变换没有因此获准采用。完整同样本条件、失败阶段和最小恢复操作见network-matrix-phase2.md。

## 2026-10-01 实现验证与联网验收拆分

Dart库3.1.0现在实际承担隔离prototype player/manifest与StreamInfo模型，三个其他核心项目的格式分层、独立轨道及异常设计进入测试/选择/下载映射，详见youtube-prototype-guide.md。没有重写完整协议，23项离线契约通过不代表真实平台通过。

新增用户两个参考见user-reference-audit.json：wangsy116/youtube-downloud实际只有README/在线站点列表；kemomi/bilibili-freevoice脚本YouTube按钮将URL交第三方ytdownfk，脚本声明AGPL但license文件/版本未充分明确。读取固定源码但不执行/复用，不访问其外部服务；不能作为本地extractor替代Dart库。

## 2026-10-01 小红书最终收尾（优先于前述历史状态）

**X-A PASS**。详见 [双端最终证据与兼容性检查](xhs-feasibility-closure.md)。Windows 本轮直接匿名 HTTP，使用明确声明Windows的移动布局兼容UA；无Cookie发送、无a1/web_session、无首页/session初始化、无WebView2或登录。正常分享重定向所带xsec_token只在内存使用，未验证移除后的必要性，不能称必须。视频6abb69640000000014010526真实下载1680739字节；8图687a4239000000002400bcc9前两张57629/59560字节。三个文件hash分别与Android对应文件一致。用户确认Windows视频画面/声音正常，两张图片能打开、内容不同且顺序一致。旧Android视频/5图/8图、MediaStore和系统打开PASS保留，不重跑。

纯HTTP A路线成立，因此不增加B路线profile/session实验。25项全research离线测试通过（含Android schema回归）；Dart静态检查无问题；Windows原生研究构建已实际执行固定8图，不是production发布构建。近期源码/提交/Issue/许可证审计见xhs-oct1-reference-audit.json；最接近JoeanAmier Converter移动/桌面hydration路线，均设计参考、没有第三方代码搬运和新增依赖。

YouTube暂停，既有prototype仍待用户联网验收。production、正式依赖、History/UI/Downloader/ParserService未改；History重启恢复不在本次已通过范围。无commit/push/merge/tag。固定样本成功不等于所有小红书作品可解析或正式发布完成。

**V0.5.0 XHS FEASIBILITY CLOSED — X-A PASS**。等待下一条指令，不进入production、不恢复YouTube。