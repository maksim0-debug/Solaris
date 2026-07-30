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
#include <physicalmonitorenumerationapi.h>

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

  // Synchronously resets color temperature to pure linear 6500K for ALL attached monitors.
  bool ResetAllMonitorsTemperatureSync();

  // Enqueues a task to be executed on the background worker thread.
  void EnqueueTask(std::function<void()> task);

  // Handles caching & invalidation of Win32 PHYSICAL_MONITOR handles
  void InvalidateMonitorHandles();
  void InvalidateMonitorHandlesDebounced(int delay_ms);

  // System & Hardware feedback callbacks
  void SetHardwareErrorCallback(std::function<void(const std::string&)> callback);

  // Game & Focus Detection
  void SetFocusAndGamingCallback(std::function<void(bool is_gaming, const std::string& active_process)> callback);
  void UpdateWhitelist(const std::vector<std::string>& whitelist);
  void UpdateBlacklist(const std::vector<std::string>& blacklist);
  void SetGameModeExitDelay(int delay_seconds);
  bool IsGamingMode() const { return is_gaming_mode_; }
  std::string GetActiveProcessName() const;

  // GUI Running Processes Enumeration
  std::vector<std::pair<std::string, std::string>> GetRunningProcesses();

 private:
  // Persistent Physical Monitor Handle Cache
  std::mutex handles_mutex_;
  std::map<std::string, std::vector<PHYSICAL_MONITOR>> physical_monitors_cache_;
  std::vector<PHYSICAL_MONITOR> GetOrCreatePhysicalMonitors(const std::string& device_path);
  void DestroyPhysicalMonitorsCache();

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

  // Hardware error feedback callback
  std::mutex error_cb_mutex_;
  std::function<void(const std::string&)> on_hardware_error_;

  // Game & Focus Detection state
  std::thread detector_thread_;
  std::atomic<bool> stop_detector_{false};
  std::atomic<bool> is_gaming_mode_{false};
  std::function<void(bool, const std::string&)> on_focus_and_gaming_changed_;

  mutable std::mutex focus_mutex_;
  std::string active_process_name_;
  
  std::mutex lists_mutex_;
  std::set<std::string> whitelist_;
  std::set<std::string> blacklist_;

  void DetectorLoop();
  int EvaluateGamingScore(HWND hwnd, DWORD processId);
  bool IsWindowFullscreen(HWND hwnd);
  std::string GetParentProcessName(DWORD processId);
  std::string ParseEdid(const std::vector<uint8_t>& edid);
  std::string GetManufacturerName(uint16_t manufacturer_id);

  // Hysteresis constants & state
  const int SCORE_THRESHOLD = 75;
  const int ENTRY_DELAY_MS = 500;
  std::atomic<int> exit_delay_ms_{30000};

  std::chrono::steady_clock::time_point last_gaming_match_time_;
  bool is_gaming_candidate_ = false;
  std::chrono::steady_clock::time_point candidate_start_time_;

  struct CachedProcessInfo {
    int static_score = 0;
    std::string process_name_lower;
    bool scanned = false;
  };
  std::unordered_map<DWORD, CachedProcessInfo> process_cache_;

  HWND active_game_hwnd_ = nullptr;
  DWORD active_game_pid_ = 0;
  DWORD last_active_game_pid_ = 0;
};

#endif  // RUNNER_MONITOR_MANAGER_H_
