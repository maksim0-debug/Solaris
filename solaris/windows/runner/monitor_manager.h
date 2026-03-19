#ifndef RUNNER_MONITOR_MANAGER_H_
#define RUNNER_MONITOR_MANAGER_H_

#include <map>
#include <string>
#include <vector>
#include <windows.h>

class MonitorManager {
 public:
  MonitorManager();
  virtual ~MonitorManager();

  // Returns a map of DevicePath (from EnumDisplayDevices) to Friendly Name.
  std::map<std::string, std::string> GetMonitorFriendlyNames();

  // Sets the brightness of a monitor given its device path (e.g., \\.\DISPLAY1).
  bool SetBrightness(const std::string& device_path, int brightness);

  // Gets the current and maximum brightness of a monitor given its device path.
  bool GetBrightness(const std::string& device_path, int& current, int& maximum);

 private:
  std::string ParseEdid(const std::vector<uint8_t>& edid);
  std::string GetManufacturerName(uint16_t manufacturer_id);
};

#endif  // RUNNER_MONITOR_MANAGER_H_
