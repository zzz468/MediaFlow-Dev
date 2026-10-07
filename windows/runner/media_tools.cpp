#include "media_tools.h"
#include <flutter/standard_method_codec.h>
#include <commdlg.h>
#include <string>
#include <vector>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateMediaToolsChannel(flutter::BinaryMessenger* messenger, HWND owner) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.mediaflow.mediaflow/media_tools",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([owner](const auto& call, auto result) {
    if (call.method_name() != "pickVideo") { result->NotImplemented(); return; }
    std::vector<wchar_t> path(32768, L'\0');
    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog); dialog.hwndOwner = owner;
    dialog.lpstrFilter = L"Video files\0*.mp4;*.m4v;*.mov;*.mkv;*.webm\0All files\0*.*\0\0";
    dialog.lpstrFile = path.data(); dialog.nMaxFile = static_cast<DWORD>(path.size());
    dialog.lpstrTitle = L"Select a local video";
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR | OFN_DONTADDTORECENT;
    if (!GetOpenFileNameW(&dialog)) {
      if (CommDlgExtendedError() != 0) result->Error("permissionDenied", "File selection failed.");
      else result->Success();
      return;
    }
    int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.data(), -1, nullptr, 0, nullptr, nullptr);
    if (count <= 0) { result->Error("invalidInput", "Invalid file path."); return; }
    std::string utf8(static_cast<size_t>(count), '\0');
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.data(), -1, utf8.data(), count, nullptr, nullptr);
    utf8.resize(static_cast<size_t>(count - 1));
    result->Success(flutter::EncodableValue(utf8));
  });
  return channel;
}
