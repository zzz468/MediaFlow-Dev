# UIFID 首次匿名 bootstrap：RESULT A4（2026-09-28）

**UIFID bootstrap still unresolved。**一次全新未登录 WebView2 profile 的首页导航在正常初始化完成前触发明确 WAF challenge 资源，按项目规则阻止并停止。不能从此推出 UIFID 必须登录、必须 JS、必须浏览器或 signer 已成为下一阻断。Browser Observation 保持 STOPPED AS PRIMARY ROUTE；本轮是独立上下文元数据实验。

## 实验与证据

开始/结束仓库：`D:\projects\mediaflow-v040`，Git top-level 相同；`feature/v0.4.0`，HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。开始已有 ` M AGENTS.md` / `?? v0.4.0/`，保留全部。已读取最新根规则与 signer/UIFID 审计、Browser closeout、匿名路线研究记录。当前规则允许有界正常客户端上下文研究，但明确安全挑战须停止。

预先记录的十五项候选矩阵和执行边界：[实验 README](uifid-bootstrap/README.md)。本轮不复跑旧纯 HTTP 首页 GET，不追加 ttwid 申请，不增加请求签名或登录材料。

| UTC | 阶段 | 实际证据 |
|---|---|---|
| 06:00:00.790 | A | GUID profile 此前不存在；未导入浏览器/profile/凭据 |
| 06:00:02.044–.146 | A | Cookie jar、document.cookie 名称、localStorage/sessionStorage keys、IndexedDB database 元数据均为空；IDB 查询成功 |
| 06:00:02.151 | A | Douyin origin 空 HTML fixture 在本地拦截，平台请求 0；无登录态、UIFID/UIFID_TEMP |
| 06:00:02.153 | B | 唯一真实首页导航 `https://www.douyin.com/` |
| 06:00:02.663 | B | 首次 Cookie snapshot 仍为空；此时不能声称页面已完成初始化 |
| 06:00:04.048 | B | 检测并阻止 `lf-waf-js.byted-static.com/obj/waf-jschallenge/out-sha256.js`；安全停止 |
| 06:00:04.898 | 结束 | WebView dispose 后 BrowserProcessExited 已收到；无 note / detail 实验 |
| 06:00:50.359 | 清理 | 核对实验 profile 完整路径、父目录、GUID 及本轮日志身份后删除；existsAfter=false |

原始记录：[浏览器元数据](uifid-bootstrap/browser-metadata.jsonl)、[归属清理](uifid-bootstrap/profile-cleanup.jsonl)、[离线策略测试](uifid-bootstrap/offline-policy-test.json)。不保存 Cookie 值、UIFID 值/哈希、storage 值、页面正文或账号数据。浏览器临时 profile 已删除，研究日志只有元数据。

真实 public navigation=1；note/work=0；显式 detail=0；ttwid registration=0；重试=0。WebView 拦截器记录放行资源 request=4、停止前收到 response callback=1；另外 challenge resource blocked=1，detail blocked=0，image/media blocked=0。这是拦截事件计数，不能当成服务端收到四次请求或操作系统全部网络流量的证明。Phase A 的本地 fixture 导航另计，不产生平台请求。停止后的待完成请求可能被取消或完成，未继续观察/消费。

## 首次来源分类与 Phase D

**Server-issued / Client-generated / Derived / Auth-bound 四类均未定。**A 的空 origin 和 B 的早期空 Cookie 是时点证据，不是正常初始化完成后的阴性结果。B 在 Cookie sample 与 storage async sample 之间停止，**没有有效的 B storage snapshot**；停止后未恢复采样。故不能宣称所有存储内均不存在 UIFID，也不能宣称 anonymous SDK 已运行成功但未生成。

Set-Cookie 记录器只提取 header 名称；本次未记录 UIFID/UIFID_TEMP 的 Set-Cookie，但响应窗口不完整。IndexedDB 仅看 database 名称/版本，未读记录；即使完整数据库元数据为空，也不等于已审计 SDK 的所有状态。

Phase C 因安全停止未执行。Phase D 仅完成已获取元数据与固定参考源码的静态对照：安全停止前被列出的唯一 script URL 是 `https://lf3-short.ibytedapm.com/slardar/fe/sdk-web/browser.cn.js`；URL 本身不证明其是 UIFID 生成器，也没有调用栈或内容证明 SecSDK 初始化已到达。challenge JS 未加载/运行/求解/逆向；安全停止后没有继续请求 Douyin JS 或随机导航。**公开页面正常 SDK → UIFID setter/发行响应的调用链未取得**，不能把这一项写成已审计完整或认定“SDK 应生成但环境没触发”。

重新核实 [ucmao/media-parser 固定 parser](https://github.com/ucmao/media-parser/blob/bf961fb30bbd13ba9d04d16466eb8a851932297b/src/parsers/douyin_parser.py)：`_get_uifid()`（194–227行）读独立环境变量、用户配置 Cookie/纯字符串、已有 session Cookie；`_get_ttwid()`（268–300行）独立注册/缓存 ttwid，不构成 UIFID 生成链。现有本地固定提交 mock tests（986行起）验证提供的假 UIFID 的提取和注入，并非 fresh-profile bootstrap。**此实现证明 UIFID 的消费方式，但不一定证明 UIFID 的首次匿名生成方式。**文档对登录 Cookie 的要求不等于 UIFID 必须账号绑定的实测证据。

本轮唯一关键缺失证据：**一条未登录、无安全挑战、正常 SDK 初始化完成的首次 UIFID 发行/写入事件，并能定位对应响应或 JS 调用点。**这同时决定首次来源与生成时机。已有试验只排除“这一次纯 HTTP 首页响应直接可见 UIFID”和“所审计 media-parser 方法本身实现了首次生成”；没有排除浏览器匿名生成、其他正常初始化动作或登录绑定。

后续仅围绕这条缺失事件做公开正常初始化调用链的静态定位；不重新以相同环境首页反复试 WAF，不追加随机 Token/固定身份/签名绕过。若无法取得该公开证据，A4 保持，不能直接进入 signer 或登录系统。

## 本轮要求的24项答案

| 项目 | 结论 |
|---|---|
| 1 首次来源 | 未定位；本轮停在首页 challenge 入口 |
| 2 无需登录？ | 未证明；本轮确实未登录，不代表成功 bootstrap |
| 3 需要 JS？ | 未证明；纯 HTTP 一次无值不能证明 JS 必须 |
| 4 需要 WebView/browser？ | 未证明；A2 不成立 |
| 5 为 Cookie？ | 参考消费者读取 Cookie；平台首次形态未定 |
| 6 UIFID_TEMP？ | A 不存在，B 完整初始化后存在性未核实 |
| 7 生命周期 | 无 UIFID 正样本；TTL/刷新/重启保持未测试；实验 profile 生命周期清理已实测 |
| 8 profile 关系 | 隔离新 profile 已证实；UIFID profile 绑定未测 |
| 9 UA 关系 | 未改默认 runtime UA；绑定/具体版本未记录、未测 |
| 10 ttwid 关系 | 独立标识；本轮没注册，对 UIFID 因果关系未知 |
| 11 media-parser bootstrap | 所审计代码是已有状态消费者，无首次匿名生成证明 |
| 12 新 detail 实验 | 未执行；可信匿名 UIFID 的前置条件未满足 |
| 13 Uifid Not Found 消失？ | 未测试；不能更新旧 baseline 403 结论 |
| 14 下一层阻断 | 本轮是浏览器初始化安全挑战；HTTP detail 下一错误未知 |
| 15 signer 下一阻断？ | 没有证据；保持冻结 |
| 16 Browser 定位 | 候选 Context Bootstrap Provider；本轮未证实能完成此能力 |
| 17 production 架构 | 若后续证明正常匿名 JS 必须，则 Adapter bootstrap + HTTP detail；现阶段不接入 |
| 18 数量 | 1真实导航，4放行请求事件，1响应事件，1challenge阻止，0detail、0重试 |
| 19 文件 | 见下方精确本轮清单 |
| 20 检查 | C#编译/离线策略/日志JSON与空origin断言通过；Flutter analyze/test/lint/build 未运行 |
| 21 Git | ` M AGENTS.md` / `?? v0.4.0/`，HEAD/branch 未变 |
| 22 production | 未修改 |
| 23 Git写操作 | 无 add/commit/push/merge/tag/reset/分支删除 |
| 24 兼容性 | 见下一节；不把 Windows 研究通过视作双端发布完成 |

## 设计、文件、验证与限制

本轮修改已有文件：`v0.4.0/README.md`、`v0.4.0/research/README.md`（最新状态入口）。根 `AGENTS.md` 修改是本轮前已存在，未改。新增：本报告；`uifid-bootstrap/ContextBootstrapProbe.cs`、`build.ps1`、`README.md`、`browser-metadata.jsonl`、`profile-cleanup.jsonl`、`offline-policy-test.json`。删除研究/production 文件：无；只按精确归属删除本轮生成的忽略目录下临时 profile。

独立研究程序避免污染 Parser、公共模型或旧 Browser helper，默认拒绝网络，明确参数才允许单次有界正常导航；编译复用已有 WebView2 .NET462 SDK，运行时不调整身份或 fingerprint。使用系统 csc 先遇旧 C# catch-await 和 header iterator API 编译错误，修正后最终编译成功、offline policy 自测成功；JSON逐行解析、空 origin 四类状态断言与字段脱敏检查通过。没有新增自动化生产测试，Flutter/Dart analyze、生产静态分析/lint、生产单测、Windows Flutter build、Android build 均未运行，不能标 PASS。Windows standalone probe build 与真实运行通过只覆盖本轮研究边界。

第三方：media-parser 是源码审计/设计参考，没有代码复用；根 MIT，已存 signer 文件额外许可风险继续冻结，不深入、不复制。WebView2 是已有研究 SDK/API 复用，其 LICENSE 随 build 复制，仅用于 Windows 独立探针；未新增 pubspec/Gradle/native生产依赖，无新增服务。采用 Microsoft 官方 [BrowserProcessExited 生命周期 API](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.browserprocessexited?view=webview2-dotnet-1.0.4191.47)，实测收到事件后执行本轮 exact-owned profile 清理，不覆盖旧 Browser helper 的历史 cleanup 结论。

尚未验证：完整正常页面、note、UIFID正样本、SDK发行/计算点、Cookie属性/TTL、重启/new profile值差异、UA/ttwid绑定、HTTP context replay、detail错误迁移、Android同等研究、生产五端构建/功能。探针12秒窗口、透明隐藏WinForms宿主、拒绝权限/弹窗、阻止image/media/detail以及安全停止均会改变可观测环境；本次在约1.9秒触发挑战而提前结束，不能用窗口阴性推导匿名不支持。公共页面消息来源仅用于元数据，未用于提供可信凭据或生产策略。

## 【项目目标兼容性检查】

| 平台 | 本轮状态与具体限制 |
|---|---|
| Windows | 独立probe构建通过且已实际测试空profile/安全停止/退出后清理；生产应用构建未测；UIFID能力未支持/未证实 |
| Android | 本轮未构建、未实测、未安装；WebView/profile异步生命周期需独立Adapter验证；没有覆盖/卸载/数据清除或签名操作，applicationId不适用 |
| iOS | 理论有WKWebView Adapter路径；本轮未实现/构建/实测；Cookie与storage生命周期有平台风险 |
| macOS | 理论WKWebView Adapter路径；本轮未实现/构建/实测；Windows .NET probe不兼容 |
| Linux | 理论替代Browser Adapter路径；本轮未实现/构建/实测；运行时/持久profile能力未确定 |

| 架构/目标 | 实际检查与风险 |
|---|---|
| Bilibili / Douyin | 本轮无production diff，不改变Bilibili路径但没回归；Douyin图库仍BLOCKED，现有视频没回归，不宣称恢复 |
| Xiaohongshu / YouTube / X / Instagram / 未来平台 | 未接入/未测试；平台上下文保持专属Adapter，不把UIFID扩成通用平台前提 |
| PlatformDetector / ParserService / UI | 未修改/未回归；将来bootstrap须由应用接口协调，UI不得直接抓底层凭据 |
| Parser / Adapter / Browser Adapter | 只新增独立Windows研究器；旧Browser主路线仍停止；不可直接拿本probe做生产跨平台实现 |
| Unified Content Model / MediaContent / MediaResource | 未修改；候选context不进入通用模型，未来多资源仍可复用；UIFID能力未证实 |
| Downloader / Media Processing | 未修改/未回归；本轮不下载、不处理；后续上下文应用受控本地引用，不污染资源/下载平台协议边界 |
| History / Settings / Logging / 本地存储 | 未修改生产；研究只存元数据，新profile已删除；未来TTL/失效/清除尚待正样本验证 |
| 隐私 / 零服务器 | 无第三方解析/云处理/同步；不导入外部登录态、不上传凭据/账号数据、不日志记录Cookie值；正常页面自身平台资源请求发生，未进行账号操作 |
| 依赖 / 包体 / 性能 / 维护 | 生产依赖和打包配置未改；研究复用Windows SDK、额外忽略build产物，生产包体未测；probe轮询只用于短期研究，不能当作生产性能方案；平台SDK更新仍是候选方案维护风险 |
| 正式发布 | 未满足Windows+Android图文验收，不能发布为已恢复；production仍BLOCKED |

## Git结果与暂停

`git diff --stat`（tracked，无法反映整个已有untracked研究目录）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：

```text
 M AGENTS.md
?? v0.4.0/
```

收尾 `git diff --check` 通过（只覆盖tracked diff）；新增build.ps1的PowerShell AST语法检查通过。该根规则diff是本轮开始时已有内容；新增与修改研究文件仍包含在已有untracked v0.4.0目录中。没有Git写操作。**本轮暂停，不自动登录、继续导航、实现signer或production接入。**
