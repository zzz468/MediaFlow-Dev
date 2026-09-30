# 参考项目：DLWangSan/douyin_parse（首轮，2026-09-25）

证据分级：以下源码事实来自[仓库](https://github.com/DLWangSan/douyin_parse)与[解析源码](https://github.com/DLWangSan/douyin_parse/blob/master/douyin_video_parser.py)；“可用”仍只是项目声明，MediaFlow 本阶段**未运行**它、未向 Douyin 发请求。

| 项目 | 记录 |
| --- | --- |
| 仓库地址 / 维护 | [DLWangSan/douyin_parse](https://github.com/DLWangSan/douyin_parse)；主页显示 19 commits，README 记载 2026-07 的签名修复及图集功能；最新提交日期未独立核实 |
| LICENSE | README 声称 MIT；仓库根目录列表未见独立 `LICENSE`。且 README 有“请勿商业使用”措辞。许可范围须向作者核实；**禁止直接复制代码/算法** |
| 关键实现 | [`douyin_video_parser.py`](https://github.com/DLWangSan/douyin_parse/blob/master/douyin_video_parser.py)，`abogus.py`、`xbogus.py`、`qt_app.py` / `qt_app_slim.py` |
| 分享链接与 ID | 从文本提取 URL；直接识别 `/video/<id>`、`/aweme/detail/<id>`、`/note/<id>` 或查询中的 ID；短链 GET 跟随重定向后再提取，必要时读 HTML。源码已核实 |
| 数据入口 / 参数 | GET `https://www.douyin.com/aweme/v1/web/aweme/detail/`；`aweme_id` 加 `device_platform=webapp`、`aid=6383`、`channel=channel_pc_web`、`pc_client_type=1`、版本与固定 Windows/Edge 相关参数。源码已核实；哪些参数真正必要未验证 |
| Headers / 身份 | Chrome 130 UA、按 `/note/` 或 `/video/` 选择 Referer；Cookie 有值才加，但构造函数读取 `douyin_cookie.txt`，README 正常使用步骤要求扫码取得或手动导入登录 Cookie。因此**代码分支可选 ≠ 匿名成功证据** |
| Token / 签名 | A-Bogus 优先，X-Bogus 失败后备选；源码未见该入口强制 `msToken` / `verifyFp`，但不能据此判定平台不要求；是否需登录态未独立实测 |
| 图文判断 / 字段 | `aweme_detail.aweme_type` 为 2/68 或 `images` 非空判图集；遍历顶层 `images`，静态图优先每项 `url_list[0]`，另试 `download_url_list` 等。LivePhoto 查看图片内 `video` 等。源码用 set 去重，可能丢作品出现顺序和重复位置，不能照搬到 MediaFlow |
| 浏览器 / 服务器 / 依赖 | 核心请求为 Python `requests`；完整版用 Playwright 扫码获取登录 Cookie、PySide6 UI；无第三方解析服务器必要性证据。登录 Cookie 流程及固定设备参数不符合 MediaFlow production 边界 |
| Windows / Android | 纯 HTTP 算法理论上可各端重写，但无匿名成功证据；Python/Qt 打包路线不适合直接作为 Android Adapter；固定 Win32 参数跨端风险高 |
| iOS / macOS / Linux | 仅有本地算法理论路径；当前项目自身的移动端实现未核实 |
| MediaFlow 决定 | **仅参考 Web detail 路径、字段线索和失败判定，不采用代码、Cookie 方案或固定指纹参数。** 第二阶段若验证须独立、匿名、双端；遇 403/验证即停止该入口 |

同源关系：源码注释表示参数/签名方法与其他项目对齐，具体复制关系未证实；与 `jiji262` 同用 Web detail 并不构成两条独立数据入口。项目未提供 MediaFlow 自测的两张图片证据。
