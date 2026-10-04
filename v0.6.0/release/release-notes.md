# MediaFlow v0.6.0

Windows x64 / Android，版本 0.6.0+6。

- **Instagram support**：公开 Reel/视频、单图、多图与图+视频 Carousel，原始顺序选择/下载、系统打开和 History。
- **X / Twitter support**：公开单视频、单图、多图与图+视频混合帖子，复用 ordered MediaContent/MediaResource。
- **Mixed / ordered media**：按原帖顺序创建和恢复下载任务，不按类型重排；支持单项、多项或全部选择。
- 继续支持 Bilibili、Douyin、小红书、YouTube，以及通用 Downloader、History、Settings 和本地存储。

## 验证与隐私

本轮重新执行：167 文件格式无改动，flutter analyze 无问题，全量 flutter test **376 通过、7 跳过、0 失败**，git diff --check PASS。正式 Release 最小 smoke 结果见发布报告；此前已归档的双端公开样本完整下载、播放、混合顺序和冷启动恢复继续作为发布证据。

本地处理、零自建/第三方解析服务器，无外部 Cookie 导入、FFmpeg 或 Python/Node/JVM 新运行时。数值转换代码来源 yt-dlp，Unlicense 已保留并随资产分发，无 yt-dlp 运行时。

## 已知限制

- 仅当前已验证公开样本，不保证全部作品匿名可用；非官方接口、访问范围和短期媒体 URL 可能变化。
- 完成文件可从 History 打开；URL 失效的未完成任务需重新解析。不合并 HLS/DASH 音视频、不实现 SABR。
- 抖音既有 App 自有主动会话流程保留；不绕过登录、付费、地区、权限或安全验证。
- iOS/macOS/Linux 未正式构建或验收；Android旧版本存储分支和大规模压力未本轮实测。

## 正式资产 SHA-256

- MediaFlow-v0.6.0-windows-x64.zip — 13880567 bytes
  a36427af50919808ff4ec21e26660c42243da2ef04c0655e6c48939137b45b6e
- MediaFlow-v0.6.0-android.apk — 55863403 bytes
  002a300b8ad5b95340952eabd4a7176c150600bdf4440c73596a94efd9d6ff7b

Android 正式包名 com.mediaflow.mediaflow，versionName 0.6.0 / versionCode 6；signer CN=MediaFlowRelease, OU=Release, O=MediaFlow, C=US，证书 SHA256 16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba；v2 验证通过，v3 未启用，沿用当前签名配置。不要先卸载已有应用或清数据升级。
