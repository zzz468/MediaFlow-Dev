# Windows Gallery production spike — 2026-09-29

**WINDOWS GALLERY PRODUCTION SPIKE PASS**

**ARGUS COMPATIBILITY HEADER REQUIRED IN CURRENT WINDOWS ENVIRONMENT**

本次目标 `7690029886242009957`。仓库内 production candidate 发出真实请求，经已有 Gallery Adapter、公共模型、mapper、Downloader 完成前两张图片下载；测试人员确认 Windows 默认图片查看器正常显示、内容不同，并确认已完成登录。这是一次目标作品/当前环境的 spike 验收，不等于整个平台或正式发布完成。

## 请求证据

| 请求 | x-tt-argus | HTTP | body bytes | Argus gate | signature error |
|---|---|---|---|---|---|
| A | 不发送 | 403 | 46 | 是 | 无明确错误 |
| B | 1 | 200 | 62,141 | 否 | 无明确错误 |

总 detail 请求 **2**。A/B 复用同一 URI（含相同 canonical query 和已生成的 A-Bogus）、UA、Referer、Cookie、session、endpoint、其他 headers；B 唯一增加 `x-tt-argus: 1`。没有重新签名、刷新 session、补参数或第三请求。body 长度为接收到的解码文本重新 UTF-8 编码的长度，不是压缩传输字节长度。

对照仅在 A 非200且 body 包含已知 Argus/UIFID marker 后允许 B；transport 包装层封闭请求额度。真实业务 body、签名 URL、Cookie 和 signer 输入没有输出到报告。受控开关原有 production 默认仍 false；本轮没有扩展公共 HTTP client 或自动启用正式用户入口。

## 32 项答复

| # | 项目 | 结果 |
|---|---|---|
| 1 | App-owned session | 成功，使用当前 WindowsDouyinSessionProvider 与已有 .NET/WebView2 helper。 |
| 2 | 登录 | 缺 session 触发正常交互窗口；测试人员确认已完成登录。challenge 是否单独出现未确认，不推断。 |
| 3 | 真实 detail 次数 | 2；没有任何额外 detail/retry。正常登录页面加载不计入 detail 请求额度。 |
| 4 | 第一次 HTTP | 403 / 46 bytes。 |
| 5 | Argus gate | A 遇到已知 Argus/UIFID gate；B 消失。 |
| 6 | A/B | 已执行，严格只增加一个 header；签名仅生成一次。 |
| 7 | x-tt-argus | 当前 Windows 环境的有界对照证明成功需要此兼容头。不是对全部客户端/未来环境的永久结论。 |
| 8 | signature error | 两次均未发现明确 signature error；B 业务成功，不另做 signer 研究。 |
| 9 | business JSON | B 取得真实 status_code=0、目标 aweme_detail；没有 fixture 替代或人工补字段。 |
| 10 | target id | 7690029886242009957，Adapter 和验收断言确认。 |
| 11 | aweme_type | 68。 |
| 12 | images | 13。 |
| 13 | MediaResource | 13，resource id 唯一；一个 imageGallery MediaContent。 |
| 14 | 不同 URL | 13个不同非空 HTTPS URL；仅内存检查，没有报告真实 URL 列表。 |
| 15 | 顺序 | 每项 resource URL 对照真实 images 同位置 url_list，全部一致。 |
| 16 | DownloadTask | 现有 downloadTasksFromMediaContent 生成13项。 |
| 17 | resourceIndex | 列表位置0..12；现有模型没有独立 resourceIndex 属性，按列表位置、resourceId、task id 和 URL 核对，未新增公共字段。 |
| 18 | 实际下载 | 仅 resource[0]、resource[1] 两张，剩余11张未下载。 |
| 19 | 两文件路径 | 见下方文件表。 |
| 20 | 两文件大小 | 495,946 / 725,672 bytes。 |
| 21 | 内容不同 | SHA256不同，Flutter实际解码成功，测试人员视觉确认内容不同。 |
| 22 | Windows打开 | 已以 Start-Process 打开两文件；测试人员确认正常显示、无明显损坏。 |
| 23 | History | 使用现有 JsonDownloadTaskRepository 在 build 内隔离验收目录保存/恢复13项 image task，2 completed、11 queued；content id/资源信息保留。未写用户正式 History，未宣称主UI History链已接通。旧 video History 离线回归通过。 |
| 24 | analyze | spike 后 `flutter --no-version-check analyze --no-pub lib test`：No issues found。 |
| 25 | test | 显式在线项1 passed；spike后全套215 passed / 6 skipped。新增在线项普通回归默认跳过。dart format完成。 |
| 26 | production修改 | 本轮没有修改 backend、signer、native provider、Downloader、History、公共模型或主UI；新增验收调用层与报告导航。 |
| 27 | Git status | 见下面完整状态；原有修改保留。 |
| 28 | Git写操作 | 无 commit、push、merge、tag、stage、reset、checkout。 |
| 29 | PASS | 是，全部12项真实 spike 条件满足；不是正式发布 PASS。 |
| 30 | 当前唯一blocker | 本轮Windows spike无剩余blocker。跨核心平台验收尚缺Android等价私有session实现与真机验证。 |
| 31 | 下一轮唯一目标 | Android real-device equivalent implementation / acceptance；遵守已有安装、签名、独立测试包和数据安全规则。本轮不开始。 |
| 32 | 兼容性 | 见下方逐项检查。 |

## 实际文件

下载目录：`D:\projects\mediaflow-v040\build\windows-gallery-spike\images`。

| index | 文件名 | bytes | SHA256 |
|---|---|---|---|
| 0 | 都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 001.webp | 495946 | 9B7D4E184E909E629004035995B9A63D778311D23464ADB2C75B1CBFCCC08525 |
| 1 | 都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 002.webp | 725672 | B53F33A81C78DD37C7915E5D29A8D17E7E6A911ABB0AB061073B7FC2DA58FF16 |

文件实际存在、size>0、WebP可解码。隔离History：`build/windows-gallery-spike/history/download_history.json`；非敏感结果：`build/windows-gallery-spike/result.json`。History包含公开资源URL，未复制到Git fixture/Markdown，不包含Cookie或session字段。真实raw detail未持久化。

退出清理：Provider.clear()返回true，后续独立 Test-Path 检查 `%LOCALAPPDATA%\MediaFlow\private-session\douyin-v040` 为false。未读取其他profile或系统浏览器，未保存密码，未执行账号无关操作。session只经私有内存/pipe在平台内部消费，没有泄露真实值。

## 实施与重现边界

新增 `test/features/parser/windows_gallery_production_spike_test.dart` 是仓库内显式在线验收入口，不是独立解析实现。它调用既有 F2DouyinGalleryDetailClient/F2GallerySigner、WindowsDouyinSessionProvider、DouyinGalleryAdapter、downloadTasksFromMediaContent、HttpDownloadService/HttpDownloadClient/LocalDownloadFileStore 和 JsonDownloadTaskRepository。没有 Python/F2 CLI、repo外解析脚本、第三方远程解析器或历史H2runner。

本轮只执行了一次：

```text
flutter --no-version-check test --no-pub --dart-define=MEDIAFLOW_WINDOWS_GALLERY_SPIKE=true test/features/parser/windows_gallery_production_spike_test.dart
```

这条命令会开启新的真实受控验收，不应为复查本报告再次运行。正常全套回归不带该 define，不联系 Douyin。此次未修改现有用户正式入口；当前状态是 production candidate 的真实链可用，UI上线和协议长期稳定性不是本次验收结论。

F2直接改编代码的来源/commit/Apache-2.0归属沿用 `third_party/f2/NOTICE.md`、LICENSE；本轮未新增第三方代码或依赖，未更改 signer。Windows沿用上轮Debug构建的helper，Dart candidate由本轮Flutter测试实际编译执行。未新增Windows构建任务；Android/iOS/macOS/Linux均未构建或安装。

新增：在线验收测试、本报告。修改：`v0.4.0/README.md`、`v0.4.0/research/README.md` 最新结果导航。删除：无。build 内生成两张图片、隔离history和非敏感metadata，均不作为源代码fixture。

Branch `feature/v0.4.0`；HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。

```text
 M AGENTS.md
 M windows/CMakeLists.txt
?? lib/features/parser/data/douyin/gallery/
?? test/features/parser/douyin_gallery_adapter_test.dart
?? test/features/parser/douyin_gallery_backend_test.dart
?? test/features/parser/windows_gallery_production_spike_test.dart
?? test/fixtures/
?? third_party/
?? tools/douyin_session/
?? v0.4.0/
```

tracked `git diff --stat`：AGENTS.md 31行（既有23+/8-），windows/CMakeLists.txt 28+（上一轮）；合计51+/8-。本轮新增文件仍untracked，不在tracked stat中。git diff --check通过。

## 【项目目标兼容性检查】

| 平台 | 状态 |
|---|---|
| Windows | 当前目标真实session/detail/13图映射/两图下载/Windows打开已实际测试；旧Debug构建复用，主UI正式入口未启用。 |
| Android | 尚未实现/未实测，本轮未安装；核心Dart模块可复用，需私有WebView Adapter及同等真机验收，不能以Windows成功代替。 |
| iOS | Dart层理论可复用；WKWebView Session Adapter暂未支持，未构建/实测。 |
| macOS | Dart层理论可复用；当前Windows session helper不支持，需对应Adapter，未构建/实测。 |
| Linux | Dart层理论可复用；需本地浏览器session Adapter，当前未支持/构建/实测。 |

- Bilibili：既有离线回归通过，本轮未在线验收。Douyin：单目标静态gallery链真实通过；旧video契约回归通过，不能宣称全平台恢复。Xiaohongshu/YouTube/X/Instagram及未来平台：未开发，其协议不进入本次模块。
- PlatformDetector/ParserService/UI：本轮未改；显式验收调用production candidate，不宣称主UI已发布。Parser/Adapter：独立Douyin模块继续隔离，H2永久冻结，无Browser Observation/SSR/Feed重启。
- Unified Content Model、MediaContent、MediaResource：未改，一作品13有序资源实测。Downloader：复用通用模块，两文件真实保存，其余11任务不执行。History：现有repository隔离恢复通过，不覆盖正式历史，旧video回归保护保留。
- Media Processing：未引入解析或平台耦合。Browser Adapter：只负责正常用户会话，未扩大内容采集。Settings/Logging：没有新增手工Cookie项或真实凭据日志；本地存储是自有profile及验收文件，profile删除实际确认。
- 隐私/零服务器：会话只发给所属平台，下载直接访问平台资源，没有第三方解析/云服务，未读取其他App/浏览器会话。原始body和Cookie留在内存，报告仅安全metadata。
- 第三方依赖/体积/性能：无新增依赖或运行时；沿用Apache归属F2 Dart适配和既有.NET/WebView2。安装包体积本轮未重新测量；detail最多2次且无自动通用重试，本次只下载2张。
- 维护/正式发布：Argus兼容头依赖仅对当前环境已证明，须保持Gallery client局部开关；平台协议与session失效仍有维护成本。五端Adapter与Android同等验收尚未完成，不能把本次Windows spike当正式版本发布完成。

达到PASS后暂停。下一轮仅Android等价实现/验收，本轮不继续开发或路线研究。
