# 第五阶段：Bilibili 公开图文数据入口调查

第五阶段时点：2026-09-24。状态当时为：**独立 PoC 在 Windows 和 Android 真机读取一个双图作品；Windows 另读取一个八图作品；当时尚未接入 production Parser。** 第六阶段后续接入结果见文末。

## 候选与方法

公开来源：[双图动态](https://www.bilibili.com/opus/1119192688409706496)、[八图文章](https://www.bilibili.com/opus/253659746303356301)。PoC：`tool/v030_gallery_source_probe.dart`；Android 网络合同：`integration_test/v030_gallery_source_probe_test.dart`。两者都使用仓库现有 `HttpNetworkClient`，没有账号、Cookie、Token、签名、浏览器 session 或第三方解析服务器；不保存完整响应。Windows 使用现有 `BilibiliParser` 的普通 `Accept`、`Referer`、浏览器风格 `User-Agent`；Android 真机还验证了与设备系统相符的 Android 风格普通 UA。没有新增随机参数、设备指纹或验证码处理。

| 入口 / Header | Windows Dart HTTP 实测 | 判断 |
| --- | --- | --- |
| `www.bilibili.com/opus/<id>`，默认 Header | `200 text/html`，1,374 字节，标题为验证码页 | 识别为安全挑战，停止解析。 |
| 同一网页，只有 `Accept` + `Referer` | 同样返回 1,374 字节验证码页 | 这两个 Header 不足以解释差异。 |
| 同一网页，`User-Agent: MediaFlow/0.3.0` + `Accept` + `Referer` | 同样返回 1,374 字节验证码页 | 如实标明应用身份的普通 UA 仍未取得内容。 |
| 同一网页，现有 Parser 普通 Header | `200 text/html`，双图页约 37 KB、八图页约 91 KB；`window.__INITIAL_STATE__` 可解析 | **候选数据入口：HTTP + 页面内嵌 JSON。** 成功与固定 User-Agent 相关，但不证明跨时间/网络稳定。 |
| `api.bilibili.com/x/polymer/web-dynamic/v1/detail?id=<id>` | `200 application/json`，`code=-352` | 风控拒绝；不加入签名、Cookie 或挑战参数。 |
| `api.bilibili.com/x/polymer/web-dynamic/v1/opus/detail?id=<id>` | 同为 `code=-352` | 不作为当前 production 候选。公开文档还标出 `buvid3` Cookie 前提。 |

所有请求都保持原 URL，没有跳转到其他数据入口。对照表明**默认、仅 Referer 和 MediaFlow 身份 UA 返回验证码；普通浏览器风格 UA 返回作品页**；服务端内部风控原因无法从响应证明。Windows 使用现有 `Windows NT` UA，Android 使用 Android 16 UA，均得到作品数据，故不依赖 Windows 专属 Header 或 TLS 行为。普通 UA 的长期可接受性和维护成本仍需评估。若所选 Header 以后也收到验证码，必须安全停止，不轮换身份、求解挑战或继续试探。

## 实际恢复的作品字段

| ID | 公开标题与作者 | 正文 | 按段落顺序恢复的图片 |
| --- | --- | --- | --- |
| `1119192688409706496` | “下班了 没时间拍抖音 但抽空拍了两张照片…”；笛堤 | 公开文本节点可读 | 2 个不同的 HTTPS JPEG URL；顺序与第四阶段真实下载夹具相同。 |
| `253659746303356301` | “摄影后期 \| 风格化后期思路分享（上）”；铺长廿七 | 公开文本节点可读 | 8 个图片出现位置；第 2、3 项 URL 相同。PoC 保留原出现顺序，以序号作为稳定且唯一的资源 ID；第二个样本的图片 MIME 仅由 `.jpg` 后缀推断。 |

`detail.id_str`、`MODULE_TYPE_AUTHOR`、`MODULE_TYPE_CONTENT.module_content.paragraphs`、图片 `pic.pics[].url` 来自页面内嵌 JSON。PoC 输出 `platform/contentId/title/author/contentType/bodyPreview/resourceCount` 及每项 `id/type/url/mimeHint/order`；资源不是固定写死在 production。双图 CDN 在第四阶段已匿名真实下载并验证 `image/jpeg` 与字节数，故页面得到的 URL 能交给现有 Downloader。页面数据不是永久有效性保证。

Android PJZ110 / Android 16：相同 `HttpNetworkClient` 在两种普通 UA 下都读取双图作品。现有 Parser 的 Windows 风格 UA 返回顶层 `detail`；Android 风格 UA 返回 `200 text/html`、约 26.6 KB，作品位于 `window.__INITIAL_STATE__.opus.detail`。两次都核对 `id_str` 与 2 个顺序正确的 HTTPS URL；未在 Android 重测八图作品。这证明同一公开入口不要求 Windows 风格 UA 或浏览器 session，但不同 UA 的页面数据路径不同，必须分别识别。中途一次流式 APK 安装曾返回 `Failure [-99]`，后续隔离包的非流式安装和真机网络测试成功；该失败不是网络响应。

## 公开项目交叉检查

以下仅参考数据入口/字段结构，**未复制第三方代码、算法、正则或完整逻辑**。维护日期为 2026-09-24 读取 GitHub 仓库元数据时的最近推送日期；最近推送不等于该入口当日有效。

| 项目 / 来源 | LICENSE；最近推送 | 参考与适配判断 |
| --- | --- | --- |
| [Rimagination/bili-note](https://github.com/Rimagination/bili-note/blob/main/references/bilibili-api-notes.md) | MIT；2026-09-22 | 文档建议图文优先读取公开页 `window.__INITIAL_STATE__`，指出 polymer API 可返回 `-352`。其其他字幕功能可能使用已登录浏览器；MediaFlow 只参考公开图文入口，不使用登录态。 |
| [DIYgod/RSSHub](https://github.com/DIYgod/RSSHub/blob/master/lib/routes/bilibili/cache.ts) | AGPL-3.0；2026-09-24 | 独立实现也读取页面内嵌数据及有序 `pic.pics`。服务端 RSS 形态与 MediaFlow 零服务器原则不合；AGPL 代码未搬运。 |
| [45min-on-the-git/BilibiliDown](https://github.com/45min-on-the-git/BilibiliDown) | Apache-2.0；2026-04-24 | 图文路径也使用页面数据。它把图片表示为视频片段的模型不适合 MediaFlow 通用内容模型；未复用。 |
| [Janson20/bilibili-api-collect-mirror](https://github.com/Janson20/bilibili-api-collect-mirror/blob/master/docs/opus/detail.md) | GitHub 标记 NOASSERTION；2026-01-22 | 文档列出 `/opus/detail` 和 `buvid3` Cookie 前提。用于排除该路线；许可证不明确，不复制。 |
| [camellia2077/gallery-dl-assistance](https://github.com/camellia2077/gallery-dl-assistance) | MIT；2026-07-24 | 图文下载工具，但使用浏览器导出的 Cookie 文件，违反本任务边界；不采用。 |
| [DD1969 的 Bilibili 移动网页用户脚本](https://greasyfork.org/zh-CN/scripts/497732-bilibili-%E4%BC%98%E5%8C%96%E6%9C%AA%E7%99%BB%E5%BD%95%E6%83%85%E5%86%B5%E4%B8%8B%E7%9A%84%E7%A7%BB%E5%8A%A8%E7%BD%91%E9%A1%B5%E7%AB%AF) | GPL-3.0；本轮未核对最近更新时间 | 仅作为移动页 `opus.detail` 字段路径线索；随后由 MediaFlow 真机响应独立确认。未复制脚本代码或正则，GPL 代码不引入。 |

## 技术路线与进入条件

选择 **B：HTTP + 页面内嵌数据**，作为首个图文 Parser 的下一阶段候选；当前没有证据要求 Browser Adapter，也没有证据支持纯 JSON API。Windows 与 Android 都用现有 Dart 网络层、各自普通浏览器风格 UA 匿名恢复同一 2 图作品；Windows 第二样本为 8 图；双图 URL 已经在第四阶段经 Downloader 两端真实保存。因此**具备进入 production 图文 Parser 接入开发阶段的技术条件**，不等于发布验收或长期稳定性保证。中性 MediaFlow UA 仍收到验证码；下一阶段必须明确处理页面结构差异和安全挑战失败。

接入阶段须限定 Bilibili 独立模块，保留现有视频 `ParserSuccess.videoInfo`、`ParserService`、Downloader 和 History 行为；解析验证码/`-352` 应返回明确失败。需增加多种页面结构、重复图片、空图、响应变更、过期资源和两端回归测试。固定 User-Agent 与页面 hydration 结构可能改变，是当前主要稳定性风险；不得通过随机 Token、设备指纹、登录态或安全挑战绕过补救。抖音/小红书本阶段未重新发起网络验证，因为 Bilibili 已满足本阶段候选门槛；此前的规划比较不等于这两平台的实测。

## Android 安装安全记录

安装前 `adb` 检查：PJZ110 上既无 `com.mediaflow.mediaflow`，也无 `com.mediaflow.mediaflow.v030probe`。本轮只在显式环境变量 `MEDIAFLOW_V030_PROBE_APP_ID_SUFFIX=.v030probe` 下构建 Debug APK；构建后先用 `aapt` 确认 applicationId 为 `com.mediaflow.mediaflow.v030probe`，用 `apksigner` 记录 SHA-256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`，再运行真机测试。没有预存同 ID 包，因此不存在签名冲突；正式 Release applicationId 配置未改。首次测试结束后设备包列表中两种 MediaFlow ID 都不存在，独立测试包由测试工具清理。一次流式安装返回 `Failure [-99]`；重新核对设备无同名包后，仅对隔离包使用非流式安装，成功运行 Android 风格 UA 测试。最终包列表仍无两种 ID。没有卸载、覆盖或清除此前存在的 MediaFlow 安装或数据；没有手动执行 `adb uninstall`。隔离包的在位同签名更新仅影响本轮测试数据。
# 第六阶段采用情况（2026-09-24）

第五阶段的数据入口已由 MediaFlow 独立实现进 `lib/features/parser/data/bilibili/bilibili_opus_parser.dart`，没有复制上述任何第三方代码、正则、算法或片段；公开资料仅提供数据路线线索，最终字段和边界由 MediaFlow 自己的真实响应及测试确认。桌面 `detail` 与移动 `opus.detail` 已通过离线测试，Windows 真实双图/八图 production Parser 通过；Android 真机隔离 Debug 包真实双图完整保存链通过。纯 JSON API 的 `-352` 路线仍被排除，未加入生产解析。

Release 候选阶段未改变 Bilibili 数据入口。2026-09-24 Android 正式包已在 PJZ110 上完成真实双图 GUI 下载、MediaStore/系统图库打开及重启后聚合 History 验证；Windows Release GUI 真实下载仍未验收。详见 [Android 验收](../acceptance/android.md)。
