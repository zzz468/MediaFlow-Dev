# 第一阶段结论（2026-09-25）

**第一阶段目标完成：基线确认、多个参考项目的首轮源码研究、候选路线整理。** 这不是 Douyin 图文功能完成，也不是第二阶段 PoC 完成。此前的规则整理未计作本阶段研究；本阶段新增[基线记录](../baseline-stage1.md)、逐项目记录、[路线矩阵](douyin-gallery-route-matrix.md)并同步阶段状态。

研究项目：`DLWangSan/douyin_parse`、`ucmao/media-parser`、`jiji262/douyin-downloader`、`Ortonzhang/DouyinDownloader`；另单列 `cmsjin/douyin` 的疑似同源关系。前 3 个都触及 Douyin Web detail，但调用参数、Cookie/签名与 fallback 不同；这不能当作独立匿名可用性证明。Ortonzhang 走浏览器观察，也可能看到同一底层 Web detail 响应。`cmsjin` 不计入独立证据。

许可证：`ucmao`、`jiji262` 有 MIT 文件；`DLWangSan` 只有 README 的 MIT 声明、未见独立许可证且有额外措辞；`Ortonzhang` 未见许可证；`cmsjin` 有 MIT 文件但疑似同源。**没有复用任何第三方代码或算法，没有新增依赖。**

未做探索性 PoC：当前既无经本轮确认的公开双图作品，也无明确的低风险匿名入口；旧 Windows 样本已出现 `targetMissing`、403、安全验证或路由壳。直接发起网络 PoC 不能可靠区分样本失效、入口失效和环境阻断。下一阶段如开展 PoC，先锁定公开作品与目标 ID，用受限请求分别在 Windows、Android 验证，安全限制即停止。

本阶段没有修改 production Flutter/Dart、Windows 或 Android 代码；没有安装、覆盖或卸载 Android 应用。未运行 `flutter analyze`、自动化测试、Windows build、Android build、真实平台验收。上述状态均不得写为通过。研究建议进入第二阶段“独立 PoC 验证”，但本阶段结束后暂停，不自行开始。
