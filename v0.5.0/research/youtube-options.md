# YouTube P1：候选路线与验证清单

状态：**待研究；下列项目没有在本阶段重新核对当前源码、活跃度、许可或运行结果。** 不以项目名称推断匿名性、稳定性或可移植性。

## 必查参考项目

| 候选 | 下一阶段重点核对 | 当前结论 |
| --- | --- | --- |
| `yt-dlp/yt-dlp` | extractor、formats/stream 选择、失败分类、依赖和许可证；区分设计参考与运行时嵌入。 | 未核实；本版不引入 Python runtime。 |
| `Tyrrrz/YoutubeExplode` | 流清单、客户端上下文、资源 URL 与质量模型、最近提交/Issues、许可证、Windows/Android 成本。 | 未核实；不引入其运行时作为默认方案。 |
| `TeamNewPipe/NewPipeExtractor` | extractor、stream 类型、访问条件、许可和 Android/JVM 绑定成本。 | 未核实；本版不引入 JVM runtime。 |
| `youtube_explode_dart` | Dart 实现的当前源码、维护、许可、直接嵌入及双端运行结果。 | 未核实；是否适用必须实测。 |
| 其他近期仍活跃的本地实现 | 由最近提交、Issues、测试与真实公开样本筛选，不以 Star 或 README 宣称为准。 | 待筛选。 |

每项均需核对当前源码、最近提交、Issues、LICENSE 与实际运行结果；记录是否匿名、登录/Cookie/session、浏览器上下文、签名/JS runtime、第三方服务器、五端依赖与合法复用边界。只可在核实许可证后决定代码复用；当前仅提出研究对象，未借鉴具体实现或复制代码。

## 最小真实验证问题

1. 用少量明确公开视频，分别在 Windows/Android 取得目标 ID、标题、封面和必要 metadata；记录不可用、年龄/登录/地区/权限/安全验证等失败类型并安全停止，不尝试绕过。
2. 列出发现的流，辨认至少两种质量，以及 progressive/muxed、video-only、audio-only 的真实字段、MIME/容器/编码、URL 有效期和请求条件。比较不同项目对同一流的分类，不把“可发现”当“可交付”。
3. 验证用户可选项与最终下载资源的映射：单文件内容实际下载、文件类型与系统播放器可打开性；分离流只能分别判定，不能在无合并能力时宣称完整音视频文件。
4. 检查短效 URL、Range/续传、重试、文件名、封面下载选择、History 重启恢复与失败提示是否适配现有通用路径；平台特有逻辑留在 YouTube Adapter。
5. 比较纯 Dart/本地协议、平台浏览器 Adapter 和参考实现的技术可行性、双端成本、维护风险、依赖许可、隐私和五端路径。第二阶段据证据决定 production 路线及 `MediaContent/MediaResource` 是否需最小扩展。

本版优先不引入 FFmpeg、Python/JVM runtime 或第三方解析服务器。若能力目标离不开新依赖或受平台访问要求限制，形成证据与范围建议，不能用未经验证的 workaround 直接进入 production。
