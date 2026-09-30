# Anonymous Static Gallery Resolver：参考验证收口（2026-09-30）

**结果 D — ANONYMOUS-FAIL（限定本次严格无凭据、原分享页 SSR 分支及本机环境）。不接 production，未达到 ANONYMOUS-GALLERY-RC-PASS。** 保持此前 `WINDOWS MAIN ENTRY GALLERY PASS`、`ANDROID MAIN ENTRY GALLERY PASS`、`V0.4.0 GALLERY RELEASE CANDIDATE READY` 的既定验收范围。本轮暂停，不发布。失败不证明该平台永远不能匿名解析，也不否定样本存在。

## 参考源码、调用链与许可

- [ucmao/media-parser](https://github.com/ucmao/media-parser)，分支 `main`，本轮通过 GitHub commits/main API 核实并下载固定 commit `ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6`，提交时间 `2026-09-28T05:00:44Z`。
- [LICENSE](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/LICENSE)：MIT，Copyright (c) 2025-2026 ucmao。外部源码保留完整许可证；没有复制参考实现到生产代码。
- 审计文件：[douyin_parser.py](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/src/parsers/douyin_parser.py)、`src/parsers/base_parser.py`、`utils/web_fetcher.py`、`tests/live_parser_samples.json`。
- 实际默认图文调用链：构造器 → `fetch_html_data` → Web detail → 失败后 `_try_share_ssr_detail` → `fetch_html_content` → 分享页 → `_parse_ssr_data` → `get_image_list`。默认构造会初始化 signer；分享页抓取会取得 ttwid、构造 Cookie 并可能附带 UIFID。**默认链不是完全不需要 Cookie/session 的实现**，本轮不能按完整默认链运行。
- 本次直接运行原 SSR 方法；保留原请求页面选择、移动 UA/Referer 和其他初始头、结构提取与图片映射。原方法即使输入 note，也访问 `https://www.iesdouyin.com/share/video/<id>`。未将其改成另一个 endpoint。
- 数据来源识别：hydration/RENDER_DATA、router/SSR/init JSON、pace 流结构；图片来自目标 detail 中 `image_post_info.images/image_list` 或 images 等数组。仅按参考数组顺序输出，不能从页面路由 itemId 推导作品媒体。

隔离目录：`D:\dev\tmp\mediaflow-anonymous-reference-ee05d757c7fe`，原源码目录 `media-parser-ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6`，外部独立 venv。运行器通过 AST 载入未改动的原 SSR 方法；跳过构造器，关闭 Cookie/ttwid/UIFID accessor；传输层关闭环境代理、每跳使用新 session、拒绝凭据、仅允许限定 Douyin 页面、TLS 校验开启、最多3跳/1MiB/6秒读取预算。没有复制整套框架、启动 API 服务或使用第三方解析服务器。

Python 3.13；实验依赖 requests 2.34.2、beautifulsoup4 4.15.0、lxml 6.1.3（仅外部 venv）。MediaFlow 无新增依赖，未引入 Python 运行时/包体。只有 Windows 外部实验实际运行；这些 Python 依赖未做 Android/iOS 部署评估，不作为五端产品依赖。

## 有效样本结果

| aweme_id | 样本证据/人工数量 | 匿名结果 | 提取图片 | 顺序/正确数量 | 耗时 |
|---|---|---|---:|---|---:|
| 7690029886242009957 | 当前用户人工确认多图；前轮 session 实测13图 | 无目标结构 | 0 | 未验证 | 520ms |
| 7669579412325683877 | 当前参考 fixture 标为 images-only；当前人工数量未知 | 无目标结构 | 0 | 未验证 | 512ms |
| 7675010865947858341 | 当前参考 fixture 标为 images-only；当前人工数量未知 | 无目标结构 | 0 | 未验证 | 508ms |
| 7626598460468333858 | 历史公开文章10图；当前数量未知 | 无目标结构 | 0 | 未验证 | 460ms |
| 7159749791113645325 | 历史公开图片作品引用；当前数量未知 | 无目标结构 | 0 | 未验证 | 450ms |

成功0，失败5，识别出的 notApplicable 0，候选观测成功率0/5；**当前人工确认静态多图样本仅1，另外4项不能当作已确认的当前多图总体样本。** 当前已确认子集为0/1。不同作者与不同图片数量的完整5–10个人工样本集未取得，未伪造该项验收。已向用户提出可选补充，未收到新样本。

平均490ms，最大520ms。样本太少，不作可靠P95估计。有效实验5次GET，每样本1次、无跳转/重试，均HTTP200、2492bytes；原提取器没有匹配目标 detail。失败原因仅能分类为 **noTargetStructuredDetail**；未保留页面body，不能把小正文或200解释成必需登录、签名缺失、明确WAF/安全挑战或作品删除。没有拿到URL，图片可达性检查0次；数量、顺序、静态类型和正确target不能宣称通过。

LivePhoto本轮排除：没有请求其动轨、没有声称支持。参考 fixture 中含 live_media 的 `7616399587141737704` 和实况 slides 样本未纳入静态验证。

### 实验完整性与无效首轮

首次运行器将类命名为 ReferenceSSR，遗漏原方法递归引用的 `DouyinParser` 全局绑定；原 `_parse_ssr_data` 会捕获该异常。离线正样本检查发现问题，**首轮统计无效，不作为失败证据**。修复绑定后正样本目标匹配/双图顺序、错ID拒绝、空images通过，然后只完成相同样本/相同请求的验证；没有更改请求参数、增加路线或为拒绝重试换身份。

总平台GET实际10次：无效首轮5、有效修正5。首轮每项200、约32KB，第二轮约2.5KB的差异不能归因。无body保留，不能补做body诊断，后续不追加请求。首轮脱敏元数据单独保存在 `poc/anonymous-static-reference-invalid-run.json`，有效结果在 `poc/anonymous-static-reference-results.json`。

## 接入决定与38项答复

| 项 | 答复 |
|---|---|
| 1–5 参考项目/分支/commit/license/实际链/凭据 | 见上节；默认链会带匿名状态，严格零凭据SSR有效实验无成功 |
| 6–10 样本数/逐项结果/成功失败率 | 候选5；0成功/5失败，0%；当前人工确认1，0/1；不能冒充合格五样本集 |
| 11–13 图片数量/顺序/URL有效 | 全部未验证，无URL可测 |
| 14–16 平均/最大或P95/原因 | 490ms/520ms；P95不报告；无目标结构，具体页面阻断原因未核实 |
| 17 LivePhoto | 排除，不支持本轮匿名验收 |
| 18 production门槛 | 未达；按硬止损不做production spike |
| 19 Resolver Chain | 未新增；保持现有平台 dispatcher → session backend → adapter → MediaContent |
| 20 Resolver Result | 未新增生产类型；研究JSON的success/notApplicable/blocked只是实验分类，不是已实现的统一产品结果类型 |
| 21 timeout/fallback | 研究读取预算6秒/5秒请求timeout/3跳/1MiB；同步connect/read的单次阻塞存在预算边界，不宣称production SLA；没有接入新的fallback或timeout |
| 22–23 Windows/Android无session匿名主入口 | 均NOT TESTED：参考未通过，不清除现有session、不进入production主入口实验 |
| 24 session fallback | 原session实现保留；本轮自动化回归通过；本轮未真实重登/复验；匿名→session新链未实现 |
| 25–26 video/Bilibili回归 | 本轮既有离线测试通过；未重发真实video/Bilibili网络请求 |
| 27 analyze | 本轮 `flutter analyze --no-pub lib test`：No issues found |
| 28 test | 本轮 `flutter test --reporter expanded`：242 passed / 6 skipped；6项真实网络 opt-in仍跳过 |
| 29–30 Windows/Android Debug/Release | 本轮未重建；前轮4种构建通过记录保留于 gallery-main-entry-result.md，不能写成此次新构建 |
| 31 production修改 | 0；新增研究运行器、两份脱敏JSON与本报告，更新research README索引；无删除 |
| 32 Git status | 见下；既有未提交修改保留 |
| 33 Git写操作 | 无commit/push/merge/tag/PR/reset/分支改动；公开源码ZIP不使用clone |
| 34 匿名RC PASS | 否 |
| 35 原RC READY | 保持既有范围，未发布 |
| 36 当前唯一blocker | 未证明零凭据原分享页SSR能稳定取得正确静态Gallery，生产门槛未达 |
| 37 下一轮唯一目标 | 如用户另行授权，继续当前session RC的发布准备/验收收尾；本轮不发布、不重启匿名或H2研究 |
| 38 项目目标兼容性 | 见下 |

没有新增resolver本地命中统计和用户指定的16项匿名production测试，因为这两项以production准入为前提。原Session/Video/Bilibili/History/下载任务去重、登录continuation回归由完整现有测试覆盖，不能代称新匿名路由测试。

## 复现与检查

运行器 `poc/anonymous_static_reference.py` 依赖固定外部源码，源码SHA256 `d5607ccdd628f35344da4f3d2f9d5341faa3233b85ad6930be8c5111cc7abbc5`。实际执行时复制运行器到上述外部目录并在外部运行：

```powershell
& D:\dev\tmp\mediaflow-anonymous-reference-ee05d757c7fe\venv\Scripts\python.exe D:\dev\tmp\mediaflow-anonymous-reference-ee05d757c7fe\anonymous_static_reference.py D:\dev\tmp\mediaflow-anonymous-reference-ee05d757c7fe\media-parser-ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6 D:\dev\tmp\mediaflow-anonymous-reference-ee05d757c7fe\result.json
```

这是记录命令，不是建议继续发请求。原SSR离线正/负控制通过；Python syntax compile通过；外部 `pip check`：No broken requirements found。Flutter初次受限运行无输出，已中止；提升SDK缓存访问后完整测试通过。pub resolution未升级依赖，pubspec/lock内容没有本轮变化；生成Windows文件仅换行变化，恢复原CRLF，未checkout/reset代码。

## 【项目目标兼容性检查】

| 平台 | 状态与证据边界 |
|---|---|
| Windows | 本轮匿名外部HTTP实测失败；现有Session普通入口已实际测试（前轮），Debug/Release构建历史通过，本轮不构建 |
| Android | 原Session普通入口已实际测试（前轮），Debug/Release构建历史通过；本轮匿名未实测、不安装APK |
| iOS | 新匿名实现未接入；原Gallery session暂不支持，未来需自有session Adapter，不宣称此次理论HTTP路径即完整支持 |
| macOS | 同上，原Gallery session暂不支持；未构建/实测 |
| Linux | 同上，原Gallery session暂不支持；未构建/实测 |

- Bilibili与Douyin video：现有自动化回归通过；本轮不替换其解析器。Douyin Gallery：已有session RC保留，严格匿名未通过。
- Xiaohongshu、YouTube、X、Instagram及未来平台：没有添加支持；本轮未跨平台复用该SSR方法，后续仍需各自独立Parser/Adapter。
- PlatformDetector、ParserService、Parser/Adapter、Unified Content Model、MediaContent/MediaResource：本轮没有生产修改，参考没有通过，未建立第二套公共Gallery模型。
- Downloader（Range/恢复/.part/任务）、History、Settings、UI、本地存储：已有自动化范围回归通过；本轮不创建真实下载任务、不改历史、不清会话。Media Processing及Browser Adapter没有接入新能力，H2/Browser Observation保持冻结。
- Logging/隐私：运行器抑制原logger，结果只存ID、计数、latency、请求状态/页面路径与类别；不保存原HTML、完整图片URL、分享文本或凭据。未读取外部浏览器/profile或密码，未注册ttwid/发送Cookie/登录/研究UIFID或signer。
- 零服务器/依赖：仅下载公开源码和pip依赖、向所属平台请求公开页面；没有向第三方解析/云处理上传链接或媒体。外部venv为验证工具，不纳入App发布。MIT源码在外部运行保留许可证，没有生产代码复用。
- 包体/性能/维护：没有新增产品依赖/包体；研究约0.49秒不能外推Android或production延迟。零命中意味着额外等待没有证实的收益，故不接入、不增加需要维护的生产分支。
- 正式发布：未发布，未安装/覆盖/卸载Android应用，未清除数据。applicationId/签名检查本轮不适用（没有安装步骤）；前轮共存测试证据不冒充此次真机操作。

## 修改文件与Git

本轮修改：`v0.4.0/research/README.md`（研究索引）。

本轮新增：`v0.4.0/research/anonymous-static-gallery-result.md`、`v0.4.0/research/poc/anonymous_static_reference.py`、`v0.4.0/research/poc/anonymous-static-reference-results.json`、`v0.4.0/research/poc/anonymous-static-reference-invalid-run.json`。删除0，production修改0。现有研究目录整体untracked，以下stat不含这些新增文件。

仓库 `D:\projects\mediaflow-v040`，分支 `feature/v0.4.0`，HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。

`git diff --stat`：10 files changed, 209 insertions(+), 16 deletions(-)，与本轮开始的tracked内容一致。

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

后续不要重复本轮样本/SSR网络测试，不通过新headers/query、Cookie、signer、Web detail、WAF研究或Browser Observation补救零命中。本轮到此暂停。
