#ifndef RUNNER_APP_ICON_EXTRACTOR_H_
#define RUNNER_APP_ICON_EXTRACTOR_H_

#include <windows.h>
#include <gdiplus.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <string>

#define WM_SOLARIS_ICON_RESULT (WM_USER + 102)

// Structure passed through PostMessage to marshal icon extraction result back to UI thread
struct IconResultData {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  std::string resolved_path;
  bool success;
};

// Shared lifecycle state between AppIconExtractor and worker threads
struct ExtractorSharedState {
  std::atomic<bool> is_shutting_down{false};
  std::atomic<int> active_tasks{0};
};

class AppIconExtractor {
 public:
  AppIconExtractor(flutter::FlutterEngine* engine, HWND window_hwnd);
  ~AppIconExtractor();

  // Non-copyable / non-movable
  AppIconExtractor(const AppIconExtractor&) = delete;
  AppIconExtractor& operator=(const AppIconExtractor&) = delete;

  // Handles WM_SOLARIS_ICON_RESULT on the main UI thread
  static void HandleResult(IconResultData* data);

 private:
  static int GetEncoderClsid(const WCHAR* format, CLSID* pClsid);
  static bool SaveIconToFile(const std::wstring& exePath, const std::wstring& savePath, std::wstring& resolvedPath);

  flutter::FlutterEngine* engine_;
  HWND window_hwnd_;
  ULONG_PTR gdiplusToken_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::shared_ptr<ExtractorSharedState> state_;
};

#endif  // RUNNER_APP_ICON_EXTRACTOR_H_
