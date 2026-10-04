# v0.6.0 Research

阶段：Instagram / X 可行性研究（Phase 2）。正式代码未修改。

已新增 [Instagram options](instagram-options.md)、[X options](x-options.md)、[mixed media model](mixed-media-model.md)、[context matrix](instagram-context-matrix.md)、[third-party provenance](THIRD-PARTY.md)、[validation / 开发报告](social-validation.md)。独立 Flutter PoC 在 `poc/social/`。2026-10-03 用户确认双端全部正常通过；Instagram / X 当前约定样本范围均 **A PASS**，状态 `V0.6.0 INSTAGRAM/X FEASIBILITY READY`。研究停止于此，未接入正式代码。完整反馈范围和限制见验证报告。

Windows 已有真实全量下载证据；Android 独立包名 `com.mediaflow.research.v060.social`，安装前必须核对设备已有应用和签名，失败不得卸载/清数据。第三方运行时仅做隔离对照，不打包。

research / PoC 与 production 隔离；仅保留必要脱敏记录，不保存完整凭据、签名媒体 URL 或敏感页面正文。未测试、环境阻断与功能失败必须分别记录。PoC 成功不代表正式完成。
