# MediaFlow v0.5.0

Windows x64 / Android，版本 0.5.0+5。

- **YouTube support**：metadata、多质量有声视频（progressive/muxed）、无声视频（video-only）、独立音频（audio-only）；用户选择后下载，完整下载与系统播放已在双端真实验收。
- **小红书 support**：公开视频、静态多图解析、资源选择、下载、系统打开、Android MediaStore 与 History，本地匿名、不依赖外部 Cookie 或解析服务器。
- 保留 Bilibili、抖音、通用 Downloader、History、Settings、Logging 和本地存储；补充敏感日志脱敏。

## 已知限制

- 不合并音视频，不引入 FFmpeg，不实现 SABR；无声视频和独立音频分别保存。
- YouTube 短期媒体 URL 不持久化，重启后的未完成任务需要重新解析。
- 抖音图文可按平台要求由用户主动建立 App 自有本地登录会话；不绕过权限、安全验证或地区/付费限制。
- 公开样本通过不代表全部作品或 codec；iOS/macOS/Linux 本版未正式验收。

## 正式资产 SHA-256

- `MediaFlow-v0.5.0-windows-x64.zip` — 13,861,340 bytes
  `b97ec9661a8cf9312588b255a5281311b5acb778ecab2d3cf4ed6439eebf083b`
- `MediaFlow-v0.5.0-android.apk` — 55,534,247 bytes
  `10be266d5607e9ab7b4ae3a964e7ff9d6de4384dcd080a0d7272223414d8321a`

Android 正式包名 `com.mediaflow.mediaflow`，versionName 0.5.0 / versionCode 5；证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`，v2 签名通过，与已发布版本一致。不要先卸载已有应用或清除数据来升级。

最终自动化：302 通过、7 跳过、0 失败；flutter analyze 无问题。
