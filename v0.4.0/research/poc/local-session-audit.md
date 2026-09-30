# Douyin Local Session / Context Provider 最小 PoC（2026-09-28）

**本轮按 S4 收口，范围限定为：tested environment 的正常用户会话入口在登录完成前被安全挑战阻断。**不是“已经登录但没有 UIFID”，也不是证明所有正常用户会话无法提供上下文。S1/S2/S3 均未成立；匿名 bootstrap 历史 A4 保留，不再研究首次发行、不回匿名导航循环。production feasibility=BLOCKED，完成后暂停。

## 架构与实际实现

独立 research PoC：[设计/字段矩阵/两端方案](local-session/README.md)、[平台无关研究契约](local-session/ContextContract.cs)、[Windows研究Adapter](local-session/LocalSessionPoc.cs)。所有新源码留在 research，未导入生产。`IDouyinContextProvider` 暴露无凭据 status、Acquire、Invalidate；`ContextHandle` 只有 owner/epoch。读取status是副本，不能通过改它伪造有效性。过期、跨profile、clear后引用和第二次detail均被拒绝。

正式设计补全显式 userEstablish/refresh/clear 与受控 HTTP executor：UI/Application请求用户建立会话；Native Adapter只使用App自己profile；Parser接收opaque handle，通过executor取得HTTP内容。UIFID实际值仅在Adapter/profile内部短暂使用，不进入ParserService、通用模型、History、日志或普通配置。Cookie存在标记availableUnvalidated；只有目标成功响应才标记scopedValidated/lastValidated，单纯越过UIFID层不证明账号或完整上下文有效。明确验证/付费/地区/权限拒绝直接撤销，不自动登录或变更身份重试。

首轮请求字段只允许UIFID header。ttwid/msToken/UIFID_TEMP/登录Cookie只检测布尔存在性，不下发到detail；证据要求它们之前不得扩展。现有production `DouyinDetailSession`本来就有匿名homepage bootstrap和ttwid/msToken/nonce白名单；production parser存在mobile feed→detail以及注入式BrowserObservation候选。本轮没有改变这些路径，不把PoC接入或重新启用Observation。已有单视频完整性检查也尚不能直接承接图文生产集成。

用户体验候选：匿名解析无法完成→用户主动打开App会话页→平台正常交互→必要context可用→关闭窗口→原目标最多重试一次。PoC只有一个研究窗口和停止清除按钮，不是完整登录系统；不自动点击登录/扫描QR/输入密码或处理挑战。外部浏览器、系统Cookie库、其他App/profile不访问。关闭本地会话不等于撤销远端其他设备的账号登录。

## 执行与安全证据

profile位于**仓库外** `D:\dev\tmp\mediaflow-v040-local-session\session-<GUID>`，新建目录设置仅当前用户与SYSTEM继承权限；不保存到repo/研究报告。默认runtime UA未改，未伪造fingerprint。只调用App profile的 `GetCookiesAsync(detail-uri)`，不调用空URI全Cookie jar。登录profile由WebView持久化，不复制Cookie到配置文件，不写UIFID值/哈希或账号数据。

首次本地启动在不必要的 `SetOwner` 权限操作失败，profile为空、导航/请求均0，未建立WebView。精确核对父目录/GUID/空目录后删除，保留[失败日志](local-session/initialization-failure.jsonl)。修正为不变更owner，离线新目录ACL验证通过，之后才执行唯一真实入口；这不是WAF重试。

真实operation日志：[session-metadata.jsonl](local-session/session-metadata.jsonl)。

| UTC | 证据 |
|---|---|
| 06:17:18.002 | appOwned=true，新profile建立，无导入状态/仓库凭据文件 |
| 06:17:18.774 | homepage scope Cookie数0、UIFID=false、loginState=false |
| 06:17:18.784 | 可见研究窗口，唯一正常首页导航 |
| 06:17:19.789 / 20.778 | detail URI范围内UIFID/UIFID_TEMP/ttwid/msToken/loginCookie皆false，Available未达到 |
| 06:17:20.939 | 检测 `lf-waf-js.byted-static.com/obj/waf-jschallenge/out-sha256.js`，同步阻止，撤销context并取消操作 |
| 06:17:21.887 | nativeProfileClear=true、UIFID absent=true、BrowserProcessExited=true、profileRemoved=true、state=Cleared |

真实导航1、拦截器放行资源request事件2、停止前response事件1；安全资源阻止1，WebView自动detail阻止0，显式HTTP detail0；登录完成未观测、正常登录未验证；没有签名、ttwid注册、note导航或第二次真实入口。请求事件计数不是服务端确认或OS所有网络流量。WebView正常页面自身资源可能显示图片，工具不抓取其body、不导出/下载媒体；实际未开展图片下载实验。

安全停止后只执行本地清除/退出，不再采样账号状态或重启导航。清除先撤销引用/取消in-flight，再清本profile全部浏览数据，URI范围验证UIFID不存在，dispose WebView，等待浏览器进程退出，核对exact-owned path和marker，删除目录。外部只读复核目录不存在。本轮清理已实测；异常关机、删除失败、完整生产长期生命周期未测试。失败时不得以删除父目录/杀其他浏览器进程继续。

正路径（取得UIFID→同profile无导航重启→最多一次detail）已写入PoC，但**没有真实执行**。detail条件与旧baseline对齐，只添加 `uifid` header，禁用proxy/redirect/Cookie容器；body仅在显式HTTP实验内存中检查，非WebView/XHR监听。它记录exact-target/detail/images数量和错误布尔值，绝不正文或URL列表。baseline固定Chrome130 UA与真实runtime UA可能不同，工具记录比较布尔值；跨客户端TLS/UA/profile绑定仍是实验限制。出现任意不同错误不能直接宣布UIFID gate通过；需明确signature错误或目标数据证据。否则仍停，不追加context。

## 本轮24项答复

| 问题 | 结论 |
|---|---|
| 1 Provider架构 | 平台无关opaque handle+状态，Native Adapter内最小context与HTTP executor；研究契约已写，正式生命周期接口为设计 |
| 2 需要用户登录？ | 未证明；窗口供正常交互，但challenge在正常登录完成前阻断 |
| 3 App自有profile建立？ | 是；新建、仓库外、权限隔离、无外部导入 |
| 4 UIFID取得？ | 否；两次scoped采样无值，不能替代完整登录后结论 |
| 5 生命周期 | UIFID TTL/重启保留未测；本轮profile建立/清理已实测 |
| 6 复制Cookie？ | 无文件导出或配置复制；Native API短暂内存snapshot限定URI；未读取完整jar，实际没有UIFID值供detail使用 |
| 7 安全清除？ | 本轮正常停止路径实测native clear+Cookie absent+browser exit+exact-folder delete；完整异常恢复未测 |
| 8 detail执行？ | 0；可信UIFID前提未达到 |
| 9 Uifid Not Found消失？ | 未测试，旧baseline结论不变 |
| 10 新阻断 | 正常会话入口的明确WAF challenge；HTTP下一层未知 |
| 11 signer成为下一阻断？ | 没有证据，仍冻结；不进入clean-room signer |
| 12 aweme_detail？ | 未取得，未请求 |
| 13 images？ | 未取得，未请求/下载 |
| 14 Windows可行性 | profile隔离、scoped读取和清除可行性实测；Douyin正常会话与UIFID正链未证实 |
| 15 Android可行性 | 有API/既有worker生命周期依据的条件路线；本轮登录/context未实测，是production门槛 |
| 16 职责边界 | Provider仅正常context建立维护；不消费DOM/hydration/页面JSON/XHR/响应body，不恢复Observation Parser |
| 17 production | BLOCKED，双端上下文/目标数据未验证 |
| 18 文件 | 见下一节，production无改动 |
| 19 数量 | 本地失败0请求；真实入口1导航、2放行request事件、1response、1安全阻止、0detail、0重试 |
| 20 检查 | 最终C#编译、10条离线断言、日志/清除不变量、PS语法通过；Flutter生产检查/构建未运行 |
| 21 Git | feature/v0.4.0，HEAD不变；M AGENTS.md / ?? v0.4.0/ |
| 22 production修改？ | 否 |
| 23 Git写操作？ | 无add/commit/push/merge/tag/reset等 |
| 24 项目目标 | 见完整兼容性检查 |

S4不等于附件第十二节“登录后仍无UIFID”的前提成立，故不伪报 `Normal user session does not expose required UIFID` 为登录实测结论。media-parser现有 `_get_uifid` 依赖环境变量/用户Cookie/已有session，不能补齐本轮正常会话前置条件；没有继续匿名生成或signer逆向。本轮后续仅保留路线决策：是否有证据充分的正常登录入口能在App自有runtime内成立。没有这样的证据，不自动开第二环境/移动端网络实验或再次撞同WAF入口。

## Android与五端工程评估

Android优先两种可替换Adapter：支持MULTI_PROFILE时专属named Profile及其CookieManager；否则满足API/启动约束的专属持久worker，`WebView.setDataDirectorySuffix`在任何WebView初始化前设置，HTTPcontext消费在同一worker内，Binder只传opaque ID/内容/安全状态。不回退default CookieManager共享jar，不向主进程复制全会话。

[Android Profile文档](https://developer.android.com/reference/androidx/webkit/Profile)支持profile CookieManager，须先feature check；[ProfileStore](https://developer.android.com/reference/androidx/webkit/ProfileStore)对loaded/live profile的delete可抛异常，返回不保证磁盘异步删除完成。因此必须进程/生命周期协调与实测磁盘清理，而非destroy后立即宣称完整退出。既有research worker的限定生命周期PASS不能证明本轮登录/UIFID能力。[标准CookieManager](https://developer.android.com/reference/android/webkit/CookieManager) URI API返回请求Cookie格式，未提供完整属性元数据；Android TTL/HttpOnly/SameSite未核实就标unknown，不照填Windows值。[数据目录suffix](https://developer.android.com/reference/android/webkit/WebView#setDataDirectorySuffix(java.lang.String))仅提供条件隔离路径。设备feature不足、无法隔离或清除即Adapter unavailable，属于正式架构阻断，不能以Windows PoC替代Android验收。

Windows依据已有SDK/API，仅复用API机制，没有复制第三方parser/signer代码。参照Microsoft [Cookie管理](https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/CookieManagement.md)的URI snapshot和[profile数据清理](https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/ClearBrowsingData.md)。ucmao/media-parser是既有设计/消费来源审计参考，根MIT，signer文件额外许可限制仍冻结；不复制、不新增attribution。研究build复用现有WebView2 SDK及其LICENSE，无新pubspec/Gradle/native生产依赖；系统.NET编译器/WinForms/HTTP客户端仅Windows research，不能移入通用核心。

## 文件与验证

本轮修改：`v0.4.0/README.md`、`v0.4.0/research/README.md`（最新状态入口）。新增：本报告，`local-session/ContextContract.cs`、`LocalSessionPoc.cs`、`build.ps1`、`README.md`、`initialization-failure.jsonl`、`session-metadata.jsonl`、`offline-tests.json`、`verification.json`。未删除代码/文档；只删除本轮两个精确归属临时目录，其中失败目录为空。

最终C# research exe编译通过；[离线10条断言](local-session/offline-tests.json)覆盖不可用/过期/跨owner/单次消费/clear后撤销/迟到验证/安全路径/精确路径/status副本；日志JSON解析、真实停止/清除不变量、目录不存在、PowerShell AST语法通过。真实网络运行后，防御性补强status副本、signature门槛与完整验证分离、初始化/重启clear期间等待浏览器退出，最终离线重编译通过，没有重复真实导航。这些补强的正路径/并发重启/真实账号仍未实测。

未运行：Flutter/Dart analyze、生产lint/单测/回归、Windows Flutter build、Android build/安装、iOS/macOS/Linux build。未把research编译写成App构建，未把模型测试写成真实会话通过。尚未验证UIFID正样本/属性/TTL/重启/失效刷新/UA绑定/HTTPgate变化、目标图文、双端登录、crash恢复/长期profile存储。

局限：正常网页popup/权限请求被拒绝、mainframe仅受控平台域名、WebView自身runtime差异和安全入口决定正常交互能否成立；Cookie-only探针不寻找localStorage/SDK生成器。五分钟窗口仅超时取消。C#字符串/native请求缓冲区只限进程生命周期，不保证内存秘密可密码学擦除；应在正式Adapter完善cancel/lease/原子clear及崩溃恢复，不把当前helper直接发布。

## 【项目目标兼容性检查】

| 平台 | 状态 |
|---|---|
| Windows | research build通过且已实际测试profile创建/读取/安全停止/清理；正常用户登录/UIFID和生产build未验证；有WebView入口风险 |
| Android | 条件设计/API依据，现有研究生命周期经验；本轮未build/实测/安装，不支持宣称context已可用；双端验收BLOCKED |
| iOS | 理论WKWebView+专属data store Adapter路径，Cookie属性/清除/HTTPbinding需实现实测；当前Windowshelper暂不支持 |
| macOS | 理论同类WKWebView Adapter；未实现/构建/实测，存储与退出生命周期有平台特有风险 |
| Linux | 理论独立Browser Adapter替换路径；runtime/profile隔离尚未确定，未实现/构建/实测 |

Android安装安全：本轮无安装/替换/卸载/清除设备数据；applicationId/签名兼容本轮不适用，没有借旧研究包验收当前context。

| 模块/目标 | 检查与具体限制 |
|---|---|
| Bilibili / Douyin | 未修改production且没有本轮回归；Douyin图文仍BLOCKED，视频能力未重测，不宣称恢复 |
| Xiaohongshu / YouTube / X / Instagram / 其他未来平台 | 未实现/测试；context隔离于对应Adapter，不扩成公用UIFID依赖 |
| PlatformDetector / ParserService / UI | 未修改/回归；未来应用协调用户建立与一次重试，UI不直接读Native凭据 |
| Parser / Adapter / Browser Adapter | 最小context契约在research；正式实现未接入；Observation仍停止，无decoder/页面body能力扩张 |
| Unified Content Model / MediaContent / MediaResource | 未修改；opaque引用不含Cookie、只公开媒体内容，未来多资源边界保留，生产图文仍待需求驱动迁移 |
| Downloader / Media Processing | 未改/回归；没有媒体下载处理；未来Adapter附加凭据不让Downloader理解登录协议 |
| History / Settings / Logging / 本地存储 | production未改/回归；只存研究元数据，profile仓库外并清除；正式长期生命周期/refresh仍待验证 |
| 隐私 / 零服务器 | 无外部浏览器或系统Cookie库访问，无第三方解析/同步/凭据上传，无密码自动操作或挑战求解；正常页面访问其所属平台资源 |
| 第三方依赖 / 包体 / 性能 | 生产依赖和打包配置未改，research复用SDK，生产包体/运行性能未测；1秒轮询只适用于有界PoC |
| 后续维护 / 正式发布 | Cookie-only假设、WebView兼容、normal-login入口和UA绑定仍有风险；无双端UIFID/目标images成功证据，不能正式发布为图文恢复 |

## Git收尾

cwd/top-level `D:\projects\mediaflow-v040`；branch `feature/v0.4.0`；HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`；根AGENTS.md修改在开始前已存在，本轮未改。

`git diff --stat`（tracked，不包含既有untracked v0.4.0目录）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：

```text
 M AGENTS.md
?? v0.4.0/
```

`git diff --check`通过（tracked范围）；没有Git写操作。**暂停，不开新会话入口、不开始signer或production集成。**
