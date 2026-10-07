# Phase 3A — Windows FFmpeg Release Foundation

日期2026-10-04；**PHASE 3A READY**。这是隔离工程基础，不是生产功能或正式发布验收；完成后立即暂停，不进入3B。

仓库D:\projects\mediaflow-v070；branch feature/v0.7.0；HEAD3ba068ae5d42ecabfaa3880afbdee1258a6df26b；`git status --short`仅`?? v0.7.0/`。没有Commit/Push/Merge/Tag/Release/bump。production/Flutter工程/依赖未改；Flutter运行产生的三个registrant换行变化经内容hash核对后还原，未删除用户修改。

## 24项完成汇报

| # | 项目 | 实际结果 |
|---|---|---|
| 1 | upstream/version/commit | 官方FFmpeg8.1.3，n8.1.3，1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7；BtbN仅Phase2基线 |
| 2 | configuration | ffmpeg-phase3a-configuration.txt；GPL/nonfree/version3/network=0、shared=1、autodetect关；实际组件另有snapshot |
| 3 | compiler/toolchain | LLVM-MinGW20260922 UCRT x64，clang23.1.2/LLVM85ac560262434c9ccfc0c183ec22d4138ed647fb、lld/llvm-ar/strip；portableMSYS2、Bash5.3.20/make4.4.1/diffutils3.12 |
| 4 | external libraries | 无外部媒体库；MinGW CRT/LLVM builtins静态运行支持、Windows/UCRT系统imports单独记载；无开发机DLL |
| 5 | license | 最终输出LGPL2.1+，无GPL/nonfree。FFmpeg/JPEG内含notice、MinGWCRT组合、LLVMexception均已附，不拿toolchainISC替代全部binary许可 |
| 6 | source provenance | 官方签名archive SHA7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3，key FCF986EA15E6E293A5644F10B4322F04D67658D8；fresh解压与build用源码diff-qr=0，无补丁 |
| 7 | binary清单/大小/hash | 2EXE+6DLL共7604736bytes；完整每文件SHA/import见ffmpeg-phase3a-binary-manifest.json；二次cleanbuild全部同hash |
| 8 | 体积 | Phase2样本delta174279680/ZIP74861812；当前含notices delta7686644/ZIP3184329；sourcesZIP另27417653；无需BuildB |
| 9 | W1–W6 | 六项全部最终自构建candidate重跑、exit0、probe+完整decode0；新候选系统打开/测试音用户单独确认全部正常 |
| 10 | progress/cancel/errors | machineprogress PASS；实际cancel exit-1，partial/final清理PASS；missing/permission/invalid分型PASS；满盘DESIGN ONLY |
| 11 | 字符路径 | English、space、中文目录/文件名、100–110字符文件名PASS；211字符长路径样本；>260/UNC未测试 |
| 12 | deployment | 旧v060Release的隔离副本+processing/ffmpeg+licenses/ffmpeg；sourcecompanion另包；absoluteexe/仅System32 PATH/其他工作目录/独立EXE验证PASS |
| 13 | LGPL工程措施 | source/config/recipe/manifest/notices配对；保持DLL名称且可替换；同批保留sourceZIP；完整清单见ffmpeg-release-compliance.md |
| 14 | review | LEGAL REVIEW REQUIRED：正式下载页/关于页/EULA/翻译、源码同渠道持续供给、installer替换/更新行为、司法辖区codec专利及条款组合；未正式发布 |
| 15 | Android | SDK路线保持，Phase2证据继续有效，未重测/重写/构建/安装，无新增FFmpeg Android库 |
| 16 | 文件 | 当前9个既有阶段文档更新，新recipe/harness/合规/manifest/evidence/license文件；详细列表下方；删除0 |
| 17 | flutter analyze | PASS：No issues found，21.6s；独立verify.dart analyze亦No issues found |
| 18 | flutter test | `flutter test --no-pub`PASS，376passed/7skipped；不是全部测试都执行 |
| 19 | Windows build | 自构建FFmpeg两次成功、独立DartEXE编译/执行成功；FlutterWindowsRelease NOT RUN：工程未改，部署用已有v060Release副本 |
| 20 | git status | 仅`?? v0.7.0/`；`git diff --stat`空（untracked不会计入，不能解释为没有新增文件） |
| 21 | production | 未接Engine/Windowsbridge/Androidchannel/UI/History/Downloader/YouTubeproductionmux；已有Parser未改 |
| 22 | production dependency | 新增0；portable工具链与FFmpeg仅研究local及拟议分发档案 |
| 23 | Git操作 | 未commit/push/merge/tag/release/bump；HEAD不变 |
| 24 | 下一阶段 | 可在另获授权后进入Phase3B双端productionAdapter集成与同等验收；现在停止，不自行实施 |

## 实际输出与误差范围

固定Phase2素材12s/320×180/25fps/H264/AAC48kmono，三个输入处理后hash保持不变；不使用在线平台解析。W6由固定video/audio本地copy成fragmentedMP4后合并，仍不是真实YouTube下载样本。

| 项目 | ms（验证02） | bytes | duration/内容 | 实际处理 |
|---|---:|---:|---|---|
| W1 | 180 | 314741 | 4.015667s/H264AAC | `-ss 2 -t 4`位于输入之后，streamcopy；不同于Phase2 input-seek参数位置，不要求字节一致或frame-accurate |
| W2 | 128 | 147717 | 12s/AAC，无视频 | copy audio→ipod/M4A |
| W3 | 154 | 909819 | 12s/H264AAC | 两个输入copy→MP4 |
| W4 | 143 | 908968 | 12.021s/H264AAC | copy MP4→MKV |
| W5 | 176 | 8946 | 320×180/JPEG | 3s取帧，H264decode/MJPEGencode |
| W6 | 138 | 909324 | 12s/H264AAC | fragmented streams→MP4，video12.000/audio11.989333s |

全部probe与完整decode通过，W1–W4/W6不重新编码；不证明任意素材/精准裁剪/整个平台兼容。系统播放人工确认是本次新构建六项，原Phase2回复没有沿用。WebM额外测试由Phase2完整工具将固定synthetic素材编码为VP9+Opus，再交最终最小候选copy合并WebM、decode，两次exit0；仅自动验证，未人工播放，未承诺VP9/Opus强行转MP4。

progress stdout使用`out_time_us`/`progress=end`等key；stderr单独有限保留。短任务通常只有末尾事件，未声称平滑UI。cancel通过`-readrate0.25`使真实子进程持续运行后350ms请求终止，总387ms，exit-1；进程PID事后不存在，输出与partial不存在。编译EXE部署验证另轮亦PASS，不能拿单次耗时保证生产性能。

缺失输入在preflight识别不启动子进程；无效媒体实际FFmpeg退出-1094995529；新建独立目录用当前用户ACL拒绝W，partial-create错误5映射outputPermissionDenied，finally还原原ACL；未改系统/正式目录权限。磁盘空间不足未制造真实满盘：设计target-volume预检/估算+reserve，创建或写入遇Windows112/39/ENOSPC才映射diskFull；未知I/O保留有限诊断，不猜测类别。未来3B必须实现/测试，不写成本阶段真满盘PASS。

输入只读、参数数组无shell、本地protocolwhitelist、输出新路径+唯一partial、校验成功rename、失败只删自有partial；overwrite仅允许唯一已创建partial。PoC存在检查与普通rename不保证竞态中的atomic no-replace，3B需补；timeout、崩溃恢复、目录symlink/外盘/SAF/生产storage权限均不在本阶段验收。FFmpeg禁网不是独立进程sandbox，未来仍需最小输入/输出权限和资源限制。

## 体积与deployment

当前同一ZipFile Optimal方法：baseline33292272bytes/ZIP13870165；candidate40978916/ZIP17054494。runtime7604736 + notices81908 = unpacked delta7686644。binaryZIPdelta3184329；对应sourceZIP27417653（FFmpeg full archive+MinGW full source+recipe/notices）另列。若首次一起分发两包，相对baseline下载增加30601982bytes。Phase2旧样本包含完整FFmpeg及PoC EXE，本次模型不带PoC EXE；不能把对比当严格等制品压缩benchmark。新同轮baselineZIP与旧baselineZIP少量不同，不以ZIP字节一致作为验收。

FFmpeg无外部media库、裁去网络/设备/文档/调试/大部分codec/filter；BuildA已合理，不启动BuildB无限优化。关闭x86asm可能影响高分辨率取帧/批量decode性能，1080p/4K性能未验证。操作本身copy不依赖高吞吐encoder。

local/phase3a/deployment内candidate.zip、corresponding-source.zip与manifest哈希配对，尚未上传。processing/ffmpeg目录只有runtime八文件、无开发.lib/toolchain。PE直接+递归DLL闭包只有此组和Windows/UCRT系统依赖。PATH仅System32、cwd另一个输出目录，独立编译的verify.exe重跑全部通过；未使用干净VM，未证明所有Win10/Win11更新级别。正式App未启动/重新构建，旧Release拷贝仅用作尺寸模型。

## 项目目标兼容性检查

| 平台 | 分类与具体限制 |
|---|---|
| Windows | 已实际测试：x64自构建FFmpeg/PoC/部署模型；productionProcessing暂不支持，Flutter新Release未构建；UCRT/禁x86asm/旧OS或ARM有风险 |
| Android | 已实际测试（Phase2历史）：SDK五项/TestAPK与正式包共存；3A未重测或安装；无AndroidFFmpeg，仍需生产bridge/SAF/MediaStore/不同设备验收 |
| iOS | 理论兼容：可独立AVFoundationAdapter；未构建/实测，当前WindowsDLL暂不支持 |
| macOS | 理论兼容：原生/独立processAdapter可替换；未构建/实测，本binary暂不支持 |
| Linux | 理论兼容：可另构建LGPLprocessAdapter；未构建/实测，本binary暂不支持 |

| 模块/目标 | 检查 |
|---|---|
| Bilibili/Douyin/Xiaohongshu/YouTube/X/Instagram/未来平台 | 各productionParser未改，现有自动化基线通过；没有本轮在线解析验证。YouTube实际MIME/codec集合宽于本Processing候选，未来需能力门控；其他平台来源不同codec也不能自动视为支持 |
| PlatformDetector/Parser/Adapter/ParserService | 未依赖FFmpeg或新工具；Processing仅本地文件，不理解站点页面；后续平台Adapter职责保持 |
| Unified Content Model/MediaContent/MediaResource | 未改或强绑单视频；本轮多输入mux参数不进入公共平台模型；后续资源关联尚未实现 |
| Downloader | 未接Processing，无修改队列/Range/.part/resume/HTTP逻辑；Processing.partial与下载.part隔离，真实联合生命周期未验收 |
| Media Processing/Browser Adapter | Processing研究层独立，Browser未改、未引入浏览器身份或抓包；正式能力抽象待3B |
| UI/History/Settings/Logging | 没有正式入口/schema/storage设置/日志实现修改；PoC报告只有自行生成样本路径，未来生产不得照搬完整命令/敏感路径日志 |
| 本地存储/隐私/零服务器 | 本地file-only，无媒体/链接/凭据上传，无远程处理；工具/公开源码研究下载不含用户数据；权限/空间/崩溃恢复生产接入待验收 |
| 第三方依赖/体积 | 正式依赖0，拟Windowsruntime与许可链已记录；新增source companion真实下载体积不可忽略，Android新增nativeFFmpeg0 |
| 性能/维护 | 小样本copy与frame实测，不保证4K/批量；固定安全版本也需后续漏洞升级/重新构建+测试/manifest更新，不能长期浮动latest |
| 正式发布 | 3A foundation就绪；source配对、发布渠道/关于/EULA/installer/legalreview及双端production验收尚需完成 |

Android安装安全（本阶段）：未构建或安装APK，未覆盖/卸载/清除数据、未触发签名冲突实验。Phase2历史Test/Debug package com.mediaflow.research.v070.processing，与正式com.mediaflow.mediaflow共存；不同签名通过独立applicationId隔离，不把它写成可覆盖安装。当前设备状态本阶段未重新核实；后续任何安装必须重新执行AGENTS30检查。

## 17项门槛

1–8：fixed source/version/config、GPL0、nonfree0、全部直接分发依赖notice、对应源码、复建与binaryhash均完成（两build八runtimehash相同）。9–10：W1–W5+W6重跑PASS并人工系统播放确认。11–14：progress/cancel/partial清理/中文空格PASS。15–17：最终unpacked/ZIP实际测量、absoluteexe不依赖PATH、production未接入PASS。关键source或依赖license未闭合项当前0；正式发布review待办明确保留。因此判定PHASE3A READY，不判定正式发布READY。

## 文件与Git

当前阶段修改9个既有文档：README.md、architecture.md、research/{README.md,media-processing-options.md,ffmpeg-options.md,phase2-report.md}、acceptance/{windows.md,android.md}、poc/README.md。它们仍在整体untracked v0.7.0中。

新增：poc/windows-ffmpeg/{bootstrap.ps1,prepare-tools.sh,build-minimal.sh,package.ps1,verify.dart}；research/{ffmpeg-build-recipe.md,ffmpeg-release-compliance.md,phase3a-report.md}；ffmpeg-phase3a-{configuration.txt,enabled-components.txt,license-output.txt,binary-manifest.json,reproducibility.json,sizes.json,package-manifest.json}；phase3a-{evidence.json,deployment-evidence.json,webm-evidence.json}；research/licenses/ffmpeg下完整LGPL/FFmpeg/IJG/MinGW/runtime/compiler-rt/toolchain/NOTICE/SOURCE文件。删除0。local/archive/build/source/log/zip/fixtures/EXE被既有.gitignore忽略，未删除Phase1/2证据。

`git diff --stat`为空；`git status --short`只有`?? v0.7.0/`；没有tracked production差异。i-have-adhd skill仅表达辅助，无额外授权。下一阶段须用户明确授权；本阶段结束即暂停。
