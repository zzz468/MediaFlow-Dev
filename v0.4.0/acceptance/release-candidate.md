# v0.4.0 Release Candidate 判定模板

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

桥接是否实际运行、Coordinator重入原因NOT VERIFIED，不能宣布双平台共同达到Browser研究边界。剩余合法候选NOT TESTED：先离线验证重入/Worker复用保护和document-start桥接健康；本轮不再请求真实目标。[证据、命令与文件]( ../research/poc/android-public-target.md )。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。已暂停，不进入第三阶段。

## 历史：Android 离线安全停止闭环（2026-09-27）

PJZ110 连续两次 securityFixture operation PASS（328ms / 285ms）：页面已加载、活动清理被拒绝，安全事件与同步观察取消同毫秒；六类离线消费替身计数停止后不增、排队任务消费0，Worker退出后Coordinator自动删除精确profile/cache/metadata/marker。Android离线安全停止PASS仅限受控模型，真实检测器/响应/decoder尚未验证；lifecycle A保持限定PASS。原3个历史cache及5个空metadata目录未删除，研究App storage不为0。Windows各结论保持，Android Network/production BLOCKED，真实结构/URL NOT VERIFIED、下载NOT TESTED、Human PASS保持。剩余候选NOT TESTED：Android最小真实目标安全停止/数据入口实验，下一轮单独决定，本轮不运行。

详细证据、时间线、文件和命令：[本轮离线安全停止记录](../research/poc/android-offline-security-stop.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，不进入真实网络、production或第三阶段。

## 历史：Android Worker 自动清理（2026-09-27）

最终独立 Worker/Coordinator 真机连续两次 operation 自动闭环 PASS（544ms/363ms），活动实例清理拒绝 PASS，operation profile/cache/no_backup/marker 均清除。Android lifecycle A PASS 仅限最终正常离线研究模型；历史 prototype 缓存/空目录因 marker 已删保留，研究 App 整体 storage 不为0、历史残留清理 BLOCKED，不能宣称全部浏览器状态已清理。安全停止 NOT TESTED，Network/production BLOCKED；Windows 原 normal cleanup FAIL/root cause NOT VERIFIED 保持，recovery 限历史 PASS。Human PASS、目标结构/URL NOT VERIFIED、下载 NOT TESTED。详情见 browser-observation-feasibility.md 最新节。本轮未真实网络、未改 production、未新增生产依赖/未 Git 写操作。暂停。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 历史：Android gate A / Windows cleanup 定位（2026-09-27）

PJZ110 真机独立无网络 Debug 包已实测：WebView加载/destroy成功，但 loaded profile 在原进程 deleteProfile 抛 IllegalStateException，Android lifecycle BLOCKED，gate B/C未运行。新进程精确profile删除成功不覆盖自动生命周期失败；独立 worker 退出后的自动闭环仍为合法离线候选，NOT TESTED。Windows 本地重定向拒绝自动cleanup PASS，但原share FAIL未复现、根因未确认，normal cleanup仍FAIL；数据入口边界保持BLOCKED。结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED，Human PASS保持。详见[本轮记录](../research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文为历史状态。

## 最新：share/note 候选验证（2026-09-27）

一次全新匿名研究会话在 2870ms 重定向 www.douyin.com /note/<id>，2875ms 拒绝继续；候选 BLOCKED，无 hydration/目标 JSON。Windows Browser Observation 在当前项目安全约束下已到达本阶段研究边界。本次自动 cleanup FAIL，helper 已退出后按本轮精确路径清理，最终 profile 根 0；此前受控 cleanup/recovery PASS 仍仅限历史已测范围，完整生命周期 NOT VERIFIED。Android 当前有 PJZ110 设备，runtime 仍 NOT TESTED；Level 1H Human PASS、结构/URL NOT VERIFIED、下载 NOT TESTED、production BLOCKED 保持。详见[本轮证据](../research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停。后文“share 尚未执行 / 无 Android 设备”等为历史状态。

## 最新：第二阶段收口判断（2026-09-27）

本轮源码审计未发现安全停止前合法数据漏消费；离线 recovery 九条断言 PASS，新增活动锁与 abandoned mutex 检查。研究生命周期达到当前受控范围，完整 production 生命周期 NOT VERIFIED。已测 /note Network BLOCKED；独立公开 share/note 入口停止前 hydration 尚有合法候选，NOT TESTED，本轮未运行。Android 无设备 NOT TESTED，结构/URL NOT VERIFIED，下载 NOT TESTED，production BLOCKED。详见[收口记录](../research/poc/browser-observation-feasibility.md)。本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段并暂停；后文为历史记录。

最新第二阶段：[recovery 边界实测](../research/poc/browser-observation-feasibility.md)完成。本轮仅离线研究，v2 marker 字段/内部归属、PID 创建时间分支、活动实例拒绝、stale/active 分离及同 session 两 recovery 互斥均有实际证据。真实 PID 重用、双 WebView2 helper、断电/跨 session/完整 marker 伪造仍未验证。目标结构与图片 URL NOT VERIFIED、下载 NOT TESTED；Network BLOCKED，完整窗口 NOT VERIFIED；Android NOT TESTED / production feasibility BLOCKED。保留第二阶段，不把 cleanup PASS 当作 production PASS；后文旧结论为历史记录。

最新研究：Windows 正常 cleanup 与本次离线硬杀/下一次独立启动精确 marker 回收 PASS；安全验证后的窗口因 AGENTS 约束未执行，目标结构/图片仍未取得。其余异常回收未验证。Android BLOCKED/NOT TESTED；这些研究证据不满足双端 production 或 RC 门槛，详见 [最新证据](../research/poc/browser-observation-feasibility.md)。下文此前“异常退出回收未测”保留为上一轮状态。

第二阶段最新：[Browser Observation](../research/poc/browser-observation-feasibility.md)结论 B。Windows 三种可控退出 cleanup 已实际验证，目标 note 匿名加载触发安全验证并停止，无图片结构/下载；异常退出回收未测。Android profile 删除风险未解除，production feasibility=BLOCKED、runtime NOT TESTED。未形成新功能或双端准入通过证据。

**当前状态：未开始 v0.4.0 功能开发，未形成 Release Candidate，不具备发布判定。** 本文件仅定义后续证据栏位；v0.3.0 的已发布状态不受影响。

| 项目 | v0.4.0 当前状态 | 候选时需记录 |
| --- | --- | --- |
| 版本与范围 | 未冻结 | production 功能清单、明确排除项、commit、资产 hash |
| Windows Release GUI | 未验证 | 解析、下载、系统打开、多资源状态、History 重启与证据 |
| Android Release 真机 | 未验证 | 设备、包名/签名/安装安全、同一功能范围和真实文件 |
| 旧功能回归 | 未运行 | Bilibili 视频/图文、Douyin 视频、下载队列/Range/重试、History/设置/日志 |
| 自动化与构建 | 未运行 | analyze/test/format/diff-check、Windows/Android 构建结果与跳过项 |
| 新平台/内容研究 | [第一阶段首轮研究完成](../research/stage1-conclusion.md)；第二阶段[上一轮 HTTP PoC](../research/poc/stage2-douyin-gallery.md)无目标结构，[续研样本确认](../research/poc/verified-samples.md)已取得 Level 1H、输入阻断解除，本轮有效输入上仍无目标结构，Android 无设备未验证；Douyin 图文仍非 production 支持 | 按[统一研究规则](../research/execution-rules.md)保存逐项目来源与许可证、路线对照、PoC、Windows/Android 独立证据；Douyin 图文须有至少两张图片的匿名真实下载，研究、PoC、production 结果分别记录 |
| iOS/macOS/Linux | 未构建、未实测 | Adapter 路径与平台特有风险，不声明正式支持 |

只有冻结范围内的 Windows 与 Android Release GUI、兼容回归及构建/自动检查全部通过，且无 release-blocking 问题，才可更新判定。未取得匿名可访问证据的候选功能不得列为 production 或通过项。
