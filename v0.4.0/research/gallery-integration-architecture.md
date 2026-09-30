# Douyin static gallery 集成架构（2026-09-28）

## 决策与实现边界

上一阶段原 F2 已实测 DATA PATH VERIFIED：target `7690029886242009957`、type 68、13 images；正常 App-owned session 成功，未提供 UIFID。自研 H2 **永久冻结**：不恢复 UIFID/W2/W3/新请求形态/Browser Observation内容解析/Mobile Feed/SSR/endpoint猜测。

本阶段推荐 **B：只采用经过许可和行为核对的最小 F2 协议模块，通过 Douyin Infrastructure 实现跨平台 detail client**。不把整个 F2 包、CLI、Downloader、History、其他平台、browser-cookie3 或 GUI 作为产品依赖。

```text
Application（URL / 用户 intent / 用户可理解的状态）
  → DouyinSessionProvider（opaque handle；平台自有 profile）
  → DouyinGalleryDetailClient（平台私有凭据消费、请求、安全错误）
  → DouyinGalleryAdapter（只读白名单内容 JSON，无网络/凭据/UI）
  → 现有 MediaContent + ordered MediaResource[]
  → 现有 downloadTasksFromMediaContent
  → 现有 Downloader / History
```

本轮新增离线 `DouyinGalleryAdapter` 与能力接口；**没有具体在线 SessionProvider/DetailClient，没有注册到 ParserService，没有改现有 DouyinParser 或正式 UI**。这不是已经实现完整 production 登录/解析的宣称。原视频路径保留；将来的 Application 内容入口选择应先识别图库，不回调已冻结的自研路径作为安全失败后的 fallback。

### 三方案比较

| 标准 | A：整套 Python/helper | B：最小协议移植（推荐） | C：Windows helper后移植 |
|---|---|---|---|
| Windows | 原项目本机可运行，打包/隔离IPC尚未验收 | Dart本地核心 + Windows会话Adapter，尚待实现 | helper可先验证，但不是正式双端完成 |
| Android | 现有桌面venv/exe不能直接部署；嵌入Python/原生库成本未验证 | 同一 Dart内容/协议契约 + Android WebView私有会话Adapter | 必须同一里程碑验证Android；不允许靠延期发布Windows单端 |
| runtime依赖 | Python及大量F2依赖；平台native轮子需打包 | 正式方向不需要Python；必要签名依赖单独评估 | 过渡阶段两套实现，最终删除helper runtime依赖 |
| 包体 | 原环境没有测量发行包体；预计增加，不能报具体MB | 最小模块更有利，仍需实测体积 | 过渡期增加包体、构建和发布组合 |
| 更新成本 | 上游升级容易获取，但整包行为范围大 | 维护小范围兼容测试，协议变更须跟进 | 两套行为容易漂移，需要同源契约/金样本 |
| session共享 | 私有管道短生命周期传递，不命令行/文件/env永久存储 | 平台Adapter内直接消费，handle不带值 | 两种消费方式需一致失效/清理行为 |
| license | Apache根许可加全部runtime依赖审计 | 保留采用模块attribution，逐依赖审计 | 同时维护helper和移植来源/NOTICE |
| 性能 | 子进程冷启动/IPC/内存未测 | 免Python子进程，实际签名耗时待测 | 过渡期性能指标不可推作最终指标 |
| UX | 不应让用户配置Python或复制Cookie | 本地自有会话、首用登录、后续透明复用 | 迁移不可改变用户会话语义或要求重新手填凭据 |

不选 A 为最终方案：没有 Android 等价部署证据，完整 Python/F2 带来的依赖范围超过图库需求。C 只作为可撤销 spike 工具，不是“Android以后再说”的最终方案；同时长期维护两套协议不合适。B 也未证明所有签名模块可直接Dart化，移植工作必须小范围、可追溯、单独验收；当前不重写 signer 或展开底层研究。

## F2 能力边界与许可

固定来源 `Johnserf-Seed/f2`，branch `v0.0.1.8-pw3`，commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`，实际包版本0.0.1.7。[LICENSE](https://github.com/Johnserf-Seed/f2/blob/a30feaf92a40f421273b01b6ef36aa83a93f63c0/LICENSE)根许可 Apache-2.0，根未发现 NOTICE。

未来可评估采用范围：`apps/douyin/model.py` 的实际 detail 参数构造、`crawler.py` 的 `fetch_post_detail`、`utils.py` 的签名调用/默认headers/token初始化、`utils/abogus.py` 等被调用的最小算法依赖（准确闭包须实施时列清单）、`filter.py` 的目标/类型/images字段约定。不能把GPL或额外商业限制实现混入。每个搬运文件须来源commit、copyright、LICENSE、修改记录和适用NOTICE；根Apache不自动覆盖全部依赖分发条件。

本轮 adapter 为自主字段映射，仅将 F2 filter 的 `aweme_detail.images[*].url_list` 作为结构参考，没有复制F2 signer或请求代码；无需新增Python/Dart包依赖。原F2仍只在仓库外执行。

### 默认 x-tt-argus 的真实边界

原 `GatewayHeaderManager.gen_gateway_headers` 总是提供 `x-tt-argus: 1`，有 UIFID/UIFID_TEMP 时另附 uifid；既有配置同名头优先。上轮成功调用包含原默认行为；**成功是否依赖这个头未测**，不能将 F2 与 W2/W3差异归结为该单一变量。

- 离线核对只能确认默认头存在、来源与合并逻辑，不能回答服务器必要性。
- 真正受控对照需要专门授权、同一正常会话、同一请求运行器和时间策略，仅移除该头的一对有界请求；遇明确安全拒绝立即止损，无重试、不追加材料。它是未来独立资格验证，不是恢复H2或Argus逆向。本轮不执行。
- production需求状态 **UNKNOWN / NOT ADOPTED**。值 `1` 没有平台签发或标准协议语义证明，不称为授权context。用户允许原F2默认行为进行验证，不等于允许MediaFlow自行设置它规避安全gate。
- 如后续证明兼容必要且项目边界允许，必须隔离于 F2 compatibility backend 的私有策略，不进入模型/UI/Downloader；仍须证明它不是安全验证绕过。若这一条件不能满足，backend返回明确不可用，不偷偷启用placeholder。不能把可替代协议字段作为既定事实。

这个在线后端门槛不阻塞当前adapter/model/session架构，但足以阻止将原F2 helper直接包装为正式能力。

## Session production UX 与生命周期

状态流程：未建立 → 用户主动正常交互 → ready → expired/invalidated；unsupported与清理失败分别显示明确状态，不假装 ready。

1. 粘贴Douyin图库链接，Application请求本地既有session capability。不暴露Cookie/UIFID/sessionid设置。
2. 没有可用capability时显示“需要抖音会话”，用户选择继续才打开MediaFlow自己的隔离profile；本人处理平台challenge/登录，自动解析暂停，窗口不销毁。
3. 用户取消返回cancelled，不请求detail。本人完成后平台Adapter在必要scope检查最小session，提供opaque handle。UI自报不能替代实际session检测。
4. Windows使用MediaFlow专用WebView2用户数据目录，禁密码保存，采用正常profile持久化；Android对应专用System WebView进程/数据目录或经验证的私有CookieStore，不把已有默认WebView全局Cookie误称隔离。不同Android版本可行性、目录隔离与退出清除需实测；不支持时返回unsupported，不能读系统Chrome。
5. 长期会话仅保存在App私有、平台隔离的受控profile/系统安全存储。身份字段不通过普通MethodChannel/ParserService/模型传递；provider只返回handle。Windows如spike使用helper，平台私有executor通过带请求关联与权限限制的本地管道短时传入最小材料，**生产不使用持久.env、命令行参数或stdout Cookie**。
6. 正常后续使用在本人既有授权和相同平台scope内取得handle，由detail client内部附加平台自身session。不做无关账号操作，不自动静默登录。
7. 过期/平台明确login-required：失效handle，提示“抖音会话已失效，请重新登录”；用户再次选择后才建立会话/重启一次解析。403按具体body分类，不一概当过期；安全验证/权限/地区/付费拒绝返回原因，不自动加头、签名或Cookie。
8. `退出登录并清除抖音数据`：撤销epoch/所有handle，取消在途请求、关闭页面和helper、清cookie/cache/storage/profile、退出运行时、验证消失。失败显示“清理未完成”，禁止旧handle复用；不把单一Clear API成功当清理验收。
9. 旧实测已暴露Clear完成但Cookie非空的风险；最终退出删除成功。实现须覆盖页面刷新重写Cookie、晚到回包、取消和下次重启。不默认立即遍历所有storage或输出敏感state。

自然UIFID不是准入必需；不用人工生成/手填。sessionid/sessionid_ss/ttwid已验证输入能工作，但各项必要性与登录普遍必要性未被单独证明；匿名优先产品原则保留，不为本轮图库强制所有平台登录。

## 模型与 mapper

`MediaContentType.imageGallery`、`MediaResourceType.image`、ordered immutable资源列表、URL、稳定ID均已存在。**不修改 MediaContent/MediaResource/DownloadTask/History 或 mapper**。

- content.id = 上游真实aweme_id。
- resource[i].id = `<aweme_id>:image:<i>`，不依赖会过期的CDN地址。
- resourceIndex = existing ordered list 的0-based位置，adapter保持不跳项/不排序。现有模型没有名为resourceIndex的字段，但已表达顺序；不为重复表达顺序新增持久字段。
- existing mapper按原列表位置生成13个普通DownloadTask，resourceId与contentId写入现有字段，History继续使用现有关系模型。API中无独立task.resourceIndex属性；本轮验证索引到task[i]一致，不宣称新增该属性。
- 只选当前原filter支持的每张图 `url_list` 首个可用HTTPS候选，保留选定URL；缺status/target/type/images/url、空images、中间坏项均明确失败，不悄悄跳过改变顺序。缺desc仅用公开fallback标题，desc不是必要解析字段。
- 公共资源只带公开媒体地址，不附带Cookie或账号Header。图片若实际要求额外授权，下一阶段需先证明并经私有下载context executor解决，不把身份值塞入resource.requestHeaders。
- 不假设图片都是JPEG，不以fixture扩展名强行标mime。CDN候选策略、MIME、URL有效期及下载授权需真实下载验收。

## Windows spike 与 Android同步方案

本轮**不执行production spike**：尚未有具体在线backend、正式session隔离持久化/失效实现，默认placeholder的production使用语义未通过资格判断。不会把仓库外Python成功偷换为production PASS。

Windows有界实施方案：在后端资格确认后，接入独立Application图库用例、Windows SessionProvider、本地 detail client、当前adapter、现有内容预览/资源选择与existing mapper/Downloader。固定样本一次解析须展示13资源，用户选择前2张，用existingDownloader保存、检查2个不同文件、Windows解码器打开、顺序正确、History关系正确。失败按真实阶段记录，不切换endpoint或叠加凭据。仅达到 `WINDOWS GALLERY PRODUCTION SPIKE PASS` 后暂停；不会自行进入Android实现。

Android同时确定方案：同一Dart adapter/内容用例/最小协议核心，平台独立SessionProvider/私有executor；System WebView正常交互和独立profile清理，Downloader继续走现有Android MediaStore。WebView只用于session，不进行Browser Observation内容解析。下阶段唯一目标为 **Android App-owned session + static gallery detail backend 与既有下载链等价验收**；先证明profile隔离/失效/清除和协议可运行，再同样13资源+2图片真机验收。安装前按AGENTS核实applicationId/签名/已有应用，优先独立测试包，不卸载/覆盖正式数据。Windows不能单端宣布版本完成。

## 【项目目标兼容性检查】

| 范围 | 状态 / 风险 |
|---|---|
| Windows | 原F2外部实测已有；本轮新增纯Dart离线adapter，正式spike未实现/未实测；WebView2会话生命周期待验收 |
| Android | 纯Dart映射理论兼容；会话/协议/backend/MediaStore真机链未实测；与Windows同等发布门槛 |
| iOS | 纯Dart映射理论兼容；WKWebView私有session/backend未实现，分发和native适配待验证 |
| macOS | 纯Dart映射理论兼容；WKWebView会话及backend未实现 |
| Linux | 纯Dart映射理论兼容；浏览器runtime/隔离session/backend未实现 |
| Bilibili / Douyin | 原视频/下载模型保留；Douyin新adapter没有接入正式解析，外部成功不等于生产恢复 |
| 小红书 / YouTube / X / Instagram / 其他未来平台 | 本轮未开发，Douyin字段/会话接口限定平台目录，不污染通用层 |
| Detector / ParserService / Parser / Adapter | Detector/ParserService未改，新增Douyin独立adapter；将来Application路由须单独验收 |
| Unified Content Model / MediaContent / MediaResource | 完全复用；多图顺序通过既有ordered列表表达，不增公共模型体系 |
| Downloader / DownloadTask / History | 完全复用，现有mapper回归需执行；真实图片下载和History端到端未测 |
| Media Processing | 未扩展，不把静态图处理放进Parser |
| Browser Adapter | 仅session设计，禁止内容Observation；双端隔离/清理失败语义是已知验收风险 |
| UI / Settings | 没有大改或凭据设置项；正式会话入口尚未实现 |
| Logging / 本地存储 / 隐私 | fixture必须脱敏白名单；真实Cookie只在自有profile/私有memory，不能进入普通日志/模型/history |
| 零服务器 | 本地后端直接请求所属平台，不引第三方解析/云/代理服务 |
| 依赖 / 包体 / 性能 | 正式依赖零新增；最终推荐无Pythonruntime，移植算法成本/包体/耗时仍需测试 |
| 维护 / 正式发布 | 上游commit可追溯，Apache合规仍需采用时逐文件/依赖确认；默认workaround不得未经资格判断入production |

真实fixture来源、测试数量、完整analyze/test结果及文件/Git状态在本轮结果报告填写；不把未完成验证填为通过。
