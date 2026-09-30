# ANDROID GALLERY PRODUCTION ACCEPTANCE PASS（2026-09-29）

同时标记 **DOUYIN STATIC GALLERY CORE IMPLEMENTATION COMPLETE**。本轮停止，不进入发布阶段。

此结论限定为当前仓库production组件、独立Android Debug验收入口、PJZ110与固定目标作品的真实链路。它不等同普通App首页图文UX/Release GUI验收、所有作品稳定可用或v0.4.0正式发布完成。Windows先前spike PASS保持；H2永久冻结。

## 41项结果

| 项目 | 真实结果 |
| --- | --- |
| 1 设备/API | OnePlus PJZ110，实际Android17/API37、arm64，serial40fcb99f；附件16/API36为旧状态。 |
| 2 复用已有session | 优先调用getExistingSession；上轮最终cleanup已清除profile，故开始时没有可复用session，未强制丢弃有效会话。 |
| 3 重新登录 | 是，已验收Desktop Session Host；测试人员本人正常扫码并点击确认。 |
| 4 sessionid | present=true、length32。 |
| 5 sessionid_ss | present=true、length32。 |
| 6 ttwid | present=true、length127。真实值未进入报告、console、fixture或Git。 |
| 7 x-tt-argus | 启用1，仅F2DouyinGalleryDetailClient内部受可关闭bool控制；没有公共HTTP client/旧视频/Bilibili修改。Android本轮未重复A/B，成功证明此配置可用，不单独证明header在Android上必要。 |
| 8 detail次数 | 目标Gallery真实detail恰好1次，无重试。计数在网络调用前写入安全phase文件，阻止意外重启重复。正常登录网页与两项旧parser回归有各自正常网络访问，不计作目标Gallery detail。 |
| 9 HTTP | 200；business JSON，Argus gate=false，signature error=false。 |
| 10 body | 62,155 UTF-8 bytes；不导出完整raw响应。 |
| 11 target | aweme_id=7690029886242009957，严格匹配。 |
| 12 type | aweme_type=68。 |
| 13 images | 13。 |
| 14 resources | 1个MediaContent(imageGallery)，13个MediaResource(image)，ID唯一，URL非空。 |
| 15 URL不同 | 13个不同HTTPS URL；恢复后仍13个不同URL。 |
| 16 顺序 | Adapter结果逐项对应真实images顺序；Task逐项对应resources；History恢复IDs仍image:0..12有序。没有补齐或替换响应。 |
| 17 tasks | 现有downloadTasksFromMediaContent生成13个Gallery任务。回归的两项真实video另有2个任务，仅用于旧History模型验证，不下载。 |
| 18 resourceIndex | 0..12是现有资源列表位置/稳定resourceId末尾位置；对应task.id末尾1..13。没有新增公共resourceIndex字段或新mapper。 |
| 19 下载数量 | 恰好2，resource[0]/[1]；其余11项未执行下载。 |
| 20 文件/MediaStore | 见下表；Download/MediaFlow公开保存路径，MediaStore Downloads两项、MIME=image/webp，系统Images URI也成功打开。 |
| 21 大小 | 495,946 bytes / 725,672 bytes，均大于0。 |
| 22 内容不同 | SHA256不同；两张均Flutter codec解码成功，测试人员也确认内容不同。 |
| 23 系统图库 | 分别ACTION_VIEW两项真实MediaStore URI；用户确认第一张正常，第二张正常/无损坏且不同。不是仅由decoder代替系统显示验收。 |
| 24 History写入 | 现有JsonDownloadTaskRepository保存13项Gallery/前2completed，再保留两项真实video；既有projectDownloadHistory得到13资源/2完成的作品卡。 |
| 25 cold History | force-stop独立包后启动；13项、IDs/顺序、前2completed、两个video记录恢复通过。用户点击既有History页面的只读验收入口，确认13资源/2完成/两条视频。 |
| 26 cold session | 同次cold start ready，无重新扫码；native仅about:blank恢复owned profile。sessionRestart=true。 |
| 27 cleanup | 最后clearSucceeded=true；再次cold start sessionAbsentAfterRestart=true，native profileRestoreCheck.exists=false，最终phase=cleared；独立包force-stop。下载文件/History保留，不删除用户媒体。 |
| 28 Douyin视频 | 原production DouyinParser解析7682375032253180345得到ParserSuccess/VideoInfo，经现有video adapter仍video；未经过Gallery Adapter，未注入Gallery session/header。 |
| 29 Bilibili | 原production BilibiliParser解析BV1uzez6UEoP得到ParserSuccess/VideoInfo；无下载，未新增Cookie/兼容header。 |
| 30 analyze | flutter analyze --no-pub lib test：No issues found。 |
| 31 test | 完整flutter test --no-pub：227 passed / 6 skipped；日志末行+227 ~6 All tests passed。无新增无意义单元测试；本轮新增的是有界真实验收断言。dart format完成。 |
| 32 Debug | arm64、lib/android_gallery_acceptance.dart独立Debug构建通过；包名/签名核验后install-r。 |
| 33 Release | 当前默认production入口arm64 Release构建通过，19,112,475 bytes（工具18.2MB）；未安装Release，未宣称正式发行签名或Release GUI通过。 |
| 34 文件 | 本轮修改已有未跟踪lib/android_gallery_acceptance.dart、v0.4.0/README.md、research/README.md；新增本报告。未删除源码，未修改协议/native host/signer/公共模型/Downloader/History实现。 |
| 35 Git | feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；完整状态见末尾。 |
| 36 Git写 | 无commit/push/merge/tag/PR/reset。既有改动保留。 |
| 37 Android PASS | 达到ANDROID GALLERY PRODUCTION ACCEPTANCE PASS，限定当前真实验收范围。 |
| 38 core complete | 达到DOUYIN STATIC GALLERY CORE IMPLEMENTATION COMPLETE；不是发布标记。 |
| 39 唯一blocker | 本轮验收无剩余blocker；普通产品UX、正式发行/更多样本不在此轮完成范围。 |
| 40 下一轮 | 等待所有者指定后续目标；本轮结束不自行进入发布或扩大平台/协议范围。 |
| 41 兼容性 | 见下。 |

## 下载文件

目录：`/storage/emulated/0/Download/MediaFlow/`

| 资源 | 文件名 | bytes | MediaStore Downloads URI |
| --- | --- | ---: | --- |
| 0 | 都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 001.webp | 495946 | content://media/external/downloads/1000030353 |
| 1 | 都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 002.webp | 725672 | content://media/external/downloads/1000030354 |

完整路径分别为：

```text
/storage/emulated/0/Download/MediaFlow/都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 001.webp
/storage/emulated/0/Download/MediaFlow/都让让 我女神来了#张元英 #wonyoung #自然系ootd #阳光明媚穿搭 #阳光遇上白月光穿搭 002.webp
```

系统图库使用content://media/external/images/media/1000030353与1000030354，均由用户确认。SHA256分别为9b7d4e184e909e629004035995b9a63d778311d23464adb2c75b1cbfccc08525、b53f33a81c78dd37c7915e5d29a8d17e7e6a911abb0ab061073b7fc2da58ff16。

## 验收实现与安全边界

当前非Pythonproduction client/signer/Adapter产生真实模型，existing mapper、HttpDownloadService、LocalDownloadFileStore、AndroidMediaStorePublisher、JsonDownloadTaskRepository与History投影承担原有职责。验收入口增加严格身份/type/资源唯一/order/task断言、安全transport观察、旧parser回归以及现有History只读页面；不是临时解析器/下载器，不手工构造业务JSON，不使用fixture或Windows helper。新页面AbsorbPointer禁止额外下载操作。

URL通过sourceUrl=https://www.douyin.com/note/7690029886242009957传给当前production detail client。UA/Client Hints、query、signer、headers、endpoint和session subset均沿用当前候选，不根据结果调整。legacy navigator.platform仍Linux aarch64，没有注入Windows值。没有H2/UIFID/新endpoint/其他header研究。

正式v0.3.0安装com.mediaflow.mediaflow lastUpdateTime保持2026-09-24 19:35:48；仅安装com.mediaflow.mediaflow.galleryv040独立Debug包，与正式安装共存。每次APK核验applicationId及SHA256=4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8后install-r，签名兼容。没有卸载/覆盖正式包、pm clear或读取正式应用数据。只移除历史失败的非敏感验收result.json开启明确授权的新轮次；旧结果已快照。没有删除session作为强制重新登录手段。

Cookie/Token从owned profile到私有client内部消费，不进入MediaContent/Resource、History或普通日志。恢复History时额外检查credentialHeadersPresent=false。只查询本轮两张文件的MediaStore条目，不扫描其他应用媒体。没有自动完成扫码/challenge、读取账号密码、第三方解析服务、Python/F2 CLI、repo外解析脚本或Windows helper参与。

忽略的安全证据目录build/android-gallery-real-acceptance/：downloaded-result.json、restart-result.json、history-summary.json、clear-result.json、final-result.json、session-ready-states.json、final-session-states.json、flutter-test.log。只保存允许的状态/公共结果/文件metadata，不保存完整raw响应、完整Cookie jar或签名敏感输入。domain/path/expiry等Cookie属性未由当前CookieManager接口提供，不编造；requestDomain仅查询作用域。

## 【项目目标兼容性检查】

| 范围 | 状态与限制 |
| --- | --- |
| Windows | 既有Gallery真实spike PASS保持；本轮未重新验收、未修改Windows功能。SDK自动生成文件换行已恢复，最终无额外diff。 |
| Android | 当前独立Debug候选真实Gallery/两下载/系统图库/History与session cold restore/cleanup通过；Debug、Release构建通过。正式Release GUI、普通App首页gallery UX以及多作品稳定性未因此通过。 |
| iOS | 此Douyin session暂不支持，理论需WKWebView Adapter；未构建实测。 |
| macOS | 此Douyin session暂不支持，理论需WKWebView Adapter；未构建实测。 |
| Linux | 此Douyin session暂不支持，需独立Browser Adapter/runtime评估；未构建实测。 |
| Bilibili | Android已知公开视频原Parser真实回归成功；下载/全人工矩阵未重跑。 |
| Douyin | 当前一个static gallery与旧视频真实成功；不声称所有图文/视频或账号环境恢复。H2继续永久冻结。 |
| Xiaohongshu/YouTube/X/Instagram/其他未来平台 | 未新增实现；无平台特例进入公共业务层。 |
| PlatformDetector/ParserService/Parser/Adapter | Detector/Service未改；production Gallery client/Adapter及原video Parser复用。独立验收入口不能冒充普通UI全链路已接入。 |
| Unified Content Model/MediaContent/MediaResource | 未改；真实13资源与video适配均成功，session不进入公共模型。 |
| Downloader | 未改；2张真实HTTP到MediaStore成功；本轮没有重新验证Range/暂停/失败重试全矩阵，离线回归保持。 |
| Media Processing | 未涉及，保持与解析/下载分离。 |
| Browser Adapter | 仅App-owned named profile正常登录/恢复；本轮未改变Desktop配置，不进行内容网络观察。系统Activity重建仍不由cold-process恢复替代。 |
| UI | 增加独立验收入口的只读既有History页面，没有产品UI大改；用户确认作品卡恢复。 |
| History | 现有Repository/投影/页面实测13资源、2完成，两个真实video记录保留。未读取正式安装History，不能声称正式用户全部旧数据已现场核对。 |
| Settings/Logging/本地存储 | 普通设置未新增手工凭据项；安全phase计数防止重复请求，History无credential headers，profile最终删除。下载媒体及History保留用于复核。 |
| 隐私/零服务器 | 本地解析/签名/保存；仅正常平台请求，无第三方数据上传、账号凭据导入或云解析。 |
| 第三方依赖/license | 无新增依赖或代码搬运；既有F2-derived Apache-2.0封装与NOTICE未改（Johnserf-Seed/f2 commit a30feaf92a40f421273b01b6ef36aa83a93f63c0）。AndroidX依赖不变。 |
| 安装包体积/性能 | Release18.2MB、19,112,475 bytes；未做性能benchmark或大批量下载压力测试。 |
| 后续维护/正式发布 | 非官方协议、固定desktop配置/上游兼容header与媒体URL有效期仍是维护风险；一次真实成功不代表长期稳定。core验收标记不触发发布或Git操作，等待下一轮明确目标。 |

## Git工作区

branch=feature/v0.4.0；HEAD=e2ea89d4e156c843af09b4c491984a2206f1135b。

git diff --stat（不含未跟踪文件）：4 files changed, 58 insertions(+), 8 deletions(-)，均为本轮前已存在的tracked变更；AGENTS.md未修改。

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
