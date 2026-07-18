# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的记录方式，并使用语义化版本。

## [Unreleased]

### Planned

- 多质量、多格式下载选项
- 系统级下载完成通知

## [0.1.0-beta] - 2026-07-18

### Added

- Windows、Android、iOS Flutter 项目基础结构
- Material 3、自适应导航、深色模式与本地设置
- Bilibili、抖音平台识别和公开媒体信息解析
- Bilibili `b23.tv` 与抖音 `v.douyin.com` 短分享链接重定向处理
- 标题、作者、封面、时长和下载可用状态展示
- 顺序多任务下载队列、暂停、继续、删除与失败重试
- HTTP Range 断点续传和 `.part` 临时文件保护
- 下载任务、状态、文件路径、创建时间和完成时间持久化
- 自定义下载目录、启动任务恢复和失败文件清理
- 应用内下载完成提示
- parser、downloader、network、error 本地分类日志和自动轮转
- 本地缓存大小统计和安全清理
- Android 完成文件发布到 `Download/MediaFlow/` 和系统 MediaStore
- 跨 Windows、Android 的安全文件名处理和稳定标题 fallback
- 关于页面、GitHub 地址、Apache-2.0 协议和零成本说明
- Windows 打包脚本、Android APK 构建脚本和发布检查文档

### Validation

- `flutter analyze` 通过
- 52 项自动化测试全部通过
- Windows RC 真实链接解析、下载和播放验证通过
- Android USB 真机安装、真实下载、暂停/继续和历史恢复验证通过

### Known Limitations

- 平台页面结构变化可能导致解析暂时失效
- 当前仅提供单一可用媒体地址，不支持多清晰度选择
- 下载队列顺序执行，不提供多线程下载加速
- 仅处理平台公开可访问的内容，不绕过登录、付费、地区或权限限制
- 公开 Android APK 应使用项目私有 release keystore 签名