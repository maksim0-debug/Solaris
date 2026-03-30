#ifndef RUNNER_MONITOR_MANAGER_H_
#define RUNNER_MONITOR_MANAGER_H_

#include <map>
#include <string>
#include <vector>
#include <windows.h>
#include <mutex>
#include <thread>
#include <queue>
#include <condition_variable>
#include <functional>
#include <atomic>

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

  // Sets the color temperature (in Kelvin) of the monitor relative to original gamma.
  bool SetTemperature(const std::string& device_path, int kelvins);

  // Resets monitor gamma ramp to cached original (or linear neutral fallback).
  bool ResetTemperature(const std::string& device_path);

  // Enqueues a task to be executed on the background worker thread.
  void EnqueueTask(std::function<void()> task);

 private:
  // Caches the original gamma ramps for displays.
  std::map<std::string, std::vector<WORD>> original_gamma_ramps_;
  std::mutex gamma_mutex_;

  // Background worker state
  std::thread worker_thread_;
  std::queue<std::function<void()>> task_queue_;
  std::mutex queue_mutex_;
  std::condition_variable condition_;
  std::atomic<bool> stop_worker_{false};

  void WorkerLoop();

  std::string ParseEdid(const std::vector<uint8_t>& edid);
  std::string GetManufacturerName(uint16_t manufacturer_id);
};

#endif  // RUNNER_MONITOR_MANAGER_H_
