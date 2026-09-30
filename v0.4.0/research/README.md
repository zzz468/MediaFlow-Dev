# v0.4.0 内容入口研究门槛

## 最新：Anonymous Static Gallery 参考验证停止（2026-09-30）

[完整结果与38项答复](anonymous-static-gallery-result.md)：最新ucmao固定源码的严格零凭据SSR分支有效观测0/5（仅1个当前人工确认样本），未达到production门槛。首轮运行器递归绑定缺陷已离线修正，首轮数据作废；实际请求合计10。现有242 passed / 6 skipped、analyze通过；production不改，保留原session RC READY，不发布，不恢复H2或其他研究路线。

## 最新：双平台 MAIN ENTRY GALLERY PASS / RC READY（2026-09-29）

[普通入口实现、42项答复与兼容性检查](gallery-main-entry-result.md)：默认ParserService、App-owned session动作与一次continuation已接通；双平台普通main真实UI、下载/系统打开、History、重启复用通过。15项新增测试，完整242 passed / 6 skipped，analyze与四种构建通过。限定当前验收范围，未发布、不执行Git写操作；暂停，不恢复H2。下文为历史。

## 最新：发布差距盘点 — NOT RELEASE CANDIDATE READY（2026-09-29）

[差距、正式 UX 方案与兼容性检查](gallery-release-gap-audit.md)：普通 factory 缺 Gallery/session glue，独立验收成功不等于普通用户流程完成。下一轮仅双平台普通入口闭环；不新增协议研究、signer 或路线。已有 core PASS 保留，后文为历史。

## 最新：ANDROID GALLERY PRODUCTION ACCEPTANCE PASS（2026-09-29）

[41项真实报告与兼容性检查](android-gallery-real-production-result.md)：目标单次detail200/62155bytes，13图/资源/任务，前2张真实下载并由用户确认系统图库正常且不同；History及session cold restore、最终profile删除通过，旧视频/Bilibili真实解析通过。analyze无问题，227 passed / 6 skipped，Debug/Release构建通过。DOUYIN STATIC GALLERY CORE IMPLEMENTATION COMPLETE；限定当前独立Debug入口与固定作品，不等于正式发布。暂停，H2永久冻结，不再扩展协议/研究路线。后文为历史。

## 最新：ANDROID SESSION ENTRY READY（2026-09-29）

[32项报告与兼容性检查](android-desktop-session-result.md)：官方Desktop metadata与UA配置出现正常PC扫码登录；三项最小session存在、Provider ready。restore本地重复挂载修复后cold restart复用及cleanup通过。Debug/Release、analyze与227 passed / 6 skipped回归通过，detail/下载0。暂停，下一轮仅Android真实Gallery验收；H2永久冻结。legacy platform仍Linux，不宣称所有身份属性等同Windows。后文为历史记录。

## 最新：Android session入口阻断，Release构建已修复（2026-09-29）

[30项结果与兼容性检查](android-session-entry-result.md)：未登录检查保持窗口已修复；正常移动首页及一次授权宽屏尝试均无网页登录入口。detail/下载0，profile清除与冷启动核验通过。Debug/Release构建通过，analyze无问题，227 passed / 6 skipped。未达到 ANDROID SESSION ENTRY READY；暂停，不恢复H2。后文为历史记录。

## 最新：Android正常session未完成，已暂停（2026-09-29）

[36项验收/安全与兼容性记录](android-gallery-acceptance-result.md)：独立Android Session Adapter编译与8项新增contract通过，全套223通过/6跳过。PJZ110当前API37；正常会话未成功，detail0/下载0，独立profile清理冷启动通过，正式MediaFlow未覆盖/卸载/清数据。Release构建失败已如实记录。下一轮只排查正常session入口，不重启H2或signer研究。

## 最新：Windows Gallery production spike PASS（2026-09-29）

[32项报告](windows-gallery-production-spike-result.md)：真实detail恰好2次，A403/46bytes，B唯一增加Argus兼容头后200/62141bytes；正常自有session取得目标13图，现有mapper/Downloader下载前2张，测试人员确认系统查看器正常显示且不同。profile清理通过，215通过/6跳过，analyze无问题。停止Windows任务，下一轮仅Android等价实现/验收，不恢复H2。

## 最新：Windows Gallery Backend ready for spike（2026-09-29）

[29项结果与兼容性检查](gallery-backend-candidate-result.md)：非Python最小backend、F2 Apache归属signer、Windows private session消费实现完成；31项新增测试，全套215通过/5跳过，analyze lib test与Windows Debug构建通过。真实detail=0、无网络A/B、无正式UI接入。下一轮只做Windows真实spike，H2永久冻结。

## 最新：Gallery集成架构与真实fixture离线映射完成（2026-09-28）

[架构](gallery-integration-architecture.md) / [29项结果](gallery-integration-result.md)：公共模型/mapper不改，13资源保持顺序并生成13个任务，18个新测试通过；在线backend未实现、spike未执行。自研H2永久冻结，旧“下一轮”仅历史。正常profile本轮清理空集/退出/删除通过；原F2默认placeholder的生产必要性仍UNKNOWN。

## 最新：原 F2 正常 session 实测通过；自研 H2 正式冻结（2026-09-28）

[完整验证报告](reference-project-validation-2026-09-28.md)：B — F2-SESSION-REQUIRED（限本次环境）。原 F2 返回目标 aweme_detail / type 68 / 13 张图及不同 URL；没有提供 UIFID，没有下载或测图片可达性。用户仅授权原项目自身默认头，不代表生产采用。自研 H2 状态为 `FROZEN — CURRENT WEB DETAIL PATH BLOCKED BY UIFID/CONTEXT GATE`，下文旧“下一轮”均为历史。停止第二候选和协议研究，下一轮只做 App-owned session UX + adapter / integration architecture；本轮暂停。

## 当前：2026-09-28 W3-2 — 两形状同UIFID gate

[W3报告](poc/h2/w3-dl-strategy-result.md)：当前DL调用链/精确差异先记录，18项query+DL headers（诚实UA/尺寸）无Cookie与正常session两次均403/46bytes/Uifid Not Found。没有signature或目标业务证据。硬止损：不再第四套Web-detail strategy，下一轮H2 go/no-go决策；正常profile清理通过，生产未改。

## 当前：2026-09-28 SCTX-2 — 正常 session context 仍不足

[实测报告](poc/h2/session-context-result.md)：正常自有profile sessionid/sessionid_ss/ttwid准入后执行唯一一次固定W2，HTTP403/46bytes/UIFID gate保持；无signature错误/JSON/gallery。不重复同类实验，signer冻结。初次secret目录权限失败后改memory/env，最终clear空集及profile删除通过；没有生产接入。

## 当前：2026-09-28 context composition / U1-U2 审计

[报告](poc/h2/context-composition-audit.md)与[静态snapshot](poc/h2/request-strategy-snapshot.json)：7源hash复核，F28/D18/M4签名前query比较。F2占位头是关键线索而非正常状态；没有单一因果/binding证明，无U2输入，网络0。推荐U1，不修改signer、不重开bootstrap，未取得业务JSON/gallery，完成后暂停。

## 当前：2026-09-28 capability / real research signer

[最新报告](poc/h2/capability-signer-audit.md)覆盖五项目矩阵、来源许可、真实算法测试、W1/W2 和 U1/U2 比较。UIFID 不是 H2 固定前置。14 Python 算法测试、44 Dart 契约通过；两次 detail 已执行，W2 明确 403 / Uifid Not Found，仍无 target/gallery、没有 signer 接受证据。此前 C5/H2-T5/42 项结果为历史记录；不据此继续登录、UIFID bootstrap 或 production integration。

## 最新：2026-09-28 授权正常交互 context 实测 C5

[本轮证据](poc/local-session/authorized-session-result.md)：用户在App自有全新隔离profile正常交互，challenge标记只暂停自动消费；用户自报完成交互/challenge，未确认登录。ttwid=true，UIFID=false，sessionid/sessionid_ss为空；没有E1/signature请求。C5仅指tested匿名Cookie scope缺必要context，不能写登录后无UIFID。清理已实测/独立复核。下一轮context来源/映射审计，signer冻结，production未改。

## 最新：2026-09-28 H2 transport 解耦验证 H2-T5

[本轮报告](poc/h2/transport-context-preflight.md)：分开 ContextProvider 建立能力与已有 context 下的 transport/data path。没有本轮明确提供、授权且可验证的 context；只检查四个候选进程输入存在性，没有读取浏览器或寻找 secret。真实 signer 未实现，旧 MOCK 仅离线 fixture。结果 H2-T5，E1/E2/E3 未执行，网络请求 0；不继续自动获取、bootstrap 或已关闭路线。后续等待测试人员安全提供本地输入，production 架构不变。

## 最新：2026-09-28 H2 架构与离线契约 PoC

[H2 完整报告](poc/h2/README.md)：三个平台隔离组件与 signer 许可矩阵已设计；[独立源码](poc/h2/h2_contract.dart)及[42 项离线测试](poc/h2/h2_contract_test.dart)通过。结果 H2-CONTEXT-BLOCKED 依据已有安全停止证据，本轮新平台请求 0；不是新的登录测试，也不是 signer/endpoint 被拒绝的证明。真实签名、目标 aweme_detail / images / URL 均未验证，production BLOCKED。下轮唯一目标为正常 App 自有 UIFID/context 前置验证；没有正常入口新证据则保持暂停，不重试 challenge 或重开匿名/Feed/Browser 内容解析。

## 最新：2026-09-28 横向审计决策 H2

五项目源码按入口聚类：Web detail 4、Share SSR 2；未发现正在使用的新 gallery endpoint。新 share/video 路径仅一次诚实通用 UA、无会话 GET，302/183 bytes，无嵌入 JSON，未跟随跳转。决策 H2：下一轮只设计 Session + license-safe signer + Web detail；不继续匿名旁路或关闭入口。当前图文成功仍未验证，production 未修改，Git 写操作无。本轮完成并暂停。

见 [完整横向报告](douyin-gallery-horizontal-audit-2026.md)。下文旧“下一步”仅为历史。

## 当前：通用UA单次排疑完成，Mobile Feed gallery关闭（2026-09-28）

新增授权的唯一snssdk Feed GET使用诚实应用UA MediaFlow/0.4.0，无Cookie/Token/signer/device/proxy；HTTP200/4其他作品/目标0，未下载媒体。结果Feed target lookup not reproduced under generic anonymous UA；reference M3控制流不变。没有严格复刻设备UA，不能解释平台内部因果；停止所有Feed追加实验。下一主路线为新的reference真实gallery入口横向审计，非自动恢复Web/UIFID/Browser/Login。本轮暂停。[本次报告及日志](poc/generic-feed-once-result.md)。以下为历史。

## 当前：Mobile Feed 控制流M3，网络实验未执行（2026-09-28）

当前reference ee05d757源码证实note/slides直接Web detail→SSR，不走Feed；Mobile Feed是常规视频主路径，不能从视频成功推出图库成功。参考UA包含设备身份声明，auto-review在启动前拒绝，Feed次数0，脚本CLI禁网保留离线检查。差异矩阵/10离线断言/analyze已完成；旧目标缺失因果未测。具体后续仅静态审计reference iesdouyin/share/video SSR入口与最小匿名条件，不自动恢复Web/UIFID/session/Browser，不开始signer。见[完整结果](poc/mobile-feed-target-result.md)、[离线审计](poc/mobile-feed-target-audit.md)。本轮暂停，以下是历史。

## 当前：Local Session / Context Provider PoC，S4会话入口阻断（2026-09-28）

独立research契约+Windows可见会话窗口完成，10条离线断言/编译通过；profile仓库外且最小Cookie读取，真实安全停止后native清除/进程退出/精确删除均实测。唯一首页导航遇WAF，正常登录未完成、UIFID未得、detail未请求，不能伪报登录后context缺失。Android条件设计未取代双端实测门槛。匿名bootstrap A4保留，不继续生成逆向；Observation仍非主Parser。见[完整结果](poc/local-session-audit.md)与[设计/字段准入](poc/local-session/README.md)。本轮暂停，不重开入口、不研究signer。下文为历史。

## 当前：首次匿名 UIFID bootstrap RESULT A4（2026-09-28）

独立全新 WebView2 profile 通过空origin Cookie/localStorage/sessionStorage/IndexedDB验证；仅首页导航即触发WAF challenge资源，阻止并结束，未进入note/detail。未完成正常SDK初始化，不能据此判断登录、JS或signer必需。已验证浏览器进程退出并精确删除本轮profile。media-parser仍仅证明已有UIFID消费，首次生成链未取得。唯一缺失证据：无挑战正常匿名初始化中的首次UIFID发行/写入事件及响应/JS调用点；后续仅围绕此静态定位，不重复WAF导航。见[完整报告](poc/uifid-bootstrap-audit.md)与[候选矩阵/独立探针](poc/uifid-bootstrap/README.md)。Browser Observation保持非主路线；本轮暂停。下文为历史状态。

## 当前：UIFID 上下文审计与规则定版（2026-09-27）

结果A限请求侧来源定位：UIFID取已有Cookie/session/页面SDK上下文并映射header/query，不是A-Bogus输出；平台首次生成机制与匿名/账号必要性未证实。正式HTTP已有bootstrap，但白名单不保留UIFID。唯一新HTTP首页实验200/72914bytes、无UIFID/UIFID_TEMP、命中安全标记，停止，无detail/登录/signer。按产品所有者指令修改根AGENTS.md及研究规则，允许匿名优先、本地signer、App自有用户主动登录fallback；不放宽挑战/权限/隐私边界。下一轮优先可信UIFID上下文来源与生命周期设计，不先逆向signer、不恢复Browser主路线。完整矩阵、来源、结果与检查见[poc/uifid-context-audit.md](poc/uifid-context-audit.md)。下文上轮规则冲突说明保留为历史，登录fallback绝对禁令已被本轮定版替代。

## 当前主路线：Web detail + 本地 signer（2026-09-27）

本轮指令取代下面旧“确认降级范围”的下一步建议。Browser Observation = **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**；保留全部代码与证据，不扩展、不默认启动WebView。独立匿名baseline实际403/46bytes，Argus UIFID安全拒绝；按AGENTS.md停止入口，B/C未执行。没有证明只缺signer或session，也未证明完整参考路线失效，附件四类结果门槛尚不能满足。

请求链/文件级许可证冲突/规则冲突/共享Dart与模型设计/检查结果见[本轮审计](poc/web-detail-signer-route-audit.md)。本地签名不是全面禁止；登录Cookie实验仍与AGENTS.md冲突。production BLOCKED，未改正式代码、未下载图片。后续优先离线审计signer协议和许可，不回Browser、不自动生产接入。以下各节保留为历史状态。

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

桥接是否实际运行、Coordinator重入原因NOT VERIFIED，不能宣布双平台共同达到Browser研究边界。剩余合法候选NOT TESTED：先离线验证重入/Worker复用保护和document-start桥接健康；本轮不再请求真实目标。[证据、命令与文件]( poc/android-public-target.md )。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不进入第三阶段。

## 历史：Android 离线安全停止闭环（2026-09-27）

PJZ110 连续两次 securityFixture operation PASS（328ms / 285ms）：页面已加载、活动清理被拒绝，安全事件与同步观察取消同毫秒；六类离线消费替身计数停止后不增、排队任务消费0，Worker退出后Coordinator自动删除精确profile/cache/metadata/marker。Android离线安全停止PASS仅限受控模型，真实检测器/响应/decoder尚未验证；lifecycle A保持限定PASS。原3个历史cache及5个空metadata目录未删除，研究App storage不为0。Windows各结论保持，Android Network/production BLOCKED，真实结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。剩余候选NOT TESTED：Android最小真实目标安全停止/数据入口实验，下一轮单独决定，本轮不运行。

详细证据、时间线、文件和命令：[本轮离线安全停止记录](poc/android-offline-security-stop.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，不进入真实网络、production或第三阶段。

## 历史：Android Worker 自动清理（2026-09-27）

最终独立 Worker/Coordinator 真机连续两次 operation 自动闭环 PASS（544ms/363ms），活动实例清理拒绝 PASS，operation profile/cache/no_backup/marker 均清除。Android lifecycle A PASS 仅限最终正常离线研究模型；历史 prototype 缓存/空目录因 marker 已删保留，研究 App 整体 storage 不为0、历史残留清理 BLOCKED，不能宣称全部浏览器状态已清理。安全停止 NOT TESTED，Network/production BLOCKED；Windows 原 normal cleanup FAIL/root cause NOT VERIFIED 保持，recovery 限历史 PASS。Human PASS、目标结构/URL NOT VERIFIED、下载 NOT TESTED。详情见 browser-observation-feasibility.md 最新节。本轮未真实网络、未改 production、未新增生产依赖/未 Git 写操作。暂停。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 历史：Android gate A / Windows cleanup 定位（2026-09-27）

PJZ110 真机独立无网络 Debug 包已实测：WebView加载/destroy成功，但 loaded profile 在原进程 deleteProfile 抛 IllegalStateException，Android lifecycle BLOCKED，gate B/C未运行。新进程精确profile删除成功不覆盖自动生命周期失败；独立 worker 退出后的自动闭环仍为合法离线候选，NOT TESTED。Windows 本地重定向拒绝自动cleanup PASS，但原share FAIL未复现、根因未确认，normal cleanup仍FAIL；数据入口边界保持BLOCKED。结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED，Human PASS保持。详见[本轮记录](poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文为历史状态。

## 最新：share/note 候选验证（2026-09-27）

一次全新匿名研究会话在 2870ms 重定向 www.douyin.com /note/<id>，2875ms 拒绝继续；候选 BLOCKED，无 hydration/目标 JSON。Windows Browser Observation 在当前项目安全约束下已到达本阶段研究边界。本次自动 cleanup FAIL，helper 已退出后按本轮精确路径清理，最终 profile 根 0；此前受控 cleanup/recovery PASS 仍仅限历史已测范围，完整生命周期 NOT VERIFIED。Android 当前有 PJZ110 设备，runtime 仍 NOT TESTED；Level 1H Human PASS、结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED 保持。详见[本轮证据](poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文“share 尚未执行 / 无 Android 设备”等为历史状态。

## 最新：第二阶段收口判断（2026-09-27）

本轮源码审计未发现安全停止前合法数据漏消费；离线 recovery 九条断言 PASS，新增活动锁与 abandoned mutex 检查。研究生命周期达到当前受控范围，完整 production 生命周期 NOT VERIFIED。已测 /note Network BLOCKED；独立公开 share/note 入口停止前 hydration 尚有合法候选，NOT TESTED，本轮未运行。Android 无设备 NOT TESTED，结构/URL NOT VERIFIED，下载 NOT TESTED，production BLOCKED。详见[收口记录](poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停；后文为历史记录。

最新第二阶段：[recovery 边界实测](poc/browser-observation-feasibility.md)完成。本轮仅离线研究，v2 marker 字段/内部归属、PID 创建时间分支、活动实例拒绝、stale/active 分离及同 session 两 recovery 互斥均有实际证据。真实 PID 重用、双 WebView2 helper、断电/跨 session/完整 marker 伪造仍未验证。目标结构与图片 URL NOT VERIFIED、下载 NOT TESTED；Network BLOCKED，完整窗口 NOT VERIFIED；Android NOT TESTED / production feasibility BLOCKED。保留第二阶段，不把 cleanup PASS 当作 production PASS；后文旧结论为历史记录。

最新子阶段：[Browser 事件 / 硬杀研究](poc/browser-observation-feasibility.md)。本轮事件定位到成功导航前的安全资源检测，保留即时停止，不能断言页面无结构；完整目标窗口 NOT TESTED。离线硬杀后残留目录在下次独立启动按精确归属 marker 回收 PASS，活动 profile 保护 PASS。Android 仍 BLOCKED/NOT TESTED，无新平台支持。后文上一轮结论是历史证据。

第一阶段首轮调查已记录于[结论](stage1-conclusion.md)、[候选路线矩阵](douyin-gallery-route-matrix.md)及各项目独立研究页。**第二阶段仍在进行。** [上一轮独立 PoC](poc/stage2-douyin-gallery.md)的 Windows 匿名 HTTP 候选未取得目标作品；[本轮样本确认](poc/verified-samples.md)已取得 Level 1H，测试输入阻断解除；有效输入上的 feed、原始 HTML、无签名 Web detail 仍无目标结构。[Browser Observation 独立研究](poc/browser-observation-feasibility.md)已运行 Windows 三种 cleanup 夹具及目标单次匿名导航；cleanup 通过，目标 browserVerification 安全停止，无图文结构；Android production feasibility=BLOCKED。Android 无设备未验证。**仍无 v0.4.0 双端匿名图文成功证据。**

第二阶段及后续平台研究统一执行[研究规则](execution-rules.md)，逐个重点项目使用[记录模板](reference-project-template.md)。本页保留入口研究的简要门槛；若表述不同，以根目录 `AGENTS.md` 和研究规则中的更具体证据要求执行。

优先复核 [v0.3.0 Douyin 图文调查](../../v0.3.0/research/douyin-gallery-source.md)：当时 Windows 匿名入口未取得目标作品完整图片，Android 未完成同等探测，因此不具备 production 依据。旧候选链接和第三方项目只能作线索，不能当作当前可用性结论；第一阶段访问了 GitHub 参考源码，但**未重新请求 Douyin 平台**。

后续仍需完成的最小验证：使用已准入 Level 1H 样本并补充第二样本，在 Windows 和 Android 分别记录目标作品 ID、图片数量与顺序、原始响应位置、匿名可访问图片 URL、MIME、实际文件及链接时效。第二阶段两个 `/note/` 候选的图片数量尚未确认，不计为已验证多图样本。重复图片按出现位置记资源。遇到登录、验证码、付费、地区、权限或安全验证即停止该入口，不使用用户登录态、设备指纹伪造、挑战求解、高频重试或地区代理。

评估每条路线时记录：技术可行性、稳定性、双端成本、页面变更风险、会话生命周期、用户隐私、长期维护、依赖与许可证。生产门槛为：双端独立匿名证据、可在平台模块内实现、离线异常契约、真实 GUI 下载/打开/History 验收方案均具备。研究或 PoC 成功仍需独立 production 验收。

若门槛不满足，保留 Douyin 图文为 `researched but not production-supported`，不把安全限制当作待绕过的 Bug。再从其他公开内容入口或多资源稳健性工作中选定可交付范围；任何新平台同样适用双端与隐私门槛。
