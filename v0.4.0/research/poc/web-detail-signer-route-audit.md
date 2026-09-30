# Web detail 主路线切换与 signer 复现审计（2026-09-27）

本轮使用 i-have-adhd 表达 Skill；根目录 AGENTS.md 优先。研究方向正式改为 **Web detail + 本地 signer**；尚未证明匿名成功，production feasibility = BLOCKED。Browser Observation = **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**；不扩展、不导航、不删研究代码。此记录取代此前“下一轮确认降级范围”的建议，不改变历史实测结果。

## 结论及 A–D 证据门槛

Experiment A 已执行：目标 7690029886242009957，GET detail，匿名无签名；实际 403/46 bytes，明确 ArgusSecurityPlugin Uifid Not Found。没有 aweme_detail、images、图片 URL。Experiment B/C = NOT TESTED：遇明确安全网关后按 AGENTS.md 安全停止，不以签名/身份材料继续探测网关。Cookie 必需性 = NOT VERIFIED；没有 session 实验。没有图片正文 GET。

**不能如实归入附件四种完整结果。** A 没有成功；B 未证明正确 signer 或 session 唯一必要；C 未证明当前成功链存在，更未证明 signer 是唯一阻断；D 未运行完整参考签名链，因此只证实 baseline 不能复现，不能宣称参考完整路线失效。当前结果是“安全停止、完整复现未完成”，不是旧收口文档的结果 C。若必须沿用四类，需调整其证据定义；不填入不成立的事实。

下一轮唯一目标建议：**以不继续探测已阻断入口的离线方式，审计可合法独立实现的 signer 协议、UA 绑定和编码测试向量**。先解决文件级许可/来源与固定指纹问题，不回 Browser、不进入 production。若产品希望允许安全网关拒绝后的有限签名对照，需要项目所有者明确修订相关边界；本轮没有修改 AGENTS.md。

## 研究临时限制与真实项目边界

AGENTS.md 第十、十五、二十节允许研究本地请求参数、签名与协议兼容；没有 A-Bogus / X-Bogus 全面禁令。旧研究文档中“签名全部排除”的措辞仅为当轮范围，不适用于本轮候选审计。本地 signer 不自动等于挑战求解，必须按实际用途评估。

真实约束仍包括：禁止读取平台账号登录信息、注入登录 Cookie、导入浏览器登录态、伪造设备指纹规避风控、主动求解挑战、绕过访问控制、高频重试；遇额外安全验证安全停止。禁止第三方解析服务、凭据上传、MITM、系统代理抓用户流量、日志/History记录凭据；本轮只直连 Douyin 和读取 GitHub 源码。

附件“任何 A 失败都继续 B”与本次明确 Argus 安全拒绝后的停止规则冲突。附件 session fallback 与第十节“读取用户平台账号登录信息 / 注入登录 Cookie”冲突。均未实施冲突部分。建议供所有者评审的规则文字：区分普通请求签名兼容与挑战求解；如允许 App 自有 WebView 用户主动登录，仅让独立 Adapter 内部受控使用 session，不导出/注入 Cookie、不读其他浏览器、不默认依赖账号、可清除、遇挑战停止。此为建议，尚未获准、不代表本轮功能方案已可执行。

## 来源、当前提交、许可证

访问 GitHub 当前源码及 API；第三方源码只留在系统临时目录 mediaflow-v040-reference-audit，不 vendor、不执行、不复制算法。

|项目|本轮查询最新提交 / UTC|许可与维护证据|
|---|---|---|
|[DLWangSan/douyin_parse](https://github.com/DLWangSan/douyin_parse)|0896c74d1e9368af8ad0b85449a8039b1b3010bd / 2026-08-14 08:52:46|API license=null；README 称 MIT 又限制商业用途；abogus.py 声明原始实现来自 JoeanAmier/TikTokDownloader GPLv3，经 Evil0ctal 修改。存在文件级许可冲突，禁止搬运。未归档；近期维护不证明实时成功。|
|[ucmao/media-parser](https://github.com/ucmao/media-parser)|bf961fb30bbd13ba9d04d16466eb8a851932297b / 2026-09-26 01:37:24|根 LICENSE 为 MIT；a_bogus.js 首行限制商业用途，文件来源/许可链未解决，不能依据根 MIT 直接复制。未归档，有近期更新。|
|[ta867070117/video-analyse](https://github.com/ta867070117/video-analyse)|09926ddf393a5663c859e769885c553138dbfc0a / 2026-09-16 07:23:55|API license=null；公开的是远程服务文档，未见 signer/平台源码；维护文档不证明匿名本地路线。|
|[jiji262/douyin-downloader](https://github.com/jiji262/douyin-downloader)|9874f413b2c1f8ad6e731b26e3e05f402fc964f8 / 2026-09-22 10:32:39|根 MIT、未归档；core/api_client.py 当前包含门禁 bridge 处理，不能沿用首轮摘要推断“只有简单 A/X 签名”。未复制任何代码。|

关键阅读文件：DL douyin_video_parser.py、abogus.py、xbogus.py、README；uc src/parsers/douyin_parser.py、utils/signer/bytedance/bogus_signer.py、a_bogus.js、x_bogus.js、utils/web_fetcher.py、LICENSE；video README；jiji core/api_client.py、README。DL/uc parser 首次按分支读取，元数据稍后查询，存在分支更新竞态，不能把首次文件强称为已锁定上述提交；后续 uc signer/URL helper与jiji api按 SHA 获取。未建立完整代码谱系或作者授权证明。

## 三个重点项目完整链路审计（源码事实，不是本轮成功链）

|审计项|DLWangSan|ucmao|video-analyse|
|---|---|---|---|
|输入|分享文本/作品 URL|解析框架传 real_url|作品 URL + 服务 token|
|aweme_id|URL 正则 video/note/aweme/detail、video_id/aweme_id/note_id；短链 GET 后重定向/HTML匹配|UrlParser.get_video_id 取路径末段或 modal_id；WebFetcher 处理限定平台重定向、meta refresh|内部方法未公开|
|endpoint / method|GET www.douyin.com/aweme/v1/web/aweme/detail/|相同 GET；note/slides 分支优先 detail|远程 proxy.layzz.cn；平台 endpoint/method 未公开，未调用|
|query|device_platform=webapp, aid=6383, channel=channel_pc_web, pc_client_type=1, version_code=190500, version_name=19.5.0, aweme_id；另 cookie_enabled/browser_language/browser_platform/browser_name/browser_online/engine_name/os_name/os_version/platform/screen_width/screen_height|前述应用参数+aweme_id；动态 msToken+a_bogus；UIFID存在时附 secsdk 签名，不含 DL 全套屏幕字段|平台 query 未知|
|headers|Accept JSON/plain/*、Accept-Language zh-CN、Origin Douyin、Sec-Fetch-Site same-site/Mode cors/Dest empty；Cookie条件添加|Accept、Accept-Language、sec-ch-ua Chrome123/mobile0/platform Windows、Sec-Fetch同源/cors/empty；Cookie总按会话合并；可加 uifid|平台 headers 未知|
|UA / Referer|Windows Chrome130；note输入用 /note/id，否则 /video/id|Windows Chrome123；/note/id?previous_page=web_code_link|未知|
|Cookie / 登录|从 douyin_cookie.txt 自动读；为空不发送。README引导扫码/导入。代码可选不能证明平台可选|用户配置 Cookie+ttwid+requests Session；ttwid动态申请且有固定fallback，UIFID可来自配置/Cookie；未证明无登录成功|未知；服务 token 不是 Douyin 登录证据|
|A-Bogus|入口要求 ABogus 可实例化；URL query先编码，签名值只编码一次|MiniRacer调用 generate_a_bogus(query, UA)|未知|
|X-Bogus|A 请求失败后 fallback；若 ABogus不可用，get_aweme_detail直接return，不能默认纯X可用|signer有 get_xbogus；本次读取的 detail请求路径未见调用X fallback|未知|
|其他动态参数|signer含时间/随机字节、硬编码ua_code和browser特征；入口未见强制msToken/verifyFp|107字符随机msToken；匿名ttwid；可选UIFID及x-secsdk-web-signature|未知|
|响应对象|root.aweme_detail；status_code0后仍需detail非空|root.aweme_detail；validate仅非空，MediaFlow仍需精确ID校验|文档type=2/pics[]，没有原始aweme_detail证据|
|图文与顺序|aweme_type 2/68、其他类型images非空；按images循环后set集合/去重会损失重复位置，不能复用|image_post_info.images/image_list，顶层images/image_list/image_infos/original_images，第一个非空数组顺序append|文档pics数组；与原作品顺序关系未公开|
|图片URL|url_list[0]、download_url_list、url、origin_url等|优先url_list最后一个；fallback display_image/image_url/image/origin_cover/cover/download_url_list/download_url|服务样例CDN URL，仅输出格式线索|
|LivePhoto|先扫描video/播放或下载地址、live/motion候选；不代表每项都有字段|video、video_play_addr、video_download_addr；play_addr/download_addr/vid/uri；输出url+live_photo_url|文档videos[]，具体平台字段未知|
|live_photo_type / clip_type|本轮未证实为必要判型字段|本次get_image_list未依赖这两个字段|未知|
|failure fallback|A→X；非note可换note Referer；缺detail终止|动态ttwid/msToken/A签名重试，图文失败→分享SSR；终端权限/删除状态停止|内部fallback未知|

jiji补充：get_video_detail按aid=6383/1128请求同一detail；默认query含Windows设备/屏幕、msToken、空uifid，A失败可X fallback。当前代码明确把aweme/detail列入需要额外门禁签名/bridge处理的接口；多次重试/身份补充不适合作为本轮匿名最小实验。当前README CLI Status明确单条视频/图片等被请求验证阻断，更新Cookie或重试不能解决。首轮已记录每位置图片候选和image_post_info/images兼容线索，本轮未复验图片映射模块。

其他既有候选：Ortonzhang是浏览器路线且许可证未确认，按本轮不扩展Browser保留；surmoun旧iteminfo、renyijiu归档iteminfo、备用移动feed已在上轮本机验证空响应或目标缺失，不重复；cmsjin疑似同源，不计独立成功证据。

**为什么别人可能有images而MediaFlow没有？** 源码具备读取images分支，不等于当前拿到了它。DL混合签名、固定特征与可选登录Cookie；uc混合ttwid/msToken/A签名/可选UIFID与重试；video使用不可审计远程服务。MediaFlow之前feed返回其他作品、HTML仅路由壳、detail在网关就被拒绝。本轮确认缺的是目标detail响应，不足以把差异归因于某一个参数。A-Bogus计算涉及query/method哈希、UA绑定、时间、编码；DL硬编码UA特征与实际Chrome130是否吻合未验证。不能通过改名/转写GPL算法声称独立原创。

## Experiment A 可复核证据

脚本 web_detail_baseline.dart，标准库、无生产导入、DIRECT、禁redirect、单请求、连接15秒/全流程25秒、响应2MiB。query按序：device_platform=webapp&aid=6383&channel=channel_pc_web&aweme_id=7690029886242009957。UA Windows Chrome130，Referer https://www.douyin.com/note/7690029886242009957，Accept application/json。没有sec-ch设备特征、Cookie、msToken、A/X签名；这些是有限baseline参数，不声称已证明最小必要集合。

UTC 2026-09-27T14:40:43.364808Z；HTTP403，text/plain，46 bytes，Set-Cookie=false，无redirect；固定分类命中ArgusSecurityPlugin Uifid Not Found。JSON=false/detailPresent=false/targetMatch=false。响应正文只在内存检查，不保存；没有向日志输出Cookie/完整响应或媒体URL。完整参数与摘要见 web-detail-baseline-network.jsonl。

此前沙箱运行一次SocketException，无HTTP结果，另存web-detail-baseline-sandbox.jsonl，不算平台失败；一次初始编译错误在发网络前修正。实际Douyin请求1次，无业务重试、短链请求0、B/C0、session0、Browser0、图片0。GitHub直连下载/metadata尝试25次（源码16，其中3个错误路径404；仓库元数据/commits8、tree1）；另6次沙箱源码访问失败，及web工具4个GitHub页面open调用。web工具内部缓存/抓取次数不可见，不将tool调用数当作底层HTTP总数。没有任何解析服务调用。

## 数据结构与模型：未获得真实目标响应

真实aweme_id/aweme_type/desc/author/images/url_list/download_url_list/url/origin_url与live相关字段均NOT VERIFIED，不能用源码线索冒充本次响应。探针离线fixture只是契约检查，不是平台数据。

条件设计：取得精确目标后，MediaContent.id=aweme_id、platform=douyin、description=desc、author=author.nickname、title从desc选非空展示值（空时用中性作品ID名称）；type依据真实内容为imageGallery或mixed，sourceUrl规范公开note URL。按原数组位置建立image资源，id=<work>:image:<index>，url取经验证候选，重复URL位置仍保留；suggestedFileName按位置命名，扩展名/MIME不从签名query猜测，未确证时留空。URL变体不当作不同图片。

现模型资源List保证顺序且允许image/video/audio；静态图集理论足够。LivePhoto能拆成image+video两个资源，但缺显式同一资产分组/配对关系；未来取得真实样本再提出可选groupId/role等最小模型演进，不本轮实现。MediaResource拒绝Cookie/Authorization，session永远不能塞入公共模型。没有模型足够表达真实gallery的完成结论。

## 五端与 session 设计边界

优先共享Dart Douyin Adapter + Signer接口，签名输入为确切编码query、method、UA与已审计的非身份运行参数；输出只给本次请求，不能落History/日志。HTTP与纯计算理论可五端共享；参考Python/gmssl或MiniRacer不能直接当移动端生产依赖。没有独立signer、没有签名正确性向量、没有Android复现，均NOT VERIFIED。

session只保留条件设计：如果将来规则明确允许且匿名必要性证据成立，Windows WebView2/Android WebView各自Adapter内部持有App自有隔离会话、显式用户授权、可清除、禁止凭据出Adapter，不读取Chrome/Edge/System用户态；关闭/退出/清除失败必须可验证。iOS/macOS WKWebView、Linux可替换runtime须各补生命周期Adapter。账号依赖与验证仍有架构风险，现规则下不实施。没有安装APK，没有读取任何设备会话/正式数据。

## 检查与修改范围

新增5文件：web_detail_baseline.dart、web_detail_baseline_test.dart、web-detail-signer-route-audit.md、web-detail-baseline-sandbox.jsonl、web-detail-baseline-network.jsonl。修改5文档：v0.4.0/README.md、research/README.md、research/douyin-gallery-route-matrix.md、research/poc/browser-closeout-route-decision.md、research/poc/stage2-douyin-gallery.md。删除0；production修改0；第三方代码复用0；新增依赖0；Git写操作0。第三方只作请求/结构设计参考，无搬运，无新增attribution义务；未来采用必须解决文件许可。

Dart format成功，提示根analysis_options无法解析flutter_lints include；两脚本dart analyze No issues found；9项离线检查PASS（空/数组/缺detail/错ID隔离/精确目标/重复位置顺序/凭据URL拒绝/live字段存在/不输出URL）；不是signer测试。git diff --check成功；tracked diff --stat空，v0.4.0全部未跟踪，不表示无新增文件。未运行flutter analyze/test、Windows/Android build、APK lint、iOS/macOS/Linux build、GUI或真实图片验证；没有用历史通过代替本轮。

【项目目标兼容性检查】

|平台|本轮状态|
|---|---|
|Windows|独立HTTP baseline已实际测试，安全拒绝；签名链/production未验证|
|Android|HTTP/signer理论共享；本轮未构建未实测，不能以Windows结果验收|
|iOS / macOS / Linux|纯Dart理论兼容；未实现signer、未构建未实测，Browser/session需平台Adapter|

Bilibili与Douyin正式能力没有代码变化，但本轮未回归；小红书/YouTube/X/Instagram/未来平台未增加支持。PlatformDetector、Parser/Adapter正式接口、ParserService、统一领域模型/MediaContent/MediaResource、Downloader/断点队列、Media Processing、UI、History、Settings、Logging与正式本地存储均没有变更，未追加通过证据。Browser研究全部保留，无扩展。隐私/本地/零服务器保持，直连目标平台而非第三方解析；研究只保留请求配置与分类摘要。依赖及正式包体未改变；探针有超时/内存限额，性能未benchmark。维护风险为安全网关、签名版本/UA绑定、源码许可冲突、平台结构/URL过期；正式发布仍不能宣称Douyin gallery支持。

Git核对：cwd/top-level D:\projects\mediaflow-v040；feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；status ?? v0.4.0/；不commit/push/merge/tag/PR，不进production，完成后暂停。
