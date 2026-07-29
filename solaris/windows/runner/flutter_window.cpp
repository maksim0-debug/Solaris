#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "monitor_manager.h"
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>

// StreamHandler for Gaming Mode events
class GamingModeStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  GamingModeStreamHandler(MonitorManager& manager) : manager_(manager) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    event_sink_ = std::move(events);
    
    // Initial state
    event_sink_->Success(flutter::EncodableValue(manager_.IsGamingMode()));

    // Set callback for future changes
    manager_.SetGamingModeCallback([this](bool is_gaming) {
      if (event_sink_) {
        event_sink_->Success(flutter::EncodableValue(is_gaming));
      }
    });

    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    manager_.SetGamingModeCallback(nullptr);
    event_sink_ = nullptr;
    return nullptr;
  }

 private:
  MonitorManager& manager_;
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
              std::string device_path = std::get<std::string>(device_path_it->second);
              int brightness = std::get<int>(brightness_it->second);
              
              monitor_manager_.EnqueueTask([this, device_path, brightness]() {
                monitor_manager_.SetBrightness(device_path, brightness);
              });
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("invalid_arguments", "Expected devicePath and brightness");
        } else if (call.method_name().compare("setMonitorTemperature") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            auto temp_it = arguments->find(flutter::EncodableValue("temperature"));
            if (device_path_it != arguments->end() && temp_it != arguments->end()) {
              std::string device_path = std::get<std::string>(device_path_it->second);
              int temperature = std::get<int>(temp_it->second);
              monitor_manager_.EnqueueTask([this, device_path, temperature]() {
                monitor_manager_.SetTemperature(device_path, temperature);
              });
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("invalid_arguments", "Expected devicePath and temperature");
        } else if (call.method_name().compare("resetMonitorTemperature") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            if (device_path_it != arguments->end()) {
              std::string device_path = std::get<std::string>(device_path_it->second);
              monitor_manager_.EnqueueTask([this, device_path]() {
                monitor_manager_.ResetTemperature(device_path);
              });
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("invalid_arguments", "Expected devicePath");
        } else if (call.method_name().compare("resetAllMonitorsTemperature") == 0) {
          bool success = monitor_manager_.ResetAllMonitorsTemperatureSync();
          result->Success(flutter::EncodableValue(success));
          return;
        } else if (call.method_name().compare("getMonitorBrightness") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            if (device_path_it != arguments->end()) {
              std::string device_path = std::get<std::string>(device_path_it->second);
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
        } else {
          result->NotImplemented();
        }
      });

  // Set up EventChannel for Gaming Mode
  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/events",
      &flutter::StandardMethodCodec::GetInstance());
  
  auto stream_handler = std::make_unique<GamingModeStreamHandler>(monitor_manager_);
  event_channel_->SetStreamHandler(std::move(stream_handler));

  // Set up EventChannel for System & Hardware events
  system_event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/system_events",
      &flutter::StandardMethodCodec::GetInstance());

  auto sys_stream_handler = std::make_unique<SystemEventsStreamHandler>(monitor_manager_, system_event_sink_);
  system_event_channel_->SetStreamHandler(std::move(sys_stream_handler));

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_POWERBROADCAST:
      if (system_event_sink_ && (wparam == PBT_APMSUSPEND || wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND)) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("event")] = flutter::EncodableValue("WM_POWERBROADCAST");
        map[flutter::EncodableValue("wparam")] = flutter::EncodableValue(static_cast<int64_t>(wparam));
        system_event_sink_->Success(flutter::EncodableValue(map));
      }
      break;

    case WM_DISPLAYCHANGE:
      monitor_manager_.InvalidateMonitorHandlesDebounced(1000);
      if (system_event_sink_) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("event")] = flutter::EncodableValue("WM_DISPLAYCHANGE");
        system_event_sink_->Success(flutter::EncodableValue(map));
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
