# Mobile Feed 精确目标：网络前离线审计（2026-09-28）

当前参考commit=`ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6`，2026-09-28T05:00:44Z；本轮API查询HEAD后按SHA读取parser/base/transport/docs/LICENSE/tests。前轮固定commit不是当前HEAD，不能只沿用缓存。当前BaseParser换为ParserSession并新增可配置代理；本轮完全不运行参考代码、不使用代理或其环境配置。根LICENSE MIT；只源码/设计参考，无代码复制/新增依赖，signer冻结。

## 离线关键结论

`src/parsers/douyin_parser.py:88` 将 `/note/`、`/slides/`、`/share/note/`、`/share/slides/` 标记is_note。`data`的823–842行：图文直接Web detail→若终端filter则结束→分享SSR→return None。845行mobile feed在此return之后。**参考Mobile Feed主路径是常规视频，不是其图文获取路线。**`get_image_list:1546+`读取已取得data的多种图片数组，并不另发Feed或创建图文数据。mock tests663+测视频feed/failover，831+测图文Web→SSR；不是实际图文Feed成功证明。

参考完整Mobile Feed行为（53–63、403–443行）：

| 项 | 当前源码 |
|---|---|
| endpoint/优先级 | 1 api5-normal-c-hl.amemv.com；2 aweme.snssdk.com；均 `/aweme/v1/feed/`，HTTPS GET |
| query/插入顺序 | `aweme_id=<id>&aid=1128`，仅这两项；未有顺序必要性证据，实验保留 |
| UA | `com.ss.android.ugc.aweme/290101 (Linux; U; Android 10; zh_CN; Pixel 4; Build/QQ3A.200805.001; Cronet/TTNetVersion:5f9037be 2023-01-13 QuicVersion:4668bb42 2022-11-21)` |
| Accept | `application/json, text/plain, */*` |
| Referer/Host | 不显式Referer；Host由endpoint传输层决定，不额外伪造 |
| Cookie/Token/signer | Feed方法不加Cookie/Token/UIFID/signer；使用self.session，已有Cookie可能自动附加，不能仅因无显式header宣称任何调用状态绝无Cookie |
| device/version/region | query均无；UA声明app版本/Android机型/build/zh_CN，不能误写“请求完全没有版本/设备信息” |
| 传输 | session.get timeout4、verify=False，Requests默认redirect；session层可能按attempt使用代理/总预算，本轮不采用 |
| selection | top JSON `aweme_list`，`str(item.aweme_id or item.id or '') == str(target)`，取首个精确匹配；不把列表首项当目标 |
| 未命中 | 继续第二endpoint；异常/非200也可fallback；源码注释承认节点收录不同，不证明因果或等价镜像 |

请求专用headers不使用constructor的Chrome sec-ch/sec-fetch/fullWeb headers。存在BogusSigner构造不等于Feed发签名；本轮不实例化它。

## 差异矩阵

| 项 | MediaFlow v0.2 production | v0.4旧备用实验 | 当前media-parser |
|---|---|---|---|
| endpoint | api5-normal-c-hl.amemv.com | aweme.snssdk.com | api5优先，snssdk次之 |
| aweme_id | 调用目标；视频验收脚本含7682375032253180345/7660061608801996068 | 7690029886242009957图文 | 调用目标；明确note不调用Feed |
| aid/query | aweme_id→aid1128，两项 | 同左 | 同左 |
| UA | MediaFlow/0.2.0 (anonymous local HTTP client) | 同左 | 专用Android app/TTNet UA（上方原文） |
| Accept/其他headers | application/json；无Referer | 同左 | application/json,text/plain,*/*；无Referer |
| Cookie/signer | fresh HTTP，无Cookie/签名 | 无Cookie/签名 | 方法不加，session可能已有Cookie；无Feed signer |
| count/命中 | 本轮没重跑视频；integration脚本验证精确id+video资源 | 5其他作品；目标缺失 | 实际返回未知；mock视频成功不作为真实证据 |
| validator | 目标精确唯一，之后须desc/author/video/play/download | 递归扫描目标/图片 | aweme_id或id匹配即包装aweme_detail，不先强制video |

v020与v040 production feed文件相同关键UA/query/endpoint；v040“5其他作品”相对v020生产请求主要换了host和目标内容类型，**并没有换UA**。相对参考项目UA才是明显差异，同时Accept更窄。参考图文控制流根本不执行这个方法，比“漏了某个签名”更直接解释为什么其图文能力不能由Feed存在推出。

v020本地验收test源码是断言定义，不能当成已运行stdout；老anonymous-web文档记录更早阶段失败，不覆盖后续视频成功。用户交接提供Windows/Android视频真实成功历史；本轮未找到该production测试运行原始日志，保持为历史报告，不伪造复验。另v030图文调查记录同feed视频7682375032253180345两次精确命中；图文候选未命中，不证明所有图文不支持。

最可信的已有解释是目标类型/该节点收录导致未进入精确目标返回、返回推荐状列表；**平台内部机制未证实**。UA路由是明确可检验的候选，尚不能断言服务器忽略id或按UA选择推荐feed。query遗漏device/signer不是源码证据支持的解释。

## 网络前预案（先写再执行）

最多两个Douyin GET，固定目标7690029886242009957；无Cookie/登录/Token/signature/UIFID/Web detail/Browser/proxy/图片下载；请求超时/2MiB限制，TLS正常校验，redirect/安全拒绝即停止整个实验，不按参考代码重试拒绝。

实验M1：api5主endpoint，query仍aweme_id→aid1128，**只把历史该endpoint请求的UA替换为参考专用Mobile Feed UA**；Accept保留MediaFlow旧`application/json`以隔离UA。声明这一与参考宽Accept的差异，不称字节级完整复刻。UA仅用于此次请求选择兼容性比较，不生成设备ID/fingerprint/随机Token，不在安全拒绝后变更UA或身份。

实验M2：仅M1完整返回安全JSON且没有精确目标时，按源码第二endpoint切换到aweme.snssdk.com，其余输入完全相同；最多一次，不刷新碰概率。M1命中即不执行M2。两轮之间没有第三方解析服务或媒体请求。

所有响应只保存安全元数据/公开作品ID、目标字段存在性/数组顺序/URL字段名+host+path特征；无raw正文、完整媒体URL/query、Cookie值。不会把其他作品的images提升为目标gallery证明。

## 来源

[当前parser](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/src/parsers/douyin_parser.py)、[传输层](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/src/utils/parser_transport.py)、[文档](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/docs/parsers/douyin.md)、[测试](https://github.com/ucmao/media-parser/blob/ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6/tests/test_douyin_parser.py)。文档的100%/零403等宣传不是MediaFlow验收证据。本节后续追加实测及最终报告，保留网络前预案。
