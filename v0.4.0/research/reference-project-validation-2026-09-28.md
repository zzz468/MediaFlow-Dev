# 原项目实测：B — F2-SESSION-REQUIRED（2026-09-28）

**F2 GALLERY DATA PATH PASS**：原 F2 在本机正常 App-owned 登录会话下返回目标 `7690029886242009957` 的 `aweme_detail`，`aweme_type=68`，`images` 共 13 项，选取 13 个不同 HTTPS URL，对应 13 个不同资源 path，顺序为 0–12。未下载媒体，未进行图片 HEAD/GET；因此不标记 `F2 IMAGE RESOURCE PASS`。

分类 B 限于本次环境和两次已测输入：匿名调用失败、正常 session 输入成功。不是严格 Cookie 因果消融，不能证明所有环境必须登录、哪一个 Cookie 必要或默认占位头的独立作用。

自研 H2 状态正式为 **`FROZEN — CURRENT WEB DETAIL PATH BLOCKED BY UIFID/CONTEXT GATE`**。保留 W2/SCTX-2/W3 历史证据；本轮成功不自动解冻自研 signer、请求策略或生产 Parser。停止第二候选和所有底层协议研究，下一轮唯一目标为 **MediaFlow App-owned session UX + adapter / integration architecture**，本轮不实施。

## 范围与来源

用户明确补充授权：**“允许F2原项目自身默认头，禁止我们自行添加或修改”**。原 F2 的 GatewayHeaderManager 默认行为含 `x-tt-argus: 1`；本轮没有手工设置该头，没有修改或替换它。该授权只覆盖原项目验证，不构成生产采用授权，也不证明它属于正常平台签发状态。

- [F2 仓库](https://github.com/Johnserf-Seed/f2)，本轮获取的默认分支 `v0.0.1.8-pw3`。
- 固定 commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`，commit 时间 `2026-09-27T21:53:00Z`。
- [本次 README](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/README.en.md)、[LICENSE](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/LICENSE)、[官方数据 API 文档](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/docs/guide/apps/douyin/overview.md)、[官方示例](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/docs/snippets/douyin/one-video.py)。
- 原调用链：`PostDetail(aweme_id)` → `DouyinCrawler.fetch_post_detail` → 原 token 初始化 / 原 signer / 原 GatewayHeaderManager → 原 BaseCrawler JSON 解析。未调用 Downloader、Bark 或 CLI 下载流程。
- 官方 API 支持直接 ID；验证脚本只调用该 API 并检查返回字段，没有重新拼 query、签名或请求头。使用 `ClientConfManager.headers()`，原默认 UA/Referer 保留。官方 crawler 配置 `max_retries=1`、timeout=10、无代理，避免自动多次请求。
- WebView 实际 UA 为 Windows Chrome/Edge 153；原 F2 默认配置 UA 为 Chrome/Edge 130。这一差异未人为修正，属于原项目按 Cookie 输入运行的实测条件。

## 环境、命令与真实结果

独立目录：`D:\dev\tmp\mediaflow-f2-validation`，在所有 MediaFlow 仓库外。固定源码 zip 解压，未执行 clone / Git 写命令。原源码位于 `source\f2-a30feaf92a40f421273b01b6ef36aa83a93f63c0`，独立 `venv`，Python **3.13.11**。包及 CLI 实际版本 **0.0.1.7**，不得将分支名当作包版本。

安装方式：独立 venv 的 `python -m pip install <上述原源码目录>`；`f2 --version`、`f2 douyin --help` 成功；`python -m pip check` 通过。未安装进 MediaFlow，未改变正式依赖。

主要实际依赖：httpx 0.28.1、curl_cffi 0.16.3、gmssl 3.2.2、pydantic 2.13.5、cryptography 50.0.1、protobuf 5.29.6、rich 15.0.0、click 8.5.0、aiofiles 25.1.0、aiosqlite 0.22.1、PyExecJS 1.5.1、websockets 12.0。原依赖 browser-cookie3 0.20.1 已被 pip 安装，但**未调用任何外部浏览器 Cookie 提取能力**。完整安装清单保留于外部 `installed-dependencies.txt`。

| 项目 | 匿名原 F2 调用 | 正常自有 session 原 F2 调用 |
|---|---|---|
| 官方 detail API 调用 | 1 次 | 1 次 |
| Cookie 输入 | 空 | sessionid、sessionid_ss、ttwid |
| 提供 UIFID | 否 | 否 |
| 结果 | APIRetryExhaustedError | 目标业务 JSON，status_code=0 |
| 失败阶段 | original_fetch_post_detail | 无失败 |
| HTTP | 未保留，不能推断 403/200 | 根据原 parse_json 非 200 即抛错规则可确认 200；未单独保存 transport status |
| body 长度 | 未记录 | 未记录 |
| UIFID gate | 无足够 body 证据判断 | 返回目标业务数据，本次未被该 gate 拒绝 |
| aweme_detail / images | 未取得 | 目标匹配 / 13 项 |
| image_post_info | 未取得 | 未发现该对象；images 已足够 |
| 明确 signer 错误 | 未确认 | 无；不据此验收 MediaFlow research signer |

匿名异常按原 BaseCrawler 源码属于空/空白响应的重试额度耗尽；没有保留 HTTP/body，不能写成 UIFID gate、登录要求或 signature error。网络计数为 **2 次官方 detail API 调用，每次 max_retries=1**；原 model 自带 token 初始化、正常页面加载、依赖下载另有网络活动，未逐包计数。不是“全轮只有 2 个 HTTP 包”。没有第三次 detail、第二项目 detail 或图片资源请求。

图片检查为内存中的 URL 非空、HTTPS、不同 URL、不同资源 path 和原数组顺序，不把 URL 内容写入报告。实际访问性、尺寸、媒体内容、下载稳定性尚未验证。

## 会话及清理

新建专用 WebView2 profile：`profile-149de816578448b390c0316a72b4b2e2`，初始化 scoped Cookie 数量为 0。测试人员在本机正常完成登录/challenge并在窗口确认，程序未求解 challenge、未读取密码、未导入系统 Chrome/Edge 或其他 App 数据。只检查目标 Douyin scope，只筛选四个允许名称，不导出 Cookie jar。

| 名称 | present | length | domain | path | expiry UTC |
|---|---|---:|---|---|---|
| sessionid | true | 32 | .douyin.com | / | 2026-11-27T14:58:07.559Z |
| sessionid_ss | true | 32 | .douyin.com | / | 2026-11-27T14:58:07.559Z |
| ttwid | true | 127 | .douyin.com | / | 2027-09-28T14:58:09.843Z |
| UIFID | false | — | — | — | — |

真实 Cookie 仅存在于本次受控 profile、进程内存和 child environment `MF_F2_COOKIE`，未保存 env secret 文件、完整 Cookie、真实值、原始业务 payload 或带 token 的 URL。日志关闭，stderr 长度 0；保存内容仅是元数据和脱敏结果。没有向第三方解析服务器发送 Cookie/链接，所属平台正常请求除外。

清理事实必须区分：`ClearBrowsingDataAsync` 完成为 true；随后 scoped Cookie 空集检查为 **false**；浏览器退出为 true；profile 目录删除为 true，退出后独立路径存在性核对为 false。最终依靠退出及删除本次隔离 profile 完成清理，不能声称原生 clear 的空集检查通过。未扩大 Cookie 检查、未为清理问题再次请求平台。外部保留源码/venv/验证脚本及脱敏日志，不保留该 profile；子进程和窗口已退出。

## 32 项答复

| # | 问题 | 答复 |
|---|---|---|
| 1 | repository / branch / commit / version | Johnserf-Seed/f2 / v0.0.1.8-pw3 / a30feaf92a40f421273b01b6ef36aa83a93f63c0 / 0.0.1.7 |
| 2 | license | 本次根 LICENSE 为 Apache-2.0；根目录未发现 NOTICE。LICENSE SHA256 c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4 |
| 3 | runtime | Windows、本地 Python 3.13.11、隔离 venv；WebView2 用于正常用户会话输入 |
| 4 | 安装 | 成功；独立源码安装，无 MediaFlow 依赖变更 |
| 5 | 启动 | CLI version/help 及官方 crawler SDK 启动成功 |
| 6 | 实际输入 | 官方 PostDetail 直接 ID；官方 kwargs Cookie；值仅 child environment/内存 |
| 7 | 用户 session | 本次成功调用使用 session；匿名失败，普遍必要性未证明 |
| 8 | 登录 | 测试人员正常登录并自报确认；是否所有调用必须登录未证明 |
| 9 | Cookie | 本次成功提供三项最小 subset；未逐项消融必要性 |
| 10 | UIFID | 未检测到、未提供；本次成功不需要人为补 UIFID |
| 11 | 目标 ID | 精确匹配 7690029886242009957 |
| 12 | 图文类型 | aweme_type=68，images 非空 |
| 13 | gallery | 已取得 images 13 项 |
| 14 | URL 数量 | 按每张图选一个 HTTPS 候选，共 13 个不同 URL；非枚举所有备用 CDN URL |
| 15 | 不同图片 | 13 个不同 URL、13 个不同资源 path，至少两项，数组顺序可确定 |
| 16 | URL 可访问 | 未进行 HEAD/GET，不能标记 IMAGE RESOURCE PASS |
| 17 | 失败点 | 仅匿名调用 original_fetch_post_detail 抛 APIRetryExhaustedError；正常 session 调用成功 |
| 18 | 第二候选实测 | 否；F2 成功后停止，不发第二候选请求 |
| 19 | 第二候选 | 预备 DLWangSan/douyin_parse，master/0896c74d1e9368af8ad0b85449a8039b1b3010bd |
| 20 | 第二候选结果 | 仅外部源码/隔离依赖准备，未执行解析；不能写失败或通过；其许可需独立解决 |
| 21 | 最适合当前线索 | F2 是本轮唯一实测取得目标图文的实现；只作为下一轮候选基础，不等于整体产品采用 |
| 22 | Windows 难度 | 中等至高：原 Python 运行已证实，封装/打包/会话生命周期/默认 workaround 的产品许可与兼容尚未验证 |
| 23 | Android 难度 | 高且未实测：Python桌面包不能直接视为 Android 支持，需独立评估最小移植/bridge 与正常会话 Adapter；不降低验收 |
| 24 | 源码复用 | 本轮只在仓库外执行原代码；未复制到生产，未来是否移植尚未决定 |
| 25 | 许可证风险 | F2根 Apache-2.0 允许候选评估；将来需保留版权/LICENSE/来源commit/修改记录/适用NOTICE并审计实际依赖与模块；不混入 GPL/额外商业限制 signer |
| 26 | 下一轮唯一目标 | MediaFlow App-owned session UX + adapter / integration architecture；本轮暂停 |
| 27 | 文件 | 见下方清单；无生产修改，无删除历史文件 |
| 28 | test/analyze/build | pip check、CLI version/help、外部 helper 编译、探针语法和源码一致性通过；真实目标图文通过；正式 Flutter test/analyze/Windows/Android build 本轮未运行 |
| 29 | Git status | feature/v0.4.0，HEAD e2ea89d4e156c843af09b4c491984a2206f1135b；仍 M AGENTS.md、?? v0.4.0/ |
| 30 | production | Parser/Downloader/领域模型/UI/正式依赖均未改 |
| 31 | Git 写操作 | 无 add/commit/push/merge/tag/PR/reset/clone；源码用固定zip获取 |
| 32 | 目标兼容性 | 见下表；成功范围仅 Windows 外部原项目与单一样本 |

## 文件与验证清单

- 仓库新增：本报告；`reference-project-validation-evidence.json`（只含脱敏结果）。
- 仓库修改：research/README.md、research/poc/h2/README.md 顶部状态导航，历史证据保留；根 AGENTS.md 的既有改动未触碰。
- 仓库删除：无。
- 外部新增：F2固定源码、LICENSE/README/元数据、venv、依赖清单、`validate_data.py`、`validate_data_session.py`、`ReferenceSession.cs/.exe`、必要WebView2 SDK DLL、两次脱敏结果、session元数据日志、`offline-verification.json`；另有第二候选准备目录 `D:\dev\tmp\mediaflow-dl-validation`，未跑解析。
- 298 个源 Python 文件与固定 zip 比较：零差异。已安装的 109 个源运行文件与zip比较：零差异；26 个 `/test/` 文件被原 wheel 打包排除，不是修改。
- 外部 helper 编译通过；验证脚本 AST 语法通过；F2 pip check 通过。未执行上游测试套件（可能发网络请求）。
- `git diff --stat` 仅显示既有 tracked AGENTS.md：31行，23 additions / 8 deletions。`v0.4.0/` 整体 untracked，故新增报告不出现在 tracked diff stat，不能据此写本轮零文件变更。

## 【项目目标兼容性检查】

| 范围 | 本轮状态与具体限制 |
|---|---|
| Windows | 已实际测试外部 F2 + 自有 WebView2 会话，单样本 gallery 成功；未构建或集成正式 App |
| Android | 暂不支持本次 Windows helper，未构建/安装/实测；同等核心验收要求保留，正式方案需独立 Adapter |
| iOS | 理论存在本地签名/会话 Adapter 路径，未证明当前 F2包可部署；需 WKWebView和分发约束评估 |
| macOS | 理论可运行 Python，当前helper不能直接用；需独立正常会话与打包验证 |
| Linux | 理论可运行 Python，当前helper不能直接用；浏览器运行时/会话清理/打包未验证 |
| Bilibili | 生产代码未变，本轮未回归，不能写已通过 |
| Douyin | 外部F2目标图文数据成功；自研H2仍冻结，生产仍未恢复该图库能力 |
| Xiaohongshu / YouTube / X / Instagram / 其他未来平台 | 未实施或实测；未来不得把F2多平台包整体绑进公共业务，保持独立Adapter |
| PlatformDetector / Parser / Adapter / ParserService | 未改；未来只向应用层交付统一内容及脱敏状态，原F2依赖边界尚待设计 |
| Unified Content Model / MediaContent / MediaResource | 未改；13张图证明下一阶段需多资源映射，凭据不得进入公共模型 |
| Downloader | 未调用/修改，队列、Range、part、重试等本轮未回归；资源访问与下载尚未验证 |
| Media Processing | 未实施，保持Parser获取/Processor处理/Downloader保存的边界 |
| Browser Adapter | Windows外部临时会话已验证；清除后空集未通过、退出删除成功，生命周期需下一阶段修正并双端验收 |
| UI / History / Settings / Logging / 本地存储 | 正式模块未改；外部helper仅实验输入；未来凭据需受控本地存储，不进入历史/公共日志 |
| 隐私 / 本地 / 零服务器 | 无外部浏览器导入、密码读取、凭据报告或第三方解析上传；请求由本地原F2发送到所属平台；profile最终删除 |
| 第三方依赖 / 包体 / 性能 | 只在外部venv安装。Python和原依赖显著增加部署复杂度，包体/冷启动/内存尚未测量，不直接引入正式App |
| 维护 / 正式发布 | 依赖上游非官方协议与默认占位workaround，单样本成功不能保证稳定性；后续许可、安全边界、双端适配和回归均是正式接入门槛 |

本轮完成并暂停。不得因 F2 成功恢复 W2/W3、改 research signer 或自动开始生产集成。
