# Android 离线安全停止闭环（2026-09-27）

## 结论与范围

Android 离线安全停止 **PASS，限 PJZ110 上两次受控 Worker/Coordinator operation**。Android lifecycle A / active protection / operation 精确清理保持已测范围 PASS。真实目标网络、真实平台安全检测及结构化数据均未验证；production feasibility BLOCKED。本轮使用 i-have-adhd Skill 组织规则核对、实现、真机双轮和收口；AGENTS.md 优先。

全程没有真实平台请求；研究包无 INTERNET，WebView blockNetworkLoads=true、JavaScript=false，仅 loadDataWithBaseURL 离线 HTML。response/body/hydration/decoder/navigation 的后续测试是无正文的离线消费替身，**不是调用真实 Parser/decoder，不是取得平台响应**。

## 实现

保留独立 :offline_worker 与无 WebView Coordinator。新 ObservationGate 将取消与消费置于同一同步锁内；消费回调只能在 gate 未取消时执行，避免 check/use 间隙。WebView 请求观察和后续导航入口也使用 gate；离线夹具始终拒绝跟随导航。

Coordinator 在真实页面加载后，先调用实际 cleanup guard：活动进程 PID/startTicks 对应时 ACTIVE_REFUSED，profile 保持存在；随后发送 SECURITY_STOP。Worker 验证已加载且尚未关闭，进入 securitySignal：记录 securityStopTriggered → 同步取消 gate → 移除专用 observation Handler 的待执行任务 → 记录 observationCancelled → 验证晚到事件被拒绝 → 调用同一个 closeView 核心退出路径。closeView 同样用于普通关闭，取消时没有延长观察窗口，也没有加载/读取正文或 decoder 操作。

安全信号本轮来源是明确标记 securityFixture 的受控 IPC。未来真实事件可进入同一 research securitySignal/cancelObservation/closeView 边界，但本轮 **没有实现或证明真实平台检测器接线**，没有修改 production 安全停止。

关口证据不是仅检查计数为0：六类入口在取消前均至少消费一次无敏感替身，取消前排队六个任务，安全事件同步取消队列，再尝试六类晚到消费；每类拒绝增加、每类消费计数从取消前到最终均不变，queuedConsumed=0 / queuedCancelled=6。任务移除为立即操作；renderer退出回调期间再次快照，Coordinator独立检查最终计数，没有为捕获数据额外等待。

Worker 沿已有退出协议 terminate 本实例唯一 renderer → 等待 onRenderProcessGone → destroy WebView → 写 completion marker / 发送 completion → stopSelf / System.exit(0)。**实测 rendererGone 在 destroy 之前**，保留真实顺序，不为了匹配示意箭头伪造时序。renderer terminate 非 Worker 异常强杀，也非人工 force-stop。

Coordinator 要求 completion、Binder death、OS /proc/PID不存在、op/nonce/PID创建ticks/精确profile归属一致后才删除；新增安全字段/六类计数校验不满足则 fail closed。精确路径与 symlink/canonical 边界沿用上轮。仅本次 profile/cache/no_backup metadata与两个marker，未扩大到清空研究根目录。

## 两次真机结果

device40fcb99f/PJZ110；上轮已确认Android17/API37/arm64/WebView151.0.7922.199，本轮连接device并实际运行。同一最终构建连续两次，第一冷启动、第二暖Coordinator但新Worker。

| 事件（ms，从Coordinator启动基准计时） | operation 1 | operation 2 |
| --- | ---: | ---: |
| Worker start | 106 | 98 |
| profile allocate | 211 | 186 |
| offline page loaded | 272 | 232 |
| active cleanup refused / profile preserved | 273 | 233 |
| security stop triggered | 274 | 235 |
| observation cancelled / late events rejected | 274 / 274 | 235 / 235 |
| closeRequested / renderer terminate requested | 274 / 274 | 235 / 236 |
| rendererGone / WebView destroy | 294 / 294 | 255 / 255 |
| Worker completion received | 301 | 262 |
| Binder death | 325 | 282 |
| OS Worker exit confirmed | 325 | 283 |
| Coordinator ownership validation | 326 | 284 |
| automatic profile/cache/metadata cleanup | 328 | 285 |
| markers deleted / final | 328 / 328 | 285 / 285 |

operation1 b63724f924a04bc684ca5fd54cc7bd49，PID7311/ticks18824612；operation2 a0f1f1df8cea4754b0efe3a7aa28d30e，PID7497/ticks18824788。两轮各OBSERVATIONConsumed=2，其他五类Consumed=1；取消后每类Rejected=1，最终Consumed不增。队列消费0、取消6。所有结果activeProtection=true / binderDeath=true / normalCompletion=true。

证据 [operation 1](android-security-stop-operation-1.json)、[operation 2](android-security-stop-operation-2.json)、[限定标签日志](android-security-stop.log)、[最终storage检查](android-security-stop-storage-inspection.txt)。进程pidof :offline_worker无输出，dumpsys activity中无本研究Activity；rendererGone已确认本Worker renderer退出，不声称系统所有WebView进程为0。两个operation profile/cache/metadata/worker marker/registration均不存在，worker_operations文件数0。Coordinator主进程可存活，不承载目标WebView。

## 历史残留与安装安全

最终版本新增 operation 未产生新的可识别残留。原3个历史cache目录及5个空metadata目录前后保留，因marker不存在不猜测归属删除。研究APK默认provider metadata、files结果、shared_prefs等仍存在，不能说研究App storage完全清空。全局历史残留清理BLOCKED/其他provider存储覆盖NOT VERIFIED保持。

安装前pm path确认正式com.mediaflow.mediaflow与独立com.mediaflow.research.v040.lifecycle均存在；pull仅研究APK到忽略build目录，apksigner核验已安装研究包和新包SHA256均为4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8，aapt核验独立包名/minSdk29/target36/无INTERNET。仅同签名Debug研究包 adb install --user 0 -r；两个包共存，无正式覆盖/停止/卸载/数据清除，无pm clear/adb uninstall。正式APK path前后不变，没有读取正式用户数据。研究包保留安装。

## 状态

| 项目 | 状态 |
| --- | --- |
| Windows Network Observation | BLOCKED |
| Windows normal cleanup | FAIL，原真实失败根因 NOT VERIFIED |
| Windows recovery | PASS，限历史研究范围 |
| Windows Browser Observation route | BLOCKED |
| Android device/runtime | PASS，真机离线 |
| Android worker lifecycle | PASS，正常及本轮安全停止受控退出 |
| Android active-worker protection | PASS，两次实际拒绝活动清理 |
| Android automatic profile cleanup | PASS，限本轮两次精确operation；历史清理BLOCKED |
| Android lifecycle A | PASS，限已测模型 |
| Android 离线安全停止 | PASS，限受控Worker/Coordinator与替身消费入口 |
| Android Network Observation | BLOCKED，未运行真实平台 |
| 目标图文结构 | NOT VERIFIED |
| 图片 URL | NOT VERIFIED |
| 图片下载 | NOT TESTED |
| production feasibility | BLOCKED |
| 剩余合法高价值候选 | NOT TESTED：Android最小真实目标安全停止/数据入口实验，需下一轮单独判断 |
| 第二阶段附件结束条件 | NOT VERIFIED |

Level1H / Human PASS保持。真实响应读取、真实hydration/decoder、真实安全资源检测及异步在途正文取消语义均未验证，本轮只是离线gate与进程/精确cleanup闭环。Worker异常退出、Coordinator死亡、PID实际重用、并发、跨provider仍未测试。Windows未重跑/修改。

本轮证据仍不足以满足附件任一 A–D 结束条件，继续停留第二阶段。完成后暂停，不进入真实网络或第三阶段。

## 文件与实际命令

修改：OfflineWorkerService.java、CoordinatorActivity.java；Android README、v0.4.0 README、research README、stage2、feasibility、RC。新增ObservationGate.java、本记录、两份安全operation JSON、storage inspection、限定标签log。删除0。保留现有所有研究文件与旧证据。

实际执行（工具使用本机已有路径，Gradle离线，无新增下载）：

```text
adb devices -l
gradle -p v0.4.0/research/poc/android-lifecycle --offline --console=plain assembleDebug lintDebug
adb -s 40fcb99f shell pm path <正式包/研究包>
adb -s 40fcb99f pull <仅已安装研究APK> build/android_lifecycle_research/installed-research-before.apk
apksigner verify --print-certs <已安装研究APK/新研究APK>
aapt dump badging <新研究APK>
adb -s 40fcb99f install --user 0 -r <新研究Debug APK>
adb -s 40fcb99f shell am start -W -n com.mediaflow.research.v040.lifecycle/.CoordinatorActivity --ez securityFixture true
adb -s 40fcb99f shell run-as com.mediaflow.research.v040.lifecycle cat files/coordinator-result.json
# 上述start/result连续两轮
adb -s 40fcb99f shell pidof com.mediaflow.research.v040.lifecycle:offline_worker
adb -s 40fcb99f shell dumpsys activity activities
adb -s 40fcb99f shell run-as com.mediaflow.research.v040.lifecycle ls -la cache no_backup files/worker_operations
adb -s 40fcb99f shell run-as com.mediaflow.research.v040.lifecycle ls -la
adb -s 40fcb99f logcat -d -s MF040Coordinator:I MF040Worker:I *:S
dart analyze v0.4.0/research/poc/browser_observation_probe.dart
git diff --check
git diff --stat
git branch --show-current
git rev-parse HEAD
git status --short
```

研究assembleDebug成功；lintDebug成功，0errors/10warnings（历史ProfileStore feature检查等未由本轮假装解决）。dart analyze No issues found。无Dart修改，不运行format。git diff --check通过，全目录仍未跟踪，git diff --stat为空不是没有研究修改；另核查本轮文本空白。

未运行真实目标网络/图片下载/Flutter全量回归/Release build/正式验收。无production改动、无新增依赖/第三方代码搬运（继续使用既有Android SDK和Apache-2.0 AndroidX依赖）；没有Git写操作。仓库cwd/top-level D:\projects\mediaflow-v040，feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b，status ?? v0.4.0/。

## 项目目标兼容性检查

Android本研究模型已实际测试，provider特定路径/真实事件取消/异常残留风险仍在；Windows未重测，旧FAIL/BLOCKED保持；iOS/macOS/Linux本模型暂不支持/未构建未测，仅独立Adapter理论方向。Bilibili/Douyin正式解析及Xiaohongshu/YouTube/X/Instagram/其他未来平台未新增支持；PlatformDetector、Parser/Adapter正式接口、Unified Content Model、MediaContent/MediaResource、Downloader、Media Processing、ParserService、UI、History、Settings、Logging、本地存储未修改也未回归。研究安全gate不等于production Browser Adapter。隐私/零服务器保持；正式依赖和安装包体积未变，研究新进程启动和锁/取消开销只有本轮时序，未做性能基准。后续维护须考虑真实异步管线和provider更新；正式发布仍BLOCKED。
