# 小红书第二阶段证据

状态：**Android Level0图文真实链路成立；双端及视频链路尚未完成，X-A/X-B未满足，X-C证据不足。**

## 参考链路

项目机制、版本、source-index、license及必要条件矩阵见 `reference-project-comparison.md`。Andy/用户脚本/MCP共同读取目标note detail及有序imageList；Joe支持HTTP与已加载脚本数据；MediaCrawler signed feed API与登录上下文是另一条路线，不等于所有公开作品必须登录。完整参考工具当前未运行：Andy多包/浏览器环境未建立；Joe默认TLS路径、脚本服务及Cookie配置需适配；MCP当前默认指纹功能违反本项目边界；MediaCrawler包含自定义许可及反检测设置。均 `NOT RUN / SOURCE VERIFIED`，不能把它们写成当前实测FAIL或成功。

## 用户人工确认的样本

| 分享URL | note ID（真实302给出） | 用户确认类型/数量 | Windows Level0 | Android Level0 |
|---|---|---|---|---|
| https://xhslink.cn/o/5X01rOYZDMT | 6abb69640000000014010526 | 公开视频 | 作品页302至/login；loginRequired | 作品页200、143848字节，目标noteDetailMap未匹配；parseNoMatch |
| https://xhslink.cn/o/4wRbjSYrcBJ | 687a4239000000002400bcc9 | 静态图文8图 | 分享302成功，作品页18秒超时；networkFailure | 作品页200、177924字节，目标数据未匹配；parseNoMatch |
| https://xhslink.cn/o/V8A6eesUi3 | 686f739c000000002203d3a2 | 静态图文5图 | 作品页302至/login；loginRequired | 作品页200、152426字节，目标数据未匹配；parseNoMatch |

最终作品URL为 `https://www.xiaohongshu.com/discovery/item/<note ID>`。实际redirect带xsec_token等平台签发分享参数，仅使用于所属平台请求；文档/JSON删去值，只存query键。Windows停止前未返回最终作品HTML；Android取得HTML哈希、大小但未取得目标detail。用户图片数未冒称Parser核实。

两端UA均如实标明实际OS；结果可能同时受UA、网络出口、时间或平台页面路由影响，尚未单变量隔离。外层标记 `platformDifference` 观察，保留原始 `loginRequired/networkFailure/parseNoMatch`，不能归因某一个字段。

## 资源与验收结果

| 验收项 | Windows | Android |
|---|---|---|
| note ID / 分享跳转 | 三样本已观察 | 三样本已观察 |
| title、author、cover、作品类型与数量 | 未取得detail | 未取得detail |
| 视频URL/下载/系统视频播放器 | NOT RUN | NOT RUN |
| 有序imageList / 页面顺序对照 | 未取得 | 未取得 |
| 前2张不同图片实际下载、哈希、视觉内容 | NOT RUN | NOT RUN |
| 系统图片应用/图库 | NOT RUN | NOT RUN |
| MediaStore | 不适用 | 未有可发布文件，NOT RUN |

PoC设计保持数组顺序，使用实际返回masterUrl/urlDefault，不重构CDN原图URL。正确顺序、两图不同及原图属性都尚未实证。Gallery领域模型可表示有序image资源，资源ID需区分重复URL/同一作品不同位置；History当前以任务ID序号分组，不额外拷贝平台页面。

## session结论与下一步

本次仅Level0，无Cookie/Auth、忽略Set-Cookie、不持久化身份。Windows/login证据只说明**此请求条件**被导向登录；Android200提示不能概括为所有入口必须登录。Android返回页面需先做一次有界字段结构诊断，再决定移动页schema适配或正常匿名Browser初始化。

Level1尚未运行；若源码/诊断支持正常初始化上下文，使用App自有隔离匿名profile、生命周期和清除可验证，一次只变一个变量组。Level2仅在Level0/1确不足且登录必要性证据支持时研究用户主动正常登录；无外部Cookie导入、不开发完整登录系统。Level3排除。当前不增加签名、身份或频繁换UA去规避登录/安全拒绝。

没有证据证明需要a1/web_session或X-S/X-T；它们是参考项目的条件线索。登录、签名、Browser、分享token必要性必须分别验证。生产Parser/Downloader/History均未修改。

## 决策

当前**继续第二阶段定位页面结构/正常上下文**，不进production，不把入口条件受限误判为X-C。只有双端结构化结果、真实下载和系统打开完成后才能进入X-A/X-B。

## 后续真实证据（覆盖上文首轮“未取得”，保留首轮记录）

1. Android一次8图页面结构诊断，200 HTML包含 `window.__INITIAL_STATE__.noteData.data.noteData`；没有桌面 `noteDetailMap`。仅存结构/类型，未保存原HTML或token值。源码参考是桌面入口，实际移动页字段必须补充实测。
2. 适配该真实字段后，Android视频取得id/title/author/type=video及video.media.stream的返回URL；8图取得id/title/author/type=normal、有序8项imageList。5图在后续网络操作未完成，不能用用户数量充当Parser成功。
3. 首次资源被PoC自身HTTPS准入挡住，是本地 `unsupportedUrl`，没有向CDN发请求。实际图片URL为 `http://sns-webpic-qc.xhscdn.com/...`。研究包仅为xhscdn允许公开无凭据HTTP，原URL不改写，HTTPS仍校验证书；明文完整性风险必须保留为发布决策事项。
4. Android8图前两张真实GET200 JPEG，57629/59560字节，1080×1080；SHA256分别 `ec44842c35b0dcd59317f036beb09dd7425a37831a7f799363946ebb8d5cb48e` / `f706cedf9bcb49d611ef128970502d9584911a99319e6b5aa5e953a03574539e`。图片URL宣称尺寸2048×2048，实际解码1080×1080，故不能称原图。两张实际内容不同：拿纸筒的猫、戴耳机的猫。
5. MediaStore分别 `content://media/external/downloads/1000030511`、`1000030512`；用户确认两张系统应用均可打开、顺序与作品页一致。系统图库独立浏览是否显示、应用名称尚未单独核验。参考 `poc/android-media-url-results.json`、`android-latest-results.json`；打开Intent派发与人眼确认分开。
6. 全程Level0，无Cookie/session/login、无X-S/X-T、无JS runtime。所以至少该Android图文样本不必登录；不能推广到所有作品或Windows。
7. Windows对此前超时的8图做一次Level1正常自有WebView2页面初始化，`ConnectionReset`，没有取得detail，profile清理成功。不是Level1登录失败证明，不进入Level2。SDK为官方Microsoft.Web.WebView21.0.4258.31，许可BSD式三条款，仅研究；没有导入浏览器Cookie或修改指纹。
8. 视频与5图后续遇到连接/超时，单次有界网络重试结果另存；不会对登录/安全拒绝重试。双端差异仍需网络与普通页面上下文隔离定位。

源码链补齐：Joe的 `source/expansion/converter.py` 也明确支持PHONE_KEYS_LINK=`noteData/data/noteData`；先前PoC遗漏该移动字段路径已修正。此处是公开页面字段结构参考与真实诊断交叉核验，没有复制GPL解析实现。最后网络重试版已非流式安装成功，但设备再次断开，完成状态与新结果导出仍待核实。

## 本轮固定样本更新

最新事实以network-matrix-phase2.md和phase2-progress-report.md续跑章节为准。YouTube两个用户固定样本双端连接失败，未取得metadata/manifest；Android小红书视频、第二5图作品真实下载与MediaStore成功，用户确认视频画面/声音及两图打开/顺序。8图PASS保留未重复。WindowsXHS本轮302登录安全停止。整体均NOT YET CLASSIFIED，不判production接入完成。

## 2026-10-01 小红书最终收尾（优先于前述历史状态）

**X-A PASS**。详见 [双端最终证据与兼容性检查](xhs-feasibility-closure.md)。Windows 本轮直接匿名 HTTP，使用明确声明Windows的移动布局兼容UA；无Cookie发送、无a1/web_session、无首页/session初始化、无WebView2或登录。正常分享重定向所带xsec_token只在内存使用，未验证移除后的必要性，不能称必须。视频6abb69640000000014010526真实下载1680739字节；8图687a4239000000002400bcc9前两张57629/59560字节。三个文件hash分别与Android对应文件一致。用户确认Windows视频画面/声音正常，两张图片能打开、内容不同且顺序一致。旧Android视频/5图/8图、MediaStore和系统打开PASS保留，不重跑。

纯HTTP A路线成立，因此不增加B路线profile/session实验。25项全research离线测试通过（含Android schema回归）；Dart静态检查无问题；Windows原生研究构建已实际执行固定8图，不是production发布构建。近期源码/提交/Issue/许可证审计见xhs-oct1-reference-audit.json；最接近JoeanAmier Converter移动/桌面hydration路线，均设计参考、没有第三方代码搬运和新增依赖。

YouTube暂停，既有prototype仍待用户联网验收。production、正式依赖、History/UI/Downloader/ParserService未改；History重启恢复不在本次已通过范围。无commit/push/merge/tag。固定样本成功不等于所有小红书作品可解析或正式发布完成。

**V0.5.0 XHS FEASIBILITY CLOSED — X-A PASS**。等待下一条指令，不进入production、不恢复YouTube。