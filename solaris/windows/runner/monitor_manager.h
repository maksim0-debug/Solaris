#ifndef RUNNER_MONITOR_MANAGER_H_
#define RUNNER_MONITOR_MANAGER_H_

#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>
#include <windows.h>
#include <mutex>
#include <thread>
#include <queue>
#include <condition_variable>
#include <functional>
#include <atomic>
#include <shellapi.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <chrono>

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

  // Game Detection
  void SetGamingModeCallback(std::function<void(bool)> callback);
  void UpdateWhitelist(const std::vector<std::string>& whitelist);
  void UpdateBlacklist(const std::vector<std::string>& blacklist);
  bool IsGamingMode() const { return is_gaming_mode_; }

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

  // Game Detection state
  std::thread detector_thread_;
  std::atomic<bool> stop_detector_{false};
  std::atomic<bool> is_gaming_mode_{false};
  std::function<void(bool)> on_gaming_mode_changed_;
  
  std::mutex lists_mutex_;
  std::set<std::string> whitelist_;
  std::set<std::string> blacklist_;

  void DetectorLoop();
  int EvaluateGamingScore(HWND hwnd, DWORD processId);
  std::string GetParentProcessName(DWORD processId);
  std::string ParseEdid(const std::vector<uint8_t>& edid);
  std::string GetManufacturerName(uint16_t manufacturer_id);

  // Hysteresis constants & state
  const int SCORE_THRESHOLD = 75;
  const int ENTRY_DELAY_MS = 500;
  const int EXIT_DELAY_MS = 3000;

  std::chrono::steady_clock::time_point last_gaming_match_time_;
  bool is_gaming_candidate_ = false;
  std::chrono::steady_clock::time_point candidate_start_time_;

  // Per-PID cache of the expensive parts of EvaluateGamingScore (path, parent,
  // loaded DLLs). These are stable for a process lifetime, so we only compute
  // them once per PID and reuse on subsequent detector ticks.
  struct CachedProcessInfo {
    int static_score = 0;            // path + parent-process + DLL scan
    std::string process_name_lower;  // lowercase file name (for whitelist/blacklist)
    bool scanned = false;
  };
  std::unordered_map<DWORD, CachedProcessInfo> process_cache_;
};

#endif  // RUNNER_MONITOR_MANAGER_H_
