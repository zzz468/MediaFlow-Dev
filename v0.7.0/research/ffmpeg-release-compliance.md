# Phase 3A — FFmpeg release compliance engineering record

本记录是工程措施和来源记录，不是法律意见。Windows 独立 process + shared FFmpeg 冻结；Android 系统原生路线不变。可准备后续集成，但不能据此直接正式分发。

## 来源与实际分发依赖

FFmpeg 8.1.3/n8.1.3，commit 1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7；官方签名源码 archive SHA-256 和工具链见 ffmpeg-build-recipe.md。`CONFIG_GPL=0`、`CONFIG_NONFREE=0`、version3 关闭；运行 `-L` 明确 LGPL 2.1 or later。全部 FFmpeg 源文件未改。关闭 autodetect/network，外部媒体库 **零**，没有 x264/x265/OpenSSL/fdk-aac 等依赖。

| 项目 | 版本 / source | 用途 / 是否进入 artifact | 许可 / 动态 |
|---|---|---|---|
| FFmpeg | official n8.1.3 | 2 CLI + 6 FFmpeg DLL，直接分发 | LGPL-2.1-or-later，shared；内部 permissive notice 保留在完整 source |
| IJG-derived files | n8.1.3 libavcodec/jfdctfst.c、jfdctint_template.c、jrevdct.c | MJPEG/DCT compiled，实际 make log 有对象 | IJG notice；不是独立 libjpeg；未修改，随 NOTICE 带三个头部 |
| MinGW-w64 CRT | commit 57b595039040eaa15bece85b7cc71d952281b269；toolchain fixed recipe pin | 静态 CRT glue，编入 EXE/DLL | ZPL-2.1/PD/BSD/MIT 组合；完整 runtime notice + root COPYING + 对应 source archive；不是外部媒体库 |
| LLVM compiler-rt builtins | LLVM commit 85ac560262434c9ccfc0c183ec22d4138ed647fb / clang 23.1.2 | 工具链静态 builtins，保守包含其 notice | Apache-2.0 WITH LLVM-exception；完整 license 包含 exception，不能只按裸 Apache-2.0 判断 |
| Windows/UCRT | OS components，运行机提供 | DLL imports，不从开发机复制、不分发系统 DLL | Windows 系统运行依赖；需支持的 OS，未新增微软 redistributable |
| LLVM-MinGW wrappers/recipe | 20260922 / 0eca5ac93da14a74bc81c249e841356ececc5d95 | 仅 build tool，不进入 runtime | ISC，保留 license 作为构建来源附件 |
| MSYS2/Bash/make/diffutils | portable base 20260927、Bash5.3.20、make4.4.1、diffutils3.12 | 仅 build tools，不进入 runtime或source companion | 各工具自身 GPL 等，不把 build tool 的许可误当成输出 FFmpeg 的许可；若未来分发整个工具包须另做其合规 |

LLVM/MinGW 版本来自固定 upstream toolchain scripts与实际 compiler version；使用已有固定 toolchain archive编译FFmpeg，不声称已从零重建 LLVM/CRT。LLVM source 获取：[固定 commit](https://github.com/llvm/llvm-project/tree/85ac560262434c9ccfc0c183ec22d4138ed647fb/compiler-rt)，原 license 已附；MinGW full source 已在 companion。没有独立外部媒体库动态或静态链接。

## 已完成的工程措施

- 官方 source、source hash、GPG signature/key、configuration、build recipe、binary manifest、实际 imports 和重复构建证据齐全。
- binary 同目录保留原 DLL 名；不是将 FFmpeg link 入 MediaFlow。模型允许停止 App 后更换兼容的 EXE/DLL，没有 embedded binary、hash enforcement、签名锁或技术限制；不同 major ABI须整组更换。替换机制对未来 installer/自动更新仍需验收。
- `licenses/ffmpeg` 带 LGPL2.1、FFmpeg LICENSE、IJG 三份通知、MinGW root/runtime notices、compiler-rt 完整 exception license、LLVM-MinGW ISC、MediaFlow FFmpeg NOTICE/SOURCE，以及 config+manifest。
- 本地 binary zip 同时生成 `corresponding-source.zip`，包含实际官方 FFmpeg archive（全部内部版权保留）、signature/key、MinGW full source、原样配置、recipe、许可及来源说明。FFmpeg patch=none。source companion与binary必须一起保留和发布，不能只链接浮动 upstream。
- shared方式方便FFmpeg组件替换；不分发MSYS/编译器/开发.lib；没有删除或改写第三方版权。MediaFlow shell/Dart/PowerShell harness 自写，参考官方 build/API 文档，非第三方实现复制。

措施参考 [FFmpeg 官方 checklist](https://ffmpeg.org/legal.html)；完整条款以随附 license 为准，官方页面也不代替法律意见。

## LEGAL REVIEW REQUIRED / 正式发布前事项

1. 未来下载页、关于页、EULA/条款及所有译文的 FFmpeg attribution、源码入口与允许调试/修改 LGPL 组件的条款。当前禁止 production UI，本阶段只准备 NOTICE，不伪称这些入口已上线。
2. 发布 binary/source 同渠道配对、长期可下载性、installer 权限/自动更新是否保留替换空间。当前只有本地部署样本，未上传/发布；正式发布须实际核查。
3. 最终商业模式/司法辖区下 codec 专利与许可证义务的适用性、LLVM exception 与静态 CRT 的组合解释。已提供所有已识别 runtime 的许可/源码链；不声称“100% legally compliant”。若未来新增库、签名约束或封闭 installer，重新审查，不能沿用本结论。

上述是正式产品发布 review，不是未知 source 或缺失直接依赖 license：本阶段关键来源/许可材料已闭合。Phase 3A READY 仅允许讨论下一阶段集成，正式发布尚未通过。未来若发现实际分发 runtime 来源或许可未闭合，必须降为 BLOCKED。
