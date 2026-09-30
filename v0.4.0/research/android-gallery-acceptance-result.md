# Android Gallery 等价实现与 PJZ110 验收 — 2026-09-29

**未达到 ANDROID GALLERY PRODUCTION ACCEPTANCE PASS。**

当前唯一真实验收 blocker：**测试人员未能在 Android App-owned 会话入口完成正常会话建立，Session Adapter 未返回可用授权 handle。** 没有服务端响应，不能推断 signer、Argus 或 detail 协议失败。

两个正常会话尝试均在 detail 之前停止：第一次反馈“无法完成或已取消”；随后用户明确要求“继续验收，现在再登录一下”，因此另行重开一次，反馈“未出现登录窗口或无法完成”。未进一步区分这两个选项的具体情况，不把它写成平台明确封禁或已完成登录。

两次合计真实 detail **0**，下载 **0**。第一次清理后保存非敏感记录，仅重置独立测试包的验收状态文件；没有重复 detail、改 UA、补 Cookie 或恢复协议研究。第二次失败后停止，完成清理及冷启动核验。

## 36 项答复

| # | 项目 | 实际结果 |
|---|---|---|
| 1 | Android Session Adapter | AndroidDouyinSessionProvider + AndroidDouyinSessionHost，私有 MethodChannel，AndroidX WebView named profile。 |
| 2 | App-owned | 是，profile名mediaflow_douyin_v040，处于独立测试包自身sandbox；不使用系统浏览器/其他App/默认共享WebView profile。正常建立未成功验收。 |
| 3 | 登录 | 测试入口缺session时请求用户本人正常交互；测试人员未确认本轮成功登录。 |
| 4 | Browser Observation parser | 未恢复，没有DOM、hydration、response抓取或旧H2 runner。WebView仅正常会话及标准navigator/window facts。 |
| 5 | session字段 | 仅实际存在的sessionid/sessionid_ss/ttwid，及共享backend已支持的可选正常msToken；当前没有成功消费真实授权subset。UA/platform/metrics来自正常WebView；Android CookieManager不提供cookie expiry元数据，未伪造。 |
| 6 | x-tt-argus | Android Gallery factory默认true，可关闭；仅F2DouyinGalleryDetailClient使用。真实detail未发出，不能称本轮Android已验证该header必要性。 |
| 7 | detail次数 | 0，两次会话尝试合计。 |
| 8 | HTTP | 未执行，status/body长度均N/A。无signature/security层证据。 |
| 9 | target | 验收目标7690029886242009957；未取得真实Android aweme_detail。 |
| 10 | aweme_type | Android真实未取得；离线fixture为68。 |
| 11 | images | 真实未取得；离线13。 |
| 12 | MediaResource | 真实未产生；Android factory离线13。 |
| 13 | 不同URL | 真实未验证，不能引用Windows结果代替Android。 |
| 14 | 顺序 | 离线共享adapter/mapper回归通过；真实未验证。 |
| 15 | DownloadTask | 真实0；共享mapper离线生成13。 |
| 16 | resourceIndex | 离线列表位置0..12。现有任务无独立resourceIndex字段，不改模型。 |
| 17 | 实际下载 | 0。 |
| 18 | 两图片size | N/A，未生成Android图片文件。 |
| 19 | 不同图片 | 未验证。 |
| 20 | 系统图库 | 未验证。 |
| 21 | History重启 | 未进行真实gallery History验收，无真实下载任务可恢复；既有History离线回归通过。没有读写正式App History。 |
| 22 | session重启复用 | 未建立可用session，无法验收重启复用；仅清理后的冷启动核验通过。 |
| 23 | session清理 | 两次clearSucceeded=true，第二次cleanupVerifiedOnRestart=true；清除named profile浏览数据后，冷启动删除pending profile。测试包最后force-stop，保留安装及非敏感结果，不卸载/清除整个App。 |
| 24 | 旧Douyin video | 既有离线契约/Parser/UI回归通过；本轮未在线验收。 |
| 25 | Bilibili | 既有离线回归通过，本轮未在线验收。 |
| 26 | analyze | flutter --no-version-check analyze --no-pub lib test：No issues found。 |
| 27 | test | **223 passed / 6 skipped**；新增8项Android bridge/factory测试。Windows signer golden及既有31项backend、18项adapter测试继续通过。 |
| 28 | Android build | 普通main Debug和独立验收Debug均构建通过，后者实际安装运行。Release构建未通过：GeneratedPluginRegistrant引用不在Release classpath中的IntegrationTestPlugin；offline pub get刷新后仍失败，未手改生成Java或扩大Gradle架构。无Release签名配置，未运行Release smoke。 |
| 29 | 文件 | 见下方本轮文件列表。 |
| 30 | Git status | 见下方；原有AGENTS.md、windows/CMakeLists.txt及v0.4.0内容保留。 |
| 31 | Git写 | 无commit/push/merge/tag/stage/reset/checkout。 |
| 32 | Android PASS | 否。 |
| 33 | CORE COMPLETE | 否，Windows既有PASS不能替代Android。 |
| 34 | 当前blocker | Android正常App-owned session无法完成/不可用；尚未进入detail层。 |
| 35 | 下一轮唯一目标 | 查明并验证Android正常会话交互入口为何未返回可用handle。继续冻结H2/signer/endpoint/协议，不自动发起下一次实验。 |
| 36 | 兼容性 | 见下方检查。 |

## 设备与安装安全

实际设备 `40fcb99f / OnePlus PJZ110 / arm64-v8a`，ADB读取为 **Android17/API37**；附件预期Android16/API36与当前实机不同。compile/target SDK36；本轮不构成Android16真机验收。

原正式包：`com.mediaflow.mediaflow`，v0.3.0/versionCode3，Release cert SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。测试包：`com.mediaflow.mediaflow.galleryv040`，Debug cert SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。两签名不兼容，因此使用独立applicationId；首次安装前确认测试包不存在。后续仅同签名更新此测试包，安装前再次核对签名。

只通过ADB明确安装目标包，没有flutter run自动卸载流程。正式包没有覆盖、卸载或数据清除，最后version/签名/lastUpdateTime仍为原值（2026-09-24 19:35:48）。测试包自身经过force-stop/重启及同签名install-r，保留安装；没有adb uninstall/pm clear。既有research包未操作。安装的测试包内实际primaryCpuAbi=arm64-v8a（Debug APK包含其他ABI，不代表实机运行其他ABI）。

## 实现、许可与清理边界

复用原Dart F2 backend、signer、Gallery Adapter、模型、mapper、Downloader及History；没有Android专属第二套parser/model/downloader。唯一signer改动是输入校验接受正常navigator.platform中的空格/标点（例如Linux aarch64），签名算法及Windows golden未改变；不是伪造Win32身份。

采用AndroidX MULTI_PROFILE，读取该profile CookieManager；仅在native内筛选detail scope允许名称，私有channel不向UI/日志公开真实值。仅读取UA和标准window/navigator数值，不读取password、DOM内容、storage/SDK数据，不观察challenge网络。

清理先关闭/销毁WebView，再用DELETE_BROWSING_DATA清除该profile的cookie/cache/site storage并检查scope Cookie为空。loaded profile的删除可能受进程生命周期限制，因此保存非敏感pending-delete标记；冷启动先删除/检查该特定profile，再返回cleared。不是重启后重新登录，不扩大到默认profile。Android API对磁盘异步清理不承诺即时物理擦除，本报告不作物理安全擦除保证。设计依据：[Profile](https://developer.android.com/reference/androidx/webkit/Profile)、[ProfileStore](https://developer.android.com/reference/androidx/webkit/ProfileStore)、[WebStorageCompat](https://developer.android.com/reference/androidx/webkit/WebStorageCompat)。

正常交互入口和session消费并未真实验收成功；不能把上述编译/API边界写成用户登录能力已恢复。错误路径无session、revoked/expired、403、invalid JSON、空images均有离线拒绝测试。

F2来源/Apache-2.0沿用third_party/f2/NOTICE.md与LICENSE。本轮没有新增依赖；复用既有androidx.webkit 1.15.0。pubspec添加两份归属assets，供Android等Flutter二进制打包；不复制GPL/商业限制signer。无Python、Windows helper、F2 CLI或外部解析服务参与Android流程。

最终Debug APK再次构建通过，ZIP条目核验包含assets/flutter_assets/third_party/f2/LICENSE（11357 bytes）与NOTICE.md（3239 bytes）。最终归属assets构建未再次安装手机；已安装的隔离验收包仅用于上述会话/清理步骤，未作为正式发布产物。

## 文件与命令

新增：

- android/app/src/main/kotlin/com/mediaflow/mediaflow/AndroidDouyinSessionHost.kt
- lib/features/parser/data/douyin/gallery/android_douyin_session_provider.dart
- lib/android_gallery_acceptance.dart（显式隔离验收入口，不注册正式UI）
- test/features/parser/android_douyin_session_provider_test.dart
- 本报告

修改：MainActivity.kt注册/释放Session Host；f2_gallery_signer.dart平台字符串校验；pubspec.yaml归属assets；v0.4.0/README.md、research/README.md最新结果导航。删除：无。没有改公共模型、Downloader、History、正常主UI或ParserService。

构建隔离验收：

```text
MEDIAFLOW_V030_PROBE_APP_ID_SUFFIX=.galleryv040
flutter --no-version-check build apk --debug --no-pub --target-platform android-arm64 -t lib/android_gallery_acceptance.dart
```

该入口会在空验收状态时开启正常会话，**不要未经新授权再次清除结果文件或重新登录**。失败状态锁定不再发detail。不要卸载正式包来解决签名冲突。

非敏感证据：build/android-gallery-acceptance/attempt-1-cancelled.json、attempt-2-result.json；手机测试包app_flutter/gallery_acceptance/result.json。没有导出raw response、完整jar或凭据。Release错误可由正式main release命令复现，未安装其产物。

Branch feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b。

```text
 M AGENTS.md
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M pubspec.yaml
 M windows/CMakeLists.txt
?? android/app/src/main/kotlin/com/mediaflow/mediaflow/AndroidDouyinSessionHost.kt
?? lib/android_gallery_acceptance.dart
?? lib/features/parser/data/douyin/gallery/
?? test/features/parser/android_douyin_session_provider_test.dart
?? test/features/parser/douyin_gallery_adapter_test.dart
?? test/features/parser/douyin_gallery_backend_test.dart
?? test/features/parser/windows_gallery_production_spike_test.dart
?? test/fixtures/
?? third_party/
?? tools/douyin_session/
?? v0.4.0/
```

tracked diff --stat：AGENTS.md既有31行23+/8-；MainActivity.kt4+；pubspec.yaml3+；windows/CMakeLists.txt既有28+；合计58+/8-。新增/untracked内容不包含在stat中。生成的Windows文件仅换行变化已恢复一致，无内容改动。git diff --check通过。

## 【项目目标兼容性检查】

| 平台 | 状态 |
|---|---|
| Windows | 保留之前真实Gallery spike PASS；本轮golden/离线回归通过，未重新执行Windows在线验收或构建。 |
| Android | Debug构建/隔离安装与native清理重启实际测试；正常授权会话未完成，Gallery线上验收未通过，Release构建失败。实际API37，不是API36实测。 |
| iOS | 共享Dart协议层理论可复用，需WKWebView Session Adapter；未构建/实测。 |
| macOS | 共享Dart层理论可复用，需对应Session Adapter；未构建/实测。 |
| Linux | 共享Dart层理论可复用，需对应浏览器Session Adapter；未构建/实测。 |

- Bilibili/Douyin旧video：离线回归通过，未在线验收。Douyin gallery：Android仍未贯通，Windows既有结论不变。小红书/YouTube/X/Instagram/其他未来平台：未引入支持或特例，其实现不绑定当前session协议。
- PlatformDetector、ParserService、正式UI：未改路线；临时入口仅验收。Parser/Adapter保持独立；Browser Adapter仅会话，没有恢复Observation解析或H2。
- Unified Content Model/MediaContent/MediaResource、mapper：未改，13图离线映射通过。Downloader/History：复用旧能力，本轮没有真实下载/重启gallery History证据，不能宣称通过。Media Processing：未引入平台耦合。
- Settings/Logging/本地存储：不增加Cookie手填项，不记录真实值；本地新增独立profile和非敏感状态。正式App用户数据未操作，测试包会话清理已核验。
- 隐私/零服务器：没有第三方解析/云处理，App-owned状态不跨App导入，实际detail0次。Profile/cookie实现需要受控生命周期和平台API支持。
- 依赖/体积：没有新runtime/package；新增归属assets约15KB源码文本，最终包增量未对比测量。复用WebKit依赖、profile API特性不足时安全返回unsupported，不退回默认profile。
- 性能/维护：本轮不能评价真实Android请求性能；平台标准navigator输入被允许，算法golden不变。Session UI适配和Release生成插件引用仍须据事实处理，不能用协议重写替代。
- 正式发布：Android PASS和CORE COMPLETE均未达到，不降低Android门槛、不发布v0.4.0。本轮暂停，下一轮先处理正常Android session入口。
