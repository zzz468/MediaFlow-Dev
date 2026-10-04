# 混合媒体模型审计

只审计，不修改 production。PoC 直接使用 `lib/features/parser/domain/media_content.dart` 与 `lib/core/models/media_link.dart` 的只读源码快照，没有第二套作品/资源领域模型。

| 项目 | 现状 | 后续结论 |
|---|---|---|
| MediaContent.type | video/image/imageGallery/article/audio/mixed | 可表达混合作品，无须本阶段改模型 |
| MediaResource.type | video/image/audio/cover | 可表达三类主体资源；cover混合了物理类型和角色，未来字幕/attachment需求出现时渐进拆分，不能当前提前重构 |
| 原始顺序 | resources不可变有序List | PoC可保留数组顺序；缺失任何child整作品失败。未来筛选/跨批恢复时可考虑显式sequenceIndex；现在诊断记录index，不新增正式字段 |
| preview/thumbnail | 作品coverUrl | 足够作品封面；逐item预览目前不足，未来按实际UI需求加入可选预览，封面不能占据正文媒体序号 |
| variant/quality | qualityLabel、尺寸、bitrate、codec、container、trackRole | 已能描述选定资源与音视频轨道，缺少variant组关系；先选一项不重复算媒体数量。HLS/DASH合并不属于本PoC |
| Downloader mapper | 遍历任意resources，resourceType/id/MIME/建议名；taskID后缀保留ordinal | 静态审计能映射混合类型。PoC不调用正式Downloader，也不修改Mapper；正式队列/Range/恢复未做新回归，不能声称正式混合下载已验收 |
| History projection | `_imageOperationId` 仅 resourceType=image 分组；视频独立条目 | 混合作品会拆分，未来production接入前须设计统一operation/sequence聚合与测试。当前不改 |
| Platform枚举 | unknown/douyin/bilibili/xiaohongshu/youtube | 尚无Instagram/X。PoC content.platform=unknown，真实平台仅research诊断。正式接入前需平台注册与迁移审计，不能用unknown完成正式产品 |
| 身份与持久化 | MediaResource禁止Cookie/Authorization，requestHeaders仍是通用Map | 本次CSRF只在独立HTTPAdapter，不进模型/History/日志；未来认证header应继续受控，不能因当前黑名单未列某header就暴露身份 |

建议边界：平台Adapter获取ordered主体资源；每个variant在作品媒体中只占一个位置；下载器只保存资源；History聚合同一操作并保留原序号；媒体处理保持独立。ParserService/UI/Settings不认识平台页面结构。音频/字幕/封面是角色/轨道问题，不能靠平台 if 分支堆在公共层。

实际证据：14项自动化测试包含Instagram image→video→image、legacy sidecar、X image→video、缺失child拒绝、ID不匹配、HLS-only、403/429/auth、URL边界、凭据隔离、token参考一致性和系统打开文件目录校验；X真实混合数组图片→视频成功下载。Instagram真实混合Carousel、audio资源下载及正式History聚合未验收。
