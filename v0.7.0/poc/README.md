# Phase 2 隔离PoC复现说明

## Phase3A（当前）

`windows-ffmpeg/bootstrap.ps1`、`prepare-tools.sh`、`build-minimal.sh`提供固定来源/哈希/配置工具链；`verify.dart`消费Phase2既有固定素材，不在最小binary中启用素材生成encoder/lavfi。`package.ps1`创建旧正式Release副本+最小runtime/notices和对应源码companion，仅隔离模型。Windows禁用network、参数数组、absoluteexe、controlledpartial。

运行新验证workspace：`dart v0.7.0/poc/windows-ffmpeg/verify.dart <absolute-bin> <absolute-fixed-fixtures> <new-output>`；也可 `dart compile exe` 后用独立EXE，已实跑。可选环境变量MEDIAFLOW_DENIED_DIR用于本次独立ACL权限测试；只在新建研究目录拒绝本用户写权限并finally还原，不触及App/素材/正式安装目录。不要把Phase2生成器直接交给最小binary。

源码、工具、build、zip、EXE、fixtures均在ignored poc/local/phase3a；可审查的configuration/hash/JSON/许可在research。不要重跑已有build/output目录，不清理Phase2证据。详细recipe/错误记录/zip尺寸见 [新报告](../research/phase3a-report.md)。以下为Phase2复现历史。

此目录不接production、不改版本号；所有输出/二进制/测试key在D盘的ignored `local/`或`android/build/`。完整结论见[研究报告](../research/phase2-report.md)。复现将生成新素材，字节hash可能不同。

## Windows

先按[来源许可档案](../research/ffmpeg-options.md)下载并核对LGPL shared archive，保留version/license/buildconf。不要把latest URL当版本锁定，不使用GPL/nonfree替代。当前本地bin：

`D:\projects\mediaflow-v070\v0.7.0\poc\local\ffmpeg\ffmpeg-n8.1-latest-win64-lgpl-shared-8.1\bin`

```powershell
$bin = 'D:\projects\mediaflow-v070\v0.7.0\poc\local\ffmpeg\ffmpeg-n8.1-latest-win64-lgpl-shared-8.1\bin'
dart v0.7.0/poc/run_windows.dart "$bin/ffmpeg.exe" "$bin/ffprobe.exe" 'D:/projects/mediaflow-v070/v0.7.0/poc/local/new-run'
dart compile exe v0.7.0/poc/run_windows.dart -o v0.7.0/poc/local/processing-poc.exe
v0.7.0/poc/local/processing-poc.exe "$bin/ffmpeg.exe" "$bin/ffprobe.exe" 'D:/projects/mediaflow-v070/v0.7.0/poc/local/new-release-run'
dart v0.7.0/poc/probe_native.dart $bin 'D:/projects/mediaflow-v070/v0.7.0/poc/local/windows-run-01/素材 中文 sample.mp4'
```

run路径必须全新，拒绝覆盖旧实验。生成12s素材、video-only/audio-only；五项及cancel/损坏输入/覆盖保护，输出report.json。取消当前小样本由真实progress事件触发，PID/exit与partial核查须保留，不能把进程已完成后取消当停止实验。progress对短任务只有1事件，不保证流畅UI。

`mf_probe.cpp`可用VS2022 x64 SDK编译，链接mfplat.lib/mfreadwrite.lib/mfuuid.lib/ole32.lib；运行传入sample完整路径，300帧decode/HRESULT0才是本轮结果。它不是五操作实现。

## Android构建（不自动安装）

需要JDK17、AndroidSDK platform36/build-tools36.0.0，脚本参数可替换路径。

```powershell
v0.7.0/poc/android/build.ps1 -FixtureDirectory 'D:/projects/mediaflow-v070/v0.7.0/poc/local/windows-run-01'
v0.7.0/poc/android/measure-apk.ps1
v0.7.0/poc/android/measure-production-packaging.ps1 -ProductionApk 'D:/projects/mediaflow-v070/v0.7.0/poc/local/installed-mediaflow.apk'
```

build.ps1只构建独立Test/Debug包，测试key只在ignored build生成；非production签名。measure-apk的no-op baseline绝不安装/用作结果。measure-production-packaging仅量化engine DEX打包，生成DO-NOT-INSTALL APK（正式package+测试签名，未接Flutter入口），**绝不安装**。

安装前每次核对设备、已装package、APK package、两边证书、数据安全，遵守根AGENTS第30节。本轮新包无-r安装，com.mediaflow.research.v070.processing与正式包共存。不提供自动卸载或清数据逻辑；重跑旧workspace会拒绝覆盖。确需重测需另选独立包/workspace或在已确认安全的测试数据范围内另行操作，不能删除正式数据。

首次运行通过Activity extra `run=true`执行两轮；系统打开可点测试App按钮。CLI启动已有task时须 `am start -W -f 0x10008000 -n com.mediaflow.research.v070.processing/.PocActivity --es open trim`，该flag只重建**PoC task界面**，不会清应用数据；operation可用extractAudio/mux/remux/extractFrame。不带clear-task时系统播放器可能占据task顶端，旧Intent不重建PoC，这一路已排除。

输出：`/sdcard/Android/data/com.mediaflow.research.v070.processing/files/processing-poc/`，可adb pull到D盘。`checkRestart=true`只清理marker授权的固定restart-owned.partial并检查成功输出保留；不是跨重启编码续跑。不要用带run=true的旧Intent重启已有素材目录。

## 实验产物

- local/windows-run-01/report.json：JIT。
- local/windows-release-run-01/report.json：编译EXE。
- local/native-ffi-probe.json、mf-probe.json：候选probe。
- local/android-run-01/report.json、android-restart.json、android-independent-verification.json。
- local/ffmpeg-{version,license,buildconf,encoders,decoders,formats,protocols}.txt。
- local/windows-package-specimen/及windows-{baseline,candidate}.zip：旁放engine的体积样本，不是正式App调用。
- android/build/apk-size.json、packaging/sizes.json：APK口径与差异。
- research/phase2-evidence.json与hash档案：可版本化摘要，不包含用户凭据或媒体。

不重复下载旧FFmpegKit或构建完整FFI来证明本轮已经完成的copy操作。正式桥接、最小binary/source合规和新增codec验证属于下一阶段，当前停止。
