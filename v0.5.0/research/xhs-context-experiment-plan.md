# Windows XHS 有界匿名上下文对照（2026-10-01）

用户已授权优先复现Android成功条件。固定视频6abb69640000000014010526、多图687a4239000000002400bcc9；不访问Android设备，不重跑AndroidPASS。

## 来源/最小必要条件/隐私矩阵

| 条件 | 正常来源 / 已有证据 | 本轮处理 |
|---|---|---|
| 分享URL/xsec_token | 用户固定分享链，平台302签发；Android成功时原样内存使用 | 不改query，不硬编码token，不持久化值；必要性先未知 |
| 移动布局请求头 | Android研究UA包含android，移动hydration成功；Joe Converter有独立PHONE_KEYS_LINK/PC_KEYS_LINK | 单变量UA `MediaFlowResearch/0.5.0 (windows; Android-compatible layout)`；明确Windows，只有布局兼容标记，无设备ID/指纹/浏览器合成 |
| Accept/Language/Referer | 原研究请求无显式配置；Andy同源客户端默认Referer | 本轮UA对照不增加，记录实际显式头 |
| Cookie/a1/web_session | Android成功全部没有发送；Windows基线有Set-Cookie但忽略 | 初始空、不接收Cookie为后续材料，不保存值、不制造身份 |
| X-S/X-T/JS | 页面路线无需签名API；MCP读取已加载状态，默认WithFingerprint不可采用 | 本轮不调用签名API、不执行挑战，不启用stealth或指纹 |
| 浏览器/home初始化 | AndroidLevel0直接分享页已有内容；Andy Browser作为另一条条件路径 | A阶段无profile、无首页初始化；只有A不足且证据支持后考虑B，不能凭猜测添加session |
| TLS/HTTP/DNS | 保留本机正常系统DNS、证书验证、DIRECT、Dart HTTP | 不改网络配置或TLS；新增头观察不能证明TLS fingerprint差异 |

## 操作预算与停止

2026-10-01 baseline-oct1仅视频一次，302到作品再login，停止。mobile-oct1是单独、明确授权的协议布局兼容对照：只改变UA，无增加身份、会话或签名；一个样本一次，无自动重试。挑战/403立即停止，不换签名/凭据；仅成功取得公开结构后下载返回的原URL，才对同一条件补固定8图。此实验检验公开页面呈现差异，不允许绕登录/权限/安全验证。

记录重定向脱敏地址、query键、Cookie发送=false、Set-Cookie名称（无值）、UA/Accept/Language/Referer、DNS、HTTP状态、页面大小/hash/schema；媒体资源概要记录host/hash；query值脱敏。既有HTTP事件还记录公开CDN path（可能含临时媒体签名），不是完整URL级脱敏；不保存Cookie/session值，原始研究证据留本地，production日志需进一步屏蔽CDN path。源码、license与最近提交/Issues对照另存审计。若UA成功仍只能确认该变量足以改变本环境响应，不声称所有平台/全部匿名作品通用可用。
