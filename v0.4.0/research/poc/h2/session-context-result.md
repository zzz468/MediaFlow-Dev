# Authorized normal-session context + frozen W2 — 2026-09-28

**SCTX-2 — UIFID gate remains**。本次正常 App-owned sessionid/sessionid_ss + ttwid 已准入并发送，唯一一次 detail 返回 **HTTP403 / text/plain / 46 bytes / ArgusSecurityPlugin Uifid Not Found**。正常 session subset 不足以满足当前 W2 的 context composition；不得重复同类注入实验。未取得业务 JSON、target aweme_detail 或 gallery，不是 H2 DATA PATH VERIFIED。Production preference仍U1，signer保持冻结，完成后暂停。

## 1–6. 正常 session 与隐私

最终实验 profile 由本轮全新 MediaFlow research 隔离目录建立，初始 Cookie 空；测试人员本人完成正常交互，勾选 challenge/login 完成。sessionid/sessionid_ss 与 ttwid 存在，expiry 无明显过期证据，UA 与历史 W2 实际 UA 一致；账号认证接口未独立调用，用户确认 + session cookie 作为本次正常会话来源证据。未自动求解 challenge、读取密码、读取系统Chrome/Edge或其他App、导出完整jar。

|发送 Cookie 名称|present|length|domain/path|expiry|
|---|---|---|---|---|
|sessionid|true|32|.douyin.com /|2026-11-27T14:22:44.380Z|
|sessionid_ss|true|32|.douyin.com /|2026-11-27T14:22:44.380Z|
|ttwid|true|127|.douyin.com /|2027-09-28T14:22:47.833Z|

最终实验 profile UIFID=false；缺失不阻止准入。本轮此前一个 profile 曾自然出现 UIFID（length320），但在本地导出错误后已清理；其值没有保存/复用/发送，不代替最终profile状态。没有手工UIFID、msToken、X-Bogus、SecsDK/WAF票据、Argus占位或tracking字段。

真实值仅在自有WebView进程内存及其受控Python子进程环境中流转，发送到所属Douyin detail任务；没有进入Markdown/JSON/console/log/fixture/Git/screenshot。结果只含cookie名称和属性，无value/hash。没有repo外临时secret留下；值的进程对象随退出结束，不声称已做密码学内存擦除。

## 7. 冻结与单变量实现

冻结 endpoint https://www.douyin.com/aweme/v1/web/aweme/detail/；target7690029886242009957；原F2研究signer实现/版本；历史实际Windows UA、note Referer、Accept；四个query顺序 device_platform/aid/channel/aweme_id；相同timestamp策略、正常新时间/entropy、相同实测尺寸和签名编码；原urllib direct/TLS验证、禁止redirect/retry、15秒连接/25秒总限/2MiB读取策略。没有重复/重放历史签名。

原 web_detail_once.py、research_signer.py、vendor算法及W1/W2记录/Dart契约六文件最终hash与上一轮snapshot完全相同。原runner源码SHA256 `fa82bf9dc84550df159140dabc8e1fbbb0a3b88afe3a2b7c2adff7d8050d3a5b`；runtime-facts SHA256 `1608537a73088d33ff93a655546a0da4f0ae5b0807a22f5b17e7acb42b38e541`，与历史W2一致。

单变量为**authorized normal-session context**：新增 Cookie header，只含本轮实际存在的三个allowlist字段。历史W2没有ttwid；本轮按用户修订把真实ttwid放入同一个授权context变量组，不另改query/ttwid初始化策略。原三个显式headers不变；不能字面宣称header数量完全相同，因为新增Cookie正是本轮授权变量。

新增 session_context_once.py 作为准入/一次额度/受控Cookie附加适配器，静态提取并执行原runner从facts读取起的原始AST statements，未修改原runner文件或签名/dispatch/reader；只有Request构造后附加Cookie，和结果元数据纠正为真实context flags。旧W1/W2永久额度不重开；新experiment用独立exclusive结果文件，禁止重复执行。不存在第二套HTTP客户端或替代signer。

## 8–16. 唯一网络结果

[脱敏结果](signer/session-context-result.json)：2026-09-28T14:22:53Z，requestBudgetConsumed=1，maximumDetailRequests=1。

|项|真实结果|
|---|---|
|显式Web detail请求|**1**；无retry/新endpoint/UA切换/后续追加|
|HTTP / body|403 / text/plain / 46 bytes|
|Uifid Not Found|仍存在，Argus marker=true|
|新错误|没有新的明确错误类别；仍uifid-gate|
|signer下一blocker|未证明；explicitSignatureError=false，不能推断接受/拒绝或已进入签名层|
|业务JSON / targetMatch|false / false|
|aweme_detail|false|
|aweme_type / image_post_info / images|未取得 / false / 0|
|图片URL / gallery|未取得；没有媒体下载；dataPathVerified=false|

网页正常交互资源不等于实验重试：两个准备profile共7个navigation、1819个resource事件、1652个response事件，未统计OS全部请求数。第一个profile只有本地导出失败，无detail；第二个唯一实验detail=1。第三方signer/解析/源码网络请求0，旧E1=0。安全拒绝后立即停止。

## 17–19. blocker、下一轮、清理

唯一主 blocker：**当前W2 context composition / UIFID gate，正常session subset已证明不足**。不是“尚未给session Cookie”，不是已经证明signer或endpoint错误；也不能推广所有Web detail必需显式UIFID。

下一轮唯一目标：**重评当前W2的gate策略及正常context消费方式**，明确是否采用正常取得的显式UIFID策略或另一Web-detail request strategy；本轮不选择/执行新路线、不搜索UIFID生成机制、不重复session+ttwid实验。仅新服务端明确signature证据才解冻signer。没有业务数据则不开始production integration。

清理：最终profile nativeProfileClear=true、scopedCookiesAbsentAfterClear=true、BrowserProcessExited=true、profileRemoved=true。独立核对所属目录不存在、helper PID23384已退出、stderr0bytes。first profile目录也不存在，但其原生clear空集检查false，不能把该检查改写成通过。最终成功清理只限本轮正常退出，不代表crash/断电覆盖。

本地限制/纠正：第一次准备在 D:\MediaFlow-secrets 创建目录时 UnauthorizedAccessException，profile被安全清理，额度未消费。后续明确require_escalated的目录创建也由OS拒绝，目录仍未创建；并非自动审批拒绝。没有强改磁盘根ACL，也没有声称目录准备成功。改用用户允许的memory/env方式，重新正常登录后执行一次；这属于本地传递方式修复，不是重试detail或复用历史凭据。指定secret文件最终不存在。

## 20–24. 文件、验证、Git

修改：local-session/AuthorizedSessionPoc.cs 增加可选正常session模式，UIFID不强制，最多取实际sessionid/sessionid_ss/ttwid；UA与登录确认准入，子进程环境传值、完成后自动clear。新增：signer/session_context_once.py、signer/session-context-result.json、本报告；三个README索引增加最新指引。删除源码：无；production修改：无；Git写操作：无。

设计沿用现有自有WebView与原research signer边界。本轮没有新增第三方代码复用、依赖或外部服务；上轮F2算法Apache attribution/NOTICE不变。没有将签名/cookie平台特例放入公共层。

验证：research csc编译PASS；既有11项离线安全契约断言PASS（不覆盖所有新增Native分支）；新Python语法PASS；frozen六文件hash/唯一结果额度/allowlist检查PASS；真实正常用户交互、subset读取/准入、实际请求、最终native clear空集与profile删除已实测。没有必要重复冻结算法14项/契约44项测试，它们是上轮证据。本轮未运行Flutter analyze/full lint或正式Windows/Android/iOS/macOS/Linux App build，未安装Android包；无覆盖/卸载/清设备数据。memory env路径已实测，repo外secret路径失败，不宣称通过。

Git：branch feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b。status仍 ` M AGENTS.md`、`?? v0.4.0/`；预存AGENTS修改未碰。git diff --stat仅AGENTS31行（23 insertions/8 deletions），因为研究目录未跟踪，该stat不代表本轮变更量；git diff --check无报错。无add/commit/push/PR/merge/reset等Git写操作。

## 25. 【项目目标兼容性检查】

|平台|状态与具体边界|
|---|---|
|Windows|已实际测试research正常session/单变量HTTP/清除，正式App build未跑；context仍被拒，不能发布gallery。|
|Android|理论Adapter路径；本轮未构建/实测/安装。需隔离profile、最小消费、clear/重启及真实业务验收，不降低核心发布门槛。|
|iOS|理论WKWebView专用store，未实现/构建/实测；Cookie属性/消费/清除需验证。|
|macOS|理论WKWebView Adapter，未实现/构建/实测；不能直接复用Windows原生helper。|
|Linux|有平台特有风险，未实现/构建/实测；browser isolation/runtime尚未选定。|

|目标/模块|兼容检查与未验证项|
|---|---|
|Bilibili / Douyin|production未改，Bilibili未回归；Douyin仅研究session能力实测，目标内容仍失败。|
|Xiaohongshu / YouTube / X / Instagram / 未来平台|没有新增能力；按需context边界可复用，DouyinCookie/gateway不得成为公共规则。|
|PlatformDetector / ParserService / Parser / Adapter|公共代码未改；临时Native/helper与HTTP适配留research，正式接口/错误回归尚待实现。|
|Unified Content Model / MediaContent / MediaResource|未修改、没有凭据进入模型；无gallery payload，不能宣称多资源映射通过。|
|Downloader / Media Processing|未修改、不下载/处理；队列/暂停/Range/.part等本轮未回归。|
|Browser Adapter / UI|用户正常登录属于U1；只有research窗口，未改正式UX，Native模式不是五端正式实现。|
|History / Settings / Logging / 本地存储|production未改；只保存属性，真实值不写报告或结果；临时secret失败导致重复正常登录，是现有研究体验限制。|
|本地优先 / 隐私 / 零服务器|签名/状态本地，必要Cookie仅发所属平台，未向第三方上传；无服务器、商业解析/云签名。|
|依赖 / 安装包体积 / 性能|无新增产品依赖；正式体积/性能未测，Python/native部署不可当正式跨端路径。|
|维护 / 正式发布|平台context composition仍未满足，gate策略维护风险未解决；无gallery/双端业务验收，不就绪。|
