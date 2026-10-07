# MediaFlow v0.7.0 release record

版本 `0.7.0+7`，日期 2026-10-07。Windows 与 Android 为当前正式支持平台。

[用户 Release Notes](release-notes.md) · [真实 RC 验收](../release-candidate.md) · [人工合规审阅](human-compliance-review.md)

## 冻结资产

| 文件 | bytes | SHA-256 |
|---|---:|---|
| MediaFlow-v0.7.0-windows-x64.zip | 17215232 | `7551aac3bb934b765527e4ae3450d073f660558b2d9a3a7281a9e310b06a10fa` |
| MediaFlow-v0.7.0-android.apk | 56525728 | `fb4be3b691c979251f119ee7a2d836fee1b238b5a52deee4855756a755004856` |
| MediaFlow-v0.7.0-ffmpeg-source-compliance.zip | 27419481 | `db501b067de44803acd6b281903bb2e74a34cbcb85fbe6f8d6465a913c033444` |

三个资产在同一 [GitHub Release](https://github.com/zzz468/MediaFlow-Dev/releases/tag/v0.7.0) 提供；必须核验服务端 filename/bytes/SHA-256 后才报告 RELEASE COMPLETE。此提交记录冻结资产和发布方案，不提前宣称上传已完成。普通 App ZIP 的 RC 文档文字作为已验证制品来源保留，未重新打包替换。

## 合规与许可

**HUMAN RELEASE COMPLIANCE REVIEW COMPLETE**：所有者已确认 attribution、许可、匹配源码同渠道提供、shared组件替换及发布声明方案。不是法律意见或“100% legally compliant”保证。

Windows FFmpeg 8.1.3 为独立 process + shared DLL，LGPL-2.1-or-later。批准 manifest 仅校验构建输入；安装后兼容组件可替换。NOTICE、完整 LGPL、IJG/MinGW-w64/compiler-rt等材料保留于 `licenses/ffmpeg/`，对应源码、配置及 recipe 作为第三个独立 asset；Android FFmpeg=0。

## 验证范围与项目目标兼容性

- RC：format 208 files/0 changed，analyze 无问题，test 458 passed/7 skipped/0 failed；合并后再次执行 analyze/test/diff check。
- Windows/Android Release、升级、关键 Processing/cancel/History及系统打开已实际验收；Windows YouTube 1080p 本轮通过，Android由所有者免本轮复验、沿用前序专项，详见 RC。
- Windows HEVC trim/AAC可用、frame按decoder禁用；本 OnePlus HEVC三操作通过。不是所有设备/codec/HDR能力承诺。
- iOS/macOS/Linux Processing未正式支持或验收，不因源码合并升级为正式能力。
- PlatformDetector/ParserService/Parser/Adapter、多资源 MediaContent/MediaResource、通用 Downloader和独立 Media Processing边界保持；Bilibili/Douyin/XHS/X/Instagram以全量回归和前序证据覆盖。
- Browser/Settings/Logging/本地存储与隐私/零服务器规则保持；本轮没有功能修改、新依赖、新第三方代码复制或转码。新的内容只有发布文字、审阅记录与发布基础脚本。
- >260/UNC、真实满盘、其他OEM/长期压力及crash-resume仍有明确验证边界；正式发布不扩大之前能力声明。

## Git 与最终发布流程

遵循既有非 squash merge：feature/v0.7.0→dev→main，annotated `v0.7.0` 必须指向最终 main commit；各远端 branch/tag target 与本地逐一核验。最终提交 SHA、服务端 assets与Release状态由发布执行结果记录，不能用预期 SHA 或本地 asset 替代服务端核验。

本版本 worktree 保留作归档/修复参考，发布完成后不继续新功能开发。
