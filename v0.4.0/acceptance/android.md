# v0.4.0 Android 验收计划

状态：**尚未验证**；本文件不是测试结果。Windows 与 Android 采用同一 production 范围，各自完成真实 Release 验收。

1. 任何安装或 `flutter run` 之前按根目录 `AGENTS.md` 第三十条核查已有包名、测试包名、签名及是否可能覆盖/卸载/清数据。不能确认数据安全则停止安装并采用隔离测试包或其他安全方式。
2. 在正式 Release GUI 解析、下载、系统图库/播放器打开 Bilibili 视频、至少双图的 Bilibili 图文、Douyin 视频，检查 MediaStore 文件、MIME 和内容有效性。
3. 验证多资源任务、部分失败/重试、作品级 History；保留数据重启后核对混合 History、文件和状态。
4. 对阶段 2 批准接入的每个新增 production 内容重复完整链路。记录设备/系统、包名、签名、安装方式、是否与旧包共存、是否覆盖/卸载/清数据及签名冲突情况。
5. 记录构建与最终回归；不把 Windows 结果或 Debug/PoC 当作 Android Release 通过。
