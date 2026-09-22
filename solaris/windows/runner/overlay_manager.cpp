#include "overlay_manager.h"

#include <algorithm>
#include <cmath>

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

OverlayManager::OverlayManager() = default;

OverlayManager::~OverlayManager() {
  DestroyAllOverlays();
}

LRESULT CALLBACK OverlayManager::OverlayWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  HBRUSH brush = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));

  switch (msg) {
    case WM_ERASEBKGND: {
      HDC hdc = reinterpret_cast<HDC>(wparam);
      RECT rc;
      GetClientRect(hwnd, &rc);
      FillRect(hdc, &rc, brush);
      return 1;
    }
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(hwnd, &ps);
      FillRect(hdc, &ps.rcPaint, brush);
      EndPaint(hwnd, &ps);
      return 0;
    }
    case WM_NCHITTEST:
      // Guarantee click-through at the message level in addition to WS_EX_TRANSPARENT
      return HTTRANSPARENT;
    case WM_MOUSEACTIVATE:
      // Ensure the window is never activated on any mouse interaction
      return MA_NOACTIVATE;
    case WM_DESTROY:
      return 0;
    default:
      return DefWindowProcW(hwnd, msg, wparam, lparam);
  }
}

void OverlayManager::EnsureWindowClassRegistered() {
  if (class_registered_) return;

  WNDCLASSEXW wc = {sizeof(WNDCLASSEXW)};
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = OverlayWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hCursor = nullptr;
  wc.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
  wc.lpszClassName = L"Solaris_Dimming_Overlay";

  RegisterClassExW(&wc);
  class_registered_ = true;
}

RECT OverlayManager::GetMonitorRect(const std::string& device_path) {
  std::wstring target_device(device_path.begin(), device_path.end());
  struct Context {
    std::wstring target;
    RECT rect{0, 0, 0, 0};
    bool found = false;
  } ctx;
  ctx.target = target_device;

  EnumDisplayMonitors(
      nullptr, nullptr,
      [](HMONITOR h_monitor, HDC hdc, LPRECT rect, LPARAM data) -> BOOL {
        auto* c = reinterpret_cast<Context*>(data);
        MONITORINFOEXW info;
        info.cbSize = sizeof(info);
        if (GetMonitorInfoW(h_monitor, &info)) {
          if (c->target == info.szDevice) {
            c->rect = info.rcMonitor;
            c->found = true;
            return FALSE;
          }
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&ctx));

  return ctx.rect;
}

void OverlayManager::SetOverlayOpacity(const std::string& device_path, double opacity) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto& info_ptr = overlays_[device_path];
  if (!info_ptr) {
    info_ptr = std::make_unique<OverlayInfo>();
  }
  info_ptr->opacity = std::max(0.0, std::min(0.85, opacity));
  ApplyOpacityLocked(device_path);
}

void OverlayManager::ApplyOpacityLocked(const std::string& device_path) {
  auto it = overlays_.find(device_path);
  if (it == overlays_.end() || !it->second) {
    return;
  }

  OverlayInfo& info = *(it->second);
  double dim = info.opacity;

  // If dimming is 0, hide the overlay window
  if (dim <= 0.001) {
    if (info.hwnd && IsWindow(info.hwnd)) {
      ShowWindow(info.hwnd, SW_HIDE);
    }
    info.alpha = 0;
    return;
  }

  EnsureWindowClassRegistered();

  RECT rc = GetMonitorRect(device_path);
  int width = rc.right - rc.left;
  int height = rc.bottom - rc.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  info.last_rect = rc;

  // Safety Floor: Clamp opacity to a maximum of 85% to ensure the user never gets a completely black screen
  double clamped_dim = std::max(0.0, std::min(0.85, dim));
  BYTE alpha = static_cast<BYTE>(std::round(clamped_dim * 255.0));
  info.alpha = alpha;

  if (!info.hwnd || !IsWindow(info.hwnd)) {
    info.hwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        L"Solaris_Dimming_Overlay",
        L"",
        WS_POPUP,
        rc.left, rc.top, width, height,
        nullptr, nullptr, GetModuleHandle(nullptr), nullptr);

    if (!info.hwnd || !IsWindow(info.hwnd)) {
      return;
    }

    // Completely exclude overlay from screenshots, Windows Graphics Capture, OBS, and desktop sharing
    SetWindowDisplayAffinity(info.hwnd, WDA_EXCLUDEFROMCAPTURE);
  }

  // Update layered window alpha transparency
  SetLayeredWindowAttributes(info.hwnd, RGB(0, 0, 0), alpha, LWA_ALPHA);

  // Position and show window without activating it (prevents stealing focus)
  SetWindowPos(info.hwnd, HWND_TOPMOST, rc.left, rc.top, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);

  if (info.hwnd && IsWindow(info.hwnd)) {
    InvalidateRect(info.hwnd, nullptr, TRUE);
  }
}

void OverlayManager::UpdateMonitorBounds() {
  std::lock_guard<std::mutex> lock(mutex_);
  for (auto& [path, info_ptr] : overlays_) {
    if (info_ptr && info_ptr->hwnd && IsWindow(info_ptr->hwnd) && info_ptr->alpha > 0) {
      RECT rc = GetMonitorRect(path);
      int width = rc.right - rc.left;
      int height = rc.bottom - rc.top;
      if (width > 0 && height > 0) {
        info_ptr->last_rect = rc;
        SetWindowPos(info_ptr->hwnd, HWND_TOPMOST, rc.left, rc.top, width, height,
                     SWP_NOACTIVATE | SWP_SHOWWINDOW);
      } else {
        ShowWindow(info_ptr->hwnd, SW_HIDE);
      }
    }
  }
}

void OverlayManager::DestroyAllOverlays() {
  std::lock_guard<std::mutex> lock(mutex_);
  for (auto& [path, info_ptr] : overlays_) {
    if (info_ptr) {
      if (info_ptr->hwnd && IsWindow(info_ptr->hwnd)) {
        DestroyWindow(info_ptr->hwnd);
        info_ptr->hwnd = nullptr;
      }
    }
  }
  overlays_.clear();
}
