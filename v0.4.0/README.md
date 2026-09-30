# MediaFlow v0.4.0 启动规划

## 最新：GALLERY RELEASE CANDIDATE READY（2026-09-29）

[普通入口42项验收报告](research/gallery-main-entry-result.md)：Windows普通Release main、Android隔离包的普通Debug main均通过登录自动续解析、13资源、真实下载/打开、History与重启session复用。242 passed / 6 skipped，analyze无问题，四种构建通过。限定当前作品/设备，不等于所有作品覆盖或正式发布；P1/未实测范围见报告。无Git写操作，立即暂停，H2永久冻结。下文为历史。

## 最新：发布差距盘点 — NOT RELEASE CANDIDATE READY（2026-09-29）

[正式入口与会话 UX 收尾方案](research/gallery-release-gap-audit.md)：双平台 core 的真实 PASS 保留；普通 ParserService 尚未接通 Gallery 和登录/过期恢复/清除流程。下一轮唯一 P0 为双平台普通入口的 Gallery/会话闭环，复用现有多资源 UI、Downloader、History。H2 永久冻结，本轮不发布、不执行 Git 写操作。后文为历史。

## 最新：Android Gallery真实验收PASS，static gallery core complete（2026-09-29）

[41项报告](research/android-gallery-real-production-result.md)：PJZ110实际API37，当前非Python候选detail仅1次200/62155bytes，目标type68/13图→13资源/任务，前2张MediaStore下载、系统图库正常且不同。History 13项/2完成/两条video及session cold restore通过，cleanup核验通过。旧Douyin视频/Bilibili真实解析、analyze、227 passed / 6 skipped、Debug/Release构建通过。标记ANDROID GALLERY PRODUCTION ACCEPTANCE PASS与DOUYIN STATIC GALLERY CORE IMPLEMENTATION COMPLETE，限定当前独立Debug入口/固定作品；不冒充正式Release GUI或所有作品支持。立即暂停，不进入发布，H2永久冻结。后文为历史。

## 最新：ANDROID SESSION ENTRY READY（2026-09-29）

[32项报告](research/android-desktop-session-result.md)：官方Desktop UA metadata使PJZ110出现PC登录入口，用户正常扫码；sessionid/sessionid_ss/ttwid取得。修复restore容器重复挂载后，cold restart复用、cleanup及cold deletion核验通过。Debug/Release构建与analyze通过，完整227 passed / 6 skipped。detail/下载0；本轮暂停，下一轮仅Android Gallery Real Production Acceptance。legacy navigator.platform仍Linux，不能把桌面兼容模式当成实际Windows环境；后文为历史。

## 最新：Android session入口阻断，Release构建已修复（2026-09-29）

[30项结果与兼容性检查](research/android-session-entry-result.md)：未登录检查保持窗口已修复；正常移动首页及一次授权宽屏尝试均无网页登录入口。detail/下载0，profile清除与冷启动核验通过。Debug/Release构建通过，analyze无问题，227 passed / 6 skipped。未达到 ANDROID SESSION ENTRY READY；暂停，不恢复H2。后文为历史记录。

## 最新：Android等价实现离线通过，真机会话未完成（2026-09-29）

[36项报告](research/android-gallery-acceptance-result.md)：PJZ110实际Android17/API37；独立Debug包与正式v0.3.0共存。Android Session Adapter/共享pipeline离线通过，223测试通过/6跳过，analyze无问题；正常会话两次均未取得可用handle，真实detail/下载0，清理及冷启动核验通过。Android PASS/CORE COMPLETE均未达到，Release构建的生成插件引用检查失败。下一轮仅正常session入口问题；暂停，不恢复协议研究。

## 最新：Windows Gallery production spike PASS（2026-09-29）

[32项真实验收](research/windows-gallery-production-spike-result.md)：production candidate正常自有登录，A无Argus头403，B仅加原F2兼容头200；目标type68/13图→13资源/任务，前2张真实下载并由测试人员确认Windows正常显示、内容不同。会话清理通过；回归215通过/6跳过，analyze无问题。下一轮仅Android等价实现/真机验收；本轮暂停，H2永久冻结。

## 最新：Windows Gallery Backend ready for spike（2026-09-29）

[29项结果](research/gallery-backend-candidate-result.md)：非 Python Dart detail/signer 与 Windows 私有 session helper 已完成；31项 backend 测试，完整215通过/5跳过，production/test analyze无问题，Windows Debug构建通过。真实Douyin请求0，Argus开关默认false，正式UI入口未启用。下一轮仅Windows真实production spike；H2永久冻结，下方旧建议仅历史。

## 最新：Gallery离线Adapter与集成架构完成（2026-09-28）

[本轮结果](research/gallery-integration-result.md)：真实F2脱敏13图fixture→既有模型→13个DownloadTask验证通过；18个adapter测试，全套184通过/5跳过。推荐最小协议模块+双端私有session Adapter，未进行production spike。自研H2永久冻结，以下旧路线建议为历史，不重新进入UIFID/W2/W3/Browser Observation/Feed/SSR。下一步仅在线backend/session接入资格与有界Windows spike；本轮暂停。

## 当前：2026-09-28 W3 DL-style A/B — W3-2 / 硬止损

[实测报告](research/poc/h2/w3-dl-strategy-result.md)：重新读取DL当前源码，策略级A/B共2次detail；A无Cookie、B新正常session subset，均403/46bytes/Argus Uifid Not Found。原signer不变、无placeholder/X/新context补丁；无业务JSON/gallery。停止第三/第四套headers/query实验；下一轮只决策显式正常授权UIFID context或关闭当前Web-detail H2。production/Git写操作无，完成后暂停。

## 当前：2026-09-28 正常 session subset + 固定 W2 — SCTX-2

[本轮实测](research/poc/h2/session-context-result.md)：重新正常登录，可信sessionid/sessionid_ss+ttwid只通过process memory/env消费；唯一detail仍403/46bytes/Uifid Not Found。UIFID不作为准入条件、不发送；signer与原W2 runner冻结。正常session subset仍不足，不重复注入；下一轮仅重评当前gate策略/context消费。最终profile clear空集/退出/删除已验证，production/Git写操作无，完成后暂停。

## 当前：2026-09-28 context composition / U1-U2 审计

[本轮报告](research/poc/h2/context-composition-audit.md)：M/F/D 请求逐字段比较完成；F2 无UIFID分支仍加Argus占位，属于源码workaround而非正常context，不采用。还有query/msToken/header/Cookie差异，未证明唯一因果变量或平台binding。Production preference=U1；无授权U2输入，平台请求0，signer/生产/Git写操作均无。下一轮仅可信context准入与固定M一次消融验证，无输入则暂停。

## 当前：2026-09-28 capability / real research signer

[最新完整报告](research/poc/h2/capability-signer-audit.md)：UIFID 改为 conditional capability，旧条目仅保留历史。Apache-2.0 F2 research signer 已实现（注明复用，不是 clean-room）；14 算法测试、44 Dart 契约通过。W1 本地响应读取失败；W2 修复读取器后返回 403 / 46 bytes / ArgusSecurityPlugin Uifid Not Found。两次 detail 额度用完，无业务数据、未证明 signer 被接受。主 blocker 仅为当前策略 context gate；下一轮只审计 context composition 与 U1/U2 边界，不重启 bootstrap。production/Git 写操作均无，完成后暂停。

## 最新：2026-09-28 授权正常交互 context 实测 C5

[实测报告](research/poc/local-session/authorized-session-result.md)：新增独立研究窗口，challenge 暂停自动流程并保留窗口由本人正常处理。用户确认交互/challenge完成、未确认登录；新自有profile匿名ttwid存在，detail scoped UIFID/账号Cookie为空，C5。E1=0；Native clear/空集/进程退出/目录删除独立复核通过。下一轮只审计context来源/组成，不开始signer、自动初始化或production；完成后暂停。

## 最新：2026-09-28 H2 transport 解耦验证 H2-T5

[前置核对报告](research/poc/h2/transport-context-preflight.md)：本轮单独验证“已有正常 context 时 transport 是否成立”，未进行 ContextProvider 自动获取研究。附件无指定 context，四个候选进程输入均缺失；现有 signer 仍是 contract/UnavailableSigner，MOCK 不可用于真实请求。因此真实 transport 未测试，H2-T5，网络请求 0。等待测试人员本地提供授权且可验证的最小 context，不把缺输入写成服务端 context/signer/endpoint FAIL。生产未改，完成后暂停。

## 最新：2026-09-28 H2 架构与离线契约 PoC

[H2 完整报告](research/poc/h2/README.md)：ContextProvider / Signer / WebDetailClient 边界、最小字段、五端方案与许可矩阵已设计；42 项合成离线检查通过，真实 signer 与 gallery 均未验证。本轮平台请求 0，保留历史正常入口 challenge 证据，结果 H2-CONTEXT-BLOCKED；唯一主 blocker 是正常自有 UIFID/context 尚未取得。下一轮只处理该前置条件，不重试旧 challenge、不恢复关闭路线；production integration 未开始。完成后暂停。

## 最新：2026-09-28 横向审计决策 H2

五项目源码按入口聚类：Web detail 4、Share SSR 2；未发现正在使用的新 gallery endpoint。新 share/video 路径仅一次诚实通用 UA、无会话 GET，302/183 bytes，无嵌入 JSON，未跟随跳转。决策 H2：下一轮只设计 Session + license-safe signer + Web detail；不继续匿名旁路或关闭入口。当前图文成功仍未验证，production 未修改，Git 写操作无。本轮完成并暂停。

见 [完整横向报告](research/douyin-gallery-horizontal-audit-2026.md)。下文旧“下一步”仅为历史。

## 当前：一次通用UA Feed排疑结束，gallery候选关闭（2026-09-28）

用户另行授权一次通用UA请求，snssdk/固定target+aid1128/UA MediaFlow/0.4.0，HTTP200/228942bytes/4其他作品，目标仍缺失。不是reference严格复现，M3源码结论保持；不追加Feed实验。下一主路线仅新的真实gallery入口横向审计，不自动回UIFID/Browser/Login循环。本轮暂停，production未改。见[本次报告](research/poc/generic-feed-once-result.md)。下文为历史。

## 当前：Mobile Feed 源码结果M3（2026-09-28）

当前media-parser HEAD ee05d757的note/slides图文分支跳过Feed，走Web detail→分享SSR；Feed主路径服务视频。旧5其他作品的服务端原因尚未证实；参考设备UA实验被auto-review拒绝，真实Feed请求0，探针CLI已禁网。10离线断言和定向Dart analyze通过。新具体线索为参考SSR实际改写iesdouyin/share/video（不是旧share/note/slides），但附会话字段，不等于匿名可用。下一唯一建议目标是静态审计该SSR最小匿名条件；本轮暂停，不回UIFID/login/Browser或signer。见[22项结果报告](research/poc/mobile-feed-target-result.md)与[网络前差异矩阵](research/poc/mobile-feed-target-audit.md)。下文历史保留。

## 当前：Local Session / Context Provider 最小PoC，S4入口阻断（2026-09-28）

平台无关opaque context契约、Windows独立可见会话与单次detail路径已编译，离线10条断言通过；App自有profile仓库外创建/最小URI范围读取/清理已实测。唯一真实首页入口在登录完成前触发WAF，停止并彻底清本轮profile，UIFID未取得、detail0；不能写成登录后仍无UIFID。Android有条件Adapter设计但登录/context未实测，是生产门槛。匿名A4历史保留，不再追首次发行，不研究signer，不进production。见[本轮24项报告](research/poc/local-session-audit.md)。完成后暂停；下文是历史。

## 当前：首次匿名 UIFID bootstrap RESULT A4（2026-09-28）

独立新 WebView2 profile 的空 Cookie/storage/IndexedDB 已验证；唯一首页导航约1.9秒后触发 WAF challenge 资源并安全停止。正常 SDK 初始化未完成，UIFID 首次来源/匿名性/生命周期仍未定；没有 note/detail/登录/signer 实验，profile 退出后已精确清理。Browser 仅评估 Context Bootstrap Provider 候选，旧 Observation 主路线保持停止。唯一缺失证据是无挑战正常匿名 SDK 初始化中的首次 UIFID 发行/写入事件及对应响应/调用点。完整检查与日志见[本轮报告](research/poc/uifid-bootstrap-audit.md)。下文为历史研究状态；本轮暂停，不进入production。

## 当前：UIFID 上下文与产品技术边界定版（2026-09-27）

按所有者明确产品调整修订根AGENTS.md：本地signer、正常请求上下文、匿名优先与App自有用户主动登录fallback允许；隐私、权限及安全挑战边界保持。UIFID请求侧来自已有Cookie/session/SDK上下文，不是A-Bogus输出；首次生成机制与登录必要性未证。一次无Cookie首页GET200/72914bytes、无UIFID/UIFID_TEMP、命中安全标记即停止，无detail/签名/登录实验。下一轮先解决可信UIFID状态来源和生命周期，production仍BLOCKED，Browser仍非主路线。完整矩阵与证据见[最新研究报告](research/poc/uifid-context-audit.md)。以下上轮冲突判断为历史状态。

## 当前：Web detail + 本地 signer 研究主路线（2026-09-27）

本轮方向取代下文旧降级建议。Browser Observation **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**，保留全部研究代码，普通解析不新增默认WebView。匿名detail baseline实际403/46bytes，命中Argus UIFID安全拒绝；B/C因项目安全停止规则未测。目标结构/图片URL仍未取得，不能归因于只缺signer或session，不进production。完整来源/许可/冲突/模型/五端/测试/Git报告见[本轮审计](research/poc/web-detail-signer-route-audit.md)。下一轮建议只做离线signer协议与许可证审计，不自行开始。以下为历史记录。

## 最新收口：Browser停止，替代路线结果C（2026-09-27）

Browser Observation = **STOPPED / NOT VIABLE FOR v0.4.0**，触发本轮硬结束条件D：缺少证据证明剩余候选具备明显信息增益。上一轮JSON原文及DOM未保存，不能声称重新解码或证明页面无数据；helper对象根限制已静态确认，实际ERROR原因仍未确认。本轮Browser导航0，不改helper或production。

替代路线四个受控匿名GET：备用feed200/5其他作品无目标；share/note200含ID但未解析目标图片对象；share/slides200无目标；旧iteminfo200空正文。无Cookie/Token/签名/代理/重放，无图片下载。**Douyin gallery production feasibility = BLOCKED**，结构/URL NOT VERIFIED，下载NOT TESTED，Level1H Human PASS保持。

结果C：已调查的合法入口均暂未得到可用结构；建议v0.4.0明确图文原图暂不支持，保留现有视频与Bilibili多资源/重试/恢复/History目标。元数据、缩略图同样未证明，不宣传已支持。下一轮唯一建议目标是确认降级范围与验收清单，不再回Browser，不自动进入第三阶段。

Windows Network BLOCKED/normal cleanup FAIL/recovery历史PASS；Android生命周期、离线安全停止、cleanup历史PASS，real bridge仅JSON链PASS、真实安全停止NOT TESTED/Network BLOCKED。本轮不重跑旧平台实验。双平台production门槛未达。

完整决策、路线表、真实响应摘要、证据限制和兼容性检查：`v0.4.0/research/poc/browser-closeout-route-decision.md`；网络摘要：`anonymous-route-closeout-network-results.jsonl`。以下旧“剩余Browser候选/继续真实导航”仅为历史记录，已被本节替代。暂停等待指令。


## 最新：接线通过后一次真实 bridge 复验，结论2（2026-09-27）

显式研究Debug激活/一次性run保护、operation全链校验及真实NAVIGATE/停止状态接线完成；导航前审查通过，同构建离线回归PASS1820ms。唯一真实样本7690029886242009957：operation/Worker START/navigation各1，init/ack/ready各1、request31、命名hydration0、JSON2、fetch response0、body2（仅JSON）、decoder2/no-match1/error1/success0。953ms navigationBoundary拒绝跟随并取消，1029ms自动cleanup PASS；未识别安全挑战，真实安全停止NOT TESTED。真实bridge PASS仅限JSON→decoder链，目标结构/URL NOT VERIFIED，下载NOT TESTED，Network/production BLOCKED，Human Level1H PASS保持。

停止后gate与bridge计数不增，本次profile/cache/metadata/marker清除、Worker退出。历史3cache/5metadata/cf两marker列表前后一致；一次性研究控制账本保留，非浏览器残留。实验后设备研究包恢复默认PUBLIC_PROBE_ENABLED=false、无INTERNET，正式应用未改。

完整审查和结果：`v0.4.0/research/poc/android-activation-audit.md`、`android-real-bridge-recheck.md`。未追加导航/扩大采集；候选价值需先重新评估，不能以本次窗口零命中断言页面无数据或双平台路线已到边界。Windows旧结论保持。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停等待指令。

## 历史：真实 bridge 前置审查未通过，离线修复后暂停（2026-09-27）

按附件前置失败分支，本轮真实导航0次：真实入口仍禁用，旧real消费者不共享fixture遥测，fixture手动发送response不等于通用采集。已统一consumePageMessage、增加命名hydration/普通JSON script及页面既有同源fetch响应副本观察，不另发请求、不重放；INTERNET和targetUrl继续关闭。真实模式激活/Coordinator调度与遥测仍需下轮审查，不能仅加权限就访问。

最终研究APK两次离线PASS（831ms / 499ms），每次注入注册/init/ack/ready各1、hydration1、JSON1、response1、body3、decoder3/success3；停止后消费不增、单operation/START1，自动清理新增存储与marker，历史3cache/5metadata/cf两marker不动。仅同源fetch离线能力，不覆盖XHR/跨域/全部资源body。真实bridge与真实安全停止NOT TESTED、Network/production BLOCKED、目标结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS，Windows结论均保持。

详细证据：`v0.4.0/research/poc/android-real-bridge-preflight.md`。剩余候选NOT TESTED：真实模式激活审查后单次最小真实Android bridge复验。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不自行访问真实目标或进入第三阶段。

## 历史：Android 离线重入与 bridge 收口（2026-09-27）

CoordinatorService 状态机在分配之前拒绝重复 trigger，Activity 重建只 attach，Worker 进程级拒绝重复初始化。最终研究 APK 连续两次单 operation PASS（451ms / 373ms），随后快速、运行中、清理中重复 trigger 拒绝3、Worker START1、final734ms；本次操作 profile/cache/metadata/marker/Worker 零残留。bridge 初始化/ack/ready各1、hydration1、JSON1、response1、body3、decoder3/成功3，安全停止后消费不增。均限离线虚拟 fixture，不证明真实目标结构。

旧 onCreate 无条件分配缺陷已确认并复现；上一轮具体外部重入事件及真实 hydration0 的确切原因仍 NOT VERIFIED。本轮三项精确归属失败原型显式清理与正常自动清理分开记录；历史3cache/5metadata/cf两marker未动。当前 APK 无 INTERNET，不接受真实 targetUrl。Windows结论保持，真实安全停止NOT TESTED、Network/production BLOCKED、结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。

完整证据：`v0.4.0/research/poc/android-reentry-bridge.md`。剩余候选 NOT TESTED：Android 单次最小真实目标 bridge 数据入口复验，下一轮须重新审查真实接线，本轮不执行。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停。

## 历史：Android 单次公开目标实验（2026-09-27）

一个share/note目标、一次真实navigation：未检测到安全条件，10秒预算结束后取消，真实安全停止NOT TESTED；请求观察51，navigation1，response/body/hydration/decoder0，取消后消费不增。主operation自动cleanup PASS，但同一次启动出现额外Coordinator operation，已初始化Worker内失败、留下两个marker，故本轮完整零残留FAIL。lifecycle A及离线安全停止的历史范围PASS保持；旧3cache/5空metadata不删除。结构/URL NOT VERIFIED、下载NOT TESTED、Network/production BLOCKED、Human PASS保持，Windows结论不变。

桥接是否实际运行、Coordinator重入原因NOT VERIFIED，不能宣布双平台共同达到Browser研究边界。剩余合法候选NOT TESTED：先离线验证重入/Worker复用保护和document-start桥接健康；本轮不再请求真实目标。[证据、命令与文件]( research/poc/android-public-target.md )。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不进入第三阶段。

## 历史：Android 离线安全停止闭环（2026-09-27）

PJZ110 连续两次 securityFixture operation PASS（328ms / 285ms）：页面已加载、活动清理被拒绝，安全事件与同步观察取消同毫秒；六类离线消费替身计数停止后不增、排队任务消费0，Worker退出后Coordinator自动删除精确profile/cache/metadata/marker。Android离线安全停止PASS仅限受控模型，真实检测器/响应/decoder尚未验证；lifecycle A保持限定PASS。原3个历史cache及5个空metadata目录未删除，研究App storage不为0。Windows各结论保持，Android Network/production BLOCKED，真实结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。剩余候选NOT TESTED：Android最小真实目标安全停止/数据入口实验，下一轮单独决定，本轮不运行。

详细证据、时间线、文件和命令：[本轮离线安全停止记录](research/poc/android-offline-security-stop.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，不进入真实网络、production或第三阶段。

## 历史：Android Worker 自动清理（2026-09-27）

最终独立 Worker/Coordinator 真机连续两次 operation 自动闭环 PASS（544ms/363ms），活动实例清理拒绝 PASS，operation profile/cache/no_backup/marker 均清除。Android lifecycle A PASS 仅限最终正常离线研究模型；历史 prototype 缓存/空目录因 marker 已删保留，研究 App 整体 storage 不为0、历史残留清理 BLOCKED，不能宣称全部浏览器状态已清理。安全停止 NOT TESTED，Network/production BLOCKED；Windows 原 normal cleanup FAIL/root cause NOT VERIFIED 保持，recovery 限历史 PASS。Human PASS、目标结构/URL NOT VERIFIED、下载 NOT TESTED。详情见 browser-observation-feasibility.md 最新节。本轮未真实网络、未改 production、未新增生产依赖/未 Git 写操作。暂停。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 历史：Android gate A / Windows cleanup 定位（2026-09-27）

PJZ110 真机独立无网络 Debug 包已实测：WebView加载/destroy成功，但 loaded profile 在原进程 deleteProfile 抛 IllegalStateException，Android lifecycle BLOCKED，gate B/C未运行。新进程精确profile删除成功不覆盖自动生命周期失败；独立 worker 退出后的自动闭环仍为合法离线候选，NOT TESTED。Windows 本地重定向拒绝自动cleanup PASS，但原share FAIL未复现、根因未确认，normal cleanup仍FAIL；数据入口边界保持BLOCKED。结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED，Human PASS保持。详见[本轮记录](research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文为历史状态。

## 最新：share/note 候选验证（2026-09-27）

一次全新匿名研究会话在 2870ms 重定向 www.douyin.com /note/<id>，2875ms 拒绝继续；候选 BLOCKED，无 hydration/目标 JSON。Windows Browser Observation 在当前项目安全约束下已到达本阶段研究边界。本次自动 cleanup FAIL，helper 已退出后按本轮精确路径清理，最终 profile 根 0；此前受控 cleanup/recovery PASS 仍仅限历史已测范围，完整生命周期 NOT VERIFIED。Android 当前有 PJZ110 设备，runtime 仍 NOT TESTED；Level 1H Human PASS、结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED 保持。详见[本轮证据](research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文“share 尚未执行 / 无 Android 设备”等为历史状态。

## 最新：第二阶段收口判断（2026-09-27）

本轮源码审计未发现安全停止前合法数据漏消费；离线 recovery 九条断言 PASS，新增活动锁与 abandoned mutex 检查。研究生命周期达到当前受控范围，完整 production 生命周期 NOT VERIFIED。已测 /note Network BLOCKED；独立公开 share/note 入口停止前 hydration 尚有合法候选，NOT TESTED，本轮未运行。Android 无设备 NOT TESTED，结构/URL NOT VERIFIED，下载 NOT TESTED，production BLOCKED。详见[收口记录](research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停；后文为历史记录。

最新第二阶段：[recovery 边界实测](research/poc/browser-observation-feasibility.md)完成。本轮仅离线研究，v2 marker 字段/内部归属、PID 创建时间分支、活动实例拒绝、stale/active 分离及同 session 两 recovery 互斥均有实际证据。真实 PID 重用、双 WebView2 helper、断电/跨 session/完整 marker 伪造仍未验证。目标结构与图片 URL NOT VERIFIED、下载 NOT TESTED；Network BLOCKED，完整窗口 NOT VERIFIED；Android NOT TESTED / production feasibility BLOCKED。保留第二阶段，不把 cleanup PASS 当作 production PASS；后文旧结论为历史记录。

最新第二阶段：[事件诊断与硬杀回收](research/poc/browser-observation-feasibility.md)已完成。目标会话在成功导航前检测安全资源并停止；按 AGENTS 不延长验证后的观察，完整目标窗口未验证。离线正常 cleanup 与精确 marker 硬杀回收 PASS，Android BLOCKED/NOT TESTED。仍无目标图片结构，未进入第三阶段或 production。

状态：**第一阶段研究已完成；第二阶段独立 PoC 仍在进行，Level 1H 测试输入阻断已解除，匿名路线尚无目标结构；Windows Browser Observation 生命周期已验证但目标安全停止，Android cleanup 阻塞；功能开发未开始**。基线为正式发布后的 `main`：`e2ea89d4e156c843af09b4c491984a2206f1135b`。版本号与最终发布范围尚未冻结。本目录只放范围、架构、迁移、研究和验收记录；Flutter 工程仍在仓库根目录。此前的规则整理不计作第一阶段工作。

## 建议核心目标

1. **保护 v0.3.0 已发布链路。** Windows 与 Android 上的 Bilibili 视频、Bilibili 图文、Douyin 视频、资源选择/多资源下载、作品级 History 重启恢复均为回归门。不得降低队列、暂停/继续、失败重试、Range、`.part` 与本地数据兼容性。
2. **巩固多资源作品体验。** 用真实多图、部分失败、单资源重试、文件缺失和重启场景确定作品状态与操作语义；只有具体场景证明当前投影不足时，才小范围调整任务元数据或 History 投影。优先复用现有 `MediaContent`、`MediaResource`、`DownloadManager`，不预先重写下载器。
3. **完成下一内容入口的双平台可行性判定。** Douyin 图文是首个研究候选，但 v0.3.0 调查没有取得双端匿名可用资源证据。v0.4.0 必须给出可复核的“可接入 / 继续研究 / 暂缓”结论；只有 [研究门槛](research/README.md)全部满足，才把它列入 production 开发与发布范围。不能把研究完成写成图文上线。
4. **保持双平台发布标准。** 任何实际接入的新内容都要在 Windows 和 Android 各自完成 Release GUI 解析、真实下载、系统打开、重启 History 与失败状态验收；单平台可用不能算 v0.4.0 production 完成。

## 建议阶段

| 阶段 | 目标 | 退出条件 |
| --- | --- | --- |
| 1. 基线与首轮研究 | [核对 v0.3.0 正式能力](baseline-stage1.md)，调查多个 Douyin 图文开源实现并形成[候选路线矩阵](research/douyin-gallery-route-matrix.md) | **2026-09-25 已完成文档研究**；[结论](research/stage1-conclusion.md)未选 production 路线、未做 PoC、未改正式代码 |
| 2. 入口研究与范围冻结 | 按[统一研究规则](research/execution-rules.md)调查多个成熟实现、比较公开路线并做独立 PoC；在 Windows、Android 分别核实 Douyin 多图的结构化结果与至少两张图片的匿名真实下载，记录失败原因和替代候选 | [上一轮独立 PoC](research/poc/stage2-douyin-gallery.md)的 Windows HTTP 候选无目标图文；[续研](research/poc/verified-samples.md)已取得 Level 1H 样本，本轮有效输入上仍无目标结构；Android 无设备、未验证。仍未满足接入门槛，功能范围未冻结 |
| 3. 限定实现 | 实施阶段 2 已批准的最小内容/History/GUI 改动，平台字段只在平台 Parser/Adapter 中 | 离线合同、异常和旧版本兼容测试通过；无新安全/隐私依赖 |
| 4. 双端验收与候选 | Windows、Android 构建和真实 Release GUI 验收，完整回归后做 Release Candidate 判定 | 两端同一冻结范围通过；阻断项为零 |

阶段 2 的上一轮 Windows HTTP 候选未能复现目标图文；续研发现历史十图样本的路由仍可达，现已取得用户当前人工确认的多图样本，但匿名机器结构仍未确认，故阶段 2 继续保持进行中。阶段 3、4 尚未启动。阶段 2 若达不到接入门槛，需另行确认最终功能范围，不能自动降低双端验收标准。

## 可延后

小红书、YouTube、X、Instagram 等新平台批量接入；完整 UI 重做；音频提取、转码、水印等 Media Processing；iOS/macOS/Linux 正式支持；批量原子事务。Douyin 图文 production 在证据不足时同样延后。可先保留设计接口与研究记录，不承诺未验证能力。

详见 [架构](architecture.md)、[迁移](migration.md)、[研究](research/README.md)、[Windows 验收](acceptance/windows.md)、[Android 验收](acceptance/android.md)及[候选判定](acceptance/release-candidate.md)。
