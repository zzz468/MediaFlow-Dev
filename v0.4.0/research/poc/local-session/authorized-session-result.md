# 授权正常交互的 Douyin context 实测 — 2026-09-28

> 后续当前态见 [capability / signer 报告](../h2/capability-signer-audit.md)：UIFID 改为条件能力，真实 research signer 已实现，W2 遇到当前策略 UIFID gate。以下 C5、未确认登录、E1 未执行与清除结果仍是该历史实验的事实；本轮未重开正常会话/登录或平台观察。

结果：**C5 — Normal session established but required context still absent**。限定含义：用户确认正常页面交互/challenge 已完成，本轮新建 App 自有 profile 收到匿名 ttwid；detail URI Cookie snapshot 没有 UIFID。**没有完成登录的证据，不能写“登录后仍无 UIFID”**，也不能声称所有正常会话都不暴露 UIFID。

`Authorized normal session established, but required UIFID/context not exposed in tested profile`

上述 normal session 指本轮正常交互后匿名平台状态；用户完成来自 checkbox 自报，程序没有独立验证 challenge 成功或账号认证。E1 没有执行；signer 继续冻结，无服务端 signer failure 证据。

## 基线与授权差异

cwd/top-level `D:\projects\mediaflow-v040`；branch `feature/v0.4.0`；HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`；开始/收尾均 ` M AGENTS.md`、`?? v0.4.0/`。根 AGENTS 改动和研究成果已存在，本轮保留、不修改 AGENTS。

本轮用户明确将旧“检测 challenge 后立即退出”调整为暂停自动流程、保持自有研究窗口、本人正常完成页面要求。这与 AGENTS 第十节此前实验的立即安全停止做法有差异；按项目所有者本轮明确修订执行，不放宽自动求解/设备伪造/外部会话导入/安全拒绝后自动叠加身份材料。E1若遇安全拒绝仍停止，不实现任何挑战自动化。

## 实际执行与证据

[脱敏运行日志](authorized-session-metadata.jsonl)；helper PID 37592，已退出。无截图、DOM/hydration/XHR内容采集、Cookie导出、系统浏览器状态读取、账号自动操作。

|UTC|实测事件|
|---|---|
|13:06:57.675|创建新的仓库外 research GUID profile，current user/SYSTEM ACL，无导入状态|
|13:06:58.488|首页/detail URI snapshot 均为空，UIFID=false、session=false|
|13:06:58.494 / 58.827|正常首页导航及页面导航事件，host=www.douyin.com|
|13:07:02.154|检测 security resource marker，自动流程暂停；页面保持打开，不屏蔽正常 challenge 资源，不自动处理|
|13:07:12.166|用户确认 normalInteraction=true、challengeCompleted=true、loginCompleted=false；basis=user-checkbox-self-report|
|13:07:12.178|限定 URI Cookie metadata：UIFID candidates=0；ttwid=true；sessionid/sessionid_ss=0|
|13:07:12.885|结束 C5；nativeProfileClear=true、scopedCookiesAbsent=true、browserExited=true、profileRemoved=true|

独立复核：日志逐行 JSON 可解析；resolved absolute profile 的父目录/名字属于本轮 owned root；目录不存在；helper 已退出；stderr 0 bytes。未读取或删除其他目录，不借此声称crash/断电/异常清理全部通过。

ttwid metadata：length=127，domain=.douyin.com，path=/，expiry=2027-09-28T13:07:11.268Z，HttpOnly=true、Secure=true、SameSite=None，非 session cookie。只记录属性，未输出 value/hash。UIFID、必要账号 Cookie 不存在，无法测它们 expiry/绑定/有效性。ttwid 证明平台匿名状态出现，不证明账号登录或 UIFID 必然派生。

本轮最小检查仅 UIFID、ttwid、sessionid/sessionid_ss；msToken/s_v_web_id/UIFID_TEMP 等没有扩张采样/发送。没有 E1，故没有账号 Cookie/ttwid/UIFID/signature 被显式 detail transport 消费。

是否跨同 profile 重启保持：**NOT TESTED**。缺 UIFID 直接 C5 清理，不重启页面尝试初始化；finished 中 uifidRetainedAfterRestart=false 是默认标志，不能写成“重启后丢失”。是否清除后消失：native 全数据 clear 后 detail scoped Cookie count=0，GUID目录删除且独立不存在核对通过。

请求数量：显式 H2-E1=0，E2/E3=0；WebView导航事件2，resource request事件414、response事件309、页面detail阻止事件0。它们是正常页面自身资源事件，不是本工具反复重试；不等于 OS 全部网络请求数。媒体导出/显式下载0，正常页面自己的图片显示资源不当成下载实验。第三方signer/解析服务/GitHub源码请求0。

## E1结果与下一步

E1 HTTP/status/error：**NOT EXECUTED**。Uifid Not Found 是否消失：未验证。aweme_detail/gallery/图片URL：未取得，不用旧mock代替。没有 C1/C2/C3 成立证据，没有 signer/endpoint失败或接受的推断。

当前唯一主 blocker：本轮正常匿名交互后的 scoped Cookie 读取未暴露必要 UIFID。下一轮只审计 **context 来源/构成与映射假设**，不开始 signer、不请求新endpoint、不重复匿名 bootstrap 或 Browser内容解析。

对已有参考证据的有限复核（未扩大网络研究）：

|问题|已知事实|尚未证明|
|---|---|---|
|UIFID一定属于账号session吗|本次匿名ttwid有、UIFID无；参考已有上下文读取与SDK消费线索|没有UIFID账号绑定或必须登录的因果证据；本轮未登录，不得下结论|
|参考依赖手工提供吗|既有固定源码审计：uc `_get_uifid` 接受 DOUYIN_UIFID/DY_UIFID、自配Cookie或已有session；DL有用户登录Cookie文件；jiji bridge只是部分注释证据|这些不是公开可验证的首次正常UIFID生成协议；不能认定自动Provider已经解决|
|是否其他正常客户端状态|ttwid 已由平台正常签发；已有SDK/context来源线索仍保留|本轮Cookie-only不说明localStorage/SDK不存在，亦不授权主动扩大抓取；msToken等不能当作UIFID替代物|

依据：[UIFID context 审计](../uifid-context-audit.md)、[固定源码横向审计](../../douyin-gallery-horizontal-audit-2026.md)。这里仅重新对齐既有证据，不执行参考程序/算法，不把“别人读取Cookie”当作本轮正常UIFID获取成功。

## 21项答复

|项|结论|
|---|---|
|1 用户正常完成challenge|用户勾选已完成；程序独立成功验证未进行|
|2 登录完成|用户未勾选完成，scoped账号Cookie为空；无登录完成证据|
|3 App自有session|新隔离profile已建立，正常交互后匿名ttwid存在；不是账号认证通过|
|4 UIFID|false，candidates=0|
|5 ttwid|true，属性见上；未暴露值|
|6 必要session cookie|sessionid/sessionid_ss未发现；未扫描全部账号字段|
|7 真实值泄露|无值日志/报告/fixture/截图/History；只读取本profile scoped内存snapshot|
|8 执行E1|否，必要UIFID前提未达到|
|9 E1状态错误|未请求，无HTTP结果|
|10 Uifid Not Found消失|未验证|
|11 signer下一阻断|没有证据；本轮不实现、不用MOCK发请求|
|12 aweme_detail|未取得|
|13 gallery|未取得/未下载|
|14 context清理|Native clear、scoped空集、浏览器退出、目录删除与独立不存在复核通过；重启/crash正链未测|
|15 Windows/Android|Windows本轮流程实测；Android对应Adapter设计可行性仍有feature/隔离/清理门槛，未build/真机，不降低验收|
|16 文件|新增AuthorizedSessionPoc.cs、build-authorized.ps1、authorized-session-runbook.md、authorized-session-metadata.jsonl、本报告；更新v0.4.0/README.md及research/README.md；删除0；旧helper/旧日志未改|
|17 test/analyze/build|C# research编译PASS，11条离线断言PASS；旧H2 42项合成测试PASS，Dart定向analyze无问题；完整Flutter lint/正式Windows/Android/iOS/macOS/Linux build未运行/验证|
|18 Git|feature/v0.4.0，HEAD不变；M AGENTS.md / ?? v0.4.0/|
|19 production修改|0；无正式Cookie UI/配置/Parser/signer/debug入口|
|20 Git写操作|0，无add/commit/push/merge/tag/reset/PR|
|21 兼容性检查|见下表；仅research Windows流程实测，不算生产context/gallery支持|

实现为何如此：新增独立可替换 Windows helper，保留旧安全停止实验可追溯性；自动检查只由本人的确认按钮触发，秘密不跨研究Adapter，context未满足则不发E1。取消撤销/HTTP取消/精确owned路径保护保留。重启和Native clear是有界正链预案，本轮没有用缺失context扩大请求。

第三方：无新增项目/算法代码复用。复用已有 Microsoft WebView2 SDK及其SDK许可文件，构建输出保留LICENSE.txt；不是照搬第三方Parser/signer。项目依赖、pubspec/Gradle/生产包体配置未改。研究进程.NET/WinForms/WebView2限定Windows，不能移到共享核心。运行时WebView差异、TLS/UA与HTTP绑定、Cookie-only观察、popup/权限被禁止可能影响正常登录，均为维护/验收风险。

## 【项目目标兼容性检查】

|平台|状态|
|---|---|
|Windows|research编译及正常交互→缺UIFID→清除路径已实际测试；未证明正常登录/UIFID/重启保留/E1/生产构建或gallery支持，有WebView/API绑定风险|
|Android|理论可替换named Profile或独立worker方案，尚未context/用户交互/清理真机验收；本轮未构建/安装，最终与Windows同等门槛|
|iOS|理论WKWebsiteDataStore/WKWebView Adapter，当前Windows helper暂不支持，未构建/实测|
|macOS|理论同类WK Adapter，当前helper不支持；生命周期/HTTP绑定需实测|
|Linux|理论可替换runtime/profile Adapter，尚未确定/实测；本轮helper不支持|

|目标/模块|具体检查|
|---|---|
|Bilibili/Douyin|production未改、未回归；Douyin匿名UIFID正链未成立，不宣称平台恢复|
|Xiaohongshu/YouTube/X/Instagram/未来平台|未新增支持；平台context隔离于对应Adapter，不把UIFID变成公共依赖|
|PlatformDetector/Parser/ParserService/UI|正式未改/回归；研究确认按钮不进入产品UI，未来Application只协调intent|
|Unified Content Model/MediaContent/MediaResource|未改，无凭据进入公共模型；真实gallery mapping未验证|
|Downloader/Media Processing|未改/回归，无媒体导出/下载/处理|
|Browser Adapter|新Windows研究helper，仅正常context路径；不采集页面内容，不恢复Observation Parser|
|History/Settings/Logging/本地存储|正式未改；日志只metadata，测试profile仓库外且已清除；长期存储/退出异常仍需验收|
|隐私/零服务器|无其他App/系统浏览器会话导入，无凭据值输出/上传第三方解析服务；正常页面向所属平台执行必要请求|
|依赖/安装包体积|无新增产品依赖或打包变更；已有SDK研究复用；生产体积未测|
|性能/维护/正式发布|网页资源事件414不是benchmark；Cookie-only、用户自报/平台变化/原生绑定仍有风险；双端context/gallery验收缺失，不能发布为恢复|

Android安全：本轮没有APK安装/替换/卸载/数据清除；applicationId和签名未核实，不借Windows验收代替Android。

`git diff --stat`（tracked；研究目录未跟踪不在统计中）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：` M AGENTS.md`、`?? v0.4.0/`。AGENTS为已有修改。`git diff --check`通过；新增研究文件/PowerShell语法/日志JSON另核查。不staging，完成后暂停，不进入signer或production。
