# Android session entry：未达到 READY（2026-09-29）

Windows Gallery spike PASS 保持。Android 本轮只验收正常 session 和构建，detail=0、download=0。测试人员确认移动首页及一次授权宽屏尝试均只有“打开App/下载”，没有正常网页登录入口。停止，不恢复 H2，不展开协议研究。

## 30项结果

| 项目 | 实际结果 |
| --- | --- |
| 1 原失败根因 | 基线 Activity/WebView/profile/页面均建立；首次点击检查时 sessionid、sessionid_ss 不存在，ttwid present/length127。旧逻辑立即 finish(noSession) 关闭窗口。另一个独立阻断是正常移动首页没有网页登录入口，不能把未登录误报成 Cookie flush 问题。 |
| 2 修复位置 | AndroidDouyinSessionHost：显式确认、未ready保持窗口、先flush再读取、异步回调归属检查、安全状态记录；独立 session-only Dart 验收入口。 |
| 3 Host | 原生 Android System WebView + AndroidX named profile mediaflow_douyin_v040；仅 App 自有 profile，最小 Cookie subset，MethodChannel 内部交接。 |
| 4 Browser Observation | 不读取 DOM、localStorage、IndexedDB 或网络响应；JS 仅读取 navigator/window 标准环境 metadata。 |
| 5 显式确认 | “我已完成登录，继续”；未ready保留窗口且提示继续正常登录。测试人员确认窗口保持。 |
| 6 ready | 实际 sessionid 或 sessionid_ss 至少一项存在，并通过共享 context 契约；ttwid不是登录ready的替代条件。 |
| 7 UIFID | 不要求，不研究，不人工提供。 |
| 8 sessionid | 基线未取得；本轮没有正常登录成功证据。 |
| 9 sessionid_ss | 基线未取得；本轮没有正常登录成功证据。 |
| 10 ttwid | 基线存在，length127；不输出真实值。后续页面没有完成登录，未宣称取得新的可信账号 context。 |
| 11 Activity重建 | stale JS callback 已拒绝；系统实际 Activity 重建/重新绑定未完成真机验证，不能标记安全通过。旋转配置不能替代系统重建证据。 |
| 12 operation唯一 | Dart并发调用coalesce离线测试通过；当前页面单个建立操作。跨Activity重建唯一性未实测。 |
| 13 handoff | ready handoff=0。诊断finish(cancelled)可能由dispose/clear调用产生，不等于ready交接。 |
| 14 重启复用 | 正常授权 session 未建立，因此未实测；不把匿名ttwid复用当成登录复用。 |
| 15 cleanup | browsing data清除返回true；冷启动第二次clear验证true，验收phase=stopped。仅测试profile；无pm clear/uninstall。 |
| 16 detail | 0，图片下载0。session-only入口不调用detail/signer/downloader。 |
| 17 Release根因 | Flutter 3.44.6 --no-pub跳过平台registrant按release模式重新生成；此前dev IntegrationTestPlugin引用留在Java，而Gradle release依赖排除dev plugin，导致无法解析类。串行--no-pub仍失败，排除仅由并行构建导致的解释。 |
| 18 Release修复 | 使用正常带pub的release构建，让Flutter生成匹配releaseMode的registrant；未手改生成Java，未把IntegrationTestPlugin加入production runtime，未增加依赖。 |
| 19 Debug | 最终session-only arm64 Debug构建通过；独立包同签名install-r成功。 |
| 20 Release | 最终默认production入口arm64 Release构建通过，APK 19,112,475 bytes（工具18.2MB）；未安装、未验收Release GUI或正式发行签名。 |
| 21 analyze | analyze --no-pub lib test：No issues found。 |
| 22 test | 完整flutter test --no-pub：227 passed / 6 skipped。新增4项session契约测试，Android provider文件共12项；跳过项不算真实平台验收。dart format完成。 |
| 23 设备 | OnePlus PJZ110，实际Android17/API37，arm64，ADB已授权。 |
| 24 文件 | 本轮修改原有未跟踪AndroidDouyinSessionHost.kt、android_douyin_session_provider_test.dart；新增lib/android_session_acceptance.dart、本报告；更新v0.4.0/README.md、research/README.md。无删除。 |
| 25 Git | feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b。完整状态见下。 |
| 26 Git写操作 | 无commit/push/merge/tag/PR/reset。 |
| 27 READY | 未达到 ANDROID SESSION ENTRY READY。 |
| 28 唯一blocker | 当前Android自有WebView正常首页不提供可完成的网页登录入口。尚不能获得ready账号会话。 |
| 29 下一轮 | 决策是否存在平台支持的正常Android App-owned网页登录入口；无确认入口前不执行Gallery真实验收。已测移动/宽屏方式不重复，不增加身份材料碰运气。 |
| 30 兼容性 | 详见下节。 |

## 有界宽屏尝试

用户明确授权一次宽屏布局。仅删除 UA 的 ` Mobile ` 布局标记，保留真实 Android/Chrome 元数据，启用 useWideViewPort/loadWithOverviewMode；UI明确标记宽屏Android。没有伪装Windows、修改signer、观察challenge网络或自动完成验证。用户确认仍只有打开App/下载，失败后停止。该显示设置仍是未验收的candidate，不代表可用的最终登录UX。

安全证据存于忽略构建目录 build/android-session-entry：baseline-full-states.json、baseline-result.json、mobile-no-login-states.json、wide-no-login-states.json 等，仅记录状态/domain/允许cookie名称present/length，不含真实值。CookieManager不提供完整domain/path/expiry元数据；requestDomain不冒充实际Cookie Domain。

## 构建复现

依次执行，避免不同模式生成文件互相干扰：

```powershell
$env:MEDIAFLOW_V030_PROBE_APP_ID_SUFFIX='.galleryv040'
flutter --no-version-check build apk --debug --target-platform android-arm64 -t lib/android_session_acceptance.dart
# 后续新的 shell 中构建默认 production Release；不用 --no-pub：
flutter --no-version-check build apk --release --target-platform android-arm64
```

独立Debug applicationId `com.mediaflow.mediaflow.galleryv040`，SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`；与正式 `com.mediaflow.mediaflow` 共存。正式v0.3.0 lastUpdateTime仍2026-09-24 19:35:48。无覆盖正式包、卸载、清正式数据或签名冲突。仅删除隔离包的非敏感验收phase文件以开启明确授权的新尝试；本地profile通过Adapter正常清理。Release未安装。SDK缓存构建锁需仓库外写权限，已获工具审批；未修改SDK源码。Windows自动生成文件仅换行规范化，最终无diff。

## 【项目目标兼容性检查】

- Windows：此前真实Gallery spike PASS，本轮不修改Windows功能、不重跑验收。
- Android：Debug/Release构建通过；正常登录session未实测成功，正式gallery不能发布为双端完成。Activity重建、成功handoff、授权session冷启动复用仍缺证据。
- iOS/macOS/Linux：理论可通过各自Browser Adapter扩展；当前Douyin session实现暂不支持，未构建/实测，不能沿用Android APIs。
- Bilibili、PlatformDetector、ParserService、公共模型MediaContent/MediaResource、Downloader、History、Settings、本地存储：代码未修改，完整离线回归通过；真实旧视频/下载恢复未在本轮重跑，不扩张通过范围。
- Douyin：仅平台私有Session Host变化；UI只是独立验收入口，普通产品入口未据此宣称恢复。WebView首页布局与平台登录入口存在维护风险。
- Xiaohongshu/YouTube/X/Instagram/其他未来平台：未新增实现；平台特殊Cookie/header未污染公共业务。Media Processing未改。
- Browser Adapter：隔离named profile，不读取系统浏览器或其他App；正常账户会话、生命周期重建和五端差异仍须验收。Logging仅状态metadata；Cookie不进入公共模型、History或日志。
- 隐私/零服务器：仅平台正常网页导航；无第三方解析服务、凭据上传、密码保存、挑战求解或媒体上传。测试profile清理验证通过。
- 第三方：本轮无新依赖/搬运代码。既有F2 Apache-2.0 signer及attribution未修改；AndroidX WebKit既有依赖继续由平台边界隔离。
- 安装包/性能：Release18.2MB，未进行本轮前后尺寸基线或性能对照；WebView启动和布局可能影响登录体验，未完成会话不能宣称性能合格。
- 正式发布：Windows单作品成功不等于双端可发布；Android session及Gallery真实链未完成，本阶段暂停。

## 工作区

`git diff --stat`（不统计未跟踪文件）：4 files changed, 58 insertions(+), 8 deletions(-)。均为本轮前已存在的tracked修改；AGENTS.md保留未改。

```text
 M AGENTS.md
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M pubspec.yaml
 M windows/CMakeLists.txt
?? android/app/src/main/kotlin/com/mediaflow/mediaflow/AndroidDouyinSessionHost.kt
?? lib/android_gallery_acceptance.dart
?? lib/android_session_acceptance.dart
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
