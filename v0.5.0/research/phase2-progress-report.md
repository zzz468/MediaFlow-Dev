# 第二阶段进度与兼容性报告

本报告是阶段中间证据，**不宣告第二阶段完成，不进入第三阶段**。基线 `feature/v0.5.0 @ e48d8d591a7bee232e09042d44fb965efea96556`，cwd/Git top-level `D:\projects\mediaflow-v050`；只在此worktree工作。

## 文件与边界

第一阶段7份规划文件保留原样。新增内容全部位于 `v0.5.0/research/`：项目对照、YouTube/XHS证据、GitHub/pub.dev/source索引、隔离Flutter包及测试、参考运行/网络诊断/Windows匿名页面脚本、脱敏两端结果。完整新增文件清单见 `phase2-file-manifest.json`（生成时的快照）。未删除文件；production现有已跟踪文件没有修改。SDK/pub缓存、平台下载文件和APK均被research .gitignore排除，不打包发布。

未修改正式PlatformDetector、ParserService、Downloader、History、Settings、Logging、Storage、UI或领域模型。没有正式依赖新增，没有Git add/commit/push/merge/tag/PR/reset/clean。`git diff --stat`为空，因为新增文件未跟踪；不能据此说没有新增研究代码。

## 自动化与构建

- 隔离PoC测试10项通过（新增用户分享链接及Shorts规范化），覆盖JSON不执行任意脚本、桌面与实测移动schema目标ID校验及顺序、失败分类、脱敏、URL域名/协议边界。
- Dart analyze lib/bin/test 无问题（以最后实跑为准）；不把研究检查写成全production回归通过。
- Windows Dart CLI及已审计yt-dlp源码已实际执行；Windows自有WebView2 C# helper已构建并执行，结束清理profile。未重建production Windows Flutter包。
- Android独立Debug APK构建通过、真机安装与网络/解析/图片下载/MediaStore/系统打开实际运行；不能将APK构建通过写成YouTube或视频下载通过。
- 生产回归、正式Windows/Android release构建及真实History新平台恢复未执行；本阶段隔离范围不适合捏造这些通过。

## Android安装安全

PJZ110、Android17/API37。已有 `com.mediaflow.mediaflow` v0.3.0 安装在用户10（用户0 installed=false），因此默认 `pm path`空不代表设备没有正式包。已只读pull其base.apk核实Release SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。用户0还有galleryv040、research.v040.lifecycle，均保留。

本阶段研究 `com.mediaflow.research.v050.feasibility`，Debug SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。首次安装无-r，后续只对同包名同签名研究包-r更新并保留结果；与正式包不同名、不同签名，签名不能用于覆盖正式包。没有卸载/清数据/替换正式应用，未使用flutter run自动安装。仅对自己的研究包force-stop再启动，结果文件SHA256一致，证明文件保留；UI确实恢复及无网络自动重跑仍须与运行记录分别核验，不能称production冷启动History PASS。

首次Debug APK 147917634字节（约141.1MiB），包含debug引擎/多ABI等，未做空包同模式对照，所以不能把其大小归因Dart库，也不能推出release增量。正式包体积没有测量变化，因为正式构建/依赖没改。

后续研究APK实测164304949字节（约156.7MiB）；同样不是release增量评估。一次ADB流式安装失败后，设备仍可见，改用非流式同签名研究包更新成功，没有卸载/清数据。真实下载两张图片共117189字节；系统应用名称未记录，用户已确认两张均可打开、顺序一致，独立图库浏览尚未单独验收。

## 已确认与尚未完成

详见两平台phase2文档与结果JSON。Android8图已取得metadata/顺序列表，并GET前两张不同JPEG、MediaStore保存，用户确认系统打开和页面顺序。Android视频取得过metadata/stream URL，下载尚未完成；5图仍受连接影响。Windows新平台下载尚未成功。YouTube两端均在连接层失败，未进入metadata/manifest。

Windows系统DNS对YouTube出现异常线索：相邻检查返回174.132.167.252、69.171.235.22及2001::1；ARIN登记分别UK-MICROSOFT-20080617/TFBNET3，TLS前TCP超时。系统WinINET代理/PAC未配置，所查代理环境变量未配置，Androidglobal http_proxy为null。小红书正常系统DNS TCP/TLS在诊断时成功，但先前请求有超时/ConnectionReset。用户确认官方页面可以访问，因此继续核对成功访问时的实际网络/浏览器配置，不默认归因地区/WAF，不改系统DNS、不用代理规避限制。

## 【项目目标兼容性检查】

| 项目 | 状态与具体风险/边界 |
|---|---|
| Windows | 研究CLI/helper已实际测试；新平台实际下载尚未完成，YouTube连接层阻断，XHS HTTP/login与Browser连接差异待解；生产构建未跑 |
| Android | 独立研究包构建及真机实测；8图两图片链已验证，视频/YouTube未完成；MediaStore Downloads保存不等于图库独立浏览完全验收 |
| iOS | 核心Dart理论兼容；未构建/实测，未来WKWebView和导出Adapter；不把WindowsSDK绑定核心 |
| macOS | 核心Dart理论兼容；未构建/实测，系统打开/Browser需Adapter |
| Linux | 核心Dart理论兼容；未构建/实测，WebView2 helper暂不支持，Browser/桌面能力需替换 |
| Bilibili | 原代码保留，未运行本轮回归，不能写实际验收通过 |
| Douyin | 既有框架/研究保留，本版P2；本轮未重启其网络实验或做正式能力开发 |
| YouTube | P1研究未取得manifest，不能正式发布；需要连接条件与stream/player兼容实证 |
| 小红书 | P1 Android图文部分已实证；桌面与视频门槛未满足；不预设账号必要 |
| X/Instagram/国际TikTok/其他未来平台 | 本版不接入；统一资源与独立Adapter继续保留扩展路径，本轮未实测 |
| PlatformDetector / ParserService | 正式路由未改；现有MediaPlatform尚无YT/XHS，未来需最小登记 |
| Parser / Adapter / Browser | 研究独立，正常自有WebView2与shared Dart边界已建立；WindowsSDK不适用于Android，不能直接共用底层实现 |
| Unified Content Model / MediaContent / MediaResource | 有audio/gallery/mixed基础，但track/quality等未表达；缺真实YT证据不重构；凭据不放公共资源 |
| Downloader | 现有mapper会遍历全部resources，必须先选中才传入；audio MIME源码支持不等于实际音频/续传验收 |
| History | contentId/resourceId/type/MIME可存；resourceIndex由task ID推导，muxed/video-only角色无持久化字段；仅源码判断，未验真实新平台恢复 |
| UI | 正式UI未改；研究入口只用于样本/证据和系统打开，不代表产品交互完成 |
| Settings / Logging / Storage | 正式模块未改/未回归；研究结果私有文件及workspace本地脱敏JSON，避免token、Cookie及原HTML持久化 |
| Browser/session | Windows一次Level1普通匿名profile清理已核实；Android成功图文是Level0；Level2未运行，未导入任何外部登录态 |
| Media Processing | 未引入FFmpeg或处理流程；分离流没有mux，不能宣称合成有声视频 |
| 隐私 / 零服务器 | 只正常请求所属平台；无第三方解析服务器、账号上传、链接同步或远程媒体处理；公开CDN明文HTTP存在完整性风险，正式策略待验证 |
| 第三方许可证/依赖 | 研究Dart BSD3及微软SDK BSD式许可；其余设计参考，GPL/custom未复制；无正式Python/JVM/JS runtime/FFmpeg依赖 |
| 性能 / 包体积 | 有请求/超时/96MiB资源预算，无大规模实验；研究Debug大小不能代表release增量，下载/解析效率尚无完整双端测量 |
| 维护 / 正式发布 | player/页面字段/URL过期会变；真实移动schema与桌面差异需独立Adapter维护；当前不得作为v0.5.0正式功能发布 |

## 路线决策

当前两个平台均继续第二阶段研究，不进入production。不能把环境中断强行写成Y-C或X-C；也不能用单个Android图文成功写成X-A/X-B双端通过。剩余优先：定位正常连接差异 →补齐双端YouTube metadata/streams/三个role下载和播放器 →补齐XHS视频、第二图文与Windows真实资源链 →依证据决定production路线。

## 2026-09-30 固定样本续跑更新（优先于上文旧状态）

详见 [网络矩阵](network-matrix-phase2.md) 与 `poc/android-fixed-samples-resume-results.json`。Windows/Android使用用户提供的同两个YouTube链接；Shorts带si参数触发库URL识别限制，自写URI规范化后仍连接失败，故已排除该本地识别问题。两端YouTube均未进入metadata/manifest；Windows分层Socket10060及Android shell curl连接超时将阻断定位到TCP/TLS之前，不能判extractor失败。浏览器可打开由用户确认，浏览器独立配置及VPN研究App覆盖范围未核实；不擅自改系统网络。

Windows本轮三条XHS分享链均正常HTTPS302至作品页再302登录，安全停止；不是本轮TCP阻断。Android同固定视频和5图无Cookie、无登录匿名页面200、移动schema解析及真实下载成功。视频1680739字节、HEVC+AAC轨、MediaStore；5图前两张918516/46990字节、1080×1080、不同hash并MediaStore。用户已确认视频系统播放画面/声音正常、5图两张系统打开且顺序一致。8图既有Gallery PASS保留且未重跑。不能因为Windows登录跳转认定全平台必须session，也不能把Android成功写成Windows同等验收已通过。

本轮10项测试通过；Dart analyze lib/bin/test No issues found；Android Debug构建成功，164307618字节，仅同签名独立研究包-r非流式更新成功，旧结果保留，与正式包共存，未卸载/清数据。WindowsDart CLI已运行，无production Flutter构建/回归。所有改动仍在research，正式依赖、production路由/模型/下载/History/UI均未改。没有Git写操作。

阶段仍 NOT YET CLASSIFIED；YouTube明确环境连接阻断，XHS Windows匿名上下文差异仍未确定。未完成YT两端metadata/manifest/三个资源角色下载/系统打开，WindowsXHS媒体链，正式History冷启动。下一步最小恢复：先证明一个固定YT官方URL在研究程序DNS→TCP→TLS→HTTP正常，再仅补同两个样本资源链；XHS另需有界正常匿名上下文对照，不重跑8图PASS、不导入外部会话。完成本轮证据报告后暂停，不进入第三阶段。

### 兼容性检查补充

Android新增实际视频/第二图文下载和MediaStore证据，但系统播放状态另记；Windows未满足新平台下载门槛。iOS/macOS/Linux仍理论兼容、未构建/实测，底层保存/打开须Adapter。Bilibili/Douyin及公共模块保留，未跑全回归；X/Instagram/国际TikTok不接入。研究库及HTTP明文图片策略不进入正式依赖/发布；HEVC解码存在设备兼容风险。正式包体积/性能未测，不能由研究Debug推算。隐私、零服务器与平台模块隔离保持，维护风险是平台页面/流变化和网络路径差异。

本轮用户补充确认：Android视频系统画面/声音正常；5图前两张可打开且顺序一致。子能力PASS，原始自动JSON与人工确认分存。

**V0.5.0 PHASE 2 BLOCKED BY VERIFIED ENVIRONMENT CONDITION**：YouTube双端研究路径TCP门槛实证阻断，Windows XHS登录上下文差异仍待独立定位。当前不判Y-A/B/C或X-A/B/C，不宣告双轨可行性完成。本轮报告后暂停，不进入第三阶段。

## 2026-10-01 策略调整与 prototype 交付（最新状态）

用户明确拆分实现验证与真实平台联网验收。旧 `V0.5.0 PHASE 2 BLOCKED BY VERIFIED ENVIRONMENT CONDITION` 保留为历史网络结论，**不再阻止隔离prototype开发**。本轮没有请求真实YouTube、没有增加网络排查或自行换样本。当前 `Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING`；真实联网仍 `REAL-WORLD VALIDATION BLOCKED BY ENVIRONMENT`，不判Y-A/B/C。

交付说明/设计/参考许可/最小测试步骤见youtube-prototype-guide.md；路径/大小/SHA256见youtube-prototype-build.json。Windows Release x64和Android独立Debug APK构建成功；23项离线测试通过，Dart analyze lib/bin/test No issues found。fixture八个discovered、五个selectable（两个progressive、一个video-only、两个audio-only），显式选择后只一个download resource；HLS不能称progressive。所有数字是synthetic fixture结果，不是平台stream实测。

核心新文件：feasibility/lib/youtube_prototype.dart、prototype_storage.dart、youtube_main.dart，test/youtube_prototype_test.dart，fixtures/youtube-minimal.json；新增Windows独立框架和四份现有自有模型/mapper原样快照及SHA256清单。修改研究pubspec仅登记fixture asset，未添加/升级依赖；研究Android MainActivity增加旧系统MediaStore能力检查，其他旧小红书入口保留。新增guide/build manifest和两个用户参考审计，更新phase2文档/.gitignore；没有删除文件。完整当前未跟踪文件见phase2-file-manifest.json。Artifacts、SDK/cache不纳入Git。

23项测试包括原样模型快照对照、真正Dart库typed stream映射、metadata/ID/时长/封面、三层选择、过滤边界、文件名、无签名URL的history sidecar、模拟HTTP单资源下载、空文件拒绝、错误脱敏和UI。第一次UI测试因Flutter fake async中的文件等待挂起，已终止并修正为明确异步区域/同步测试目录；最终全套通过。Windows第一次缺generated_plugins.cmake，研究包offline pub get补齐，最终Release构建通过。pubspec.lock没有版本升级。本轮无production全量回归或正式release构建，不称这些通过。

Android包名com.mediaflow.research.v050.feasibility，Debug SHA256 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8，与先前独立研究包已核实签名一致，与正式包不同名。本轮adb devices为空，**没有执行真机安装/覆盖/卸载/清数据**；当前设备安装状态未重新核实。用户手动安装时同签名研究包更新保留旧结果；若冲突停止回传，不能卸载正式包继续。本APK164368564字节，约156.75MiB，多ABI Debug，不代表正式release增量。Android10+可用当前MediaStore Adapter；APK最低API24，API24–28保存/解析路径有可能可用，但该研究MediaStore打开链暂不支持，未实测。

Windows ZIP约12.46MiB，需完整DLL/data、可写解压目录；程序启动/真实媒体尚待用户。应用不会启动时自动联网，没有自动固定样本执行。下载512MiB/10分钟预算、.part完整性保护，无正式队列/续传/FFmpeg合并；HTTP服务器特殊分段/codec/过期URL可能失败，必须回传具体阶段。Dart库显式observed WEB路线没有设备合成/TVfallback/JSruntime，真实流覆盖尚不明确。研究history不等于正式History，平台暂unknown加PoC youtube identity；production接入前需最小平台登记和通用stream字段方案。

### 【项目目标兼容性检查】（本轮）

| 项目 | 状态与具体判断 |
|---|---|
| Windows | 独立Release构建通过、离线UI测试通过；用户真实解析/下载/播放器未实测。可写目录和系统codec有风险 |
| Android | 独立Debug构建通过、包名/签名核验；本轮新UI未上真机。旧XHS 8图/5图/视频/MediaStore/系统打开PASS保留；本轮不重复。Android10以下研究MediaStore链暂不支持 |
| iOS/macOS/Linux | Dart核心理论兼容，未构建/实测；当前研究保存/系统打开Adapter仅Windows/Android，其他端暂不支持该测试UI保存链。没有让production核心绑定新系统API |
| Bilibili / Douyin | 既有代码保留，本轮未回归；Douyin P2，不受新研究Adapter路由影响，但不能称真实已通过 |
| YouTube / Xiaohongshu | Y实现就绪待用户双端实测；XHS旧AndroidPASS保留，Windows上下文差异未解。本轮没有正式Parser接入 |
| X / Instagram / 国际TikTok / 其他未来平台 | 本版不接入；独立Adapter与模型边界保留，未实际验证 |
| PlatformDetector / ParserService | 未修改production登记或路由，研究URL识别仅YouTubeAdapter；需要另阶段决定生产登记 |
| Parser / Adapter / Unified Content Model / MediaContent / MediaResource | 模型与mapper自有原样快照由hash契约保护；stream字段和duration是PoC附加描述，凭据不进入公共资源 |
| Downloader | 仅选择一个资源映射既有任务，research下载保存。正式队列/续传/重试未修改和未回归，prototype不能替代完整Downloader |
| History | sidecar保存公开metadata/角色/本地文件，不写签名URL；可读取研究记录，不代表production冷启动History验收 |
| UI / Settings / Logging / Storage | 正式模块未改；独立研究UI/私有或portable文件、复制脱敏诊断；公有metadata与路径会显示，用户决定回传；无日志上传 |
| Media Processing / Browser Adapter | 未引入FFmpeg/转码/合流/浏览器会话或JS挑战求解；分离流以原角色保存，不把video-only伪装成有声视频 |
| 隐私 / 零服务器 | 仅所属平台必要请求，无外部Cookie导入、第三方解析/云/同步。外部解析型用户参考没有采用 |
| 第三方依赖 / 许可证 | 研究继续使用BSD3 Dart库、现有http/crypto/Flutter；另外三个核心项目设计参考不复制GPL。测试分发保留库LICENSE和Flutter依赖NOTICES，正式依赖为零 |
| 包体积 / 性能 | Windows ZIP13,067,700字节、APK164,368,564字节；不同build mode不相互比较；下载预算/进度节流，真实性能未验 |
| 维护 / 正式发布 | player协议、签名、WEB覆盖与codec会变；库封在可替换Adapter中。当前仅research测试，不是v0.5.0正式发布 |

最终Git状态仍?? v0.5.0/、tracked diff --stat为空；没有commit/push/merge/tag/PR/reset/clean。完成双端测试构建后暂停，等用户反馈再分类。

**YOUTUBE PROTOTYPE READY - REAL-WORLD USER VALIDATION PENDING**

## 2026-10-01 小红书最终收尾（优先于前述历史状态）

**X-A PASS**。详见 [双端最终证据与兼容性检查](xhs-feasibility-closure.md)。Windows 本轮直接匿名 HTTP，使用明确声明Windows的移动布局兼容UA；无Cookie发送、无a1/web_session、无首页/session初始化、无WebView2或登录。正常分享重定向所带xsec_token只在内存使用，未验证移除后的必要性，不能称必须。视频6abb69640000000014010526真实下载1680739字节；8图687a4239000000002400bcc9前两张57629/59560字节。三个文件hash分别与Android对应文件一致。用户确认Windows视频画面/声音正常，两张图片能打开、内容不同且顺序一致。旧Android视频/5图/8图、MediaStore和系统打开PASS保留，不重跑。

纯HTTP A路线成立，因此不增加B路线profile/session实验。25项全research离线测试通过（含Android schema回归）；Dart静态检查无问题；Windows原生研究构建已实际执行固定8图，不是production发布构建。近期源码/提交/Issue/许可证审计见xhs-oct1-reference-audit.json；最接近JoeanAmier Converter移动/桌面hydration路线，均设计参考、没有第三方代码搬运和新增依赖。

YouTube暂停，既有prototype仍待用户联网验收。production、正式依赖、History/UI/Downloader/ParserService未改；History重启恢复不在本次已通过范围。无commit/push/merge/tag。固定样本成功不等于所有小红书作品可解析或正式发布完成。

**V0.5.0 XHS FEASIBILITY CLOSED — X-A PASS**。等待下一条指令，不进入production、不恢复YouTube。
## 2026-10-01 小红书 Production 接入完成（当前状态）

**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**。详见 [正式接入、双端验收与兼容性检查](../acceptance/production/README.md)。独立XHS匿名HTTP Adapter正式登记到PlatformDetector/ParserService，沿用MediaContent/MediaResource、Downloader和History。Windows与Android正式main.dart路径均验证视频、完整8图、系统打开及进程冷启动History；人工原话和脱敏任务证据已归档。5图另有production离线fixture契约，未冒充本次5图联网验收。此阶段完成不代表全v0.5.0正式发布或全部作品覆盖。

全量production测试281通过、7跳过、0失败；flutter analyze无问题；Windows Release和Android独立Debug构建成功。Android测试包com.mediaflow.mediaflow.xhsprodv050与正式包共存，无覆盖/卸载/清数据。没有新增/升级正式依赖、复制GPL源码、引入服务器、登录或外部Cookie。YouTube继续冻结，全部研究文件保留。未commit/push/merge/tag，完成后暂停。