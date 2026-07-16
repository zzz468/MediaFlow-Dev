# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的记录方式，并使用语义化版本。

## [Unreleased]

### Added

- 基础配置、核心数据模型与媒体模块抽象接口
- 链接 URL 校验、抖音/Bilibili 平台检测与等待解析状态
- 统一 `VideoInfo`、`ParserResult`、`ParserInterface` 与平台解析器接口
- 解析服务、解析状态闭环与视频信息展示
- 多任务模拟下载管理、进度状态和下载记录展示
- 独立网络客户端与统一解析错误码
- Bilibili 真实公开视频信息解析
- 抖音分享页重定向、结构化数据与 Open Graph 元数据解析
- 首页网络封面展示与失败占位

### Planned

- 真实下载引擎与下载选项模型
- 下载任务持久化

## [0.1.0] - 2026-07-16

### Added

- Flutter 跨平台项目基础结构
- Windows、Android、iOS 平台工程
- 路由、主题、状态管理、错误处理与日志入口
- 首页、下载记录页和设置页
- 基础 Widget 测试