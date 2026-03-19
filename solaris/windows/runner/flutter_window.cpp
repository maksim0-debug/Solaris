#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "monitor_manager.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Set up MethodChannel
  monitor_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.solaris.monitor/names",
      &flutter::StandardMethodCodec::GetInstance());

  monitor_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getMonitorNames") == 0) {
          MonitorManager manager;
          auto names = manager.GetMonitorFriendlyNames();
          
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
              
              MonitorManager manager;
              bool success = manager.SetBrightness(device_path, brightness);
              result->Success(flutter::EncodableValue(success));
              return;
            }
          }
          result->Error("invalid_arguments", "Expected devicePath and brightness");
        } else if (call.method_name().compare("getMonitorBrightness") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto device_path_it = arguments->find(flutter::EncodableValue("devicePath"));
            if (device_path_it != arguments->end()) {
              std::string device_path = std::get<std::string>(device_path_it->second);
              MonitorManager manager;
              int current = 0;
              int maximum = 100;
              if (manager.GetBrightness(device_path, current, maximum)) {
                result->Success(flutter::EncodableValue(current));
                return;
              } else {
                result->Success(flutter::EncodableValue()); // Return null if failed
                return;
              }
            }
          }
          result->Error("invalid_arguments", "Expected devicePath");
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
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
  // Give Flutter, including plugins, an opportunity to handle window messages.
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
