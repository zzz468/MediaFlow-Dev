# 双端验证与当前阶段报告

2026-10-03；分支 `feature/v0.6.0`；基准 HEAD `d3f1f86bd0575305586a8507c22ff0d78bdf529d`。本阶段仅 `v0.6.0/` 内研究代码、报告和证据。尚未 commit/push/merge/tag，未接 production。

## 等级与停止点

A PASS：两端真实公开样本、结构化列表、完整下载、顺序、系统打开均通过；有音轨需画面/声音确认。B LIMITED PASS：路线真实可用但类型/匿名范围等有明确限制。C BLOCKED：当前边界下不能取得足够数据/资源。两端人工验收未完成时标记 `PENDING USER VALIDATION`，不为了输出等级把“待测”写成 B 或 C。

最新验收（2026-10-03）：用户确认「windows和android全部能正常通过」。按此前约定的固定样本、完整下载、系统打开/播放、类型与顺序验收流程，Instagram 与 X 均为 **A PASS（当前样本范围）**。阶段状态：`V0.6.0 INSTAGRAM/X FEASIBILITY READY`。这是汇总人工反馈，没有新增逐资源诊断导出；原始记录见 `evidence/user-validation-2026-10-03.json`。不推断全平台匿名可用或 Instagram 真实混合 Carousel 已通过。研究在此停止，未授权 production 接入或 Git 写操作。

本次仅更新研究文档和验收证据，没有修改代码或新增依赖；未重复运行测试或构建。此前 14 项测试通过、静态检查无问题、Windows/Android research Release 构建通过的结果保持原记录。下文自动测试中的 Android SocketException 和早期待验收描述属于历史记录，保留以追溯环境差异，当前人工验收状态以上述反馈为准。

## 固定样本

用户提供：X 2102857143263085031（视频）、2106263058905813231（双图）、2106209623682453836（单图）；Instagram DdoJxTMFFgi（4图）、Dd_OJNzCVSU（Reel）。分享查询参数移除。上游补充：X carrotsprout_/1577924293023133696（图→视频）、Instagram BqvsDleB3lV（单图）。均只请求所属平台，不调用第三方解析 API。

Windows：Instagram 三类、X 四类元数据与全部资源成功；具体文件字节数见 instagram-options.md / x-options.md 和 `evidence/validation-*.json`。9张图片 Windows解码成功、哈希不同。MP4结构/轨道检查不等于播放器/音画验收；见 `evidence/windows-mp4-containers.json`。系统打开、播放、顺序、类型已收到上述用户汇总通过反馈，没有新增逐项记录。

Android：research `com.mediaflow.research.v060.social`，Release build 3 包以本地 Debug key签名，仅研究用途。设备 [DEVICE] / PJZ110、Android API37。安装前检查的既有包：com.mediaflow.mediaflow、com.mediaflow.mediaflow.galleryv040、com.mediaflow.research.v040.lifecycle、com.mediaflow.research.v050.feasibility、com.mediaflow.mediaflow.youtubeprodv050；不存在本次 package，首次安装与这些包共存，不涉及替换其签名。构建证书SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。只允许 adb install -r，不调用卸载/清数据；若后来发现已有同包名，必须先比较设备APK证书再更新。

Android所有下载均写App私有目录，再由research平台Adapter发布MediaStore，图片通过BitmapFactory解码，视频通过MediaExtractor检查轨道。自动固定样本入口仅在明确 `research_batch` 启动extra下启用；没有登录/账号操作/自动系统播放。该入口仅为真机诊断，不影响正常手工测试按钮。

## 手工验证操作

Windows ZIP 解压后运行 `mediaflow_social_research.exe`；Android打开“MediaFlow v060 Research”。无需用户自行安装 APK。点击固定样本按钮 → 测试元数据 → 对每个资源下载 → 用系统应用打开此文件 → 选择图片正常/音画正常确认与顺序/类型确认。没有音轨不要确认“有声音”，在反馈框说明。另测 X 混合样本；Instagram真实混合尚无固定样本，不据fixture声称完成。

保存诊断与反馈写本地JSON；也可复制诊断反馈给本对话归档。系统启动intent成功不等于打开/播放成功，只有用户确认才改验收状态。Android publication需要API29+，API24-28构建可安装但本research未实现MediaStore替代路径。

网络/错误分层：Socket/DNS/Timeout/TLS只判 BLOCKED BY ENVIRONMENT；明确401/login redirect/login_required判 PLATFORM REQUIRES AUTH；403原因未知判 PLATFORM ACCESS DENIED并停止；429判PLATFORM RATE LIMITED；200但无匹配媒体或格式缺失判 TECHNICAL ROUTE FAILED。Android本轮确有SocketException环境阻断，按任务要求转人工验证，不反复重试，不将其写成技术失败或登录要求；不使用代理绕过地区限制。

## 开发报告

1. 修改文件：仅现有 v0.6.0/research/README.md 将补充本阶段入口；production修改0。
2. 新增：instagram-options.md、x-options.md、mixed-media-model.md、instagram-context-matrix.md、THIRD-PARTY.md、本报告；poc/social（Dart解析、测试UI、本地文件Adapter、Android/Windows宿主、模型快照、测试/工具）；reference审计源码/许可证/提交/issue；evidence诊断、哈希与解码结果。完整清单见 evidence/research-file-list.txt。
3. 删除：0；未删除原有改动。
4. 实现：Instagram本轮匿名CSRF初始化+doc-id；X公开syndication； ordered resources转现有模型；受控HTTP、完整文件长度检查、.part保护、逐资源系统打开、本地反馈。
5. 设计原因：便于核对真匿名能力；跨平台Dart；平台协议隔离；不给正式Parser/Downloader/UI带入临时协议或运行时。
6–9. 第三方参考/许可/借鉴/复用：见THIRD-PARTY；仅yt-dlp radix36数值算法翻译复用，其他为设计/协议参考；GPL extractor不搬运至Dart。
10–11. 正式依赖新增0；research运行时只Flutter SDK/dart:io/services；Python三工具只隔离对照，包不会包含它们。不存在FFmpeg/Node/JVM/Docker正式负担。
12–13. 自动化14项通过（含Windows路径分隔符/目录边界检查）；flutter analyze无问题。最终包为0.6.0 build 3。
14–15. Windows和Android research Release均构建通过；正式应用本阶段未重建，不将research成功说成正式构建成功。
16–18. iOS/macOS/Linux：模型和解析理论兼容；本PoC仅有Windows/Android文件Adapter，其他系统打开/存储未实现，未构建/实测。
19–20. 真实Windows解析/完整下载已做；Android及人工结果见下方实测记录。系统播放器音画、真实Instagram混合、敏感/限制内容、长文/引用、HLS-only和最高原始质量未验收。
21–22. 已知限制/风险：非官方协议ID与数据变化、匿名范围受限、CDN时效、单变量组不能证明某个header单独必要；MediaStore旧Android风险；History图片聚合不能直接用于混合；平台enum缺失。
24–25. git diff --stat对tracked文件为空，因为所有v0.6.0均untracked；git status为 `?? v0.6.0/`。最后实际Git状态另保存，不stage。

## 【项目目标兼容性检查】

| 项目 | 状态与具体边界/风险 |
|---|---|
| Windows | research构建通过，真实解析下载和图片解码已实际测试；系统播放未验收 |
| Android | research构建通过；API37设备已实际安装、Instagram四图解析下载/解码/MediaStore通过；X和Instagram Reel受本轮网络阻断；API24-28的发布能力有平台特有风险 |
| iOS | 解析/模型理论兼容；需要本地存储/系统打开Adapter，暂未实现、未构建 |
| macOS | 同上，理论兼容；需文件/打开Adapter，未构建 |
| Linux | 同上，理论兼容；需桌面打开Adapter，未构建 |
| Bilibili / Douyin / Xiaohongshu / YouTube | 正式模块未修改，未重新做各平台真实回归；不能以隔离研究测试替代它们验收 |
| X / Instagram / 未来平台 | 本地平台HTTPAdapter隔离；仅固定样本证据，不是全平台恢复；新增更多平台需各自协议/匿名范围维护 |
| PlatformDetector / ParserService | 未接入research；正式尚无新平台注册，下一阶段需审计enum/分发 |
| Parser / Adapter | research独立实现；HTTP状态明确停止，协议变化维护成本存在 |
| Unified Content Model / MediaContent / MediaResource | 复用现有快照；顺序可表达混合，角色/variant扩展仍有后续需求 |
| Downloader | 不接正式队列/Range/恢复；research仅完整保存，不支持生产下载队列能力 |
| Media Processing | 没有加入处理；不把转码/合并放入Parser |
| Browser Adapter | 未加入浏览器运行时/Observation；不是本次主路线 |
| UI | 新增仅research UI；正式UI未改；手工音画/顺序确认仍必须进行 |
| History | 正式未改；仅图片聚合的已知混合缺口记录为下一阶段设计任务 |
| Settings / Logging | 正式未改；研究诊断不输出CSRF/Cookie/原始响应和带分享参数的URL |
| 本地存储 / 隐私 / 零服务器 | App私有目录+本地MediaStore/Windows目录；只请求所属平台；不上传诊断/媒体、不依赖外部解析服务器 |
| 第三方依赖 / 安装包体积 | 正式无新增；research APK约46.6 MiB，Flutter Windows运行时独立；参考Python工具不打包 |
| 性能 | 单作品、有界512MiB/5min资源预算；未做吞吐/内存压力测试；长图/超大媒体会受限 |
| 后续维护 / 正式发布 | 本PoC未production ready；需双端人工验收、稳定范围矩阵、许可证版本固定、History/平台枚举设计后另授权 |

## Android真实结果与人工反馈

首次安装build 2返回 Failure[-99]，立即停止；当时package未安装，无卸载/清数据。用户确认“不小心返回了，重新安装”后，最新build 3首次安装Success、启动成功。versionCode=3/versionName=0.6.0；已确认全部既有MediaFlow包仍共存，没有覆盖/卸载/清数据、没有发现同包签名冲突。固定样本自动验证已完成，见 evidence/android-batch.json。X三个样本及Instagram Reel均因网络异常标记BLOCKED BY ENVIRONMENT，不能判为技术路线失败/需要登录，不自动重试。Instagram DdoJxTMFFgi的4图在Android元数据200、全部JPEG全量200，字节数与Windows一致，3277×4096实际Bitmap解码成功并发布MediaStore。系统打开/音画/顺序人工验收仍待反馈。


最新测试产物：artifacts/MediaFlow-v060-instagram-x-windows-build3.zip（EXE：mediaflow_social_research.exe），artifacts/MediaFlow-v060-instagram-x-android-build3.apk；完整哈希见evidence/build3-artifacts.json。状态：INSTAGRAM/X MANUAL VALIDATION READY - USER TEST REQUIRED。
