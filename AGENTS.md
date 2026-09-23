# MediaFlow 项目级总指令

> 适用范围：仓库 `zzz468/MediaFlow-Dev` 全部开发活动，以及在本仓库工作的 Codex / Agent。
>
> 具体任务指令与本 `AGENTS.md` 冲突时，以 `AGENTS.md` 的项目级约束为准，除非项目所有者明确修改该规则。发现冲突时，必须说明冲突点，不得自行放宽规则。
>
> 本文件记录已确认的长期规则；不构成任何具体功能开发或 Git 写操作的授权。

这是 MediaFlow 后续开发的长期项目级总约束。

以后所有修改、重构、新功能、Bug 修复、平台适配、媒体处理和 UI 调整，都必须以本指令为最高项目约束。

不能为了当前某一个问题、某一个平台、某一个测试链接或某个第三方项目的现成实现，牺牲 MediaFlow 的长期架构目标。

项目：

`zzz468/MediaFlow-Dev`

## 一、核心原则

MediaFlow 必须长期坚持：

- 本地优先
- 隐私优先
- 零自建服务器
- 不依赖付费云服务
- 不依赖商业媒体解析 API
- 不上传用户链接
- 不上传用户设置
- 不上传下载历史
- 不上传日志
- 不上传 Cookie
- 不上传媒体内容
- 不把用户登录平台账号作为正常使用前提
- 不绕过登录、付费、地区、权限或平台安全限制
- 当前将 Windows 与 Android 同等作为核心发布平台
- 长期支持 Windows、Android、iOS、macOS、Linux
- 平台可插拔
- 内容类型可扩展
- 下载能力通用化
- 媒体处理模块化
- Browser 能力 Adapter 化
- UI 可替换
- 核心业务尽量平台无关
- 渐进式演进，不做无必要的大规模重构

## 二、产品长期定位

MediaFlow 不应被设计成：

“只支持 Bilibili 和抖音的视频下载器”。

长期定位应是：

“多平台媒体内容解析、下载、导出和本地处理工具”。

未来计划支持的平台包括但不限于：

- Bilibili
- Douyin / 抖音
- Xiaohongshu / 小红书
- YouTube
- X / Twitter
- Instagram
- 后续其他公开媒体平台

所有架构设计都必须考虑未来支持 5 个、10 个甚至更多平台后的可维护性。

## 三、多平台解析架构

每个平台的解析逻辑必须尽量独立。

新增平台时优先通过新增独立：

- Parser
- Adapter
- Platform Service

实现。

不得不断把平台特例堆入公共业务层。

长期推荐流程：

URL / Share Link

→ PlatformDetector

→ Platform Parser / Adapter

→ Unified Content Model

→ Optional Media Processing

→ Download / Export

→ History

要求：

1. 平台特有页面结构必须放在对应平台模块。

2. 平台特有 Cookie、Header、匿名会话、签名兼容、WebView、浏览器适配等逻辑必须隔离。

3. 避免在公共模块中大量出现：

`if platform == douyin`

`if platform == youtube`

`if platform == instagram`

等平台判断。

4. Downloader 不应直接依赖具体 Parser。

5. History 不应理解平台页面结构。

6. Settings 不应与某个平台实现强绑定。

7. UI 不应直接调用某个平台底层 Parser。

8. 各个平台最终转换成统一领域模型。

9. 如果某个平台必须使用浏览器环境，应通过可替换 Browser Adapter 接入。

10. 不允许因为某个平台实现困难，就把平台特殊逻辑污染 ParserService、Downloader 或公共领域模型。

核心目标：

“平台可插拔”。

## 四、统一内容模型

MediaFlow 未来不只处理视频。

长期应支持至少：

- Video
- Image
- ImageGallery
- Article / TextPost
- Audio
- MixedMedia

例如：

- 抖音视频
- 小红书图文
- 小红书多图作品
- Instagram 轮播
- Instagram 视频
- X 图文
- X 图文 + 视频
- YouTube 视频
- 视频 + 封面
- 视频 + 音频
- 视频 + 字幕
- 多媒体混合内容

因此不能永久绑定：

“一个作品 = 一个 VideoInfo + 一个 videoUrl”

这一设计假设。

长期推荐演进为：

MediaContent

→ List<MediaResource>

MediaContent 表示一个作品，可以包含：

- id
- platform
- title
- author
- description
- sourceUrl
- publish metadata
- contentType
- resources
- 其他通用公开元数据

MediaResource 表示具体媒体资源，例如：

- video
- image
- audio
- cover
- subtitle
- attachment
- thumbnail
- 其他未来资源类型

当前不要求立即推翻 `VideoInfo`。

但：

- 新代码不得继续制造强烈的“所有作品一定是单视频”耦合。
- 当现有模型真正阻碍图文、多图、音频或混合内容时，应提出渐进式迁移方案。
- 不进行没有实际需求支撑的大规模提前重构。

## 五、Downloader 长期通用化

Downloader 长期不能只理解一个 `videoUrl`。

未来应支持：

- 单视频
- 单图片
- 多图片
- 图片集
- 图文组合
- 视频 + 封面
- 视频 + 音频
- 多媒体作品
- 一个作品包含多个 MediaResource

推荐长期流程：

MediaContent

→ MediaResource[]

→ Download Tasks

→ Download / Export

Downloader 不应理解：

- 抖音页面结构
- 小红书页面结构
- YouTube 页面结构
- Instagram 页面结构

平台特有的：

- Referer
- User-Agent
- Cookie
- Header
- 下载 URL
- 文件名建议

应通过 MediaResource / DownloadRequest 元数据传递。

现有下载能力不得被破坏：

- 下载队列
- 暂停
- 继续
- 删除
- 失败重试
- HTTP Range
- 断点续传
- `.part` 文件保护
- 下载历史
- 启动恢复
- 本地文件管理

## 六、媒体处理能力模块化

MediaFlow 未来不仅负责解析和下载，还会增加本地媒体处理功能。

包括但不限于：

- 视频提取
- 图文提取
- 图片集提取
- 封面提取
- 音频提取
- 文案提取
- 标题、作者等公开元数据提取
- 图文水印处理
- 视频动态水印处理
- 图片处理
- 视频裁剪
- 转码
- 音频分离
- 格式转换
- 后续其他个性化本地媒体处理能力

这些能力必须和平台 Parser 分离。

禁止直接把媒体处理逻辑写进：

- DouyinParser
- XiaohongshuParser
- YouTubeParser
- InstagramParser
- Downloader

应设计独立：

Media Processing Layer

或：

Processor / Pipeline

长期流程建议：

MediaContent

→ Optional Processor Pipeline

→ Processed MediaResource

→ Download / Export

核心原则：

“Parser 负责获取内容，
Processor 负责处理内容，
Downloader 负责保存内容。”

同一个处理能力应尽量可以复用于不同平台来源的媒体。

## 七、UI 必须可替换

当前 UI 不是永久固定设计。

未来可能重新设计：

- 首页
- 链接输入方式
- 分享链接接收方式
- 解析结果页面
- 视频预览
- 图片宫格
- 图文页面
- 多资源选择页面
- 下载任务页面
- 历史记录
- 设置页面
- 导航结构
- 主题
- 桌面布局
- 移动端布局
- 整体视觉风格

因此要求：

1. Parser 不能依赖某个 Widget。

2. Downloader 不能依赖具体 UI。

3. History、Settings、Media Processing 必须独立于 UI。

4. 不要把核心业务逻辑直接写入 Widget。

5. UI 应通过稳定的 Application / Domain 接口调用核心能力。

6. 未来整套 UI 重做时，不应要求重写 Parser、Downloader 和 Media Processing。

7. 当前单视频 UI 不能反过来限制未来领域模型。

8. 桌面和移动端可以采用不同布局。

长期目标：

“UI 可替换，核心能力可复用”。

## 八、长期五端支持

MediaFlow 长期计划支持：

- Windows
- Android
- iOS
- macOS
- Linux

当前 Windows 与 Android 同为核心发布平台，不能通过延后或降低其中一端的验收标准来完成当前版本。

但所有核心架构必须考虑未来五端扩展。

要求：

1. Domain 尽量平台无关。

2. Application 尽量平台无关。

3. Parser 核心接口尽量平台无关。

4. Downloader 上层接口尽量平台无关。

5. Media Processing 上层接口尽量平台无关。

6. 平台差异集中到：

Platform Adapter / Infrastructure Layer

不要把大量：

- `Platform.isWindows`
- `Platform.isAndroid`
- `Platform.isIOS`
- `Platform.isMacOS`
- `Platform.isLinux`

散落在业务代码中。

允许不同平台底层实现不同。

例如：

Windows：
- WebView2
- Windows 文件系统能力
- Windows 通知

Android：
- Android System WebView
- MediaStore
- Android 文件权限和通知

iOS：
- WKWebView
- iOS 文件、分享和系统能力

macOS：
- WKWebView
- macOS 原生能力

Linux：
- 合适的 WebKit / 浏览器运行时
- Linux 桌面系统能力

但这些差异必须尽量通过 Adapter 隔离。

不得因为 Windows 当前优先，就让公共领域模型、Parser、Downloader 或 Processor 永久绑定 Windows API。

## 九、平台特有功能和 PoC

某项能力如果当前只能在某个平台实现，可以阶段性标记：

`platform-specific`

或：

`PoC`

但必须明确说明：

- 为什么目前只能支持该平台
- 是否只是验证方案
- 其他平台是否存在合理实现路径
- 后续需要补哪些 Adapter
- 是否影响公共架构
- 是否可以替换

PoC 成功不代表可以直接作为最终正式架构。

## 十、Browser / WebView Adapter

如果某个平台公开页面必须在正常浏览器 JavaScript 环境中运行，可以使用 Browser Adapter。

但 Browser Adapter 必须独立。

不能把 WebView 逻辑直接堆进 Parser 主文件。

建议长期结构：

Platform Parser

→ Browser Adapter Interface

→ Windows WebView2 Adapter

→ Android WebView Adapter

→ iOS WKWebView Adapter

→ macOS WKWebView Adapter

→ Linux Browser Adapter

Browser Adapter 可让页面在本地浏览器环境运行，并在必要范围内读取 DOM、JS 状态或已经加载的网络响应。平台 Parser 也可研究客户端公开可访问的接口、请求参数、签名算法和客户端协议兼容。是否官方推荐、是否非官方实现、是否涉及逆向分析，本身都不是停止条件；每条路线仍须逐项评估稳定性、维护成本、登录依赖和隐私影响。

这些能力不得用于绕过登录、付费、地区、权限或平台安全验证，也不得扩展成与解析任务无关的通用抓包能力。

禁止：

- 导入用户 Chrome Cookie
- 导入用户 Edge Cookie
- 导入 Safari 登录态
- 读取用户平台账号登录信息
- 注入登录 Cookie
- 破解验证码
- 自动绕过验证码
- 伪造设备指纹规避风控
- 主动求解平台安全挑战
- 高频重试规避 WAF
- 使用用户账号作为默认解析前提

遇到：

- 登录要求
- 验证码
- 付费限制
- 地区限制
- 权限限制
- 额外安全验证

必须安全停止并返回明确错误。

## 十一、隐私、本地化与零服务器原则

必须长期保持：

- URL 不上传
- 下载历史不上传
- 设置不上传
- 日志不上传
- Cookie 不上传
- 媒体不上传
- 媒体处理尽量本地执行
- 内容解析尽量本地执行

临时匿名 Cookie：

- 能不保存则不保存
- 仅保存必要范围
- 明确生命周期
- 不长期跟踪用户
- 不与用户平台账号登录状态混合
- 不作为跨设备身份标识使用

如果某项功能必须依赖：

- 自建服务器
- 外部解析服务器
- 商业解析 API
- 付费云服务
- 远程媒体处理

必须先停止实施并向我说明。

不得默认引入。

## 十二、现有能力保护

所有修改必须保证 MediaFlow 现有目标仍然可以完成。

包括但不限于：

- Bilibili 解析
- Douyin 解析框架
- PlatformDetector
- ParserService
- Downloader
- 下载队列
- 暂停 / 继续
- 删除
- 失败重试
- HTTP Range
- 断点续传
- `.part` 文件保护
- History
- Settings
- Logging
- 本地持久化
- Windows 构建
- Android 构建
- Android Download / MediaStore
- iOS 长期实现路径
- macOS 长期实现路径
- Linux 长期实现路径

不允许为了单个平台 Bug，破坏公共模块。

## 十三、依赖管理

新增依赖之前必须评估：

- 为什么必须使用
- 是否存在替代方案
- 是否可以自行实现更轻量部分
- Windows 是否支持
- Android 是否支持
- iOS 是否支持
- macOS 是否支持
- Linux 是否支持
- 是否明显增加安装包体积
- 是否增加运行时依赖
- 是否增加维护风险
- 是否长期维护
- 是否依赖远程服务
- 如果该项目停止维护是否容易替换

如果依赖只支持少数平台：

不得直接让核心业务层绑定它。

必须通过 Adapter 或抽象接口隔离。

## 十四、开发与重构策略

不要因为未来目标很大，就现在一次性重构全部项目。

采用渐进式开发。

原则：

1. 当前 Bug 优先解决。

2. 稳定能力优先保护。

3. 新代码不制造明显长期架构债务。

4. 当现有模型真正阻碍新功能时，再重构。

5. 重构必须配套自动化测试。

6. 每次修改必要范围。

7. 不为了“未来可能需要”进行没有实际收益的大改。

8. 不为了当前某条测试链接写死平台、设备、作品 ID。

9. PoC 和生产架构必须分开。

10. 不把临时 workaround 当成长久架构。

11. 不因第三方平台频繁变化，污染公共领域层。

总体原则：

“现在可用，同时为未来保留正确边界。”

## 十五、当前抖音问题特别约束

当前抖音匿名 HTTP 流程已经确认受到浏览器 JavaScript / WAF 环境影响。

允许调查可在本地客户端维护的请求参数、签名算法和协议兼容实现，但不得无限叠加过时签名、随机 Token、固定设备参数或脆弱的硬编码。不得伪造设备指纹规避风控、主动求解安全挑战，或绕过登录与访问控制。

如果继续使用 Browser Adapter：

目标是让可访问页面在本地浏览器环境正常执行，并在明确的范围内观察页面已经加载的数据；匿名会话和跨轮身份状态必须有可验证的生命周期。也可以比较独立的本地客户端接口路线，不把 Browser Adapter 预设为唯一方案。

抖音长期流程可以保持：

SSR

→ SSR 数据不完整

→ 安全 HTTP 降级

→ 检测 Browser / WAF 环境

→ Browser Adapter

→ Unified Content Model

同时 Browser Adapter 应考虑未来是否能够复用于：

- Xiaohongshu
- Instagram
- X
- 其他需要浏览器执行环境的平台

不能设计成完全不可复用的 Douyin 黑盒。

## 十六、GitHub 参考项目与代码借鉴

开发过程中，如果 GitHub 上存在成熟、可靠、相关的开源项目，可以主动搜索、阅读和参考。

允许参考：

- Parser 设计
- URL 识别逻辑
- Browser Adapter
- WebView 集成
- Downloader
- 多资源下载模型
- 图文模型
- 图片集模型
- 音频处理
- FFmpeg 封装
- 跨平台适配
- Cookie / Session 生命周期
- 错误处理
- 测试方式
- UI 交互思路
- 性能优化
- 模块边界
- 架构设计

但是：

MediaFlow 项目级总指令优先级永远高于参考项目。

第三方项目的成功实现是技术可行性线索，即使它使用非官方接口或逆向分析，也应评估其本地实现条件；不能因为别人这样实现就直接照搬。

## 十七、参考项目采用规则

参考任何 GitHub 项目之前必须判断：

- 它解决什么问题
- 是否真的适合 MediaFlow
- 是否依赖服务器
- 是否依赖登录
- 非官方接口或协议的稳定性、更新频率及失效风险
- 是否需要登录态或绕过访问控制
- 是否高度平台绑定
- 是否引入不必要依赖
- 是否能长期维护
- 是否符合 MediaFlow 当前架构
- 是否符合五端长期目标
- 是否符合本地和隐私原则

优先级应是：

1. 借鉴设计思想
2. 借鉴接口和模块边界
3. 借鉴算法
4. 最后才考虑直接复用代码

不要无脑复制整个模块或整个项目。

## 十八、开源许可证要求

任何实际代码搬运或修改复用之前，都必须检查开源许可证。

包括但不限于：

- MIT
- BSD
- Apache-2.0
- MPL
- LGPL
- GPL
- AGPL
- 自定义许可证

必须评估其是否会影响：

- MediaFlow 发布
- 二进制分发
- 开源义务
- 源代码披露义务
- 二次修改
- 商业使用可能性
- attribution 要求

禁止直接复制：

- 没有明确许可证的代码
- 来源不明代码
- 明确禁止再分发代码
- 许可证与 MediaFlow 未来发布方式存在重大冲突的实现

如果许可证存在重要风险：

先汇报，不要直接搬运。

## 十九、参考代码必须可追溯

如果实际采用 GitHub 项目的代码或明显基于其实现修改，完成汇报必须注明：

- 项目名称
- GitHub 仓库
- 参考文件 / 模块
- 借鉴内容
- 是“设计参考”还是“代码复用”
- 原项目许可证
- MediaFlow 做了哪些适配
- 为什么符合 MediaFlow 项目级总指令
- 是否需要保留版权或 attribution

必要时在源码、NOTICE、LICENSE 或文档中保留许可证要求的信息。

## 二十、非官方实现与参考项目的安全边界

可以研究本地客户端可实现的非官方接口、签名算法、协议兼容、浏览器自动化，以及第三方项目的数据来源与实现方法。非官方、逆向或平台未提供公开 API，不单独构成停止条件；“别人能够实现”应作为线索继续验证，不自动等于适合 MediaFlow。

每种候选路线分别报告技术可行性、稳定性、Windows / Android 适配成本、维护风险、平台更新导致失效的原因、登录态需求，以及对用户账号和隐私的影响。优先用最小验证确认真实能力，再决定是否接入生产 Parser。

仍禁止依赖第三方解析服务器或付费商业解析 API，向第三方解析服务上传用户链接、Cookie、Token 或账号凭证，导入用户浏览器登录态，绕过登录、付费、地区、权限或安全验证，以及使用代理服务规避地区限制。平台特有实现必须留在 Parser / Adapter / Infrastructure 边界内；参考代码必须核实来源和许可证，不得直接复制不兼容或来源不明的代码。

## 二十一、参考项目选择标准

优先参考：

- 最近仍维护
- Issue / PR 活跃
- 有自动化测试
- 架构清晰
- 有明确 LICENSE
- 有跨平台思路
- 没有大量硬编码
- 不依赖不可控服务
- 代码结构清楚
- 对异常处理充分

Star 数只能作为参考。

不能因为 Star 高就直接认定适合 MediaFlow。

## 二十二、第三方实现必须隔离

如果一个参考项目只支持某个平台：

它的实现只能进入相应：

- Parser
- Adapter
- Infrastructure

不能因此让：

- Downloader
- ParserService
- UI
- Unified Content Model
- Media Processing

依赖某个平台特有结构。

## 二十三、第三方代码仍必须做自己的测试

不能因为原项目测试过，就认为 MediaFlow 不需要测试。

所有引入或改写的第三方实现都必须加入 MediaFlow 自己的验证。

至少覆盖：

- 原有能力回归
- 公共接口契约
- 异常响应
- 网络失败
- 空响应
- 数据结构变化
- 依赖不可用
- 平台能力不可用
- 构建影响
- 五端兼容性影响

## 二十四、允许主动寻找参考实现

Codex 在解决任务时，如果发现：

“GitHub 上已经存在成熟可靠的类似实现”

可以主动告诉我并参考。

不需要每次都从零发明。

但在实际采用之前必须先完成：

- 架构兼容判断
- 安全边界判断
- LICENSE 判断
- 跨平台判断
- 依赖判断

如果风险较大：

先汇报，不要直接搬运。

最终原则：

“可以借鉴，不盲目复制；
可以复用，不破坏边界；
许可证优先；
MediaFlow 自己的长期架构优先。”

## 二十五、每次任务完成后的项目目标兼容性检查

每次完成较大的：

- 功能
- Bug 修复
- 架构调整
- 平台适配
- 新依赖
- 第三方代码引入

必须增加：

【项目目标兼容性检查】

逐项说明：

- Windows
- Android
- iOS
- macOS
- Linux

并分别标记：

- 已支持
- 已实际测试
- 构建通过但未实测
- 理论兼容
- 暂不支持
- 有平台特有风险

同时检查：

- Bilibili
- Douyin
- Xiaohongshu
- YouTube
- X
- Instagram
- 其他未来平台
- PlatformDetector
- Parser / Adapter
- Unified Content Model
- MediaContent
- MediaResource
- Downloader
- Media Processing
- Browser Adapter
- ParserService
- UI
- History
- Settings
- Logging
- 本地存储
- 隐私
- 零服务器
- 第三方依赖
- 安装包体积
- 性能
- 后续维护
- 正式发布

不得默认写：

“无影响”。

如果有潜在风险，必须明确说明具体原因。

## 二十六、每次开发完成后的汇报格式

完成任务后至少汇报：

1. 修改文件
2. 新增文件
3. 删除文件
4. 核心实现逻辑
5. 为什么采用该设计
6. 是否参考第三方项目
7. 第三方项目名称及 LICENSE
8. 借鉴了什么
9. 是否直接复用代码
10. 是否新增依赖
11. 新依赖五端支持情况
12. 自动化测试结果
13. 静态检查结果
14. Windows 构建结果
15. Android 构建结果
16. iOS 状态
17. macOS 状态
18. Linux 状态
19. 真实场景验证结果
20. 尚未验证项目
21. 已知限制
22. 风险
23. 项目目标兼容性检查
24. `git diff --stat`
25. `git status`

不得：

- 把“未测试”写成“通过”
- 把“构建成功”写成“真实功能验证成功”
- 把 PoC 写成正式完成
- 把单个链接成功写成整个平台完全恢复

## 二十七、Git 操作规则

除非我明确授权：

不要：

- Commit
- Push
- 创建 PR
- 合并分支
- 删除现有修改
- Reset 工作区
- 强制覆盖代码
- 强制 Push
- 删除分支

完成开发和测试后先汇报。

只有当我明确说：

“可以提交”

或者给出明确 Git 操作指令后，才能执行。

## 二十八、长期最终架构目标

MediaFlow 的长期架构统一定义为：

“平台可插拔

+ 内容类型可扩展

+ MediaContent / MediaResource 通用化

+ 下载能力通用化

+ Media Processing 模块化

+ Browser 能力 Adapter 化

+ UI 可替换

+ Windows / Android / iOS / macOS / Linux 五端可持续扩展

+ 本地优先

+ 隐私优先

+ 零服务器

+ 可合理借鉴成熟开源项目

+ 不被第三方项目反向绑架架构”。

以后任何重要技术方案都必须检查：

1. 新增更多平台后还能不能维护？

2. 支持图文、多图片、音频、混合媒体后还能不能复用？

3. 增加水印、转码、音频等处理能力后会不会污染 Parser？

4. 整套 UI 重做后核心能力还能不能直接复用？

5. Windows、Android、iOS、macOS、Linux 是否存在合理实现路径？

6. 是否让核心业务层绑定某个系统 API？

7. 是否仍符合本地、隐私和零服务器原则？

8. 是否只是为了当前某个链接写临时 Hack？

9. 是否只是因为某个 GitHub 项目这样实现，就无脑照搬？

10. 第三方许可证是否允许？

11. 两年后是否仍有合理维护路径？

如果答案明显是否定的：

不要把该方案作为最终架构实施。

## 二十九、当前最高开发原则

MediaFlow 当前阶段始终以：

“稳定完成现有目标

+ 保护现有能力

+ 渐进扩展新平台

+ 渐进支持图文、图片、音频和混合媒体

+ 为未来本地媒体处理留出正确架构

+ 保持 UI 可替换

+ 保持五端长期扩展能力

+ 合理借鉴成熟开源项目

+ 不制造长期架构债务”

为最高优先级。

如果具体任务与本项目级总指令发生冲突：

优先遵守本项目级总指令，并明确向我说明冲突点。
