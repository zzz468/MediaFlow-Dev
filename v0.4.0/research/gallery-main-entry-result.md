# 普通主入口 Gallery + Session 闭环（2026-09-29）

状态：**WINDOWS MAIN ENTRY GALLERY PASS**、**ANDROID MAIN ENTRY GALLERY PASS**、**V0.4.0 GALLERY RELEASE CANDIDATE READY**。限定本轮固定作品、当前设备与正常用户会话，不代表所有图文/设备覆盖。只标记候选准入；未发布、未执行 Git 写操作，完成后暂停。

## 正式实现

`lib/main.dart → Home → LinkParserViewModel → ParserService → DouyinContentParser → Gallery backend → Adapter → MediaContent → 现有多资源 UI → mapper/DownloadManager → Json History`。

默认 factory 的 Douyin 条目改为平台内 dispatcher，保留原 DouyinParser 作为 video delegate，不增加第二套顶层服务。明确 `/note/<id>` 进入 Gallery；短链接通过正常 HTTP redirect 的 final URI 确认为 note 后进入同一路径；其余未知/video 链接交给旧 video parser，失败本身不触发 Gallery 登录。Bilibili 两个 parser 原样保留。未搜索新 endpoint、研究 UIFID、改 signer 或重启 H2。

平台 factory 在 Windows 使用应用可执行文件同级 `MediaFlowDouyinSession.exe`；Android 使用现有 Desktop Session Host。正常 main 无环境变量、Cookie 输入框、独立脚本或手工 helper 启动要求。其他系统返回 Gallery capability 不可用；不冒充五端 session 已实现。

`ParserFailureCode.sessionRequired/sessionExpired/userCancelledLogin` 是应用可消费契约，UI 不检查 HTTP/Argus/Cookie 字符串。Gallery 非会话失败统一安全文案，原异常及平台 marker 不进入 UI。sessionRequired 的动作是“登录并继续”，expired 是“重新登录并继续”；点击是用户主动登录意图，不代替用户扫码/challenge。

continuation 只保存在 Notifier 内存：原 URI、平台所在 state、operation generation 和 resumed 标记。重复点击登录被合并，取走 continuation 后只续解析一次；输入修改/clear/Provider 重新初始化递增 generation，迟到结果被丢弃。普通 Widget/路由重建不重发请求；完整进程退出不恢复未完成的解析操作。真实 Activity 在登录进行中重建尚未专项实测，离线 observer/导航重建已验证，不声称可跨进程保留 pending continuation。

Provider 保留过期 context 的状态；backend 可返回明确 expired。状态查询复用刚读取的状态，避免无会话时额外启动 helper。登录获取新 context 后继续原请求；再次会话拒绝不无限续解析。取消回到解析页，原 URL 保留，可主动重试。

Windows 未登录时误点确认，现在保留会话窗口并提示继续完成正常登录。Android 保持已验证的 desktop UA/Client Hints/profile 配置，未改 navigator.platform。Settings 新增用户确认后的退出/清除动作，调用同一 session Provider，取消 pending continuation，保留下载和 History；清理失败明确提示。

Home 使用既有 Gallery 卡、复选项、数量/编号与下载动作。重新进 Home 时输入框恢复 Notifier 中的原 URL；失败/成功后可主动重试。没有增加图片预览、公共模型、下载器或历史模型。

## 离线/构建证据

- 新增 `douyin_main_entry_test.dart` **15 项**：匿名 video、未知 video 不升级登录、已有 session 的13图/任务、required/expired 契约、登录原 URI 续解析、一次重试上限、取消、双击/迟到输入结果、security 安全文案、短链接 note 路由、其他平台隔离、observer 重建；另通过正式 Home Widget 验证登录→13选项→一个13任务组→History/返回不重复。
- Widget 下载使用 offline DownloadService 和内存仓库；不把其模拟完成写成真实下载。
- dart format 完成；最终 analyze lib test：无问题；完整 flutter test：**242 passed / 6 skipped**。
- Windows Debug / Release、Android arm64 Debug / Release 正常 main 构建全部通过。既有 Windows CS1668 LIB 搜索路径警告不阻断构建，未修无关环境配置。
- 日志在 `build/gallery-main-entry/`。6 项 skipped 保留真实网络测试的 opt-in 门槛，本轮真实验收走 UI 而非这些 spike runner。

## 真实普通入口证据

Windows 使用普通 **Release `lib/main.dart`**。最初直接启动的 Debug 进程没有可见窗口，不将它计为验收；通过 computer-use 定位正常 Release 主界面，确认媒体输入与 sessionRequired 动作。没有自动操作认证窗口、读取二维码或真实 Cookie。

用户确认 Windows 正常登录后自动显示13张图片，无需重贴链接；确认随后关闭窗口。再次启动普通候选后，用户确认复用会话成功、图片下载/打开及 History 正常。

只读核验正常 Windows History：目标13任务、13 completed、13不同 URL、13不同 resourceId、一个 operation group；另4项其他历史记录保留。用户实际通过 UI 下载了全部13项，本程序没有调用临时下载器或额外下载。前两文件存在、非空、不同 SHA256：

| 资源 | Windows 文件 | bytes | SHA256 |
|---|---|---:|---|
| 0 | `D:\新建文件夹\Dsektop\MediaFlow\都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 001.webp` | 495946 | `9b7d4e184e909e629004035995b9a63d778311d23464adb2c75b1cbfccc08525` |
| 1 | 同目录同标题 `002.webp` | 725672 | `b53f33a81c78dd37c7915e5d29a8d17e7e6a911abb0ab061073b7fc2da58ff16` |

Android 设备 PJZ110 / serial 40fcb99f，使用普通 **Debug `lib/main.dart`**，只用隔离 suffix `.galleryv040`。未使用 android_gallery_acceptance.dart、acceptance Activity 或手工调用 session Provider。ADB 只用于安全安装、现有文件/History 核验、系统打开和冷启动，普通用户解析不需要 ADB。

用户确认从手机普通主界面正常登录、自动显示13资源并点击下载全部。正常 `files/MediaFlow/download_history.json` 中13项均 completed，一个 operation，resourceId 为目标 image:0..12。该正常仓库与先前 `gallery_acceptance/history` 是不同存储位置，正常仓库没有既有视频记录，不能以此声称旧 acceptance 视频记录丢失。

Android 前两文件在 `/storage/emulated/0/Download/MediaFlow/`，同标题 `001 (1).webp` / `002 (1).webp`；bytes 324066 / 414544；RIFF/WEBP magic 可识别；SHA256 `0219e2fc72a15a5dc855bce4431fd577b0531d57d25e5f60a06c291e58ddf5db` / `567f7e377d1658a3ff3e9ea51b17b338edc0b34337e02ff2fcc94abf7caa39bb`，内容不同。仅从已下载文件读取核验，没有新增网络下载。对应系统 images URI 为1000030356/1000030357。两张系统图库均正常、无损坏且不同，已由用户确认。

测试包 force-stop/cold start（不是清数据）后，正常存储保留13项 completed、一个 operation group；用户确认普通 History 显示正常，再次粘贴解析无需登录即可显示13资源，没有点击下载。再次读取确认13个不同 URL/资源，仍是13项任务。Windows 的重启复用与正常 History 也由用户确认。两端真实 HTTP success 可由 client 只接受200及正确 detail 的代码契约与真实 UI 结果证明；未增加网络抓包或敏感 body/签名日志，未声称精确请求次数有抓包计数证据。

## Android 安装安全

现有正式包 `com.mediaflow.mediaflow` / v0.3.0 / versionCode3，lastUpdateTime `2026-09-24 19:35:48` 未变。测试包 `com.mediaflow.mediaflow.galleryv040` Debug，已安装测试包与新 APK 的 SHA256 certificate 均为 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。核验 applicationId/cert 后仅 `adb install -r` 更新隔离测试包；未卸载、清数据或覆盖正式包，未发现测试包签名冲突。

正常 Debug/Release 默认包只构建，不安装；隔离 main Debug 另行构建安装，保留正常包产物副本。正式版号仍0.3.0+3，未擅自修改版本/发布。Release 签名/升级发布验收仍属后续发布准备，不由本次 Debug 安装证明。

## 边界与限制

F2 signer、endpoint、query/UA/header 协议算法保持已有实现。Gallery factory 使用已验证的内部 Argus compatibility setting on；低层可关闭。其头不进入公共 HTTP client、旧 video 或 Bilibili。本轮不做新 A/B、不扩展协议研究。正常 video 原 delegate 保留，Bilibili 离线回归通过，先前真实视频回归证据保留；本轮未重新发视频网络请求。

F2 Apache-2.0、固定 commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`、Dart 改编来源与 LICENSE/NOTICE 沿用已审计记录，无新增第三方代码/依赖。无 Python/F2 CLI/远程解析器。会话仅在自有 profile/私有内存中，未导出/展示真实值，凭据不进入公共模型、任务或 History。

仍有限制：未知 URL 不猜图文类型；长标题序号保护和重进页面进度关联为既有 P1；全部13项系统打开不是本轮门槛；expired/取消通过自动化，不以此声称实际平台会话失效的真机专项验收。跨 Activity 的认证中断专项测试、其他设备/WebView、更多作品和 Release Android 真机未新增实测。全部图片系统显示、正式版本分发及升级继续作为后续收尾，不能写成所有 Douyin 作品都支持。

## 文件与 Git

production 新增：`douyin_content_parser.dart`、`douyin_gallery_factory.dart`（Gallery 私有目录）。

production 修改：ParserService、ParserFailureCode、LinkParserState、LinkParserViewModel、HomePage、SettingsPage；Gallery backend 的 expired 分类、两端 Session Provider 的已读状态；WindowsDouyinSession.cs 的未就绪确认保留窗口；capabilities 注释。

test 新增：`test/features/parser/douyin_main_entry_test.dart`。report 新增：本文件；两个 v0.4.0 索引更新。F2 NOTICE 最后一句更新普通入口启用状态，版权/来源/算法记录不变；构建时的 LICENSE/NOTICE 已包含完整 attribution，这次状态文案不是新增第三方实现。删除文件：无。前轮 AGENTS.md、MainActivity、pubspec、Windows CMake 及其余 untracked core/test/research 保留，不覆盖。

分支 `feature/v0.4.0`，HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。无 commit/push/merge/tag/PR/reset。构建产生的 Windows generated 文件仅换行变化已恢复原 CRLF，没有 Git checkout/reset。当前 tracked diff stat：10文件，209 additions / 16 deletions（包含前轮4个文件），untracked 不含在 stat 内。

```text
 M AGENTS.md
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M lib/features/home/presentation/home_page.dart
 M lib/features/parser/application/parser_service.dart
 M lib/features/parser/domain/link_parser_state.dart
 M lib/features/parser/domain/parser_result.dart
 M lib/features/parser/presentation/link_parser_view_model.dart
 M lib/features/settings/presentation/settings_page.dart
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
?? test/features/parser/douyin_main_entry_test.dart
?? test/features/parser/windows_gallery_production_spike_test.dart
?? test/fixtures/
?? third_party/
?? tools/douyin_session/
?? v0.4.0/
```

## 最终42项答复

| # | 项目 | 结果 |
|---|---|---|
| 1 | ParserService 接入 | 默认 factory 注册 DouyinContentParser，Gallery 经正式 application 层进入 |
| 2 | video 路径 | 保留旧匿名 delegate，不因失败强制登录 |
| 3 | Gallery 路由 | 明确 note URI；短链接正常 final URI 确认为 note；未知不猜 |
| 4 | required 契约 | ParserFailureCode.sessionRequired + 登录并继续 |
| 5 | expired 契约 | ParserFailureCode.sessionExpired + 重新登录并继续 |
| 6 | continuation | 内存 URI/state platform/operation generation/resumed，一次消费，迟到结果丢弃 |
| 7 | 自动续解析 | 两端真实用户确认 |
| 8 | 重贴链接 | 登录续解析不需要；新启动的新解析仍由用户粘贴链接 |
| 9 | Windows main entry | PASS，普通 Release main |
| 10 | Android main entry | PASS，隔离 package 的普通 Debug main |
| 11 | Windows 首次 session | 用户正常登录，自动显示13图 |
| 12 | Android 首次 session | 用户正常登录，自动显示13图 |
| 13 | Windows 复用 | 用户关闭后重启，确认无需登录解析 |
| 14 | Android 复用 | cold restart 后用户确认无需登录解析 |
| 15 | 失效恢复 | application/local-expired 与 server failure 契约自动化通过，真实过期未专项制造 |
| 16 | 用户取消 | userCancelledLogin，保留原 URL，不发 detail；自动化通过 |
| 17 | Gallery UI | 两端正常卡显示13资源，使用既有 UI；导航重进离线验证 |
| 18 | MediaResource | 每端13，目标7690029886242009957，type68；实际任务13个不同 URL/资源 |
| 19 | DownloadTask | 每端正常 History13，一个 operation group；顺序按资源 image:0..12，不新增 resourceIndex 公共字段 |
| 20 | Windows 下载 | 用户实际下载13，前2文件/大小/hash与正常打开已核验 |
| 21 | Android 下载 | 用户实际下载13，前2文件/大小/hash、系统图库正常且不同已核验 |
| 22 | History | 两端用户确认；Android cold restore13 completed，一个组；Windows另4记录保留 |
| 23 | Douyin video | 旧 delegate 未改，匿名路由/既有完整回归通过；历史真实回归保留，本轮未重发视频请求 |
| 24 | Bilibili | 旧 parser 未改，完整测试通过；历史真实回归保留，本轮未重发视频请求 |
| 25 | spike 依赖 | 无；测试只是 package 隔离，Dart entry 正常 main |
| 26 | Python/F2 CLI | 无 |
| 27 | Argus 边界 | 现有 Gallery 私有开关 on，可关闭，不进入公共 HTTP/video/Bilibili |
| 28 | analyze | lib test 无问题 |
| 29 | test | 242 passed / 6 skipped，新增15项 |
| 30 | Windows Debug | build通过；不是此次可见 UI 的验收产物 |
| 31 | Windows Release | build通过，普通 GUI 实测 |
| 32 | Android Debug | 默认包与隔离 main 包构建通过，后者真机实测 |
| 33 | Android Release | arm64 build通过，未安装 Release |
| 34 | production 文件 | 见上文新增/修改明细；公共模型/下载器/History 不改 |
| 35 | Git status | 上文完整列表，branch/HEAD不变 |
| 36 | Git 写操作 | 无 |
| 37 | Windows milestone | WINDOWS MAIN ENTRY GALLERY PASS |
| 38 | Android milestone | ANDROID MAIN ENTRY GALLERY PASS |
| 39 | RC milestone | V0.4.0 GALLERY RELEASE CANDIDATE READY，限定当前验收范围，未发布 |
| 40 | 当前唯一 blocker | 本轮 P0已消除；仍有上述 P1/未实测范围，不扩展本轮 |
| 41 | 下一轮唯一目标 | 不自动开始下一目标；暂停，等待用户另行指定收尾/发布准备 |
| 42 | 兼容性检查 | 下表与边界审查；不声称五端完整支持 |

## 【项目目标兼容性检查】

| 平台 | 本轮状态 |
|---|---|
| Windows | Debug/Release 构建通过，普通 Release UI 登录、续解析、复用、下载/History 由用户与文件证据确认；单目标局限保留 |
| Android | Debug/Release 构建通过，独立 package 的普通 main 已实测；系统图库、History cold restore、session 复用通过；依赖 WebView profile/desktop metadata 能力 |
| iOS | session Adapter 暂不支持；Domain/mapper 可复用，需 WKWebView/安全存储实现；未构建 |
| macOS | session Adapter 暂不支持；需本地 WKWebView Adapter；未构建 |
| Linux | session Adapter 暂不支持；需受控浏览器 Adapter；未构建 |

PlatformDetector 未改；ParserService 默认 factory 注册平台 dispatcher，session 动作通过 application 层进入，UI 不调用 Gallery backend。Bilibili/旧 Douyin 保留 delegate，其他未来平台本轮未实现，需自身 Adapter，不能继承 Douyin 的会话/头。Unified Content Model、MediaContent、MediaResource、Downloader、History 未修改；Media Processing 未扩展，继续独立。UI 仅增加绑定、登录动作与输入恢复，Settings 仅提供会话清除；后续多平台 session actions 需扩展 application capability，而非公共层堆平台协议。

Browser 能力隔离于平台 Provider；Logging 不新增身份值或签名输入，原生 Release 诊断继续关闭。本地存储/历史数据未清除；不导入浏览器/其他 App 状态，不上传第三方，零服务器。依赖无新增，Windows .NET/WebView2 与 Android 系统 WebView 的体积/可用性风险保持现有隔离边界；未做性能基准，不声称零影响。维护需跟踪协议与 WebView 兼容，保留来源与版权。正式发布/Git 写操作未授权，本轮不执行。
