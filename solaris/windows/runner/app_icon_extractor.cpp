#include "app_icon_extractor.h"

#include <psapi.h>
#include <tlhelp32.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <objbase.h>
#include <flutter/encodable_value.h>

#include <chrono>
#include <vector>
#include <list>
#include <cwctype>
#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <thread>
#include <mutex>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shlwapi.lib")

using namespace Gdiplus;

namespace {

// RAII wrapper for HICON
struct ScopedHicon {
  HICON icon = nullptr;
  explicit ScopedHicon(HICON h = nullptr) : icon(h) {}
  ~ScopedHicon() {
    if (icon) {
      DestroyIcon(icon);
    }
  }
  ScopedHicon(const ScopedHicon&) = delete;
  ScopedHicon& operator=(const ScopedHicon&) = delete;
  ScopedHicon(ScopedHicon&& other) noexcept : icon(other.icon) {
    other.icon = nullptr;
  }
  ScopedHicon& operator=(ScopedHicon&& other) noexcept {
    if (this != &other) {
      if (icon) DestroyIcon(icon);
      icon = other.icon;
      other.icon = nullptr;
    }
    return *this;
  }
  void reset(HICON h = nullptr) {
    if (icon) DestroyIcon(icon);
    icon = h;
  }
  HICON get() const { return icon; }
  HICON* put() {
    reset();
    return &icon;
  }
  explicit operator bool() const { return icon != nullptr; }
};

// RAII wrapper for HKEY
struct ScopedHkey {
  HKEY key = nullptr;
  explicit ScopedHkey(HKEY k = nullptr) : key(k) {}
  ~ScopedHkey() {
    if (key) {
      RegCloseKey(key);
    }
  }
  ScopedHkey(const ScopedHkey&) = delete;
  ScopedHkey& operator=(const ScopedHkey&) = delete;
  ScopedHkey(ScopedHkey&& other) noexcept : key(other.key) {
    other.key = nullptr;
  }
  ScopedHkey& operator=(ScopedHkey&& other) noexcept {
    if (this != &other) {
      if (key) RegCloseKey(key);
      key = other.key;
      other.key = nullptr;
    }
    return *this;
  }
  void reset(HKEY k = nullptr) {
    if (key) RegCloseKey(key);
    key = k;
  }
  HKEY get() const { return key; }
  HKEY* put() {
    reset();
    return &key;
  }
  explicit operator bool() const { return key != nullptr; }
};

template <typename K, typename V, size_t MaxCapacity = 512>
class BoundedLruCache {
public:
  bool Get(const K& key, V& out_value) {
    auto it = map_.find(key);
    if (it == map_.end()) return false;
    order_.erase(it->second.second);
    order_.push_front(key);
    it->second.second = order_.begin();
    out_value = it->second.first;
    return true;
  }

  void Put(const K& key, const V& value) {
    auto it = map_.find(key);
    if (it != map_.end()) {
      order_.erase(it->second.second);
    } else if (map_.size() >= MaxCapacity) {
      const K oldest = order_.back();
      order_.pop_back();
      map_.erase(oldest);
    }
    order_.push_front(key);
    map_[key] = {value, order_.begin()};
  }

  bool Contains(const K& key) const {
    return map_.find(key) != map_.end();
  }

private:
  std::list<K> order_;
  std::unordered_map<K, std::pair<V, typename std::list<K>::iterator>> map_;
};



std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                        static_cast<int>(wide.size()),
                                        nullptr, 0, nullptr, nullptr);
  if (size_needed <= 0) return {};
  std::string result(size_needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                      static_cast<int>(wide.size()),
                      &result[0], size_needed, nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                        static_cast<int>(utf8.size()),
                                        nullptr, 0);
  if (size_needed <= 0) return {};
  std::wstring result(size_needed, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                      static_cast<int>(utf8.size()),
                      &result[0], size_needed);
  return result;
}

std::wstring SanitizeIconPath(std::wstring path) {
  if (path.empty()) return path;

  auto trimQuotesAndSpaces = [](std::wstring& s) {
    while (!s.empty() && (s.front() == L' ' || s.front() == L'"' || s.front() == L'\'')) {
      s.erase(0, 1);
    }
    while (!s.empty() && (s.back() == L' ' || s.back() == L'"' || s.back() == L'\'')) {
      s.pop_back();
    }
  };

  // 1. If path starts with a quote, extract the exact quoted substring
  if (path.front() == L'"') {
    auto secondQuote = path.find(L'"', 1);
    if (secondQuote != std::wstring::npos) {
      path = path.substr(1, secondQuote - 1);
    }
  }

  // 2. Strip comma and icon index if present (e.g. "path.exe",0 or path.exe, -1)
  auto commaPos = path.find_last_of(L",");
  if (commaPos != std::wstring::npos) {
    bool isIconIndex = true;
    for (size_t k = commaPos + 1; k < path.size(); ++k) {
      if (!std::iswdigit(path[k]) && path[k] != L'-' && path[k] != L' ' && path[k] != L'"') {
        isIconIndex = false;
        break;
      }
    }
    if (isIconIndex) {
      path = path.substr(0, commaPos);
    }
  }

  // 3. Trim all remaining leading and trailing quotes or whitespaces
  trimQuotesAndSpaces(path);

  // 4. Expand environment variables (e.g. %ProgramFiles%, %LocalAppData%, %SystemRoot%)
  if (path.find(L'%') != std::wstring::npos) {
    DWORD reqSize = ExpandEnvironmentStringsW(path.c_str(), nullptr, 0);
    if (reqSize > 0) {
      std::vector<wchar_t> buffer(reqSize);
      if (ExpandEnvironmentStringsW(path.c_str(), buffer.data(), reqSize) > 0) {
        path = buffer.data();
      }
    }
    trimQuotesAndSpaces(path);
  }

  return path;
}

std::wstring ReadRegistryStringValue(HKEY hKey, const wchar_t* valueName = nullptr) {
  DWORD type = 0;
  DWORD bytes = 0;
  if (RegQueryValueExW(hKey, valueName, NULL, &type, NULL, &bytes) == ERROR_SUCCESS && bytes > 0) {
    if (type != REG_SZ && type != REG_EXPAND_SZ) {
      return L"";
    }
    std::vector<wchar_t> buffer(bytes / sizeof(wchar_t) + 1, L'\0');
    if (RegQueryValueExW(hKey, valueName, NULL, &type, reinterpret_cast<LPBYTE>(buffer.data()), &bytes) == ERROR_SUCCESS) {
      buffer.back() = L'\0';
      return std::wstring(buffer.data());
    }
  }
  return L"";
}

std::wstring FindAppPathInRegistry(const std::wstring& exeName) {
  std::wstring subkey = L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\" + exeName;
  auto queryAppPath = [&](HKEY root, REGSAM extraSam = 0) -> std::wstring {
    ScopedHkey hKey;
    if (RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ | extraSam, hKey.put()) == ERROR_SUCCESS) {
      std::wstring rawPath = ReadRegistryStringValue(hKey.get(), NULL);
      if (!rawPath.empty()) {
        return SanitizeIconPath(rawPath);
      }
    }
    return L"";
  };

  std::wstring path = queryAppPath(HKEY_CURRENT_USER);
  if (!path.empty()) return path;

  path = queryAppPath(HKEY_LOCAL_MACHINE);
  if (!path.empty()) return path;

  return queryAppPath(HKEY_LOCAL_MACHINE, KEY_WOW64_32KEY);
}

// ---------------------------------------------------------------------------
// Uninstall Registry Caching (Thread-Safe O(1) lookups of installed apps)
// ---------------------------------------------------------------------------
std::mutex g_populateMutex;
std::mutex g_uninstallMutex;
std::unordered_map<std::wstring, std::wstring> g_uninstallCache;
std::vector<std::wstring> g_installLocations;
std::atomic<bool> g_uninstallCachePopulated{false};

void PopulateUninstallCache() {
  if (g_uninstallCachePopulated.load(std::memory_order_acquire)) return;

  std::lock_guard<std::mutex> popLock(g_populateMutex);
  if (g_uninstallCachePopulated.load(std::memory_order_relaxed)) return;

  std::unordered_map<std::wstring, std::wstring> localCache;
  std::vector<std::wstring> localLocations;

  auto scanUninstall = [&](HKEY hRootKey, const std::wstring& subKey) {
    ScopedHkey hUninstallKey;
    if (RegOpenKeyExW(hRootKey, subKey.c_str(), 0, KEY_READ, hUninstallKey.put()) != ERROR_SUCCESS) {
      return;
    }

    DWORD subKeysCount = 0;
    DWORD maxSubKeyLen = 0;
    if (RegQueryInfoKeyW(hUninstallKey.get(), NULL, NULL, NULL, &subKeysCount, &maxSubKeyLen, NULL, NULL, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) {
      return;
    }

    std::vector<wchar_t> subKeyName(maxSubKeyLen + 1);
    for (DWORD i = 0; i < subKeysCount; ++i) {
      DWORD nameLen = maxSubKeyLen + 1;
      if (RegEnumKeyExW(hUninstallKey.get(), i, subKeyName.data(), &nameLen, NULL, NULL, NULL, NULL) == ERROR_SUCCESS) {
        ScopedHkey hAppKey;
        std::wstring appSubKey = subKey + L"\\" + subKeyName.data();
        if (RegOpenKeyExW(hRootKey, appSubKey.c_str(), 0, KEY_READ, hAppKey.put()) == ERROR_SUCCESS) {
          
          // 1. Read DisplayIcon (Direct path to EXE or icon resource)
          std::wstring rawDisplayIcon = ReadRegistryStringValue(hAppKey.get(), L"DisplayIcon");
          if (!rawDisplayIcon.empty()) {
            std::wstring cleanPath = SanitizeIconPath(rawDisplayIcon);
            if (!cleanPath.empty() && GetFileAttributesW(cleanPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
              auto slashPos = cleanPath.find_last_of(L"\\/");
              std::wstring exeName = (slashPos == std::wstring::npos) ? cleanPath : cleanPath.substr(slashPos + 1);
              if (!exeName.empty()) {
                std::wstring lowerExe = exeName;
                std::transform(lowerExe.begin(), lowerExe.end(), lowerExe.begin(), ::towlower);
                if (localCache.find(lowerExe) == localCache.end()) {
                  localCache[lowerExe] = cleanPath;
                }
              }
            }
          }

          // 2. Read InstallLocation (App installation directory)
          std::wstring locPath = ReadRegistryStringValue(hAppKey.get(), L"InstallLocation");
          if (!locPath.empty()) {
            while (!locPath.empty() && (locPath.front() == L' ' || locPath.front() == L'"')) {
              locPath.erase(0, 1);
            }
            while (!locPath.empty() && (locPath.back() == L' ' || locPath.back() == L'"')) {
              locPath.pop_back();
            }
            if (!locPath.empty()) {
              if (locPath.back() != L'\\' && locPath.back() != L'/') {
                locPath += L"\\";
              }
              if (std::find(localLocations.begin(), localLocations.end(), locPath) == localLocations.end()) {
                localLocations.push_back(locPath);
              }
            }
          }
        }
      }
    }
  };

  scanUninstall(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall");
  scanUninstall(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall");
  scanUninstall(HKEY_CURRENT_USER, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall");

  {
    std::lock_guard<std::mutex> dataLock(g_uninstallMutex);
    g_uninstallCache = std::move(localCache);
    g_installLocations = std::move(localLocations);
  }
  g_uninstallCachePopulated.store(true, std::memory_order_release);
}

std::mutex g_lruMutex;
BoundedLruCache<std::wstring, std::wstring, 512> g_locatedCache;

std::wstring LocateExecutable(const std::wstring& rawExeName) {
  if (rawExeName.empty()) {
    return L"";
  }

  std::wstring exeName = rawExeName;
  std::wstring lower = exeName;
  std::transform(lower.begin(), lower.end(), lower.begin(), ::towlower);
  if (lower.size() < 4 || lower.rfind(L".exe") != lower.size() - 4) {
    exeName += L".exe";
    lower += L".exe";
  }

  const std::wstring& lowerExeName = lower;

  // 1. Check fast LRU cache FIRST under mutex protection (O(1) hit before any heavy OS snapshot)
  {
    std::lock_guard<std::mutex> lock(g_lruMutex);
    std::wstring cachedPath;
    if (g_locatedCache.Get(lowerExeName, cachedPath)) {
      if (cachedPath.empty()) {
        return L"";
      }
      if (GetFileAttributesW(cachedPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
        return cachedPath;
      }
    }
  }

  auto recordSuccess = [&](const std::wstring& path) {
    std::lock_guard<std::mutex> lock(g_lruMutex);
    g_locatedCache.Put(lowerExeName, path);
    return path;
  };

  // 2. Search in live running processes (Snapshot via Toolhelp32 only on cache miss)
  HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    if (Process32FirstW(hSnapshot, &pe32)) {
      do {
        if (_wcsicmp(pe32.szExeFile, exeName.c_str()) == 0) {
          HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pe32.th32ProcessID);
          if (hProc) {
            wchar_t procPath[MAX_PATH] = {0};
            DWORD size = MAX_PATH;
            if (QueryFullProcessImageNameW(hProc, 0, procPath, &size)) {
              CloseHandle(hProc);
              CloseHandle(hSnapshot);
              return recordSuccess(procPath);
            }
            CloseHandle(hProc);
          }
        }
      } while (Process32NextW(hSnapshot, &pe32));
    }
    CloseHandle(hSnapshot);
  }

  // 2. Search in Registry App Paths (HKCU & HKLM - Fast O(1) registry check)
  std::wstring registryPath = FindAppPathInRegistry(exeName);
  if (!registryPath.empty()) {
    if (GetFileAttributesW(registryPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
      return recordSuccess(registryPath);
    }
  }

  // 3. Search in standard Windows user & system application directories
  const std::vector<std::wstring> systemLookupPaths = {
    L"%LocalAppData%\\Microsoft\\WindowsApps\\" + exeName,
    L"%SystemRoot%\\System32\\" + exeName,
    L"%SystemRoot%\\" + exeName
  };

  for (const auto& pathPattern : systemLookupPaths) {
    wchar_t expanded[MAX_PATH] = {};
    ExpandEnvironmentStringsW(pathPattern.c_str(), expanded, MAX_PATH);
    if (GetFileAttributesW(expanded) != INVALID_FILE_ATTRIBUTES) {
      return recordSuccess(expanded);
    }
  }

  // 4. Search in System Path
  wchar_t buffer[MAX_PATH] = {};
  wchar_t* filePart = nullptr;
  DWORD searchResult = SearchPathW(NULL, exeName.c_str(), NULL, MAX_PATH, buffer, &filePart);
  if (searchResult > 0 && searchResult < MAX_PATH) {
    if (GetFileAttributesW(buffer) != INVALID_FILE_ATTRIBUTES) {
      return recordSuccess(buffer);
    }
  }

  // Populate Registry Uninstall cache if not done yet
  PopulateUninstallCache();

  // 5. Search in cached Uninstall DisplayIcons (O(1) lookup under mutex)
  std::wstring cachedDisplayIcon;
  std::vector<std::wstring> installLocationsCopy;
  {
    std::lock_guard<std::mutex> lock(g_uninstallMutex);
    auto it = g_uninstallCache.find(lowerExeName);
    if (it != g_uninstallCache.end()) {
      cachedDisplayIcon = it->second;
    }
    installLocationsCopy = g_installLocations;
  }

  if (!cachedDisplayIcon.empty()) {
    if (GetFileAttributesW(cachedDisplayIcon.c_str()) != INVALID_FILE_ATTRIBUTES) {
      return recordSuccess(cachedDisplayIcon);
    }
  }

  // 6. Search by combining cached InstallLocations with the EXE name
  for (const auto& loc : installLocationsCopy) {
    // 6.1. Direct check in install directory
    std::wstring fullPath = loc + exeName;
    if (GetFileAttributesW(fullPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
      {
        std::lock_guard<std::mutex> lock(g_uninstallMutex);
        g_uninstallCache[lowerExeName] = fullPath;
      }
      return recordSuccess(fullPath);
    }

    // 6.2. Generic Squirrel / Electron check: versioned subfolder (e.g. loc + app-*\ + exeName)
    // Works for any app using Squirrel (Discord, Slack, Figma, Teams, Postman, etc.) without hardcoding
    std::wstring pattern = loc + L"app-*";
    WIN32_FIND_DATAW fd;
    HANDLE hF = FindFirstFileW(pattern.c_str(), &fd);
    if (hF != INVALID_HANDLE_VALUE) {
      do {
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
          std::wstring subPath = loc + fd.cFileName + L"\\" + exeName;
          if (GetFileAttributesW(subPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
            FindClose(hF);
            {
              std::lock_guard<std::mutex> lock(g_uninstallMutex);
              g_uninstallCache[lowerExeName] = subPath;
            }
            return recordSuccess(subPath);
          }
        }
      } while (FindNextFileW(hF, &fd));
      FindClose(hF);
    }
  }

  // 7. Search in Windows SystemApps (Last-resort folder traversal)
  wchar_t winDir[MAX_PATH] = {};
  GetWindowsDirectoryW(winDir, MAX_PATH);
  std::wstring systemAppsPattern = std::wstring(winDir) + L"\\SystemApps\\*";
  WIN32_FIND_DATAW findData;
  HANDLE hFind = FindFirstFileW(systemAppsPattern.c_str(), &findData);
  if (hFind != INVALID_HANDLE_VALUE) {
    do {
      if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        if (wcscmp(findData.cFileName, L".") != 0 && wcscmp(findData.cFileName, L"..") != 0) {
          std::wstring candidatePath = std::wstring(winDir) + L"\\SystemApps\\" + findData.cFileName + L"\\" + exeName;
          if (GetFileAttributesW(candidatePath.c_str()) != INVALID_FILE_ATTRIBUTES) {
            FindClose(hFind);
            return recordSuccess(candidatePath);
          }
        }
      }
    } while (FindNextFileW(hFind, &findData));
    FindClose(hFind);
  }

  {
    std::lock_guard<std::mutex> lock(g_lruMutex);
    g_locatedCache.Put(lowerExeName, L"");
  }

  return L"";
}

}  // namespace

// ---------------------------------------------------------------------------
// Construction & Destruction
// ---------------------------------------------------------------------------

AppIconExtractor::AppIconExtractor(flutter::FlutterEngine* engine, HWND window_hwnd)
    : engine_(engine), window_hwnd_(window_hwnd), gdiplusToken_(0),
      state_(std::make_shared<ExtractorSharedState>()) {
  // Initialize GDI+
  GdiplusStartupInput gdiplusStartupInput;
  GdiplusStartup(&gdiplusToken_, &gdiplusStartupInput, NULL);

  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine_->messenger(), "com.solaris.monitor/icons",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "extractAppIcon") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto exe_it = args->find(flutter::EncodableValue("exePath"));
            auto save_it = args->find(flutter::EncodableValue("savePath"));
            if (exe_it != args->end() && save_it != args->end()) {
              const auto* pExe = std::get_if<std::string>(&exe_it->second);
              const auto* pSave = std::get_if<std::string>(&save_it->second);
              if (pExe && pSave) {
                if (state_->is_shutting_down.load()) {
                  result->Error("SHUTTING_DOWN", "Extractor is shutting down");
                  return;
                }
                // Execute asynchronously via Windows ThreadPool to prevent raw thread accumulation
                struct IconExtractionContext {
                  std::shared_ptr<ExtractorSharedState> state;
                  std::string exe_path;
                  std::string save_path;
                  HWND window_hwnd;
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> res;
                };

                auto* ctx = new IconExtractionContext{
                    state_,
                    *pExe,
                    *pSave,
                    window_hwnd_,
                    std::move(result)
                };

                state_->active_tasks++;
                BOOL queued = QueueUserWorkItem(
                    [](LPVOID param) -> DWORD {
                      auto* ctx = reinterpret_cast<IconExtractionContext*>(param);
                      HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
                      bool co_initialized = SUCCEEDED(hr);

                      try {
                        std::wstring resolvedPath;
                        bool success = false;
                        if (!ctx->state->is_shutting_down.load()) {
                          success = SaveIconToFile(Utf8ToWide(ctx->exe_path), Utf8ToWide(ctx->save_path), resolvedPath);
                        }

                        if (!ctx->state->is_shutting_down.load()) {
                          std::string utf8ResolvedPath = WideToUtf8(resolvedPath);
                          auto* data = new (std::nothrow) IconResultData{
                              std::move(ctx->res),
                              std::move(utf8ResolvedPath),
                              success
                          };

                          if (data) {
                            if (!PostMessage(ctx->window_hwnd, WM_SOLARIS_ICON_RESULT, 0, reinterpret_cast<LPARAM>(data))) {
                              delete data;
                            }
                          } else if (ctx->res) {
                            throw std::bad_alloc();
                          }
                        }
                      } catch (...) {
                        // Prevent uncaught C++ exceptions from terminating the thread pool thread
                        if (!ctx->state->is_shutting_down.load() && ctx->res) {
                          auto* data = new (std::nothrow) IconResultData{
                              std::move(ctx->res),
                              "",
                              false
                          };
                          if (data) {
                            if (!PostMessage(ctx->window_hwnd, WM_SOLARIS_ICON_RESULT, 0, reinterpret_cast<LPARAM>(data))) {
                              delete data;
                            }
                          }
                        }
                      }

                      if (co_initialized) {
                        CoUninitialize();
                      }

                      ctx->state->active_tasks--;
                      delete ctx;
                      return 0;
                    },
                    ctx,
                    WT_EXECUTEDEFAULT);

                if (!queued) {
                  state_->active_tasks--;
                  ctx->res->Error("QUEUE_FAILED", "Failed to queue icon extraction work item");
                  delete ctx;
                }
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENTS", "Missing or invalid exePath or savePath");
        } else {
          result->NotImplemented();
        }
      });
}

AppIconExtractor::~AppIconExtractor() {
  if (method_channel_) {
    method_channel_->SetMethodCallHandler(nullptr);
  }
  state_->is_shutting_down.store(true);
  int wait_count = 0;
  while (state_->active_tasks.load() > 0 && wait_count < 200) {
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    wait_count++;
  }
  if (state_->active_tasks.load() == 0 && gdiplusToken_) {
    GdiplusShutdown(gdiplusToken_);
    gdiplusToken_ = 0;
  }
}

void AppIconExtractor::HandleResult(IconResultData* data) {
  if (!data) return;
  if (data->result) {
    if (data->success) {
      data->result->Success(flutter::EncodableValue(data->resolved_path));
    } else {
      data->result->Success(flutter::EncodableValue(""));
    }
  }
  delete data;
}

// ---------------------------------------------------------------------------
// Icon Extraction (GDI+)
// ---------------------------------------------------------------------------

int AppIconExtractor::GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  // Zero-allocation fast-path for PNG encoder
  if (wcscmp(format, L"image/png") == 0) {
    static const CLSID kPngClsid = {0x557cf406, 0x1a04, 0x11d3, {0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e}};
    *pClsid = kPngClsid;
    return 0;
  }

  UINT num = 0, size = 0;
  GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;

  std::vector<BYTE> buffer(size);
  ImageCodecInfo* pImageCodecInfo = reinterpret_cast<ImageCodecInfo*>(buffer.data());

  GetImageEncoders(num, size, pImageCodecInfo);
  for (UINT j = 0; j < num; ++j) {
    if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
      *pClsid = pImageCodecInfo[j].Clsid;
      return j;
    }
  }
  return -1;
}

bool AppIconExtractor::SaveIconToFile(const std::wstring& exePath, const std::wstring& savePath, std::wstring& resolvedPath) {
  resolvedPath = SanitizeIconPath(exePath);
  if (GetFileAttributesW(resolvedPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
    auto pos = resolvedPath.find_last_of(L"\\/");
    std::wstring exeName = (pos == std::wstring::npos) ? resolvedPath : resolvedPath.substr(pos + 1);
    std::wstring located = LocateExecutable(exeName);
    if (!located.empty()) {
      resolvedPath = located;
    } else {
      return false;
    }
  }

  ScopedHicon hIcon;
  UINT iconId = 0;

  // 1. Try to extract high-res icon (128x128 provides crisp detail for blur & downscaling)
  UINT extracted = PrivateExtractIconsW(resolvedPath.c_str(), 0, 128, 128, hIcon.put(), &iconId, 1, 0);
  if (extracted == 0 || extracted == 0xFFFFFFFF || !hIcon.get()) {
    hIcon.reset();
  }

  if (!hIcon) {
    // 2. Fallback: try standard Large size (32x32 / 48x48)
    if (ExtractIconExW(resolvedPath.c_str(), 0, hIcon.put(), NULL, 1) <= 0 || !hIcon.get()) {
      hIcon.reset();
    }
  }

  if (!hIcon) {
    // 3. Fallback: Shell File Info Large
    SHFILEINFOW sfi = {0};
    if (SHGetFileInfoW(resolvedPath.c_str(), 0, &sfi, sizeof(sfi), SHGFI_ICON | SHGFI_LARGEICON)) {
      hIcon.reset(sfi.hIcon);
    } else if (SHGetFileInfoW(resolvedPath.c_str(), 0, &sfi, sizeof(sfi), SHGFI_ICON | SHGFI_SMALLICON)) {
      hIcon.reset(sfi.hIcon);
    }
  }

  if (!hIcon) return false;

  // Convert HICON to GDI+ Bitmap with full 32-bit ARGB alpha channel preservation (no black square artifacts)
  std::unique_ptr<Bitmap> bitmap;

  ICONINFOEXW ii = { sizeof(ii) };
  if (GetIconInfoExW(hIcon.get(), &ii)) {
    BITMAP bmColor = { 0 };
    if (ii.hbmColor && GetObject(ii.hbmColor, sizeof(bmColor), &bmColor) > 0) {
      if (bmColor.bmBitsPixel == 32 && bmColor.bmWidth > 0 && bmColor.bmHeight > 0) {
        HDC hDC = GetDC(NULL);
        BITMAPINFO bmi = { 0 };
        bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth = bmColor.bmWidth;
        bmi.bmiHeader.biHeight = -bmColor.bmHeight; // top-down orientation
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 32;
        bmi.bmiHeader.biCompression = BI_RGB;

        std::vector<DWORD> pixels(bmColor.bmWidth * bmColor.bmHeight);
        if (GetDIBits(hDC, ii.hbmColor, 0, bmColor.bmHeight, pixels.data(), &bmi, DIB_RGB_COLORS) > 0) {
          ReleaseDC(NULL, hDC);

          bool hasAlpha = false;
          for (DWORD p : pixels) {
            if ((p & 0xFF000000) != 0) {
              hasAlpha = true;
              break;
            }
          }

          // If icon lacked a valid 32-bit alpha channel, reconstruct alpha from the 1-bit mask
          if (!hasAlpha && ii.hbmMask) {
            HDC hMaskDC = GetDC(NULL);
            std::vector<DWORD> maskPixels(bmColor.bmWidth * bmColor.bmHeight);
            if (GetDIBits(hMaskDC, ii.hbmMask, 0, bmColor.bmHeight, maskPixels.data(), &bmi, DIB_RGB_COLORS) > 0) {
              for (size_t i = 0; i < pixels.size(); ++i) {
                if ((maskPixels[i] & 0x00FFFFFF) == 0) {
                  pixels[i] |= 0xFF000000;
                } else {
                  pixels[i] = 0x00000000;
                }
              }
            }
            ReleaseDC(NULL, hMaskDC);
          }

          bitmap = std::make_unique<Bitmap>(bmColor.bmWidth, bmColor.bmHeight, PixelFormat32bppARGB);
          BitmapData bmpData;
          Rect rect(0, 0, bmColor.bmWidth, bmColor.bmHeight);
          if (bitmap->LockBits(&rect, ImageLockModeWrite, PixelFormat32bppARGB, &bmpData) == Ok) {
            const int rowBytes = bmColor.bmWidth * sizeof(DWORD);
            const auto* src = reinterpret_cast<const BYTE*>(pixels.data());
            auto* dst = reinterpret_cast<BYTE*>(bmpData.Scan0);
            for (int y = 0; y < bmColor.bmHeight; ++y) {
              memcpy(dst + y * bmpData.Stride, src + y * rowBytes, rowBytes);
            }
            bitmap->UnlockBits(&bmpData);
          }
        } else {
          ReleaseDC(NULL, hDC);
        }
      }
    }

    if (ii.hbmColor) DeleteObject(ii.hbmColor);
    if (ii.hbmMask) DeleteObject(ii.hbmMask);
  }

  // Fallback for legacy 16/256-color icons or if direct 32bpp extraction failed
  if (!bitmap) {
    bitmap.reset(Bitmap::FromHICON(hIcon.get()));
  }

  if (bitmap && bitmap->GetLastStatus() == Ok) {
    CLSID pngClsid;
    if (GetEncoderClsid(L"image/png", &pngClsid) >= 0) {
      Status stat = bitmap->Save(savePath.c_str(), &pngClsid, NULL);
      if (stat != Ok) {
        DeleteFileW(savePath.c_str());
        return false;
      }
      return true;
    }
  }

  return false;
}
