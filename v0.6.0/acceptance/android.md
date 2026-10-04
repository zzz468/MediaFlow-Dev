# v0.6.0 android 验收

Instagram 与 X production 的真实解析、完整下载、多图/混合原序、系统打开/播放和 History 冷进程恢复已验收。参见 ../production/README.md 与 ../production/x/README.md。

按用户最新指令，正式 Release 最小 smoke 只确认启动、Instagram/X 正式解析链路、Downloader/History 基本可用；不重复之前的多组播放、逐张图片和大规模混合顺序/冷启动验收。结果见 ../release/smoke.json 与 ../release/README.md。

Android 安装前核对实际 package/applicationId 与当前 APK signer；仅同签名 install -r，不卸载、不清数据。Windows 与 Android 同等门槛，构建成功不代替功能 smoke。
