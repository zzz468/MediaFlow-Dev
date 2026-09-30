# 当前 Web detail context composition 审计 — 2026-09-28

结论：**Production preference = U1**。当前唯一主 blocker 仍是 **Strategy M 的 context composition / UIFID gate**。没有获得本轮明确提供并完成来源核验的 U2 context，因此平台请求 **0**，不做 W3/W4、不修改 signer。

找到了 F2 的重要解释线索：无 UIFID 时也构造 detail 请求，但默认发送 `x-tt-argus` 占位头，源码作者声称它能避免同类错误。这是实现的模拟/workaround，不是可信平台签发 context。本轮不采用、不测试。另有 query/msToken/Cookie/客户端差异，**没有证明唯一关键变量，也没有证明 UIFID 的平台 session binding**。不能标为 SUCCESS C1/C2/C3 或 H2 DATA PATH VERIFIED。

## 证据范围

工作目录 D:\projects\mediaflow-v040；branch feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b。开始状态 ` M AGENTS.md`、`?? v0.4.0/`；保留预存修改。

M = 本机已保存 W2 / web_detail_once.py / research_signer.py / runtime-facts.json。
F = F2 固定 commit a30feaf92a40f421273b01b6ef36aa83a93f63c0。
D = DLWangSan 固定 commit 0896c74d1e9368af8ad0b85449a8039b1b3010bd。
辅助绑定线索 UC = ucmao 固定 commit ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6。

“当前参考实现”在这里指上轮固定源码版本，不是新联网确认远端 HEAD 或实际成功请求。7 个被使用缓存文件与[来源清单](../../douyin-gallery-horizontal-sources.json) SHA256 一致；[离线 snapshot](request-strategy-snapshot.json)记录 query 形状、固定来源/hash、冻结文件 hash。仅 ast.parse，不 import/运行参考模块，不初始化 token。

## 1–4. M / F / D 完整策略与逐字段矩阵

common = 三类源码都有的结构，不表示协议必需或取值相同；implementation-specific = 实现选择；optional = 可缺省/配置/透传；absent = 本次 M 或被审具体分支未加入；unknown = 配置/传输/服务端语义未验证。F/D 不是保存的完整线包，不把它们称作已成功的无 UIFID 请求。

|字段|M：已执行 W2|F：固定 F2 detail 分支|D：固定 DL detail 分支|
|---|---|---|---|
|method/endpoint|common：GET https://www.douyin.com/aweme/v1/web/aweme/detail/|common：POST_DETAIL 常量、fetch_post_detail GET|common：同 endpoint GET|
|query 起始|common：device_platform=webapp, aid=6383, channel=channel_pc_web|common：同三个 model 字段|common：同三个 BASE_PARAMS|
|aweme_id|common：7690029886242009957，第四项|common：PostDetail 追加末尾|common：复制 BASE_PARAMS 后追加末尾|
|query 顺序/编码|implementation-specific：保留 caller 顺序，UTF8 percent encode 一次，空格 %20；签名最后|implementation-specific：model_dump 顺序 → dict.items 原样 k=v join → a_bogus；28 字段顺序为静态声明推断，未执行 Pydantic/HTTP runtime|implementation-specific：dict 插入顺序 → urlencode（空格 +）→ escaped A；18 字段；X fallback 另建 URL|
|UA|common：实际空白 WebView2 Windows10/Win64 Chrome153/Edge153，与 signer 同值|implementation-specific：kwargs headers；缓存配置 Windows10/Win64 Chrome130/Edge130，signer 取同 header|implementation-specific：固定 Windows10/Win64 Chrome130；AB 实例默认 UA，未在该调用显式传本 parser UA，是否一致 unknown；X 显式传 UA|
|sec-ch-ua|absent|absent 显式构造；配置可加 optional|absent 显式构造|
|sec-ch-ua-platform|absent|absent 显式构造；配置可加 optional|absent 显式构造|
|Referer|common：/note/目标|implementation-specific：kwargs 配置，缓存默认首页|common/implementation-specific：根据 original_url 选择 note/video，失败分支可换 note|
|Accept|implementation-specific：application/json|unknown：缓存 Douyin config 未指定，BaseCrawler/HTTP 默认未在本次缓存确认|implementation-specific：application/json, text/plain, */*|
|Sec-Fetch-*|absent|absent 显式默认；配置可加 optional|implementation-specific：Site=same-site, Mode=cors, Dest=empty；是手工声明，不证明浏览器实际请求|
|Origin|absent|absent 显式默认；配置可加 optional|implementation-specific：https://www.douyin.com|
|Accept-Language|absent|absent 显式默认；配置可加 optional|implementation-specific：zh-CN,zh;q=0.9,en;q=0.8|
|ttwid|absent（历史匿名值已清除，不复用）|optional：传入 Cookie 可含；TokenManager 工具有生成能力，但 detail model/crawler 不保证调用该工具|optional：用户 Cookie 文件/设置透传；没有 detail 专门初始化|
|cookie_enabled|absent|implementation-specific query=true|implementation-specific query=true|
|Cookie|absent，urllib 无 cookie processor|implementation-specific：kwargs.cookie 合并为 Cookie；可能为空/None，实际 HTTP 对 None 的处理 unknown|optional：douyin_cookie.txt / set_cookie，有值才加|
|账号 session|absent|optional：配置 Cookie 可能包含，不区分匿名/登录；detail 无必须账号检查|optional：Cookie 可能包含，detail 无必须账号检查|
|msToken|absent|implementation-specific：model default_factory cached_msToken，调用 token 初始化并缓存；失败处理见下文|absent：本分支不专门加，Cookie 透传中可能 optional|
|verifyFp|absent|absent detail（只在别的 Live model）|absent detail|
|s_v_web_id|absent|optional Cookie 透传；detail model 无字段|optional Cookie 透传；BASE_PARAMS 无字段|
|UIFID query|absent|absent PostDetail model|absent BASE_PARAMS|
|uifid header|absent|optional：Cookie UIFID 优先，其次 UIFID_TEMP；或用户配置同名 header 优先|absent 独立 header；Cookie 中可能 optional|
|A-Bogus|common 主策略：本地真实 research signer，实际尺寸而非合成 fingerprint|common/implementation-specific：ab 配置启用；生成 Edge fingerprint，query/UA/body 输入|common 主尝试：ABogus；成功与否未在本轮验证|
|X-Bogus|absent|optional 配置替代 AB|optional/fallback：A 未拿到结果后调用 X|
|secsdk signature/timestamp header|absent|absent reviewed detail 默认；任意 headers 配置值 unknown|absent reviewed detail|
|x-tt-argus|absent|implementation-specific：默认占位；不是实际获得的安全状态；可配置覆盖|absent|
|browser/device query|absent 扩展尺寸/CPU/内存等 query；签名内部消费16项实测尺寸/Win32|implementation-specific：见完整 query；固定 screen/cpu/memory/network，部分来自配置|implementation-specific：固定 screen/OS/browser 等，见完整 query|
|连接/压缩/TLS|implementation-specific：urllib/SSL direct、无 retry/redirect、Accept-Encoding identity/Connection close 属实现推断；未保存线包|unknown：BaseCrawler/httpx 最终默认、Cookie jar 吸收/持续状态未核验|implementation-specific：requests.get 与库默认；具体编码/Connection/TLS 线包 unknown|

M 完整签名前 query（4）：`device_platform, aid, channel, aweme_id`。signer 附加 `a_bogus`。显式 headers 只有 `User-Agent, Accept, Referer`；Host 由 URL/HTTP 库提供。源头真实 runtime UA SHA、测量 metadata 见上一轮证据；本轮不再次打开 WebView。W2 无 account/UIFID/ttwid/msToken/X/secsdk，direct、SSL验证、零自动 retry、禁止 redirect；HTTP403/46bytes/plaintext/UIFID gate 是真实已保存结果。

F 完整 model query 声明顺序（28，签名之前）：

```text
device_platform, aid, channel, pc_client_type, publish_video_strategy_type,
pc_libra_divert, version_code, version_name, cookie_enabled,
screen_width, screen_height, browser_language, browser_platform,
browser_name, browser_version, browser_online, engine_name, engine_version,
os_name, os_version, cpu_core_num, device_memory, platform,
downlink, effective_type, round_trip_time, msToken, aweme_id
```

F model 默认：pc_client_type=1，publish_video_strategy_type=2，pc_libra_divert=Windows，版本 fallback 290100/29.1.0（配置可覆盖），cookie_enabled=true，screen1920×1080，browser/engine fallback Edge/Blink130，Win32/Windows10，cpu12/memory8，PC/downlink10/4g/rtt100。语言等由配置 getter 覆盖。它们是实现声明而非本机诚实测量，不复制。没有 verifyFp/s_v_web_id/UIFID 独立 query。

D 完整 BASE_PARAMS+target 顺序（18，签名之前）：

```text
device_platform, aid, channel, pc_client_type, version_code, version_name,
cookie_enabled, browser_language, browser_platform, browser_name,
browser_online, engine_name, os_name, os_version, platform,
screen_width, screen_height, aweme_id
```

D 固定 version190500/19.5.0，pc_client_type1，browser_language zh-CN，Win32/Edge/Blink/Windows10，PC/screen1920×1080。不同于其 HTTP Chrome130 UA 的声明，不能把这种策略当真实设备事实复制。D 的 Cookie 输入可包含 UIFID，**没有独立 uifid header 不代表没有任何 UIFID context**。

## F2 八项核查与关键局限

1. 完整 query 由 BaseRequestModel + PostDetail.aweme_id 构成；28 项见上，msToken 首次 model 实例初始化，而非 signer 自行取得。
2. DouyinCrawler.__init__ 先 GatewayHeaderManager.merge_headers(kwargs.headers, cookie)，再并 Cookie header；fetch_post_detail 使用同 UA 生成 signed endpoint，再 _fetch_get_json。缓存 conf 默认只声明 UA/首页 Referer；调用方任意自定义 headers 优先，最终 BaseCrawler wire defaults 未完整获取，不虚构完整线包。
3. Cookie 来自 kwargs.cookie，配置/调用方负责供给，未证明来源属于 App 自有 profile。TokenManager.cached_msToken 首次调用 gen_real_msToken，失败会抛出且不缓存，未见此路径自动调用随机 fallback。另有独立 gen_false_msToken 工具，不能把它当 detail 已使用的路径；两者均未执行/复用。
4. gateway 从 Cookie UIFID / UIFID_TEMP 读取；非空才加 uifid。配置同名头（大小写不敏感）可覆盖。
5. 没有 UIFID 的时候，没有 gateway 本地阻止 detail 的检查，仍可继续构造/尝试请求；空 Cookie 值被下层接受与否/线上成功是不同问题，未实测。
6. 此时仍默认添加 x-tt-argus 占位；不是证明它与正常 UIFID 等价。可能其他配置 Cookie/headers 已存在，不能把 F2 整体写成匿名无 context 成功。
7. 没有本分支默认 secsdk signature；x-tt-argus 不是 secsdk 或 A-Bogus 的别名。
8. GatewayHeaderManager 的注释声称该占位能避免 Argus UIFID 错误，并描述将来验证值可能失效。**这是源码作者声称的 workaround，非本轮独立证据**；不复制占位/不调用它绕过当前明确安全拒绝，也不从外部浏览器复制覆盖值。

可追溯位置：F2 utils.py 611–688（gateway）、753起（AB manager）、model.py 12–39 /216（model）、crawler.py 100–118 /221（构造/detail）、api.py POST_DETAIL、conf.yaml Douyin headers；DL parser.py 26–44 /149–162 /174–230。具体固定 URL/hash 在 snapshot.sources 中。

## 5–6. 为什么 M 遇到 gate；绑定证据到哪一步

**已证明**：M 在当前网络/时间/目标/真实UA+本地签名形态，被 Argus 返回 UIFID Not Found。错误可定位到 context gate；服务器内部路由触发器没有公开在该响应中。

**最具体的候选解释**：M 没有任何正常 gateway/context 材料，F2 却用 gateway 占位处理同名错误；D 多18字段/Header/Cookie/不同签名调用。候选间没有有界消融因果实验，不能断言“因为缺 cookie_enabled/msToken/Fetch 或占位所以进入”，也不能断言“只加 UIFID 就能工作”。不为满足 C2 伪造唯一原因。

绑定证据分层：

|绑定候选|实际证据|可得结论|
|---|---|---|
|UIFID ↔ Cookie|F2 把 Cookie UIFID/TEMP 映射至 uifid header|证明实现的来源/组合，不证明平台密码绑定或必须同 jar|
|UIFID ↔ timestamp/query/secsdk|UC _sign_secsdk 代码组合 uifid/timestamp/canonical query|证明 UC 所用函数有输入依赖，不证明当前 M endpoint 必需该函数或服务器验证这种绑定|
|signer ↔ UA/query/时间/尺寸|本机算法测试及输入链|属于 signer binding；不能移植成 UIFID binding 结论|
|UIFID ↔ UA/ttwid/profile/account|F2 注释描述 fingerprint；历史自有 profile 有 ttwid 无 UIFID|相关性/作者说法，不是受控服务器验证；依赖未知|

因此 UIFID 的**服务端独立值或组合绑定仍 unknown**，没有达到 C3。“来源必须 App 自有、profile有归属/epoch、UA一致、可撤销/清除”是我们设计的可信性要求，不能冒充平台已证明的密码学要求。

## 7–8. U1/U2 正式比较与产品选择

|维度|U1 App-owned normal context|U2 authorized imported context（research）|
|---|---|---|
|来源/信任|自有全新隔离 profile 正常交互；来源、scope、UA、epoch 可在 Adapter 内确认|测试人提供最小本人的状态；须确认来源/账号/时间/scope/UA，无公开或他人 Cookie|
|生命周期|退出/clear、过期、challenge 后撤销；refresh 仅正常授权行为|expiry/profile关联不透明；内存或短期 repo 外安全输入，用完销毁，不能自动刷新|
|体验/维护|不手工复制；需要双端隔离 Adapter；平台不暴露时 unavailable|复制易错/过期/泄露；非默认产品流程，无法保证来源绑定|
|当前证据|历史用户正常交互只得到匿名 ttwid；UIFID absent，登录未确认；不是证明 U1 不可能|本轮没有可使用材料，也没有一次成功 transport 验证|
|严格变量|同 profile 内实际UA/状态可保持一致|若来源UA与W2不同，单加值不等于同一可信绑定；不得修改UA/query/signer来掩盖不匹配|
|production|优先；仍须真实取得/消费/清除验收|不推荐；只作有来源证明的隔离研究输入|

**Production preference = U1**，理由是来源、生命周期和隐私可管理，不是因为已经证明 UIFID 必须与 profile 绑定。没有 U1 正链成功，保留 unavailable/error，不要求用户反复登录碰概率。

项目规则边界：AGENTS 第十/二十节禁止导入/导出外部 Chrome/Edge/其他 App 登录态；本轮附件允许主动最小输入作研究，但没有明确修改该长期规则。因此不读取外部浏览器、不教用户复制登录凭据。App 自有正常平台 context、无凭据聊天/文档/JSON/log、repo 外受控输入是可继续评估的来源；若拟用外部浏览器来源，应先明确解决规则冲突，而非按隐含 research 例外实施。本轮无 U2 值可用，未因此留下可执行操作。

## capability provider 正式设计（本轮文档设计，未生产实现）

Provider.describeCapabilities() 返回 available/absent/expired/challenged/unknown 与非敏感 metadata；可选 userAgent/referer/ttwid/uifid/cookieSubset/sessionMetadata/normalGatewayContext。normalGatewayContext 只能是正常取得状态，不是占位模拟。UIFID 永远按策略条件声明，不在初始化时全局强制。

Client/Signer.requiredCapabilities 分别声明；Application 只协调 intent、错误和 opaque handle。Provider.acquire(requirements, purpose) 返回 owner/profileId/epoch/lease 的不可伪造引用；Adapter executor 内检查来源douyin.com、path/expiry/实际UA、normal session来源与最小权限，再在同 profile scope 消费所需材料。cookieSubset 是明确 allowlist/domain/path 的内部值，未知必要字段不自动扩展。Parser不读Cookie jar，UI/日志不见值，不提供 exportAllCookies。

clear 先提升 epoch/cancel/revoke，再清所属profile并核对消失与退出；profile重启保持性是需实测metadata，不预设。refresh 受用户授权与平台正常行为限制，安全拒绝后不能后台重试。现有 Dart 的 opaque owner/epoch/capability 是离线契约基底，不等于 Native provider 已实现；Python研究输入不是正式公共接口。本轮不修改 signer、HTTP runner 或生产 API。

## 9–17. 实验状态、缺失证据与下一轮

本轮询问测试人员是否有授权 context，未获得明确位置/来源及可验证材料。**U2 available=false，single-variable experiment=false，platformRequests=0**。没有搜索磁盘 secret、读取/打印 env 值、创建秘密JSON或索要聊天真实值。旧 W2 403/UIFID 错误保留；本轮没有新响应，故 gate 是否消失=未验证、signer next blocker=未证明、business JSON/aweme_detail/gallery=均未取得，不下载图片。

单变量实验准入定义（尚未执行/没有新增运行器）：只允许已验证本人正常 App context、scope/时间/实际UA与固定M一致；增加明确最小 UIFID/context 一个变量组，不合成身份/不导入全jar/不带未证需要状态。query四项、endpoint、UA、signer算法保持；自然时间/签名entropy仍刷新，不重放历史签名或challenge token。请求数1，无retry，任一明确安全拒绝停止，结果只metadata/error分类。

尚缺的**唯一关键证据**：在保持 M 策略的情况下，可信正常来源 context 是否使 UIFID gate 消失；如果失败，再根据新响应区分映射/绑定，不能先认定 token独立。源码差异很多，静态比较不能代替这个实验。

当前唯一 blocker：M context composition / UIFID gate；不另列 signer、endpoint、payload 为已证明 blocker。下一轮唯一目标：**可信 context 准入与一次固定 M context 消融验证**；没有合法来源输入则保持暂停，不启动普通 W3/W4、bootstrap、登录自动化、其他 endpoint、Mobile Feed/Browser Observation。

## 18–23. 文件、验证和 Git

新增：context-composition-audit.md、request_strategy_snapshot.py、request-strategy-snapshot.json。
修改：三个当前索引 v0.4.0/README.md、research/README.md、h2/README.md 增加本轮指引。删除：无。
设计参考 F2/DL/UC 调用/context 边界；本轮第三方代码复用=无，只静态解析公开缓存。F2 Apache-2.0；DL 无清晰根 LICENSE/其 signer GPL风险；UC根MIT而 signer限制风险。没有复制其签名/placeholder/context代码，无新增依赖，不改变上轮 NOTICE。

平台网络请求0；第三方网络请求0；本地HTTP0；没有打开WebView/profile、Android安装/覆盖/卸载/清数据。没有新的真实场景成功验证。新增工具的 AST/hash/集合断言通过：7源hash一致，F28/D18字段，与M起始三项相同，F有msToken，F/D无verifyFp/uifid query。冻结六文件最终hash与snapshot一致（两signer/runner/W1/W2/Dart契约）。本轮无需重复算法/合同测试，它们上轮结果14/44通过，不计作本轮再测。新Python源码 in-memory compile 与snapshot JSON解析/字段检查通过；纯文档/离线提取改动未跑Flutter analyze/full lint/五端正式build，不声称通过。未增加不必要算法测试。

结束 branch/HEAD 不变，status ` M AGENTS.md`、`?? v0.4.0/`。git diff --stat 为预存 AGENTS.md 31行（23 insertions/8 deletions）；新研究目录未跟踪，stat不含本轮新增文件。AGENTS未改、production未改、Git写操作无；无add/commit/push/merge/PR/reset。完成后暂停。

## 24. 【项目目标兼容性检查】

|平台|本轮状态与限制|
|---|---|
|Windows|已实际执行离线源码提取/完整性检查；正常context/HTTP本轮未实测、正式build未跑；已有U1匿名清理证据不能等同UIFID正链。|
|Android|理论兼容设计；未构建/实测；需要named profile或独立worker/suffix、受控消费与清理，不能降低核心发布验收。|
|iOS / macOS|理论兼容，未实现/构建/实测；WKWebView隔离store与生命周期、cookie属性能力需验证。|
|Linux|有平台特有风险，未实现/构建/实测；browser runtime隔离与metadata能力未选定。|

|项目目标/模块|具体检查结论|
|---|---|
|Bilibili / Douyin|production未动；Bilibili未回归，Douyin本轮只解释context差异，无业务数据成功。|
|Xiaohongshu / YouTube / X / Instagram / 未来平台|未增加解析能力；provider接口可推广，Douyin gateway字段不可放公共协议。|
|PlatformDetector / ParserService / Parser / Adapter|源码未改；边界继续由平台Adapter承接，Native实现尚待验收，不以文档设计替代功能。|
|Unified Content Model / MediaContent / MediaResource|未改变单/多资源语义，不携带凭据；gallery映射未验证。|
|Downloader / Media Processing|源码未改、不下载；队列/暂停/Range/.part/处理链未回归。|
|Browser Adapter / UI|ContextProvider按需启动，UI仅意图/metadata；自有profile登录可行性仍待证，未新增UI流程。|
|History / Settings / Logging / 本地存储|未改；研究文件没有真实Cookie/Token值，未来session存储/清除仍需独立验证。|
|隐私 / 本地优先 / 零服务器|静态离线分析，没有上传链接/凭据/媒体，不引入云签名/解析服务；外部浏览器导入边界不放宽。|
|第三方依赖 / 安装包体积|无新增依赖/产品打包变化；正式尺寸和各端运行时未测。|
|性能 / 后续维护|工具读取有限缓存，未做性能基准；平台gateway变化和正常状态可获得性是实际维护风险，占位workaround不作正式基础。|
|正式发布|不就绪；没有C1/C2/C3证明/数据路径/双端真实验收，禁止将审计写成平台已恢复。|
