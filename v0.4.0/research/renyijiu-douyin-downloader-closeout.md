# 补充参考：renyijiu/douyin_downloader（2026-09-27）

- 仓库：https://github.com/renyijiu/douyin_downloader
- 文件：https://github.com/renyijiu/douyin_downloader/blob/master/douyin.py
- LICENSE：MIT；2023-01-05已归档，不能当当前可用实现。
- 路线：旧iteminfo、用户批量视频下载；这里只取iteminfo端点历史线索，不采纳批量抓取。
- 分享/ID：代码中分享链接及作品标识用于查询；完整当前重定向行为未核实。
- 图文识别/字段/顺序：该项目不是本轮图文成功证据；images字段以另一个PHP源码对照，当前资源顺序未验证。
- 请求/headers：MediaFlow本轮GET旧iteminfo，item_ids唯一公开参数、固定UA/Accept，无Cookie/Token/签名。项目自身其他签名/浏览器/ADB路线不采用，账号需求未逐项证明。
- 依赖：历史Python/browser/ADB环境不能整套移植；是否有第三方服务依赖未完成全仓审计。本轮不调用项目服务。
- Windows：独立探针实际HTTP200空正文；Android同HTTP理论路径，NOT TESTED；原项目五端适配未验证。
- MediaFlow：只参考接口线索，自行实现最小Dart请求；无代码复用/新增依赖/attribution代码义务。归档和当前空响应使生产采用BLOCKED。
- 同源：与surmoun共用平台旧入口，不构成两次独立匿名成功。fork关系未证实。
