# 激活前接线审查（真实导航之前保存）

范围：独立研究Debug包、一个主frame公开share/note；只读取命名hydration/JSON scripts与同源fetch既有响应。AGENTS.md与i-have-adhd已读取；branch feature/v0.4.0 HEAD e2ea89d，status ?? v0.4.0/。

|检查|证据|判定|
|---|---|---|
|operation分配与重入|CoordinatorService state检查在UUID分配前；真实run使用createNewFile一次性领用；Activity重建仅attach；Worker atomic claim|PASS，静态与既有离线范围|
|真实生命周期接线|LOADED先校验identity并拒绝active清理，然后唯一NAVIGATE；Worker独立实时停止后COMPLETED使状态STOPPING→AWAITING_DEATH|PASS，静态|
|统一bridge|realTarget/bridgeFixture同一WebMessageListener和consumePageMessage，不再fixture伪造response|PASS，静态+同构建fixture|
|初始化/ack/ready|同一PublicPageScript和consumer；离线各1|PASS，离线|
|hydration/JSON/response/body/decoder|无fixture-only阻断；response来自页面原fetch的clone；fixture成功3|PASS，静态+离线|
|operation全链|Coordinator生成op→START Bundle→source(op)→所有JS消息带operation→consumer验证→summary.operation→cleanup比较|PASS，静态+离线一致ID|
|security cancellation|资源线程同步cancel gate，bridge入口立即拒绝，JS reader取消/UI stop、stopLoading、renderer terminate，无grace window|PASS，静态及离线受控范围，真实待验证|
|精确cleanup|completion/Binder death/OS absence/op-nonce-PIDticks-路径校验；before/final gate与bridge计数检查，目标路径限定当前op|PASS，静态+fixture自动零残留|
|历史目录保护|路径以当前UUID生成，不扫根目录；既有3cache/5metadata/cf2marker基线已保存|PASS，静态；真实退出后复核|
|临时权限|仅-PenablePublicProbe=true + publicProbeRun启用研究Debugoverlay INTERNET；显式publicProbe extra和URL格式验证；默认false；正式manifest未改|PASS，构建/apksigner/aapt|

同构建离线operation1857388abce945d48a3408527fe8c9b1 PASS1820ms：script/init/ack/ready各1、hydration1/JSON1/response1/body3/decoder3成功3；安全取消后不增、START1、新增profile/cache/metadata/marker均清除。

下一条命令最多一次批准样本公开页面导航；run领用文件防止同构建第二次operation。没有修改生产网络行为，无凭据/Cookie/Token导出、重放、API主动请求、代理/MITM或扩大采集。真实结果不以此审查PASS代替。
