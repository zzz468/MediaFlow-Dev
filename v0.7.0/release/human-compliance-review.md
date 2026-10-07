# v0.7.0 Human Release Compliance Review

日期：2026-10-07。**HUMAN RELEASE COMPLIANCE REVIEW COMPLETE**。

本文件记录工程核对与所有者发布审阅决定，不是法律意见。只有用户明确确认审阅完成后，才能记录 `HUMAN RELEASE COMPLIANCE REVIEW COMPLETE` 并创建正式 tag/Release。

## 可审阅的最终方案

1. FFmpeg 8.1.3 attribution/copyright、LGPL2.1-or-later 与第三方 notices：Windows 包的 `licenses/ffmpeg/`，About、README、[Release Notes](release-notes.md) 均有声明。
2. 对应 source/compliance ZIP **直接作为第三个 GitHub Release asset**，与 Windows/Android 包同渠道提供；不只依赖浮动 upstream 链接。名称、bytes/hash已冻结，Release Notes有匹配下载入口。
3. Windows 为独立 process + shared DLL；允许停止应用后更换兼容整组组件，没有运行时 hash/signature 锁。无封闭安装器或额外 EULA 限制，包中保留完整许可证。
4. GPL/nonfree/network关闭，外部媒体库0；FFmpeg源无修改；IJG、MinGW-w64、LLVM compiler-rt/exception等已识别依赖通知与材料保留。Android FFmpeg=0。
5. 不宣称“100% legally compliant”；codec专利、所在地义务及最终条款解释由人工审阅，不由工程测试代替。
6. 普通 App ZIP 中的 RC 文档文字保留为已验证资产来源；正式仓库与 Release Notes会说明正式发布状态。不修改冻结资产，不重新构建。

工程核对：PASS。源码 tar 签名已复核；runtime 8 hash匹配 approved manifest；三资产的 bytes/hash均再次匹配；NOTICE/SOURCE、About和README声明已检查。

## 人工决定

- reviewer：项目所有者（当前对话的人类用户）。
- review status: COMPLETE
- confirmation：用户对上述明确方案回复“已完成人工审阅，允许 tag/Release”。
- source distribution：直接上传同一 GitHub Release 的第三个 source/compliance asset，已人工确认。
- tag / GitHub Release：人工 gate 已通过；仍须先完成 feature/dev/main、合并后检查及冻结 hash/tag target 核验。

这是对当前冻结三资产及声明方案的人工发布决定，不是“100% legally compliant”的保证；如组件、资产或发布条件变化，必须重新审阅。
