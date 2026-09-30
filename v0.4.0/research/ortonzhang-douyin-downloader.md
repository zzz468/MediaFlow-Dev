# 参考项目：Ortonzhang/DouyinDownloader（首轮，2026-09-25）

证据分级：来自[仓库](https://github.com/Ortonzhang/DouyinDownloader)和 [`server/index.js`](https://github.com/Ortonzhang/DouyinDownloader/blob/master/server/index.js)。MediaFlow 未运行浏览器或验证真实图文。

| 项目 | 记录 |
| --- | --- |
| 仓库地址 / 维护 | [Ortonzhang/DouyinDownloader](https://github.com/Ortonzhang/DouyinDownloader)；主页显示仅 3 commits、1 issue；具体最近提交日期与持续维护能力未核实 |
| LICENSE | 仓库根目录未见 LICENSE，README 也未见明确许可；**代码不得直接复制**，仅分析思路 |
| 关键实现 | `server/index.js`（Express + Puppeteer）、`server/package.json`；React 客户端只接本地 server JSON。和 MediaFlow 零服务器架构不兼容，不能照搬服务形态 |
| 分享链接与 ID | `/api/analyze` 接收原始 URL 并在浏览器中打开；服务端从抓到的 `aweme_detail` 取 `aweme_id`/`awemeId`；短链与 `modal_id` 的独立提取合同未在源码中核实 |
| 数据入口 / 参数 | Puppeteer 导航到公开页面，观察已加载的 `/aweme/v1/web/aweme/detail` 或 `/aweme/v1/web/aweme/slidesinfo` JSON；失败再读 `RENDER_DATA` / `__UNIVERSAL_DATA_FOR_REHYDRATION__` 等页面状态和 DOM。API 请求由页面发出，项目未展示独立 host/query 构造；不能把其成功声明等同于匿名 HTTP 可复现 |
| Headers / Cookie / Token / 签名 | `page.setUserAgent` 固定桌面 Chrome；浏览器自行管理页面请求、Cookie、Token 与动态签名。项目代码在所查解析段未显式构造 A-Bogus/X-Bogus/msToken/verifyFp；浏览器实际发送值未核实。没有证明无登录 Cookie 情况下能得到目标图文 |
| 图文判断 / 图片 | `aweme_type===2` 对音轨作特殊处理；优先 `awemeDetail.images[*].urlList[0]` 或 `url_list[0]`，其次 `image_infos[*].label_large.url_list[0]` / camelCase 变体；DOM 图片仅兜底，可能无法确认目标作品与完整顺序 |
| 浏览器 / 服务器 / 依赖 | Puppeteer Chromium、Node/Express、Axios 与可代理流媒体的 `/api/proxy`；**MediaFlow 不得引入其代理服务，也不得上传用户链接**。本地 Browser Adapter 可借鉴“只观察目标页面已加载响应”的思路，但需自己的范围限制、会话生命周期和安全停止 |
| Windows / Android | Windows 可借现有 WebView2 Adapter 作理论最小观察；Android 可借 System WebView Adapter 作理论路径。项目本身是桌面 Chromium + Node 服务，**没有 Android 真机验证**；包体积和性能风险高 |
| iOS / macOS / Linux | 项目未提供 MediaFlow 五端 Adapter；仅抽象观察边界理论可扩展 |
| MediaFlow 决定 | **仅作为 Browser Observation / 页面状态路线线索**，不复用无许可证源码、Puppeteer 服务、代理或视频探测逻辑。第二阶段先确认两个平台的匿名页面是否真正加载图文，再考虑独立 PoC |

其 Browser Observation 与 Web detail HTTP 可能最终读取同一底层响应；两种观察机制不自动等于两条独立平台数据源。
