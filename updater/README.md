# Solaris Native Updater (`updater.exe`)

Component of the Solaris auto-update system. A highly reliable, standalone C++17 console application with no GUI and no external MSVC Runtime dependencies (static linking `/MT`).

## Purpose

- Waiting for the termination of the main Solaris process (`--pid`) with a 30-second timeout and forced termination fallback.
- Creating an atomic backup of the current version (Rollback Point) with retry mechanisms for Windows file lock resilience.
- Safely extracting the update ZIP archive using the `miniz` library with built-in protection against the Zip Slip vulnerability (CWE-22).
- Automatic cleanup of the downloaded ZIP archive upon successful extraction.
- Automatic rollback to a working version in case of any extraction or verification failures.
- Safely restarting Solaris with proper UAC privilege de-escalation (Token Duplication / Explorer COM) if `updater.exe` was executed with elevated privileges (Administrator), with an emergency direct-launch fallback.

## Executable Lifecycle & Execution Flow

Before triggering an update, the main Solaris application copies `updater.exe` from its installation directory to a unique temporary folder (`%TEMP%\solaris_updater_<timestamp>\updater.exe`). Running `updater.exe` out of `%TEMP%` ensures that the updater binary itself does not lock any files inside the target installation directory, allowing complete overwrite or atomic renaming of the entire application folder.

## Command-Line Arguments

```cmd
updater.exe --pid <PID> --zip <path_to_zip> --target <install_dir> [--exe <exe_name>] [--backup <backup_dir>]
```

| Argument   | Description                                                                             |
| ---------- | --------------------------------------------------------------------------------------- |
| `--pid`    | PID of the Solaris process to monitor for completion                                    |
| `--zip`    | Full path to the downloaded update ZIP archive                                          |
| `--target` | Target installation directory of Solaris                                                |
| `--exe`    | Executable file name to restart (`solaris.exe` by default)                              |
| `--backup` | Custom path to the backup folder (defaults to `${target_parent}/${target_name}_backup`) |

_Note: The main Solaris application always passes `--backup` explicitly as `<parent_dir>\solaris_backup` to guarantee drive affinity during atomic file operations._

## 🔒 Security, Privileges & UAC Mechanism

Because `updater.exe` performs low-level file replacement in the Solaris installation directory, it incorporates robust privilege management and security checks.

### 1. When is UAC Elevation Required?

- **User-space installations** (e.g., `%LOCALAPPDATA%\Solaris`): The updater runs under standard user privileges (`asInvoker` in `app.manifest`) without triggering any UAC prompts.
- **System-wide installations** (e.g., `C:\Program Files\Solaris`): Standard users lack write permissions to Program Files. If the main application detects it cannot write to the target directory, it invokes `updater.exe` via `ShellExecuteEx` with the `runas` verb to request administrator elevation (UAC prompt).

### 2. The Principle of Least Privilege: De-escalation

Running a desktop GUI application (like Solaris, which interacts with the system tray, user context, and IPC servers) permanently with Administrator privileges is a security anti-pattern.

To prevent this, `updater.exe` implements a strict **privilege de-escalation** mechanism before restarting `solaris.exe`:

1. If `updater.exe` itself was elevated to Administrator via UAC, it checks its elevation status (`IsElevated()`).
2. Before launching the newly updated `solaris.exe`, it attempts to drop privileges back to the standard logged-in user context using two resilient fallback methods:
   - **Token Duplication (`CreateProcessWithTokenW`)**: It locates the running instance of Windows Explorer (`explorer.exe`), opens its process token, duplicates it, and spawns `solaris.exe` using that user token.
   - **Explorer COM Automation (`IShellDispatch2::ShellExecute`)**: As a fallback, it invokes the active desktop shell COM object to execute `solaris.exe` in the standard user session.
3. **Emergency Fallback**: If both de-escalation methods fail (e.g., Explorer shell unavailable or restricted COM policies), `updater.exe` logs a `WARN` message and falls back to a direct `CreateProcessW` launch (preserving elevated privileges) to ensure the application restarts reliably without user interruption.

### 3. Protection Against Zip Slip (CWE-22)

During archive extraction, `updater.exe` validates every single file path inside the downloaded ZIP using strict canonicalization checks (`IsPathSafe`). If an archive attempts a directory traversal attack (e.g., extracting a file to `../../System32/`), the updater immediately aborts the process and triggers an automatic rollback.

### 4. Atomic Backup & Automatic Rollback (Fail-Safe)

1. **Process Termination & Lock Release**: The updater waits up to 30 seconds for PID completion. If the process does not terminate within 30s, it forcefully calls `TerminateProcess`. It then pauses for 1000ms to allow the OS to release active file handles.
2. **Atomic Snapshot with Retries**: The current version is moved into the temporary backup folder (`solaris_backup`) using `MoveDirectoryContentsWithRetry` (up to 25 attempts with 200ms delays to handle transient locks by antivirus software).
3. **Extraction & ZIP Cleanup**: The new version is extracted via `miniz`. Upon successful extraction, the downloaded ZIP archive is automatically deleted.
4. **Verification**: The updater verifies that the primary executable (`solaris.exe`) exists in the target directory and is accessible.
5. **Rollback Trigger**: If extraction fails halfway, files are corrupted, or verification fails, the updater intercepts the error, wipes the incomplete target directory, restores the entire previous version from the backup via retry loops, and launches the old working executable.

## Building

```bash
cd updater
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

The compiled binary will be located at `updater/build/Release/updater.exe`.

## Exit Codes

- `0` — Successful update and application restart.
- `1` — Fatal error (missing required arguments or failed to create backup).
- `2` — Extraction/verification error occurred; successful rollback to the previous version executed and original `solaris.exe` launched.

## Logging & Inter-Process Communication (IPC)

Because `updater.exe` runs as an independent, detached process while the main Solaris application is fully terminated, standard IPC mechanisms (like named pipes or local sockets) cannot be used across the process lifecycle boundary. Instead, Solaris uses a file-based IPC pattern via a shared log file.

### 1. Log File Location

All operational events, warnings, critical errors, and final status summaries are written to:
`%LOCALAPPDATA%\Solaris\update.log`

### 2. Structured JSON Result Output

Upon completing its workflow (whether successful, failed, or rolled back), `updater.exe` appends a structured JSON block to `update.log`. This acts as the return code payload for the main application:

- **Success Example:**

  ```json
  {
    "status": "SUCCESS",
    "timestamp": "2026-07-22T04:00:00Z"
  }
  ```

- **Rollback Example:**

  ```json
  {
    "status": "ROLLBACK",
    "timestamp": "2026-07-22T04:05:00Z",
    "reason": "Verification failed: solaris.exe missing after extraction"
  }
  ```

- **Fatal Error Example:**
  ```json
  {
    "status": "ERROR",
    "timestamp": "2026-07-22T04:05:00Z",
    "reason": "Failed to create backup"
  }
  ```

### 3. Post-Update Lifecycle Handling (`PostUpdateService`)

When Solaris launches after an update attempt, its initialization sequence (`PostUpdateService`) handles post-update tasks as follows:

1. **Read & Parse**: Reads `update.log`, parses the JSON status payload (`SUCCESS`, `ROLLBACK`, `ERROR`), and loads it into the app state (`postUpdateResultProvider`).
2. **Log Rotation (Retention)**: Safely renames `update.log` to `update.last.log` to preserve diagnostics for debugging while clearing the active log for future updates.
3. **Conditional Backup Cleanup**:
   - If `status == SUCCESS`: Automatically deletes the post-update `backup` directory to free up disk space.
   - If `status == ROLLBACK` or `ERROR`: Retains the `backup` directory intact so developers or users can investigate the previous state.
4. **Windows Autorun Registry Synchronization**: Checks if Solaris is registered for Windows startup and updates the registry path (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`) to match `Platform.resolvedExecutable`.
5. **Background Artifact Garbage Collection**: After a 3-second startup delay, asynchronously scans `%TEMP%` and deletes temporary updater folders (`solaris_updater_*` and `solaris_updates_*`) older than 24 hours without blocking app initialization.
6. **User Notification**: Displays a localized success notification banner or a detailed error/rollback warning dialog to the user on the dashboard.

## License & Third-Party Libraries

- This project component is licensed under the **MIT License**.
- Includes [miniz](https://github.com/richgel999/miniz) ([MIT License](https://github.com/richgel999/miniz/blob/master/LICENSE)) for ZIP archive extraction and decompression.
