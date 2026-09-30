# H2 Web detail 架构与独立离线 PoC — 2026-09-28

> **永久冻结：** 用户已决定自研H2不再恢复，包括UIFID/W2/W3/新策略/Browser Observation内容解析/Feed/SSR。后续方向是[独立Gallery adapter与session集成架构](../../gallery-integration-architecture.md)，本轮[离线结果](../../gallery-integration-result.md)已完成，不改变本目录历史源码或signer。以下旧后续建议不再是执行指令。

> **最新正式决策：** `FROZEN — CURRENT WEB DETAIL PATH BLOCKED BY UIFID/CONTEXT GATE`。不再 W2/W3、第四套策略、UIFID bootstrap、Cookie叠加或 signer改动。[仓库外原 F2 实测](../../reference-project-validation-2026-09-28.md)已在正常自有 session 下取得目标 13 张图，未提供 UIFID；仅授权原项目自身默认头，本轮不解冻自研 H2、不集成生产。下一轮只做 App-owned session UX + adapter / integration architecture；下文状态和建议保留为历史。

> **最新硬止损：**[W3 DL-style A/B](w3-dl-strategy-result.md)两次均403/46bytes/Argus Uifid Not Found，无signature/业务JSON/gallery。当前signer未改，不再第三/第四套headers/query组合；下一轮仅决策显式正常授权UIFID context或关闭当前Web-detail H2，完成后暂停。

> **当前真实结果：**[正常session subset实验](session-context-result.md)已执行1次，SCTX-2：可信sessionid/sessionid_ss+ttwid仍403/46bytes/Uifid Not Found。原signer/runner保持hash不变；不再重复session注入。下一轮只重评当前gate策略/context消费，未取得gallery，不开始production。

> **最新离线审计：**[context composition / U1-U2](context-composition-audit.md)已比较M/F/D，确认F2无UIFID分支仍使用Argus占位workaround（不采用）。没有唯一因果/binding证明，无授权U2输入、本轮平台请求0；Production preference=U1，signer冻结，旧W2 gate仍为当前策略唯一主blocker。

> **当前结论修正：**以下为早先契约轮的历史报告。后续[capability / signer 报告](capability-signer-audit.md)已将 UIFID 改为 conditional capability；真实 Apache-2.0 research signer 已实现，14 算法测试、44 契约通过。W1/W2 共两次，W2 返回 UIFID gate；仅当前策略 context blocked，不能推广所有 H2。下文“signer 未实现”“固定 context 前置”“下一轮不开始 signer”“42 项/零请求”均只描述历史轮，不是当前状态。

结论：**H2-CONTEXT-BLOCKED**，基于已保存的本机证据，不是本轮重新登录或网络复测结果。唯一主 blocker：尚未取得正常来源、可受控消费的 UIFID / Web 请求上下文。历史入口在正常登录完成前遭遇明确 challenge；不能说“登录后仍无 UIFID”，不能说平台必需登录，也不能说 UIFID 是唯一充分条件。

H2 路线保持冻结。三个组件及生产接入门槛已经设计，独立**离线契约 PoC**可运行；真实 H2 PoC **未完成 / 未通过**。本报告不能作为 production-ready 验收证明。没有实现或验证 A-Bogus 算法，没有目标 gallery JSON，不进入 production integration。网络实验前置条件不成立，因此本轮 P1/P2/P3 均未执行；不是通过减少验收要求完成任务。

## 基线与必读证据

- cwd / top-level：`D:\projects\mediaflow-v040` / `D:/projects/mediaflow-v040`。
- branch：`feature/v0.4.0`；HEAD：`e2ea89d4e156c843af09b4c491984a2206f1135b`。
- 开始状态：` M AGENTS.md`、`?? v0.4.0/`；全部保留。根 AGENTS 修改在本轮前已存在。
- 已读取根 AGENTS、[横向审计](../../douyin-gallery-horizontal-audit-2026.md)、[signer 审计](../web-detail-signer-route-audit.md)、[UIFID 审计](../uifid-context-audit.md)、[local session 审计](../local-session-audit.md)、production DouyinParser / DouyinDetailSession、ParserService、MediaContent / MediaResource。
- 旧审计中的“禁止所有 App 登录”“下一轮不开始 signer”是历史规则/当轮范围；本轮按当前 AGENTS 和本次请求完成离线 contract。禁止 challenge 自动求解/安全拒绝后继续叠加身份材料仍有效。
- 本次请求允许用户正常交互，但 AGENTS 第十节规定“遇到……额外安全验证……必须安全停止当前解析”。因此不重复已停止的首页入口，不执行平台挑战，不启动另一环境碰概率。不是 signer 全面禁令。

## 三个边界与 Application 协调

```text
Application：目标 ID + 用户建立/刷新/清除会话意图
  → DouyinContextProvider：状态 + opaque handle
  → DouyinWebDetailClient（在 Douyin Adapter 内执行）
       canonical request → DouyinWebRequestSigner → signed request
       scoped context → bounded HTTP transport → raw JSON
  → 后续 Douyin Parser：raw aweme_detail → MediaContent
```

ContextProvider 不读内容、不签名、不下载：持有 App 自有 profile、scope、epoch、真实 UA、有限必要状态；提供 `status/acquire/invalidate/clear`。正式设计增加 `establish(userIntent)`、`refresh(userIntent)` 和清除结果；本轮这些 Native 操作没有新实现。未具备上下文可返回 sessionRequired，但不能把该内部错误解释为服务端已证明必须登录。匿名可用时不强制账号。

公开 handle 仅 owner + epoch，私有构造，不含凭据。status 仅状态/过期与字段可用性，不提供完整 Cookie jar。签名输入、uifid header、HTTP envelope 均限定在 Douyin Adapter 内；ParserService/UI/History/Settings/Logging 不接触值。Client 受控消费 handle，ContextProvider 的私有 material API 是同一 Dart research library 内部协作，不是跨平台公开接口。正式 Native Adapter 应由同一进程内的 executor 消费，Binder/MethodChannel 只返回 opaque ID、脱敏状态、内容。

Signer 只做 canonical request → SignaturePatch；不持久化、不发请求、不管理 WebView、不解析 aweme。算法可替换；没有合格实现时 `UnavailableSigner` 明确失败并保证零请求。测试 RecordingFixtureSigner 返回 MOCK，仅用于编码/输入传递检查，绝不是 A-Bogus、测试向量或可提交平台的签名。没有“换变量名”重写受限算法。

Client 固定 HTTPS Douyin detail origin/path，以参数 awemeId 建立请求，接收 raw JSON，校验 status_code / 精确目标 ID。不生成 DownloadTask/History/UI/MediaContent。未来 transport 负责 direct、禁跳转/代理/重试、流式 2 MiB 上限、连接15秒/总25秒、取消；本轮没有 live transport。离线 Client 另检查 body 上限与清除后迟到响应；这不能替代 Native in-flight cancel、实际流式限额或内存擦除验收。

Application 仅协调 intent / capability / error。用户建立正常会话后可授权原目标一次重新解析；不自动升级身份或换 signer 重试。Provider 不承接 Browser Observation，不读取 DOM、hydration、XHR 或加载媒体正文。

## 最小 context：源码携带不等于服务器必要

|字段/状态|证据与等级|本轮/未来消费规则|
|---|---|---|
|真实 UA、note Referer|四项目 Web 请求共同使用；具体版本/值必要性未消融|UA 来自自有 runtime；signer 与 HTTP 使用同一值，不伪造设备|
|UIFID|本机 baseline 明确 Argus Uifid Not Found；来源链见既有审计|当前缺失的条件状态；只从 App 正常 context 取得，内部 transient header；不生成、不重放|
|Cookie/session subset|四项目有会话能力；账号必要性未证实|由 profile 保管，当前不传 jar；后续每个字段须有来源/必要性证据|
|ttwid|UC 有初始化，其余多为透传/工具；非共同硬门槛|likely context 候选，未证明本目标必需；本轮不注册、不加入|
|UIFID_TEMP|既有读取线索；不能替代 UIFID|conditional，单独证据才准入|
|msToken|三项目使用、来源不同|conditional；只正常平台签发，不随机生成|
|verifyFp / s_v_web_id|源码线索，无本机因果验证|conditional；不合成指纹、不硬编码|
|账号 Cookie|源码正常登录路径可提供|仅用户主动授权后的 Adapter 内最小子集；不默认启用|
|A-Bogus|四项目 detail 收敛最强|独立 signer；算法/输入/许可/向量都待验证|
|x-secsdk-web-signature / timestamp|条件引用，不是共同条件|P2 后明确新证据才评估；不是 A 的别名|
|x-tt-argus 占位|仅 F2 workaround|排除，不发送|

本轮研究入口候选保留旧 baseline 四个 query：device_platform=webapp、aid=6383、channel=channel_pc_web、aweme_id。这是可对照 baseline，不是已经证明的服务器最小参数集合。UIFID 原始值不传 signer，除非后续协议证据要求其成为签名 query；那时只在 Adapter 内以 exact bytes 传入。没有 `Map allCookies`。

## 生命周期与双端设计

absent → userEstablishing → availableUnvalidated → scopedValidated；expired/rejected/challenged → revoke；clearing → cleared/clearFailed。存在某字段不等于会话有效；scopedValidated 必须标注作品/入口/时间，不推成全平台认证。session Cookie 无期限时 expiry=unknown，不能虚构十分钟平台 TTL；可另设短任务 lease deadline。

清除先提升 epoch、撤销引用、取消 Native 请求/建立流程，再清本 profile，确认退出/归属/删除结果。清除失败留 clearFailed，不默认为成功，不删除共享父目录、不操作外部浏览器。crash 恢复先核对 owned marker/活动实例/进程归属再清理。刷新不自动重放已失败任务；安全拒绝冻结当前 operation。

|平台|实现路径与验收门槛|
|---|---|
|Windows|独立 WebView2 UDF/profile；URI-scoped CookieManager；context/client 在 Native Adapter 内；清除后等 browser 进程退出再移除精确 owned UDF。旧 PoC 实测创建/停止/清除，不证明长期持久化、refresh、正常登录或 UIFID 正链。|
|Android|优先 feature-gated MULTI_PROFILE named Profile + profile CookieManager；不支持则独立 worker，在任何 android.webkit 调用前 setDataDirectorySuffix。HTTP 消费留同 worker，不复制 Cookie 到主进程；绝不回退默认 jar。Cookie 属性/expiry unknown 不猜测。隔离、clear、进程退出/重启、Native cancel、UIFID 正链均需实测。|
|iOS|理论专属 WKWebsiteDataStore + WKWebView/HTTP Adapter；属性、clear 和绑定未实现/实测。|
|macOS|理论同类 WKWebView Adapter；关闭/清理/重启与平台绑定待验证。|
|Linux|替换 Browser Adapter runtime；隔离 profile 与清除能力未选定/实测。|

官方 API 核对：[WebView2 UDF](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/user-data-folder)、[Android Profile CookieManager / MULTI_PROFILE](https://developer.android.com/reference/androidx/webkit/Profile)、[setDataDirectorySuffix](https://developer.android.com/reference/android/webkit/WebView#setDataDirectorySuffix(java.lang.String))。Android 文档要求不同进程目录不同、suffix 在任何 WebView/相关 API 初始化前设置。它们支持候选机制，不证明目标平台会话可以建立。

Windows/Android 同为 production gate。Android 若不能安全隔离/清除则 capability unavailable，是架构阻断；不能把 Windows 先发布当完成。本轮无 Android 安装、覆盖、卸载、清数据；未核实设备 applicationId/签名，此轮未进行安装验收。

## Signer 来源与许可证矩阵

继承固定 SHA/hash [来源清单](../../douyin-gallery-horizontal-sources.json)。本轮复核缓存 LICENSE 和 signer 文件许可头，未读算法体、未执行第三方程序；GitHub 三次固定 LICENSE 页面 open 缓存未命中，没有据此改写旧审计。以下“可复制”是本轮采用决定，不是法律意见。

|实现|License / 来源状态|可复制进入本轮|行为参考|测试向量可用性|
|---|---|---|---|---|
|DLWangSan abogus.py|头明示 Evil0ctal 修改、原始 JoeanAmier GPLv3；仓库缺 LICENSE/另有用途限制|否|只参考公开输入输出，不照译源码|无许可清楚、独立验证的保存向量|
|ucmao a_bogus.js|根 MIT，既有审计记录文件商业限制及来源待清理|否|只记录调用 query/UA 边界|未取得可用向量|
|jiji262 signer 依赖|根 MIT；模块级谱系未完成，page bridge 实现不在所审公开树|否，待模块审计|接口与职责设计参考|未取得可用向量|
|F2 abogus.py|根与文件头 Apache-2.0；不是 GPL 风险已消除的完整证明|本轮不复制；谱系/依赖/是否合成特征仍待审|算法互操作候选；不采用 Argus 占位或生成指纹|未取得真实公开已核验向量|
|MediaFlow clean-room|本轮只自编 contract/client/fixture；无密码算法|自编 contract 可用作研究|非第三方算法复用|42 项合成契约断言，不是协议向量|

F2 是许可较清晰的候选，不能说所有 signer 都被 GPL 阻断，也不能仅根 LICENSE 就宣称全部可搬运。若后续实际采用须检查具体代码谱系/依赖、Apache NOTICE/版权等义务及五端实现；本轮没有这种采用，没有新增 attribution 文件。

clean-room 互操作在原则上有路径：只用合法公开客户端输入输出/非敏感向量建立独立行为规范，隔离受限算法阅读与实现，固定 method、exact query、UA、时间和必要算法 entropy，再自行实现并验证。不借“clean-room”标签给已读受限源码照译洗来源；本轮未验证其可实现/当前平台接受，不能承诺成功。算法以外合同由 MediaFlow 自编，未复用第三方代码。不能使用远程 signer 或平台挑战 token 重放。

## 离线 signer contract 与错误模型

本轮 canonical convention：显式有序 query pairs，不排序，不容许重复 key/已有 a_bogus/X-Bogus，UTF-8 percent encoding，space=%20、+=%2B、%= %25（无空格），签名值原始输入后只编码一次；UA 非空、无 CR/LF，timestamp 非负。这里只验证自定义约定，是否与平台算法相符待 protocol vectors；未来不同 signer 可明确自己的 canonical adapter，不能暗改 bytes。

算法 entropy 若必需须显式输入或可控随机源；固定输入+时间+entropy 才可做确定向量比较。合同保留时间对象，不自称算法必定 Unix 秒/毫秒，不虚构算法时间窗口。FixtureSigner 记录 UA/time 不证明密码学 UA binding；稳定格式/协议正确性尚未验证。

错误设计：sessionRequired=本地缺 context 或平台明确要求会话；sessionExpired=已知 expiry/撤销；securityChallengeRequired=明确 challenge/安全拒绝；signatureRejected=正常 context 下响应明确签名校验拒绝；contentUnavailable=明确删除/不可用；unsupportedContent=明确类型暂未支持；networkFailure=网络异常；parserSchemaChanged=非预期结构。另加 signerUnavailable 和 requestRejected，避免把缺实现、未知403强行归入签名失败。付费/地区/权限拒绝需保留独立 detail reason，由未来证据目录映射，不自动登录。

当前 Client 只实现合成可核实的 subset：Argus/challenge、404/410、未知 HTTP 拒绝、invalid JSON/status/target、networkFailure；其他状态为设计、未获真实错误样本。不记录 exception 原文、完整 URL/body/Cookie/signature；默认 toString 脱敏，但这不是所有调用者永远不会泄漏的证明。Native/crash telemetry 必须继续禁止凭据序列化。

## 网络分层、数量与成功条件

目标仍 `7690029886242009957`，没有证据证明失效，不替换。

|层|先决条件|本轮结果/请求数|
|---|---|---|
|P1 context + baseline|正常 App context 可用，旧安全停止解除有独立证据|NOT EXECUTED / 0；必要状态未取得|
|P2 context + A-Bogus|许可安全实现+离线真实向量；P1 非安全拒绝且有签名必要性证据|NOT EXECUTED / 0；未进入签名校验层|
|P3 其他 context/signature|P2 明确新非挑战阻断，单变量预案|NOT EXECUTED / 0；不得泛加参数|

每层最多一次，无自动刷新概率尝试。未知拒绝记录 unknown，明确安全拒绝停止整个 operation，不能 P1 被安全拒绝后自动继续 P2/P3。当前无 live runner，误运行测试不会请求平台。

本轮新建立的真实 session/context：**0**；仅内存合成 fixture。历史 [session-metadata.jsonl](../local-session/session-metadata.jsonl) 的 owned profile 在 UIFID/login 完成前遇 out-sha256 challenge，已 clear/退出/删除；此次只读取证据，未重建 profile。历史显式 detail=0。旧 HTTP baseline Argus UIFID missing 见 [network evidence](../web-detail-baseline-network.jsonl)。这些不是本轮网络结果。

target aweme_detail / images / image_post_info / 图片 URL：**本轮均未取得**。合成 example.invalid 图片列表不能作为真实 payload。成功须满足本次请求正常业务响应、精确目标、可识别图文、至少一个真实资源结构、可确定顺序、有效图片 URL，context/signing 均本地。transport 通过但无 gallery 时只能 transport PASS / payload NOT VERIFIED；本轮连真实 transport PASS 也没有。

## MediaContent 条件映射预案

没有真实 JSON，**不实现、不宣称最终映射已验证**。候选：id=aweme_id、platform=douyin、description=desc、author=nickname、title 从实际 desc/中性作品名取得、sourceUrl=公开 note URL。type 依据真实 gallery/payload；按原数组位置建 image resources，位置决定 ID/顺序，重复 URL 不去重；仅验证公开 HTTP(S) URL，不携带 context 凭据。url_list 优选规则、扩展名和 MIME 必须等真实字段验证，不能照抄第三方优先项。

现 MediaContent/MediaResource 支持 ordered List 与 image；静态多图理论可映射。Live Photo 无本轮真实样本，暂不设计具体 pairing 字段、不改模型；真实样本有 image+video 配对需求后再评估最小关联演进。现 DouyinParser 返回 VideoInfo 且完整性要求 videoUrl；下一阶段接入必须走平台 Parser/Application 契约演进，不能凭本轮 mock 绕过正式单视频检查。

## 验证与交付

新增：本 README、h2_contract.dart、h2_contract_test.dart、offline-results.json。修改：v0.4.0/README.md、research/README.md 追加最新索引。删除：0；production 修改：0；Git 写操作（add/commit/push/merge/tag/reset/PR）：0；新增依赖：0，纯 Dart 标准库；产品包体/依赖配置未改。

自动化：42 项合成离线检查 PASS，包括 Unicode/保序/单次编码、重复和签名参数拒绝、UA/time 传递、缺 context/缺 signer 零请求、过期边界、跨 owner、clear/迟到响应、单次消费、challenge 撤销、未知403不归因 signer、JSON/目标/schema/network/410、默认诊断脱敏。算法正确性、真实签名格式、真实 UA binding、图片 URL 可用性与 Native 生命周期未验证。

命令（用 SDK exe 避开 Flutter launcher）：

```powershell
& D:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe format v0.4.0/research/poc/h2
& D:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe analyze v0.4.0/research/poc/h2
& D:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe v0.4.0/research/poc/h2/h2_contract_test.dart
```

Dart 定向 analyze：No issues found。format：通过，但 root include `package:flutter_lints/flutter.yaml` 无法解析，**完整 Flutter lint 未通过验收**。Flutter launcher 首次命令未返回输出，终止本轮该 session，直接 SDK 的 format/analyze/test 正常完成；没有通过 pub get 改依赖。Windows/Android 正式 build、Flutter test/analyze、APK lint、iOS/macOS/Linux build：本轮未运行；只 research 标准库变更，不用历史构建结果代替本轮。

## 【项目目标兼容性检查】

|平台|状态|
|---|---|
|Windows|离线 contract 已实际测试；旧 Native profile 创建/安全停止/清除有证据，本轮未复测；正常会话/真实 signer/gallery/生产构建未验证，有 runtime/context 绑定风险|
|Android|纯 Dart contract 理论兼容；Native 隔离/上下文、构建/真机未验证；与 Windows 同等 production 门槛，不能发布为已支持|
|iOS|纯计算理论兼容；WK Adapter 未实现，本 PoC 无实际平台支持证明|
|macOS|理论兼容；Native profile/退出/清理有待实现的风险，未构建/实测|
|Linux|理论兼容；runtime 替换未定，未构建/实测|

|目标/模块|具体检查|
|---|---|
|Bilibili / Douyin|生产未改、未本轮回归；Douyin gallery 仍 BLOCKED，不能宣布整个平台恢复|
|Xiaohongshu / YouTube / X / Instagram / 其他未来平台|没有新增支持；Douyin上下文/签名保留平台边界，未来各自Adapter验证|
|PlatformDetector / Parser / Adapter / ParserService / UI|正式接口未改；未来用户intent协调及 MediaContent 接入尚需独立实现/回归|
|Unified Content Model / MediaContent / MediaResource|未改；静态顺序理论合适，真实URL选择/LivePhoto配对未验证|
|Downloader / Media Processing|未改、未回归；无图片下载/处理；将来仍不能消费身份材料|
|Browser Adapter|本轮无导航/Observation/Native扩展；Provider仅context，不成内容Parser|
|History / Settings / Logging / 本地存储|正式未改、未回归；只保存研究元数据；长期profile/crash/clear失败还需验收|
|隐私 / 零服务器|无外部浏览器/系统Cookie读取，无第三方signer/解析服务，无账号操作；fixture全合成，默认诊断脱敏|
|第三方依赖 / 安装包体积|没有新增，未改打包；未来 signer engine 的移动端体积/许可需评估|
|性能 / 后续维护|离线小样本测试，不是benchmark；协议query、签名、错误结构、context绑定会变化，需要真实向量与版本化证据|
|正式发布|双端上下文/签名/目标gallery/下载和GUI验收缺失，不能进入正式发布|

Git tracked `diff --stat`（新增 h2 在 untracked v0.4.0 内，不会显示）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：` M AGENTS.md`、`?? v0.4.0/`。HEAD/branch 不变。`git diff --check` 通过；新增 h2 四文件独立检查无行尾空白、结果 JSON 解析/42 项/零平台请求一致性通过。Dart format 最终检查 0 changed。不 staging。

下一轮唯一目标：**完成 H2 正常自有会话/context 的可用性前置验证（UIFID 的受控取得与消费）**。必须先有独立证据说明正常入口可成立；不得重复旧 challenge 导航、UIFID 首次 bootstrap 研究、Mobile Feed、匿名旁路、新 endpoint 泛搜或 Browser 内容观察。本轮没有这样的证据，暂停真实实验；不改路线、不替代为 signer blocker。context 正常后才进行许可安全 signer/真实向量和一次分层 detail 验证。production integration 仅 H2-PASS 后另轮启动。
