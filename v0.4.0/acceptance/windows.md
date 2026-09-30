# v0.4.0 Windows 验收计划

状态：**尚未验证**；本文件不是测试结果。阶段 2 冻结 production 范围后填入版本、包 hash、日期、系统与证据位置。

1. 用 Windows Release 包真实 GUI 解析、下载、系统打开 Bilibili 视频、至少双图的 Bilibili 图文、Douyin 视频；检查非空有效文件。
2. 确认多资源选择、每张独立任务、作品聚合卡片、部分失败/重试和最终状态。自然网络失败如发生可记录；不人为制造危险网络条件。
3. 关闭并重启同一 Release，保留应用数据，核对旧与新 History、资源数、文件存在和任务状态。
4. 对阶段 2 批准接入的每个新增 production 内容，重复 GUI 解析、真实保存、系统打开和重启恢复；未接入者只记录研究状态。
5. 记录构建、`flutter analyze --no-pub`、`flutter test --no-pub`、格式与 `git diff --check`，并与 Android 同一冻结范围核对。
