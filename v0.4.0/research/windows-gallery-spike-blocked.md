# Windows gallery production spike — BLOCKED（2026-09-28）

**未达到 `WINDOWS GALLERY PRODUCTION SPIKE PASS`。唯一 blocker：符合本轮准入范围的非 Python production F2 detail backend 尚不存在。**

不是再次证明平台拒绝，不是 UIFID/Argus/signer 服务端错误。本轮平台请求0、图片请求0、Python启动0；没有重新打开登录窗口采集会话，没有恢复H2或进入其他路线。

## 仓库证据与任务范围

用户要求“只允许使用已经经过许可证审计、为 production 选定的最小模块”，禁止Python runtime/F2 CLI。实际状态：

1. `lib/features/parser/data/douyin/gallery/douyin_gallery_capabilities.dart` 只有 abstract SessionProvider / DetailClient 接口，文件明确写没有 live backend。
2. 本地 lib/tools/windows 中没有实现上述两个接口的生产模块，也没有非Python A-Bogus实现；现有旧视频签名不是F2已验证算法，不能替代。
3. 上轮 `gallery-integration-result.md` 明确记录“没有在线provider/client实现或正式解析入口注册”，F2协议模块只是未来评估范围。
4. 现有 F2 signer 位于 research 的 `.py`，其 `signer/NOTICE.md` 明确声明“this research is not a production license clearance”。这是本项目采用范围尚未完成，不是断言 Apache-2.0 禁止生产使用。
5. 已真实工作的 detail client 是仓库外 Python F2 SDK，依赖其原模型/token初始化/signer/默认headers；本轮明确禁止执行它。脱敏fixture只有替换后的测试URL，不能用来真实下载或伪造在线结果。

因此 architecture B 的选型、18项离线Adapter测试与原F2成功，不等于已经具备可接入的production最小协议模块。新移植与资格验证会越过本轮“仅使用已经验证/准入模块”的限制，不能自动假设它已完成。没有将接口包装成成功的production入口，也没有只接线却无法工作的空壳。

Windows Session Adapter 尚未实现是该未完成在线backend链的实施内容，未在本轮展开成另一条研究路线。下一轮唯一目标应是：**实现并准入非Python的F2最小production detail backend（包括Windows私有session消费），先完成离线协议兼容验证，再执行有界Windows spike。** 不重新做架构比较，不启动Python，不恢复H2，不做Android开发。

## 30项答复

| # | 项目 | 本轮事实 |
|---|---|---|
| 1 | production入口 | 未接入；避免注册尚无可运行backend的空壳 |
| 2 | Windows Session Adapter | 生产实现不存在；既有research WebView2工具不冒充production Adapter |
| 3 | 是否需要登录 | 本轮未验证；原F2已有成功样本使用正常自有session，不证明普遍必须登录 |
| 4 | 真实detail | 本轮没有取得；上一阶段成功不是本轮production证据 |
| 5 | HTTP | 未请求，无status/body |
| 6 | Argus gate | 本轮未观察；不能套用历史403为新结果 |
| 7 | x-tt-argus:1 | 未加入production、未发送 |
| 8 | A/B | 未执行；不存在可运行的production candidate A |
| 9 | target | 指定7690029886242009957，未在线验证 |
| 10 | aweme_type | 历史/fixture为68；本轮未在线读取 |
| 11 | images | 历史/fixture13；本轮真实detail未取得 |
| 12 | MediaResource | 既有离线13通过；本轮真实production未生成 |
| 13 | 顺序 | 既有离线已验证；本轮真实链未验证 |
| 14 | DownloadTask | 既有离线13通过；本轮未入正式队列 |
| 15 | resourceIndex | 既有ordered list位置0–12；模型没有新属性，本轮不改模型 |
| 16 | 实际下载数 | 0 |
| 17 | 两文件路径 | 无 |
| 18 | 文件大小 | 无 |
| 19 | 不同图片 | 本轮未验证 |
| 20 | Windows打开 | 本轮未执行 |
| 21 | History | 未新增本次gallery记录，未修改旧video history |
| 22 | 错误处理 | 既有adapter空images/缺字段离线测试历史通过；本轮production无session/失效/detail失败UX均未实现/未实测 |
| 23 | flutter analyze | 本轮未运行，只有报告新增；上一阶段lib test无问题，全仓库49条旧research info |
| 24 | flutter test | 本轮未运行；上一阶段184 passed / 5 skipped，不能写成本轮运行结果 |
| 25 | 文件 | 本轮仅新增本报告；生产源码零修改，零依赖新增，零文件删除 |
| 26 | Git status | feature/v0.4.0；HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；既有修改与untracked保留，见下方状态 |
| 27 | Git写操作 | 无add/commit/push/merge/tag/PR/reset/checkout，仅只读查询 |
| 28 | 唯一blocker | 已准入且可运行的非Python F2 production detail backend缺失 |
| 29 | 下一轮唯一目标 | 实现并准入上述最小backend，完成离线协议兼容后执行Windows spike；不做新架构研究 |
| 30 | 兼容性检查 | 见下表；没有生产改动，但不能说正式能力已经支持 |

Git 工作区：

```text
 M AGENTS.md
?? lib/features/parser/data/douyin/gallery/
?? test/features/parser/douyin_gallery_adapter_test.dart
?? test/fixtures/
?? v0.4.0/
```

`git diff --stat`：只有既有tracked AGENTS.md，31 lines / 23 insertions / 8 deletions；untracked新增报告不计入。AGENTS.md本轮未修改。`git diff --check`本轮通过。

## 【项目目标兼容性检查】

| 范围 | 状态 / 限制 |
|---|---|
| Windows | production图库在线能力尚未实现/未实测；已有纯Dart离线mapping不等于spike PASS |
| Android | 本轮不开发、不安装、不改任何数据；生产在线能力仍待实现，双端同等正式门槛保留 |
| iOS / macOS / Linux | 本轮未实现/构建/实测，纯Dart映射理论兼容不代表session/backend可用 |
| Bilibili / Douyin / 其他未来平台（小红书/YouTube/X/Instagram等） | 无生产改动，本轮未回归；Douyin自研H2永久冻结，新图库入口仍未接入 |
| Detector / Parser / Adapter / ParserService / UI | 本轮未修改，未用fixture冒充成功；session UX未正式实现 |
| Unified Content Model / MediaContent / MediaResource | 未改；既有ordered资源足以表达图库，问题是在线backend而不是公共模型 |
| Downloader / DownloadTask / History / Media Processing | 未改，未新增/下载真实任务，未验证本轮真实图片/历史效果 |
| Browser Adapter / Settings / Logging / 本地存储 | 未调用research工具建立session，不读取系统浏览器，不扩大凭据采集；生命周期正式实现尚缺 |
| 隐私 / 本地优先 / 零服务器 | 本轮没有凭据读取或平台/第三方请求，没有上传或新服务 |
| 第三方依赖 / 包体 / 性能 | 零新增依赖，未引Pythonruntime；backend不存在，不能给正式包体或性能通过结论 |
| 维护 / 正式发布 | 原F2 Apache来源已知，但实际生产采用闭包/运行时/兼容测试未完成，不能声明production-ready |

本轮按失败停止条件暂停；不把实现缺失改写成平台拒绝，不自行开启新路线。
