# 第二阶段：Douyin 图文独立 PoC（2026-09-25）

## 当前研究方向更新（2026-09-27）

主路线 **Web detail + 本地 signer**；Browser **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**，不扩展。目标7690029886242009957的新匿名baseline403/46bytes/Argus UIFID安全停止，无detail/images/URL，B/C未测试，session必要性未验证；生产仍BLOCKED。新附件A–D完整分类证据均未满足，不与下文旧结果C混淆。见[本轮完整审计](web-detail-signer-route-audit.md)，旧降级下一步建议被替代，全部历史证据保留。

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

桥接是否实际运行、Coordinator重入原因NOT VERIFIED，不能宣布双平台共同达到Browser研究边界。剩余合法候选NOT TESTED：先离线验证重入/Worker复用保护和document-start桥接健康；本轮不再请求真实目标。[证据、命令与文件]( android-public-target.md )。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不进入第三阶段。

## 历史：Android 离线安全停止闭环（2026-09-27）

PJZ110 连续两次 securityFixture operation PASS（328ms / 285ms）：页面已加载、活动清理被拒绝，安全事件与同步观察取消同毫秒；六类离线消费替身计数停止后不增、排队任务消费0，Worker退出后Coordinator自动删除精确profile/cache/metadata/marker。Android离线安全停止PASS仅限受控模型，真实检测器/响应/decoder尚未验证；lifecycle A保持限定PASS。原3个历史cache及5个空metadata目录未删除，研究App storage不为0。Windows各结论保持，Android Network/production BLOCKED，真实结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。剩余候选NOT TESTED：Android最小真实目标安全停止/数据入口实验，下一轮单独决定，本轮不运行。

详细证据、时间线、文件和命令：[本轮离线安全停止记录](android-offline-security-stop.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，不进入真实网络、production或第三阶段。

## 历史：Android Worker 自动清理（2026-09-27）

最终独立 Worker/Coordinator 真机两次 operation 自动闭环 PASS（544ms/363ms），活动实例清理拒绝 PASS，operation profile/cache/no_backup/marker 均清除。Android lifecycle A PASS **仅限最终正常离线研究模型**；历史 prototype 缓存/空目录因marker已删保留，研究App整体storage不为0、历史残留清理BLOCKED，不能宣称全部浏览器状态已清理。安全停止NOT TESTED，Network/production BLOCKED；Windows原normal cleanup FAIL/root cause NOT VERIFIED保持，recovery限历史PASS。Human PASS、目标结构/URL NOT VERIFIED、下载 NOT TESTED。详情见 research/poc/browser-observation-feasibility.md 最新节（从子目录按相对路径定位）。本轮未真实网络、未改production、未新增依赖/未Git写操作。仅第二阶段并暂停；后文为历史记录。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 最新：Android gate A / Windows cleanup 定位（2026-09-27）

PJZ110 真机独立无网络 Debug 包已实测：WebView加载/destroy成功，但 loaded profile 在原进程 deleteProfile 抛 IllegalStateException，Android lifecycle BLOCKED，gate B/C未运行。新进程精确profile删除成功不覆盖自动生命周期失败；独立 worker 退出后的自动闭环仍为合法离线候选，NOT TESTED。Windows 本地重定向拒绝自动cleanup PASS，但原share FAIL未复现、根因未确认，normal cleanup仍FAIL；数据入口边界保持BLOCKED。结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED，Human PASS保持。详见[本轮记录](browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文为历史状态。

## 最新：share/note 候选验证（2026-09-27）

一次全新匿名研究会话在 2870ms 重定向 www.douyin.com /note/<id>，2875ms 拒绝继续；候选 BLOCKED，无 hydration/目标 JSON。Windows Browser Observation 在当前项目安全约束下已到达本阶段研究边界。本次自动 cleanup FAIL，helper 已退出后按本轮精确路径清理，最终 profile 根 0；此前受控 cleanup/recovery PASS 仍仅限历史已测范围，完整生命周期 NOT VERIFIED。Android 当前有 PJZ110 设备，runtime 仍 NOT TESTED；Level 1H Human PASS、结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED 保持。详见[本轮证据](browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文“share 尚未执行 / 无 Android 设备”等为历史状态。

## 最新：第二阶段收口判断（2026-09-27）

本轮源码审计未发现安全停止前合法数据漏消费；离线 recovery 九条断言 PASS，新增活动锁与 abandoned mutex 检查。研究生命周期达到当前受控范围，完整 production 生命周期 NOT VERIFIED。已测 /note Network BLOCKED；独立公开 share/note 入口停止前 hydration 尚有合法候选，NOT TESTED，本轮未运行。Android 无设备 NOT TESTED，结构/URL NOT VERIFIED，下载 NOT TESTED，production BLOCKED。详见[收口记录](browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停；后文为历史记录。

最新第二阶段：[recovery 边界实测](browser-observation-feasibility.md)完成。本轮仅离线研究，v2 marker 字段/内部归属、PID 创建时间分支、活动实例拒绝、stale/active 分离及同 session 两 recovery 互斥均有实际证据。真实 PID 重用、双 WebView2 helper、断电/跨 session/完整 marker 伪造仍未验证。目标结构与图片 URL NOT VERIFIED、下载 NOT TESTED；Network BLOCKED，完整窗口 NOT VERIFIED；Android NOT TESTED / production feasibility BLOCKED。保留第二阶段，不把 cleanup PASS 当作 production PASS；后文旧结论为历史记录。

## 最新：事件定位 / 硬杀回收

[本轮研究](browser-observation-feasibility.md)确认新目标会话在成功导航前检测安全资源并停止，无候选 JSON；不延长安全验证后的观察，与 AGENTS 第十/十五条冲突的部分未执行。不能推断页面没有结构化数据。离线正常 cleanup PASS；硬杀留下 UDF，活动 profile 回收被拒绝，关联 WebView2 退出后下一次独立启动通过精确 marker 回收，Hard-kill recovery PASS（研究范围）。完整目标观察窗口 NOT TESTED，Android BLOCKED/NOT TESTED；Level 1H 与机器/下载状态不变。第二阶段暂停，无 production 接入。后文 B 与旧“硬杀未测试”为历史状态。

## 最新子阶段：Browser Observation（2026-09-27）

[独立可行性研究](browser-observation-feasibility.md)已完成：Windows 新建 InPrivate profile，正常退出、加载失败、主动取消均实际完成 cleanup；目标 Level 1H note 单次加载触发 browserVerification，安全停止并清理，无目标图文结构或图片。Human PASS、Machine/Structured NOT VERIFIED、Image download NOT TESTED 保持。Android 技术审计仍有已加载 profile 删除与强杀残留风险，production feasibility=BLOCKED；adb 无设备，runtime NOT TESTED。

**结论 B：Windows Browser Observation 技术可行，但尚未取得目标图文结构，第二阶段继续研究。** Windows 生命周期测试不是 production 准入；异常关闭回收未验证。未修改 production、未进入第三阶段。下面 HTTP 结论 C 保留为此前子阶段证据，不再重复这些 HTTP 请求。

## 2026-09-27：Level 1H 有效样本上的匿名路线实测

本节是当前状态，后文旧轮次结论保留为历史记录。样本 `7690029886242009957` 保持 Level 1H，Human verified **PASS**；测试输入阻断已解除。Machine image verification、Structured data verification **NOT VERIFIED**，Image download verified **NOT TESTED**。

### Windows 实际请求

独立运行 `douyin_gallery_probe.dart 7690029886242009957` 一次，退出码 0 仅表示检查完成。脱敏输出见 [本轮运行日志](stage2-level1h-windows.log)。所有请求均直接 HTTPS，无 Cookie、账号 Token、登录态、动态签名或第三方解析服务器；Set-Cookie 只记录存在性，不保存或回传。

| 路线 | 当前响应 | 目标结果 |
| --- | --- | --- |
| mobile feed：`api5-normal-c-hl.amemv.com/aweme/v1/feed/?aweme_id=7690029886242009957&aid=1128` | 200 application/json；373623 字节；status_code=0；aweme_list=6；无重定向/Set-Cookie | 无精确目标对象，也无目标 ID 关系引用 |
| 原始 `www.douyin.com/note/7690029886242009957` | 200 text/html；72914 字节；无重定向；返回 Set-Cookie 未使用 | 无目标 ID；JSON 根 1；无 canonical、OG image、JSON-LD 或已检查 hydration 标记；无目标结构 |
| 原始 `www.iesdouyin.com/share/note/7690029886242009957/`，标准 Android Mobile UA | 200 text/html；33478 字节；无重定向/Set-Cookie | JSON 根 4，canonical 标签 1；仅 _ROUTER_DATA 路由引用目标；无作品媒体对象 |
| Web detail：`www.douyin.com/aweme/v1/web/aweme/detail/?aweme_id=7690029886242009957&aid=6383&device_platform=webapp` | 403 text/plain；46 字节；无重定向/Set-Cookie | **匿名无签名 Web detail 当前不可直接使用**；立即停止，没有扩大参数或签名研究 |

feed 返回的主要 aweme_id（按响应顺序）：
`7686092475471436793`、`7681948635123572901`、`7682760490183190758`、`7689740486333104506`、`7684908169365914597`、`7686050815954773428`。
六项 aweme_type 均为 0；group_id 与各自 aweme_id 相同，统计/状态 ID 也对应各自作品。已检查 item_id/group_id/来源或转发等 ID 关系，没有目标引用。image_post_info 不存在；images、images_v2 与 post 图片列表均未取得数组（images 键存在但值为 null）。该入口对请求目标 aweme_id **不具备本次可证明的可靠定向返回能力**，不再反复重试；未做控制实验，不推断参数对推荐结果的因果作用。

分享页目标仅在 `loaderData.note_(id)/page.lastPath`、`commonContext.lastPath`、`itemId`。这些是路由壳数据，不是 aweme_detail/image_post_info/images。JSON-LD、RENDER_DATA、__UNIVERSAL_DATA_FOR_REHYDRATION__ 未找到；OG image 标签 0。只读 JSON/已支持编码解析未执行 JS，因此不证明浏览器运行后一定没有数据。403 也不能证明哪个签名或会话参数必需。

### 图片与双平台证据

目标结构化对象未取得；目标图文类型、有序图片数组及实际图片数量未取得。已提取目标图片 URL **0**，不是作品真实图片数。图片 GET **0 次**；至少两个不同资源、下载状态/MIME/Content-Length/字节数/文件头/解码/内容差异/图片重定向均 **NOT TESTED**。

`adb devices -l` 仅输出 `List of devices attached`，无设备；Android PoC **NOT TESTED**。未构建或安装 APK，没有覆盖、卸载或清除应用数据。

### Browser Observation 前置条件评估（未启动）

仅在上述 HTTP 路线结束后阅读已有本地源码。Windows helper 为每轮生成 GUID profile，启用 InPrivate，退出时检查 profile 路径前缀后尝试删除并报告 profileCleaned；这是源码设计证据，**不是本轮实际隔离/cleanup 成功证据**。现有 Dart adapter 导航校验只接受目标 `/video/<id>`，不能直接充当 note PoC。Android installed adapter 明确因 named-profile cleanup 尚不安全返回 null；原生代码虽有 deleteProfile 和失败计数，但本轮没有设备证据解除该风险。未使用用户浏览器、未启动 Browser Observation、未改 production adapter。后续若继续该候选，须先在独立研究环境证明 note 导航、匿名 profile 生命周期与清理能力。

### 当前 production 前置门槛

| 门槛 | 状态 |
| --- | --- |
| #1 独立目标结构 / #2 精确目标对应 / #8 Windows 完整 PoC | **FAIL**（本轮有效输入上实际请求未取得目标） |
| #3 图文类型 / #4 有序数组 / #5 两个资源 / #6 两图下载 / #7 图片真实性 | **NOT TESTED**（无目标结构可继续验证） |
| #9 Android / #15 独立成功路线可实现性 | **NOT TESTED** |
| #10 无登录 Cookie / #11 无账号凭证 / #12 无第三方解析 / #13 无 MITM、代理截获、请求重放 / #14 遵守项目边界 | **PASS**（仅已执行的研究范围） |

### 脚本与验证

只改研究探针：share/note 移动 UA、固定 Web query、逐项 ID/字段形态诊断、只读 script JSON/已知 hydration 编码检查及 images_v2 检查。无第三方代码复用、无新增依赖；不修改正式 Parser、模型、下载、History 或 UI。探针仅使用 Dart 标准库，Windows 已实际运行；Android 未测试；iOS/macOS/Linux 未构建、未实测，标准库设计不构成平台功能通过证据。

执行命令：`D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe analyze v0.4.0/research/poc/douyin_gallery_probe.dart v0.4.0/research/poc/verify_public_sample.dart`，结果见本轮最终汇报。未运行 flutter analyze、flutter test、Windows build、Android build；未执行正式平台验收。研究检查不替代已发布功能回归。

**结论 C：有效多图样本上的匿名路线仍未取得目标结构化数据，继续停留在第二阶段。** 不进入第三阶段，不声明图文已支持。保留 Level 1H，后续继续独立 PoC；不重复本轮无定向命中的 feed 或相同无签名 403 请求。

---


## 历史记录：准入规则修正及此前各轮（当前结果见上节）

**此前 Level 1 定义要求匿名机器提取图片证据，与第二阶段要验证的解析能力形成循环依赖，因此将样本真实性与解析能力拆分。** 新定义见[分层证据与样本等级](verified-samples.md)：Level 1H 允许当前人工直接观察确认真实公开多图输入；Level 1M 是更强的匿名机器证据，非开工前置条件；Level 2 为目标结构化 PoC 结果。下文旧“无机器图片证据所以不得开始 PoC”的表述仅保留为历史记录，不再适用。

用户于 2026-09-27 明确确认当前客户端可正常查看公开图文作品 `7690029886242009957`，实际看到了至少两张不同图片，实际为多张不同照片。该样本现为 **Level 1H — Human-verified current multi-image sample**，Human verified: **PASS**；Machine image verification: **NOT VERIFIED**；Structured data verification: **NOT VERIFIED**。先前 Anonymous HTML structured data: NOT FOUND、image_post_info/images 与匿名图片 URL 提取 NOT VERIFIED 的事实保持不变。

**已取得一个当前人工确认的公开多图样本（Level 1H），第二阶段测试输入阻断解除。下一轮可以恢复匿名路线 PoC；机器结构化验证仍为 NOT TESTED。** 此处 NOT VERIFIED 描述未证实的机器能力，NOT TESTED 描述针对有效多图输入尚未执行完整结构化 PoC，两者都不是通过。仅允许**下一轮**恢复研究；本轮只更新状态，不执行网络 PoC、feed、Web detail、Browser Observation 或 production 工作。以下无合格样本的旧结论均为历史状态，不再代表当前样本准入。

> 2026-09-27 仅样本准入续查：新增两个有公开来源的 Level 0 候选页面检查，均仅取得路由 ID、无目标图片证据；历史十图候选不升级。合格样本仍为 0，未恢复路线 PoC，详见[最新样本分级](verified-samples.md)。

> **续研状态（2026-09-25）：第二阶段仍在进行，尚未满足 production 门槛。** 后续优先补充了[样本确认记录](verified-samples.md)：找到第三方公开复现的十图历史作品，匿名短链当前仍能到达目标路由，但原始移动分享页仅有路由 `itemId`、无媒体/图片结构，故当前公开多图样本尚未确认。本轮遵守样本门槛，在此停止，没有重新运行下文的 feed/Web detail。下文是**上一轮 Windows 实测**，不能误读为本轮新结果。

**当前有效 production 门槛状态：**由于尚无已确认“当前公开且至少两图”的测试输入，数据链路与双端成功项 #1–9 均记为 **NOT TESTED**；边界合规项 #10–14 在已执行的研究请求范围内为 **PASS**；独立成功路线可实现性 #15 为 **NOT TESTED**。下文原矩阵的 #1、#2、#8 `FAIL` 仅描述上一轮对未确认多图的两个候选 ID 的实际请求失败，**不构成对有效多图样本的生产准入判定**。

## 证据边界与结论

本页仅记录 **MediaFlow 自行运行的 PoC**。第一阶段的第三方源码线索见[路线矩阵](../douyin-gallery-route-matrix.md)，旧版调查见[v0.3.0 记录](../../../v0.3.0/research/douyin-gallery-source.md)，均不计为本轮成功证据。

上一轮结论 **C：当时实际尝试的候选路线未能独立复现目标图文结构化结果，仍未达到 production 接入门槛。** 这不证明公开匿名路线永久不存在。没有取得目标图文对象、两张图片 URL 或真实图片下载；Android 没有可用设备。未进入 production，也未宣称 Douyin 图文已支持。当前仍需先取得确证为多图且当前公开可访问的样本，并解决双端验证条件。

## 样本

| 原始公开候选 URL | 目标 ID | HTTP 最终 URL | 选择理由与限制 |
| --- | --- | --- | --- |
| https://www.douyin.com/note/7679016640391062705 | `7679016640391062705` | note 请求保持原 URL；`iesdouyin.com/share/video/<id>` 跳至 `www.douyin.com/video/<id>` | 公开搜索索引中的 `/note/` 候选；**图片数量未确认**，匿名原始页面没有目标作品数据 |
| https://www.douyin.com/note/7680412682671111578 | `7680412682671111578` | 同上 | 第二个不同作品的公开 `/note/` 候选；**图片数量未确认**，不能称为已验证多图样本 |

两个 URL 是公开候选输入，不能把 `/note/` 路径或搜索摘要本身当作图文类型证明。没有使用私人作品或用户提供的账号内容。本轮未能满足“至少两个已确认多图样本”，后续须补齐。

## 隔离设计与命令

[探针](douyin_gallery_probe.dart)是独立 Dart 标准库脚本，不导入 Flutter 工程、不修改正式 Parser。所有请求为直接 HTTPS GET，`findProxy = DIRECT`，不发送 Cookie、Token 或账号凭证；禁自动重定向，手动最多两跳且限定已知平台/CDN 域名；每个响应 15–20 秒超时，结构响应 2 MiB 上限，图片 20 MiB 上限。没有保存完整响应、图片、Cookie 或媒体 URL。即使服务器返回 `Set-Cookie`，也只记录布尔值，不保存或发送。脚本仅在**精确匹配结构化 `aweme_id`**并提取前两项不同图片 URL 后才尝试真实完整 GET、MIME/文件头及字节差异检查；路由上的 ID 不算目标命中。

```powershell
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' 'v0.4.0\research\poc\douyin_gallery_probe.dart' 7679016640391062705 7680412682671111578
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'v0.4.0\research\poc\douyin_gallery_probe.dart'
& 'D:\Android\Sdk\platform-tools\adb.exe' devices -l
```

第一次在受限沙箱运行时，八次请求均为 `SocketException`，不作为平台失败证据。经允许的直接网络环境以同一命令运行一次后，取得下表 HTTP 证据；随后仅为补充脱敏响应形态诊断，再对相同两个样本运行一次。探针 exit code 0 只表示执行完成，不代表路线成功。`dart analyze` 为 `No issues found!`。`dart format` 完成；其读取根目录 `analysis_options.yaml` 时提示未解析 `flutter_lints`，不影响该独立脚本格式化，但不把它当成完整项目 analyze。

## Windows：逐路线实测

| 路线 | 请求与参数 / headers | 两个样本的实际结果 | 判定 |
| --- | --- | --- | --- |
| 匿名移动 feed | `GET https://api5-normal-c-hl.amemv.com/aweme/v1/feed/?aweme_id=<id>&aid=1128`；`Accept: application/json`、`User-Agent: MediaFlow/0.2.0 (anonymous local HTTP client)` | 均 `200 application/json`，无跳转/`Set-Cookie`；`status_code=0`，`aweme_list` 分别 6、5 项，响应 396283、331017 字节；递归扫描没有精确目标图文对象，图片 0 | **目标缺失**；200 和非空推荐列表不是目标作品成功 |
| `/note/` 原始 HTML | `GET https://www.douyin.com/note/<id>`；`Accept: text/html`、研究用 `User-Agent` | 均 `200 text/html`、72914 字节、无跳转；收到 `Set-Cookie` 但未发送。HTML 中无目标 ID、`_ROUTER_DATA`、`RENDER_DATA`、`__UNIVERSAL_DATA_FOR_REHYDRATION__`、`image_post_info` 或 `aweme_detail` 标记；解析不到目标结构 | **仅 HTML/路由入口**；不把 200 当作媒体数据。未运行页面 JS |
| 移动分享页 HTML | `GET https://www.iesdouyin.com/share/video/<id>`；同类 HTML headers | 均重定向至 `https://www.douyin.com/video/<id>`，最终 `200 text/html`、72914 字节；收到 `Set-Cookie` 但未发送；无上述目标/结构标记 | **分享入口无可用原始结构数据**；重定向路径 ID 不算媒体匹配 |
| Web detail 最小公开参数 | `GET https://www.douyin.com/aweme/v1/web/aweme/detail/?aweme_id=<id>&aid=6383`；`Accept: application/json`、研究用 `User-Agent` | 两个样本均 `403 text/plain`、46 字节、无跳转/`Set-Cookie`；收到 403 即停止该入口 | **被拒绝**；本请求未带 `msToken`、`A-Bogus`、`X-Bogus`、`verifyFp`、Cookie，不能从 403 推断哪个动态项必需；没有尝试伪造参数或挑战求解 |

上述 6/5 项与字节数来自补充诊断的第二次执行；首次直接网络运行分别为 feed 379540/402782 字节，但同样无精确目标。两次结果都未出现可验证图片。脚本当前对 HTML 仅解析原始 `<script>` JSON 和列出的标记，不执行 JS；因此“原始响应无可用结构”并不等于“浏览器运行后也一定没有”。

### 下载与内容证据

结构化目标：**未取得**。图文类型标记：**未取得**。图片数组字段路径：**未取得**。有序图片 URL：**0**。两张不同资源：**未取得**。匿名完整图片 GET：**0 次**。MIME、Content-Length、实际图片字节、JPEG/PNG/WebP/GIF/AVIF 文件头及两张内容差异：**未测试**，不能虚构证据。

## Browser Observation 与 Android

HTTP 候选均未达门槛后，评估了 Browser Observation；**本轮未执行**。已有 [v0.3.0 调查](../../../v0.3.0/research/douyin-gallery-source.md)指出 Android 旧浏览器观察路径存在匿名隔离/cleanup 风险。当前没有经证明可清理且双端一致的全新匿名浏览器环境，也没有可用 Android 真机；不能用现有用户浏览器 profile 或旧 production 路线替代独立 PoC。它仍是待验证候选，不是本轮失败实测，更不是安全限制绕过建议。

`adb devices -l` 输出仅 `List of devices attached`，没有设备。**Android PoC 未执行**，无 package/applicationId 或已安装 MediaFlow 的可核验对象；未构建、未安装 APK，未覆盖、卸载或清除数据。Windows 失败也不能推断 Android 一定失败；Android 的真实阻断是设备缺席。

## production 前置门槛逐项核对

| # | 条件 | 本轮状态 | 证据 |
| --- | --- | --- | --- |
| 1 | MediaFlow 独立取得目标图文结构 | FAIL | 四条 HTTP 路线无目标对象 |
| 2 | 结构与输入目标精确对应 | FAIL | feed 推荐列表未命中；HTML 只有入口路径 |
| 3 | 可靠识别图文 | NOT TESTED | 无目标结构可判类型 |
| 4 | 提取有序图片数组 | NOT TESTED | 无目标图片字段 |
| 5 | 至少两个不同图片资源 | NOT TESTED | 0 个已验证资源 |
| 6 | 至少两张匿名真实下载 | NOT TESTED | 未触发图片 GET |
| 7 | MIME/文件头真实图片 | NOT TESTED | 无图片响应 |
| 8 | Windows 独立 PoC 成功 | FAIL | Windows 已实测，完整链路未成立 |
| 9 | Android 独立 PoC 成功 | NOT TESTED | `adb devices -l` 无设备 |
| 10 | 不使用登录 Cookie | PASS | 探针始终清除 Cookie 请求头；收到的 Set-Cookie 未使用 |
| 11 | 不使用账号凭证 | PASS | 脚本无账号/凭证输入 |
| 12 | 不使用第三方解析服务器 | PASS | 仅直连 Douyin 平台入口；无解析服务 |
| 13 | 不使用 MITM/代理截获/用户请求重放 | PASS | `DIRECT`、独立 GET，无用户请求重放 |
| 14 | 不违反 AGENTS.md 与研究规则 | PASS | 本轮脚本和请求遵守边界；遇 403 停止；无正式接入 |
| 15 | 可由 MediaFlow 独立实现，无须复制不适合代码 | NOT TESTED | 探针原创且仅标准库，但尚无成功数据路线可评估 production 实现 |

## 后续阻断与范围

1. 用平台可公开核实的方式取得至少一个、最好两个**图片数确认为两张以上**的作品样本，并在研究记录中注明确认方法；不能靠 URL 路径推断。
2. 对能提供目标结构的匿名入口做有限、独立、双端验证；如仅浏览器运行后有数据，先设计全新匿名 profile、会话生命周期和 cleanup 证据，再实施本地观察。遇登录、验证码或安全验证即停止。
3. 准备 Android 设备后先按根目录 `AGENTS.md` 核对已安装包、applicationId、签名与数据安全；优先无需安装 APK 的隔离验证。未满足双端硬门槛之前，Douyin 图文保持 `researched but not production-supported`。

本轮**未改正式代码，未新增依赖，未运行 `flutter analyze`、自动化测试、Windows build、Android build 或真实平台验收**。这些检查与正式生产接入属于后续阶段；当前脚本通过独立 `dart analyze` 并实际执行网络请求。
