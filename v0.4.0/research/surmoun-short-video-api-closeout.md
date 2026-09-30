# 补充参考：surmoun/Short_Video-API（2026-09-27）

- 仓库：https://github.com/surmoun/Short_Video-API
- 核心源码：https://github.com/surmoun/Short_Video-API/blob/main/API.php
- LICENSE：主页未列许可证文件，未确认可复用授权；禁止复制代码。维护：主页14 commits，最近提交日期未核实，不认定仍维护。
- 分享链接/ID：PHP按分享地址展开到作品标识；只借鉴入口线索，不移植提取逻辑。
- 图文路线：旧公开 GET www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids=ID；源码从item_list[0].images[*].url_list获取图片。字段只是第三方历史线索，非当前证明。
- Headers/Cookie/Token/签名：本轮自行实现探针只带固定UA/Accept，无Cookie/Token/动态签名；不能据此认定整个第三方项目无需会话。源码其他平台路线未完整核实。
- 图文判断/排序：images数组为线索，源码改写封面/图片位置的策略不复用，不能替代目标原始顺序证明。
- 浏览器/第三方：PHP可部署解析服务器；MediaFlow不调用其服务，不上传链接。仅直接平台GET独立实现。
- Windows：本轮200 application/json空正文，无目标结构；Android：同HTTP理论可实现，本轮NOT TESTED。原项目平台适配未验证。
- 匿名证据：MediaFlow本轮匿名请求实际成立，但结构失败；README支持图集不等于MediaFlow支持。
- MediaFlow：仅入口/字段参考，不复制代码/依赖，不采用production，不新增PHP/服务器；空正文当前BLOCKED。
- 同源：与旧renyijiu入口属于相同iteminfo路线族，不能当两条独立可用证据；没有足够证据断言二者fork/抄袭。
