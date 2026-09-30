# 参考项目：ucmao/media-parser（首轮，2026-09-25）

证据分级：以下来自[仓库](https://github.com/ucmao/media-parser)、[Douyin Parser 源码](https://github.com/ucmao/media-parser/blob/main/src/parsers/douyin_parser.py)与[项目技术说明](https://github.com/ucmao/media-parser/blob/main/docs/parsers/douyin.md)。项目运行成功率及匿名能力未由 MediaFlow 本阶段实测。

| 项目 | 记录 |
| --- | --- |
| 仓库地址 / 维护 | [ucmao/media-parser](https://github.com/ucmao/media-parser)；仓库主页显示 212 commits、测试目录与近期可访问源码；确切最近提交时间未核实 |
| LICENSE | 仓库有 [MIT LICENSE](https://github.com/ucmao/media-parser/blob/main/LICENSE)；若未来复用代码需留原版权和许可证，本轮只参考设计 |
| 关键实现 | `src/parsers/douyin_parser.py`、`src/parser_factory.py`、`docs/parsers/douyin.md`；框架还有 Python Web API、运营服务与数据库，不能整套移植 |
| 分享链接与 ID | Parser 从作品 URL/短链得到 `aweme_id`，然后尝试不同入口；短链具体提取规则本轮未逐行确认，留待第二阶段核实 |
| 数据入口 / 参数 | 常规视频先尝试 `api5-normal-c-hl.amemv.com` / `aweme.snssdk.com` 的 `/aweme/v1/feed/`（`aweme_id`,`aid=1128`）；图文分支优先 Web detail `https://www.douyin.com/aweme/v1/web/aweme/detail/`，含 `aweme_id`,`aid=6383`,`device_platform=webapp`,`channel=channel_pc_web`,`pc_client_type=1` 等；分享页 `https://www.iesdouyin.com/share/video/<id>` 作 SSR 路线。源码已核实。移动 feed 对图文有效性未证明，v0.3.0 三个 note 样本均 targetMissing |
| Headers / Cookie / Token | 移动 feed 代码声称无 Cookie；分享页使用移动 UA、Referer 和项目构造的 Cookie 头，可合并用户 Cookie、ttwid 与会话 Cookie；Web detail 加 `msToken`、`a_bogus`，可用 UIFID/uifid 头与 `x-secsdk-web-signature`。所以“项目可选 Cookie”不等于“图文匿名可用” |
| 图文判断 / 图片 | `get_image_list()` 按 `image_post_info.images`、`image_post_info.image_list`、顶层 `images`/`image_list`/`image_infos`/`original_images` 扫描；每项优先 `url_list`，再试 `display_image`、`image_url`、`download_url` 等。字段为源码线索；是否仍为实时结构未实测 |
| 浏览器 / 服务器 / 依赖 | 主实现使用 Python HTTP，不要求本地浏览器；项目自身可作为 API/运营服务器运行，MediaFlow **不得调用其服务器**。源码含 `verify=False`、固定 fallback ttwid、对 403 退避重试与签名更换；这些方案不能直接移入 MediaFlow production |
| Windows / Android | 本地 HTTP/SSR 路径理论上可由 Dart 双端实现；但 Windows 旧探测未得目标图片，Android 未复现。UIFID/网关和时效性是双端共同阻断 |
| iOS / macOS / Linux | 仅有平台无关 HTTP 的理论路径；需未来平台 Adapter/真实验证 |
| MediaFlow 决定 | **只参考入口顺序、结构字段和适配边界；不复用代码、服务、Cookie/UIFID/重试绕过逻辑。** 分享页 SSR 可列为探索候选，但不能把项目文档的匿名声明当验收 |

特别区分：该项目的多入口是一个项目的降级链，不是多个独立来源。`DLWangSan` 与它同用 Web detail host/path；参数相似只说明共用平台入口，不证明匿名必要条件已被交叉证实。
