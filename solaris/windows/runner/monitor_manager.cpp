#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "monitor_manager.h"

#include <iostream>
#include <initguid.h>
#include <setupapi.h>
#include <devguid.h>
#include <ntddvdeo.h>
#include <cfgmgr32.h>
#include <algorithm>
#include <cctype>
#include <highlevelmonitorconfigurationapi.h>
#include <physicalmonitorenumerationapi.h>

#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "dxva2.lib")

// GUID_DEVINTERFACE_MONITOR is usually {E6F07B5F-EE97-4a90-B076-33F57BF4EAA7}
DEFINE_GUID(GUID_DEVINTERFACE_MONITOR_INTERNAL, 0xE6F07B5F, 0xEE97, 0x4a90, 0xB0, 0x76, 0x33, 0xF5, 0x7B, 0xF4, 0xEA, 0xA7);

MonitorManager::MonitorManager() {}
MonitorManager::~MonitorManager() {}

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
    SetupDiGetDeviceInterfaceDetail(dev_info, &interface_data, nullptr, 0, &detail_size, nullptr);

    std::vector<uint8_t> detail_buffer(detail_size);
    auto detail_data = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA>(detail_buffer.data());
    detail_data->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

    if (SetupDiGetDeviceInterfaceDetail(dev_info, &interface_data, detail_data, detail_size, nullptr, &device_data)) {
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
