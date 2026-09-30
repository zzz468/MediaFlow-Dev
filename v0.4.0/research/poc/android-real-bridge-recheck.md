# Android 真实模式激活与一次公开 bridge 复验（2026-09-27）

## 结论 2

真实 bridge 已被证明工作，但仍未获得目标图文结构。本轮仅一次真实公开导航，样本7690029886242009957（Human Level1H PASS保持）。自然JSON script候选2个进入共享body/decoder链，decoder SUCCESS0 / NO_MATCH1 / ERROR1。命名hydration0、同源fetch response0；这些零计数只限本次953ms允许窗口及当前覆盖，不证明页面没有数据或接口不可用。没有目标图片URL证据，未执行研究图片下载/保存/验证或production接入。自动图片加载关闭、明显媒体扩展名请求被阻断；未做全流量审计，不声称页面绝无其他形式的自然媒体请求。

接线审查通过后才执行目标。全过程采用i-have-adhd Skill拆解审查、激活、单次实验、收口，AGENTS.md优先。未使用账号/Cookie/Token导出/导入、请求重放、主动detail/feed API、代理/MITM/第三方解析服务；未扩大XHR/WebSocket/service worker/跨域body/网络层。

## A 激活前审查

导航前已保存android-activation-audit.md。沿用Coordinator→独立Worker→同一PublicPageScript→同一WebMessageListener→consumePageMessage→ObservationGate→同一summary decoder→worker exit→cleanup。没有fixture主动发送response路径。真实模式不运行fixtureHtml或fixturePayload、不设置fixtureId、不进入maybeReady，不注入合成数据。

修正仅用于本轮可信激活：Coordinator真实LOADED验证identity并实际拒绝active cleanup后发送NAVIGATE；真实COMPLETED使WORKER_RUNNING→STOPPING→AWAITING_DEATH，未误发fixture SECURITY_STOP。Activity重建只attach，重复trigger先拒绝再分配；Worker进程级atomic claim与navigationStarted+gate使仅一次loadUrl。所有JS消息携带本次operation，原生先精确校验，decoder摘要也标operation；cleanup再校验op/nonce/PID创建ticks/路径与最终计数。

研究build.gradle默认PUBLIC_PROBE_ENABLED=false，无网络权限。仅明确-PenablePublicProbe=true和合法publicProbeRun才加入Debug overlay INTERNET；Activity显式publicProbe extra、Coordinator URL范围检查、Worker build gate共同启用。每run通过createNewFile一次性领用控制账本，后续即使完成再触发也不能创建第二个真实operation。历史目录不参与清理。

停止仍资源回调同步cancel native gate，JS reader/observer取消及stopLoading/terminate/destroy沿既有退出；不允许停止后消费，未添加延迟窗口。异步JS自身处置有IPC/UI调度边界，本次证明的是native受控消费停止与进程退出，不声称任意真实在途fetch读取竞态全覆盖。

## 同一激活构建的离线回归

operation1857388abce945d48a3408527fe8c9b1，final1820ms PASS、Worker START1、profile/cache/metadata/marker/registration均清理。operation一致性校验通过。script/init/ack/ready各1，hydration1/JSON1/response1/body3/decoder3成功3；安全停止后gate消费不增长。虚拟资源本地提供，blockNetworkLoads=true；没有真实目标输入。证据android-activation-offline-regression.json。

## 唯一真实 operation / 时间线

URL https://www.douyin.com/share/note/7690029886242009957 ，operation92f087e881ca457faca56143db05d43d，WorkerPID10870/startTicks19330843。真实NAVIGATE command1 / target loadUrl1，未刷新、未更换样本。

|事件|elapsed ms|
|---|---:|
|operation registered|2|
|Worker start / profile allocate|140 / 249|
|Worker ready（尚非页面加载）/ active cleanup拒绝|250 / 250|
|NAVIGATE command / target navigation requested|250 / 253|
|navigationStarted / bridge initialized / ack|530 / 531 / 532|
|JSON decoder ERROR / NO_MATCH|848 / 848|
|document ready / onPageFinished|925 / 927|
|navigationBoundary / observationCancelled|953 / 954|
|close / renderer terminate|956 / 956|
|renderer gone / WebView destroy|987 / 988|
|Worker completion|991|
|Binder death / OS Worker exit确认|1012 / 1012|
|ownership validated|1022|
|profile/cache/metadata/markers自动删除|1028|
|final|1029|

stopReason navigationBoundary：页面尝试离开精确限定URL被拒绝，不是第二次实际导航。没有记录该被拒绝URL的值，不能推测目的地或把它认定为挑战/note重定向。securityStopped=false / securityStopCount0，因此真实安全停止NOT TESTED；本次正常策略取消不能冒充平台安全挑战PASS。日志旧名offlineLoaded仍出现在真实onPageFinished，不能误解为fixture加载。

## C 真实遥测

|指标|结果|
|---|---:|
|operation分配 / Worker START|1 / 1|
|duplicateRejected / navigationRequests|0 / 1|
|script registration / initialization / ack / document ready|1 / 1 / 1 / 1|
|request observation|31|
|named hydration / JSON candidate|0 / 2|
|fetch response / shared body|0 / 2|
|decoder invocation / success / no-match / error|2 / 0 / 1 / 1|
|decoder来源 hydration / JSON / response-body|0 / 2 / 0|
|bodyReadError / security stop count|0 / 0|

body2来自JSON script，不是fetch正文；response0不能被shouldInterceptRequest请求31替代。两个输入都来自本次主frame匿名页面、停止前自然脚本元素；无原payload落盘。现有summary只支持JSONObject根并有大小/节点限制，ERROR只记录分类，无法确定本次是非对象根、格式还是其他解析错误。不能猜测平台数据错误。NO_MATCH未产生targetEvidence，未绑定目标作品；没有可复核图文数组/order/图片URL证据。

Activity未主动recreate，未记录binderReconnectRejected或第二个operation；最终单operation结果与单导航/marker证据确认无观察到重入。限定logcat事后读取仅保留Activity destroy一行，旧环形缓冲未保留完整Activity创建/rebind轨迹，所以确切Activity重建/重绑定次数NOT VERIFIED，不把没有日志写成完整生命周期trace PASS。时间线依据operation结果内Worker/Coordinator事件数组，证据android-activation-real-operation.json；android-activation-real.log为不完整辅助日志。

## Stop / cleanup / 历史保护

beforeStop / afterStop / final：OBSERVATION36、RESPONSE0、BODY2、HYDRATION2、DECODER2、NAVIGATION1消费均不增。HYDRATION gate包含JSON两次，命名hydration callback仍0。bridgeBeforeStop、bridgeAfterStop与最终bridgeHealth所有字段一致，Coordinator逐字段校验；所有桥接/decoder输入带同一operation。没有新operation或后续targetNavigationRequested；待执行观察Handler任务取消，后到bridge消息native gate拒绝。没有真实已排队payload的额外正向证据，不能宣称所有在途response路径都实测。

normalCompletion、Binder death、activeProtection均true，Worker最终不存在；当前profile/cache/metadata/worker marker/registration全部false。本次final PASS只证明操作级自动退出cleanup和计数不增，不代表Network/图文支持PASS。

pidof Worker无输出、相关services无输出；恢复默认包后Activity/Worker均不存在。android-activation-storage-before.txt与after.txt的目录列表Compare-Object无差异，历史3cache/5隐藏metadata/cf两marker继续存在。未手动force-stop或后续recovery/猜测删除。一次性public-probe-used-stage2-20260927-activation控制账本保留（无身份或网页数据，不是profile/worker marker）；研究App storage非0。

## 实验后临时权限撤回

真实Worker已退出并自动cleanup后，重新无参数构建默认研究APK并同签名更新。aapt无INTERNET，生成BuildConfig.PUBLIC_PROBE_ENABLED=false / RUN空；设备dumpsys package无INTERNET。禁止自行再次激活或导航。已用激活APK备份仅在忽略build目录，保留研究证据。

## 第二阶段判断 / 状态

|项目|状态及范围|
|---|---|
|Windows Network Observation|BLOCKED|
|Windows normal cleanup|FAIL，历史原因NOT VERIFIED|
|Windows recovery|PASS，历史研究限定范围|
|Windows Browser Observation route|BLOCKED|
|Android device/runtime|PASS，PJZ110|
|Android lifecycle|PASS，已测离线及本次单operation退出范围；异常/完整production生命周期NOT VERIFIED|
|Android Coordinator reentry protection|PASS，既有重建/duplicate及本次单operation范围|
|Android bridge health（offline）|PASS，同构建已知fixture|
|Android real bridge|PASS，限本次init/ack/ready及JSON→body→decoder；fetch response路径NOT VERIFIED|
|Android real security stop|NOT TESTED，本次未识别平台安全条件|
|Android automatic cleanup|PASS，本次新增operation零残留|
|Android Network Observation|BLOCKED，未取得目标结构/同源fetch响应证据，不代表所有浏览器数据入口失败|
|目标图文结构|NOT VERIFIED|
|图片 URL|NOT VERIFIED|
|图片下载|NOT TESTED|
|production feasibility|BLOCKED|
|剩余合法高价值候选|NOT VERIFIED，需先离线评估decoder根类型诊断及导航边界分类价值；不直接扩大采集或追加真实导航|
|第二阶段结束条件|NOT VERIFIED|

区分结果：bridge确实工作；命名hydration未见；同源fetch未见metadata或body；JSON body进入且decoder一no-match一error；未找到目标结构。仅说明本窗口未取得当前范围中的目标对象。不能推导页面无数据、公开结构不存在或必须hook XHR/跨域。

下一步只建议先评估纯离线decoder数组/对象/字符串根和错误分类能否改善脱敏诊断，并静态检查navigationBoundary分类；不保证会增加目标命中，不自动安排第二次真实目标。Windows结论不变，未宣布双平台Browser路线共同到达边界。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。结论2，暂停等待用户指令，不第三阶段。

## 文件变化

修改：android-lifecycle/build.gradle；CoordinatorActivity.java、CoordinatorService.java、OfflineWorkerService.java、PublicPageScript.java；v0.4.0/README.md、research/README.md、poc/stage2-douyin-gallery.md、poc/browser-observation-feasibility.md、acceptance/release-candidate.md、android-lifecycle/README.md。

新增：android-lifecycle/src/publicProbe/AndroidManifest.xml；android-activation-audit.md；android-activation-offline-regression.json；android-activation-real-operation.json；android-activation-real.log；android-activation-storage-before.txt、after.txt；本记录android-real-bridge-recheck.md。删除0。所有旧研究文件保留。

## 实际检查 / 未执行

adb devices -l；根规则/skill/preflight/Activity/Coordinator/Worker/script/Gradle/manifest静态审查；pm path正式/研究包，pull仅研究APK；apksigner旧/激活/默认研究签名一致SHA2564f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8；Gradle9.1/JDK17 --offline -PenablePublicProbe=true -PpublicProbeRun=stage2-20260927-activation assembleDebug lintDebug；研究同签名install --user0 -r；一次无targetUrl离线fixture及一次 --ez publicProbe true --es targetUrl <批准URL>；按新operation ID取结果；pidof/dumpsys/run-as storage、Compare-Object、限定logcat；无参数Gradle assembleDebug lintDebug并install默认研究包；aapt/BuildConfig/dumpsys验证临时权限撤回；dart analyze browser_observation_probe.dart No issues found；git diff --check/stat/branch/HEAD/status。两种研究构建均成功，lint各0errors/12warnings；无Dart修改不format。

研究applicationId com.mediaflow.research.v040.lifecycle Debug与正式com.mediaflow.mediaflow共存；仅研究包同签名更新，没有卸载、清数据、formal force-stop/替换；正式APK path前后一致。正式签名未读，不同ID不作为替换目标；研究旧新签名兼容已核实。未读取正式用户数据。

未执行图片下载、第二次真实navigation、detail/feed主动请求、XHR/跨域/其他网络层采集、Windows方案/构建、iOS/macOS/Linux、Release、Flutter全量回归、正式验收、production修改或Git写操作。没有新增依赖、复制第三方代码；沿用既有Apache-2.0 AndroidX和Android SDK。defaultDebug网络权限仅独立研究构建变化，不修改正式包。

Git cwd/top-level D:\projects\mediaflow-v040，feature/v0.4.0，e2ea89d4e156c843af09b4c491984a2206f1135b；status ?? v0.4.0/。tracked diff --stat为空，因为整个研究目录未跟踪；git diff --check通过，非无修改。无commit/push/merge/tag等Git写操作。

## 项目目标兼容性检查

Windows本轮未测试、旧BLOCKED/FAIL及历史recovery PASS保持。Android独立研究包真实/离线实测，不是正式发布验收，provider与系统后台策略、异常重建完整生命周期风险仍在。iOS/macOS/Linux本helper暂不支持/未构建，需独立Adapter。正式Bilibili/Douyin与未来Xiaohongshu/YouTube/X/Instagram/其他平台无新增支持；PlatformDetector、Parser/Adapter正式接口、ParserService、统一内容模型/MediaContent/MediaResource、Downloader、Media Processing、UI、History、Settings、Logging、正式本地存储未改/未回归，不能宣称功能通过。研究Browser能力仍Android限定，fetch包装和副本预算有页面兼容/性能风险；仅当前操作时序，非性能基准。隐私本地/零服务器保持，无凭据上传/导入、代理/MITM/重放。正式依赖及包体不变，研究生成BuildConfig及overlay/计数代码增加维护面，必须防止意外带入生产；正式发布门槛BLOCKED。
