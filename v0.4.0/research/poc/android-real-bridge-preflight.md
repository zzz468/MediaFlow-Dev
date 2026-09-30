# Android 真实 bridge 前置审查与离线修复（2026-09-27）

## 结论：执行附件的前置失败分支

真实导航0次。附件明确规定：真实模式未正确接线时，本轮不要访问平台，先修研究 helper、离线回归后暂停。静态审查发现真实模式仍禁用且未共享离线消费实现，故未执行目标访问。这是研究基础设施结论，不能推导平台页面无数据、不能宣布双平台路线达到研究边界。

已使用 i-have-adhd Skill 组织审查、修复、回归和收口，AGENTS.md优先。cwd/top-level D:\projects\mediaflow-v040，feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b，status仅?? v0.4.0/。全部旧文件和证据保留，无Git写操作。

## 审查发现与修复

|检查|发现及本轮处理|
|---|---|
|真实入口|Activity/Coordinator/Worker拒绝targetUrl、Manifest无INTERNET。本轮保持关闭，未临时放行|
|document-start注入|realTarget或bridgeFixture走同一注册位置；增加scriptInjection遥测。该计数是注册成功次数，执行证据另看initialized|
|bridge callback|旧real分支仅处理hydration，fixture分支才有init/ack/ready/JSON/response计数。改为共享consumePageMessage，restriction优先进入realStop|
|response/body|旧fixture手动postMessage伪装response，不是通用观察。现由PublicPageScript观察页面既有同源fetch返回的clone，无新请求/重放；fixture不再发送response消息|
|hydration/JSON|命名根与application/json/ld+json script由同一观察器去重读取，不再把MF040_JSON当特殊必需ID；fixture使用普通GENERIC_JSON|
|decoder|共享gate内入口，结果区分SUCCESS/NO_MATCH/ERROR；fixture另检查两个不同合成资源，不能把任意decode当fixture成功|
|安全取消|原生gate同步取消；JS observer/readers取消通过UI线程调度，修正未来resource线程直接调用evaluateJavascript的风险；无额外观察窗口|
|Coordinator及cleanup|未修改，仍在分配前拒绝重复操作，Worker进程级claim、Binder death+/proc、归属校验和精确目录删除保留|

本轮修复了共享采集消费链，但不宣称已经启用完整真实调度。下一轮须审查targetUrl三处禁用、Coordinator真实NAVIGATE/stop/completion状态、真实结果遥测与INTERNET启用方案后再决定一次真实实验。当前Coordinator仍强制离线fixture并发送离线安全信号，不能只加INTERNET权限就访问真实目标。

## 采集范围及边界

PublicPageScript只对页面本来调用的fetch追加观察：Reflect.apply原fetch，仅一次，返回原Promise，不主动发起新请求，不请求重放、不代理/MITM。仅同源response读取公开JSON/HTML/javascript类型副本，500000字节/字符预算，不读Cookie、账号凭据或请求headers/body；无完整payload落盘。security response路径或DOM限制优先触发停止。stop断开MutationObserver并取消副本reader，native gate拒绝后到消费者。

覆盖不包括XHR、跨域body、主document HTML body及浏览器原生script/style资源正文；shouldInterceptRequest依旧只是请求入口。不能将同源fetch能力写成完整Network Observation。未修改平台请求或安全算法，未导入会话。包装fetch和clone有内存/时序开销，真实页面兼容性及大响应/在途读取取消竞态尚未实测。

summary只保留目标匹配、gallery、图片数、不同URL数及title/author是否存在，不保存URL值或账号数据。当前真实响应host/path/MIME细分遥测仍未实证，本文不虚构这些结果。新增decoderNoMatch/error计数本次均0，不代表这两个分支已经负向实测。

## 两次最终研究 APK 离线真机回归

PJZ110 serial40fcb99f。本地mediaflow.invalid资源由shouldInterceptRequest内存提供，INTERNET仍缺失、blockNetworkLoads=true；普通页面fetch仅本地data.json，图片只是合成URL字符串，未请求图片。

|事件（elapsed ms）|a7e0580e296b4601b5dba132ae2eae00|547a09e62d584223bcf518dde522fd61|
|---|---:|---:|
|profile allocate|514|304|
|bridge initialized|599|371|
|hydration / JSON decoded|608 / 609|372 / 372|
|document ready / page loaded|609 / 609|372 / 373|
|response metadata / response body decoded|688 / 688|408 / 408|
|active cleanup refused|690|410|
|security stop / cancel|697 / 697|410 / 410|
|renderer exit / destroy|786 / 787|427 / 428|
|completion|798|429|
|Binder death / OS exit|825 / 825|444 / 495|
|ownership validated|829|497|
|automatic cleanup / marker removed|831 / 831|499 / 499|
|final|831|499|

每次scriptInjection1、initialized1、ack1、documentReady1、hydration1、JSON1、response1、body3、decoder3/success3/noMatch0/error0、bodyReadErrors0。两次单operation、Worker START1、duplicate0、active保护成功、normal completion/Binder death成功、Worker不存在。

gate消费在beforeStop/afterStop/final均为OBSERVATION8、RESPONSE1、BODY3、HYDRATION2、DECODER3、NAVIGATION1；OBSERVATION包含bridge消息与嵌套消费，不是HTTP请求数。localRequest事件每轮3次（document/data.json/favicon），均本地；未新增独立request计数。取消后各类late guard拒绝1，queuedConsumed0/queuedCancelled6。安全信号是离线IPC，不是本轮真实安全事件；受控late stand-in不等同真实在途响应取消的验证。

证据android-wiring-offline-operation-1.json、operation-2.json、android-wiring-offline.log、android-wiring-storage-inspection.txt。本次profile/cache/metadata/worker marker/registration全部false。最终worker pidof及相关services无输出。历史3cache、5个隐藏metadata目录、cf428492e7764815a00dbfcfd5b9e462两marker保留；研究storage非空，未执行手工cleanup/recovery/force-stop。

## 真实实验九个问题

1. 真实bridge健康：NOT TESTED，本轮未导航；离线共享链PASS。
2. response/body真实工作：NOT TESTED；同源fetch离线PASS，不能覆盖所有response API。
3. 真实hydration：NOT TESTED。
4. decoder真实输入：NOT TESTED，仅合成fixture。
5. 目标结构：NOT VERIFIED。
6. 图片URL：NOT VERIFIED。
7. 真实安全停止：NOT TESTED，没有真实输入。
8. 本轮重入未再出现：两次独立操作均START1、duplicate0；此前重复触发/recreate PASS限定结论保持，本轮没有重跑所有duplicate场景。
9. 仍有具体合法高价值候选：先完成真实模式激活/状态调度与遥测审查，再下一轮单次最小真实bridge复验。禁止通过放宽安全停止来取得数据。本轮不进入此候选。

## 状态表

|项目|状态|
|---|---|
|Windows Network Observation|BLOCKED|
|Windows normal cleanup|FAIL|
|Windows recovery|PASS，历史限定范围|
|Windows Browser Observation route|BLOCKED|
|Android device/runtime|PASS|
|Android lifecycle A|PASS，历史范围|
|Android offline security stop|PASS，离线受控范围|
|Android Coordinator reentry protection|PASS，历史重复/recreate及本轮单操作范围|
|Android bridge health|PASS，离线共享fetch/script夹具|
|Android真实 bridge|NOT TESTED|
|Android真实安全停止|NOT TESTED|
|Android automatic cleanup|PASS，本轮两次新增操作|
|Android Network Observation|BLOCKED|
|目标图文结构|NOT VERIFIED|
|图片 URL|NOT VERIFIED|
|图片下载|NOT TESTED|
|production feasibility|BLOCKED|
|剩余合法高价值候选|NOT TESTED：真实模式激活审查后单次最小真实Android bridge复验|
|第二阶段附件结束条件|NOT VERIFIED|

Level1H/Human PASS保持，不升级Machine或Structured状态。没有理由宣布平台无结构或整个版本不可实现。A–D条件尚未满足：无真实目标结构/图片，双端production证据不足。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。

## 文件与检查

修改PublicPageScript.java、OfflineWorkerService.java及六份最新状态文档；新增本文、两份operation JSON、限定log、storage检查。删除0。无production、依赖、第三方代码搬运或Git写操作。沿用Android SDK与已存在Apache-2.0 AndroidX库。

实际执行adb devices -l；静态读取manifest/Activity/Service/script/gate；Gradle9.1 JDK17 --offline assembleDebug lintDebug，两次构建均成功，最终lint0errors/13warnings；pm path正式/研究包；pull仅已安装研究APK；apksigner旧/新研究签名一致SHA2564f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8；aapt核验独立applicationId及无INTERNET；adb install --user0 -r仅更新研究Debug；两次CoordinatorActivity无targetUrl启动及读取新ID的COMPLETED结果；pidof/dumpsys/run-as精确storage、限定tag日志；dart analyze browser_observation_probe.dart No issues found；git diff --check/stat/branch/HEAD/status。tracked diff stat空，因为v0.4.0全未跟踪；不代表无研究修改。

安装applicationId com.mediaflow.research.v040.lifecycle Debug，与com.mediaflow.mediaflow共存；正式APK path前后不变，未卸载/替换/清正式数据，无签名冲突；研究包同签名更新，无数据清除。未读取正式用户数据。无Dart修改，不format。

未执行真实experiment（按附件前置失败条件）、图片下载、Windows复测/构建、Release、Flutter全量回归、正式验收、真实安全条件PASS测试、跨域/XHR/全资源body观察、进程重建/异常recovery、负向decoder分支测试。完成后暂停，不自行第三阶段。

## 项目目标兼容性检查

Android仅独立研究包实际测试，不等于正式能力；Windows未复测，旧FAIL/BLOCKED保持；iOS/macOS/Linux本helper暂不支持、未构建，需对应Adapter。Bilibili/Douyin正式解析与未来Xiaohongshu/YouTube/X/Instagram、PlatformDetector、ParserService、统一模型/MediaContent/MediaResource、Downloader、Media Processing、UI、History、Settings、Logging、正式本地存储均未改/未回归，不宣称通过。研究script属于Browser边界，fetch包装可能影响页面性能/兼容性，正文副本虽有预算仍需真实场景验证；不能直接生产接入。隐私及零服务器保持，无用户身份导入、Cookie/Token导出、代理/MITM/重放。正式依赖/包体未变；研究代码增加观察开销，性能/后续维护和production生命周期仍有风险，正式发布BLOCKED。
