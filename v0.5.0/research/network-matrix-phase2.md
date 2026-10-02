# 第二阶段固定样本与网络矩阵（2026-09-30 断点续跑）

研究证据，不是 production 验收。用户要求使用人工确认的链接，不打开浏览器寻找或替换样本。浏览器可访问是用户确认；其 DNS/代理/DoH 尚未核实。不得把浏览器可打开等同当前系统直连可打开。

## 环境

Windows 活动接口 Remote NDIS Internet Sharing Device #2（以太网2，ifIndex16），USB 手机共享；IPv4 10.120.174.72，网关/DNS 10.120.174.45，无活动 IPv6。Wi-Fi/Bluetooth 不活动，不能使用残留配置推断当前路径。WinINET Proxy/PAC 未配置，WinHTTP DIRECT，代理环境变量空，没有看到活动 Windows VPN/TUN。系统 DoH 模板存在但 AutoUpgrade=false，不能证明使用 DoH。

Android PJZ110，默认网络210/Wi-Fi wlan0，IPv4 192.168.10.36，有 IPv6；DNS 192.168.10.1、114.114.114.114、fe80::10%wlan0。Private DNS opportunistic（自动），specifier null；global HTTP proxy null。vgate0 存在，VPN 服务报告活动包 moe.nb4a，但研究 App UID10443 是否被覆盖 **NOT VERIFIED**；默认网络 Wi-Fi/NOT_VPN 不足以否定按应用 VPN。rndis0=10.120.174.45，与 Windows 网关一致。没有读取 VPN 凭据/配置或修改路由。

环境 JSON：`poc/windows-network-environment-resume.json`、`poc/android-network-environment-resume.json`。上次 Android 图文成功时未保存完整网络快照，不能用本轮 Wi-Fi/VPN 状态补写其必要条件。

## DNS → TCP → TLS → HTTP

| 端与执行路径 | DNS | TCP443 | TLS | HTTP / 结论 |
|---|---|---|---|---|
| Windows 用户浏览器 | NOT VERIFIED | 用户确认页面可打开，不独立拆层 | NOT VERIFIED | 两个新 YT / 三个 XHS 用户确认可访问；独立代理/DoH具体配置未知 |
| Windows 自有 WebView2（历史一次） | 未拆层 | ConnectionReset 所在具体阶段未核实 | 未核实 | 导航失败；源码显式 --no-proxy-server，不继承系统代理；临时匿名 profile 清理；本轮按用户指示不打开浏览器 |
| Windows curl -q、无代理 | YT 系统解析，DNS耗时0.056251s | YT 6s超时，connect=0 | 未到达 | HTTP000/exit28；XHS该次也TCP超时，不能认定稳定平台拒绝 |
| Windows PowerShell HttpClient UseProxy=false | 系统解析；最终地址未独立捕获 | YT8s取消，精确阶段仅靠此请求未知 | YT未验证 | XHS302 HTTP/1.1；说明另一次链路能到HTTP |
| Windows Dart 分层诊断 | YT157.240.7.20；XHS106.54.99.69/118.195.253.242 | YT SocketException10060，6s超时；XHS连118.195.253.242成功 | XHS证书正常校验通过，YT未到达 | XHS后续独立HttpClient请求12s超时；不同socket，不声称同一已建立TLS连接失效 |
| Windows Dart 固定样本 | YT1=185.45.5.35，修正后的YT2=31.13.92.37；XHS短链与官网DNS记录见JSON | YT socket/timeout；分层同域证据确定环境TCP阻断 | YT未到达；XHSHTTPS请求正常返回 | YT两个均无metadata；XHS三个短链302→作品302→login安全停止；无下载 |
| Android 系统浏览器 | NOT VERIFIED | 用户确认可访问 | NOT VERIFIED | 用户报告独立配置或不同网络；不读取外部浏览器会话 |
| Android App/Dart | 本轮YT两者174.132.167.252/2001::1；与shell198.18.0.63不同 | 本轮两个固定YT样本12s socket/timeout | 本轮YT未到达 | 8图旧证据PASS；视频与5图页面200且真实下载/MediaStore成功，用户确认系统打开成功 |
| Android WebView | NOT TESTED | NOT TESTED | NOT TESTED | 尚无对应PoC；不为补表擅自打开浏览器 |
| Android adb shell | YT ping解析198.18.0.63（合成地址线索，非实际服务可达证明）；XHS解析106.54.99.69 | YT curl6s连接超时；ping一次成功只证明该地址ICMP | XHS正常TLS；YT未到达 | YTHTTP000；XHS302 HTTP/1.1，DNS2.552035s/TCP2.597534s/TLS2.692233s |

Windows DNS对YT多次变化，另见历史174.132.167.252、69.171.235.22、2001::1及ARIN核查记录。这些是解析/网络异常线索，不足以归因为地区限制、安全挑战或某个VPN故障。当前 **networkFailure.tcp** 为可直接验证层级；代理原因、DNS异常具体来源、浏览器成功所需配置仍未确认。

## 固定样本

最终URL只记录实际到达且已脱敏的地址；未取得响应不编造最终URL。分享query值不写入日志，完整用户提供的原始URL作为样本输入保留。

| 平台 / 类型 | 原始URL | ID | 实际最终地址 / 类型确认 | Windows PoC | Android PoC / 下载 |
|---|---|---|---|---|---|
| YT 视频 | https://youtu.be/hLY9KMIU2BA?si=gb6c0DbBnq7vBihS | hLY9KMIU2BA | 请求canonical watch，连接失败无最终响应；用户确认公开视频，metadata未验 | networkFailure | 本轮networkFailure，未取得metadata |
| YT Shorts | https://youtube.com/shorts/g4kriJeJFYA?si=igdpD_IiNvysbhRX | g4kriJeJFYA | 请求canonical watch，连接失败无最终响应；用户确认公开，频道未核实 | 初次本地URL识别ArgumentError；修正后networkFailure | 本轮networkFailure |
| XHS 视频 | https://xhslink.cn/o/5X01rOYZDMT | 6abb69640000000014010526 | Windows作品页→/login；Android历史作品页type=video已确认 | loginRequired，无媒体下载 | 旧metadata/stream URL取得；真实下载未完成，本轮networkFailure |
| XHS 8图 | https://xhslink.cn/o/4wRbjSYrcBJ | 687a4239000000002400bcc9 | Windows作品页→/login；Android历史作品页normal/8图 | loginRequired，无媒体下载 | **Gallery PASS**：有序8资源，两张不同JPEG下载、MediaStore、系统打开、顺序人工确认；本轮不重跑 |
| XHS 5图 | https://xhslink.cn/o/V8A6eesUi3 | 686f739c000000002203d3a2 | Windows作品页→/login；Android此前200HTML但未取得有效schema | loginRequired，无媒体下载 | 用户确认5图；PoC结构/下载未验，本轮networkFailure |

用户确认以上链接可打开。Windows结果见 `poc/windows-fixed-samples-resume-results.json`（初始运行），Shorts修正后的结果见 `poc/windows-shorts-normalized-results.json`。分层见 `poc/windows-dart-network-matrix-resume.json`；旧JSON保留，不覆盖失败记录。

## XHS 必要条件对照

共同Level0：Cookie发送=false，不导入、不持久化；重定向中的平台签发query在内存原样使用，落盘只键名。研究UA分别 MediaFlowResearch/0.5.0 (windows/android)，不是仿造设备指纹。Accept/Accept-Language/Referer没有人为补造（库默认行为未逐字抓取，不声称两端所有传输头一致）。Windows作品302包含Set-Cookie但未使用，短链未包含；不能凭此证明匿名Cookie或登录session必要。

Android8图成功读取移动schema `window.__INITIAL_STATE__.noteData.data.noteData`，桌面路线与移动schema不同；本轮已同时支持并校验目标ID。Windows本轮未到达内容HTML，所以尚不能比较两端同一响应结构。HTTP版本：shell/PowerShell实测1.1；Dart事件未记录协商版本。Dart page事件没有响应体字节计数字段；响应大小 **NOT VERIFIED**，不编造。媒体实际字节另有下载记录。

没有单变量实验能证明UA、session、IPv6或VPN是最小必要条件。当前只成立“Android Level0匿名8图链可用”和“Windows当前Level0正常收到登录跳转”。Windows明确登录跳转后停止；不反复改变签名/身份、复制Cookie或绕登录。后续先明确正常网络/匿名上下文条件，再另立有界实验。

## 判定与最小恢复操作

YouTube **NOT YET CLASSIFIED**；XHS整体 **NOT YET CLASSIFIED**。Android8图子能力 **PASS**，其他未完成能力保持NOT VERIFIED/BLOCKED；错误响应不是整个平台FAIL。

1. 恢复研究程序至YouTube官方域的正常连接条件；仅先用一个固定URL证明DNS→TCP→TLS→HTTP。不开新解析路线，不修改系统网络或关闭TLS校验。
2. 连接正常后，仅同两个YT样本补metadata/manifest；每端各下载一个muxed、video-only、audio-only并系统打开，Android保存MediaStore。缺muxed记formatUnavailable后再询问一个固定样本；不无限换链接。
3. XHS保留8图PASS，补视频、5图和Windows资源链。Windows登录跳转条件尚未定位，不以YT网络恢复当成XHS已解决；需正常匿名客户端上下文来源/隐私/生命周期矩阵，必要登录只在明确用户授权的App自有profile内。
4. 不进入production，History新平台冷启动验证仍未执行。环境阻断报告必须明确YT TCP实证以及XHS尚未定位的不同HTTP结果，不宣告双轨完成。

## 本轮 Android 新证据

`poc/android-fixed-samples-resume-results.json` 保留每次DNS、HTTP状态、HTML字节数与hash、schema形状、metadata、资源URL hash及媒体文件hash。视频HTML143714字节；成功响应为移动schema，无Cookie发送，无登录。视频HTTP200、video/mp4，native MediaExtractor检出video/hevc及audio/mp4a-latm；检测到轨不等同用户已确认正常播放。5图metadata标题“我不是电量很充足的人”、作者“迟迟”，两张下载不同，均1080×1080。匿名不保存Set-Cookie，页面有Set-Cookie不代表此次需要session。两端HTTP行为不同仍未证明唯一变量，不能直接判UA/IPv6/VPN必要。

用户对“视频画面和声音、5图两张打开及顺序”组合问题回复“可以”，作为人工确认记录于human-confirmations.json；程序原始JSON的systemOpen=NOT TESTED保留，以免把后续人工确认伪装为当时自动结果。Android视频及第二图文下载/系统打开子能力PASS，独立系统图库浏览、正式History冷启动仍NOT TESTED。

本轮暂停标记：**V0.5.0 PHASE 2 BLOCKED BY VERIFIED ENVIRONMENT CONDITION**。它特指YouTube研究路径TCP连接未能建立这一实测门槛，不表示已知网络配置根因，也不表示Windows XHS登录差异已经解决。矩阵未核实的浏览器设置、VPN覆盖、历史WebView具体reset层级明确保留未知，不把调查表误写为所有路径都实测成功。

## 2026-10-01 小红书最终收尾（优先于前述历史状态）

**X-A PASS**。详见 [双端最终证据与兼容性检查](xhs-feasibility-closure.md)。Windows 本轮直接匿名 HTTP，使用明确声明Windows的移动布局兼容UA；无Cookie发送、无a1/web_session、无首页/session初始化、无WebView2或登录。正常分享重定向所带xsec_token只在内存使用，未验证移除后的必要性，不能称必须。视频6abb69640000000014010526真实下载1680739字节；8图687a4239000000002400bcc9前两张57629/59560字节。三个文件hash分别与Android对应文件一致。用户确认Windows视频画面/声音正常，两张图片能打开、内容不同且顺序一致。旧Android视频/5图/8图、MediaStore和系统打开PASS保留，不重跑。

纯HTTP A路线成立，因此不增加B路线profile/session实验。25项全research离线测试通过（含Android schema回归）；Dart静态检查无问题；Windows原生研究构建已实际执行固定8图，不是production发布构建。近期源码/提交/Issue/许可证审计见xhs-oct1-reference-audit.json；最接近JoeanAmier Converter移动/桌面hydration路线，均设计参考、没有第三方代码搬运和新增依赖。

YouTube暂停，既有prototype仍待用户联网验收。production、正式依赖、History/UI/Downloader/ParserService未改；History重启恢复不在本次已通过范围。无commit/push/merge/tag。固定样本成功不等于所有小红书作品可解析或正式发布完成。

**V0.5.0 XHS FEASIBILITY CLOSED — X-A PASS**。等待下一条指令，不进入production、不恢复YouTube。