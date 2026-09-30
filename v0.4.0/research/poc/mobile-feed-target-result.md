# Mobile Feed 本轮结果：M3（2026-09-28）

> 后续用户另行批准的一次通用UA排疑已结束：HTTP200/4其他作品/目标缺失，Mobile Feed gallery候选关闭，真实请求1；见[新实验报告](generic-feed-once-result.md)。本文下方“0请求/未执行”保留为此前设备UA被拒阶段的准确历史，不覆盖新记录。

**RESULT M3 — Reference Mobile Feed does not serve galleries，严格限定当前参考源码控制流。**已证明明确note/slides图文分支跳过Mobile Feed，视频成功不能用来推断图文主路线。没有证明Feed接口在所有环境永远不支持图文，也没有通过新实测解释服务器内部为何给出其他作品。本轮Feed请求 **0**，实验M1/M2均未执行。

请求全表、UA、源码行号、v020/v040差异矩阵及先于网络写入的预案：[离线审计](mobile-feed-target-audit.md)。当前源码提交`ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6`（2026-09-28），通过GitHub HEAD查询后按固定SHA取parser/base/transport/tests/docs/LICENSE；旧固定SHA不当作当前版本。读取当前根规则及本轮要求的已有研究、v020 production/feed验收定义和历史记录；不更改历史结论。

## 自动审批阻断与安全收口

工具在进程启动前拒绝了计划的参考UA请求，理由：**该UA包含Android Pixel/Build/Cronet的移动设备身份声明，审核认为与项目禁止伪造设备指纹规避风控冲突**。本轮未发出任何Feed请求，没有平台status或response，更不能生成虚假的network JSONL。没有换工具/代理/HTTP库绕过拒绝。

探针CLI已明确禁用网络，原请求预案保留为不可调用注释，仅安全的离线响应检查函数/测试可运行。`--run`本地返回77，不访问平台。已询问用户是否按M3收口，或另行批准不含设备身份声明的通用UA方案；没有将等待时间当作授权，未执行依赖该回答的动作。通用UA无法严格复现参考设备UA，也不保证新增证据价值。

## 参考项目实际路由与下一步

源码88行识别note/slides及share形态；823–842行先Web detail，终端filter立即结束，否则分享SSR，随后return。845行视频Feed调用只有非note才能到达。常规视频顺序是主Feed→备用Feed→分享SSR→Web detail→末级SSR。所谓Mobile Feed主路径、无Argus宣传主要针对常规视频；图文文档说静态原图依赖SSR，不是Feed。图片decoder读取images等字段不会改变它们的获取来源。

本轮发现具体后续入口：`fetch_html_content:104–146`把普通作品（包括note）统一改写为 **`https://www.iesdouyin.com/share/video/<id>`**，使用特定移动Web UA/Referer并附加 `_get_ttwid`、Cookie header及可用UIFID；`_try_share_ssr_detail:443+`从该HTML中取aweme_detail。旧closeout的`www.douyin.com/share/note`、`www.iesdouyin.com/share/slides`并非这条相同的页面路径，不能把旧阴性结果当成对当前fallback的严格复现。该代码附加身份材料，**不证明其SSR真实依赖这些材料，也不证明匿名可用**；本轮没请求它、不重新研究UIFID/signer/login。

**下一轮唯一建议目标：离线审计当前参考的 `iesdouyin/share/video → SSR aweme_detail/images` 数据来源和最小匿名请求条件。**先定位正常HTML数据包装、target绑定、headers与既有失败入口差异，评估是否有新信息收益，再另立有界实验；不自动恢复Web detail、Context Provider或Browser，不直接采用其Cookie/固定机型UA。当前参考Feed图库主候选停止投入（作为“已证实图库路线”NOT VIABLE），不宣传所有Mobile Feed图库不可行。

旧备用返回5其他作品的最可信**假说**是目标类型/节点收录未进入定向返回，响应呈推荐列表；证据不足以证明服务端忽略aweme_id或UA触发了推荐路由。相对v020 production，旧v040只显著变了host和目标内容类型，UA与两参数相同；相对参考实现还有专用UA、宽Accept和不同selection/transport。本轮未运行UA对照，不能声称UA已被证实为原因。具体未验证变量为**专用UA是否改变该目标的Feed选择行为**，不扩成泛化签名猜测。源码note路径跳过Feed解释了参考gallery能力来源，而非给出平台内部推荐机制的证明。

## 必答22项

| 问题 | 答案 |
|---|---|
| 1 完整Mobile Feed请求 | GET，主api5/备用snssdk，`/aweme/v1/feed/?aweme_id=<id>&aid=1128`；专用Android app UA，Accept json/plain/*；详见离线全表 |
| 2 图文进入Feed？ | 明确note/slides分支不进入；绕过note检测的其他链接只能算非note调用，不是已验证gallery支持 |
| 3 v020差异 | v020通用MediaFlow UA/窄Accept/单主host/强制视频完整性；参考双host、专用UA、aweme_id或id首个匹配即接受 |
| 4 旧5其他作品原因 | 目标/节点收录假说最可信，UA路由未验证；不能下因果定论 |
| 5 实验M1 | 未执行，auto-review启动前拒绝；没有HTTP结果 |
| 6 实验M2 | 未执行，M1条件未成立 |
| 7 target命中 | 本轮未测；旧实验未命中 |
| 8 aweme_type | 本轮目标未知，不拿其他作品type替代 |
| 9 images | 目标本轮未取得 |
| 10 图片URL | 未取得/未请求/未下载 |
| 11 绕过Argus/UIFID？ | 源码有不同host/路径，文档称视频不经过PC网关；本轮没验证图文或网关行为 |
| 12 Cookie需要？ | Feed方法不显式需要，但共享session可能自动带Cookie；匿名图文必要性未测 |
| 13 signer需要？ | Feed方法没签名调用；本轮没证明下一阻断，不研究signer |
| 14 fallback | note：Web→SSR→结束；video：Feed主/备→SSR→Web→末级SSR |
| 15 下一唯一目标 | 静态审计reference实际iesdouyin/share/video SSR gallery入口及最小匿名条件 |
| 16 文件 | 下方清单；无production/UI/Downloader改动 |
| 17 网络数量 | Douyin Feed 0；Web detail/Browser/media 0；只读GitHub源码请求独立计，不是平台实验 |
| 18 检查 | 两Dart脚本analyze无问题、10离线断言通过；format通过但flutter_lints include未解析；生产build/lint未跑 |
| 19 Git | feature/v0.4.0、HEAD不变、M AGENTS.md / ?? v0.4.0/ |
| 20 production | 无修改 |
| 21 Git写操作 | 无add/commit/push/merge/tag/reset/删除分支 |
| 22 项目兼容性 | 见下方；双端图文仍BLOCKED |

## 修改、测试和参考许可

本轮修改：`v0.4.0/README.md`、`v0.4.0/research/README.md`。新增：`mobile-feed-target-audit.md`、本结果报告、`mobile_feed_target_probe.dart`、`mobile_feed_target_probe_test.dart`、`mobile-feed-target-offline-tests.json`。删除代码/文档：无。真实network日志未创建，拒绝不当作平台失败。

设计采用独立纯Dart inspection，避免production单视频validator过滤目标图文，也避免把其他作品资源当目标。无新增依赖；没有复制第三方代码或执行reference Python。参考ucmao/media-parser，根MIT，借鉴请求/路由结构，未搬decoder或signer，额外signer许可风险冻结，无新增attribution要求。当前reference新增代理transport只做静态审计，未采用代理功能/远程服务；TLS本轮设计正常校验，不照搬verify=False。

最终`dart analyze`两文件No issues found；10离线断言PASS（其他作品不冒充目标、目标精确匹配、id回退、重复目标、图片数组、URL脱敏、错误结构与安全拒绝）；仅合成数据，不代表真实Feed成功。formatter成功，根flutter_lints include不可解析的既有警告保留，不能声称完整Flutter lint通过。最初dart.bat无输出被取消，改用现有SDK exe；初次cascade语法问题修正后定向检查通过。CLI禁网验证本地exit77，0请求。

未运行Flutter analyze/test/生产回归、Windows Flutter build、Android build/安装、iOS/macOS/Linux构建。没有第二样本、真实Feed、图片URL访问、跨平台gallery或性能验收。本轮current源码展示的mock tests是第三方单元合同，不替代MediaFlow网络证据。

## 【项目目标兼容性检查】

| 平台 | 本轮状态与限制 |
|---|---|
| Windows | 本地Dart离线检查已实际运行；Feed实际请求未执行、生产build未运行；设备身份UA复刻被审批阻断 |
| Android | HTTP/Dart理论路线，历史视频成功不能证明图文；本轮未构建/实测/安装；无覆盖/卸载/设备数据清除，package/签名检查不适用 |
| iOS | 纯Dart inspection理论兼容，未build/实测；Feed客户端行为与平台许可须另验 |
| macOS | 同上，未build/实测；Windows离线不作功能保证 |
| Linux | 同上，未build/实测；真实TLS/服务端返回未验证 |

| 模块/目标 | 实际检查与风险 |
|---|---|
| Bilibili / Douyin | 未改production/未回归；Douyin视频合同保留但本轮不重测，图文尚未可用 |
| Xiaohongshu / YouTube / X / Instagram / 其他未来平台 | 未接入/未测试，平台逻辑仅Douyin research，无公共条件扩张 |
| PlatformDetector / ParserService / UI | 未改/未回归；图文路由/能力判断需来源证据后另做渐进集成 |
| Parser / Adapter / Browser Adapter | 独立research decoder；不修改正式Parser；Browser/Context停止，不扩网络采集 |
| Unified Content Model / MediaContent / MediaResource | 未改；inspection按精确作品和数组顺序检查，未来多资源可映射但当前无成功证据 |
| Downloader / Media Processing | 未改/未回归、无下载/处理，资源URL只存字段/host/特征，不进入媒体请求 |
| History / Settings / Logging / 本地存储 | 未改生产；研究只元数据/源码结论/合成测试，无凭据/响应正文持久化 |
| 隐私 / 零服务器 | 无第三方解析、账号Cookie、Token、session上传；GitHub只读公开源码；实际Douyin请求0 |
| 依赖 / 包体 / 性能 / 维护 | 无新依赖/打包配置变化，包体未测；planned 2MiB/25秒非实测性能；节点定向行为、UA依赖和参考路由更新是风险 |
| 正式发布 | 无双端目标图库证据，production BLOCKED；M3只表示参考控制流，不宣称平台全部图库不可行 |

## Git状态与暂停

cwd/top-level `D:\projects\mediaflow-v040`；branch `feature/v0.4.0`；HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。根规则diff本轮开始已有，本轮未改。

`git diff --stat`（tracked，不包含既有untracked研究目录）：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

`git status --short`：

```text
 M AGENTS.md
?? v0.4.0/
```

`git diff --check`只验证tracked diff；新增文件定向analyze/test已测。完成后暂停；不把待答UA问题视为授权，不自动开始SSR请求或生产集成。
