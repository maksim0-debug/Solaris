# Solaris Native Updater (`updater.exe`)

Component 4 of the Solaris auto-update system. A highly reliable, standalone C++17 console application with no GUI and no external MSVC Runtime dependencies (static linking `/MT`).

## Purpose

- Waiting for the termination of the main Solaris process (`--pid`).
- Creating an atomic backup of the current version (Rollback Point).
- Safely extracting the update ZIP archive using the `miniz` library with built-in protection against the Zip Slip vulnerability (CWE-22).
- Automatic rollback to a working version in case of any extraction or verification failures.
- Safely restarting Solaris with proper UAC privilege de-escalation (Token Duplication / Explorer COM) if `updater.exe` was executed with elevated privileges (Administrator).

## Command-Line Arguments

```cmd
updater.exe --pid <PID> --zip <path_to_zip> --target <install_dir> [--exe <exe_name>] [--backup <backup_dir>]
```

| Argument | Description |
| --- | --- |
| `--pid` | PID of the Solaris process to monitor for completion |
| `--zip` | Full path to the downloaded update ZIP archive |
| `--target` | Target installation directory of Solaris |
| `--exe` | Executable file name to restart (`solaris.exe` by default) |
| `--backup` | Custom path to the backup folder (`${target}_backup` by default) |

## Building

```bash
cd updater
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

The compiled binary will be located at `updater/build/Release/updater.exe`.

## Exit Codes

- `0` — Successful update and application restart.
- `1` — Fatal error (failed to create backup or invalid arguments).
- `2` — Extraction/verification error occurred, successful rollback to the previous version executed, and original `solaris.exe` launched.

## License & Third-Party Libraries

- This project component is licensed under the **MIT License**.
- Includes [miniz](https://github.com/richgel999/miniz/blob/master/LICENSE) ([MIT License](https://github.com/richgel999/miniz/blob/master/LICENSE)) for ZIP archive extraction and decompression.

