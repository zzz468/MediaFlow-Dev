#ifndef MEDIAFLOW_MEDIA_TOOLS_H_
#define MEDIAFLOW_MEDIA_TOOLS_H_
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <memory>
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateMediaToolsChannel(flutter::BinaryMessenger* messenger, HWND owner);
#endif
