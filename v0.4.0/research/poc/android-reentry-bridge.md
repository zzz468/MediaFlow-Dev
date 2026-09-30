# Android Coordinator 重入与 bridge 离线验证（2026-09-27）

## 范围与结论

本轮无任何真实平台访问。使用 i-have-adhd Skill 分为定位、单次闭环、重复触发、状态收口四项，AGENTS.md 优先。所有改动限研究目录，未修改 production、未新增依赖、未复制第三方代码、未进行 Git 写操作。

## 六个问题的直接回答

1. 旧 CoordinatorActivity 每次 onCreate 无条件分配 UUID/registration，operation 状态归属于 Activity；重建或重复入口可能产生新 operation。离线 dryRun：一个外部 trigger + Activity recreate 得到两次旧分配。缺失跨 Activity 保护已确认；上一轮究竟是哪一个外部生命周期事件引起额外 operation，现有旧日志仍 NOT VERIFIED。未证明 adb 本身必然双启动。
2. 已将归属放入主进程 CoordinatorService，主线程先校验状态再分配；Activity singleTop，重建仅 attach；Binder reconnect 不重复 START，Worker 进程级 atomic claim 拒绝第二次初始化。不是 sleep/忽略第二个结果。进程被系统杀后恢复仍未验证，START_NOT_STICKY fail closed，不代表 production recovery。
3. 最终 fixture 各层实际工作：初始化1、Java/JS ack1、documentReady1、hydration1、JSON candidate1、response1、body3、decoder调用3/成功3，均解出 fixture-gallery 的两个不同合成资源。
4. 旧真实路径没有 response/body 采集实现，因此这两个计数0不证明页面无响应；旧 script 缺桥接初始化诊断并在首 root 后断开，有可能漏后续合法数据。hydration0与decoder0的确切历史原因仍 NOT VERIFIED，不能将本轮离线修复倒推为历史根因。本轮修复命名 root 去重及显式健康事件。
5. 最终版本连续两次独立操作及随后重复触发操作均新增零残留。历史3 cache、5空 metadata、cf428492e7764815a00dbfcfd5b9e462两个marker保持，未清空整个研究storage。
6. 下一轮一次最小真实目标 bridge 复验有技术价值：离线基础设施已可验证，旧真实0数据不能排除合法入口。当前 APK 移除 INTERNET、禁止 targetUrl；下一轮必须重新审查真实模式及安全停止接线，不能直接用离线fetch的成功宣称通用网络body observer可用。本轮不执行。

## 实现与安全语义

IDLE → ALLOCATING → WORKER_RUNNING → STOPPING → AWAITING_DEATH → CLEANING → COMPLETED；异常 BLOCKED。busy trigger 在 UUID/marker/profile 分配之前明确拒绝。Activity 保持绑定直到 package-only final，防止后台启动后 UI 提前退出导致服务被停止。独立 Worker 持有 WebView，Coordinator 不初始化 WebView。

虚拟 mediaflow.invalid HTML/JSON由 shouldInterceptRequest 本地提供，INTERNET权限移除、blockNetworkLoads=true，未知路径空响应；无图片请求。命名 RENDER_DATA + JSON script + 受控fetch通过 document-start script、origin限制桥、Worker、ObservationGate、decoder。合成媒体不能提升真实样本等级或真实图片URL状态。

安全 stop 同步 cancel gate、取消队列、断开script observer，沿核心关闭路径终止renderer、destroy、completion、进程退出。OBSERVATION/RESPONSE/BODY/HYDRATION/DECODER/NAVIGATION消费在stop前、后、final分别保持6/1/3/2/3/1；各类late guard拒绝1，queuedConsumed0、queuedCancelled6。late guard包含受控替身，不证明任意真实在途响应的竞态已通过。

测试holdWorker/holdCleanup使用显式IPC释放，仅冻结离线检查点；不是延迟真实安全停止。45秒deadline失败边界，退出由Binder death及/proc验证，不凭固定等待猜测。

## 最终 APK 真机证据

PJZ110 40fcb99f。两次顺序单trigger：

|operation|profile|loaded|stop/cancel|renderer/destroy|completion|Binder/OS|ownership|delete markers|final|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|91d0b89ee6834d9aae97cc37bf3e1431|217|299|332/332|358/359|361|386/444|448|450|451|
|1ac659c00d654aa4a806d1d94cfefda6|221|270|317/317|343/343|345|369/369|371|372|373|

单位毫秒，来自同一operation elapsedRealtime。每次Worker START1、duplicate0、正常completion、active保护、Worker不存在、profile/cache/metadata/marker/registration均false。证据 android-bridge-release-operation-{1,2}.json。

随后 ae554d63e2624da5b923f45ae84081ad，Activity recreate日志 restoredAttachOnly_noNewTrigger；快速双trigger、WORKER_RUNNING重复、CLEANING重复共拒绝3，单START1，final734ms，五类存储false、Worker不存在。证据 android-bridge-release-duplicate.json / android-bridge-release.log。较早最终核心版本也有816ms/423ms两次及ALLOCATING/WORKER_RUNNING/CLEANING三拒绝证据。额外快速复验fedc...拒绝ALLOCATING重复1、final533ms。

读取结果曾读到旧final，复验脚本改为要求新operation ID再接受COMPLETED；旧读取不作为新单次通过。最终上述451/373ms证据正确绑定新ID。

## 本轮失败与精确清理

早期后台服务失去绑定后被OS停止，及fixture设置blockNetworkLoads=false却没有INTERNET导致SecurityException，分别保留 initial-failure / permission-failure日志；修正绑定生命周期及blockNetworkLoads=true。一次lint receiver flags错误已用既有ContextCompat修复。

有限清单61d6a046e87443ecbe3910363943e739、76786c6879004d9d86f865a23f7109ea、b882dc0817d2476a974c87ee5556b698为本轮失败原型。OwnedFixtureCleanupActivity只允许这三个登记ID，检查nonce/marker/path、原协调者/Worker进程均死亡及无symlink后删除其精确存储。三次PASS见 android-bridge-owned-prototype-cleanup.jsonl。此显式清理不是正常自动cleanup PASS，也不是通用recovery；研究APK升级可能终止早期研究实例，不能宣称其自动闭环成功。历史cf两marker保持。

最终pidof Worker无输出、dumpsys无Worker/renderer/CoordinatorService；缓存只剩旧3个mf040目录、metadata旧5个，worker_operations只剩cf两marker。默认WebView/provider/Crash Reports仍存在，研究storage非空。

## 状态

|项目|状态及限定|
|---|---|
|Windows Network Observation|BLOCKED|
|Windows normal cleanup|FAIL；原因NOT VERIFIED|
|Windows recovery|PASS；历史已测研究范围|
|Windows Browser Observation route|BLOCKED|
|Android device/runtime|PASS；PJZ110|
|Android lifecycle A|PASS；历史限定范围|
|Android offline security stop|PASS；受控fixture|
|Android Coordinator reentry protection|PASS；重建、快速及active/cleaning重复|
|Android bridge health|PASS；已知离线fixture|
|Android automatic cleanup|PASS；最终两次+重复操作新增零残留|
|Android Network Observation|BLOCKED；真实输入能力未证实|
|Android真实安全停止|NOT TESTED|
|目标图文结构|NOT VERIFIED；Human Level1H PASS保持|
|图片 URL|NOT VERIFIED|
|图片下载|NOT TESTED|
|production feasibility|BLOCKED|
|剩余合法高价值候选|NOT TESTED：Android 单次最小真实目标 bridge 数据入口复验|
|第二阶段附件结束条件|NOT VERIFIED|

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 命令、安装与检查

adb devices -l；Gradle --offline assembleDebug lintDebug（研究debug构建成功；lint0errors/13warnings）；apksigner verify --print-certs；研究包adb install --user 0 -r；am start CoordinatorActivity的单trigger、holdWorker/holdCleanup/recreate及release控制；run-as读取progress/result/精确storage；pidof、dumpsys activity services、限定logcat；dart analyze v0.4.0/research/poc/browser_observation_probe.dart（No issues）；git diff --check、diff --stat、rev-parse、branch、status。无Dart改动，未format；未运行真实网络/图片下载/Windows/Release/Flutter全量回归/正式验收。

研究 applicationId com.mediaflow.research.v040.lifecycle Debug，与正式com.mediaflow.mediaflow共存。安装前核实签名一致SHA256 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8，仅更新研究包；正式APK path前后不变，未卸载/清数据/force-stop正式App，未发现研究签名冲突。未读取正式用户数据。

修改：CoordinatorActivity.java、OfflineWorkerService.java、PublicPageScript.java、AndroidManifest.xml及六份状态文档。新增：CoordinatorService.java、OwnedFixtureCleanupActivity.java、本记录及android-bridge-*证据。删除0。无第三方代码复用、新增依赖；既有AndroidX仅调用现有receiver API。

## 项目目标兼容性检查

Windows未重跑，原FAIL/BLOCKED保留。Android仅独立研究包实测，正式构建/回归未测。iOS/macOS/Linux未实现本研究helper，需独立Adapter，不能宣称已支持。Bilibili/Douyin正式解析、未来Xiaohongshu/YouTube/X/Instagram、PlatformDetector、ParserService、MediaContent/Resource、Downloader、Processor、UI、History、Settings、Logging、本地持久化均未改动，未做正式回归因此不报告功能通过。研究WebView属于平台边界；本地虚拟输入无服务器、无Cookie/Token导出/登录态。正式依赖及包体未改变，研究包增加Service及IPC状态代码；进程重建、后台策略、真实网络竞态仍有维护与production风险。

Git top-level/cwd D:\projects\mediaflow-v040，feature/v0.4.0，e2ea89d4e156c843af09b4c491984a2206f1135b。tracked git diff --stat空（研究目录全未跟踪），status仅?? v0.4.0/，无commit/push/merge/tag或其他Git写操作。完成后暂停。
