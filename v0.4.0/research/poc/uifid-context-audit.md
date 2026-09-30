# UIFID 请求上下文根因与技术边界定版（2026-09-27）

> 后续修正见 [2026-09-28 capability / signer 报告](h2/capability-signer-audit.md)：UIFID 只作为 conditional context；旧 baseline 仅证明特定请求遇到 gate。本轮真实 signer W2 也遇到 gate，但没有排除所有其他形态差异，不能恢复 UIFID bootstrap 或把其写成全局固定前置。以下保留历史证据。

## 修改总规则前的差异记录

本轮产品所有者明确指定“方便使用 + 本地处理 + 可维护”，允许本地signer、必要客户端参数、匿名优先和用户主动登录后的App自有本地session fallback。AGENTS.md开头允许所有者明确修改规则；当前没有禁止编辑总指令的条款。因此本轮直接落实这些明确调整，不推断Git提交/生产实现/登录实验授权。使用既已读取的i-have-adhd Skill组织输出。

|旧条款|冲突|本轮精确调整|
|---|---|---|
|一：不把用户账号登录作为正常使用前提|可能被解释成禁止任何登录fallback|保留匿名优先；平台确有要求时可提供用户主动授权的登录fallback|
|十：禁止读取账号登录信息/注入登录Cookie|绝对禁令阻止App自己登录后的会话使用|禁止未授权读取、外部浏览器导入、手工导出/注入凭据；允许App自有隔离profile内部受控使用平台签发session|
|十：遇登录要求一律停止|缺少正常登录入口边界|停止当前解析，给出登录选择；用户授权后走平台正常登录，不自动操作账号或求解挑战|
|五：Cookie通过公共资源元数据传递|与MediaResource禁止凭据及新session隔离目标冲突|公开headers/文件建议仍传模型；敏感身份只在Adapter内部，通过不含凭据的上下文引用执行|
|一/十一：Cookie不上传|如果字面涵盖Cookie正常发送所属平台，则本地会话不能工作|明确不向第三方传输；受控请求可向所属平台发送必要会话材料，不含第三方解析服务|
|十五：匿名HTTP/Browser路线描述|被当成唯一路线|本地请求上下文+signer优先；正常App登录是条件fallback，Browser Observation本轮仍非主路线|
|二十：不导入用户浏览器登录态|与App自有profile容易混淆|保留外部浏览器导入禁令；明确App内部授权session不等同导入其他App登录态|

保留不绕过付费/地区/权限/平台安全验证，不MITM、不系统代理、不高频重试、不伪造设备特征、不记录/上传凭据、不商业解析服务、五端Adapter和Git禁写规则。正常协议签名与状态初始化不是全面禁止项；收到明确挑战/限制停止，不把泛化403自动诊断为缺某签名，也不把规则调整当作网关已可通过的证据。

## 实验前矩阵与唯一实验选择

当前baseline日志只证明403/46bytes/Argus UIFID missing，没有任何UIFID输入。正式DouyinDetailSession已存在首页bootstrap，Cookie白名单仅ttwid/msToken/__ac_nonce，不捕获UIFID，也不映射uifid header/query；所以“MediaFlow完全没有初始化”是不准确的。

|条件|当前已有|参考实现实际做法|与403相关证据|本轮是否测试|
|---|---|---|---|---|
|aweme_id|baseline有已准入目标|三项目都有|没有作品后端响应，不能归为ID错误|不重复|
|UA|baseline Chrome130；正式session研究UA|DL Chrome130、uc Chrome123、jiji固定池Chrome139|UA绑定signer，但无UA导致UIFID错误的单变量证据|固定baseline UA|
|Referer|baseline note，正式session video|uc note含previous_page，DL按输入|未证明此字段产生UIFID|不改detail|
|Cookie jar|baseline无；正式session有限内存Cookie|uc requests Session，DL从文件读，jiji传入cookies|持有Cookie不等于带有有效UIFID|只检查正常首页响应|
|ttwid|baseline无；正式白名单有|uc独立register/cache；jijiCookie|与UIFID不同字段，无充分因果证据|不注册、不随机补|
|webid|baseline无|uc成员固定值，本次detail不使用|不能证明是UIFID来源|不测|
|msToken|baseline无；正式只用平台返回|uc随机107字节，jiji签发/随机fallback|独立生成/存储，非UIFID别名证据|不生成|
|verifyFp/fp|baseline无|已有项目保留s_v_web_id上下文的线索|同源绑定强度未由MediaFlow验证|不伪造、不测|
|A-Bogus|baseline无|DL/uc/jiji签query|uc发送前_get_uifid独立执行，不能视为UIFID生成器|不写signer、不测|
|X-Bogus|baseline无|DL/jiji fallback；uc detail不调用|不能证明解决本次UIFID错误|不测|
|用户登录session|无，未读取设备账号态|DL GUI登录Cookie；uc条件用户Cookie；jiji正常登录收集|参考流程有登录，不证明匿名一定失败|不登录|
|UIFID/uifid|baseline无；正式白名单拒收|uc配置/Cookie/jar→header，另query；jijiSDK bridge注释|本机403+源码链强关联；平台生成/有效性仍未知|检查首页Set-Cookie是否自然出现UIFID/临时字段|
|x-secsdk-web-signature / timestamp|无|uc额外计算，jiji描述页面SDK补全|第三方称下一层Signature Not Found；本机未验证|不加、不测|
|odin_tt/passport|baseline无|参考登录Cookie集合|不能因共存证明UIFID依赖账号|不收集账号值|
|sec-ch / sec-fetch|baseline无|uc有固定浏览器headers|未证明它们本身足够初始化UIFID|不扩展headers|

唯一实验预案：新建无Cookie HTTP客户端，固定baseline UA，仅GET https://www.douyin.com/ 一次；不运行JS、不跟redirect、不登录、不签名、不请求detail/图片，内存检查响应状态与已知Cookie字段存在性。仅保存字段名的布尔值和安全分类，无Cookie值/长度/完整响应。用途是判定“纯HTTP初始化是否已自然提供候选UIFID”，不能证明UIFID有效或平台必须登录。如果没有UIFID或有挑战，当场结束，不加ttwid/msToken/身份材料尝试。

此预案先于网络实验写入；当前未证明匿名bootstrap已足够，因此不预设 `initialization→detail` 一定可执行。不重新开启Browser Observation。

## 结果与证据等级

**RESULT A — 请求侧UIFID来源已定位，范围限定为已有客户端上下文的传递链。** 最可信根因：baseline没有平台UIFID上下文，Argus报告缺失；源码显示其来自已有Web Cookie/session或页面SDK上下文，再作为uifid header/query使用，不是A-Bogus本身生成的输出。平台如何首次签发/生成UIFID、是否绑定账号/运行时/出口环境，尚未完全定位，不宣称已掌握生成协议。

E1 本机真实证据：上轮detail403/46bytes/ArgusUifidMissing；本轮干净HTTP首页200/72914bytes，Set-Cookie字段2，已知名字仅__ac_nonce=true，UIFID/UIFID_TEMP/ttwid/webid/msToken/s_v_web_id/odin_tt/sessionid/sessionid_ss/passport_csrf_token均false；knownSecurityMarker=true。UTC2026-09-27T14:56:17.502528Z。检测器命中现有WAF/nonce脚本等安全标记集合，不推断确切挑战类型，不执行其JS。日志只存布尔值，不保存任何Cookie值/正文；没有detail第二次请求。证据文件anonymous-context-metadata-result.jsonl。此200不等于正常解析环境初始化完成；不能把__ac_nonce自动认定为UIFID前身。

E2 固定提交源码：uc从DOUYIN_UIFID/DY_UIFID、自配Cookie UIFID、纯字符串配置或session.cookies提取字段，header独立注入；额外query加uifid/timestamp/x-secsdk-web-signature。jiji默认query中uifid为空，desktop page_bridge注释称由页面SDK补uifid/timestamp/Web签名；CLI无bridge。DL parser无UIFID生成器，GUI正常登录后把context cookies作为parser输入。MediaFlow正式白名单丢弃UIFID为静态事实，但没有“收到UIFID又丢掉导致本次403”的实测证据：本次baseline根本没bootstrap，本轮首页也没收到它。

E3 维护者说明：uc issue15称UIFID来自真实浏览器环境；uc技术文档称header可改变错误层、额外Web签名用于下一层校验，且特定部署/LivePhoto流程要求完整登录Cookie。jiji API注释区分Argus确定性拒绝与一般限流，记载UIFID后可能仍Signature Not Found。均是第三方报告，不等同MediaFlow单变量实测。uc“100%/150次”没有本项目目标与同环境证据，不计成功验收。

E0 未证实：UIFID生成端点/算法、匿名是否可得有效值、是否必须账户登录、UA/Referer或IP的因果影响、A/X是否下一真实阻断、当前目标detail能否复现。故不选B（未证明匿名初始化足够）、C（context未解决）、D（未证明登录必需）或E（没有完整当前参考链失败实测）。RESULT A不表示端到端根因全部解决。

## UIFID各载体与参数关系

|项目|已知关系|证据限制|
|---|---|---|
|Cookie|uc读取UIFID；jiji登录工具保留UIFID/UIFID_TEMP|不是所有Cookie都UIFID；本轮HTTP未签发这两字段|
|Header|uc发送独立uifid header|平台接受哪种载体组合未单独实测|
|Query|uc附加uifid，jiji默认空，页面SDK补齐为注释事实|不能只随便填字符串；为空不是有效初始化|
|Browser/Web session|已有上下文被读取或SDK使用；维护者称浏览器产生|未发现公开可验证的匿名UIFID首次生成实现，不把browser-derived认定为必然登录态|
|风控客户端标识|Argus错误及SDK上下文线索支持属于客户端安全上下文|不是仅凭“UIFID”名称扩展其语义，账号/设备绑定细节未知|
|A-Bogus|uc signer签query/UA，UIFID单独读取；uc把A加完才附UIFID/Web签名|可作为签名输入的一部分不等于A生成UIFID，也未证明与A完全无绑定|
|X-Bogus|独立fallback，未见生成UIFID的调用|不证明X能替代上下文|
|msToken|uc随机生成；jijiCookie优先再mssdk获取/随机fallback|与UIFID独立管理，无等价或必然派生证据|
|verifyFp/fp|s_v_web_id相关线索存在；uc对来源Cookie有筛选|本轮未验证同源绑定，不复用随机fingerprint|
|ttwid|uc单独POST register并缓存|没有证据从ttwid直接推导UIFID，文档“必须ttwid”未单独证实|
|webid|uc固定成员，但note detail query本次未用|不能当作缺失UIFID替代物|
|odin_tt|登录Cookie集合共存，uc可保留|未证明是UIFID派生输入或账号认证的充分条件|
|passport/session cookies|参考登录流程正常取得并共存|共存不证明UIFID只能登录取得；不因账号Cookie名字出现就启用登录|
|UA|signer输入和请求UA须一致；参考固定标识|没有本轮实验说明UA变化解决UIFID层|
|Referer/sec-ch/sec-fetch|请求环境headers，参考均有使用|未证明能够生成UIFID|
|Web签名/timestamp|uc另加x-secsdk-web-signature；jiji称页面SDK附加|与A/X不同命名和调用层；不存在本轮“下一层已解决”结论|

## 调用signer之前的完整链

DLWangSan：clean parser构造→读取douyin_cookie.txt（可能为空）→固定Chrome130→ABogus/XBogus构造→从分享长链/短链提ID→固定BASE_PARAMS→note/video Referer与浏览器headers→对query签A→requests.get发送Cookie（有则发送）→失败X fallback→status_code0且非空detail。短链使用独立requests.Session，没有看到该session jar转给detail请求；直接ID路径没有隐藏bootstrap。完整版GUI另有Playwright自有context→homepage GET→用户扫码正常登录→sessionid存在判定→context.cookies导出/保存→parser读文件。GUI还隐藏webdriver特征，MediaFlow不采用此行为；登录Cookie导出文件也不采用。不能把“构造参数Cookie可选”理解成当前匿名成功证明。

ucmao：BaseParser创建requests.Session→构造MiniRacer signer/fixedChrome123→预生成随机msToken及读取用户Cookie→解析note ID→图文detail优先（没有先fetch_html_content）→_get_ttwid cache或独立register POST（有固定fallback）→合并自配Cookie及Session部分Cookie→_get_uifid→固定headers+Referer+Cookie/可选uifid→query加新msToken→A签名→有UIFID则附Web签名→同Session GET→验证detail→失败限次重试/SSR。若初始用户Cookie无UIFID、jar也无，_get_uifid返回空；ttwid注册不是UIFID初始化器。分享SSR fetch_html_content是fallback，也使用同样ttwid/Cookie/uifid上下文。配置/会话初始化在A之前，某些Webquery签名在A之后；不能简化成ID→A→detail。

jiji：工具提供clean Playwright context→用户正常登录→storage_state提Cookie（可含UIFID/临时字段）→传入APIClient→sanitize+Cookie jar→UA固定池→已有msToken优先；否则mssdk POST并读取Set-Cookie，失败随机fallback，配置可能从远程F2加载→固定query包括空uifid→无page_bridge的CLI用A（随机browser fingerprint）/X直连；desktop注释指另一页面SDK通道补上下文。当前公开树未找到core/page_bridge.py与docs/spec/common-mistakes.md，两个raw404；故desktop的完整SDK初始化链NOT VERIFIED，不能把注释当已审计源码。其CLI README仍明示单条图文受验证阻断。MediaFlow不采用随机特征、远程参数配置、导出Cookie/账号态文件或反复安全重试。

以上未运行第三方程序。uc测试是mocked输入/请求，不是首次生成UIFID或目标作品实时成功证据。技术文档存在自述与源码不一致（如query排序描述与实际函数的顺序、ttwid缓存清除时机），以后以源码为准，不直接复刻文档算法。

## 来源和许可证 / clean-room定位

固定提交与前轮相同：DL0896c74d1e9368af8ad0b85449a8039b1b3010bd，ucbf961fb30bbd13ba9d04d16466eb8a851932297b，jiji9874f413b2c1f8ad6e731b26e3e05f402fc964f8。本轮新增文件都按上述SHA取；uc issue15为2026-09-27读取、updated_at2026-09-20（内容可修改，不是固定提交）。

主来源：[uc源码](https://github.com/ucmao/media-parser/blob/bf961fb30bbd13ba9d04d16466eb8a851932297b/src/parsers/douyin_parser.py)、[uc指南](https://github.com/ucmao/media-parser/blob/bf961fb30bbd13ba9d04d16466eb8a851932297b/docs/parsers/douyin.md)、[维护者issue15](https://github.com/ucmao/media-parser/issues/15)、[uc BaseParser](https://github.com/ucmao/media-parser/blob/bf961fb30bbd13ba9d04d16466eb8a851932297b/src/parsers/base_parser.py)、[uc mock测试](https://github.com/ucmao/media-parser/blob/bf961fb30bbd13ba9d04d16466eb8a851932297b/tests/test_douyin_parser.py)、[jiji API](https://github.com/jiji262/douyin-downloader/blob/9874f413b2c1f8ad6e731b26e3e05f402fc964f8/core/api_client.py)、[jiji cookie工具](https://github.com/jiji262/douyin-downloader/blob/9874f413b2c1f8ad6e731b26e3e05f402fc964f8/tools/cookie_fetcher.py)、[jiji msToken](https://github.com/jiji262/douyin-downloader/blob/9874f413b2c1f8ad6e731b26e3e05f402fc964f8/auth/ms_token_manager.py)、[DL GUI](https://github.com/DLWangSan/douyin_parse/blob/0896c74d1e9368af8ad0b85449a8039b1b3010bd/qt_app.py)。

DL根README MIT但abogus.py声明GPLv3上游；uc根MIT但a_bogus.js有商业限制；jiji根MIT不自动证明全部signer谱系合法。允许参考输入输出/编码/流程/公开行为；本轮不复制任何signer代码，不新增依赖或attribution。具体风险是文件许可与仓库许可不一致，不概括成“GPL一律不能研究”。依照本轮明确要求，不把GPL/受限实现引入production。

clean-room后续方案：先建立不含实现常量/表/代码结构的行为规范与合法测试向量及来源账本；独立实现方只收到此规范，单独实现；再由研究方做黑盒一致性验证。当前agent此前已读过受限实现，不能把自己直接按记忆改写或变量改名称为严格clean-room。若未来需真实隔离，应另行明确授权独立实现流程，本轮不启动agent/新chat。先确认有效context、endpoint及下一层真实阻断再投资signer；目前全部前置条件尚未满足。

## 下一步与session工程定位

下一轮唯一目标：**平台正常生成UIFID上下文的来源与生命周期设计**，先解决可信状态来源；本轮不自动进行下轮网络。下一网络实验候选只能是“正常匿名初始化是否自然得到有效UIFID上下文”，其前置是公开确认安全运行路径、初始化方式和停止条件。现有纯HTTP首页已测且安全停止，不重复、不追加detail；不预设A-Bogus实验。若只能浏览器运行取得，先审计自有Adapter的正常初始化与范围，不恢复Browser Observation媒体采集主路线；无法保证不求解挑战时不执行。没有证据支持直接账号session实验。

session为条件架构：匿名Adapter优先；平台明确login-required且用户选择登录才启动App自有平台profile；已登录不代表无验证限制。共享Application仅持context opaque handle/状态（anonymous/needsLogin/ready/expired/blocked/clearing），平台Adapter内部保留敏感状态及发请求能力；MediaContent/MediaResource只接公开作品资源。首次主动登录后会话在有效期内自动受控复用，不承诺永不再登录；失效提示重新登录。清除须取消在途请求、隔离profile和系统安全存储删除确认，失败报错不得假称清空。日志/History/Crash只白名单事件，不记录Cookie/token/uifid/签名值/包含凭据的URL。

Windows WebView2独立profile，Android专有WebView数据目录/适配能力须独立验证（CookieManager全局共享风险不能忽略）；iOS/macOS WKWebsiteDataStore隔离生命周期；Linux替换Browser runtime/profile并验证清除。通过Adapter复用业务状态机，不能把原生Cookie对象或账号态传到公共模型。无需手工Cookie导入；不读取已有正式App数据，本轮未安装APK。正常登录组件不是Browser Observation媒体观察器；其路线是否适用需下一轮评审。

## 变更、检查和兼容性

production feasibility仍BLOCKED；未取得目标detail/images/URL，未修改lib/Downloader/History/UI或生产配置，无图片下载。Browser **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**，没有新导航/采集/扩展。

本轮新增4文件：本报告、anonymous_context_metadata.dart、anonymous_context_metadata_test.dart、anonymous-context-metadata-result.jsonl。修改4文件：根AGENTS.md、v0.4.0/research/execution-rules.md、v0.4.0/research/README.md、v0.4.0/README.md。删除0；全是规则、研究和元数据探针，原研究全部保留。没有第三方代码复用，无新增依赖，正式包体未改变。

网络：Douyin首页GET1次；detail0、signer0、登录0、Browser0、媒体0、业务重试0。GitHub直接请求10次（8个raw含2个404、tree1、issue1），另web工具2个search查询/2个固定源码open；其内部抓取数不可见。无解析服务、代理/MITM，无凭据上传或落盘。源码只读临时目录，不vendor。

Dart format完成，提示root flutter_lints include无法解析；新两个脚本dart analyze No issues found。离线隐私测试PASS，覆盖字段白名单、Expires逗号、不输出value、空输入不生成状态。未运行Flutter全量analyze/test、APK lint、Windows/Android build、iOS/macOS/Linux build、GUI/图片真实验收；文档/规则不冒称构建或功能通过。git diff --check通过，最终tracked diff --stat与status在终端核对。

【项目目标兼容性检查】Windows独立HTTP元数据实验已实际测试，完整context/解析仍失败；Android仅共享Dart理论可行，本轮未构建未实测；iOS/macOS/Linux纯HTTP理论兼容，session需独立Adapter和真实清除验证。Bilibili、Douyin现有视频未改但未回归；小红书/YouTube/X/Instagram/其他未来平台未新增支持。PlatformDetector、正式Parser/Adapter/ParserService、Unified Content Model/MediaContent/MediaResource、Downloader及恢复队列、Media Processing、UI、History、Settings、Logging/本地存储代码未改；账号上下文设计必须保持不泄漏公共领域。Browser研究保留但不作为主路线。隐私/本地/零服务器保留，正常平台会话使用界限更明确；无新依赖/包体变化，性能未基准；主要维护风险为UIFID生命周期/SDK变化、license、上下文绑定及Android共享Cookie状态。没有具备正式发布证据。

Git：cwd/top-level D:\projects\mediaflow-v040，branch feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；本轮修改AGENTS.md，v0.4.0仍未跟踪；没有commit/push/merge/tag/PR或其他Git写操作。完成后暂停。

最终tracked git diff --stat：AGENTS.md | 31，1 file changed, 23 insertions(+), 8 deletions(-)。git status --short：M AGENTS.md；?? v0.4.0/。未跟踪目录内的研究变更不计入此stat，不能忽略上述新增/修改清单。
