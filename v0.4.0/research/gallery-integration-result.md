# Gallery architecture / offline adapter 完成（2026-09-28）

完成本轮八项设计/离线停止条件；**未执行 Windows production spike**，不标记 `WINDOWS GALLERY PRODUCTION SPIKE PASS`。当前离线链条为：真实脱敏F2结构 → 新DouyinGalleryAdapter → existing MediaContent → 13 ordered MediaResource → existing mapper → 13 DownloadTask。没有在线provider/client实现或正式解析入口注册。

[推荐架构、三方案比较、session UX、双端spike方案、workaround边界及兼容性检查](gallery-integration-architecture.md)。自研H2永久冻结。当前下一步是本地gallery在线backend/session接入资格与有界Windows spike，不是重启任何H2协议路线；Windows通过后才进入Android等价实现，并立即暂停本轮。

## 真实 fixture 与敏感数据

上一轮未保留原始payload，不能把13条统计凭空改称真实fixture。因此本轮重新打开专用隔离profile，通过本人正常登录，调用**原F2官方detail API一次**，没有修改上游源码、signer或headers，没有对placeholder做网络消融。

UTC `2026-09-28T15:19:29Z` 返回 target匹配、status_code=0、type68、images13、不同HTTPS URL13及不同resource path13。实际图片结构只有 `url_list`。选择白名单 status_code/aweme_detail.aweme_id/aweme_type/images[*].url_list，保留数组和候选顺序，替换URL及desc后写fixture。不是原始完整响应或真实URL下载fixture。

- fixture：`test/fixtures/douyin/authorized_gallery_13_sanitized.json`。
- 来源与SHA：`test/fixtures/douyin/authorized_gallery_13_provenance.json`，SHA256 `b2e5351a7c6251f975f8b12286f1098750ddc5b4114cc859276bee92d88a57ef`。
- sessionid/sessionid_ss长度32，ttwid长度127，所属 .douyin.com、path `/`，正常未来expiry。只消费三项；**本轮不读取或提供UIFID**。
- 本人登录确认true，challenge完成确认false；无法断言challenge出现/完成，未自动处理任何challenge。
- 新profile初始化空集；结束DeleteAllCookies + ClearBrowsingData成功，scoped Cookie空集true，浏览器退出true，profile删除true，独立存在性复核false。helper和child均结束。
- 窗口首次被启动参数隐藏，恢复同一进程窗口，没有重建session或自动操作平台页面。
- 没有保存真实Cookie/原始payload/CDN URL/密码到Git、fixture、报告或日志。环境输入只在外部child，stderr长度0。仓库外保留脱敏fixture、验证脚本、结果及session元数据，profile已删除。
- 原F2 token初始化与正常页面加载另有平台请求；detail API调用1次，无重试、无媒体资源HEAD/GET/下载。不是全轮HTTP包总数为1。

## 29项答复

| # | 项目 | 结果 |
|---|---|---|
| 1 | 推荐architecture | B最小F2协议模块 + Windows/Android私有SessionAdapter + 同一DartGalleryAdapter + 现有下载/History；具体在线backend尚未实现 |
| 2 | 不选A/C原因 | A整包Python依赖过重且Android未证实；C两套协议维护与延期双端风险，只允许有界spike工具，不作为最终架构 |
| 3 | Python runtime | 本轮仓库外取fixture使用既有Python3.13.11；推荐正式架构无需Python；没新增production runtime |
| 4 | Windows | 独立WebView2 session provider + 私有detail执行器；一旦在线backend资格通过，复用当前adapter/现有资源UI/Downloader做spike |
| 5 | Android | 专用SystemWebView session隔离 + 私有executor + 相同Dart协议/adapter + existing MediaStore下载；隔离与协议需真机证明 |
| 6 | 生命周期 | 私有profile/安全存储、opaque handle/epoch、失效撤销、用户选择刷新、退出取消在途/清平台数据/验证消失；清理失败不伪装成功 |
| 7 | 用户登录 | 当前F2成功样本使用正常登录会话；未证明所有Douyin解析普遍必须登录，产品匿名优先仍保留 |
| 8 | 失效UX | 明确提示重新登录，由本人主动选择；安全/权限/地区/付费错误单独返回，不自动叠加context重试 |
| 9 | F2复用范围 | 未来评估detail参数构造、实际签名调用闭包、基础headers/token初始化、响应字段；本轮只设计参考与原外部调用，未复制协议/signer到production |
| 10 | source/license | Johnserf-Seed/f2 / a30feaf92a40f421273b01b6ef36aa83a93f63c0 / Apache-2.0；采用时保留来源、版权、LICENSE、修改记录/适用NOTICE，依赖另审计 |
| 11 | x-tt-argus | 原默认1确实存在；必要性UNKNOWN，离线不能证明服务端依赖；无生产采用/网络消融。限制于原F2行为验证，不将其视作平台签发context |
| 12 | MediaContent修改 | 无；既有 imageGallery 与 ordered resources 足够 |
| 13 | MediaResource修改 | 无；id/type/url已足够，resourceIndex由existing list index表达。没有凭空声称新增resourceIndex属性 |
| 14 | adapter测试 | 18项全部通过，覆盖目标/类型/13图/URL及顺序/稳定唯一id/13task/凭据隔离/缺字段/坏中间项/空images/错误类型/不安全URL/业务错误 |
| 15 | 13图映射 | 是，一份MediaContent含13个image资源，基于真实响应脱敏fixture |
| 16 | 顺序 | 是，上游数组顺序原样保持，索引0–12，坏项拒绝整次映射，不跳项 |
| 17 | 13 DownloadTask | 是，由existing downloadTasksFromMediaContent生成；task[i]对应resource[i]，内容/资源id一致，公共mapper未改 |
| 18 | Windows spike | 未执行；在线backend/session实现与默认workaround生产资格未完成，风险不满足可控条件 |
| 19 | spike取得13图 | 无production spike；外部F2本轮再次返回13图，仅用于真实fixture |
| 20 | 下载2不同图片 | 未执行本轮真实CDN下载，不能标通过；unit测试的本地服务下载不是该目标实测 |
| 21 | 图片Windows打开 | 未执行该目标实际文件解码/打开，未标IMAGE RESOURCE或WINDOWS SPIKE PASS |
| 22 | Android下一阶段唯一目标 | 在Windows spike通过并暂停后，Android App-owned session + static gallery detail backend + existing MediaStore等价验收；本轮未开始Android开发/安装 |
| 23 | flutter analyze | 全仓库49条既有research info/lint，退出1；lib test定向分析No issues found。新adapter/tests无问题 |
| 24 | flutter test | 完整unit/widget suite 184 passed、5 skipped，退出0；包括18新adapter测试。原模型/mapper/旧Douyin视频定向回归41通过。跳过的live验收不算通过 |
| 25 | 文件 | 见清单；没有删除文件、新增依赖或公共模型变更 |
| 26 | Git status | feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；既有 M AGENTS.md和?? v0.4.0/保留，另新增gallery源码/tests/fixtures为untracked |
| 27 | production修改 | lib新增离线adapter和能力契约；未改/接入DouyinParser、ParserService、正式UI、Downloader、History、模型或依赖。不写“production完全无修改”，但现有行为入口未变 |
| 28 | Git写操作 | MediaFlow仓库无add/commit/push/merge/tag/PR/reset/checkout。Flutter首次analyze自动尝试SDK仓库fetch --tags，网络失败；不是MediaFlow Git操作，也未手动授权/执行提交。后续--no-version-check避免再触发 |
| 29 | 目标兼容性 | 详见architecture完整检查；本轮公共纯Dart链回归通过，正式在线五端/图片下载未验收 |

## 验证、文件与Git

- 新增源码：`lib/features/parser/data/douyin/gallery/douyin_gallery_adapter.dart`、`douyin_gallery_capabilities.dart`。
- 新增测试：`test/features/parser/douyin_gallery_adapter_test.dart`。
- 新增fixture：`test/fixtures/douyin/authorized_gallery_13_sanitized.json`、`authorized_gallery_13_provenance.json`、`README.md`。
- 新增文档：本报告、`gallery-integration-architecture.md`；修改 v0.4.0/README.md、research/README.md、research/poc/h2/README.md 状态导航，明确永久冻结和本轮离线完成，保留历史。
- 外部新增：既有F2验证目录内 `capture_gallery_fixture.py`、`CaptureGallerySession.cs/.exe`、脱敏fixture、capture结果、fixture-session元数据日志。没有修改F2原源码。
- 删除：无。新增正式依赖：无。pubspec及lock未变。
- 外部helper编译第一次因脚本默认GBK读取失败，改UTF-8后编译通过；仅工具准备错误，没有提前请求平台。adapter源码/测试dart format通过；git diff --check通过。
- `flutter analyze` 首次产生49条旧research提示；未为通过而删除研究代码或调低lint。定向 `flutter --no-version-check analyze --no-pub lib test` 无问题。
- `flutter --no-version-check test --no-pub`：184 passed / 5 skipped。真实HTTP/Bilibili production opt-in测试未启用，原浏览器/Feed测试为离线回归，不是恢复冻结路线。
- Windows/Android正式build未运行；Android无设备安装/覆盖/卸载/清数据。iOS/macOS/Linux未构建/实测。
- Flutter自动重写3个Windows generated文件LF；核对git diff无内容变化，仅恢复CRLF，最终均不在status；未覆盖任何已有用户代码。
- `git diff --stat`：只有既有tracked AGENTS.md，31 lines / 23 insertions / 8 deletions。新文件untracked不计入tracked stat；不能写本轮零文件变更。AGENTS未改动。

最终状态：设计与离线集成完成，Windows/Android真实生产链尚未完成。本轮暂停，不自动开展协议移植或production spike。
