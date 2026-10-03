#include "flutter_window.h"

#include <optional>
#include <algorithm>
#include <atomic>
#include <thread>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "monitor_manager.h"
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <objbase.h>

struct FocusEventData {
  bool is_gaming;
  std::string active_process;
};

// StreamHandler for Focus and Gaming Mode events
class GamingModeStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  GamingModeStreamHandler(MonitorManager& manager, HWND window_hwnd)
      : manager_(manager), window_hwnd_(window_hwnd) {}

  void SendFocusEvent(bool is_gaming, const std::string& active_process) {
    if (event_sink_) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("is_gaming")] = flutter::EncodableValue(is_gaming);
      map[flutter::EncodableValue("active_process")] = flutter::EncodableValue(active_process);
      event_sink_->Success(flutter::EncodableValue(map));
    }
  }

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    event_sink_ = std::move(events);
    
    // Initial state map
    flutter::EncodableMap map;
    map[flutter::EncodableValue("is_gaming")] = flutter::EncodableValue(manager_.IsGamingMode());
    map[flutter::EncodableValue("active_process")] = flutter::EncodableValue(manager_.GetActiveProcessName());
    event_sink_->Success(flutter::EncodableValue(map));

    // Set callback for future changes
    manager_.SetFocusAndGamingCallback([this](bool is_gaming, const std::string& active_process) {
      if (window_hwnd_) {
        auto* data = new FocusEventData{is_gaming, active_process};
        if (!PostMessage(window_hwnd_, WM_SOLARIS_DISPATCH_EVENT, 0, reinterpret_cast<LPARAM>(data))) {
          delete data;
        }
      }
    });

    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    manager_.SetFocusAndGamingCallback(nullptr);
    event_sink_ = nullptr;
    return nullptr;
  }

 private:
  MonitorManager& manager_;
  HWND window_hwnd_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

// StreamHandler for System & Hardware Events
class SystemEventsStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  SystemEventsStreamHandler(MonitorManager& manager, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>& sink_ref)
      : manager_(manager), sink_ref_(sink_ref) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    sink_ref_ = std::move(events);
    manager_.SetHardwareErrorCallback([this](const std::string& err_msg) {
      if (sink_ref_) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("event")] = flutter::EncodableValue("on_hardware_error");
        map[flutter::EncodableValue("detail")] = flutter::EncodableValue(err_msg);
        sink_ref_->Success(flutter::EncodableValue(map));
      }
    });
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    manager_.SetHardwareErrorCallback(nullptr);
    sink_ref_ = nullptr;
    return nullptr;
  }

 private:
  MonitorManager& manager_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>& sink_ref_;
};

namespace {

// Checks the registry status of GdiIcmGammaRange and whether a restart is pending:
// 0: Disabled (registry value missing, invalid, or != 256)
// 1: PendingRestart (registry value == 256, but written after current system boot)
// 2: Active (registry value == 256, written prior to current system boot)
int CheckExpandedGammaStatus() {
  HKEY hKey = nullptr;
  LSTATUS status = RegOpenKeyExW(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ICM",
      0,
      KEY_READ | KEY_WOW64_64KEY,
      &hKey);

  if (status != ERROR_SUCCESS) {
    return 0;
  }

  DWORD value = 0;
  DWORD size = sizeof(value);
  DWORD type = 0;
  status = RegQueryValueExW(
      hKey,
      L"GdiIcmGammaRange",
      nullptr,
      &type,
      reinterpret_cast<LPBYTE>(&value),
      &size);

  if (status != ERROR_SUCCESS || type != REG_DWORD || value != 256) {
    RegCloseKey(hKey);
    return 0;
  }

  FILETIME ftLastWrite;
  status = RegQueryInfoKeyW(
      hKey,
      nullptr, nullptr, nullptr, nullptr, nullptr, nullptr,
      nullptr, nullptr, nullptr, nullptr,
      &ftLastWrite);

  RegCloseKey(hKey);

  if (status != ERROR_SUCCESS) {
    return 2;
  }

  FILETIME ftNow;
  GetSystemTimeAsFileTime(&ftNow);
  ULARGE_INTEGER nowVal;
  nowVal.LowPart = ftNow.dwLowDateTime;
  nowVal.HighPart = ftNow.dwHighDateTime;

  // Retrieve interrupt time in 100-nanosecond intervals.
  // QueryInterruptTime (available on Windows 10 build 10240+) includes time spent
  // in system sleep/standby, preventing calculated boot time from drifting into
  // the future after sleep cycles (which occurs with GetTickCount64).
  ULONGLONG interruptTimeIntervals = 0;
  typedef VOID (WINAPI *QueryInterruptTimeFn)(PULONGLONG lpInterruptTime);
  HMODULE hKernel32 = GetModuleHandleW(L"kernel32.dll");
  auto pfnQueryInterruptTime = hKernel32 ? reinterpret_cast<QueryInterruptTimeFn>(
      GetProcAddress(hKernel32, "QueryInterruptTime")) : nullptr;

  if (pfnQueryInterruptTime) {
    pfnQueryInterruptTime(&interruptTimeIntervals);
  } else {
    interruptTimeIntervals = GetTickCount64() * 10000ULL;
  }

  ULARGE_INTEGER bootTime;
  if (nowVal.QuadPart > interruptTimeIntervals) {
    bootTime.QuadPart = nowVal.QuadPart - interruptTimeIntervals;
  } else {
    bootTime.QuadPart = 0;
  }

  ULARGE_INTEGER writeVal;
  writeVal.LowPart = ftLastWrite.dwLowDateTime;
  writeVal.HighPart = ftLastWrite.dwHighDateTime;

  const ULONGLONG kGracePeriodIntervals = 20000000ULL; // 2-second grace period for clock skew
  if (writeVal.QuadPart > bootTime.QuadPart + kGracePeriodIntervals) {
    return 1; // PendingRestart
  }

  return 2; // Active
}

bool CheckExpandedGammaUnlocked() {
  return CheckExpandedGammaStatus() == 2;
}

bool PerformUnlockExpandedGammaSync(HWND parent_hwnd = nullptr) {
  SHELLEXECUTEINFOW sei = {sizeof(sei)};
  sei.fMask = SEE_MASK_NOCLOSEPROCESS;
  sei.hwnd = parent_hwnd;
  sei.lpVerb = L"runas";
  sei.lpFile = L"reg.exe";
  sei.lpParameters = L"add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ICM\" /v GdiIcmGammaRange /t REG_DWORD /d 256 /f /reg:64";
  sei.nShow = SW_HIDE;

  if (!ShellExecuteExW(&sei)) {
    return false;
  }

  if (sei.hProcess) {
    DWORD waitResult = WaitForSingleObject(sei.hProcess, 10000);
    DWORD exitCode = 1;
    if (waitResult == WAIT_OBJECT_0) {
      GetExitCodeProcess(sei.hProcess, &exitCode);
    } else {
      TerminateProcess(sei.hProcess, 1);
    }
    CloseHandle(sei.hProcess);
    return (waitResult == WAIT_OBJECT_0 && exitCode == 0);
  }
  return false;
}

bool PerformRestartComputer() {
  SHELLEXECUTEINFOW sei = {sizeof(sei)};
  sei.lpVerb = L"open";
  sei.lpFile = L"shutdown.exe";
  sei.lpParameters = L"/r /t 0";
  sei.nShow = SW_HIDE;
  return ShellExecuteExW(&sei) != FALSE;
}

} // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Set up MethodChannel
  monitor_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/names",
      &flutter::StandardMethodCodec::GetInstance());

  monitor_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getMonitorNames") == 0) {
          auto names = monitor_manager_.GetMonitorFriendlyNames();
          
          flutter::EncodableMap response;
          for (auto const& [path, name] : names) {
            response[flutter::EncodableValue(path)] = flutter::EncodableValue(name);
          }
          result->Success(flutter::EncodableValue(response));
        } else if (call.method_name().compare("setMonitorBrightness") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            auto brightness_it = arguments->find(flutter::EncodableValue("brightness"));
            
            if (device_path_it != arguments->end() && brightness_it != arguments->end()) {
              if (const auto* path_str = std::get_if<std::string>(&device_path_it->second)) {
                int brightness = 0;
                if (const auto* val_i = std::get_if<int>(&brightness_it->second)) {
                  brightness = *val_i;
                } else if (const auto* val_i64 = std::get_if<int64_t>(&brightness_it->second)) {
                  brightness = static_cast<int>(*val_i64);
                } else if (const auto* val_d = std::get_if<double>(&brightness_it->second)) {
                  brightness = static_cast<int>(std::round(*val_d));
                } else {
                  result->Error("invalid_arguments", "Brightness must be an integer");
                  return;
                }

                std::string device_path = *path_str;

                // Software Dimming Overlay is managed instantly on the UI thread
                if (brightness < 0) {
                  double opacity = (static_cast<double>(std::abs(brightness)) / 100.0) *
                                   OverlayManager::kMaxOverlayDarkness;
                  overlay_manager_.SetOverlayOpacity(device_path, opacity);
                } else {
                  overlay_manager_.SetOverlayOpacity(device_path, 0.0);
                }

                monitor_manager_.EnqueueTask([this, device_path, brightness]() {
                  monitor_manager_.SetBrightness(device_path, brightness);
                });
                result->Success(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result->Error("invalid_arguments", "Expected devicePath and brightness");
        } else if (call.method_name().compare("setMonitorTemperature") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto temp_it = arguments->find(flutter::EncodableValue("temperature"));
            if (temp_it != arguments->end()) {
              int temperature = 6500;
              if (const int* val_i = std::get_if<int>(&temp_it->second)) {
                temperature = *val_i;
              } else if (const int64_t* val_i64 = std::get_if<int64_t>(&temp_it->second)) {
                temperature = static_cast<int>(*val_i64);
              } else if (const double* val_d = std::get_if<double>(&temp_it->second)) {
                temperature = static_cast<int>(std::round(*val_d));
              } else {
                result->Error("invalid_arguments", "Temperature must be a numeric value");
                return;
              }

              std::string device_path = "";
              auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
              if (device_path_it != arguments->end()) {
                if (const auto* path_str = std::get_if<std::string>(&device_path_it->second)) {
                  device_path = *path_str;
                }
              }

              monitor_manager_.EnqueueTask([this, device_path, temperature]() {
                if (temperature >= 6500) {
                  if (!device_path.empty() && device_path != "all") {
                    monitor_manager_.ResetTemperature(device_path);
                  } else {
                    monitor_manager_.ResetAllMonitorsTemperatureSync();
                  }
                } else {
                  if (!device_path.empty() && device_path != "all") {
                    monitor_manager_.SetTemperature(device_path, temperature);
                  } else {
                    monitor_manager_.SetAllMonitorsTemperature(temperature);
                  }
                }
              });

              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("invalid_arguments", "Expected temperature");
        } else if (call.method_name().compare("resetMonitorTemperature") == 0 ||
                   call.method_name().compare("resetAllMonitorsTemperature") == 0) {
          std::string device_path = "";
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            if (device_path_it != arguments->end()) {
              if (const auto* path_str = std::get_if<std::string>(&device_path_it->second)) {
                device_path = *path_str;
              }
            }
          }

          monitor_manager_.EnqueueTask([this, device_path]() {
            if (!device_path.empty() && device_path != "all") {
              monitor_manager_.ResetTemperature(device_path);
            } else {
              monitor_manager_.ResetAllMonitorsTemperatureSync();
            }
          });
          result->Success(flutter::EncodableValue(true));
          return;
        } else if (call.method_name().compare("getMonitorBrightness") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            if (device_path_it != arguments->end()) {
              if (const auto* path_str = std::get_if<std::string>(&device_path_it->second)) {
                const std::string& device_path = *path_str;

                // 1. Instant non-blocking check: If software dimming overlay is active (> 0),
                // return calculated negative brightness immediately without blocking the UI thread on slow DDC/CI!
                double overlay_opacity = overlay_manager_.GetOverlayOpacity(device_path);
                if (overlay_opacity > 0.001) {
                  int software_brightness = std::min(
                      -1,
                      -static_cast<int>(
                          std::round((overlay_opacity / OverlayManager::kMaxOverlayDarkness) * 100.0)));
                  result->Success(flutter::EncodableValue(software_brightness));
                  return;
                }

                // 2. Hardware query: Only if overlay is inactive, read physical brightness from hardware
                int current = 0;
                int maximum = 100;
                if (monitor_manager_.GetBrightness(device_path, current, maximum)) {
                  result->Success(flutter::EncodableValue(current));
                  return;
                } else {
                  result->Success(flutter::EncodableValue());
                  return;
                }
              }
            }
          }
          result->Error("invalid_arguments", "Expected devicePath");
        } else if (call.method_name().compare("updateWhitelist") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableList>(call.arguments());
          if (arguments) {
            std::vector<std::string> whitelist;
            for (const auto& item : *arguments) {
              if (auto* str = std::get_if<std::string>(&item)) {
                whitelist.push_back(*str);
              }
            }
            monitor_manager_.UpdateWhitelist(whitelist);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("invalid_arguments", "Expected list of strings");
        } else if (call.method_name().compare("updateBlacklist") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableList>(call.arguments());
          if (arguments) {
            std::vector<std::string> blacklist;
            for (const auto& item : *arguments) {
              if (auto* str = std::get_if<std::string>(&item)) {
                blacklist.push_back(*str);
              }
            }
            monitor_manager_.UpdateBlacklist(blacklist);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("invalid_arguments", "Expected list of strings");
        } else if (call.method_name().compare("setGameModeExitDelay") == 0) {
          if (const auto* delay = std::get_if<int32_t>(call.arguments())) {
            monitor_manager_.SetGameModeExitDelay(*delay);
            result->Success(flutter::EncodableValue(true));
            return;
          } else if (const auto* delay64 = std::get_if<int64_t>(call.arguments())) {
            monitor_manager_.SetGameModeExitDelay(static_cast<int>(*delay64));
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("invalid_arguments", "Expected integer seconds");
        } else if (call.method_name().compare("getRunningProcesses") == 0) {
          auto processes = monitor_manager_.GetRunningProcesses();
          flutter::EncodableList response;
          for (auto const& [exe, title] : processes) {
            flutter::EncodableMap map;
            map[flutter::EncodableValue("exe")] = flutter::EncodableValue(exe);
            map[flutter::EncodableValue("title")] = flutter::EncodableValue(title);
            response.push_back(flutter::EncodableValue(map));
          }
          result->Success(flutter::EncodableValue(response));
          return;
        } else if (call.method_name().compare("getExpandedGammaStatus") == 0) {
          result->Success(flutter::EncodableValue(CheckExpandedGammaStatus()));
          return;
        } else if (call.method_name().compare("isExpandedGammaUnlocked") == 0) {
          result->Success(flutter::EncodableValue(CheckExpandedGammaUnlocked()));
          return;
        } else if (call.method_name().compare("unlockExpandedGamma") == 0) {
          auto* task = new GammaUnlockTask{GetHandle(), std::move(result), false};
          BOOL queued = QueueUserWorkItem(
              [](LPVOID param) -> DWORD {
                auto* task = reinterpret_cast<GammaUnlockTask*>(param);
                HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
                bool co_initialized = SUCCEEDED(hr);

                task->success = PerformUnlockExpandedGammaSync(task->window_hwnd);

                if (co_initialized) {
                  CoUninitialize();
                }

                if (!PostMessage(task->window_hwnd, WM_SOLARIS_GAMMA_UNLOCK_RESULT, 0, reinterpret_cast<LPARAM>(task))) {
                  delete task;
                }
                return 0;
              },
              task,
              WT_EXECUTEDEFAULT);

          if (!queued) {
            task->result->Error("QUEUE_FAILED", "Failed to queue unlock work item");
            delete task;
          }
          return;
        } else if (call.method_name().compare("restartComputer") == 0) {
          result->Success(flutter::EncodableValue(PerformRestartComputer()));
          return;
        } else {
          result->NotImplemented();
        }
      });

  // Set up EventChannel for Gaming Mode & Focus Events
  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/events",
      &flutter::StandardMethodCodec::GetInstance());
  
  auto stream_handler = std::make_unique<GamingModeStreamHandler>(monitor_manager_, GetHandle());
  gaming_stream_handler_ = stream_handler.get();
  event_channel_->SetStreamHandler(std::move(stream_handler));

  // Set up EventChannel for System & Hardware events
  system_event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/system_events",
      &flutter::StandardMethodCodec::GetInstance());

  auto sys_stream_handler = std::make_unique<SystemEventsStreamHandler>(monitor_manager_, system_event_sink_);
  system_event_channel_->SetStreamHandler(std::move(sys_stream_handler));

  // Initialize AppIconExtractor for async app icon retrieval
  app_icon_extractor_ = std::make_unique<AppIconExtractor>(
      flutter_controller_->engine(), GetHandle());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  monitor_manager_.ResetAllMonitorsTemperatureSync();
  overlay_manager_.DestroyAllOverlays();

  if (app_icon_extractor_) {
    app_icon_extractor_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_SOLARIS_DISPATCH_EVENT: {
      auto* data = reinterpret_cast<FocusEventData*>(lparam);
      if (data) {
        if (gaming_stream_handler_) {
          gaming_stream_handler_->SendFocusEvent(data->is_gaming, data->active_process);
        }
        delete data;
      }
      return 0;
    }

    case WM_SOLARIS_ICON_RESULT: {
      auto* data = reinterpret_cast<IconResultData*>(lparam);
      if (data) {
        if (flutter_controller_ && app_icon_extractor_) {
          AppIconExtractor::HandleResult(data);
        } else {
          delete data;
        }
      }
      return 0;
    }

    case WM_SOLARIS_GAMMA_UNLOCK_RESULT: {
      auto* task = reinterpret_cast<GammaUnlockTask*>(lparam);
      if (task) {
        if (flutter_controller_ && task->result) {
          task->result->Success(flutter::EncodableValue(task->success));
        }
        delete task;
      }
      return 0;
    }

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_POWERBROADCAST:
      if (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND) {
        monitor_manager_.EnqueueTask([this]() {
          monitor_manager_.RestoreLastTemperatures();
        });
      }
      if (system_event_sink_ && (wparam == PBT_APMSUSPEND || wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND)) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("event")] = flutter::EncodableValue("WM_POWERBROADCAST");
        map[flutter::EncodableValue("wparam")] = flutter::EncodableValue(static_cast<int64_t>(wparam));
        system_event_sink_->Success(flutter::EncodableValue(map));
      }
      break;

    case WM_DISPLAYCHANGE:
      overlay_manager_.UpdateMonitorBounds();
      monitor_manager_.InvalidateMonitorHandlesDebounced(1000);
      monitor_manager_.EnqueueTask([this]() {
        monitor_manager_.RestoreLastTemperatures();
      });
      if (system_event_sink_) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("event")] = flutter::EncodableValue("WM_DISPLAYCHANGE");
        system_event_sink_->Success(flutter::EncodableValue(map));
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
