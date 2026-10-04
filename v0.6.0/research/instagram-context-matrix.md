# Instagram 独立匿名上下文实验（2026-10-03）

证据：Instaloader 4.15.3 无登录运行成功取得 BoHk1haB5tM 的 GraphSidecar/5 项；本地 Dart 裸 GraphQL 两个用户样本均 403。源码 `doc_id_graphql_query` 先 GET 平台首页获取 csrftoken，然后 POST。403 不能据此断言必须登录或只缺某项参数。

| 项目 | 来源/用途 | 实验许可与隐私 | 最小条件 |
|---|---|---|---|
| csrftoken | Instagram HTTPS 首页 Set-Cookie；普通防跨站请求上下文 | 平台本身签发；只在本轮内存、只回传 www.instagram.com；不显示/落盘/进入模型 | 独立验证有无；本轮结束丢弃 |
| Referer / Origin / Accept / x-ig-app-id | 已审计 Instaloader 普通客户端协议字段 | 非账号身份；仅对应平台 Adapter 使用 | 与 CSRF 初始化视作一个请求上下文变量组 |
| doc_id / variables / server_timestamps | 已审计 Post._obtain_metadata / doc_id_graphql_query | 非官方协议、随平台更新失效；MIT 设计参考 | 不更换签名、不反复变更 doc_id |
| User-Agent | 保持 MediaFlow-Research/0.6.0 | 不复制浏览器/iPhone 指纹 | 同裸请求保持不变 |
| sessionid / auth_token | 用户账号身份 | 本实验禁止；服务器签发非空账号 session 时停止 | 不读取外部会话，不尝试登录 |
| mid、设备/窗口字段、iPhone headers | 上游还存在的其他状态 | 本实验不采用；必要性未证明 | 不合成身份/设备指纹 |

范围：新建独立 context 路线，每个固定样本最多首页 GET + 一次 POST。遇到 401/403/429、登录重定向或验证标记立即停止；不自动降级或重试，不在被拒绝请求内追加身份材料。技术路线与账号登录必要性分别判断。此矩阵不授权 production 接入。
