# Android 真机 beta 测试

## 最小环境

建议安装到 `D:\Android\Sdk`：

- Android SDK Command-line Tools
- Platform Tools
- 一个当前目标 SDK Platform
- 与目标 SDK 匹配的 Build Tools

不要安装 Android Emulator 或 System Image。最小 SDK、Gradle 依赖和构建缓存预计占用约 3–5 GB，具体取决于下载版本和缓存状态。

## 构建

```powershell
powershell -ExecutionPolicy Bypass -File tool\release\build_android_apk.ps1
```

脚本会检查 SDK、配置 Flutter、构建 APK、复制到 `dist` 并生成 SHA256。

如果仓库根目录没有 `android/key.properties`，beta APK 使用调试签名，适合免费测试，不适合应用商店正式发布。

## 真机安装

1. 手机开启开发者选项和 USB 调试。
2. USB 连接电脑并允许调试授权。
3. 执行：

```powershell
D:\Android\Sdk\platform-tools\adb.exe devices
D:\Android\Sdk\platform-tools\adb.exe install -r dist\MediaFlow-v0.1.0-beta-android.apk
```

## 真机检查

- 应用可以启动和切换页面
- 粘贴和解析 Bilibili/抖音链接
- 创建、暂停、继续和删除下载任务
- 修改下载目录相关设置
- 关闭应用后重新启动并恢复历史
- 清理缓存不会删除下载记录