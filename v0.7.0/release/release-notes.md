# MediaFlow v0.7.0

本版面向 Windows 和 Android，继续保持本地处理、隐私优先与零自建服务器。

## 新功能

- 本地视频快速裁剪、AAC 音频提取为 M4A、指定时间抽取 JPEG 图片。
- 独立 Processing History，支持打开最终处理文件和重启恢复。
- YouTube H.264 + AAC 双流自动下载并合并，History 仅记录最终文件。
- 默认选择当前完整下载与合并链可用的最高兼容清晰度，同时保留手动选择。
- HEVC 手机视频按具体操作和设备能力判断兼容性。

## 改进

- 处理进度和取消反馈、文件冲突保护、输出校验与原子发布。
- 本地视频/音频 codec 与每项处理能力检测。
- 保留已有下载历史、设置和 storage 设置的升级兼容性。

## 重要限制

- 快速裁剪受关键帧边界影响，不是帧级精准剪辑。
- 部分 YouTube VP9/AV1 高清流当前不自动转码，最终兼容画质可能低于平台最高画质。
- Windows 当前无法对 HEVC 视频抽帧；Android 以当前设备实际解码能力为准。
- 部分 HDR / Dolby Vision 高级动态元数据裁剪后可能无法完整保留。
- AAC 提取不转换其他音频 codec；Android 阻塞抽帧采用协作取消。
- iOS、macOS、Linux Processing 当前未正式支持或验收。

## 下载与升级

- Windows：解压完整 `MediaFlow-v0.7.0-windows-x64.zip`，运行 `MediaFlow.exe`。
- Android：安装同签名 `MediaFlow-v0.7.0-android.apk`；升级无需卸载或清除应用数据。
- 升级保留旧文件，不会重新下载或提高旧视频的分辨率。

| 文件 | bytes | SHA-256 |
|---|---:|---|
| MediaFlow-v0.7.0-windows-x64.zip | 17215232 | `7551aac3bb934b765527e4ae3450d073f660558b2d9a3a7281a9e310b06a10fa` |
| MediaFlow-v0.7.0-android.apk | 56525728 | `fb4be3b691c979251f119ee7a2d836fee1b238b5a52deee4855756a755004856` |
| MediaFlow-v0.7.0-ffmpeg-source-compliance.zip | 27419481 | `db501b067de44803acd6b281903bb2e74a34cbcb85fbe6f8d6465a913c033444` |

## FFmpeg 许可与对应源码

Windows 包使用 FFmpeg 8.1.3，Copyright (c) 2000–2026 the FFmpeg developers，按 LGPL 2.1 或后续版本分发。许可证、版权及依赖通知位于包内 `licenses/ffmpeg/`；Android 不包含 FFmpeg。

匹配的 [source/compliance ZIP](https://github.com/zzz468/MediaFlow-Dev/releases/download/v0.7.0/MediaFlow-v0.7.0-ffmpeg-source-compliance.zip) 与 Windows/Android 用户资产在同一 Release 提供，包含实际 FFmpeg 源码、签名、构建配置/recipe、MinGW-w64 源码与许可材料。MediaFlow 未修改 FFmpeg 源码。源码及构建记录也见仓库 `third_party/ffmpeg/` 和 `v0.7.0/research/ffmpeg-build-recipe.md`。

Windows 使用独立 EXE 与 shared DLL，停止 MediaFlow 后可整组替换为保持文件名与 ABI 兼容的 FFmpeg 组件；应用运行时不锁定组件 hash 或签名。构建时批准的 manifest 校验不限制安装后的替换。

MediaFlow 为 Apache-2.0；第三方组件按各自许可证分发。上述为来源与发布说明，不宣称“100% legally compliant”，不提供内容授权或绕过平台限制。
