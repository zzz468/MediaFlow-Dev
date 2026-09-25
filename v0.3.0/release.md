# MediaFlow v0.3.0

MediaFlow v0.3.0 在 Windows x64 和 Android 上完成正式 Release 真实场景验收。版本号为 `0.3.0+3`。

## 本版变化

- 引入 `MediaContent` / `MediaResource` 内容模型，保留旧 `VideoInfo` 视频解析接口。
- 一个作品可包含多个资源；下载任务记录作品 ID、资源 ID 和资源顺序。
- Bilibili 公开图文可解析、选择并下载多张图片，History 按作品聚合展示并在重启后恢复。
- Bilibili 视频、Douyin 视频在两端继续可解析、下载及用系统应用打开。

## 平台和范围

- **已实测：** Windows x64、Android 16（OnePlus PJZ110）的正式 Release 包；Bilibili 双图、Bilibili 视频、Douyin 视频及混合 History 重启恢复。
- **本版未接入 production：** Douyin 图文；Xiaohongshu、YouTube、X、Instagram 等后续平台。
- **本版未构建或真实验收：** iOS、macOS、Linux；不宣称这些平台已正式支持。
- 只处理公开可访问内容；不绕过登录、付费、地区、权限或平台安全验证。链接、媒体、设置、历史和日志不上传至 MediaFlow 服务器。

## 发布资产

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `MediaFlow-v0.3.0-windows-x64.zip` | 13,739,644 | `d610a731a4d0ad548e498ce00eb0e7c98fcd7c572a09534e3677a4dc5a1cd4ba` |
| `MediaFlow-v0.3.0-android.apk` | 54,852,547 | `edff7ea0e5334e0e86f54cda92dfcd467b36d01898ccdf65d5df524debe7620d` |

Windows ZIP 延续 v0.2.0 的单目录结构，含 `MediaFlow.exe`、Flutter/WebView2 依赖、README、用户指南、LICENSE 与 `RELEASE_INFO.txt`；已实际解压核对入口和关键 DLL。Android APK 为 `com.mediaflow.mediaflow`，versionName `0.3.0`、versionCode `3`，v2 签名验证通过。正式证书 SHA-256：`16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`；签名 DN 为 `CN=MediaFlowRelease, OU=Release, O=MediaFlow, C=US`，不是 Android Debug。

## 验证与限制

真实 GUI/真机结果分别见 [Windows 验收](acceptance/windows.md)和 [Android 验收](acceptance/android.md)。Windows 图文两张 JPEG 用画图打开，两个 MP4 用系统“照片”应用打开；Android 对应文件由系统图库和播放器打开。双端重启后均恢复一张双图聚合卡片及两个独立视频任务。

最终发布构建后回归：`flutter analyze --no-pub` 无问题；`flutter test --no-pub` 166 通过、5 个 opt-in 实时网络用例默认跳过；格式检查 118 文件、0 改动；`git diff --check` 退出码 0，仅提示 Git 换行符转换。跳过的实时测试不计为通过。Windows 本轮双图没有自然下载失败；Android 双图有一次连接中断，单次重试后成功。单个公开样本的成功不代表平台上所有作品长期可用。

仓库使用 Apache-2.0；本版没有新增生产依赖，也没有直接复制研究所列第三方项目代码。
