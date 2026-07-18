# Android 真机 beta 测试

## 验收环境

- Android SDK：`D:\Android\Sdk`
- 测试设备：一加 13（PJZ110）
- Android 16 / API 36
- USB ADB 真机调试
- 不安装 Android Emulator 或 System Image

## 构建

```powershell
powershell -ExecutionPolicy Bypass -File tool\release\build_android_apk.ps1
```

脚本会检查 SDK、配置 Flutter、构建 APK、复制到 `dist` 并生成 SHA256。

公开发布前应配置项目私有 `android/key.properties` 和 release keystore。缺少该配置时构建会回退到调试签名，仅适合内部测试。

## 真机安装

1. 手机开启开发者选项和 USB 调试。
2. USB 连接电脑并允许调试授权。
3. 执行：

```powershell
D:\Android\Sdk\platform-tools\adb.exe devices -l
D:\Android\Sdk\platform-tools\adb.exe install -r dist\MediaFlow-v0.1.0-beta-android.apk
```

## v0.1.0-beta 验收结果

以下项目已通过：

- APK 安装、应用启动和页面切换
- Bilibili `b23.tv` 短链接解析与真实下载
- Bilibili 标准链接解析与真实下载
- 抖音 `v.douyin.com` 短链接解析与真实下载
- 完成文件保存到 `Download/MediaFlow/`
- MediaStore 索引、文件管理器可见和系统播放器访问
- 真实下载暂停与继续
- 强制停止应用后的历史和暂停状态恢复
- 未完成任务删除与部分文件清理

最终公开资产使用正式签名重新构建后，应再执行一次安装和启动冒烟测试。