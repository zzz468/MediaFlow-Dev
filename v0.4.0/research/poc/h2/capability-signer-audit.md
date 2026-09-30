# H2 capability / real research signer — 2026-09-28

本报告取代旧文档中“UIFID 是 H2 固定前置条件”“signer 尚未实现”的当前态描述；旧 baseline、C5、H2-T5 仍是历史证据，不改写。最新附件目标是最小条件重新建模与 signer PoC，并非重新启动登录实验。

结论：**H2-CURRENT-STRATEGY-CONTEXT-BLOCKED**。已实现真实、注明 Apache-2.0 来源的 research signer；离线算法检查通过。两次 detail 额度已用完。W1 本地读取响应失败，没有保存可用 HTTP 证据；修复读取器后 W2 返回 **403 / 46 bytes / ArgusSecurityPlugin Uifid Not Found**。当前策略进入 UIFID gate，不证明所有 H2 都必需 UIFID，也不证明签名已被服务器接受。无业务 JSON、target aweme_detail 或 gallery；不是 H2 DATA PATH VERIFIED，production 未接入。完成后暂停。

## 1–3. 五项目条件矩阵与假设修正

基于[固定源码清单](../../douyin-gallery-horizontal-sources.json)和本地缓存复核。DL / UC / JJ / F2 / JW 分别为 DLWangSan/douyin_parse、ucmao/media-parser、jiji262/douyin-downloader、Johnserf-Seed/f2、jackwoo725-ux/douyin-downloader。

这里 required 仅表示**被审计实现分支要求/调用**，不是平台协议必需；optional 表示可以缺省；fallback 表示替代路线；implementation-specific 表示特定分支行为；unknown 表示未证明必要性，括号补充源码未见。未重新请求参考项目验证成功率。

|条件|DL|UC|JJ|F2|JW 本地 Dart 路线|
|---|---|---|---|---|---|
|Web detail|required 主路线|required 主路线|required 主路线|required detail 方法|unknown（Share SSR / legacy iteminfo，不是 Web detail）|
|A-Bogus|required 主尝试|implementation-specific（调用，异常可继续）|required 主签名，异常可换 X|implementation-specific（签名可配置）|unknown（未见）|
|X-Bogus|fallback|unknown（reviewed detail 未见）|fallback|implementation-specific（可配置替代）|unknown（未见）|
|UIFID|unknown（独立 header 未见）|optional（有值才加 header/secsdk）|implementation-specific（page_bridge SDK；普通分支空 query）|optional（Cookie UIFID / UIFID_TEMP 有值才加）|unknown（未见）|
|ttwid|optional（外部 cookie 透传，不主动要求）|required 实现初始化，失败用固定 fallback|optional（cookie 透传）|implementation-specific（工具/配置，不证明每次 detail 必需）|unknown（未见）|
|Cookie|optional（空值不发送）|required 实现携带 cookie/ttwid|optional（构造接收 cookie，可为空）|implementation-specific（配置 cookie/header）|unknown（本地路线未见）|
|登录 session|unknown（未证明必需）|optional 用户配置，账号必要性 unknown|implementation-specific（登录 page_bridge）；协议必需 unknown|optional 配置/登录工具；协议必需 unknown|unknown（未证明必需）|
|msToken|unknown（reviewed detail 未见）|required 实现每次生成|implementation-specific（cookie/初始化/default query）|required model 默认初始化|unknown（未见）|
|verifyFp|unknown（reviewed detail 未见）|unknown（reviewed detail 未见）|unknown（reviewed detail default 未见）|implementation-specific（Live model，非所审 gallery detail）|unknown（未见）|
|secsdk signature|unknown（未见）|optional（UIFID 存在时）|implementation-specific（page_bridge SDK）|unknown（reviewed detail 未见；Argus 占位不是 secsdk）|unknown（未见）|

共同程度较高的是四个实现中的 Web detail、Web UA/Referer、A-Bogus 主签名或配置选项；不是五项目都同一路线，也不是成功请求的必要充分条件。Cookie 能力多处存在，账号登录必要性未消融。UIFID、ttwid、msToken、X、secsdk 都不能升格为协议共同要求。旧无签名 baseline 仅证明旧请求形态遇到 gate；本轮 W2 将证据扩展到本次最小签名形态。

关键文件：DL douyin_video_parser.py；UC src/parsers/douyin_parser.py；JJ core/api_client.py、config/default_config.py；F2 f2/apps/douyin/{model,crawler,utils}.py；JW lib 本地解析文件。更详细文件/hash 以清单为准。参考实现的固定 fallback token、随机 msToken、指纹、重试、外部 Cookie 路径没有复用。

## 4. capability 模型

ContextProvider 返回可用能力与 opaque scope/epoch，不为每条路线提前取得全部状态。Dart 契约默认要求 userAgent；UIFID 可以为空，有值才附加，只有策略明确 requiredCapabilities 包含 uifid 时拒绝缺失。研究测试由 42 增至 44 项。

Python LocalWebContext 提供真实 UA、Referer、measuredBrowserMetrics 与可选 ttwid/uifid/msToken，repr 不输出值。ResearchSigner 声明需要 UA + measuredBrowserMetrics；WebDetailStrategy 声明 UA + Referer，ttwid 默认不启用。Cookie subset/sessionState 是未来 Native Adapter 的可选能力，本轮没有实现账户材料持有/导入。query、clock、算法 entropy 属 signer 输入，不强制来自会话。

现有 Python 含私有研究输入值，不是 production opaque session API。正式实现必须留在平台 Adapter 内，不向 ParserService、领域模型、History、日志暴露凭据。Browser ContextProvider 是按需 capability，不是每次启动 H2 的前置。空白 WebView 仅读取真实运行尺寸/UA，未导航 Douyin、未观察平台内容或读取 Cookie。

## 5–7. signer 来源、许可证与实现

|来源|来源/许可证风险|本轮采用决定|
|---|---|---|
|DL abogus.py|GPLv3 来源标记，根许可证缺失/额外用途限制|Cannot copy；只参考调用边界|
|UC a_bogus.js|根 MIT，但文件商业限制/来源链冲突|Cannot copy；只参考调用边界|
|JJ signer 模块|根 MIT 不自动覆盖算法来源；缓存未完成模块来源证明|Behavioral reference only，不复制|
|F2 abogus.py|根 LICENSE 与文件头 Apache-2.0；README 有研究/学习及商业 attribution 描述|采用固定版本作研究代码复用，保留完整 license、作者、修改说明；非正式发布许可结论|
|JW 本地 Dart|没有可用本地 Web detail signer；远程后端不适合项目边界|不采用远程解析/签名服务|

**real research signer 已实现**，不是 MOCK。F2 固定 commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`；文件 `f2/utils/crypto/bytedance/abogus.py`；SHA256 `b6bcc778f8f3308411c9ce6e51af366d5468158c22bfdb6b0ee910f7057726d9`。Copyright (c) 2023 JohnserfSeed；完整 LICENSE 在 signer/vendor/LICENSE.txt，来源/变更在 [NOTICE](signer/NOTICE.md)。未发现固定 tree 内 upstream NOTICE。

这是**注明来源的改编复用，不是 clean-room**。用户的 clean-room 条件适用于没有合适来源的情形，本轮未宣称独立发明算法。移除随机 BrowserFingerprintGenerator 和示例 CLI；UA/16 项尺寸/平台从本机空白 runtime 实测取得；注入时间与 entropy；SM3 改用本地 hashlib/OpenSSL，未安装 gmssl、未复制 GPL/商业限制 signer。保留原算法及选项；上游 `[0,1,14]` 调用方言/当前平台协议正确性尚无独立证明。

Apache 的修改/分发条件要求保留 license、适用 attribution/notice 和变更说明。本轮限定 research；正式发布仍须完整来源、README 用语、运行时许可与分发审查。没有将有商业限制的实现改名搬运。没有新增 pub/npm/pip 依赖；Python/OpenSSL 和 Windows research WebView2 SDK 是现有本地工具，正式打包尚未设计。

## 8. 离线 signer 证据

- 14 项 Python unittest PASS：固定时间/entropy 可重复、timestamp/UA/query 变化、Unicode、URL encoding/roundtrip、参数顺序、空/多参数、输入拒绝、日志/repr 脱敏、可选与必需 UIFID、全局 RNG 不污染、SM3 标准向量、签名回归。
- 固定上游与改编实现对照 5 组输出一致，覆盖空/单/多/顺序/Unicode。对照通过 namespace 注入相同 clock/随机源与相同 hashlib SM3；不是独立密码实现或平台 oracle。
- offline-vector.json 是自己生成的合成回归 fixture，只保存输出 hash/length。真实 platform signature 未保存/展示。离线一致性不等于服务器接受，也未证明参数方言最适合当前接口。
- Dart 44 项 synthetic contract PASS、targeted analyze No issues；其中 MOCK 仍仅测试契约，不计作真实 signer 验证。

## 9–16. W1 / W2 与数据结果

两次目标均 `7690029886242009957`，HTTPS Web detail、direct 无 proxy、禁止 redirect/自动 retry，query 为 device_platform/aid/channel/aweme_id 加本地 A-Bogus；真实 Windows UA、note Referer、Accept。不携带 Cookie、ttwid、UIFID、msToken、X、secsdk、设备型号/CPU/内存等扩展 query。不下载媒体。

|实验|结果与证据|
|---|---|
|W1 13:34:16 UTC|已发起，消耗一次额度。OSError（响应读取器关闭 socket 后再次 settimeout）；旧版本未先保存 headers，HTTP/status/body **未知**。不能补写成 403。见 w1-result.json。|
|本地回归|单次 localhost fixture 重现 OSError 10038，证明读取器错误；增加 isclosed 检查并先记录 headers。见 reader-regression.json。|
|W2 13:36:59 UTC|已发起，唯一纠正变量组是响应读取/记录器，平台 query/header/context 策略相同；时间/算法 entropy 随请求正常变化。403、text/plain、46 bytes、ArgusSecurityPlugin Uifid Not Found。见 w2-result.json。|

W1 是本地证据损失，W2 针对已离线复现的读取错误，未追加身份材料或绕过平台拒绝。W2 明确 gate 后停止；无 W3。运行器随后加固定 W1/W2 路径与已记录拒绝保护，两次历史记录未重写。w2-result.json 的旧 errorClass 字符串 `W1-B-uifid-gate` 是分类器历史标签；experiment=W2，不能误读成第三次/W1 证据。

W2 UIFID 错误仍存在；**无明确 signature 错误，无法判断是否进入/通过 signer 校验**。业务 JSON=false，targetMatch=false，detailPresent=false，image_post_info=false，imageCount=0。没有业务 payload 或图片 URL，更没有 gallery 下载。raw body、签名、真实 Cookie/Token 未写入日志/结果；运行时尺寸/UA 属非凭据环境元数据。算法产生的签名只在内存内用于该次所属平台请求。

## 17–19. 唯一主 blocker、产品可行性、下一轮

唯一主 blocker：**当前 request strategy 的 UIFID/context gate**。不是 H2 全局先取得 UIFID，也不是 signer/license 已证明阻断。此前匿名正常 profile 有 ttwid、无 UIFID、登录未确认的 C5 保留；本轮没有再建立账号会话/采集平台存储。

Production feasibility：技术上可替换 signer + 按策略能力模型成立，真实数据路径未成立；无法给 production-ready 结论。query/msToken/cookie/TLS/客户端执行环境与参考实现的差异未完全消融，因此未满足“排除其他形态差异后恢复 UIFID 研究”的条件。不得因 W2 直接重启 bootstrap、平台观察或批量请求。签名服务端接受、当前协议方言、正式许可、双端真实场景仍有待验证。

|方案|来源、维护与隐私|Windows / Android / 当前结论|
|---|---|---|
|U1 正常 App session/context provider|App 自有隔离 profile、用户正常交互、Adapter 内受控消费/清除；不手工复制 secret。平台不暴露字段时明确 unavailable，不 hook/绕过。依赖平台行为，成本中高，但生命周期可管理。|Windows 已有正常匿名交互/清除历史证据，尚无 UIFID 正链；Android named profile 或独立 worker/suffix 路径需隔离与清理实测。较符合长期目标，尚未实现完成。|
|U2 用户授权 platform context 导入|若指 Chrome/Edge/其他 App Cookie/Token 导入，即使用户授权也与当前 AGENTS 第十/二十节外部登录态禁令冲突，本轮不实施；手工复制容易泄露、失效、失去 profile 绑定。若只指 App 自有 provider 内 opaque 引用，则实质是 U1 的消费接口。|无可批准的外部导入实现或双端实测；不得把 research 一次例外当长期生产授权。排除第三方公开 Cookie、值导出、外部浏览器读取。|

**下一轮唯一目标：当前 Web detail 策略的 context composition / U1-U2 产品边界审计**，先离线明确与固定参考分支的必要差异及可接受来源，再决定是否另立有界正常 context 实验。不是继续 signer、立即 production、重新自动找 UIFID，或扩大 endpoint。当前轮完成后暂停。

## 20–25. 文件、请求、验证、Git

修改：h2/h2_contract.dart、h2_contract_test.dart、offline-results.json、README.md；v0.4.0/README.md、research/README.md；旧 uifid-context-audit.md 与 local-session/authorized-session-result.md 仅增加当前结论指引，保留历史。

新增：本报告；signer/.gitignore、research_signer.py、research_signer_test.py、web_detail_once.py、RuntimeFacts.cs、build-runtime-facts.ps1、NOTICE.md、vendor/f2_abogus.py、vendor/LICENSE.txt、offline-vector.json、upstream-comparison.json、runtime-facts.json、reader-regression.json、w1-result.json、w2-result.json。删除源码文件：无。生成 build/cache 不属于交付源码。

请求数量：平台 detail **2**；平台首页/ttwid/bootstrap/登录请求 **0**；本地 reader fixture HTTP **1**；空白 runtime 平台导航 **0**。文档来源 web 工具为 2 次 pinned raw open（cache miss）、1 次 search 含 2 queries；底层 HTTP 数工具未暴露，不把它们写成 detail 请求。未向第三方发送链接/凭据/媒体；第三方搜索仅项目/许可证名称。没有第三方 signer 请求。

检查：Python 14 tests PASS、5 original/adapted comparisons PASS、SM3 标准向量 PASS；早先 py_compile PASS，最终重复 py_compile 因缓存写权限失败，改用四文件 in-memory compile PASS（不把缓存失败写成通过）。Dart SDK 直接执行 44 contracts PASS、targeted analyze PASS；flutter 包装的 dart.bat 未及时返回，已中断，结果以 SDK 直接调用为准。Windows research csc compile PASS，空白 runtime 实测/清理 PASS。五次失败 sandbox 空白启动生成的临时 profile，在核对精确父目录和活动进程后安全删除，remaining=0；成功实例 Native clear/退出/删除=true。没有平台 session 清理动作，因为本轮未建立平台 session。Android 未安装/覆盖/卸载/清数据。运行器再次调用已记录 W2 路径时返回“Operation already recorded; no request sent”，只验证额度保护，没有第三次请求。

完整 Flutter lint：未验证（既有 flutter_lints include 未解析）；正式 Windows/Android/iOS/macOS/Linux 构建：本轮未运行，不能用 research csc 代替 Flutter app build。现有生产能力不因本轮宣称回归通过。Python研究工具未进入正式安装包。

Git：feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；开始/结束 status 均 ` M AGENTS.md`、`?? v0.4.0/`。AGENTS 预存修改未碰；git diff --stat 仅显示 AGENTS.md 31 行、23 insertions/8 deletions，因为整个研究目录未跟踪，该 stat 不代表本轮研究代码变更量。**production 修改=否；Git 写操作=否**（无 add/commit/push/PR/merge/reset/branch 操作）。

## 26. 【项目目标兼容性检查】

|平台|状态|实际边界/风险|
|---|---|---|
|Windows|已实际测试 research signer/HTTP/空白 runtime；正式 App 构建未测|WebView2 Native 仅测环境；正常 context 正链未成，不能发布 gallery。|
|Android|理论兼容；未实测/未构建本轮 App|需要等价测量/本地 SM3/signer Adapter、隔离 context/清理/真实请求验收；不能降低验收。|
|iOS|理论兼容，未实现/实测|WKWebView/受控存储与 signer runtime 需替换/验证。|
|macOS|理论兼容，未实现/实测|WebView 与 signer 部署/生命周期待适配。|
|Linux|有平台特有风险，未实现/实测|浏览器 runtime、SM3 可用性与隔离机制未选定。|

|项目目标/模块|兼容结论与具体限制|
|---|---|
|Bilibili|生产源码未变，本轮没有解析/下载回归，不宣称实测通过。|
|Douyin|仅隔离 H2 research；真实目标数据失败，生产原能力不扩大。|
|Xiaohongshu / YouTube / X / Instagram / 未来平台|未实现新能力；可替换 signer/context 边界可借鉴，Douyin 签名/状态不能当通用协议。|
|PlatformDetector / ParserService|未修改；研究 HTTP 不通过公共服务，未来 integration 需单独契约回归。|
|Parser / Adapter / Browser Adapter|平台行为隔离在研究目录；Windows runtime 是 PoC，不成为跨端核心依赖。|
|Unified Content Model / MediaContent / MediaResource|未修改、未把凭据加入领域模型；无 payload 验证，不能宣称图文模型已兼容。|
|Downloader / Media Processing|未修改、不下载；队列/Range/.part/处理能力本轮未测试。|
|UI / History / Settings / Logging / 本地存储|生产未修改；研究结果只存元数据/hash，登录值不进入它们。未来 session 存储仍需安全设计。|
|隐私 / 本地优先 / 零服务器|签名/计算本地；必要签名只发所属 Douyin；无第三方解析/上传。真实环境元数据虽非凭据，也只保留有界研究用途。|
|依赖 / 安装包体积|无新增产品依赖；已有 research Python/OpenSSL/WebView2 使用不代表五端打包解决，未测正式体积。|
|性能 / 维护|离线算法可重复；未基准评估，平台参数/签名版本变化是实际维护风险。|
|正式发布|未就绪：无 gallery、无双端验收、服务端签名接受与正式分发许可未确认。禁止将 PoC 宣称正式完成。|
