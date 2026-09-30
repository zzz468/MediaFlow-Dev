# ANDROID SESSION ENTRY READY（2026-09-29）

PJZ110 上 App-owned desktop-site WebView 出现正常 PC 登录入口，测试人员本人扫码登录；取得三项最小 Cookie，SessionProvider ready，冷启动复用与 cleanup 均实测通过。本轮 Gallery detail=0、图片下载=0。停止，下一轮仅 Android Gallery Real Production Acceptance；H2 永久冻结。

## 32项报告

| 项目 | 结果 |
| --- | --- |
| 1 原移动UA | Mozilla/5.0 (Linux; Android 17; PJZ110 Build/CP2A.260605.016; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/151.0.7922.199 Mobile Safari/537.36 |
| 2 原metadata | 官方API读回 mobile=true、platform=Android。上一轮用户确认移动及宽屏首页只有Open App/Download。 |
| 3 Desktop UA | Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36 Edg/154.0.0.0；来自全新空profile中的当前Windows WebView2默认Settings.UserAgent，不读取系统浏览器或已有会话。 |
| 4 Client Hints配置 | 官方API支持且读回false/Windows；实际页面navigator.userAgentData也读到mobile=false、platform=Windows、Chromium/Edge154。未抓取网络，不把API/JS验证冒充线上wire header抓包。 |
| 5 System WebView | com.google.android.webview 151.0.7922.199；真机实际Android17/API37，并非附件旧16/API36。 |
| 6 官方API | WebSettingsCompat.setUserAgentMetadata/getUserAgentMetadata，使用USER_AGENT_METADATA能力检查；不支持时返回unsupported，不使用JS spoof。 |
| 7 是否仍暴露Android | UA/UAData已为桌面兼容设置，但legacy navigator.platform仍Linux aarch64；实际运行时仍Android WebView151，不是Windows浏览器。没有注入伪造navigator对象，不能宣称所有设备属性等同Windows。 |
| 8 desktop主页 | https://www.douyin.com/正常加载，站点自身导航到https://www.douyin.com/jingxuan；该URL无敏感query记录。 |
| 9 Open App/Download | 不再仅限此页面表现；用户确认出现PC登录入口。 |
| 10 Login入口 | 是，用户正常操作；未枚举入口或调用私有登录接口。 |
| 11 登录方式 | 页面原生扫码，由测试人员本人完成。 |
| 12 登录成功 | 是，用户确认；native Cookie与Provider ready共同支持。是否出现challenge未单独确认，未自动求解任何验证。 |
| 13 sessionid | present=true，length=32；登录后与最终冷启动restore均存在。 |
| 14 sessionid_ss | present=true，length=32；登录后与最终冷启动restore均存在。 |
| 15 ttwid | present=true，length=127；登录后与最终冷启动restore均存在。 |
| 16 UIFID | 不是ready条件，未采集/研究/手工提供。 |
| 17 Provider ready | 是；本轮三个字段均存在，满足已有backend契约。未加强公共ready规则。 |
| 18 重启复用 | 最终true；force-stop独立包后cold start，在about:blank读取同一named profile并返回ready，没有平台导航或重新登录。此前false已保留，根因为本地容器重复挂载，见下。 |
| 19 cleanup | clearSucceeded=true、clearVerifiedCold=true，最终phase=stopped。清浏览数据后下一cold start确认profile删除；测试包最终force-stop。 |
| 20 Gallery detail | 0；session-only入口没有detail client、signer调用或Downloader调用。 |
| 21 图片下载 | 0。网页自身正常资源加载不计为应用Gallery请求/下载。 |
| 22 analyze | flutter analyze --no-pub lib test：No issues found；没有扩大到无关research lint。 |
| 23 test | 完整flutter test --no-pub：227 passed / 6 skipped；Dart未新增测试或改变已有契约。Native配置与restore通过Debug构建及本轮实际真机验证，不能由Dart单元测试替代。dart format 1 file/0 changed。 |
| 24 Debug | 最终arm64 session-only Debug构建通过，独立同签名install-r。 |
| 25 Release | 最终默认入口arm64 Release构建通过，19,112,475 bytes（工具18.2MB）；使用带pub正常生成release registrant。未安装Release，未完成正式发行签名/GUI验收。 |
| 26 文件 | 修改AndroidDouyinSessionHost.kt及两个v0.4.0 README；新增DouyinDesktopSessionHost.kt、本报告。忽略build目录新增UA probe/metadata证据，未进入Git。无删除production源码。 |
| 27 Git status | feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；状态见下。 |
| 28 Git写操作 | 无commit/push/merge/tag/PR/reset；AGENTS.md等既有修改保持。 |
| 29 READY | 达到ANDROID SESSION ENTRY READY；本轮最小context建立可称ANDROID DESKTOP WEB SESSION READY。不称Android Gallery production PASS。 |
| 30 当前blocker | 本轮session入口/重启复用blocker已解除；Android真实Gallery detail/下载尚未执行，仍是下一验收门。 |
| 31 下一轮 | Android Gallery Real Production Acceptance；此刻暂停，不自行执行。 |
| 32 兼容性 | 见下。 |

## 核心实现与复用失败修正

新增独立DouyinDesktopSessionHost配置类，仅由owned Douyin session view调用，不改其他WebView。官方metadata与UA、wide viewport同时配置；实际navigator字段只读取、不改写。JavaScript/DOM storage沿用正常站点运行配置。named profile、最小Cookie读取、显式“我已完成登录，继续”、flush和未ready保持窗口均保留。

首次桌面登录已成功，但用户重启后ready恢复为false，随后按验收步骤清理。因旧原生诊断每进程覆盖，无法据此判断Cookie丢失。新增最多200条跨重启安全事件，再以同一首页/UA配置正常扫码复核。三个Cookie与ready都成立；cold restore在Cookie读取前抛IllegalStateException。源码显示restore先surface.setContentView(box)，随后activity.addContentView(box)：容器已属于Dialog，重复挂载。

最小修正：只在interactive路径创建Dialog/挂载容器；restore只附加Activity内的1x1 view、加载about:blank。修复后原来的授权profile保留，cold restore三项Cookie再次present并返回ready，证明该次false是本地Host缺陷，不是站点session缺失。没有为此修改signer、backend或Cookie字段。

修复复核时，历史failed-result和states已保存；仅将非敏感验收phase文件恢复到先前真实ready checkpoint，使程序重新执行失败的restore步骤。此文件不含Cookie/Token，未改profile、未伪造restore成功；最终true来自新native调用。没有再次登录或平台导航。然后按原状态机完成清理和cold deletion核验。

同一主页的站点正常导航到/jingxuan不作为人为新增入口；备用登录入口未使用。第二次登录是同一配置的生命周期故障诊断，不是第三种UA/URL策略。登录流程均由本人执行，无自动提交、WAF绕过、SDK hook或Browser Observation内容解析。

## 隐私与设备安装安全

- Cookie仅在owned profile与私有进程桥接中使用；日志/报告仅名称、present、length。没有导出完整jar、密码或账号标识。
- UA探针用全新空WebView2 profile，未导航平台或读取Cookie；已清除该临时profile。Windows production/helper源码未修改。
- Android测试applicationId=com.mediaflow.mediaflow.galleryv040，Debug SHA256=4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8，和设备既有独立测试包一致。每次构建后核验包名/签名再install-r。
- 正式com.mediaflow.mediaflow v0.3.0共存，lastUpdateTime仍2026-09-24 19:35:48。未覆盖/卸载正式包、未pm clear、无签名冲突；研究lifecycle包未改。
- 证据：build/android-session-entry/desktop-ready-states.json、desktop-restart-states.json、desktop-restart-fixed-states.json、desktop-restart-fixed-result.json、desktop-final-result.json、desktop-final-states.json；均为安全metadata，不含Cookie值。
- CookieManager接口未提供此处的domain/path/expiry明细，requestDomain=www.douyin.com仅指查询作用域，不冒充Cookie Domain。未编造expiry。

## API依据与维护边界

采用官方[WebSettingsCompat](https://developer.android.com/reference/kotlin/androidx/webkit/WebSettingsCompat) metadata设置API及[UserAgentMetadata](https://developer.android.com/reference/androidx/webkit/UserAgentMetadata)。这些API生成UA Client Hints；能力必须通过运行时feature检测。仅参考API，不搬运第三方源码，不新增依赖。

桌面兼容配置取自本机实测WebView2 UA，Android实际渲染引擎仍151、Windows参考154。固定版本存在更新维护成本，且legacy platform保持Linux；本轮只证明正常登录入口与session可维护。backend runtime query目前仍沿用Android采集逻辑，尚未证明桌面UA与query组合的服务端兼容性；下一轮真实验收必须如实按响应判断，不把本轮READY当Gallery成功或自动扩张身份模拟。

## 【项目目标兼容性检查】

| 范围 | 状态与实际边界 |
| --- | --- |
| Windows | 既有Gallery真实spike PASS保持；本轮仅新空profile读取UA，无功能改动/重跑Gallery，自动生成文件恢复原换行后无diff。 |
| Android | session入口、正常扫码、native handoff、cold restore与cleanup已实际测试；Debug/Release构建通过。Gallery detail/下载/Release GUI仍未实测，本轮不称双端production完成。系统Activity重建不是本轮已验证的cold-process恢复，不能混写通过。 |
| iOS | 当前Douyin session暂不支持，理论需WKWebView Adapter；未构建实测。 |
| macOS | 当前Douyin session暂不支持，理论需WKWebView Adapter；未构建实测。 |
| Linux | 当前Douyin session暂不支持，需独立Browser Adapter及运行时feature评估；未构建实测。 |
| Bilibili / PlatformDetector / ParserService | 本轮代码未改，离线完整回归通过；真实旧Bilibili解析/下载未重跑，发布前仍须原验收门。 |
| Douyin | 正常session入口获证，不恢复H2/UIFID/W2/W3/SSR/Feed；Gallery实际backend能力下一轮验证。 |
| Xiaohongshu / YouTube / X / Instagram /其他未来平台 | 未新增实现；桌面配置不进入公共模块。各平台应独立评估自己的Session Adapter。 |
| Unified Content Model / MediaContent / MediaResource | 未修改，13图fixture与旧模型回归仍在完整测试中；session不进入领域模型。 |
| Downloader / History | 未修改、未真实下载；已有离线测试通过，不代表本轮验证Range、恢复或MediaStore真实场景。 |
| Media Processing | 未涉及，仍隔离。 |
| Browser Adapter | named profile私有化；配置类仅Douyin调用。UA metadata能力与平台版本是具体维护风险，不适用于所有WebView。 |
| UI | 只调整session窗口模式提示；核心解析不依赖Widget，无大改版。扫码屏幕缩放体验需后续常规UX验证。 |
| Settings / Logging /本地存储 | 普通设置未新增Cookie输入项。safe diagnostics跨重启最多200条；profile清理通过，诊断只留无凭据状态。 |
| 隐私 / 零服务器 | 无系统浏览器/其他App账号读取，无第三方解析服务或日志上传；扫码由用户正常授权平台执行。 |
| 第三方依赖/license | 沿用AndroidX WebKit1.15.0，无新依赖或代码复制。F2 Apache-2.0 signer/attribution未修改，未启动Python/F2 CLI。 |
| 安装包体积 / 性能 | Release18.2MB；精确文件长度19,112,475。未做性能基准；只读metadata诊断有有限文件I/O，未宣称整体性能达标。 |
| 后续维护 / 正式发布 | 需维护Desktop UA/metadata与实际WebView差异，平台可能改变登录页面。单机session成功不是稳定性/多作品或五端发布保证；下一轮唯一门为Android真实Gallery验收。 |

## 工作区

git diff --stat（不含未跟踪文件）：4 files changed, 58 insertions(+), 8 deletions(-)，均为本轮前既有tracked修改。本轮Host修改与新增文件仍在未跟踪集合内。

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
