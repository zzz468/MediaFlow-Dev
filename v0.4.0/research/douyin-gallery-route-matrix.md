# Douyin 图文首轮候选路线与同源关系（2026-09-25）

> 当前研究主路线切换为 **Web detail + 本地 signer**；Browser **STOPPED AS PRIMARY ROUTE / RETAINED AS FALLBACK / DEBUG**，不扩展、不删除。新baseline403/46bytes、Argus UIFID安全停止，B/C未测、Cookie必要性未证；DL signer GPL来源与uc a_bogus.js商业限制需文件级许可审计。见[最新审计](poc/web-detail-signer-route-audit.md)。旧降级建议被本轮替代，历史请求结果不变。

## 最新收口：Browser停止，替代路线结果C（2026-09-27）

Browser Observation = **STOPPED / NOT VIABLE FOR v0.4.0**，触发本轮硬结束条件D：缺少证据证明剩余候选具备明显信息增益。上一轮JSON原文及DOM未保存，不能声称重新解码或证明页面无数据；helper对象根限制已静态确认，实际ERROR原因仍未确认。本轮Browser导航0，不改helper或production。

替代路线四个受控匿名GET：备用feed200/5其他作品无目标；share/note200含ID但未解析目标图片对象；share/slides200无目标；旧iteminfo200空正文。无Cookie/Token/签名/代理/重放，无图片下载。**Douyin gallery production feasibility = BLOCKED**，结构/URL NOT VERIFIED，下载NOT TESTED，Level1H Human PASS保持。

结果C：已调查的合法入口均暂未得到可用结构；建议v0.4.0明确图文原图暂不支持，保留现有视频与Bilibili多资源/重试/恢复/History目标。元数据、缩略图同样未证明，不宣传已支持。下一轮唯一建议目标是确认降级范围与验收清单，不再回Browser，不自动进入第三阶段。

Windows Network BLOCKED/normal cleanup FAIL/recovery历史PASS；Android生命周期、离线安全停止、cleanup历史PASS，real bridge仅JSON链PASS、真实安全停止NOT TESTED/Network BLOCKED。本轮不重跑旧平台实验。双平台production门槛未达。

完整决策、路线表、真实响应摘要、证据限制和兼容性检查：`v0.4.0/research/poc/browser-closeout-route-decision.md`；网络摘要：`anonymous-route-closeout-network-results.jsonl`。以下旧“剩余Browser候选/继续真实导航”仅为历史记录，已被本节替代。暂停等待指令。

本表是**源码与文档线索的交叉比较**，不是 MediaFlow 的实时网络成功结果。MediaFlow 本阶段未请求 Douyin、未取得图文 JSON 或图片直链、未做 PoC。所有路线均待第二阶段按[执行规则](execution-rules.md)独立、有限地验证。旧版失败事实见 [v0.3.0 调查](../../v0.3.0/research/douyin-gallery-source.md)。

| 路线 | 参考与数据入口 | 匿名 / Cookie / Token / 签名 / 浏览器 / 服务器 | Windows / Android 初判 | 当前证据与阻断 |
| --- | --- | --- | --- | --- |
| A. 匿名移动 feed | `ucmao` 与 MediaFlow 既有视频路径：`api5-normal-c-hl.amemv.com`、`aweme.snssdk.com` `/aweme/v1/feed/` | 项目称视频无 Cookie、UIFID、签名；纯 HTTP、无解析服务器 | 两端已有视频实现基础；图文需各自证明收录和资源字段 | **图文弱证据**：v0.3.0 三个 note 候选在 Windows 均 `targetMissing`；备用 host 对图文未验证。不能把视频成功推广至图文 |
| B. Web detail API | `DLWangSan`、`ucmao`、`jiji262` 共用 `www.douyin.com/aweme/v1/web/aweme/detail/`，通常 `aweme_id` + `aid=6383` | 代码路径常有 A-Bogus / X-Bogus、`msToken`、ttwid 或可选用户 Cookie；`ucmao` 还可用 UIFID。是否能无账号、无挑战成功未证明；本地 HTTP 可实现，不依赖第三方服务器 | Windows 理论可行；Android 需避免 Win32 固定设备参数，两端均受网关影响 | **同一数据入口的多个项目，非三条独立平台证据**。v0.3.0 无 Cookie Web detail 对候选为 403；`jiji262` 当前 README 明示 CLI 单条图文请求验证阻断。绕过网关/伪造指纹/高频重试不能接入 production |
| C. 分享页 SSR / 页面内嵌 JSON | `ucmao`：`www.iesdouyin.com/share/video/<id>` 的 `_ROUTER_DATA`、`videoInfoRes`；普通 `www.douyin.com/note/<id>` 页面状态另可观察 | 理论上可匿名读公开 HTML，但项目实现仍可合并 Cookie/ttwid；不必动态签名、无解析服务器，可能需要正常浏览器 JS；真实必要条件未核实 | Windows/Android 均可有限 HTTP 或 Adapter 验证 | v0.3.0 三个候选的移动分享页仅路由壳、公开 note 页含安全验证。需新的明确公开多图样本并区分路由 ID 与媒体数据 |
| D. Browser Observation | `Ortonzhang` 的 Puppeteer 观察 `aweme/detail` / `slidesinfo` 已加载响应和页面状态；MediaFlow 已有 Windows/Android Browser Adapter 边界 | 浏览器可能自动持有匿名会话 Cookie/Token/签名；不应导入用户登录态或主动求解挑战。其服务/代理实现不可采用 | Windows WebView2、Android System WebView 理论可行，均未对图文实测 | 观察的是页面是否**本来已加载**目标结构化数据；若页面显示登录/验证即安全停止。Orton 无 LICENSE，不复用代码；可能与路线 B 同源响应，不计作独立数据源 |
| E. 登录 Cookie / Token 路线 | `DLWangSan`、`jiji262` 使用扫码或导入用户 Cookie；`ucmao` 可用用户 Cookie/UIFID | 需要用户账号或从登录环境取得身份数据 | 技术上可运行不等于符合 MediaFlow | **不符合 production 边界**；只能说明第三方为什么可能成功，不能作为第二阶段接入路径 |
| F. 第三方解析服务 / 代理 | `ucmao` 的部署 API、`Ortonzhang` 的 Express `/api/analyze` 和流代理 | 用户链接或媒体经独立服务处理 | 与两端本地解析目标冲突 | **不采用**；不向外部服务上传用户链接/Cookie/媒体，不代理用户流量。可借鉴其本地解析模块的设计思想 |

## 交叉确认与差异

- 多项目确认 `/note/<id>` 可作为**ID 线索**，`aweme_detail` 的图集字段可能是 `image_post_info.images`、`image_post_info.image_list` 或顶层 `images`；这些是代码约定，尚无 MediaFlow 当前响应确认。`jiji262` 与 `ucmao` 都扫描 `image_post_info`，`DLWangSan` 主要读顶层 `images`，说明兼容扫描是项目选择，不能假定每个字段都必需。
- `DLWangSan` 取首个 `url_list`，`ucmao` 可取末项，`jiji262` 按镜像/尺寸/水印排序；**哪条 URL 可匿名真实下载未证实**。第二阶段必须按出现位置保存图片，至少验证两张；不能凭字段或 HEAD 推断真实文件。
- `DLWangSan` 的 set 去重会改变重复图片语义；MediaFlow 已有 Bilibili 多资源位置合同，不能照搬。`jiji262` 的“每位置多个镜像候选”可作为设计参考，但只在真实失败案例证明必要时考虑。
- `cmsjin/douyin` 与 `jiji262/douyin-downloader` README/目录高度相似，暂列**疑似同源**，不计入多来源成功证据。四个重点独立候选项目的代码谱系尚未完成 commit/hash 审计；相同 host/path 的项目即使彼此无 fork，也共用同一平台数据入口。
- `Ortonzhang` 浏览器观察和 Web API 可能读取同一 Douyin 响应；实现机制不同，平台数据来源未必独立。其页面 JSON/DOM fallback 需逐级确认目标 ID、资源数量和顺序。

## 第一阶段结论与第二阶段候选清单

**未选定 production 路线。** 优先供第二阶段独立 PoC 比较的是：① 无用户登录态的分享页/公开页面内嵌数据；② 有界的本地 Browser Observation；③ 无 Cookie/Token 导入且不触发安全验证的匿名 HTTP 数据入口。移动 feed 可做一次有界对照，但已有 note `targetMissing` 不能反复盲试。Web detail 若要求伪造指纹、重放身份令牌或规避 WAF，就停止该入口。候选之间需使用同一明确公开多图作品，并分别记录 Windows 与 Android 的目标 ID、结构字段、至少两张直链及实际下载/MIME。

当前缺口：没有新的目标作品实时结构化结果、没有两张可下载图片、没有 Android 复现、没有可证明稳定的 fallback。Douyin 图文状态继续为 `researched but not production-supported`。建议下一阶段仅做独立最小 PoC；只有全部 production 门槛满足才可讨论正式接入。
