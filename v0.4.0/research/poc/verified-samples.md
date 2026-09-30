# 第二阶段续研：公开多图样本确认（2026-09-25）

## 当前准入定义：样本真实性与匿名解析能力分离

**以下定义取代本页旧 Level 1 规则；后续各节为按当时规则形成的历史记录，不作为当前机器证据前置要求。** 匿名页面未提取到图片数组不能用来否定人工确认的当前多图作品真实性。

| 等级 | 证据与用途 |
| --- | --- |
| Level 0 — Candidate | 仅 URL、ID、历史引用或尚不完整的当前观察；不能确认当前多图输入 |
| Level 1H — Human-verified current multi-image sample | 当前人工直接确认：分享来自公开作品、明确图文、可实际查看至少两张不同图片；目标 ID 已确认，非历史文章或第三方解析证据。允许下一轮匿名路线 PoC；**不证明匿名解析成功** |
| Level 1M — Machine-verified current multi-image sample | MediaFlow 无账号凭证的匿名研究工具从当前公开响应确认图文及至少两个图片资源；证据更强，**不是开始 PoC 的前置条件** |
| Level 2 — Structured PoC sample | 已取得目标结构化图文对象、有序图片数组及至少两个不同图片资源；属于第二阶段解析结果，不属于样本真实性准入条件 |

### 当前候选 `7690029886242009957` 的分层证据

分享 URL：`https://v.douyin.com/cdnbAA253Us/`；目标 ID 已由先前匿名重定向确认。

| Evidence type / 证据类别 | 当前状态 |
| --- | --- |
| Human verified / 人工直接观察 | **PASS（2026-09-27 用户直接确认）**：当前客户端可正常看到公开图文作品，实际查看到至少两张不同图片，且实际为多张不同照片。分享来自用户当前客户端；不是历史文章或第三方解析证据 |
| Machine verified / 匿名机器确认 | **NOT VERIFIED**：本轮有效样本上的匿名 feed 与页面检查没有目标图片证据；Machine image count: NOT VERIFIED |
| Structured data verified / 目标结构化数据 | **NOT VERIFIED**：本轮 Anonymous HTML structured data: NOT FOUND；feed 无精确目标对象，Web detail 403；image_post_info/images 与 Anonymous image URL extraction: NOT VERIFIED |
| Image download verified / 图片真实下载 | **NOT TESTED**：无目标图片 URL，未触发图片 GET |
| 当前准入 | **Level 1H — Human-verified current multi-image sample**；人工样本真实性已确认，允许下一轮匿名路线 PoC；不证明 MediaFlow 匿名解析成功 |

**当前样本计数：Level 1H = 1；Level 1M = 0；Level 2 = 0。** 已取得一个当前人工确认的公开多图样本（Level 1H），第二阶段测试输入阻断解除。匿名路线 PoC 已在该有效样本上恢复：Windows feed、原始 note/share HTML 与最小 Web detail 均未取得目标结构，Machine image verification 与 Structured data verification 仍为 NOT VERIFIED；Image download verified 为 NOT TESTED。详见 [本轮实测](stage2-douyin-gallery.md)。本轮匿名机器失败不否定人工样本真实性。

前一轮只修正文档；本轮恢复独立匿名研究探针，没有修改正式代码。人工观察可使用用户自己正常使用的客户端；MediaFlow 不读取该客户端登录态、Cookie、Token 或用户请求。Level 1H 不降低 production 的匿名独立获取、真实下载和双端验证门槛。历史样本 `7626598460468333858` 仍为 Level 0 / 历史多图候选。

## 历史记录：2026-09-27 用户多图明确确认之前

**新增候选 `7690029886242009957` 仍为 Level 0；Level 1 合格样本总数仍为 0。** 用户当前从 Douyin 客户端复制分享文案“西之郎的图文作品”，提供 `https://v.douyin.com/cdnbAA253Us/`。这属于当前用户观察，区别于历史博客；但用户并未提供至少两张不同图片的证据，本机匿名页面也未独立确认目标媒体，因此不能升级。

| 准入项 | 本轮证据与判定 |
| --- | --- |
| 目标 ID | **确认**：独立匿名短链依次 `302` 至 `www.iesdouyin.com/share/note/7690029886242009957/`，再 `302` 至 `www.douyin.com/note/7690029886242009957` |
| 当前作品公开可读 | **未独立确认**：路由可达不等于作品媒体公开可读；最终 200 页面没有目标作品内容 |
| 当前图文/note | 用户当前客户端观察与分享文案为图文；匿名 HTTP 仅确认 note 路由，**未独立确认目标图文媒体** |
| 至少两张不同图片 | **未确认**：没有目标图片数组或作品图片 URL；`imageCount=0 distinctCandidateUrls=0` 指探针提取量，不是作品真实图片数 |
| 当前证据 | 用户当前观察与本轮匿名请求是当前证据；没有用历史记录代替当前多图证明 |
| 无凭证等条件 | 已执行请求未发送 Cookie/Token/账号凭证，无第三方解析、MITM、代理截获、用户请求重放或浏览器自动化；没有恢复 feed/Web detail |

原始页面证据：桌面 note HTML 为 `72914` 字节，没有目标 ID、JSON-LD 或 OG 图片；移动 UA 的 share/note HTML 为 `33478` 字节，37 个 script，含目标 ID 的两个脚本可解析。目标 ID 只位于 `loaderData.note_(id)/page.lastPath`、`commonContext.lastPath`、`itemId`；`exactTarget=false imageField=absent`。Set-Cookie 在部分跳转/桌面响应中出现，未保存或回传。未执行页面 JS；结果不能证明作品不存在、私密或只有一张图。

```powershell
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' 'v0.4.0\research\poc\verify_public_sample.dart' 7690029886242009957 --share=https://v.douyin.com/cdnbAA253Us/
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'v0.4.0\research\poc\verify_public_sample.dart'
```

样本脚本仅增加经校验的 `--share=` 公共短链输入，不增加解析接口、Cookie 管理、签名或浏览器能力。实际运行完成（exit 0），但**样本未准入**；独立 dart analyze 无问题。第二阶段仍阻塞于测试输入，下一轮路线 PoC 暂不能恢复。

## 2026-09-27：仅样本准入续查

**合格 Level 1 样本：0；Level 2 样本：0。仍未确认当前公开多图样本，第二阶段继续阻塞于测试输入。** 未恢复 feed、Web detail、Browser Observation 或 production Parser 研究。

本轮按当前六项准入标准分级：当前作品公开可读、目标 ID、当前图文类型、至少两张不同图片、非历史证据、无需凭证/第三方解析/截获或重放，必须同时成立。页面 200、路径与路由 ID 仅为 Level 0。以下“未确认”不等于已证明作品私密或已删除。

| ID | 来源 | 当前平台检查 | 当前公开 / 当前图文 / 两张不同图片 | 分级 |
| --- | --- | --- | --- | --- |
| `7626598460468333858` | 下文十图历史文章 | 保留 2026-09-25 的历史/路由检查；本轮不重复请求 | 均未取得当前作品证据 | **Level 0 / 历史多图候选**，不升级 |
| `7616399587141737704` | [ucmao GitHub 文档的 note 示例](https://github.com/ucmao/media-parser/blob/main/docs/parsers/douyin.md)；相同 ID 也列作 video 示例，所以不能按示例路径判型 | 本机匿名 GET `https://www.iesdouyin.com/share/note/7616399587141737704/`，200 text/html，33478 字节，无跳转；37 个 script，两个含 ID 的 JSON 可解析，ID 仅在路由 lastPath/commonContext.lastPath/itemId；无目标媒体对象、图片候选 0 | 未确认 / 未确认 / 未确认 | **Level 0 / 文档 URL 候选** |
| `7159749791113645325` | [花瓣公开引用的壁纸作品](https://huaban.com/pins/5742277669/)；引用属于历史线索 | 本机匿名 GET `https://www.iesdouyin.com/share/note/7159749791113645325/`，200 text/html，33548 字节，无跳转；同样为路由 JSON，图片候选 0 | 未确认 / 未确认 / 未确认 | **Level 0 / 历史公开引用候选** |

针对 GitHub README/fixture 和公开文章的有限检索，另遇到的多数结果只有通用 `/note/...` 格式或第三方“支持图集”声明，没有可准入的当前作品证据；未向第三方解析服务提交链接。上述两个具体新候选各做一次原始分享页面 GET，没有枚举 ID、批量抓取、登录、浏览器自动化或签名开发。收到 Set-Cookie 时只记录布尔值，未保存或发送。

### 样本脚本与执行证据

`verify_public_sample.dart` 本轮仅新增：接受一个有公开来源的候选 ID、正常 UTF-8 解码、候选图片 URL 去重计数。仍只请求页面，不调用导入研究脚本的网络 main、feed 或 Web detail；URL 数量统计仅是线索，不自动授予 Level 1，也不能把不同 URL 的同图尺寸/格式变体算作两张不同图片。

```powershell
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'v0.4.0\research\poc\verify_public_sample.dart'
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' 'v0.4.0\research\poc\verify_public_sample.dart' --mobile-only 7616399587141737704
& 'D:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' 'v0.4.0\research\poc\verify_public_sample.dart' --mobile-only 7159749791113645325
```

`dart analyze`：No issues found，exit 0。两个实际检查均 exit 0，`exactTarget=false imageField=absent imageCount=0 distinctCandidateUrls=0`；exit 0 表示完成检查，**不是样本通过**。格式化完成但提示根目录 flutter_lints include 未解析；没有把它称为 Flutter 项目静态检查通过。未运行 flutter analyze/test、Windows/Android build。本轮仅 Windows 本机页面读取，不是 Android 或正式功能验证。

**下一轮路线 PoC 尚不允许恢复。** 需要新的当前目标内容证据；保留全部 Level 0 线索及旧记录，不以找不到样本推断匿名路线永远不可行。

## 判定

**本轮未确认满足全部条件的当前公开多图样本。测试输入条件尚未成立，不能继续对 production 门槛作有效验证。** 本轮在此停止，没有用未知当前状态的样本重试 feed、Web detail、图片下载或 Browser Observation。

## 重点候选及证据分层

| 项目 | 记录 |
| --- | --- |
| 原始公开分享 URL | `https://v.douyin.com/8SOAeTUxRo8/` |
| 规范化 URL | `https://www.douyin.com/note/7626598460468333858` |
| 作品 ID | `7626598460468333858`；当前匿名短链依次 `302` 至 `www.iesdouyin.com/share/note/<id>/`，再 `302` 至规范化 URL |
| 多图历史依据 | [Chaoyu Fan 的公开文章](https://chaoyu-fan.github.io/blogs/claude-code-ecosystem/)明确写明原始分享链接、规范化 `/note/` URL，并公开列出“原始 10 张图文”及图 1–10；文章更新时间为 2026-04-10。这是**第三方公开复现的历史内容证据**，不是 MediaFlow 当前从 Douyin 取得的作品数据 |
| 本机匿名检查时间 | 2026-09-25 约 17:21（Asia/Shanghai）；[独立检查脚本](verify_public_sample.dart)不使用账号、Cookie、Token、代理或第三方解析服务 |
| 当前平台响应 | 原始短链 `302→302→200`；桌面 `/note/<id>` 为 `72914` 字节 HTML 路由壳，正文没有目标 ID；标准 Android Mobile UA 请求 `www.iesdouyin.com/share/note/<id>/` 为 `200 text/html`，约 33.5 KB，含目标 ID 与 `_ROUTER_DATA` |
| 原始移动 HTML 结构 | 两个脚本含目标 ID；在成功解析的目标相关 JSON 中，ID 只出现在 `root.loaderData.note_(id)/page.lastPath`、`commonContext.lastPath`、`itemId`。未找到可精确匹配的 `aweme_id` 媒体对象、`image_post_info`、`images` 列表、图片数量或媒体直链；脚本检查到 37 个 `<script>` 标签。此检查不执行 JS，也不能排除未识别的编码格式。`Set-Cookie` 偶有返回，但从未保存或回传 |
| 当前是否确认“图文且 ≥2 张” | **未确认**。第三方历史图 1–10 与现时路由可达，不能合并推断“当前目标作品可匿名读取且仍有十张图”；`itemId` 只证明页面路由引用目标 ID |

上一轮的 `7679016640391062705`、`7680412682671111578` 仍只是 `/note/` 路径候选；没有多图数量证据，本轮没有对它们重新发请求。另见到第三方文档中的其他 `/note/` 示例，但“支持此 URL 格式”或问答中提到图文，均没有当前公开作品与至少两张图片的可核验证据，因此未把它们升格为样本。第三方解析 API 没有被调用。

## 本轮实际请求与限制

只检查了重点候选的公开短链、已知 `/share/note/` 路径与规范化 `/note/` 页面，均为直接 HTTPS GET；请求不自动带 Cookie，手动限定 Douyin 域名重定向并限制响应大小。移动 UA 是正常浏览器标识，未伪造设备指纹。没有执行页面 JS、挑战代码或浏览器观察。探针只输出状态、路径、字节数和脱敏字段路径；没有保存 HTML、Cookie 或图片。

短链重定向证明**路由仍可达**，不证明作品当前公开可读。`200` 页面中的路由 `itemId` 也不等于目标媒体结构。当前公开可访问性与当前图片数量是剩余阻断；需要能独立核对现时媒体内容的公开页面或公开元数据，再恢复路线 PoC。不得用这份历史复现替代 MediaFlow 自测。
