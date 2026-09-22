#ifndef RUNNER_OVERLAY_MANAGER_H_
#define RUNNER_OVERLAY_MANAGER_H_

#include <windows.h>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

class OverlayManager {
 public:
  OverlayManager();
  ~OverlayManager();

  // Sets the software dimming overlay opacity for a specific monitor device path (e.g. \\.\DISPLAY1).
  // Opacity 0.0 disables dimming. Values > 0.0 show a click-through transparent darkened overlay.
  // Opacity is clamped to a safety floor of 0.85 (85% max darkness) so the display is never completely blacked out.
  void SetOverlayOpacity(const std::string& device_path, double opacity);

  // Repositions and resizes all active overlay windows when screen layout or resolution changes.
  void UpdateMonitorBounds();

  // Closes and cleans up all active overlay windows.
  void DestroyAllOverlays();

 private:
  struct OverlayInfo {
    HWND hwnd = nullptr;
    double opacity = 0.0;
    BYTE alpha = 0;
    RECT last_rect{};
  };

  std::mutex mutex_;
  std::unordered_map<std::string, std::unique_ptr<OverlayInfo>> overlays_;
  bool class_registered_ = false;

  void EnsureWindowClassRegistered();
  static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
  RECT GetMonitorRect(const std::string& device_path);
  void ApplyOpacityLocked(const std::string& device_path);
};

#endif  // RUNNER_OVERLAY_MANAGER_H_
