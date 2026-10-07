# Phase 3A — Windows FFmpeg 构建配方

2026-10-04；仅隔离 release foundation，不接 production。自行编写 bootstrap / shell recipe / verifier / packaging model；没有复制 BtbN 或第三方 FFmpeg wrapper 代码。

## 固定输入

| 输入 | 精确版本 / 来源 | SHA-256 |
|---|---|---|
| FFmpeg | [官方 8.1.3 archive](https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz)，tag n8.1.3，tag object 23151b11c75aa44d9ab8db796a53c76acf00f6c0，commit 1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7 | 7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3 |
| LLVM-MinGW | [20260922 UCRT x86_64](https://github.com/mstorsjo/llvm-mingw/releases/tag/20260922)，recipe commit 0eca5ac93da14a74bc81c249e841356ececc5d95 | e3ad77d117a4bea19a7a3b333341824d79a5a371004a10e25b8504e7b3047666 |
| MSYS2 portable base | [2026-09-27](https://github.com/msys2/msys2-installer/releases/tag/2026-09-27) | ea2f31a0b6ade63914ce441ffb022f0f6aa96982bfefa2326460a26d5fb01322 |
| GNU make build tool | [4.4.1-3](https://repo.msys2.org/msys/x86_64/make-4.4.1-3-x86_64.pkg.tar.zst) | af0bdba17f06fe037f0194069adaa31a8fe45f1a11381501896aea1fae37bd5d |
| GNU diffutils build tool | [3.12-1](https://repo.msys2.org/msys/x86_64/diffutils-3.12-1-x86_64.pkg.tar.zst) | 7902c8ce3d4dd69a0f5e98dc9d5c83c17b23314ba486169db57ef6e2835ce3b6 |
| MinGW-w64 source | [57b595039040eaa15bece85b7cc71d952281b269](https://github.com/mingw-w64/mingw-w64/tree/57b595039040eaa15bece85b7cc71d952281b269)，toolchain 固定脚本中的 pin | a68816e314290facd5da1ac96c7eead7e6de6ea4f709a1fbdcf8185497c57eb2 |

官方源码 detached GPG signature 实际验证成功；从 FFmpeg 官方站取得 key，fingerprint FCF986EA15E6E293A5644F10B4322F04D67658D8。签名是 archive 证据；commit 来自官方镜像 tag 解析，不把 release archive 声称为 Git archive。源码不修改，补丁为零。FFmpeg archive、signature、key 和 MinGW source 已装入本地 corresponding-source companion。

编译器 clang 23.1.2 / LLVM commit 85ac560262434c9ccfc0c183ec22d4138ed647fb；LLVM lld、llvm-ar、llvm-strip 同一工具包；GNU make 4.4.1；Bash 5.3.20。Windows x64/UCRT，FFmpeg 使用 w32threads；无 NASM，关闭 x86asm。工具都放在 poc/local，不系统安装、不开 WSL、不改正式依赖。

## 复建

仓库目录执行 `v0.7.0/poc/windows-ffmpeg/bootstrap.ps1`，核对固定 hash，准备 portable tools 并验签。随后 portable `tools/msys64/usr/bin/bash.exe --noprofile --norc ./v0.7.0/poc/windows-ffmpeg/build-minimal.sh build-a`。路径均相对于仓库；对应源码 companion 中的 recipe 应先还原至此目录结构。已存在构建目录会拒绝执行，不覆盖研究证据。

独立重建使用参数 `build-a-repeat`。实际两次 build 的 2 EXE + 6 DLL SHA-256 **全部相同**，见 ffmpeg-phase3a-reproducibility.json。这是同一固定 Windows 工具链、同一 source/路径、两个新 build directory 的字节复现；未证明不同 OS/工具链/仓库路径的字节一致性。configure 字符串包含本机 source prefix-map 路径，迁移路径应视为新 artifact 并重录 manifest。SOURCE_DATE_EPOCH=1789948800、LC_ALL=C、TZ=UTC，PE timestamp 禁用，strip debug。

完整请求 configuration 见 ffmpeg-phase3a-configuration.txt，实际自动选择组件见 ffmpeg-phase3a-enabled-components.txt，最终 license 输出见 ffmpeg-phase3a-license-output.txt。不能把请求列表当成实际启用列表。

初次 `--disable-postproc` 被 FFmpeg 8.1.3 拒绝，已移除；错误 configure 保留在 local/phase3a/configure-attempt-01。Build A 最初少 cmp，构建仍完成；补上固定 diffutils 后第二次 clean configure 无该警告，runtime 字节完全相同。pkg-config 缺失警告仍在：autodetect 关闭、无启用外部媒体库，实际 DLL import 与 configure 状态另行审计。

## 必需、可选与删减

| 类别 | 必需 / 已实测 | 可选 / 实测范围 | 当前不要 |
|---|---|---|---|
| containers | MP4/M4A/MKV/JPEG；W6 fragmented MP4 H.264+AAC → MP4 | WebM VP9+Opus → WebM，copy + decode 实测，未人工播放 | HLS/DASH 网络抓取、任意新容器承诺 |
| demuxers | mov、matroska、image2 | aac 已启用未单独测 ADTS | 网络、设备 demux |
| muxers | mp4、ipod、matroska、image2、null（验证） | mov、webm；W6 测 fragmented MP4 input | 广泛格式输出 |
| decoders | h264、aac、mjpeg（完整解码核查） | vp9、opus 已做 WebM 解码 | AV1/HEVC/通用视频解码承诺 |
| encoders | mjpeg（frame）、wrapped_avframe/pcm_s16le（null decode verification） | 无 | H.264/AAC 视频音频重新编码、x264/x265/fdk-aac |
| parsers/bsfs | h264/aac/mjpeg，AAC container adaptation | vp9/opus；完整 auto-selected 集合另见配置 | 随意扩展 codec |
| protocols | file；pipe 仅 progress 和 null 输出 | 无 | http/https/tcp/udp 与其他网络 |
| filters | scale/format；anull/aresample 等 CLI 依赖 | configure 自动选 aformat/atrim/crop/hflip/rotate/transpose/trim/vflip | 编辑器、字幕、水印、复杂滤镜 |

stream-copy 的 container 操作不要求 decoder/encoder；JPEG 提取需 H.264 decode + MJPEG encode + pixel conversion。YouTube 当前 parser 接受 MP4/WebM、优先 MP4且不限制所有 codec；本样本支持 H.264+AAC MP4，VP9+Opus 明确选 WebM，不强塞 MP4。其他组合必须 capability/error gate，不能宣称整个平台素材都可处理。W6 是离线 synthetic fragmented streams，不是线上解析成功。

## 分发模型与检查

`package.ps1` 只复制 v0.6.0 已有 Release 至隔离目录：`MediaFlow/processing/ffmpeg/{ffmpeg.exe,ffprobe.exe,6 DLL}`、`MediaFlow/licenses/ffmpeg/`；另附 `corresponding-source.zip`。不包含开发 `.lib`、编译器、MSYS2、BtbN、PoC executable。程序尚未调用这些文件，模型不是新正式 App build。

所有 PE import 用 llvm-readobj 审计：闭包仅六个同目录 FFmpeg DLL及 Windows KERNEL32/SHELL32/bcrypt/UCRT API sets；无 MSYS、winpthread、libgcc、libstdc++、开发机路径。运行 absolute exe，working directory 是输出目录，PATH 仅 System32。移到安装目录模型后再次运行全部六项。此为干净环境模型，不是全新 Windows VM；Windows 10/11 x64 + UCRT 为预期基础，旧版/其他 CPU 未实测。

逐 binary hash/size/import：ffmpeg-phase3a-binary-manifest.json。源与制品配对、许可证措施见 ffmpeg-release-compliance.md。本地资料不能代替未来发布渠道实际提供 source companion。
