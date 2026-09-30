# Browser Observation 最终收口与替代路线决策（2026-09-27）

> 当前路线决定已由[Web detail / signer 审计](web-detail-signer-route-audit.md)更新：Browser = **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**，本轮不扩展。旧“下一轮确认功能降级”不再是当前目标；旧实测、安全停止与cleanup结论全部保留。新baseline安全拒绝且完整签名链未测，不等于本文旧结果C或新附件结果C。

## 结果 C：本轮调查的合法路线均暂未取得目标结构

Douyin gallery production feasibility = BLOCKED。
Browser Observation = STOPPED / NOT VIABLE FOR v0.4.0。触发本轮硬结束条件 D：不存在证据充分、信息增益明显且只差一次真实验证的剩余候选。不会再以扩大采集或多轮导航作为下一步。不是声称页面不存在数据，也不是穷尽世界上所有可能入口。未进入第三阶段。

Primary direction: v0.4.0 功能降级；没有获准接入的 Douyin 图文数据路线。
下一轮唯一建议目标：确认 v0.4.0 降级范围与验收清单（Douyin 图文原图暂不支持，保留现有视频、Bilibili 多资源、失败重试、恢复/History目标）。本轮仅记录建议，不实现 UI/production，不自动启动下一阶段。

## Browser 离线收口

读取最新 android-activation-real-operation.json：operation 92f087e881ca457faca56143db05d43d，单 operation/START/navigation。JSON2、命名 hydration0、fetch response0、body2（JSON）、decoder2/error1/no-match1/success0。848ms 两次 decoder；925ms document ready；953ms navigationBoundary；954ms cancellation；987ms renderer gone；988ms WebView destroy；1012ms Binder death/OS退出；1022ms归属验证；1028ms清理；final1029ms。不同进程时间线是研究记录的 elapsedMs，不当成额外网络证据。

**两个真实 JSON 原文及已渲染 DOM 未持久保存。** 当前只剩遥测，无法重新离线解码实际 payload，也无法离线从实际 DOM 提取资源。原文缺失不等于没有图文结构。没有新浏览器导航，也没有为补证据重新抓取。

PublicPageScript.java summary 首先 new JSONObject(raw)，失败后仍 new JSONObject(Uri.decode(raw))：根数组无法处理；find 虽支持嵌套数组，不能补救根解析失败。此为静态确认的研究 helper 限制，不能证明上一轮 ERROR 就由它导致。深度/节点预算、字段绑定只认 aweme_id 也限制覆盖率。NO_MATCH 仅代表此 decoder 未匹配，不能证明内容不存在。两次 decoder 在 document ready 之前已调用，没有发现“必须等 navigation complete 才解析而丢失已入链 JSON”的证据。没有原文，其他格式或字段遗漏的原因 NOT VERIFIED。

本轮不改 Browser helper：修根数组或增加 DOM 遍历不能在缺少原始样本、目标绑定及资源证据时证明高信息增益；DOM 中图片也可能是 avatar/icon/推荐，不能升级。A（实际原文/DOM全部解码仍失败）不能冒称已完成；B/C 为禁止继续扩展的边界，决定依据 D。历史生命周期 PASS 保留，不替代 production 能力。

## 现有 production HTTP 基础设施核对

只读 lib/features/parser/data/douyin/douyin_mobile_feed_session.dart 及 douyin_parser.dart。现有入口 api5-normal-c-hl.amemv.com/aweme/v1/feed/，固定 aweme_id、aid=1128；视频对象后续须有播放资源。此前相同 Level1H 样本实测 HTTP200/status_code0、aweme_list6，但无目标精确/关联 ID，本轮不机械重试。放宽 video 字段校验不能创造响应里不存在的作品。

备用 host aweme.snssdk.com 由既有 ucmao-media-parser.md 提供线索；同一个 feed 入口族，不算独立支持证据。本轮独立 Dart GET 验证，不复制第三方实现。

## 本轮实际 HTTP/HTML 证据

唯一公开样本：7690029886242009957，Human Level1H PASS 保持。每候选一次请求，无第二样本、无浏览器、无图片下载。时间：2026-09-27，本地 Windows Dart。
脚本 anonymous_route_closeout.dart；可审计输出 anonymous-route-closeout-network-results.jsonl。各请求 GET、DIRECT、无 Cookie/Token/签名；仅固定 Accept/UA。响应 Set-Cookie=false。无重放、私有 API、代理/MITM、第三方解析服务。2MiB限制，错误/挑战停止，不重试。

|候选请求|实际结果|目标结构/资源|
|---|---|---|
|aweme.snssdk.com/aweme/v1/feed/?aweme_id=目标&aid=1128|200 application/json，291038 bytes，status_code0，aweme_list5|目标 ID 不在全文；5 IDs：7682808253096932017、7683887163994612721、7687168514545069413、7690184932001369394、7689661228737687131；不能定向取得目标|
|www.douyin.com/share/note/目标|200 text/html，33454 bytes；4可解析 JSON roots，meta23/canonical1/og:image0|目标 ID 出现，但未解析出目标作品对象、类型或图片数组；URL/ID不能证明资源|
|www.iesdouyin.com/share/slides/目标/|200 text/html，25966 bytes；1 JSON root（reason），meta19|全文无目标 ID；未取得目标对象|
|www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids=目标|200 application/json，0 bytes|空正文，不能解析|

HTML 检查纯脚本 JSON/已有命名包装等由现有研究 htmlRoots 处理；不是任意 JS 执行器，可能不覆盖所有序列化形式。以上是当前探针范围的未取得，不是证明页面完全无数据。没有取得可信 title/author/description 或目标媒体 URL。未发生重定向。

第一次沙箱直接运行四项 SocketException，无 HTTP status，因此不作为平台失败证据；取得网络权限后各一次请求的上述结果才用于判断。早先 dart run 无输出被取消（启动/依赖解析原因未确认）；改用 dart script 直接执行。无业务重试/额外真实导航。

## 路线比较与排序

|路线|取得图文结构|匿名/签名|跨平台|稳定性|合规性|production复杂度|结论|
|---|---|---|---|---|---|---|---|
|现有匿名 HTTP 扩展|NOT VERIFIED，两 feed host 不定向|本轮匿名/无签名|HTTP理论通用；Android本轮NOT TESTED|目标缺失，不能保证|本轮符合边界|低，但不能凭200接入|BLOCKED|
|HTML/SSR静态|NOT VERIFIED，两分享入口未得对象|匿名/无签名|Dart理论通用；Android未复现|shell/字段变化风险|本轮符合边界|低到中，覆盖范围有限|BLOCKED|
|其他合法匿名入口（旧iteminfo）|NOT VERIFIED，空正文|匿名/无签名|HTTP理论通用；Android未复现|旧接口失效/空响应风险|本轮符合边界|低；无可用数据|BLOCKED|
|功能降级|不宣称结构或原图|无需新解析机制|现有双端功能保留，新增能力未验收|不承诺未证实能力|符合边界|低；本轮仅范围建议|建议优先确认降级范围|
|Browser Observation（停止）|NOT VERIFIED|此前隔离匿名；不导入凭据|各端 helper 不同，Windows cleanup仍FAIL|安全边界/证据/生命周期风险|已测边界内；不能扩展突破限制|高|STOPPED / NOT VIABLE FOR v0.4.0|

未选择结果B：没有一条候选已具备足够证据仅差最后验证，不能把旧接口空响应或 URL-ID 路由提升成高价值候选。匿名 HTTP 成功条件未达到，不接 production。

## 功能降级范围

- 可保留输入 URL/作品 ID 识别；note 路径只作为图文候选，不能冒充机器确认。Human PASS 是样本真实性，不是产品解析能力。
- 没有取得目标公开元数据，不能宣布“图文识别+元数据”已支持。
- 页面可见图片/缩略图没有来源归属证据，暂不提供这类下载，不能将通用封面替代原图。
- v0.4.0 建议明确“Douyin 图文原图暂不支持”，保留研究到后续版本；不影响既有视频功能和其验收要求。本轮不实现提示或 UI。

## 最新状态

|项目|状态/范围|
|---|---|
|Windows Network Observation|BLOCKED，完整窗口NOT VERIFIED|
|Windows normal cleanup|FAIL，旧真实实验结论不改|
|Windows recovery|PASS，限已测研究场景；完整生命周期NOT VERIFIED|
|Windows Browser Observation route|STOPPED / NOT VIABLE FOR v0.4.0|
|Android device/runtime、lifecycle、Coordinator protection、automatic cleanup|PASS，限既有已测场景；本轮未重跑|
|Android bridge offline / real|PASS，real仅上轮JSON→decoder链|
|Android 离线安全停止 / 真实安全停止|PASS（离线）/ NOT TESTED（真实）|
|Android Network Observation|BLOCKED|
|Android Browser Observation route|STOPPED / NOT VIABLE FOR v0.4.0|
|目标结构 / 图片 URL|NOT VERIFIED / NOT VERIFIED|
|图片下载|NOT TESTED|
|production feasibility|BLOCKED；双端原图生产门槛未满足|
|剩余 Browser 高价值候选|BLOCKED，无已证明值得继续的候选|
|第二阶段结束条件|当前 Browser 路线按本轮D收口；不是旧附件A–D成功/production通过|

本轮证据仍不足以满足此前附件任一 A–D 结束条件，继续停留第二阶段。此句指旧 production/技术验收附件；本轮新定义 Browser 硬结束条件 D 已触发，不再重启 Browser 轮次。

## 验证、变更与风险

新增研究探针及两份 JSONL（沙箱失败/实际网络）和本记录；更新总README、research README、stage2、feasibility、RC、路线矩阵、Android研究README的最新状态，保留历史。未删除文件、未修改production/Java/Manifest、未安装APK、未新增依赖、未复制第三方代码。无需第三方 attribution（仅接口/设计参考）。

执行 Dart format、dart analyze（新脚本），实际直接 Dart探测、git diff --check/stat/status/branch/HEAD。format提示root flutter_lints include无法解析；analyze结果No issues found。未执行APK build/lint、Windows/Android Release、flutter analyze/test、Flutter全量回归、正式验收、图片下载、Browser/Android navigation、Git写操作。git diff --stat为空仅表示tracked无改动，不能忽略未跟踪研究文件。

【项目目标兼容性检查】
Windows已实际测试本轮HTTP，Browser风险未消失；Android已有研究实测，本轮HTTP NOT TESTED；iOS/macOS/Linux仅HTTP理论兼容，Browser暂不支持/平台特有风险。未修改现有Bilibili/Douyin视频、PlatformDetector、ParserService、MediaContent/MediaResource、Downloader、History、Settings、Logging、本地存储和UI；没有本轮回归证据，不能追加“全部通过”。小红书/YouTube/X/Instagram及未来平台未实现，维持独立Parser/Adapter边界。Media Processing未变；Browser研究停止而非正式Adapter接入。仅本地研究日志，不上传链接到解析服务器、不保存凭据；直接访问目标平台是正常解析请求。依赖/正式包体未改变，探针限制内存/超时但未做性能基准。维护风险为接口非定向、SSR覆盖、缺失历史原文与平台变化；正式发布不能宣传Douyin图文支持。全部现有研究文件保留。

Git：cwd/top-level D:\projects\mediaflow-v040；feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；status ?? v0.4.0/。无commit/push/merge/tag等Git写操作。完成后暂停。

## 补充来源与复用边界

备用feed入口依据已存 ucmao-media-parser.md（MIT，只参考）与现有生产网络基础设施；旧iteminfo历史参考分别记录在 ../surmoun-short-video-api-closeout.md 和 ../renyijiu-douyin-downloader-closeout.md。两者同用平台入口，不算两条独立匿名成功路线；没有证实fork关系。surmoun许可证未确认，不允许搬代码；renyijiu MIT但已归档。MediaFlow独立请求，没有直接复用代码。

搜索对照还包括 https://github.com/coflyn/Mori/issues/13 （分享/slides/iteminfo失败报告）及 https://github.com/jackwoo725-ux/douyin-downloader/blob/main/backend/douyin.py （slides/分享解析与第三方fallback线索）。这些不是MediaFlow成功证据、不是本轮采用实现，License/维护/完整依赖未核实，不复用。第三方fallback/Cookie/签名路线全部排除，不作为下一轮候选。分享/slides是公开路径拼接，既有目标ID直接GET，不重放抓取请求。

最终命令核验：dart analyze No issues found；git diff --check成功、git diff --stat无tracked变更，git status仅?? v0.4.0/。本轮新增6文件、更新7文档，无删除。未运行任何build/lint，不用旧成功结果代替本轮。
