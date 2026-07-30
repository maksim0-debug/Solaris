#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "monitor_manager.h"

#include <algorithm>
#include <cctype>
#include <cfgmgr32.h>
#include <cmath>
#include <cwctype>
#include <devguid.h>
#include <highlevelmonitorconfigurationapi.h>
#include <initguid.h>
#include <ntddvdeo.h>
#include <physicalmonitorenumerationapi.h>
#include <setupapi.h>
#include <unordered_map>


#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "dxva2.lib")
#pragma comment(lib, "Psapi.lib")

// GUID_DEVINTERFACE_MONITOR is usually {E6F07B5F-EE97-4a90-B076-33F57BF4EAA7}
DEFINE_GUID(GUID_DEVINTERFACE_MONITOR_INTERNAL, 0xE6F07B5F, 0xEE97, 0x4a90,
            0xB0, 0x76, 0x33, 0xF5, 0x7B, 0xF4, 0xEA, 0xA7);

MonitorManager::MonitorManager() {
  last_gaming_match_time_ =
      std::chrono::steady_clock::now() - std::chrono::hours(24);
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

  ResetAllMonitorsTemperatureSync();
  DestroyPhysicalMonitorsCache();
}

void MonitorManager::SetHardwareErrorCallback(std::function<void(const std::string&)> callback) {
  std::lock_guard<std::mutex> lock(error_cb_mutex_);
  on_hardware_error_ = callback;
}

void MonitorManager::InvalidateMonitorHandles() {
  std::lock_guard<std::mutex> lock(handles_mutex_);
  DestroyPhysicalMonitorsCache();
}

void MonitorManager::InvalidateMonitorHandlesDebounced(int delay_ms) {
  EnqueueTask([this, delay_ms]() {
    std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
    InvalidateMonitorHandles();
  });
}

void MonitorManager::DestroyPhysicalMonitorsCache() {
  for (auto& pair : physical_monitors_cache_) {
    if (!pair.second.empty()) {
      ::DestroyPhysicalMonitors(static_cast<DWORD>(pair.second.size()), pair.second.data());
    }
  }
  physical_monitors_cache_.clear();
}

std::vector<PHYSICAL_MONITOR> MonitorManager::GetOrCreatePhysicalMonitors(const std::string& device_path) {
  std::lock_guard<std::mutex> lock(handles_mutex_);
  auto it = physical_monitors_cache_.find(device_path);
  if (it != physical_monitors_cache_.end() && !it->second.empty()) {
    return it->second;
  }

  std::wstring target_device(device_path.begin(), device_path.end());
  struct MonitorContext {
    std::wstring target_name;
    HMONITOR h_monitor = nullptr;
  } context;
  context.target_name = target_device;

  EnumDisplayMonitors(
      nullptr, nullptr,
      [](HMONITOR h_monitor, HDC hdc, LPRECT rect, LPARAM data) -> BOOL {
        auto ctx = reinterpret_cast<MonitorContext *>(data);
        MONITORINFOEXW info;
        info.cbSize = sizeof(info);
        if (GetMonitorInfoW(h_monitor, &info)) {
          if (ctx->target_name == info.szDevice) {
            ctx->h_monitor = h_monitor;
            return FALSE;
          }
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&context));

  if (!context.h_monitor) {
    return {};
  }

  DWORD physical_count = 0;
  if (!GetNumberOfPhysicalMonitorsFromHMONITOR(context.h_monitor, &physical_count) || physical_count == 0) {
    return {};
  }

  std::vector<PHYSICAL_MONITOR> physical_monitors(physical_count);
  if (!GetPhysicalMonitorsFromHMONITOR(context.h_monitor, physical_count, physical_monitors.data())) {
    return {};
  }

  physical_monitors_cache_[device_path] = physical_monitors;
  return physical_monitors;
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
      condition_.wait(
          lock, [this] { return stop_worker_.load() || !task_queue_.empty(); });
      if (stop_worker_ && task_queue_.empty())
        return;
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

  for (DWORD i = 0; SetupDiEnumDeviceInterfaces(
           dev_info, nullptr, &GUID_DEVINTERFACE_MONITOR_INTERNAL, i,
           &interface_data);
       i++) {
    SP_DEVINFO_DATA device_data;
    device_data.cbSize = sizeof(SP_DEVINFO_DATA);

    DWORD detail_size = 0;
    SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, nullptr, 0,
                                     &detail_size, nullptr);

    std::vector<uint8_t> detail_buffer(detail_size);
    auto detail_data = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA_W>(
        detail_buffer.data());
    detail_data->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);

    if (SetupDiGetDeviceInterfaceDetailW(dev_info, &interface_data, detail_data,
                                         detail_size, nullptr, &device_data)) {
      // Get the device path (e.g., \\?\DISPLAY#...)
      std::wstring device_path_w(detail_data->DevicePath);
      std::string device_path;
      for (wchar_t wc : device_path_w) {
        device_path += static_cast<char>(wc);
      }

      // Standardize the path for comparison (Windows might use different
      // casing/separators)
      std::transform(device_path.begin(), device_path.end(),
                     device_path.begin(), [](unsigned char c) -> char {
                       return static_cast<char>(std::tolower(c));
                     });
      // Replace # with \ to match some EnumDisplayDevices outputs if needed,
      // but usually the registry path matches the symbolic link path.

      // Open registry key for this device
      HKEY hkey = SetupDiOpenDevRegKey(dev_info, &device_data, DICS_FLAG_GLOBAL,
                                       0, DIREG_DEV, KEY_READ);
      if (hkey != INVALID_HANDLE_VALUE) {
        DWORD edid_size = 0;
        if (RegQueryValueExW(hkey, L"EDID", nullptr, nullptr, nullptr,
                             &edid_size) == ERROR_SUCCESS) {
          std::vector<uint8_t> edid(edid_size);
          if (RegQueryValueExW(hkey, L"EDID", nullptr, nullptr, edid.data(),
                               &edid_size) == ERROR_SUCCESS) {
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

namespace {
std::string GetPrettyBrandName(const std::string &brand_code) {
  static const std::unordered_map<std::string, std::string> kBrandMap = {
      {"ACR", "Acer"},      {"CHE", "Acer"},
      {"API", "Acer"},      {"AOC", "AOC"},
      {"APP", "Apple"},     {"ASU", "ASUS"},
      {"AUS", "ASUS"},      {"BNQ", "BenQ"},
      {"BOE", "BOE"},       {"CMN", "Chimei Innolux"},
      {"CHI", "Chimei"},    {"CPQ", "Compaq"},
      {"CRM", "Corsair"},   {"DEL", "Dell"},
      {"DFI", "DFI"},       {"EIZ", "Eizo"},
      {"ELG", "Elgato"},    {"EPI", "Envision"},
      {"FCM", "Funai"},     {"FUJ", "Fujitsu"},
      {"FUS", "Fujitsu"},   {"GBT", "Gigabyte"},
      {"GBY", "Gigabyte"},  {"GIG", "Gigabyte"},
      {"GLD", "Goldstar"},  {"GSM", "LG"},
      {"GWY", "Gateway"},
      {"HKC", "HKC"},       {"HNM", "Honor"},
      {"HPQ", "HP"},        {"HWP", "HP"},
      {"HSD", "Hannspree"}, {"HSG", "Hannspree"},
      {"HTC", "Hitachi"},   {"HWV", "Huawei"},
      {"HYU", "Hyundai"},   {"IBM", "IBM"},
      {"INL", "Innolux"},   {"IVM", "Iiyama"},
      {"JVC", "JVC"},       {"KDS", "KDS"},
      {"KTC", "KTC"},       {"LEN", "Lenovo"},
      {"LNV", "Lenovo"},    {"LGD", "LG"},
      {"LGP", "LG"},        {"LPL", "LG"},
      {"MAX", "Maxdata"},   {"MEL", "Mitsubishi"},
      {"MSI", "MSI"},       {"NEC", "NEC"},
      {"NOK", "Nokia"},     {"NVD", "Nvidia"},
      {"OVR", "Oculus"},    {"PAN", "Panasonic"},
      {"RZR", "Razer"},     {"PHL", "Philips"},
      {"PNR", "Planar"},    {"SAM", "Samsung"},
      {"SEM", "Samsung"},   {"SDC", "Samsung"},
      {"SHP", "Sharp"},     {"SNY", "Sony"},
      {"SON", "Sony"},      {"SPT", "Sceptre"},
      {"SUN", "Sun"},       {"TAT", "Tatung"},
      {"TOS", "Toshiba"},   {"TSB", "Toshiba"},
      {"TPV", "TPV"},       {"VSC", "ViewSonic"},
      {"WAC", "Wacom"},     {"XMI", "Xiaomi"},
      {"YMH", "Yamaha"}};

  auto it = kBrandMap.find(brand_code);
  if (it != kBrandMap.end()) {
    return it->second;
  }
  return brand_code;
}

bool ContainsIgnoreCase(const std::string &str, const std::string &search) {
  if (search.empty())
    return true;
  auto it =
      std::search(str.begin(), str.end(), search.begin(), search.end(),
                  [](char ch1, char ch2) {
                    return std::tolower(static_cast<unsigned char>(ch1)) ==
                           std::tolower(static_cast<unsigned char>(ch2));
                  });
  return it != str.end();
}
} // namespace

std::string MonitorManager::ParseEdid(const std::vector<uint8_t> &edid) {
  if (edid.size() < 128)
    return "";

  // Extract Manufacturer Name (bytes 8-9)
  uint16_t manufacturer_id = (edid[8] << 8) | edid[9];
  std::string brand_code = GetManufacturerName(manufacturer_id);
  std::string brand = GetPrettyBrandName(brand_code);

  // Search for Monitor Name descriptor (Type 0xFC)
  // Descriptors are at bytes 54, 72, 90, 108
  for (int i = 0; i < 4; i++) {
    int offset = 54 + (i * 18);
    // Bytes 0-1 are 0, Byte 2 is 0, Byte 3 is type
    if (edid[offset] == 0 && edid[offset + 1] == 0 && edid[offset + 2] == 0) {
      if (edid[offset + 3] == 0xFC) {
        // This is the monitor name. In EDID, it starts at index 5 of the
        // descriptor. Byte 4 is reserved (usually 0x00), so starting at 4 would
        // immediately break the loop.
        std::string name;
        for (int j = 5; j < 18; j++) {
          char c = static_cast<char>(edid[offset + j]);
          if (c == 0x0A || c == 0x00)
            break;
          name += c;
        }
        // Trim whitespace
        name.erase(
            std::find_if(name.rbegin(), name.rend(),
                         [](unsigned char ch) { return !std::isspace(ch); })
                .base(),
            name.end());

        if (!name.empty()) {
          // If the name already contains the brand (e.g. "LG IPS224" vs brand
          // "LG"), return it. Otherwise, prepend the brand name.
          if (ContainsIgnoreCase(name, brand)) {
            return name;
          } else {
            return brand + " " + name;
          }
        }
      }
    }
  }

  // If no name found, return brand + product ID (minimal)
  uint16_t product_id = edid[10] | (edid[11] << 8);
  char buf[64];
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
bool MonitorManager::SetBrightness(const std::string &device_path, int brightness) {
  // Clamp brightness to 0-100
  brightness = std::max(0, std::min(100, brightness));

  auto physical_monitors = GetOrCreatePhysicalMonitors(device_path);
  if (physical_monitors.empty()) {
    return false;
  }

  bool success = false;
  for (size_t i = 0; i < physical_monitors.size(); i++) {
    if (::SetMonitorBrightness(physical_monitors[i].hPhysicalMonitor, (DWORD)brightness)) {
      success = true;
    } else {
      DWORD err = GetLastError();
      if (err == 0xC0262588 /* STATUS_GRAPHICS_MC_INVALID_PHYSICAL_MONITOR_HANDLE */) {
        InvalidateMonitorHandles();
      }
      std::lock_guard<std::mutex> lock(error_cb_mutex_);
      if (on_hardware_error_) {
        on_hardware_error_("DDC/CI SetMonitorBrightness failed for " + device_path);
      }
    }
  }

  return success;
}

bool MonitorManager::GetBrightness(const std::string &device_path, int &current, int &maximum) {
  auto physical_monitors = GetOrCreatePhysicalMonitors(device_path);
  if (physical_monitors.empty()) {
    return false;
  }

  bool success = false;
  for (size_t i = 0; i < physical_monitors.size(); i++) {
    DWORD dwMinimum, dwCurrent, dwMaximum;
    if (::GetMonitorBrightness(physical_monitors[i].hPhysicalMonitor, &dwMinimum, &dwCurrent, &dwMaximum)) {
      current = static_cast<int>(dwCurrent);
      maximum = static_cast<int>(dwMaximum);
      success = true;
      break;
    }
  }

  return success;
}

bool MonitorManager::SetTemperature(const std::string &device_path,
                                    int kelvins) {
  if (kelvins >= 6500) {
    return ResetTemperature(device_path);
  }

  // Convert Kelvin to RGB multipliers (0.0 to 1.0)
  // Simplified Tanner Helland's algorithm adapted for 1000-40000K
  double temp = std::max(1000, std::min(40000, kelvins)) / 100.0;

  double red = 1.0;
  double green = 1.0;
  double blue = 1.0;

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

  // Clamp to 0-255 and normalize to 0.0-1.0
  double rFactor = std::max(0.0, std::min(255.0, red)) / 255.0;
  double gFactor = std::max(0.0, std::min(255.0, green)) / 255.0;
  double bFactor = std::max(0.0, std::min(255.0, blue)) / 255.0;

  // Convert device_path to wstring
  std::wstring target_device;
  target_device.reserve(device_path.length());
  for (char c : device_path) {
    target_device.push_back(static_cast<wchar_t>(c));
  }

  // Apply to Gamma Ramp
  HDC hDC = CreateDCW(L"DISPLAY", target_device.c_str(), NULL, NULL);
  if (!hDC)
    return false;

  std::vector<WORD> base_ramp;
  {
    std::lock_guard<std::mutex> lock(gamma_mutex_);
    auto it = original_gamma_ramps_.find(device_path);
    if (it == original_gamma_ramps_.end()) {
      WORD orig_ramp[3][256];
      bool is_valid_neutral = false;
      if (GetDeviceGammaRamp(hDC, orig_ramp)) {
        // Validate if captured ramp isn't pre-tinted by checking blue vs red channel ratio at midpoint (L128)
        if (orig_ramp[0][128] > 0) {
          double blue_red_ratio = (double)orig_ramp[2][128] / (double)orig_ramp[0][128];
          if (blue_red_ratio >= 0.95) {
            is_valid_neutral = true;
          }
        }
      }

      std::vector<WORD> flat_ramp(3 * 256);
      if (is_valid_neutral) {
        std::memcpy(flat_ramp.data(), orig_ramp, sizeof(orig_ramp));
      } else {
        // Construct pure linear baseline if captured ramp was warm/invalid
        for (int i = 0; i < 256; i++) {
          int val = i * 257;
          flat_ramp[i] = flat_ramp[i + 256] = flat_ramp[i + 512] =
              (WORD)std::min(65535, val);
        }
      }
      original_gamma_ramps_[device_path] = flat_ramp;
      base_ramp = flat_ramp;
    } else {
      base_ramp = it->second;
    }
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

bool MonitorManager::ResetTemperature(const std::string &device_path) {
  std::wstring target_device;
  target_device.reserve(device_path.length());
  for (char c : device_path) {
    target_device.push_back(static_cast<wchar_t>(c));
  }
  HDC hDC = CreateDCW(L"DISPLAY", target_device.c_str(), NULL, NULL);
  if (!hDC)
    return false;

  WORD gammaArray[3][256];
  bool found = false;
  std::vector<WORD> base_ramp;

  {
    std::lock_guard<std::mutex> lock(gamma_mutex_);
    auto it = original_gamma_ramps_.find(device_path);
    if (it != original_gamma_ramps_.end() && it->second.size() == (3 * 256)) {
      base_ramp = it->second;
      found = true;
    }
  }

  if (found) {
    // Restore user's original calibrated baseline ramp (preserving DisplayCAL / ICC profile)
    for (int i = 0; i < 256; i++) {
      gammaArray[0][i] = base_ramp[i];
      gammaArray[1][i] = base_ramp[i + 256];
      gammaArray[2][i] = base_ramp[i + 512];
    }
  } else {
    // Pure linear fallback
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

bool MonitorManager::ResetAllMonitorsTemperatureSync() {
  DISPLAY_DEVICEA displayDevice;
  ZeroMemory(&displayDevice, sizeof(displayDevice));
  displayDevice.cb = sizeof(displayDevice);

  DWORD deviceIndex = 0;
  bool all_success = true;
  while (EnumDisplayDevicesA(NULL, deviceIndex, &displayDevice, 0)) {
    if ((displayDevice.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0) {
      std::string device_path(displayDevice.DeviceName);
      if (!ResetTemperature(device_path)) {
        all_success = false;
      }
    }
    deviceIndex++;
  }
  return all_success;
}

namespace {
struct ScopedHandle {
  HANDLE handle = NULL;
  explicit ScopedHandle(HANDLE h = NULL) : handle(h) {}
  ~ScopedHandle() {
    if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
      CloseHandle(handle);
    }
  }
  ScopedHandle(const ScopedHandle&) = delete;
  ScopedHandle& operator=(const ScopedHandle&) = delete;
  ScopedHandle(ScopedHandle&& other) noexcept : handle(other.handle) {
    other.handle = NULL;
  }
  ScopedHandle& operator=(ScopedHandle&& other) noexcept {
    if (this != &other) {
      if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
        CloseHandle(handle);
      }
      handle = other.handle;
      other.handle = NULL;
    }
    return *this;
  }

  bool is_valid() const { return handle != NULL && handle != INVALID_HANDLE_VALUE; }
  operator HANDLE() const { return handle; }
  HANDLE get() const { return handle; }
};

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return "";
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.size()), NULL, 0, NULL, NULL);
  if (size_needed <= 0) return "";
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.size()), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

std::string GetProcessExeName(DWORD pid) {
  if (pid == 0) return "";
  ScopedHandle hProcess(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid));
  if (!hProcess.is_valid()) return "";

  wchar_t buffer[4096];
  DWORD size = 4096;
  std::wstring full_path;
  if (QueryFullProcessImageNameW(hProcess.get(), 0, buffer, &size)) {
    full_path = std::wstring(buffer, size);
  }

  if (full_path.empty()) return "";

  for (wchar_t& wc : full_path) {
    wc = static_cast<wchar_t>(::towlower(wc));
  }

  size_t last_slash = full_path.find_last_of(L"\\/");
  std::wstring file_name = (last_slash == std::wstring::npos) ? full_path : full_path.substr(last_slash + 1);

  return WideToUtf8(file_name);
}

struct UwpSearchContext {
  DWORD child_pid = 0;
};

BOOL CALLBACK EnumUwpChildWindowsProc(HWND hwnd, LPARAM lParam) {
  auto* ctx = reinterpret_cast<UwpSearchContext*>(lParam);
  if (!IsWindowVisible(hwnd)) return TRUE;

  wchar_t class_name[256];
  if (GetClassNameW(hwnd, class_name, 256)) {
    if (wcscmp(class_name, L"Windows.UI.Core.CoreWindow") == 0) {
      RECT rect;
      if (GetWindowRect(hwnd, &rect) && (rect.right - rect.left > 0) && (rect.bottom - rect.top > 0)) {
        DWORD pid = 0;
        GetWindowThreadProcessId(hwnd, &pid);
        if (pid != 0) {
          ctx->child_pid = pid;
          return FALSE;
        }
      }
    }
  }
  return TRUE;
}

std::string ExtractProcessNameWithUwp(HWND hwnd, DWORD pid) {
  std::string exe_name = GetProcessExeName(pid);
  if (exe_name == "applicationframehost.exe") {
    UwpSearchContext ctx;
    EnumChildWindows(hwnd, EnumUwpChildWindowsProc, reinterpret_cast<LPARAM>(&ctx));
    if (ctx.child_pid != 0 && ctx.child_pid != pid) {
      std::string child_exe = GetProcessExeName(ctx.child_pid);
      if (!child_exe.empty()) {
        return child_exe;
      }
    }
  }
  return exe_name;
}

struct EnumWindowsContext {
  DWORD current_pid = GetCurrentProcessId();
  std::vector<std::pair<std::string, std::string>> processes;
  std::set<std::string> seen_exes;
};

BOOL CALLBACK EnumGuiWindowsProc(HWND hwnd, LPARAM lParam) {
  auto* ctx = reinterpret_cast<EnumWindowsContext*>(lParam);

  if (!IsWindowVisible(hwnd)) return TRUE;

  LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  if (exStyle & WS_EX_TOOLWINDOW) return TRUE;

  int title_len = GetWindowTextLengthW(hwnd);
  if (title_len <= 0) return TRUE;

  RECT rect;
  if (!GetWindowRect(hwnd, &rect) || (rect.right - rect.left <= 0) || (rect.bottom - rect.top <= 0)) {
    return TRUE;
  }

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0 || pid == ctx->current_pid) return TRUE;

  std::string exe_name = ExtractProcessNameWithUwp(hwnd, pid);
  if (exe_name.empty() || exe_name == "solaris.exe") return TRUE;

  if (ctx->seen_exes.count(exe_name)) return TRUE;

  wchar_t title_buf[512];
  int read_len = GetWindowTextW(hwnd, title_buf, 512);
  std::string utf8_title;
  if (read_len > 0) {
    utf8_title = WideToUtf8(std::wstring(title_buf, read_len));
  }

  ctx->seen_exes.insert(exe_name);
  ctx->processes.push_back({exe_name, utf8_title});
  return TRUE;
}
} // namespace

void MonitorManager::SetFocusAndGamingCallback(
    std::function<void(bool is_gaming, const std::string& active_process)> callback) {
  std::lock_guard<std::mutex> lock(focus_mutex_);
  on_focus_and_gaming_changed_ = callback;
}

std::string MonitorManager::GetActiveProcessName() const {
  std::lock_guard<std::mutex> lock(focus_mutex_);
  return active_process_name_;
}

std::vector<std::pair<std::string, std::string>> MonitorManager::GetRunningProcesses() {
  EnumWindowsContext ctx;
  EnumWindows(EnumGuiWindowsProc, reinterpret_cast<LPARAM>(&ctx));
  return ctx.processes;
}


void MonitorManager::UpdateWhitelist(
    const std::vector<std::string> &whitelist) {
  std::lock_guard<std::mutex> lock(lists_mutex_);
  whitelist_.clear();
  for (const auto &app : whitelist) {
    std::string lower_app = app;
    std::transform(lower_app.begin(), lower_app.end(), lower_app.begin(),
                   [](unsigned char c) -> char {
                     return static_cast<char>(std::tolower(c));
                   });
    size_t lastSlash = lower_app.find_last_of("\\/");
    if (lastSlash != std::string::npos) {
      lower_app = lower_app.substr(lastSlash + 1);
    }
    if (!lower_app.empty()) {
      whitelist_.insert(lower_app);
    }
  }
  active_game_hwnd_ = nullptr;
  active_game_pid_ = 0;
  if (last_active_game_pid_ != 0) {
    ScopedHandle hProcess(OpenProcess(SYNCHRONIZE, FALSE, last_active_game_pid_));
    if (hProcess.is_valid()) {
      if (WaitForSingleObject(hProcess.get(), 0) != WAIT_TIMEOUT) {
        last_active_game_pid_ = 0; // Process actually exited
      }
    } else {
      last_active_game_pid_ = 0;
    }
  }
  is_gaming_candidate_ = false;
  process_cache_.clear();
}

void MonitorManager::UpdateBlacklist(
    const std::vector<std::string> &blacklist) {
  std::lock_guard<std::mutex> lock(lists_mutex_);
  blacklist_.clear();
  for (const auto &app : blacklist) {
    std::string lower_app = app;
    std::transform(lower_app.begin(), lower_app.end(), lower_app.begin(),
                   [](unsigned char c) -> char {
                     return static_cast<char>(std::tolower(c));
                   });
    size_t lastSlash = lower_app.find_last_of("\\/");
    if (lastSlash != std::string::npos) {
      lower_app = lower_app.substr(lastSlash + 1);
    }
    if (!lower_app.empty()) {
      blacklist_.insert(lower_app);
    }
  }
  active_game_hwnd_ = nullptr;
  active_game_pid_ = 0;
  if (last_active_game_pid_ != 0) {
    ScopedHandle hProcess(OpenProcess(SYNCHRONIZE, FALSE, last_active_game_pid_));
    if (hProcess.is_valid()) {
      if (WaitForSingleObject(hProcess.get(), 0) != WAIT_TIMEOUT) {
        last_active_game_pid_ = 0; // Process actually exited
      }
    } else {
      last_active_game_pid_ = 0;
    }
  }
  is_gaming_candidate_ = false;
  process_cache_.clear();
}

void MonitorManager::SetGameModeExitDelay(int delay_seconds) {
  if (delay_seconds < 0) delay_seconds = 0;
  if (delay_seconds > 300) delay_seconds = 300;
  exit_delay_ms_ = delay_seconds * 1000;
}

static bool IsAppInSet(const std::string &process_name_lower,
                       const std::set<std::string> &app_set) {
  if (app_set.empty() || process_name_lower.empty())
    return false;
  if (app_set.count(process_name_lower))
    return true;

  if (process_name_lower.size() > 4 &&
      process_name_lower.compare(process_name_lower.size() - 4, 4, ".exe") == 0) {
    std::string name_no_ext =
        process_name_lower.substr(0, process_name_lower.size() - 4);
    if (app_set.count(name_no_ext))
      return true;
  }

  if (process_name_lower.size() <= 4 ||
      process_name_lower.compare(process_name_lower.size() - 4, 4, ".exe") != 0) {
    std::string name_with_ext = process_name_lower + ".exe";
    if (app_set.count(name_with_ext))
      return true;
  }

  return false;
}

void MonitorManager::DetectorLoop() {
  HWND last_hwnd = nullptr;
  DWORD last_pid = 0;
  int eval_tick_counter = 0;
  bool is_match = false;

  while (!stop_detector_) {
    HWND hwnd = GetForegroundWindow();
    DWORD processId = 0;
    if (hwnd) {
      GetWindowThreadProcessId(hwnd, &processId);
    }

    std::string current_active_process = "";
    if (hwnd && processId != 0) {
      current_active_process = ExtractProcessNameWithUwp(hwnd, processId);
    }

    bool hwnd_or_pid_changed = (hwnd != last_hwnd || processId != last_pid);
    if (hwnd_or_pid_changed) {
      last_hwnd = hwnd;
      last_pid = processId;
      eval_tick_counter = 0;
    }

    bool should_eval = hwnd_or_pid_changed || (eval_tick_counter >= 20);
    if (should_eval) {
      eval_tick_counter = 0;
      is_match = false;

      if (hwnd) {
        bool check_completed = false;

        // Bypass Check (State Lock):
        if (active_game_hwnd_ != nullptr) {
          if (hwnd == active_game_hwnd_ || processId == active_game_pid_) {
            bool is_whitelisted = false;
            bool is_blacklisted = false;
            {
              std::lock_guard<std::mutex> lock(lists_mutex_);
              auto cache_it = process_cache_.find(processId);
              if (cache_it != process_cache_.end() &&
                  !cache_it->second.process_name_lower.empty()) {
                if (IsAppInSet(cache_it->second.process_name_lower, blacklist_)) {
                  is_blacklisted = true;
                } else if (IsAppInSet(cache_it->second.process_name_lower, whitelist_)) {
                  is_whitelisted = true;
                }
              }
            }

            if (!is_blacklisted && (is_whitelisted || IsWindowFullscreen(hwnd))) {
              is_match = true;
              check_completed = true;
            } else {
              active_game_hwnd_ = nullptr;
              active_game_pid_ = 0;
              if (is_blacklisted) {
                last_active_game_pid_ = 0;
              }
            }
          } else {
            active_game_hwnd_ = nullptr;
            active_game_pid_ = 0;
          }
        }

        // Standard Search:
        if (!check_completed) {
          int score = EvaluateGamingScore(hwnd, processId);
          if (score >= SCORE_THRESHOLD) {
            is_match = true;
            active_game_hwnd_ = hwnd;
            active_game_pid_ = processId;
            last_active_game_pid_ = processId;
          } else {
            is_match = false;
          }
        }
      } else {
        is_match = false;
      }
    } else {
      eval_tick_counter++;
    }

    auto now = std::chrono::steady_clock::now();
    bool target_gaming_mode = false;

    if (is_match) {
      if (!is_gaming_candidate_) {
        is_gaming_candidate_ = true;
        candidate_start_time_ = now;
      }

      auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                          now - candidate_start_time_)
                          .count();
      if (duration >= ENTRY_DELAY_MS || is_gaming_mode_) {
        last_gaming_match_time_ = now;
        target_gaming_mode = true;
      }
    } else {
      is_gaming_candidate_ = false;

      bool is_game_process_running = false;
      if (last_active_game_pid_ != 0) {
        ScopedHandle hProcess(OpenProcess(SYNCHRONIZE, FALSE, last_active_game_pid_));
        if (hProcess.is_valid()) {
          DWORD waitResult = WaitForSingleObject(hProcess.get(), 0);
          if (waitResult == WAIT_TIMEOUT) {
            is_game_process_running = true;
          }
        }
      }

      if (is_game_process_running) {
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                            now - last_gaming_match_time_)
                            .count();
        if (duration < exit_delay_ms_.load()) {
          target_gaming_mode = true;
        } else {
          target_gaming_mode = false;
        }
      } else {
        target_gaming_mode = false;
        last_active_game_pid_ = 0;
      }
    }

    bool gaming_changed = (target_gaming_mode != is_gaming_mode_);
    bool process_changed = false;
    {
      std::lock_guard<std::mutex> lock(focus_mutex_);
      if (active_process_name_ != current_active_process) {
        process_changed = true;
        active_process_name_ = current_active_process;
      }
    }

    if (gaming_changed || process_changed) {
      is_gaming_mode_ = target_gaming_mode;
      std::function<void(bool, const std::string&)> cb;
      {
        std::lock_guard<std::mutex> lock(focus_mutex_);
        cb = on_focus_and_gaming_changed_;
      }
      if (cb) {
        cb(is_gaming_mode_, current_active_process);
      }
    }

    // Fast polling tick (100ms) for high-responsiveness focus switching
    for (int i = 0; i < 2 && !stop_detector_; i++) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
  }
}

bool MonitorManager::IsWindowFullscreen(HWND hwnd) {
  if (!hwnd || IsIconic(hwnd))
    return false;

  HMONITOR hMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi = {sizeof(mi)};
  if (!GetMonitorInfoW(hMonitor, &mi))
    return false;

  RECT wr;
  if (!GetWindowRect(hwnd, &wr))
    return false;

  return (wr.left <= mi.rcMonitor.left + 1 && wr.top <= mi.rcMonitor.top + 1 &&
          wr.right >= mi.rcMonitor.right - 1 &&
          wr.bottom >= mi.rcMonitor.bottom - 1);
}

int MonitorManager::EvaluateGamingScore(HWND hwnd, DWORD processId) {
  if (!hwnd)
    return 0;

  // --- Early Exit: Class Check ---
  wchar_t className[256];
  if (GetClassNameW(hwnd, className, 256)) {
    std::wstring wsClassName(className);
    if (wsClassName == L"WorkerW" || wsClassName == L"Progman" ||
        wsClassName == L"Shell_TrayWnd" ||
        wsClassName == L"MultitaskingViewFrame" ||
        wsClassName == L"NotifyIconOverflowWindow" ||
        wsClassName == L"SimplePopupMenu" ||
        wsClassName == L"RainmeterMeterWindow") {
      return 0;
    }
  }

  std::string process_name_lower;
  int static_score = 0;
  bool is_cached = false;

  // 1. Thread-safe lookup in process_cache_
  {
    std::lock_guard<std::mutex> lock(lists_mutex_);
    auto cache_it = process_cache_.find(processId);
    if (cache_it != process_cache_.end() && cache_it->second.scanned) {
      process_name_lower = cache_it->second.process_name_lower;
      static_score = cache_it->second.static_score;
      is_cached = true;
    }
  }

  // 2. If not cached, inspect process outside lock (heavy Win32 API calls)
  if (!is_cached) {
    std::wstring fullPathLower;

    ScopedHandle hProcess(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId));
    if (hProcess.is_valid()) {
      wchar_t buffer[4096];
      DWORD size = 4096;
      if (QueryFullProcessImageNameW(hProcess.get(), 0, buffer, &size)) {
        fullPathLower = std::wstring(buffer, size);
        for (wchar_t& wc : fullPathLower) {
          wc = static_cast<wchar_t>(::towlower(wc));
        }

        size_t lastSlash = fullPathLower.find_last_of(L"\\/");
        std::wstring fileName = (lastSlash == std::wstring::npos)
                                    ? fullPathLower
                                    : fullPathLower.substr(lastSlash + 1);
        process_name_lower = WideToUtf8(fileName);
      }
    }

    // --- Path Heuristics ---
    if (!fullPathLower.empty()) {
      if (fullPathLower.find(L"\\steamapps\\common\\") != std::wstring::npos ||
          fullPathLower.find(L"\\epic games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\origin games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\gog galaxy\\games\\") != std::wstring::npos ||
          fullPathLower.find(L"\\xboxgames\\") != std::wstring::npos) {
        static_score += 100;
      }
      if (fullPathLower.find(L"c:\\windows\\") != std::wstring::npos) {
        static_score -= 200;
      }
    }

    // --- Parent Process Check ---
    std::string parentName = GetParentProcessName(processId);
    if (parentName == "steam.exe" || parentName == "epicgameslauncher.exe" ||
        parentName == "galaxyclient.exe" || parentName == "origin.exe") {
      static_score += 100;
    }

    // --- DLL Scanning (one-shot per PID) ---
    ScopedHandle hProcDll(OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                                  FALSE, processId));
    if (hProcDll.is_valid()) {
      HMODULE hMods[1024];
      DWORD cbNeeded;
      if (EnumProcessModules(hProcDll.get(), hMods, sizeof(hMods), &cbNeeded)) {
        for (unsigned int i = 0; i < (cbNeeded / sizeof(HMODULE)); i++) {
          wchar_t szModName[MAX_PATH];
          if (GetModuleBaseNameW(hProcDll.get(), hMods[i], szModName,
                                 sizeof(szModName) / sizeof(wchar_t))) {
            std::wstring modName(szModName);
            for (wchar_t& wc : modName) {
              wc = static_cast<wchar_t>(::towlower(wc));
            }

            if (modName.find(L"xinput") != std::wstring::npos)
              static_score += 60;
            if (modName == L"dinput8.dll")
              static_score += 50;
            if (modName.find(L"xaudio2") != std::wstring::npos)
              static_score += 30;
            if (modName == L"d3d11.dll" || modName == L"d3d12.dll" ||
                modName == L"vulkan-1.dll") {
              static_score += 10;
            }
          }
        }
      }
    }

    // Insert into cache under lock
    {
      std::lock_guard<std::mutex> lock(lists_mutex_);
      if (process_cache_.size() >= 64) {
        process_cache_.clear();
      }
      CachedProcessInfo info;
      info.static_score = static_score;
      info.process_name_lower = process_name_lower;
      info.scanned = true;
      process_cache_[processId] = std::move(info);
    }
  }

  // 3. Thread-safe Whitelist / Blacklist (Checked FIRST to allow custom app overrides)
  {
    std::lock_guard<std::mutex> lock(lists_mutex_);
    if (!process_name_lower.empty()) {
      if (IsAppInSet(process_name_lower, blacklist_))
        return -1000;
      if (IsAppInSet(process_name_lower, whitelist_))
        return 1000;
    }
  }

  // --- Size Check ---
  if (!IsWindowFullscreen(hwnd))
    return 0;

  HMONITOR hMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi = {sizeof(mi)};
  if (!GetMonitorInfoW(hMonitor, &mi))
    return 0;

  RECT wr;
  if (!GetWindowRect(hwnd, &wr))
    return 0;

  // --- Style Analysis ---
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  // Real games don't have systemic frames or captions in fullscreen.
  // If they have them, it's likely an app (Telegram viewer, etc)
  if ((style & WS_CAPTION) || (style & WS_THICKFRAME)) {
    return 0;
  }

  int score = static_score;

  // --- Cursor Behavior ---
  CURSORINFO ci = {sizeof(ci)};
  if (GetCursorInfo(&ci)) {
    if (!(ci.flags & CURSOR_SHOWING)) {
      score += 40; // Hidden cursor is very common in games
    }
  }

  RECT clipRect;
  if (GetClipCursor(&clipRect)) {
    // If the clip rect matches the window exactly or is significantly smaller
    // than monitor
    if (abs(clipRect.left - wr.left) < 5 && abs(clipRect.top - wr.top) < 5 &&
        abs(clipRect.right - wr.right) < 5 &&
        abs(clipRect.bottom - wr.bottom) < 5) {

      if ((clipRect.right - clipRect.left) <
          (mi.rcMonitor.right - mi.rcMonitor.left - 10)) {
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
              parentName += static_cast<char>(
                  std::tolower(static_cast<unsigned char>(wc)));
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
