#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "monitor_manager.h"

#include <cmath>
#include <initguid.h>
#include <setupapi.h>
#include <devguid.h>
#include <ntddvdeo.h>
#include <cfgmgr32.h>
#include <algorithm>
#include <cctype>
#include <cwctype>
#include <highlevelmonitorconfigurationapi.h>
#include <physicalmonitorenumerationapi.h>

#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "dxva2.lib")
#pragma comment(lib, "Psapi.lib")

// GUID_DEVINTERFACE_MONITOR is usually {E6F07B5F-EE97-4a90-B076-33F57BF4EAA7}
DEFINE_GUID(GUID_DEVINTERFACE_MONITOR_INTERNAL, 0xE6F07B5F, 0xEE97, 0x4a90, 0xB0, 0x76, 0x33, 0xF5, 0x7B, 0xF4, 0xEA, 0xA7);

MonitorManager::MonitorManager() {
  last_gaming_match_time_ = std::chrono::steady_clock::now() - std::chrono::seconds(10);
  candidate_start_time_ = last_gaming_match_time_;
  
  worker_thread_ = std::thread(&MonitorManager::WorkerLoop, this);
  detector_thread_ = std::thread(&MonitorManager::DetectorLoop, this);
}

MonitorManager::~MonitorManager() {
  stop_worker_ = true;
  condition_.notify_one();
  if (worker_thread_.joinable()) {
    worker_thread_.join();
  }

  stop_detector_ = true;
  if (detector_thread_.joinable()) {
    detector_thread_.join();
  }
}

void MonitorManager::EnqueueTask(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    task_queue_.push(std::move(task));
  }
  condition_.notify_one();
}

void MonitorManager::WorkerLoop() {
  while (!stop_worker_) {
    std::function<void()> task;
    {
      std::unique_lock<std::mutex> lock(queue_mutex_);
      condition_.wait(lock, [this] { return stop_worker_.load() || !task_queue_.empty(); });
      if (stop_worker_ && task_queue_.empty()) return;
      if (!task_queue_.empty()) {
        task = std::move(task_queue_.front());
        task_queue_.pop();
      }
    }
    if (task) {
      task();
    }
  }
}

std::map<std::string, std::string> MonitorManager::GetMonitorFriendlyNames() {
  std::map<std::string, std::string> friendly_names;

  HDEVINFO dev_info = SetupDiGetClassDevsEx(
      &GUID_DEVINTERFACE_MONITOR_INTERNAL, nullptr, nullptr,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE, nullptr, nullptr, nullptr);

  if (dev_info == INVALID_HANDLE_VALUE) {
    return friendly_names;
  }

  SP_DEVICE_INTERFACE_DATA interface_data;
  interface_data.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

  for (DWORD i = 0; SetupDiEnumDeviceInterfaces(dev_info, nullptr, &GUID_DEVINTERFACE_MONITOR_INTERNAL, i, &interface_data); i++) {
    SP_DEVINFO_DATA device_data;
    device_data.cbSize = sizeof(SP_DEVINFO_DATA);

    DWORD detail_size = 0;
    SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, nullptr, 0, &detail_size, nullptr);

    std::vector<uint8_t> detail_buffer(detail_size);
    auto detail_data = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA_W>(detail_buffer.data());
    detail_data->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);

    if (SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, detail_data, detail_size, nullptr, &device_data)) {
      // Get the device path (e.g., \\?\DISPLAY#...)
      std::wstring device_path_w(detail_data->DevicePath);
      std::string device_path;
      for (wchar_t wc : device_path_w) {
        device_path += static_cast<char>(wc);
      }
      
      // Standardize the path for comparison (Windows might use different casing/separators)
      std::transform(device_path.begin(), device_path.end(), device_path.begin(), 
        [](unsigned char c) -> char { return static_cast<char>(std::tolower(c)); });
      // Replace # with \ to match some EnumDisplayDevices outputs if needed, 
      // but usually the registry path matches the symbolic link path.
      
      // Open registry key for this device
      HKEY hkey = SetupDiOpenDevRegKey(dev_info, &device_data, DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_READ);
      if (hkey != INVALID_HANDLE_VALUE) {
        DWORD edid_size = 0;
        if (RegQueryValueExW(hkey, L"EDID", nullptr, nullptr, nullptr, &edid_size) == ERROR_SUCCESS) {
          std::vector<uint8_t> edid(edid_size);
          if (RegQueryValueExW(hkey, L"EDID", nullptr, nullptr, edid.data(), &edid_size) == ERROR_SUCCESS) {
            std::string friendly_name = ParseEdid(edid);
            if (!friendly_name.empty()) {
              friendly_names[device_path] = friendly_name;
            }
          }
        }
        RegCloseKey(hkey);
      }
    }
  }

  SetupDiDestroyDeviceInfoList(dev_info);
  return friendly_names;
}

std::string MonitorManager::ParseEdid(const std::vector<uint8_t>& edid) {
  if (edid.size() < 128) return "";

  // Extract Manufacturer Name (bytes 8-9)
  uint16_t manufacturer_id = (edid[8] << 8) | edid[9];
  std::string brand = GetManufacturerName(manufacturer_id);

  // Search for Monitor Name descriptor (Type 0xFC)
  // Descriptors are at bytes 54, 72, 90, 108
  for (int i = 0; i < 4; i++) {
    int offset = 54 + (i * 18);
    // Bytes 0-1 are 0, Byte 2 is 0, Byte 3 is type
    if (edid[offset] == 0 && edid[offset + 1] == 0 && edid[offset + 2] == 0) {
      if (edid[offset + 3] == 0xFC) {
        // This is the monitor name
        std::string name;
        for (int j = 4; j < 18; j++) {
          char c = static_cast<char>(edid[offset + j]);
          if (c == 0x0A || c == 0x00) break;
          name += c;
        }
        // Trim whitespace
        name.erase(std::find_if(name.rbegin(), name.rend(), [](unsigned char ch) {
          return !std::isspace(ch);
        }).base(), name.end());
        
        if (!name.empty()) return name;
      }
    }
  }

  // If no name found, return brand + product ID (minimal)
  uint16_t product_id = edid[10] | (edid[11] << 8);
  char buf[32];
  snprintf(buf, sizeof(buf), "%s %04X", brand.c_str(), product_id);
  return std::string(buf);
}

std::string MonitorManager::GetManufacturerName(uint16_t id) {
  // Manufacturer ID is 3 uppercase letters, 5 bits each.
  // Bits: 14-10 (1st), 9-5 (2nd), 4-0 (3rd).
  char name[4];
  name[0] = ((id >> 10) & 0x1F) + 'A' - 1;
  name[1] = ((id >> 5) & 0x1F) + 'A' - 1;
  name[2] = (id & 0x1F) + 'A' - 1;
  name[3] = '\0';
  return std::string(name);
}

bool MonitorManager::SetBrightness(const std::string& device_path, int brightness) {
  // Clamp brightness to 0-100
  brightness = std::max(0, std::min(100, brightness));

  // Convert device_path to wstring for EnumDisplayDevices
  std::wstring target_device(device_path.begin(), device_path.end());

  DISPLAY_DEVICEW display_device;
  display_device.cb = sizeof(display_device);
  
  // We need to find the HMONITOR for the given device_path
  struct MonitorContext {
    std::wstring target_name;
    HMONITOR h_monitor = nullptr;
  } context;
  context.target_name = target_device;

  EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR h_monitor, HDC hdc, LPRECT rect, LPARAM data) -> BOOL {
    auto ctx = reinterpret_cast<MonitorContext*>(data);
    MONITORINFOEXW info;
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(h_monitor, &info)) {
      if (ctx->target_name == info.szDevice) {
        ctx->h_monitor = h_monitor;
        return FALSE; // Found it, stop enumeration
      }
    }
    return TRUE;
  }, reinterpret_cast<LPARAM>(&context));

  if (!context.h_monitor) {
    return false;
  }

  // Get physical monitors from HMONITOR
  DWORD physical_count = 0;
  if (!GetNumberOfPhysicalMonitorsFromHMONITOR(context.h_monitor, &physical_count)) {
    return false;
  }

  std::vector<PHYSICAL_MONITOR> physical_monitors(physical_count);
  if (!GetPhysicalMonitorsFromHMONITOR(context.h_monitor, physical_count, physical_monitors.data())) {
    return false;
  }

  bool success = false;
  for (DWORD i = 0; i < physical_count; i++) {
    if (::SetMonitorBrightness(physical_monitors[i].hPhysicalMonitor, (DWORD)brightness)) {
      success = true;
    }
  }

  DestroyPhysicalMonitors(physical_count, physical_monitors.data());
  return success;
}

bool MonitorManager::GetBrightness(const std::string& device_path, int& current, int& maximum) {
  // Convert device_path to wstring for EnumDisplayDevices
  std::wstring target_device(device_path.begin(), device_path.end());

  // We need to find the HMONITOR for the given device_path
  struct MonitorContext {
    std::wstring target_name;
    HMONITOR h_monitor = nullptr;
  } context;
  context.target_name = target_device;

  EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR h_monitor, HDC hdc, LPRECT rect, LPARAM data) -> BOOL {
    auto ctx = reinterpret_cast<MonitorContext*>(data);
    MONITORINFOEXW info;
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(h_monitor, &info)) {
      if (ctx->target_name == info.szDevice) {
        ctx->h_monitor = h_monitor;
        return FALSE; // Found it, stop enumeration
      }
    }
    return TRUE;
  }, reinterpret_cast<LPARAM>(&context));

  if (!context.h_monitor) {
    return false;
  }

  // Get physical monitors from HMONITOR
  DWORD physical_count = 0;
  if (!GetNumberOfPhysicalMonitorsFromHMONITOR(context.h_monitor, &physical_count)) {
    return false;
  }

  std::vector<PHYSICAL_MONITOR> physical_monitors(physical_count);
  if (!GetPhysicalMonitorsFromHMONITOR(context.h_monitor, physical_count, physical_monitors.data())) {
    return false;
  }

  bool success = false;
  for (DWORD i = 0; i < physical_count; i++) {
    DWORD dwMinimum, dwCurrent, dwMaximum;
    if (::GetMonitorBrightness(physical_monitors[i].hPhysicalMonitor, &dwMinimum, &dwCurrent, &dwMaximum)) {
      current = static_cast<int>(dwCurrent);
      maximum = static_cast<int>(dwMaximum);
      success = true;
      break; // Just take the first one for now
    }
  }

  DestroyPhysicalMonitors(physical_count, physical_monitors.data());
  return success;
}

bool MonitorManager::SetTemperature(const std::string& device_path, int kelvins) {
  // Convert Kelvin to RGB multipliers (0.0 to 1.0)
  // Simplified Tanner Helland's algorithm adapted for 1000-40000K
  double temp = std::max(1000, std::min(40000, kelvins)) / 100.0;
  
  double red = 1.0;
  double green = 1.0;
  double blue = 1.0;

  if (kelvins < 6500) {
    if (temp <= 66.0) {
        red = 255.0;
        green = 99.4708025861 * std::log(temp) - 161.1195681661;
        if (temp <= 19.0) {
            blue = 0.0;
        } else {
            blue = 138.5177312231 * std::log(temp - 10.0) - 305.0447927307;
        }
    } else {
        red = 329.698727446 * std::pow(temp - 60.0, -0.1332047592);
        green = 288.1221695283 * std::pow(temp - 60.0, -0.0755148492);
        blue = 255.0;
    }
  } else {
    // 6500K and above is treated as neutral (pure white multipliers)
    red = 255.0;
    green = 255.0;
    blue = 255.0;
  }

  // Clamp to 0-255 and normalize to 0.0-1.0
  double rFactor = std::max(0.0, std::min(255.0, red)) / 255.0;
  double gFactor = std::max(0.0, std::min(255.0, green)) / 255.0;
  double bFactor = std::max(0.0, std::min(255.0, blue)) / 255.0;

  // Convert device_path to wstring
  std::wstring target_device(device_path.begin(), device_path.end());

  // Apply to Gamma Ramp
  HDC hDC = CreateDCW(L"DISPLAY", target_device.c_str(), NULL, NULL);
  if (!hDC) return false;

  // Cache the original gamma ramp if not already cached
  {
      std::lock_guard<std::mutex> lock(gamma_mutex_);
      if (original_gamma_ramps_.find(device_path) == original_gamma_ramps_.end()) {
          WORD orig_ramp[3][256];
          if (GetDeviceGammaRamp(hDC, orig_ramp)) {
              std::vector<WORD> flat_ramp(3 * 256);
              std::memcpy(flat_ramp.data(), orig_ramp, sizeof(orig_ramp));
              original_gamma_ramps_[device_path] = flat_ramp;
          } else {
              // If we fail to get original, we'll construct a linear one as fallback
              std::vector<WORD> flat_ramp(3 * 256);
              for (int i = 0; i < 256; i++) {
                  int val = i * 257;
                  flat_ramp[i] = flat_ramp[i + 256] = flat_ramp[i + 512] = (WORD)std::min(65535, val);
              }
              original_gamma_ramps_[device_path] = flat_ramp;
          }
      }
  }

  std::vector<WORD> base_ramp;
  {
      std::lock_guard<std::mutex> lock(gamma_mutex_);
      base_ramp = original_gamma_ramps_[device_path];
  }
  
  WORD gammaArray[3][256];
  for (int i = 0; i < 256; i++) {
      // Scale original ramp by our temperature factors
      gammaArray[0][i] = (WORD)std::min(65535.0, base_ramp[i] * rFactor);
      gammaArray[1][i] = (WORD)std::min(65535.0, base_ramp[i + 256] * gFactor);
      gammaArray[2][i] = (WORD)std::min(65535.0, base_ramp[i + 512] * bFactor);
  }

  bool success = SetDeviceGammaRamp(hDC, gammaArray);
  DeleteDC(hDC);
  return success;
}

bool MonitorManager::ResetTemperature(const std::string& device_path) {
  std::wstring target_device(device_path.begin(), device_path.end());
  HDC hDC = CreateDCW(L"DISPLAY", target_device.c_str(), NULL, NULL);
  if (!hDC) return false;

  WORD gammaArray[3][256];
  std::vector<WORD> base_ramp;
  bool found = false;

  {
    std::lock_guard<std::mutex> lock(gamma_mutex_);
    auto it = original_gamma_ramps_.find(device_path);
    if (it != original_gamma_ramps_.end() && it->second.size() == (3 * 256)) {
      base_ramp = it->second;
      found = true;
    }
  }

  if (found) {
    for (int i = 0; i < 256; i++) {
      gammaArray[0][i] = base_ramp[i];
      gammaArray[1][i] = base_ramp[i + 256];
      gammaArray[2][i] = base_ramp[i + 512];
    }
  } else {
    // Fallback for fresh app starts without cached baseline.
    for (int i = 0; i < 256; i++) {
      WORD linear = static_cast<WORD>(i * 257);
      gammaArray[0][i] = linear;
      gammaArray[1][i] = linear;
      gammaArray[2][i] = linear;
    }
  }

  bool success = SetDeviceGammaRamp(hDC, gammaArray);
  DeleteDC(hDC);
  return success;
}

void MonitorManager::SetGamingModeCallback(std::function<void(bool)> callback) {
  on_gaming_mode_changed_ = callback;
}

void MonitorManager::UpdateWhitelist(const std::vector<std::string>& whitelist) {
  std::lock_guard<std::mutex> lock(lists_mutex_);
  whitelist_.clear();
  for (const auto& app : whitelist) {
    std::string lower_app = app;
    std::transform(lower_app.begin(), lower_app.end(), lower_app.begin(), [](unsigned char c) -> char { return static_cast<char>(std::tolower(c)); });
    whitelist_.insert(lower_app);
  }
}

void MonitorManager::UpdateBlacklist(const std::vector<std::string>& blacklist) {
  std::lock_guard<std::mutex> lock(lists_mutex_);
  blacklist_.clear();
  for (const auto& app : blacklist) {
    std::string lower_app = app;
    std::transform(lower_app.begin(), lower_app.end(), lower_app.begin(), [](unsigned char c) -> char { return static_cast<char>(std::tolower(c)); });
    blacklist_.insert(lower_app);
  }
}

void MonitorManager::DetectorLoop() {
  while (!stop_detector_) {
    HWND hwnd = GetForegroundWindow();
    bool is_match = false;
    
    if (hwnd) {
      DWORD processId;
      GetWindowThreadProcessId(hwnd, &processId);
      int score = EvaluateGamingScore(hwnd, processId);
      is_match = (score >= SCORE_THRESHOLD);
    }

    auto now = std::chrono::steady_clock::now();
    bool target_gaming_mode = false;

    if (is_match) {
        if (!is_gaming_candidate_) {
            is_gaming_candidate_ = true;
            candidate_start_time_ = now;
        }
        
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now - candidate_start_time_).count();
        if (duration >= ENTRY_DELAY_MS) {
            last_gaming_match_time_ = now;
            target_gaming_mode = true;
        }
    } else {
        is_gaming_candidate_ = false;
        
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_gaming_match_time_).count();
        if (duration < EXIT_DELAY_MS) {
            target_gaming_mode = true; // Hysteresis: Keep active
        } else {
            target_gaming_mode = false;
        }
    }

    if (target_gaming_mode != is_gaming_mode_) {
      is_gaming_mode_ = target_gaming_mode;
      if (on_gaming_mode_changed_) {
        on_gaming_mode_changed_(is_gaming_mode_);
      }
    }
    
    for (int i = 0; i < 10 && !stop_detector_; i++) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
  }
}

int MonitorManager::EvaluateGamingScore(HWND hwnd, DWORD processId) {
  if (!hwnd) return 0;

  // --- Early Exit: Class Check ---
  wchar_t className[256];
  if (GetClassNameW(hwnd, className, 256)) {
    std::wstring wsClassName(className);
    if (wsClassName == L"WorkerW" || wsClassName == L"Progman" || wsClassName == L"Shell_TrayWnd" || 
        wsClassName == L"MultitaskingViewFrame" || wsClassName == L"NotifyIconOverflowWindow" || 
        wsClassName == L"SimplePopupMenu" || wsClassName == L"RainmeterMeterWindow") {
      return 0;
    }
  }

  // --- Size Check ---
  HMONITOR hMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi = { sizeof(mi) };
  if (!GetMonitorInfoW(hMonitor, &mi)) return 0;

  RECT wr;
  if (!GetWindowRect(hwnd, &wr)) return 0;

  bool isFullscreen = (wr.left <= mi.rcMonitor.left + 1 && wr.top <= mi.rcMonitor.top + 1 &&
                       wr.right >= mi.rcMonitor.right - 1 && wr.bottom >= mi.rcMonitor.bottom - 1);

  if (!isFullscreen) return 0;

  // --- Style Analysis ---
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  // Real games don't have systemic frames or captions in fullscreen. 
  // If they have them, it's likely an app (Telegram viewer, etc)
  if ((style & WS_CAPTION) || (style & WS_THICKFRAME)) {
    return 0; 
  }

  int score = 0;
  std::string processName = "";
  std::wstring fullPathW = L"";
  
  HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
  if (hProcess) {
    wchar_t buffer[MAX_PATH];
    DWORD size = MAX_PATH;
    if (QueryFullProcessImageNameW(hProcess, 0, buffer, &size)) {
      fullPathW = buffer;
      std::wstring fullPathLower = fullPathW;
      std::transform(fullPathLower.begin(), fullPathLower.end(), fullPathLower.begin(), ::towlower);
      
      size_t lastSlash = fullPathW.find_last_of(L"\\/");
      std::wstring fileName = (lastSlash == std::wstring::npos) ? fullPathW : fullPathW.substr(lastSlash + 1);
      for (wchar_t wc : fileName) {
        processName += static_cast<char>(std::tolower(static_cast<unsigned char>(wc)));
      }

      // --- Path Heuristics ---
      if (fullPathLower.find(L"\\steamapps\\common\\") != std::wstring::npos ||
          fullPathLower.find(L"\\epic games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\origin games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\gog galaxy\\games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\xboxgames\\") != std::wstring::npos) {
        score += 100;
      }

      // Penalty for system paths
      if (fullPathLower.find(L"c:\\windows\\") != std::wstring::npos) {
          score -= 200;
      }
    }
    CloseHandle(hProcess);
  }

  // --- Whitelist / Blacklist ---
  {
    std::lock_guard<std::mutex> lock(lists_mutex_);
    if (whitelist_.count(processName)) return 1000; // Absolute match
    if (blacklist_.count(processName)) return -1000; // Absolute mismatch
  }

  // --- Parent Process Check ---
  std::string parentName = GetParentProcessName(processId);
  if (parentName == "steam.exe" || parentName == "epicgameslauncher.exe" || 
      parentName == "galaxyclient.exe" || parentName == "origin.exe") {
    score += 100;
  }

  // --- DLL Scanning (More permissive access) ---
  hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
  if (hProcess) {
    HMODULE hMods[1024];
    DWORD cbNeeded;
    if (EnumProcessModules(hProcess, hMods, sizeof(hMods), &cbNeeded)) {
      for (unsigned int i = 0; i < (cbNeeded / sizeof(HMODULE)); i++) {
        wchar_t szModName[MAX_PATH];
        if (GetModuleBaseNameW(hProcess, hMods[i], szModName, sizeof(szModName) / sizeof(wchar_t))) {
            std::wstring modName(szModName);
            std::transform(modName.begin(), modName.end(), modName.begin(), ::towlower);
            
            // Controller APIs (High confidence)
            if (modName.find(L"xinput") != std::wstring::npos) score += 60;
            if (modName == L"dinput8.dll") score += 50;

            // Audio engine (Medium confidence)
            if (modName.find(L"xaudio2") != std::wstring::npos) score += 30;

            // Graphics engines (Low confidence, apps use them too)
            if (modName == L"d3d11.dll" || modName == L"d3d12.dll" || modName == L"vulkan-1.dll") {
                score += 10;
            }
        }
      }
    }
    CloseHandle(hProcess);
  }

  // --- Cursor Behavior ---
  CURSORINFO ci = { sizeof(ci) };
  if (GetCursorInfo(&ci)) {
      if (!(ci.flags & CURSOR_SHOWING)) {
          score += 40; // Hidden cursor is very common in games
      }
  }

  RECT clipRect;
  if (GetClipCursor(&clipRect)) {
      // If the clip rect matches the window exactly or is significantly smaller than monitor
      if (abs(clipRect.left - wr.left) < 5 && abs(clipRect.top - wr.top) < 5 &&
          abs(clipRect.right - wr.right) < 5 && abs(clipRect.bottom - wr.bottom) < 5) {
          
          if ((clipRect.right - clipRect.left) < (mi.rcMonitor.right - mi.rcMonitor.left - 10)) {
              score += 60; // Isolated to small area
          } else {
              score += 30; // Exactly window size
          }
      }
  }

  // --- Shell notification flag ---
  QUERY_USER_NOTIFICATION_STATE notification_state;
  if (SHQueryUserNotificationState(&notification_state) == S_OK) {
    if (notification_state == QUNS_RUNNING_D3D_FULL_SCREEN) {
        score += 20;
    }
  }

  return score;
}

std::string MonitorManager::GetParentProcessName(DWORD processId) {
  DWORD ppid = 0;
  HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    if (Process32FirstW(hSnapshot, &pe32)) {
      do {
        if (pe32.th32ProcessID == processId) {
          ppid = pe32.th32ParentProcessID;
          break;
        }
      } while (Process32NextW(hSnapshot, &pe32));
    }
    
    if (ppid != 0) {
      // Reuse snapshot or close/re-open? Toolhelp says we can reuse.
      if (Process32FirstW(hSnapshot, &pe32)) {
        do {
          if (pe32.th32ProcessID == ppid) {
            std::wstring wsParent(pe32.szExeFile);
            std::string parentName = "";
            for (wchar_t wc : wsParent) {
              parentName += static_cast<char>(std::tolower(static_cast<unsigned char>(wc)));
            }
            CloseHandle(hSnapshot);
            return parentName;
          }
        } while (Process32NextW(hSnapshot, &pe32));
      }
    }
    CloseHandle(hSnapshot);
  }
  return "";
}

