# v0.4.0 Gallery 发布前差距盘点（2026-09-29）

结论：**NOT RELEASE CANDIDATE READY**。双平台 static gallery core 的真实验收仍有效；普通 `lib/main.dart` 用户入口尚未接通，不把独立验收包的成功写成正式用户流程完成。本轮没有发送 detail、下载媒体、安装 APK、改协议或恢复 H2。

## 普通入口与现有能力

| 环节 | Windows | Android |
|---|---|---|
| 粘贴链接、识别平台、ParserService | 已正式接入旧视频流程 | 已正式接入旧视频流程 |
| Douyin video/gallery 分派 | 缺 production glue；默认 factory 仅注册旧 DouyinParser | 同左 |
| App-owned session infrastructure | helper、私有 profile、IPC 已实现并真实验收 | 原生 host、私有命名 profile 已实现并真实验收 |
| 普通入口首次登录/续解析 | 缺 Application/UI glue | 缺 Application/UI glue |
| 复用本地 session | Provider 可用；普通入口未调用 | Provider 与冷启动复用已验收；普通入口未调用 |
| 失效提示/重新登录/原请求恢复一次 | 缺 glue | 缺 glue |
| 退出并清除平台数据 | Provider clear 已验收，缺普通设置入口 | 同左 |
| detail → Adapter → MediaContent | production 模块可用，仅 spike 调用 | production 模块可用，仅验收入口调用 |
| Gallery 结果 UI | 现有通用多资源卡可接收 MediaContent；默认解析不可达 | 同左 |
| 下载/History | 通用实现、映射和真实组件链已验收；普通 Gallery 链未贯通 | 同左，冷启动 History 已在独立验收包验证 |

实际阻断位于 `createDefaultParserService`，不是 signer、模型或 Downloader。`LinkParserViewModel` 能处理 ParserContentSuccess，但没有会话动作、失效恢复及 Gallery typed failure 文案映射。不能仅注册一个 parser 后宣称流程完整。

Windows helper 已由 CMake 构建并随应用安装到同级目录；Provider 可自动启动它，无需用户手工启动。正式 factory 尚未解析已打包的同级路径，不能继续使用 spike 的仓库绝对路径。Android 原生 bridge 已注册，但普通 Dart factory 未消费；当前成功流程使用独立验收入口。

## 唯一下一轮 P0：双平台普通入口的 Gallery/会话闭环

在 Douyin 私有 Parser/Adapter 及 Application 边界内完成一个纵向任务：

1. 创建正常平台 factory，选择本地 Session Provider 和 Gallery backend；Windows 从应用目录定位 bundled helper，Android 使用现有原生 bridge。不依赖研究脚本或测试包。
2. 使用既有 URL 识别/正常解析能力分派 video/gallery，不把所有视频失败当成登录需求，保护旧 Douyin 视频与 Bilibili。
3. 首次需要会话时展示用户主动登录动作；保留原 URI，用户取消明确结束。登录完成自动继续原请求一次，后续复用已有本地会话。
4. 仅明确 sessionExpired 时提示重新登录并允许用户授权后恢复一次；securityGate 不通过重新登录/追加材料自动重试。建立操作代次，输入改变或取消后丢弃旧结果。
5. 添加退出登录并清除平台数据动作，清除失败对用户可见。Windows 未准备好时点击确认应保留窗口，与 Android 一致。
6. 将业务结果接入现有多资源卡、mapper、DownloadManager、History；增加 typed failure → 产品文案映射。两端普通入口各做真实验收，再判断 RC，不能以构建通过代替验收。

不新增公共模型，不重写下载/历史，不继续协议研究。普通流程目标是“粘贴 → 必要时主动登录 → 自动继续 → 图文结果 → 全部/选中下载 → 历史”。

## UI、下载、History 与错误

现有 Home 多资源卡显示类型、图片数量、按 upstream 顺序的编号/复选项，默认全选，支持下载全部及选中项；下载列表和 History 已提供资源任务状态、失败重试。离线 13 图 Adapter/mapper 契约通过；本轮未做普通入口 13 图真实 GUI 验收。结果卡没有图片预览和逐资源状态徽标，不需要为了美观重做。

现有文件系统会避免与最终文件或 `.part` 同名覆盖；MediaStore/Windows 前两图真实存储已在历史验收验证。全部 13 任务可生成，全部 13 实际下载未验收。长标题会在文件名 80 字符截断时丢失末尾序号，这是 P1，需保留稳定 ordinal，而非重写 Downloader。Home 活跃任务集合仅存在于当前 Widget；重进页面的进度关联也是 P1。

| 类型 | 正式文案/行为要求 | 当前差距 |
|---|---|---|
| 无效/不支持链接 | 链接无效/暂不支持 | 已有基础提示，不能误报 session |
| noSession | 需要完成一次抖音登录，提供主动动作 | backend 类型存在；缺普通入口映射 |
| sessionExpired | 抖音会话已失效，请重新登录 | 类型存在；缺恢复原请求一次 |
| securityGate/detail failure | 平台暂未允许本次解析，请稍后再试 | 缺统一产品映射；不展示 Argus/UIFID/signer 或内部请求 |
| empty images | 未取得可下载的图片，不能假成功 | Adapter 明确失败；缺产品文案映射 |
| 下载失败 | 显示失败、允许重试对应任务 | 现有下载系统支持；普通 Gallery 链待贯通 |

History 现有模型可保留 gallery 13 项、前两项完成与旧视频记录，无需模型迁移。正式端到端恢复仍应在下一轮普通入口验收。

## P0 / P1 / P2

- P0：上述普通入口/会话闭环未接通；首次、失效、清除和错误处理缺口属于同一纵向任务。两端普通入口真实验收尚未完成，RC 被阻断。
- P1：长标题文件名保留资源序号；页面重进后绑定下载组进度；Release 分发的 helper/WebView2 可用性与 Android WebView 能力缺失提示、正式错误/取消/过期测试及多作品回归。
- P2：图片预览、逐资源状态徽标与体验优化；不作为本轮 UI 重做理由。

## 兼容字段、临时代码与隐私

`x-tt-argus: 1` 只在 Gallery detail 内部可关闭兼容开关中使用。底层客户端默认 off，Android factory 与成功 Windows candidate 显式 on。Windows 已有严格 A/B：off 403、仅加此头 on 200；Android成功使用该设置，未单独证明必要性。不能推广到公共 HTTP client、Douyin video 或其他平台，本轮不再研究它。

独立 `android_gallery_acceptance.dart`、`android_session_acceptance.dart` 有测试 target 和按钮，但不被 `lib/main.dart` 导入，也不是普通路由/资源；保留验收证据，不发布为正式入口。目标 ID 在 fixture/测试/验收/研究里，不在 Gallery 核心写死。无 Python、F2 CLI、远程解析器或 repo 外解析脚本 runtime；Windows .NET/WebView2 helper 是已打包的受控基础设施。

本轮最小修正：Android session 元数据诊断仅在 debuggable 包运行；诊断写盘失败不再打断正常会话。Release 不加载/写入该诊断记录。未新增 Cookie/二维码/签名输入日志；私有 session 不进入模型、History 或公共日志。后续 glue 必须保持此边界，不能把异常对象或 URI/query/header 完整打印。

## 来源与许可证

F2 `Johnserf-Seed/f2`，固定 source commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`，Apache-2.0。直接改编 `f2/utils/crypto/bytedance/abogus.py` 为 Dart signer；request model/header/crawler 为行为参考，未复制整套项目或 Python 依赖。SM3 为规格实现。

`third_party/f2/NOTICE.md` 列出对应文件、版权与修改；LICENSE/NOTICE 为 Flutter assets，Windows CMake 也安装其副本。production LICENSE 与固定 vendor LICENSE SHA256 相同：`C71D239DF91726FC519C6EB72D318EC65820627232B2F796219E87DCF35D0AB4`。本轮尝试在线核对固定源失败（Cache miss），以现存固定 vendor 和来源记录核验，不声称完成新的 upstream 在线审计。采用的 production 模块未发现 GPL、商业限制或来源不明 signer；不把研究参考项目等同于生产依赖。

## 本轮验证与文件

- dart format：1 文件，0 格式变更。
- analyze lib test：无问题。
- 完整 flutter test：227 passed / 6 skipped；包括既有 Gallery/backend/mapper 与 UI 回归，不代表普通 factory 已接通。
- 四种正常 `lib/main.dart` 构建全部通过：Windows Debug / Release、Android arm64 Debug / Release；未安装、覆盖、卸载或清除手机应用。
- Windows Release 有既有 C# CS1668 LIB 搜索路径警告，不阻断构建。未修无关环境配置。依赖有可更新提示，未升级。
- Android APK：Debug 83,550,760 bytes；Release 19,112,795 bytes（18.2 MiB）。Windows Debug/Release 均有同级 MediaFlowDouyinSession.exe；Release licenses/f2/LICENSE 与 NOTICE.md 完整存在。
- 日志：`build/gallery-release-gap-audit/`；无真实 detail 或新媒体下载。
- 修改：AndroidDouyinSessionHost.kt（Release 诊断边界）、gallery capabilities 注释、F2 NOTICE、v0.4.0 两个索引。
- 新增：本报告。删除：无。没有修改公共模型、Downloader、History、signer 或请求策略。

## Git

分支 `feature/v0.4.0`；HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。不 commit/push/merge/tag/PR，不删除原修改。当前 tracked diff 为 AGENTS.md、MainActivity.kt、pubspec.yaml、windows/CMakeLists.txt（先前已有），58 additions / 8 deletions；本轮 production 修正位于原有 untracked Gallery/native 文件组。完整 status 随最终核验记录。

```text
 M AGENTS.md
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M pubspec.yaml
 M windows/CMakeLists.txt
?? android/app/src/main/kotlin/com/mediaflow/mediaflow/AndroidDouyinSessionHost.kt
?? android/app/src/main/kotlin/com/mediaflow/mediaflow/DouyinDesktopSessionHost.kt
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

## 【项目目标兼容性检查】

| 平台 | 状态及限制 |
|---|---|
| Windows | Core 已实际测试；普通入口尚未接通，helper/WebView2 分发可用性仍需正式环境验收 |
| Android | Core 在 PJZ110 已实际测试；普通入口尚未接通，依赖 WebView profile/desktop metadata 能力，不能降低设备验收门槛 |
| iOS | Session Adapter 暂不支持；核心模型/协议理论可复用，需 WKWebView/安全存储适配，未构建 |
| macOS | Session Adapter 暂不支持；理论可复用，需平台 Adapter，未构建 |
| Linux | Session Adapter 暂不支持；理论可复用，需受控浏览器 Adapter，未构建 |

Bilibili 与旧 Douyin 视频走原 Parser，历史真实回归及本轮离线回归有效，未新增真实网络回归。小红书/YouTube/X/Instagram/未来平台本轮没有新增实现；Gallery 特例保持私有模块，未来插件不需要继承其 headers 或会话。

PlatformDetector/ParserService 现有流程保留，但 Gallery 注册正是 P0；UI 复用而非重做。Unified Content Model、MediaContent、MediaResource、Downloader、History、本地存储无需迁移；Media Processing 保持独立且本轮未扩展。Settings 缺退出会话入口，Browser Adapter 的正常用户登录能力不等同于协议绕过。Logging 已收紧原生诊断，后续 UI glue 仍需防止异常/凭据泄漏。

隐私/本地/零服务器保持：session 仅归属 App profile 和本地私有 Adapter，不导入其他 App/浏览器、不上传第三方。依赖未新增，Windows 仍有 .NET/WebView2 分发成本，Android 仍有系统 WebView 能力风险；构建产物大小只反映当前包，不把变化归因于本轮三行注释/诊断。性能未做新基准，诊断 Release 关闭减少本地写盘。维护需跟踪平台协议变化及 Adapter 可用性，保留 F2 attribution。正式发布未授权、RC 不成立；本轮结束暂停，下一轮仅上述 P0。
