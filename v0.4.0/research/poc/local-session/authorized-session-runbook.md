# 用户正常交互的授权 context 实验

本轮仅 Windows research，生产 Parser/Signer/UI/Downloader 未修改。独立 helper：AuthorizedSessionPoc.cs；build-authorized.ps1 复用已有 WebView2 SDK，不新增产品依赖。旧 LocalSessionPoc 及历史日志保留。

所有者本轮明确将 challenge 行为改为“暂停自动流程、保持窗口、本人正常处理”。这修订了 AGENTS 第十节此前对本轮研究入口立即关闭的做法；仅允许本人正常交互，不允许自动求解、指纹伪造、token 重放、代理、外部会话导入。

## 操作

1. helper 创建仓库外专用 `mediaflow-v040-authorized-session/session-<GUID>`，ACL 限制为当前用户/SYSTEM；只读 homepage/detail URI scoped snapshot 确认初始零 Cookie、无 UIFID/账号态。
2. 打开 Douyin 首页。验证信号只暂停本工具自动流程，正常页面及其挑战资源保持加载；没有自动点击/填写/破解/反复导航。用户自行正常完成交互。
3. 用户勾选“本人已正常完成页面交互”，另独立记录 challenge/login 自报，再点检查。自报不是程序验证的账号认证结果，未勾选不自动断言完成。
4. 只采样 scoped UIFID、ttwid、sessionid/sessionid_ss 元数据。msToken/s_v_web_id 等未证实必需，不采样/发送。不得导出完整 jar。
5. UIFID 唯一、非空、无控制字符/空白/分号、domain 为 douyin.com/www.douyin.com、scoped path、未超过已知 expiry 才可用于当前任务。session Cookie expiry unknown，不虚构 TTL；存在性不证明服务端接受。
6. 缺少/不可用 UIFID：结束本轮，无 detail，记录 C5（依据本人正常交互自报，账号登录与 session cookie 实际证据另列）。不扩大初始化研究。
7. 可信 UIFID 可用：冻结页面网络，只使用本 profile 实际 UA 和 UIFID header，最小四参数 baseline + note Referer。direct、禁 proxy/cookies/redirect、25秒、2MiB 限额、无重试；最多一个 E1。没有 signer，账号 Cookie/ttwid 不发送。
8. E1 后仅检查 JSON 内目标/图片数组数量，不输出正文/媒体 URL，不下载图片。错误分类证据：UIFID missing → C3；明确 signature 错误且无 challenge → C1 candidate；正确目标且 status_code=0 → C2；其他/安全拒绝保留实际状态、不归因 signer。C4 用于受控流程未完成/取消/其他拒绝，不能把未知E1错误解释为用户一定无法登录。
9. 同 profile 关闭等待进程退出，离线重启无首页导航，检查 UIFID 是否保留。然后清本 profile 全部浏览数据、scoped Cookie 验证、释放 WebView、等待 browser 退出、核对精确路径/归属 marker 后删该 GUID 目录。删除/退出失败必须保留失败状态，不宣称全部清除。
10. 随时 Clear test session / 关闭窗口：撤销 context、取消 E1、清理并记录 USER_CANCELLED；不删除/修改其他 profile。

WebView 自动 detail 请求被阻止，避免页面侧发出额外目标详情请求；它可能影响正常页面交互，必须如实报告。弹窗/权限/下载被禁止；如果正常登录依赖这些能力，不能把该 helper 限制写成平台全局不可用。默认实际 UA，WebView --no-proxy-server；不修改 automation/fingerprint 特征。没有网络/DOM/XHR内容采集或用户密码观察；网页自身正常图片加载不等于本工具媒体导出/下载。

日志只写 present/length/domain/path/expiry/HttpOnly/Secure/SameSite、用户完成自报与事件统计。挑战信号不写完整URL/标题，账号字段不写值/账号名。日志的 resource 事件计数不是全部 OS 网络包数量。没有截图。

## 编译与离线验证

```powershell
& ./v0.4.0/research/poc/local-session/build-authorized.ps1
& ./build/authorized_session_research/AuthorizedSessionPoc.exe --self-test
```

最终编译通过，11 条离线断言 PASS：错误分类优先级、未知拒绝不归签名、domain 边界、header注入拒绝、真实UA含空格可接受、主页面域名限制、单次消费和clear撤销。初次 Windows .NET 编译器不支持 await catch/finally，已改为 catch 后统一异步清除；首次失败发生在网络启动前。

旧 H2 42 项合成契约重跑 PASS，Dart 定向 analyze 无问题；不是 Native UI/真实context通过。完整 Flutter lint 未验证，保持已有 flutter_lints include 限制；Windows Flutter/Android/iOS/macOS/Linux 正式build未运行。

## Android 对应设计

MULTI_PROFILE feature-gated named Profile 的 CookieManager，或独立 worker 在任何 android.webkit 初始化前设置 data-directory suffix。用户本人交互与一次 E1留在同 Adapter/worker；主进程仅 opaque 状态。挑战信号暂停自动消费但保持正常页面，由用户完成确认再检查。系统API未暴露的Cookie属性标unknown，不能照填Windows metadata。worker停止/重启、全数据clear和精确目录删除须独立真机验收；不能用Windows结果替代。

本轮 Android 未build/安装/真机测试，applicationId/签名未核实；没有覆盖/卸载/清数据。iOS/macOS的WKWebsiteDataStore、Linux可替换runtime均为理论Adapter路径，未实测。Windows临时helper不进入共享业务层。

实时状态与最终运行证据在 authorized-session-metadata.jsonl；最终报告须基于 finished 事件和独立目录复核，不能在用户仍操作时提前判 C1–C5 或清除成功。
