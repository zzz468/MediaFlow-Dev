# 参考项目：jiji262/douyin-downloader（首轮，2026-09-25）

证据分级：来自[仓库](https://github.com/jiji262/douyin-downloader)、[`core/api_client.py`](https://github.com/jiji262/douyin-downloader/blob/main/core/api_client.py)、[`core/url_parser.py`](https://github.com/jiji262/douyin-downloader/blob/main/core/url_parser.py) 与 [`core/downloader_base.py`](https://github.com/jiji262/douyin-downloader/blob/main/core/downloader_base.py)；MediaFlow 未运行项目或验证目标作品。

| 项目 | 记录 |
| --- | --- |
| 仓库地址 / 维护 | [jiji262/douyin-downloader](https://github.com/jiji262/douyin-downloader)；主页显示 99 commits、tests、开放 Issues/PR。README **当前明确提示**：CLI 单条视频/图片等下载受 Douyin 请求验证阻断，更新 Cookie 或重试也不能解决；不能用旧 README 的“支持图集”代替当前可用性 |
| LICENSE | 仓库有 [MIT LICENSE](https://github.com/jiji262/douyin-downloader/blob/main/LICENSE)；本轮未复制代码，未来若复用需保留声明 |
| 关键实现 | `core/url_parser.py`、`core/api_client.py`、`core/downloader_base.py`；配置/认证模块及 Playwright browser fallback 另在项目内 |
| 分享链接与 ID | URLParser 识别 `/note|gallery|slides/<id>` 为 gallery，`note_id` 同时映射 `aweme_id`；短链解析/重定向的完整调用链本轮未核实 |
| 数据入口 / 参数 | `DouyinAPIClient.get_video_detail()` 请求 `https://www.douyin.com/aweme/v1/web/aweme/detail/`；`aweme_id`、`aid` 依次 6383/1128；默认 query 含 `device_platform=webapp`、`channel=channel_pc_web`、`msToken`、固定 Windows/Chrome 屏幕与设备字段等。源码注释称 aid=6383 可覆盖图文，但这不是 MediaFlow 实测 |
| Headers / Cookie / Token | Web UA 与 Referer 由客户端管理；代码有 CookieManager、`msToken` 管理和可选代理。README 快速开始要求浏览器登录并保存 Cookie，且当前 CLI 验证仍阻断。`uifid` query 在所查默认参数中为空；`verifyFp` 在已查文件未找到，不能断言其他模块不存在 |
| 动态签名 | 构造 A-Bogus（含 BrowserFingerprintGenerator），失败回退 X-Bogus；多轮签名/退避重试实现用于应对空 200/风控。动态指纹与风控重试不能直接移入 MediaFlow production |
| 图文判断 / 图片 | `aweme_type` 2/68/150 或 `image_post_info`/`images` 非空；优先 `image_post_info.images` / `image_list`，再顶层 `images` / `image_list`；每项按多个 URL 源与分辨率、疑似水印排序，逐位置保留候选镜像再下载。可参考“每位置多候选”设计，不复制代码 |
| 浏览器 / 服务器 / 依赖 | Python `aiohttp` 等、本地 Playwright fallback、SQLite History；可选本地 REST server。项目有登录 Cookie 流程和可能的代理配置；MediaFlow 不接入其服务或账号流程。跨端直接复用 Python/Playwright/SQLite 不合适 |
| Windows / Android | Windows Python CLI 有项目说明，但当前单条图文被请求验证阻断；Android 无该 CLI 的原生实现证据。仅字段映射与接口抽象可独立重写，双端匿名入口未证明 |
| iOS / macOS / Linux | CLI 声称 macOS/Linux 可运行，非移动端 production 证据；MediaFlow 仍需独立 Adapter |
| MediaFlow 决定 | **不采用当前请求路线作 production 候选结论**；保留 URL/字段与每资源候选镜像的设计参考。Cookie 登录、指纹生成、代理或针对风控的反复签名重试不采用 |

同源关系：与 `cmsjin/douyin` 的 README、文件树和项目叙述高度相似，后者列为疑似同源，**不计作第二条独立实现**。本项目与 DLWangSan 共用 Douyin Web detail 数据入口，也不能把两份代码计成两条独立数据入口。
