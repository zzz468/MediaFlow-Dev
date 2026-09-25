# 最小兼容迁移方案（第二阶段已完成模型与适配器）

## 顺序

1. 已完成：增加独立 `MediaContent` / `MediaResource` 领域类型和离线契约测试，未改 `VideoInfo`、`ParserSuccess`、Parser、UI 或持久化。模型没有新增依赖。
2. 已完成：增加纯函数 `VideoInfo -> MediaContent` 适配器，调用方必须显式传入作品 `sourceUrl`；既不从短时媒体 `videoUrl` 猜作品链接，也不暗中依赖 `metadata['sourceUrl']`。映射视频及必要请求头、标题、作者、描述；只选择一个质量作为当前资源，不把全部质量当作多媒体资源。封面默认只展示，不自动加入下载集合。
3. 保持 `ParserSuccess.videoInfo` 与现有构造函数，先为新调用方提供不改变旧返回值的适配入口。需要第一个非视频 Parser 时，再引入独立的内容成功结果或兼容扩展，并更新 `ParserResult` 穷尽分支测试；不以假的 `videoUrl` 填充图文作品，也不强制旧 UI 理解新结果。
4. 已完成离线映射：每个资源映射一个现有 `DownloadTask`；调用方提供每次操作唯一的 `operationId`，任务 ID 用操作 ID + 资源序号构成，另以可选字段保存 `contentId/resourceId/resourceType`。标题/文件名含稳定顺序号以避免多图同名；传 URL、平台、请求头、建议文件名及 MIME。现有队列与重试沿用原实现。第七阶段已增加只读作品级 History 聚合 UI；批量原子性尚未实现。
5. 分别验证 Windows 本地路径与 Android 私有 `.part` -> MediaStore 发布。图片/音频需实测 MIME、扩展名、重名、失败回滚及文件管理器可见性后才标记支持。

## 旧历史与本地数据

- 不移动、不清空 `download_history.json` 或 `settings.json`，也不变更应用数据目录；现有 `DownloadTask.fromJson` 继续读取 v0.2.0 数组。第一批模型不持久化，因此本阶段**无需历史格式迁移**。
- 已为任务增加可选 `contentId/resourceId/resourceType/suggestedFileName/mimeType`，缺失值兼容读取，旧任务序列化时不写这些键；保留现有 `id/title/url/platform/mode/requestHeaders/status/savePath` 语义。固定 v0.2.0 JSON 夹具和新旧混合历史回读已通过离线测试。不得用新增字段覆盖旧路径或误将已完成任务重新下载。作品关系需按平台与 `contentId` 一同分组，避免跨平台同 ID 冲突。
- 作品级状态不另存：用相同作品下各任务的真实状态推导完成、部分成功、部分失败与进行中。第三阶段时 History UI 仍按单任务展示；第七阶段已加入纯读取投影的作品卡片，见文末。
- 新历史保存会剔除 Cookie/Authorization/Proxy-Authorization，读取旧历史时也剔除这些头；普通 Referer/User-Agent 保留。
- URL 与请求头可能短时失效；恢复时维持既有 paused/failed 语义，过期资源明确报错，不保存浏览器 Cookie 或尝试绕过访问控制。
- Android 现有历史记录存公开路径；后续如需 `content://` URI，必须先设计兼容读取和文件访问方式，不能直接改变旧 `savePath` 类型。Windows 继续使用文件路径。

## 第一批离线契约测试（后续编码时先写）

1. `VideoInfo` 适配：作品源链接与资源直链分离；选中质量/推荐质量只产生一个 video 资源；请求头保留；缺失/非法源链接失败；封面不自动下载。
2. `MediaContent`：多图片顺序、重复资源 ID、空列表、非 HTTP(S) URL、图文/音频类型验证；不接受平台原始响应或 Cookie 存储字段。
3. `ParserResult`：旧 `ParserSuccess(VideoInfo)` 与 Bilibili/Douyin 解析测试继续通过；新内容结果不会被单视频 UI 当成 `VideoInfo` 强转。
4. 资源到任务：多资源产生独立且唯一任务、继承必要请求头、标题与扩展名不冲突；一个任务失败不改动已完成资源。
5. 历史：固定 v0.2.0 JSON 夹具加载、保存回读、混合新旧任务、queued/downloading 启动恢复、损坏记录处理、`.part` 续传。
6. 文件保存：Windows 路径与重名；Android publisher 使用图片/音频 MIME 的 MethodChannel 合同、成功发布与失败保留可续传数据。平台真实发布仍需设备验收。

第 1、2、4 项的离线合同测试和旧历史回读已新增并运行；第 3 项的新内容 `ParserContentSuccess` 已在第六阶段实现并测试。第四阶段补充 Android 真机双图 MediaStore 发布与新容器 History 恢复，第六阶段又通过正式 Parser 双端链；Windows 旧视频真实解析也已复测。第七阶段增加图文 GUI 和只读 History 聚合。Android 旧视频真机联网回归、全部启动恢复情形及 Release 构建仍未执行；DownloadTask、HTTP 媒体类型检查此前已做最小兼容扩展。

## 第四阶段实测更新（2026-09-24）

- 固定公开双图资源测试仅放在 `test/features/downloader/v030_public_gallery_acceptance_test.dart` 和 `integration_test/v030_public_gallery_download_test.dart`。两端都使用第三阶段正式 mapper；Windows 走现有 HTTP 服务/文件仓，Android 还走现有队列及 MediaStore publisher。两张资源分别以 `image-001`、`image-002` 持久化，同一 `contentId` 下独立为 `completed`；历史 JSON 回读及 Android 新容器启动恢复通过。
- 旧 `DownloadTask` JSON 与单视频映射离线回归通过；本阶段没有重测旧视频的真实联网下载、暂停/Range 或两端 Release。作品级 History 聚合、部分失败受控真实测试尚未完成。
- Flutter 匿名 HTTP 获取作品页遇验证码，故不能开始正式图文 Parser 接入。下一步需寻找可由两端正式客户端公开获取的页面/数据路径，或重新比较其他公开样本；不得依赖账号、持久化 Cookie 或绕过验证。

## 第五阶段数据入口更新（仅独立 PoC）

使用普通浏览器风格请求头，Windows 和 Android 的 `HttpNetworkClient` 均可匿名读取双图公开页内嵌 JSON；Android 自身风格 UA 取得移动页 `opus.detail`，Windows 第二样本还恢复了 8 个有序图片出现位置。详见 [数据入口研究](research/bilibili-gallery-source.md)。这满足下一阶段开始独立 Bilibili 图文 Parser 开发的数据入口条件，但**本阶段没有修改** `ParserSuccess`、`ParserService`、任何 production Parser、Downloader 或 History。正式接入时保持旧单视频结果和下载合同，遇验证码/风控拒绝返回明确错误；两种页面结构、图片重复出现是否各自下载、页面变化和固定 UA 的长期有效性需要契约测试和两端验收。
# 第六阶段过渡合同（2026-09-24）

- 旧 `ParserSuccess(VideoInfo)` 构造与非空 `videoInfo` 不变；Bilibili 视频 Parser 和 Douyin Parser 没有改动。需统一内容的调用方继续显式传来源链接，用既有 `VideoInfoMediaContentAdapter` 转换。
- 首个非视频成功返回 `ParserContentSuccess.mediaContent`，不伪造 `VideoInfo` 或 CDN 视频 URL。`ParserService.parseUri` 的返回类型保持 `ParserResult`；调用方按成功分支判断。ViewModel 把图文保存在新 `LinkParserState.mediaContent`；现有单视频下载按钮和质量选择仍走旧字段。后续 GUI 可以从 `mediaContent` 迁移，不需要改变 History JSON。
- 图文每个出现位置映射成独立 `DownloadTask`；即使 URL 相同也保留独立资源 ID、任务 ID 和顺序。历史仍是旧兼容 JSON 数组，作品关系由现有可选 `contentId/resourceId/resourceType` 表示；不删除或迁移旧记录。
- 第六阶段 Windows 正式链实测通过。Android 真机短暂未连接后恢复，经过重新预检，隔离 Debug applicationId 的正式 Parser 到 MediaStore 和 History 组合验收也通过；仍未测试 Release 或 GUI。
# 第七阶段 UI/History 兼容

图文结果通过第六阶段的 `LinkParserState.mediaContent` 进入首页独立卡片；视频继续走 `videoInfo`、质量选择和原下载按钮。图文选择只影响该次操作的资源子集，不改变 Parser 结果。`DownloadTask.copyWith` 仅增加可选 `title` 参数供新 GUI 任务显示作品标题，旧字段、序列化键和旧历史文件格式均不变。History 聚合是纯读取投影，未改 `JsonDownloadTaskRepository`、未迁移或清空已有 JSON；混合旧任务、新多图任务、重复 URL 和同作品不同操作均有离线测试。单资源图文也显示为作品卡片，旧单视频保留原卡片。

受控部分失败使用本地 HTTP 服务器返回一张有效 JPEG 和一个 404，通过正式 mapper 与 HTTP 下载服务后，成功文件仍在，History 回读形成“部分完成”。Windows GUI 默认路径真实双图通过；Android 设备恢复后，隔离 Debug 包 GUI 到 MediaStore、History 的真实双图链也通过，系统图库可打开两张图片。

## 第八阶段抖音图文迁移门槛

本阶段没有改生产迁移链。现有抖音视频仍由 `DouyinParser` 返回 `ParserSuccess(VideoInfo)`，不得将图文伪造成视频；后续只有在至少一个真实公开多图作品的目标 ID、图片数量/顺序、匿名图片 URL、MIME 在 Windows 和 Android 都独立确认后，才新增返回 `ParserContentSuccess(MediaContent)` 的 Douyin 图文分支。现有 feed 的目标匹配和视频要求不放宽；图文平台字段仅在 Douyin 模块内解析。当前调查未满足该门槛，见 [研究记录](research/douyin-gallery-source.md)。

Release 范围冻结：v0.3.0 不迁移 Douyin 图文，也不改变已有 History JSON。其状态为 `researched but not production-supported`，后续版本只有取得新的 Windows/Android 匿名双端证据才重启接入评估。旧视频、新图文及混合 History 的离线合同已测试；Release 环境中的混合 History 重启恢复仍待实测。
