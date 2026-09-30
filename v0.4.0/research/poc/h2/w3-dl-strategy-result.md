# W3 — DL-style Web Detail Strategy（2026-09-28）

**最终：W3-2 — W3-A / W3-B 均保持 UIFID gate。** 两次detail均HTTP403 / 46bytes / `Blocked by ArgusSecurityPlugin Uifid Not Found`，正常session没有改变结果。无signature错误、业务JSON/target/gallery。不得继续第四套Web-detail headers/query组合；H2进入产品/技术决策，不以继续微调碰概率。完成后暂停。

## 执行前：当前来源与精确差异

从GitHub重新取得DLWangSan/douyin_parse当前master commit：0896c74d1e9368af8ad0b85449a8039b1b3010bd；douyin_video_parser.py SHA256 e415dea060c00e95b86d420ee78a6838dc094f9d8ef9958ca2a25d630bbd995d。当前HEAD仍与之前固定版本相同，但本轮没有仅据旧报告推断。两次GitHub请求（commit API + pinned raw file），未执行第三方源码。精确实发形状见 [w3-shape.json](signer/w3-shape.json)。

BASE_PARAMS声明17项，复制后追加aweme_id共18项。_build_headers提供UA、Accept、Accept-Language、Referer、Origin、三个Sec-Fetch；仅有Cookie时附加。_sign_abogus_url先urlencode(params)，AB.get_value(params)，把quote(signature,safe='')放最后，避免二次编码。get_aweme_detail以original_url包含/note/选择note Referer。_request_json首先A，失败后源码可换X；本轮禁止X及Referer/请求重试，只用当前许可已审计的research signer。

DL源码parser固定UA Chrome130；AB实例没有显式传parser UA，不能证明其内部默认UA与HTTP一致。本轮不复制/执行DL算法，使用现有research signer且UA与HTTP保持本机实际Chrome153/Edge153一致。DL固定screen1920×1080替换为既有自有runtime实测1536×864，其余BASE_PARAMS标量保持；这些差异限定W3为DL-style，不能声称逐byte复现DL成功客户端。

|条件|历史W2|本轮W3-A / W3-B|
|---|---|---|
|endpoint|https://www.douyin.com/aweme/v1/web/aweme/detail/|相同|
|target|7690029886242009957|相同|
|query字段|device_platform, aid, channel, aweme_id|DL基础17项 + aweme_id，完整有序值见下|
|query顺序|上述4项，A最后|下列18项顺序，A最后|
|UA|真实Windows10/Win64 Chrome153/Edge153|相同，与signer同UA；不是DL固定Chrome130|
|Referer|https://www.douyin.com/note/7690029886242009957|相同|
|Origin|无|https://www.douyin.com|
|Accept|application/json|application/json, text/plain, */*|
|Accept-Language|无|zh-CN,zh;q=0.9,en;q=0.8|
|Sec-Fetch-Site|无|same-site（参考实现声明，不代表真实浏览器导航）|
|Sec-Fetch-Mode / Dest|无|cors / empty|
|ttwid|无|A无；B仅本轮自有session实际值|
|session cookie|无|A无；B仅实际sessionid/sessionid_ss|
|msToken|无|均无；当前DL分支不主动使用|
|UIFID|无|均不加入|
|A-Bogus|原research算法，query最后一次percent encode|算法不变；签名输入变成18项。此次全为无空格ASCII，当前canonical编码与DL urlencode相同|
|X-Bogus / secsdk / Argus placeholder|无|均无；不采用DL X fallback|
|其他headers|HTTP库Host等默认，direct/禁止redirect|HTTP库默认/transport不变；未加sec-ch/其他设备头|
|screen query|无|加入真实1536×864；不使用DL固定尺寸或额外CPU/memory/Pixel等|
|timestamp/entropy / transport|原策略|相同生成策略，自然当前时间和entropy；不重放历史签名|

W3有序query（签名前）：

```text
device_platform=webapp
aid=6383
channel=channel_pc_web
pc_client_type=1
version_code=190500
version_name=19.5.0
cookie_enabled=true
browser_language=zh-CN
browser_platform=Win32
browser_name=Edge
browser_online=true
engine_name=Blink
os_name=Windows
os_version=10
platform=PC
screen_width=1536
screen_height=864
aweme_id=7690029886242009957
```

version_code/name沿用参考Web客户端参数，未证明与当前平台版本相符；不是实际系统版本探测结果。此处只声明参考请求形状，不把源码字段定义为协议必需。策略组改变包括query集合/顺序与headers，**不是单变量实验**。

执行约束：先W3-A一次无Cookie；200立即停止；只有明确context/security gate且无signature错误才可W3-B一次新正常自有session subset。无UIFID/placeholder/新参数动态修补，无媒体下载。原signer与W2 runner文件不修改；W3适配器复用原dispatch/response reader，仅换策略query和显式headers，一次额度独立记录。

## 3–12. W3-A / W3-B 实际结果

|项目|W3-A|W3-B|
|---|---|---|
|执行|是，2026-09-28T14:34:46Z|是，2026-09-28T14:36:34Z|
|Cookie|无|本轮新自有profile实际sessionid/sessionid_ss/ttwid|
|HTTP / content type / bytes|403 / text/plain / 46|403 / text/plain / 46|
|实际安全错误（白名单脱敏文本）|Blocked by ArgusSecurityPlugin Uifid Not Found|完全相同|
|UIFID gate消失|否|否|
|explicitSignatureError|false|false|
|业务JSON / targetMatch|false / false|false / false|
|aweme_detail / aweme_type|未取得 / 未取得|未取得 / 未取得|
|images / image_post_info|0 / false|0 / false|
|H2 DATA PATH VERIFIED|否|否|

记录：[W3-A](signer/w3-a-result.json)、[W3-B](signer/w3-b-result.json)。没有保存任意raw body，只保存严格白名单的非敏感错误文本，signature/Cookie值没有输出。没有media下载、X fallback、失败后的修补或重复请求。

W3-B只在A明确UIFID gate后执行，使用新隔离profile。测试人员本人确认challenge/正常登录完成，sessionid与sessionid_ss各length32、ttwid length127，均.douyin.com/path=/，前两expiry2026-11-27T14:36:26.838Z、ttwid expiry2027-09-28T14:36:30.777Z；与profile实际UA一致且无明显过期证据。账号接口未独立核验认证。B不检查/取得UIFID，不使用其值；helper finished中的uifidObserved=false只是未观察标志，不能写成该profile必然没有UIFID。

凭据只在WebView/helper内存与受控Python子进程环境中流转，发送所属Douyin任务；没有secret文件、其他App/浏览器导入或完整jar导出，metadata只记录名称/属性。A/B的18项query与8项原显式headers由同一strategy()构造；B唯一额外是allowlist Cookie header。

最终profile nativeProfileClear=true、scopedCookiesAbsentAfterClear=true、BrowserProcessExited=true、profileRemoved=true。独立目录不存在、helper PID6384已退出、stderr0bytes；未做crash/断电或重启持久性验收。helper旧reason字符串single_session_w2_completed不改写原日志，实际子进程结果experiment=W3-B与w3_b_child均明确，不能误读成又一次W2。显式E1计数0不包含Python的W3-B；detail总数见两结果额度之和。

## 13–16. blocker、H2决策与额度

当前唯一主blocker：**在当前本机环境，两种已测试Web-detail strategy均遇到同类UIFID/context gate**，普通正常session subset不足。没有证据签名被服务端接受/拒绝或已进入签名层，不把signer设为新blocker。

H2是否继续：**保留候选，不继续当前组合实验，production仍阻断，等待明确go/no-go决策**。本轮并未否定所有Web-detail实现，但已明显削弱“只是历史W2简单形状导致”的解释；不得把当前有限证据写成所有环境/所有协议都必需独立UIFID字符串。W3采用诚实UA/尺寸与当前research signer，与DL实际客户端并非完全相同，仍有协议/TLS/上下文绑定不确定性，不能声称成功项目线上行为已复现。

下一轮唯一目标：**H2产品/技术决策：采用显式正常授权UIFID context，或关闭当前Web-detail H2**。不再提出第三/第四套headers/query试验，不解冻signer、不研究UIFID首次生成。历史已有某轮正常profile自然UIFID的存在性证据，只是可获得性线索，不是绑定/可消费证明，必须有新的明确授权与来源验证才能实验；本轮不执行这条路线。

本轮detail请求总数 **2（A1+B1）**，无retry；GitHub当前源码读取2（与detail预算分开）；WebView正常页面4个navigation、941个resource事件、915个response事件，不代表941次解析实验，OS全量网络数未知。第三方signer/解析服务请求0；无其他endpoint。

## 17–21. 文件、验证、Git

新增：signer/w3_dl_strategy.py、signer/w3-shape.json、signer/w3-a-result.json、signer/w3-b-result.json、本报告。修改：local-session/AuthorizedSessionPoc.cs 增加W3-B正常session模式，不读取UIFID，只通过process env消费允许subset；三个README索引追加最新结论。删除源码：无；raw参考源码仅放忽略build/w3-source作审计缓存，不把受限signer搬进研究/产品。

第三方：DLWangSan为行为/调用边界参考，根LICENSE缺失/其signer GPL及来源风险仍排除；没有复用/翻译其算法，只读取公开参数/header结构。继续用既有F2 Apache-2.0研究算法，原NOTICE/版权/license不变；未新增第三方代码模块或依赖，无X、商业/云signer。未来production许可仍须按既有报告审查。

验证：csc research编译PASS；11项既有离线安全契约断言PASS（不等于新增Native模式全覆盖）；W3 Python语法、18字段顺序/8headers、canonical_query与DL urlencode字节一致、两结果预算/allowlist/same-error检查PASS；冻结六文件hash一致，signer/原W2 runner未改。真实A/B与用户正常session/最终clear已实测，但目标业务失败。无需重复冻结算法/契约测试；完整Flutter analyze/lint、正式Windows/Android/iOS/macOS/Linux build本轮未运行。无Android安装、覆盖、卸载或清数据。

Git：feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；开始/结束status ` M AGENTS.md`、`?? v0.4.0/`。预存AGENTS未改；git diff --stat仍为AGENTS31行、23 insertions/8 deletions，研究目录未跟踪故stat不包含本轮变更；git diff --check无报错。production修改=否；Git写操作=否（无add/commit/push/PR/merge/reset）。

## 22. 【项目目标兼容性检查】

|平台|状态/限制|
|---|---|
|Windows|已实际测试research A/B、正常自有session、clear/退出/删除；正式App build未跑，目标数据失败。|
|Android|理论隔离Adapter路径；本轮未构建/实测/安装；仍需同等级正常context/业务/clear验收，不能以Windows研究代替。|
|iOS|理论WKWebView专用store+HTTP适配，未实现/构建/实测；属性与生命周期需验证。|
|macOS|理论WKWebView Adapter，未实现/构建/实测；现有helper仅Windows研究。|
|Linux|有平台特有风险，未实现/构建/实测；runtime/隔离及正常客户端协议尚未解决。|

|目标/模块|具体兼容性检查|
|---|---|
|Bilibili / Douyin|production源码未改；Bilibili未回归，Douyin研究目标未成功，不宣称平台恢复。|
|Xiaohongshu / YouTube / X / Instagram / 未来平台|无新增能力；平台策略只能放对应Adapter，DL参数不得成为公共HTTP规则。|
|PlatformDetector / ParserService / Parser / Adapter|公共源码未改；W3仅research可替换策略，正式接入未开始。|
|Unified Content Model / MediaContent / MediaResource|未修改、不引入凭据；无gallery payload，未验证多资源映射。|
|Downloader / Media Processing|未修改、不下载/处理；队列/暂停/Range/.part与处理能力未回归。|
|Browser Adapter / UI|只用户正常session入口，未新增正式UX；不做平台内容Observation或存储/SDK扩大采集。|
|History / Settings / Logging / 本地存储|production未改；真实值不进报告/结果/截图；研究文件只元数据和严格非敏感错误。|
|隐私 / 本地 / 零服务器|签名本地，Cookie只发所属平台的授权任务；无凭据向第三方上传、云解析/签名或代理。|
|依赖 / 包体积 / 性能|无新增产品依赖；正式包体积/性能未测，研究Python/WebView工具不算五端部署完成。|
|维护 / 正式发布|两形状同gate，继续微调收益没有证据；路线必须决策，无gallery/双端验收，正式发布未就绪。|
