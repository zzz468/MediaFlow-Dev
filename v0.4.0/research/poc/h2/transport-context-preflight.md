# H2 transport 解耦验证前置核对 — 2026-09-28

结果：**H2-T5 — No authorized context available**。

`H2 transport remains untested because no authorized valid context was available.`

本轮将 Problem A（生产 ContextProvider 如何建立正常 context）与 Problem B（已有正常 context 时 H2 能否取得 gallery）分开。没有重新研究 A，也没有利用旧 challenge 失败替代 B 的实测结果。H2-T1/T2/T3/T4 均无成立证据；原 H2-CONTEXT-BLOCKED 保留为上一轮历史结论。

## 基线、授权及检查范围

- cwd / Git top-level：`D:\projects\mediaflow-v040` / `D:/projects/mediaflow-v040`。
- branch：`feature/v0.4.0`；HEAD：`e2ea89d4e156c843af09b4c491984a2206f1135b`。
- 开始状态：` M AGENTS.md`、`?? v0.4.0/`；已有成果全部保留。
- 本次所有者明确允许测试人员本人正常取得的 context 手工用于独立 research PoC。这与 AGENTS 第十、二十节禁止外部浏览器会话导入/手工复制凭据的长期规则有差异；按所有者明确的本轮研究例外处理，不修改长期规则，不扩展为 production 入口或未经授权扫描浏览器。
- 本次附件没有给出临时 secret 文件路径、已配置环境变量名、context 值或会话来源/授权/有效期/UA 元数据。
- 只检查当前工具进程中 `DOUYIN_UIFID`、`DY_UIFID`、`MEDIAFLOW_H2_CONTEXT_FILE`、`MEDIAFLOW_H2_UIFID` 的存在性，全部 false；未打印值，未枚举其他环境变量、读取系统持久环境或搜索本地 secret 文件。
- 这只证明本次可识别且明确提供的入口没有 context，不证明测试人员电脑所有位置都没有正常会话。没有测试账号或测试 profile 被本次指定、读取或启动。
- 未访问 Chrome/Edge 数据库、其他 App、历史 profile、远程 session、共享/泄露凭据；未启动 Browser/WebView。

## 最小字段矩阵

|Context 项|是否已有证据需要|本轮是否提供|
|---|---|---|
|UIFID|旧 baseline 明确 Uifid Not Found；已有源码消费 header/query，尚未证明其充分性|否|
|ttwid|参考实现携带/初始化；当前目标必要性未消融|否；不默认增加|
|Cookie subset|参考有会话能力；账号必要性/具体最小子集未验证|否；不发送完整 jar|
|msToken|部分实现使用；来源不同，无本机必需证据|否|
|s_v_web_id / verifyFp|条件线索，无当前因果证据|否；不合成|
|真实 UA / context binding|请求与 signer 应一致，具体平台绑定未验证|无真实 context UA；fixture UA 不可用于真实验证|
|其他|没有新增必需证据|否；不加占位 Argus、随机 Token、设备特征|

UIFID 格式、domain/path scope、到期状态、Cookie subset 格式、UA/context binding：全部 **NOT VERIFIED / 未提供**。不能仅非空或长度满足就称 valid context，也不能从“字段名是 UIFID”推断来源合法。前置验证不成立，禁止 detail 请求。

## Signer 实际状态

复核 [h2_contract.dart](h2_contract.dart)：`DouyinWebRequestSigner` 是 contract；`UnavailableSigner.sign` 抛 signerUnavailable。[测试](h2_contract_test.dart)中的 RecordingFixtureSigner 返回 MOCK，仅验证编码/输入传递，不是 license-safe 的真实 A-Bogus 实现。

因此还存在一个未完成的后续先决条件：**真实 signer implementation incomplete**。本轮不能写 `context ready / signer implementation incomplete`，因为 context ready 本身没有成立；正确口径为 `context unavailable; real signer implementation incomplete`。也不能写 H2-T3，因为没有请求证明 context gate 通过或 signer 被服务端拒绝。没有复制 GPL、商业受限或来源不明代码，没有采用远程 signer，没有新的第三方项目/依赖。

## 分层执行记录

目标保持 `7690029886242009957`，没有换样本。

|阶段|执行|结论|
|---|---|---|
|Context preflight|本地输入存在性/源码核对|没有授权且可验证的 context|
|H2-E1 valid context + minimum request|0 次|NOT EXECUTED，不能判断 UIFID 错误消失|
|H2-E2 context + signer|0 次|NOT EXECUTED；真实 signer 未实现，未进入服务端校验|
|H2-E3 payload validation|未执行|没有业务 JSON，未取得 target aweme_detail/gallery/图片 URL|

E3 是对已取得 JSON 的本地检查，不额外请求/下载图片。未来 E1 只能一次最小请求；Uifid Not Found 或明确安全拒绝停止。未知403、空正文、错误变化不能当作 context 接受；E2 必须有明确 context 接受且签名必要性证据。任何明确安全拒绝不得自动进入 E2。不能凭缺少错误文本断言 context + signer 均通过，更不能据此归 endpoint FAIL。

H2 TRANSPORT PASS 尚未成立。要求精确目标 aweme_detail、真实非空图文数组、可确定顺序、至少两个图片 URL、本地 context/signing/请求，不依赖第三方服务；不把 mock 两张图、HTTP200、无 UIFID 错误或 offline PASS 算作真实 transport PASS。

## 21 项结果答复

|项|结果|
|---|---|
|1 Context 来源类别|没有收到/定位本轮明确提供的 context；无实际来源类别|
|2 测试人员自己的正常会话|未提供，无法核实；未借用任何会话|
|3 提供哪些 context 类型|真实类型 0；旧离线测试只有合成 fixture|
|4 是否泄露真实值|检查只输出指定输入存在性；未取得真实值、未保存/输出秘密，无截图/History/原始响应|
|5 UIFID gate 消失|未验证|
|6 signer 实际验证|未发生；现有 contract 不能冒充真实实现|
|7 Web detail 正常业务响应|未请求/未取得|
|8 target aweme_detail|未取得|
|9 gallery structure|未取得|
|10 图片 URL|真实 URL 0；未下载图片|
|11 H2 transport PASS|否，UNTESTED；结果 H2-T5|
|12 当前唯一主 blocker|本轮没有授权且可验证的测试 context；真实 signer 未实现为后续先决条件，不是已观测的 SIGNER-FAIL|
|13 production ContextProvider 必要|仍必要；即便临时注入 transport 成功也不能用于生产|
|14 Windows/Android 后续任务|先完成独立 transport 验证；若 T1 才转双端 ContextProvider 实现/隔离/清除/失效验收，再 Parser integration，不提前实施|
|15 网络请求数量|全部 0：平台/detail/Browser/媒体/第三方/GitHub 均未请求|
|16 文件|新增本报告；更新 v0.4.0/README.md 与 research/README.md 索引；删除 0；h2 源码/旧证据未改|
|17 analyze/test/lint/build|当前 Dart 定向 analyze 无问题，重跑42项合成离线检查 PASS；完整 Flutter lint 未验证，保留 unresolved flutter_lints 限制；正式 Windows/Android/iOS/macOS/Linux build、Flutter test/analyze 未运行|
|18 Git status|` M AGENTS.md`、`?? v0.4.0/`；branch/HEAD 不变|
|19 production 修改|0；无 debug secret 入口、Cookie UI/配置或公共模型凭据|
|20 Git 写操作|0；没有 add/commit/push/merge/tag/reset/PR|
|21 项目目标兼容性|见下表；没有新增平台支持或功能通过结论|

自动化命令采用 SDK exe，避免此前 Flutter launcher 卡住：

```powershell
& D:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe analyze v0.4.0/research/poc/h2
& D:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe v0.4.0/research/poc/h2/h2_contract_test.dart
```

没有真实 secret 文件/变量/profile 由本轮建立或消费，因此没有真实 secret 清理对象；没有删除测试人员未知文件，也不清空其未知环境。读取存在性的临时进程变量引用已置空。重跑 fixture 不会发网络，不把该42项作为新增 signer 向量或正常 context 验证。

## 【项目目标兼容性检查】

|平台|本轮状态|
|---|---|
|Windows|已实际测试本地 preflight/离线契约；真实 transport/生产构建未验证，context/UA/HTTP绑定风险待测|
|Android|纯 Dart 契约理论兼容；本轮未构建/安装/真机/context 测试；保持与 Windows 同等生产门槛|
|iOS|理论 Adapter 路径，未实现/构建/实测；临时 context 研究不等同平台支持|
|macOS|理论 Adapter 路径，未构建/实测；profile/clear/HTTP绑定仍需验证|
|Linux|理论兼容，runtime/profile方案尚未实测；未构建/功能验证|

|模块/长期目标|具体检查|
|---|---|
|Bilibili/Douyin|生产未改、未本轮回归；Douyin gallery transport 仍未验证，不宣称恢复|
|Xiaohongshu/YouTube/X/Instagram/其他未来平台|未新增支持，Douyin临时研究不进入公共协议|
|PlatformDetector/Parser/Adapter/ParserService/UI|未修改/回归；保持平台边界，无 Cookie UI 或 secret debug 入口|
|Unified Content Model/MediaContent/MediaResource|未改，不注入 context/凭据，真实 gallery 映射未验证|
|Downloader/Media Processing|未改/回归，无图片下载/处理|
|Browser Adapter|未启动/扩展；无 Observation 内容采集，无 ContextProvider 自动获取研究|
|History/Settings/Logging/本地存储|生产未改；只写无秘密的研究结论，没有 secret 文件或会话持久化|
|隐私/零服务器|未读取外部浏览器会话，未进行任何网络请求；无凭据上传/共享账号/第三方服务|
|第三方依赖/包体/性能|无新增依赖/代码复用，打包配置未改；未做性能benchmark，不能写包体/性能已验收|
|后续维护/正式发布|真正 signer、合法context与目标payload仍需证据；生产双端 Provider/解析/GUI/下载验收尚未完成，不发布|

Android 安装安全：本轮无安装/替换/卸载/清除设备数据；applicationId、签名兼容未核实，此轮不做安装验收。

tracked `git diff --stat`：

```text
 AGENTS.md | 31 +++++++++++++++++++++++--------
 1 file changed, 23 insertions(+), 8 deletions(-)
```

其中 AGENTS 为已有修改，本轮未改。v0.4.0 未跟踪，新增/索引修改不进入上述统计；不 staging。`git diff --check` 通过；报告与索引的新增空白另核查。

本轮完成后暂停。后续由测试人员在本地指定本人正常取得、授权本次研究的最小 context 输入及非敏感来源/domain/path/expiry/UA 元数据；不要把秘密粘贴到聊天、Markdown、JSON报告、fixture或截图。优先明确给出仓库外临时 secret 文件位置或受控进程变量输入方式，不自动寻找/导入浏览器会话。只有这些条件成立才可以称 context ready；那时仍需如实检查真实 signer 是否实现，不用 MOCK 发请求。不重启匿名 bootstrap/Feed/Browser内容采集/endpoint泛搜，不修改 production。
