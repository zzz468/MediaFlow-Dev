# MediaFlow

当前测试版本：`v0.2.0`（发布前验收中）

MediaFlow 是一个面向 Windows、Android 和 iOS 的免费开源媒体链接处理工具。Windows 与 Android 同为当前核心发布平台，所有设置、下载历史和日志仅保存在本机。

## 当前能力

- Bilibili、抖音公开媒体信息解析
- Bilibili `b23.tv`、抖音 `v.douyin.com` 短分享链接重定向处理
- 标题、作者、封面、时长和平台信息展示
- 顺序多任务下载队列
- 暂停、继续、删除和失败重试
- HTTP Range 断点续传和 `.part` 文件保护
- 下载历史与设置持久化
- 自定义下载目录、深色模式和启动恢复
- 本地下载完成提示和缓存清理
- parser、downloader、network、error 分类日志
- Android 完成文件发布到 `Download/MediaFlow/` 并加入系统 MediaStore

## v0.1.0-beta 验收状态

- `flutter analyze`：通过
- `flutter test`：52 项全部通过
- Windows RC：真实 Bilibili 短链接、标准链接和抖音短链接解析、下载及播放验证通过
- Android USB 真机：APK 安装、应用启动、真实链接下载、暂停/继续和历史恢复通过
- Android 下载文件可在 `Download/MediaFlow/` 和系统文件管理器中查看

## 零成本原则

- 不依赖自建服务器
- 不使用付费云服务
- 不使用商业媒体解析 API
- 优先使用公开信息和本地离线能力
- 不上传用户链接、设置、历史或日志

## 技术栈

- Flutter / Dart
- Riverpod
- go_router
- http / html
- logging
- path_provider
- Material 3

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Windows Release 构建：

```powershell
flutter build windows --release --build-name 0.2.0 --build-number 2
```

Android Release APK 构建：

```powershell
flutter build apk --release --build-name 0.2.0 --build-number 2
```

## 文档

- [使用说明](docs/使用说明.md)
- [User Guide](docs/USER_GUIDE.md)
- [开发指南](docs/开发指南.md)
- [开发计划](docs/开发计划.md)
- [解析模块](docs/解析模块.md)
- [下载模块](docs/下载模块.md)
- [设置与持久化](docs/设置与持久化.md)
- [发布检查清单](docs/发布检查清单.md)
- [v0.1.0-beta 发布说明](docs/v0.1.0-beta发布说明.md)
- [Android 真机测试](docs/Android真机测试.md)
- [v0.1.0-beta 测试报告](docs/v0.1.0-beta测试报告.md)

## 分支

- `main`：稳定发布版本
- `dev`：日常开发与集成版本
- `feature/*`、`fix/*`、`docs/*`：短期工作分支

## 项目地址

`https://github.com/zzz468/MediaFlow-Dev`

## 开源协议

MediaFlow 使用 [Apache License 2.0](LICENSE) 发布。

## 免责声明

MediaFlow 不提供任何平台内容授权，也不绕过登录、付费、地区或权限限制。用户应遵守平台服务条款、版权规则和所在地法律。
