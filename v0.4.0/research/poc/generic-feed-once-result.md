# Mobile Feed 通用 UA 排疑：唯一请求结束（2026-09-28）

**Feed target lookup not reproduced under generic anonymous UA。按用户规则关闭 Mobile Feed gallery 候选，不再追加实验。**本实验不是media-parser请求的严格复现：未使用、模拟或间接执行含Pixel/Android Build/Cronet声明的参考UA。前轮源码结果M3（明确note/slides跳过Feed）保持，单个HTTP结果不改写该控制流事实。

## 结果与历史对比

一次请求，开始UTC `2026-09-28T11:23:27.936365Z`。原始安全元数据：[generic-feed-once.jsonl](generic-feed-once.jsonl)。

| 项目 | 本轮 |
|---|---|
| endpoint | `GET https://aweme.snssdk.com/aweme/v1/feed/`，与历史返回5其他作品的host/path相同 |
| query/顺序 | `aweme_id=7690029886242009957&aid=1128` |
| UA / 类型 | `MediaFlow/0.4.0`；诚实应用标识，无OS、手机型号、Build或Cronet身份声明 |
| Accept | `application/json`，与历史保持相同 |
| Cookie / Token / signer / device params / proxy | 全部未发送/未使用；无Referer附加，无redirect follow |
| status / JSON status_code | HTTP200 / 0 |
| MIME / body length | application/json / **228942 bytes** |
| redirect / Set-Cookie | false / false |
| aweme_list | **4**，精确目标匹配 **0** |
| 公开作品ID | 7685361836103387366、7681094764376717737、7688699107724021027、7679585824869977390 |
| 返回项type | 四项均aweme_type=0；不是目标作品类型 |
| 图文相关字段名 | 四项均有images、image_infos、original_images；没有证明这些值非空或属于图文资源 |
| 目标images / URL | 未取得目标对象，因此目标资源未验证；不拿其他项字段冒充目标 |
| 媒体请求/下载 | **0** |
| 本轮Feed请求 | **1**；无第二host、UA变更、重试或设备参数追加 |

历史同endpoint/target/aid/Accept、UA=`MediaFlow/0.2.0 (anonymous local HTTP client)`返回HTTP200/291038bytes/5其他作品；本轮UA仍属不声明设备的通用类，返回HTTP200/4其他作品。**只证实更换为此通用UA仍未恢复目标lookup**，不能认定所有UA都无作用、证明历史5作品的确切来源，或把推荐状列表证明为服务端内部推荐机制。两次跨时刻请求同时存在时间/服务端状态差异，返回数量变化不能归因于UA。

最稳妥解释仍是“该目标未进入此endpoint的定向返回，得到其他作品列表”；节点收录/内容类型/请求选择语义原因未确定。本轮没有证据指向Cookie、signer或缺少设备参数。也没有证明目标被删除/权限限制。使用通用UA的单次排疑信息增益到此为止，候选关闭是本轮路线决策，不是所有平台图文能力的全称否定。

## 实现与验证

新增独立 `generic_feed_once.dart`，只允许固定已授权目标/endpoint，一次GET，无循环/fallback。使用现有Dart HttpClient、TLS正常校验、DIRECT、禁redirect，25秒/2MiB上限。结果文件在网络前独占预留，已存在则本地exit73，防止重跑；失败也不删reservation重试。复用MediaFlow自己前轮的inspection函数，不调用被拒绝的UA或旧禁网main，不复用第三方实现。响应正文仅在内存检查，日志只有公开ID、字段名、长度和安全状态，不保存URL、Cookie或body。

返回项gallery字段仅记录key存在性，值/数组长度未被保留；原始body未保存，不能事后宣称数组为空/完整或重新检查实际值。目标命中为false，未进入目标imageArrays检查，无必要追加请求。

定向 `dart analyze generic_feed_once.dart`：No issues found；`dart format`成功，但根analysis_options的flutter_lints include解析警告仍在，不能标记全量Flutter lint通过。前轮inspection的10条合成离线断言本轮重新执行通过，0网络；覆盖目标匹配、其他项不能冒充、URL脱敏和安全错误分类，不能替代真实图文成功。本轮真实请求输出与保存日志一致，JSON已复核。

未运行生产Flutter analyze/test/lint、Windows/Android应用构建、iOS/macOS/Linux构建、真机安装/替换/卸载、图片URL验证/下载、production parser集成。研究脚本直接运行是本轮Windows主机HTTP实测，不能叫正式应用构建通过。

修改已有文件：v0.4.0/README.md、v0.4.0/research/README.md、mobile-feed-target-result.md（只追加本次链接，前轮0请求历史不改）。新增：generic_feed_once.dart、generic-feed-once.jsonl、本报告。删除代码/文档：无。根AGENTS.md修改是此前已有，本轮未改。无新依赖/服务/第三方代码复制；参考项目与根MIT/文件级signer许可风险仍为前轮静态审计，本轮不新增采用或attribution。

## 【项目目标兼容性检查】

| 平台 | 本轮状态 |
|---|---|
| Windows | 独立Dart HTTP请求已实际测试；目标lookup失败，生产build/回归未运行 |
| Android | HTTP/inspection理论兼容；本轮未构建/实测/安装，历史视频不能替代gallery验收 |
| iOS | Dart inspection理论兼容；未构建/实测，平台Feed行为未知 |
| macOS | 同上，未构建/实测 |
| Linux | 同上，未构建/实测 |

Bilibili、Douyin生产视频、PlatformDetector、ParserService、UI、History、Settings、Logging、本地生产存储均未修改/回归；不追加功能通过结论。Xiaohongshu/YouTube/X/Instagram及未来平台未接入，此研究未引入公共平台特例。Parser/Adapter独立边界保持；Unified Content Model/MediaContent/MediaResource未改，目标资源不足，不能映射成功。Downloader/Media Processing未改、无媒体操作。Browser/Local Context保持停止，不重新研究UIFID/login。隐私/零服务器：只访问所属平台公开endpoint，不用第三方解析，不传凭据，不记录媒体URL或账号数据。无新依赖或生产打包变更，包体/性能基准未测；服务端非定向行为、来源控制流与数据来源变化仍是维护风险。正式发布/双端图文验收依旧BLOCKED。

Android安全：没有设备安装、覆盖、卸载、清数据；applicationId/签名核对本轮不适用。

## 下一路线与暂停

**不再围绕Mobile Feed gallery追加实验。**下一主路线是新的参考实现横向审计：核实当前项目真正使用的gallery Web detail、分享SSR或其他独立gallery endpoint，分别记录实际控制流、数据来源、最小上下文、许可证和双端维护成本。重点区别reference实际`iesdouyin/share/video` SSR与历史share/note/slides路径，不把文档宣称当作成功证据，也不照搬附加Cookie/设备UA。本轮没有开始这些网络实验或横向审计，不自动恢复UIFID、Browser或Login旧循环。

cwd/top-level `D:\projects\mediaflow-v040`，branch `feature/v0.4.0`，HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`不变；无Git写操作。

`git diff --stat`（tracked，不含已有untracked v0.4.0目录）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：

```text
 M AGENTS.md
?? v0.4.0/
```

`git diff --check`通过（tracked范围）。按要求完成后暂停。
