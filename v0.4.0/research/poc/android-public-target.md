# Android 单次公开目标实验（2026-09-27）

## 本轮结论

只执行一次 `am start`、一个目标 URL、一次真实 navigationRequested：`https://www.douyin.com/share/note/7690029886242009957`，Level1H/Human PASS保持。**未触发本实现已识别的安全停止条件，因此 Android真实安全停止 NOT TESTED。** 不能用离线PASS或观察预算结束当成真实安全停止PASS，也不能证明页面没有挑战或图文结构。

没有收到命名hydration桥接消息，结构/图片URL NOT VERIFIED，图片下载 NOT TESTED。十秒预算结束后取消消费，主operation自动退出并精确清理PASS；但同一次启动期间出现额外Coordinator operation，在已初始化provider的同一Worker进程失败并留下两份marker，故**本轮完整生命周期/全operation零残留 FAIL**。Android lifecycle A和离线停止的历史已测范围PASS保留，不能扩展成真实环境完整生命周期PASS。

使用 i-have-adhd Skill 组织核对、研究接线、单次实验、收口；AGENTS.md优先。停止真实访问，不更换样本、不重试、不进入第三阶段。

## 实现与安全边界

沿用Coordinator → :offline_worker → WebView → ObservationGate → Worker退出 → Coordinator精确cleanup。研究Manifest仅增加INTERNET权限；既有离线模式仍JavaScript=false/blockNetworkLoads=true。真实模式输入严格限定www.douyin.com/share/note/<19位ID>，未改正式Parser或正式Android host。

复用本仓库已有AndroidX WebKit1.15.0的document-start script/WebMessageListener能力（只设计参考本仓库AndroidBrowserObservationHost，未复制第三方代码），仅主frame且www.douyin.com origin。脚本只检查DOM限制标记与三个命名script元素：RENDER_DATA、_ROUTER_DATA、__UNIVERSAL_DATA_FOR_REHYDRATION__，不hook fetch/XHR、不重放请求。原生gate内才解码，摘要只含root/精确aweme_id绑定/图片数/不同图片URL数/title-author存在性，不落盘原HTML/script正文或账号字段。payload预算500000字符、深度16/节点6000。未实现window全局根、JSON-LD/其他JSON scripts的完整覆盖，**不能用未收到消息证明hydration不存在**。

security resource检测沿用已有研究边界waf-jschallenge/lf-waf-js，并识别captcha/verify/challenge资源；DOM检测登录/验证码/地区/权限/付费限制。重定向/navigate到既有阻塞/note路径立即停止。resource线程在发main线程退出消息之前同步cancel gate，禁止之后消费；main线程沿同一closeView退出，不延迟停止或主动求解验证。

Android shouldInterceptRequest是请求入口而非response observer。本次仅统计请求观察，不声称已取得HTTP status/Content-Type/response headers/body：这些是 NOT VERIFIED。没有另发HTTP读取或缓存重放。页面读取仅document-start桥接，未注入Cookie/Token、未导入用户状态。全新operation suffix；临时匿名平台状态可能由provider自然产生，精确目录生命周期清理是隔离证据，并非“浏览器从不产生Cookie”。没有读取、导出或记录Cookie/Token值。

加载关闭图片自动加载、阻断明显图片/视频扩展名请求、禁止自动媒体播放；未调用图片Downloader或保存图片，未提取图片URL。没有全流量审计，因此不声称页面脚本绝不可能自然请求其他形式媒体；本轮没有图片下载验证。

真实模式在provider/profile初始化后先发送identity给Coordinator，活动保护通过才允许NAVIGATE；这不代表目标页面已加载。允许navigationStarted但尚未onPageFinished时正常取消/退出清理，避免安全条件早于页面加载时无法cleanup。十秒是无安全条件时的总预算，安全条件出现立即取消，不等待剩余预算。边界、身份、消费计数不符均fail closed。

## 实测时间线

主operation `b03ffc73f80341d29e092d04e70b5ef3`，WorkerPID753/startTicks18977955，CoordinatorPID623。以下是自然事件，未收到securityResourceDetected/DOM restriction/blockedNoteRedirect：

| 事件 | elapsed ms |
| --- | ---: |
| Coordinator registered | 6 |
| Worker started | 333 |
| profileAllocated | 1000 |
| Worker ready（日志workerLoaded，非页面加载） | 1002 |
| activeRefusedProfilePreserved | 1011 |
| targetNavigationRequested | 1013 |
| navigationStarted | 1353 |
| targetPageFinished | 2031 |
| windowEnded / observationCancelled | 11028 / 11028 |
| closeRequested / rendererTerminationRequested | 11029 / 11030 |
| rendererGone / viewDestroyed | 11080 / 11080 |
| completionReceived | 11082 |
| Binder death / OSExitConfirmed | 11109 / 11109 |
| ownershipValidated | 11118 |
| profile/cache/metadata/markers deleted | 11126 |
| final | 11127 |

旧日志名offlineLoaded在真实mode中也被输出，但本轮onPageFinished来自真实入口，不是离线夹具；不要误用该日志名。

取消前/立即取消后/final消费：OBSERVATION=51（自然请求观察），NAVIGATION=1；RESPONSE/BODY/HYDRATION/DECODER均0。六类计数取消后均不增加。未收到目标作品绑定/title/author/image数组或图片URL证据；输入targetId不是响应绑定证据。没有fixture造假消费，没有已排队hydration消息的正向证据；队列清除实现存在，但真实在途body取消未实测。

主结果JSON的status PASS只表示该operation的退出cleanup和active保护，不代表真实安全停止/Network/图文PASS。证据：[主JSON](android-public-target-primary.json)、[限定标签原日志](android-public-target.log)。

## 新发现：额外Coordinator operation

同一次外部启动中第二个operation `cf428492e7764815a00dbfcfd5b9e462` 在主观察期间出现，使用相同CoordinatorPID623、WorkerPID753/startTicks18977955。其workerStarted32ms后IllegalStateException，未profileAllocated、未第二次targetNavigationRequested，因此**仍只有一次真实目标导航**。9324msBinder death，9325ms final BLOCKED/workerIdentityMissing。

确切触发来源 NOT VERIFIED；可能Activity重建/重入，但没有本轮专门生命周期trace，不能当成已确认根因。当前Service在同一进程重新初始化provider时不安全，Coordinator不能关联该失败Worker身份并取得completion，故不回收其marker。没有为成功结论忽略该failure。

`coordinator-result.json` 最后被第二operation BLOCKED结果覆盖，故单独从限定日志保留主operation JSON；[最终结果](android-public-target-operation.json)为第二operation，两个结果必须一起读。

## 最终存储与安装

pidof :offline_worker无输出，研究Activity不在activity列表；主operation profile/cache/no_backup metadata/marker/registration均不存在。额外operation未创建profile/cache/metadata，但 `cf...registration.json` / `cf...worker.json` 两个marker保留，缺completion不手工绕过fail-closed规则清除。**本轮新增marker=2**，不能说最终新增operation无残留。历史3个cache、5个空metadata目录未删除；默认provider/runtime文件依旧存在，App storage非0。证据：[storage inspection](android-public-target-storage-inspection.txt)，仅研究包路径/生命周期字段，不含正文或凭据。

安装前pm path核验正式与研究包；只pull已安装研究APK到忽略build目录并用apksigner验证旧/新研究签名SHA256一致：4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8。aapt核验研究applicationId com.mediaflow.research.v040.lifecycle / min29 target36 /新增INTERNET。仅同签名Debug研究APK install --user0 -r。正式com.mediaflow.mediaflow v0.3.0的APK路径前后相同；共存，未停止、覆盖、卸载或清除正式数据，未pm clear/adb uninstall。研究包保留安装。

## 状态与第二阶段判断

| 项目 | 状态 |
| --- | --- |
| Windows Network Observation | BLOCKED |
| Windows normal cleanup | FAIL，原真实失败根因NOT VERIFIED |
| Windows recovery | PASS，历史范围 |
| Windows Browser Observation route | BLOCKED |
| Android device/runtime | PASS，PJZ110实际运行 |
| Android lifecycle A | PASS，仅历史两轮正常离线研究范围；本轮全operation cleanup FAIL |
| Android 离线安全停止 | PASS，仅历史受控范围 |
| Android 真实安全停止 | NOT TESTED，未检测到触发条件 |
| Android Network Observation | BLOCKED，未取得目标对象/完整响应观察能力 |
| 目标图文结构 | NOT VERIFIED |
| 图片 URL | NOT VERIFIED |
| 图片下载 | NOT TESTED |
| production feasibility | BLOCKED |
| 剩余合法高价值候选 | NOT TESTED：离线Coordinator重入/Worker复用保护与document-start桥接健康诊断；通过后下一轮再决定真实验证 |
| 第二阶段附件结束条件 | NOT VERIFIED |

Android没有实证security条件导致路线停止，且document-start是否实际运行/命名根覆盖尚有实现验证问题，**不能宣布Windows与Android已共同达到Browser Observation研究边界**。下一具体合法实验只在离线验证Activity重建/并发入口拒绝、精确身份与桥接确认，不越过任何安全停止、不真实重试；真实路径仍需用户下一轮另行决定。Windows结论不变，不宣布整个v0.4.0不可实现。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。暂停，未进入第三阶段。

## 文件、命令与检查

修改研究Manifest、OfflineWorkerService.java、CoordinatorActivity.java和六个状态文档（v0.4.0 README/research README/stage2/feasibility/RC/Android README）；新增PublicPageScript.java、本记录、主/最终两个JSON、log、storage inspection。无删除，无production文件修改，无新增依赖、无第三方代码复制。仅独立研究APK权限改变，正式manifest/包依赖不变。

实际命令：adb devices -l；既有Gradle9.1/JDK17离线 `-p v0.4.0/research/poc/android-lifecycle --offline --console=plain assembleDebug lintDebug`；pm path正式/研究包；pull仅研究APK；apksigner verify --print-certs旧/新研究APK；aapt dump badging；adb install --user0 -r仅研究包；一次 `adb -s 40fcb99f shell am start -W -n com.mediaflow.research.v040.lifecycle/.CoordinatorActivity --es targetUrl https://www.douyin.com/share/note/7690029886242009957`；限定tag logcat；run-as本研究包cat结果/marker、ls -la cache/no_backup/files/worker_operations及root；pidof worker；dumpsys activity仅过滤本研究Activity；pm path正式包复核；dart analyze browser_observation_probe.dart；git diff --check/stat、branch/HEAD/status。

初次构建因Java文本块URL正则转义失败，未运行真实目标；将解码从JS移入原生gate后最终build/lint成功，0errors/13warnings，未假装无警告。dart analyze No issues found。无Dart修改，不format。git diff --check通过；目录未跟踪，diff stat空；另检查新增/修改文本空白。

未做第二目标/重复导航、Windows实验、图片下载、正式Parser接入、Release build、正式验收、Flutter全量回归、真实安全停止条件PASS验证、并发/Activity重建离线修复实验。无Git写操作。cwd/top-level D:\projects\mediaflow-v040；branch feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；status ?? v0.4.0/。

【项目目标兼容性检查】Android独立研究已真机测试但重入生命周期FAIL、新网络权限与共享provider元数据需关注；Windows未重测且原FAIL/BLOCKED保持；iOS/macOS/Linux本模型暂不支持/未测，仅Adapter理论方向。Bilibili/Douyin正式Parser、Xiaohongshu/YouTube/X/Instagram/其他未来平台、PlatformDetector、ParserService、Unified Content Model、MediaContent/MediaResource、Downloader、Media Processing、UI、History、Settings、Logging、本地存储未修改/未回归；研究不构成正式Browser Adapter。隐私/零服务器保持、不导入账号状态、不读取或导出凭据、不MITM/代理/重放。正式依赖/包体积未变，研究进程及10秒预算仅单次耗时证据，性能/维护/跨provider风险未验证，正式发布仍BLOCKED。
