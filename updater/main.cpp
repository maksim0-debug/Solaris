#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <shldisp.h>
#include <exdisp.h>
#include <shlguid.h>

#ifndef SWDI_CALLBACK
#define SWDI_CALLBACK 1
#endif

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <filesystem>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <map>

#include "miniz.h"

namespace fs = std::filesystem;

// Global settings
struct Config {
    DWORD pid = 0;
    fs::path zipPath;
    fs::path targetDir;
    fs::path exeName = L"solaris.exe";
    fs::path backupDir;
};

// Log helper
class Logger {
public:
    static void Init() {
        PWSTR localAppDataPath = NULL;
        if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, NULL, &localAppDataPath))) {
            fs::path dir = fs::path(localAppDataPath) / L"Solaris";
            CoTaskMemFree(localAppDataPath);
            std::error_code ec;
            fs::create_directories(dir, ec);
            s_logPath = dir / L"update.log";
        } else {
            s_logPath = L"update.log";
        }
    }

    static std::string GetISO8601Timestamp() {
        auto now = std::chrono::system_clock::now();
        auto in_time_t = std::chrono::system_clock::to_time_t(now);
        std::tm tm_buf;
        gmtime_s(&tm_buf, &in_time_t);
        std::ostringstream ss;
        ss << std::put_time(&tm_buf, "%Y-%m-%dT%H:%M:%SZ");
        return ss.str();
    }

    static void Log(const std::string& level, const std::string& message) {
        if (s_logPath.empty()) Init();
        std::ofstream logFile(s_logPath, std::ios::app);
        if (logFile.is_open()) {
            logFile << "[" << GetISO8601Timestamp() << "] [" << level << "] " << message << "\n";
            logFile.flush();
        }
    }

    static void LogJsonResult(const std::string& status, const std::string& reason = "") {
        if (s_logPath.empty()) Init();
        std::ofstream logFile(s_logPath, std::ios::app);
        if (logFile.is_open()) {
            logFile << "{\n";
            logFile << "  \"status\": \"" << status << "\",\n";
            logFile << "  \"timestamp\": \"" << GetISO8601Timestamp() << "\"";
            if (!reason.empty()) {
                logFile << ",\n  \"reason\": \"" << reason << "\"";
            }
            logFile << "\n}\n";
            logFile.flush();
        }
    }

private:
    static fs::path s_logPath;
};

fs::path Logger::s_logPath;

// Privileges & Process Elevation Helpers
bool EnablePrivilege(LPCWSTR privilegeName) {
    HANDLE hToken = NULL;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        return false;
    }
    TOKEN_PRIVILEGES tp;
    LUID luid;
    if (!LookupPrivilegeValueW(NULL, privilegeName, &luid)) {
        CloseHandle(hToken);
        return false;
    }
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Luid = luid;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    BOOL res = AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(TOKEN_PRIVILEGES), NULL, NULL);
    DWORD err = GetLastError();
    CloseHandle(hToken);
    return res && (err != ERROR_NOT_ALL_ASSIGNED);
}

bool IsElevated() {
    BOOL fRet = FALSE;
    HANDLE hToken = NULL;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
        TOKEN_ELEVATION elevation;
        DWORD cbSize = sizeof(TOKEN_ELEVATION);
        if (GetTokenInformation(hToken, TokenElevation, &elevation, sizeof(elevation), &cbSize)) {
            fRet = elevation.TokenIsElevated;
        }
        CloseHandle(hToken);
    }
    return fRet != FALSE;
}

DWORD GetExplorerPid() {
    DWORD explorerPid = 0;
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe;
        pe.dwSize = sizeof(pe);
        if (Process32FirstW(hSnapshot, &pe)) {
            do {
                if (_wcsicmp(pe.szExeFile, L"explorer.exe") == 0) {
                    explorerPid = pe.th32ProcessID;
                    break;
                }
            } while (Process32NextW(hSnapshot, &pe));
        }
        CloseHandle(hSnapshot);
    }
    return explorerPid;
}

bool LaunchViaTokenDuplication(const fs::path& exePath) {
    DWORD explorerPid = GetExplorerPid();
    if (explorerPid == 0) return false;

    HANDLE hExplorerProc = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, explorerPid);
    if (!hExplorerProc) return false;

    HANDLE hExplorerToken = NULL;
    if (!OpenProcessToken(hExplorerProc, TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY | TOKEN_QUERY, &hExplorerToken)) {
        CloseHandle(hExplorerProc);
        return false;
    }

    HANDLE hNewToken = NULL;
    BOOL dupResult = DuplicateTokenEx(hExplorerToken, TOKEN_ALL_ACCESS, NULL, SecurityImpersonation, TokenPrimary, &hNewToken);
    CloseHandle(hExplorerToken);
    CloseHandle(hExplorerProc);

    if (!dupResult || !hNewToken) return false;

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = { 0 };
    std::wstring cmdLine = L"\"" + exePath.wstring() + L"\"";
    wchar_t cmdLineBuf[32768];
    wcsncpy_s(cmdLineBuf, cmdLine.c_str(), _TRUNCATE);

    BOOL created = CreateProcessWithTokenW(
        hNewToken,
        LOGON_WITH_PROFILE,
        NULL,
        cmdLineBuf,
        0,
        NULL,
        exePath.parent_path().c_str(),
        &si,
        &pi
    );

    CloseHandle(hNewToken);

    if (created) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return true;
    }
    return false;
}

bool LaunchViaExplorerCom(const fs::path& exePath) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
        return false;
    }

    bool success = false;
    IShellWindows* psw = NULL;
    hr = CoCreateInstance(CLSID_ShellWindows, NULL, CLSCTX_LOCAL_SERVER, IID_PPV_ARGS(&psw));
    if (SUCCEEDED(hr) && psw) {
        VARIANT vEmpty = { 0 };
        HWND hwnd = 0;
        IDispatch* pdisp = NULL;
        if (psw->FindWindowSW(&vEmpty, &vEmpty, SWC_DESKTOP, (long*)&hwnd, SWDI_CALLBACK, &pdisp) == S_OK) {
            IServiceProvider* psp = NULL;
            if (SUCCEEDED(pdisp->QueryInterface(IID_PPV_ARGS(&psp)))) {
                IShellBrowser* psb = NULL;
                if (SUCCEEDED(psp->QueryService(SID_STopLevelBrowser, IID_PPV_ARGS(&psb)))) {
                    IShellView* psv = NULL;
                    if (SUCCEEDED(psb->QueryActiveShellView(&psv))) {
                        IDispatch* pdispBackground = NULL;
                        if (SUCCEEDED(psv->GetItemObject(SVGIO_BACKGROUND, IID_PPV_ARGS(&pdispBackground)))) {
                            IShellFolderViewDual* psfvd = NULL;
                            if (SUCCEEDED(pdispBackground->QueryInterface(IID_PPV_ARGS(&psfvd)))) {
                                IDispatch* pdispApplication = NULL;
                                if (SUCCEEDED(psfvd->get_Application(&pdispApplication))) {
                                    IShellDispatch2* psd = NULL;
                                    if (SUCCEEDED(pdispApplication->QueryInterface(IID_PPV_ARGS(&psd)))) {
                                        BSTR bstrFile = SysAllocString(exePath.c_str());
                                        HRESULT hresExec = psd->ShellExecute(bstrFile, vEmpty, vEmpty, vEmpty, vEmpty);
                                        SysFreeString(bstrFile);
                                        if (SUCCEEDED(hresExec)) {
                                            success = true;
                                        }
                                        psd->Release();
                                    }
                                    pdispApplication->Release();
                                }
                                psfvd->Release();
                            }
                            pdispBackground->Release();
                        }
                        psv->Release();
                    }
                    psb->Release();
                }
                psp->Release();
            }
            pdisp->Release();
        }
        psw->Release();
    }

    CoUninitialize();
    return success;
}

bool LaunchAsNormalUser(const fs::path& exePath) {
    Logger::Log("INFO", "Attempting launch as normal user (de-escalation)");
    EnablePrivilege(SE_IMPERSONATE_NAME);
    if (LaunchViaTokenDuplication(exePath)) {
        Logger::Log("INFO", "Launched via Token Duplication successfully");
        return true;
    }
    Logger::Log("WARN", "Token Duplication failed, attempting Explorer COM launch");
    if (LaunchViaExplorerCom(exePath)) {
        Logger::Log("INFO", "Launched via Explorer COM successfully");
        return true;
    }
    Logger::Log("ERROR", "All de-escalation methods failed");
    return false;
}

bool LaunchProcess(const fs::path& exePath) {
    if (IsElevated()) {
        if (LaunchAsNormalUser(exePath)) {
            return true;
        }
        Logger::Log("WARN", "De-escalation failed, falling back to direct CreateProcessW");
    }

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = { 0 };
    std::wstring cmdLine = L"\"" + exePath.wstring() + L"\"";
    wchar_t cmdBuf[32768];
    wcsncpy_s(cmdBuf, cmdLine.c_str(), _TRUNCATE);

    if (CreateProcessW(NULL, cmdBuf, NULL, NULL, FALSE, DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP, NULL, exePath.parent_path().c_str(), &si, &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        Logger::Log("INFO", "Direct process created successfully");
        return true;
    }
    Logger::Log("ERROR", "Failed to launch process directly, Error Code: " + std::to_string(GetLastError()));
    return false;
}

// Zip Slip path security check
bool IsPathSafe(const fs::path& targetDir, const fs::path& entryRelativePath) {
    try {
        fs::path fullPath = fs::weakly_canonical(targetDir / entryRelativePath);
        fs::path canonicalTarget = fs::weakly_canonical(targetDir);

        std::wstring strFull = fullPath.wstring();
        std::wstring strTarget = canonicalTarget.wstring();

        if (!strTarget.empty() && strTarget.back() != L'\\' && strTarget.back() != L'/') {
            strTarget += L'\\';
        }

        if (strFull.length() < strTarget.length()) return false;
        std::wstring prefix = strFull.substr(0, strTarget.length());
        return (_wcsnicmp(prefix.c_str(), strTarget.c_str(), strTarget.length()) == 0);
    } catch (...) {
        return false;
    }
}

// Move directory contents with retry loop
bool MoveDirectoryContentsWithRetry(const fs::path& srcDir, const fs::path& dstDir) {
    std::error_code ec;
    fs::create_directories(dstDir, ec);

    if (!fs::exists(srcDir)) return true;

    for (const auto& entry : fs::directory_iterator(srcDir, ec)) {
        fs::path rel = fs::relative(entry.path(), srcDir);
        fs::path targetPath = dstDir / rel;

        bool moved = false;
        for (int attempt = 0; attempt < 25; ++attempt) {
            if (entry.is_directory()) {
                if (MoveDirectoryContentsWithRetry(entry.path(), targetPath)) {
                    fs::remove(entry.path(), ec);
                    moved = true;
                    break;
                }
            } else {
                if (MoveFileExW(entry.path().c_str(), targetPath.c_str(), MOVEFILE_COPY_ALLOWED | MOVEFILE_WRITE_THROUGH | MOVEFILE_REPLACE_EXISTING)) {
                    moved = true;
                    break;
                }
            }
            Sleep(200);
        }
        if (!moved) {
            Logger::Log("ERROR", "Failed to move file after 25 attempts: " + entry.path().string());
            return false;
        }
    }
    return true;
}

// Perform Rollback: restore backup to target
bool PerformRollback(const Config& config, const std::string& reason) {
    Logger::Log("WARN", "Starting ROLLBACK due to: " + reason);
    Logger::LogJsonResult("ROLLBACK", reason);

    std::error_code ec;
    if (fs::exists(config.targetDir)) {
        fs::remove_all(config.targetDir, ec);
    }
    fs::create_directories(config.targetDir, ec);

    if (fs::exists(config.backupDir)) {
        if (!MoveDirectoryContentsWithRetry(config.backupDir, config.targetDir)) {
            Logger::Log("CRITICAL", "Rollback file restoration partially failed!");
        }
    }

    fs::path oldExe = config.targetDir / config.exeName;
    if (fs::exists(oldExe)) {
        Logger::Log("INFO", "Restored old executable found, launching...");
        LaunchProcess(oldExe);
    } else {
        Logger::Log("CRITICAL", "Old executable not found after rollback!");
    }

    return false;
}

int wmain(int argc, wchar_t* argv[]) {
    Logger::Init();
    Logger::Log("INFO", "Solaris Native Updater started");

    Config config;
    for (int i = 1; i < argc; ++i) {
        std::wstring arg = argv[i];
        if (arg == L"--pid" && i + 1 < argc) {
            config.pid = std::stoul(argv[++i]);
        } else if (arg == L"--zip" && i + 1 < argc) {
            config.zipPath = argv[++i];
        } else if (arg == L"--target" && i + 1 < argc) {
            config.targetDir = argv[++i];
        } else if (arg == L"--exe" && i + 1 < argc) {
            config.exeName = argv[++i];
        } else if (arg == L"--backup" && i + 1 < argc) {
            config.backupDir = argv[++i];
        }
    }

    if (config.zipPath.empty() || config.targetDir.empty()) {
        Logger::Log("ERROR", "Missing required arguments --zip or --target");
        Logger::LogJsonResult("ERROR", "Missing required arguments --zip or --target");
        return 1;
    }

    if (config.backupDir.empty()) {
        config.backupDir = config.targetDir.parent_path() / (config.targetDir.filename().wstring() + L"_backup");
    }

    Logger::Log("INFO", "Target Dir: " + config.targetDir.string());
    Logger::Log("INFO", "Backup Dir: " + config.backupDir.string());
    Logger::Log("INFO", "Zip Path: " + config.zipPath.string());

    // Step 1: Wait for main Solaris process termination
    if (config.pid != 0) {
        Logger::Log("INFO", "Waiting for PID " + std::to_string(config.pid) + " to terminate...");
        HANDLE hProcess = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, config.pid);
        if (hProcess != NULL) {
            DWORD dwWait = WaitForSingleObject(hProcess, 30000);
            if (dwWait == WAIT_TIMEOUT) {
                Logger::Log("WARN", "PID " + std::to_string(config.pid) + " timed out after 30s. Terminating process.");
                TerminateProcess(hProcess, 1);
                Sleep(500);
            }
            CloseHandle(hProcess);
        } else {
            Logger::Log("INFO", "PID process handle was NULL (already terminated or invalid)");
        }
    }

    // Step 2: Sleep 1 second for OS file lock release
    Sleep(1000);

    // Step 3: Create atomic backup
    Logger::Log("INFO", "Creating backup directory...");
    std::error_code ec;
    if (fs::exists(config.backupDir)) {
        fs::remove_all(config.backupDir, ec);
    }
    fs::create_directories(config.backupDir, ec);

    if (!MoveDirectoryContentsWithRetry(config.targetDir, config.backupDir)) {
        Logger::Log("ERROR", "Failed to create backup. Aborting update before changes.");
        Logger::LogJsonResult("ERROR", "Failed to create backup");
        return 1;
    }
    Logger::Log("INFO", "Backup created successfully.");

    // Step 4: Re-create empty target directory
    fs::create_directories(config.targetDir, ec);

    // Step 5: Extract ZIP via miniz
    Logger::Log("INFO", "Opening ZIP file for extraction...");
    FILE* pZipFile = _wfopen(config.zipPath.c_str(), L"rb");
    if (!pZipFile) {
        PerformRollback(config, "Cannot open ZIP file: " + config.zipPath.string());
        return 2;
    }

    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_cfile(&zip, pZipFile, 0, 0)) {
        fclose(pZipFile);
        PerformRollback(config, "Invalid or corrupted ZIP archive");
        return 2;
    }

    mz_uint32 numFiles = mz_zip_reader_get_num_files(&zip);
    Logger::Log("INFO", "Extracting " + std::to_string(numFiles) + " entries from ZIP...");

    bool extractionOk = true;
    std::string extractErrorReason = "";

    for (mz_uint32 i = 0; i < numFiles; ++i) {
        mz_zip_archive_file_stat stat;
        if (!mz_zip_reader_file_stat(&zip, i, &stat)) {
            extractionOk = false;
            extractErrorReason = "Failed to stat zip entry index " + std::to_string(i);
            break;
        }

        // Convert filename from UTF-8 to UTF-16 using dynamic buffer sizing
        int reqLen = MultiByteToWideChar(CP_UTF8, 0, stat.m_filename, -1, NULL, 0);
        if (reqLen <= 0) {
            extractionOk = false;
            extractErrorReason = "UTF-8 path conversion error (invalid length)";
            break;
        }
        std::vector<wchar_t> wEntryBuf(reqLen);
        int wLen = MultiByteToWideChar(CP_UTF8, 0, stat.m_filename, -1, wEntryBuf.data(), reqLen);
        if (wLen <= 0) {
            extractionOk = false;
            extractErrorReason = "UTF-8 path conversion error";
            break;
        }
        wchar_t* wEntry = wEntryBuf.data();

        // Replace '/' with '\'
        for (int k = 0; wEntry[k] != L'\0'; ++k) {
            if (wEntry[k] == L'/') wEntry[k] = L'\\';
        }

        fs::path entryRel(wEntry);
        if (!IsPathSafe(config.targetDir, entryRel)) {
            extractionOk = false;
            extractErrorReason = "Zip Slip security policy violation: " + entryRel.string();
            break;
        }

        fs::path destPath = config.targetDir / entryRel;

        if (stat.m_is_directory) {
            fs::create_directories(destPath, ec);
        } else {
            fs::create_directories(destPath.parent_path(), ec);
            size_t fileSize = 0;
            void* pBuf = mz_zip_reader_extract_to_heap(&zip, i, &fileSize, 0);
            if (!pBuf && fileSize > 0) {
                extractionOk = false;
                extractErrorReason = "Failed to extract zip file: " + destPath.string();
                break;
            }

            HANDLE hOut = CreateFileW(destPath.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
            if (hOut == INVALID_HANDLE_VALUE) {
                if (pBuf) mz_free(pBuf);
                extractionOk = false;
                extractErrorReason = "Failed to create output file: " + destPath.string();
                break;
            }

            DWORD written = 0;
            if (fileSize > 0) {
                WriteFile(hOut, pBuf, (DWORD)fileSize, &written, NULL);
            }
            CloseHandle(hOut);
            if (pBuf) mz_free(pBuf);

            if (written != fileSize) {
                extractionOk = false;
                extractErrorReason = "Write size mismatch for file: " + destPath.string();
                break;
            }
        }
    }

    mz_zip_reader_end(&zip);
    fclose(pZipFile);

    if (!extractionOk) {
        PerformRollback(config, extractErrorReason);
        return 2;
    }

    // Step 6: Verification
    fs::path newExe = config.targetDir / config.exeName;
    if (!fs::exists(newExe)) {
        PerformRollback(config, "Verification failed: " + config.exeName.string() + " does not exist after extraction");
        return 2;
    }

    Logger::Log("INFO", "Update extracted and verified successfully!");
    Logger::LogJsonResult("SUCCESS");

    // Launch updated executable
    LaunchProcess(newExe);

    // Clean up backup directory and ZIP
    fs::remove_all(config.backupDir, ec);
    fs::remove(config.zipPath, ec);

    Logger::Log("INFO", "Updater completed cleanly. Exiting.");
    return 0;
}
