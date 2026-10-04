# MediaFlow v0.6.0

版本 0.6.0+6，Windows x64 / Android。新增 Instagram Reel/视频、单图、多图及图+视频 Carousel；X 单视频、单图、多图及混合帖子。资源按原始顺序选择、下载并恢复 History。

继续支持 Bilibili、Douyin、小红书、YouTube。平台协议在独立 Adapter，统一 MediaContent/MediaResource、Downloader、UI、History 复用，不新增第三方解析服务或外部运行时。

- [正式发布审计与资产](release/README.md)
- [Instagram 双端 production 验收](production/README.md)
- [X 双端 production 验收](production/x/README.md)
- [研究与来源](research/README.md)
- [架构边界](architecture.md)
- [Windows](acceptance/windows.md) / [Android](acceptance/android.md)

正式源码在 lib/，测试在 test/、integration_test/；research 子工程不参与 production 编译。仅当前已验证公开样本范围，非官方接口/匿名范围/CDN URL 可变化，不绕过访问限制。iOS/macOS/Linux 未正式验收。
