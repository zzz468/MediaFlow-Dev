# Android 第二阶段离线生命周期研究

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

桥接是否实际运行、Coordinator重入原因NOT VERIFIED，不能宣布双平台共同达到Browser研究边界。剩余合法候选NOT TESTED：先离线验证重入/Worker复用保护和document-start桥接健康；本轮不再请求真实目标。[证据、命令与文件]( ../android-public-target.md )。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不进入第三阶段。

## 历史：Android 离线安全停止闭环（2026-09-27）

PJZ110 连续两次 securityFixture operation PASS（328ms / 285ms）：页面已加载、活动清理被拒绝，安全事件与同步观察取消同毫秒；六类离线消费替身计数停止后不增、排队任务消费0，Worker退出后Coordinator自动删除精确profile/cache/metadata/marker。Android离线安全停止PASS仅限受控模型，真实检测器/响应/decoder尚未验证；lifecycle A保持限定PASS。原3个历史cache及5个空metadata目录未删除，研究App storage不为0。Windows各结论保持，Android Network/production BLOCKED，真实结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。剩余候选NOT TESTED：Android最小真实目标安全停止/数据入口实验，下一轮单独决定，本轮不运行。

详细证据、时间线、文件和命令：[本轮离线安全停止记录](../android-offline-security-stop.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，不进入真实网络、production或第三阶段。

## 历史：Android Worker 自动清理（2026-09-27）

最终独立 Worker/Coordinator 真机两次 operation 自动闭环 PASS（544ms/363ms），活动实例清理拒绝 PASS，operation profile/cache/no_backup/marker 均清除。Android lifecycle A PASS **仅限最终正常离线研究模型**；历史 prototype 缓存/空目录因marker已删保留，研究App整体storage不为0、历史残留清理BLOCKED，不能宣称全部浏览器状态已清理。安全停止NOT TESTED，Network/production BLOCKED；Windows原normal cleanup FAIL/root cause NOT VERIFIED保持，recovery限历史PASS。Human PASS、目标结构/URL NOT VERIFIED、下载 NOT TESTED。详情见 research/poc/browser-observation-feasibility.md 最新节（从子目录按相对路径定位）。本轮未真实网络、未改production、未新增依赖/未Git写操作。仅第二阶段并暂停；后文为历史记录。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

当前独立 applicationId `com.mediaflow.research.v040.lifecycle`，Debug、minSdk 29 / targetSdk 36。默认构建PUBLIC_PROBE_ENABLED=false、无INTERNET，未带targetUrl时仅本地fixture。显式研究参数enablePublicProbe/publicProbeRun才启用Debug overlay网络权限，并要求publicProbe Intent、合法share/note输入及一次性run领用；CoordinatorService持有状态，独立Worker使用共享bridge消费者。此次唯一真实复验已结束、设备恢复默认禁网络包，不能自行再激活/重试。旧LifecycleActivity仅保留历史实现。生产包com.mediaflow.mediaflow不参与安装或测试。

以下保留上一轮同进程实验记录，不代表当前 Worker/Coordinator 状态。

复用项目已用 AndroidX WebKit 1.15.0、AGP 9.0.1 / Kotlin 插件 2.3.20（apply false）及本机已缓存传递依赖；没有下载或引入新生产库。AndroidX 为 Apache-2.0，直接使用已存在 SDK API，不复制第三方代码。缓存约束只为独立工程离线解析，与 production 依赖清单分离。

构建：设置 ANDROID_HOME=D:\Android\Sdk，以已有 Gradle 9.1.0 执行 `-p v0.4.0/research/poc/android-lifecycle --offline assembleDebug`。输出在仓库忽略的 `build/android_lifecycle_research/`。安装前核对 APK 包名/签名与设备已有应用，不运行自动卸载。首次安装不带 -r；后续仅同签名研究包更新允许 -r，禁止替换正式包。

普通启动 LifecycleActivity：随机 named profile → 离线 HTML → stop/destroy → 300ms 后一次 deleteProfile → 写入仅本包 result.json。无网络、无 Cookie/Token 读取、没有目标数据。故意不反复重试已加载 profile。异常类型与状态计数可观察，不记录正文或账号数据。

cleanupOnly：仅新进程启动，读取本包私有 owned-profile.txt 的精确 `mf040_offline_<32 hex>` 名称，再调用 ProfileStore.deleteProfile；成功后移除 marker。这是本次受控 stale 清理，不是 production 自动恢复或完整 marker 安全机制，不可在活动 worker 场景使用它来冒充安全回收。

PJZ110 实测：原进程 offlineLoaded=true、viewDestroyed=true，deleteProfile IllegalStateException / profilePresent=true（gate A BLOCKED）。本研究包停止、进程退出后新进程 cleanupOnly 88ms 删除成功。不得用后者覆盖前者。gate B/C 未执行，真实目标禁止访问。独立研究包保留安装，未卸载或清除任何应用数据。

下一合法研究候选仅为离线生命周期：独立 worker 完成后退出，协调器验证实例退出与精确 profile 归属，再在未加载该 profile 的进程中删除并验证存储状态。自动闭环/活动保护/安全停止尚未实现和测试；不能由本次两步人工协调宣布生产可行。
