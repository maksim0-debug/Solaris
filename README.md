# Solaris

<p align="center">
  <img src="solaris/assets/icon/icon_180.png" alt="Solaris icon" width="140" />
</p>

<p align="center">
  <a href="https://github.com/maksim0-debug/Solaris/releases/latest/download/Solaris-Windows.zip">
    <img src="https://img.shields.io/badge/Download-Windows_(.zip)-0284c7?style=for-the-badge&logo=windows&logoColor=white" alt="Download for Windows" />
  </a>
  <a href="https://github.com/maksim0-debug/Solaris/releases/latest">
    <img src="https://img.shields.io/github/v/release/maksim0-debug/Solaris?style=for-the-badge&color=fdba74&label=Release" alt="Latest Release" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-emerald?style=for-the-badge" alt="MIT License" />
  </a>
</p>

Solaris is a Windows desktop app that automatically adjusts monitor brightness and color temperature based on the position of the sun. It calculates solar elevation for your location in real time and maps it to a brightness curve you can customize. Color temperature shifts from daylight (6500 K) to warm (1000 K) as the sun goes down. Works across multiple monitors, supports per-app profiles, integrates with weather data, and exposes a local API for automation.

Built with Flutter. Talks to monitors over DDC/CI.

<img width="1284" height="881" alt="Solaris dashboard — brightness curve, sun position, multi-monitor controls" src="https://github.com/user-attachments/assets/363bfcb9-094f-4d62-84fc-7389fcdc77b0" />

---

## Features

### Circadian auto-brightness

The app tracks the sun's elevation angle for your coordinates and adjusts brightness along a curve. Transitions are gradual — no abrupt jumps. The curve is editable: drag Bézier control points or pick a preset (Bright, Balanced, Soft). Changes preview on the graph in real time.

![Curve editor with Bézier control points and presets](https://github.com/user-attachments/assets/0fd7fb2d-d0e7-4101-8b2e-470f7dd8a84d)

### Multi-monitor control

Each connected display can have its own brightness offset. You can adjust a specific monitor individually or control all screens at once. Solaris communicates with monitors over DDC/CI for hardware-level brightness control.

<img width="314" height="254" alt="Per-monitor brightness offsets" src="https://github.com/user-attachments/assets/53066949-0c59-4fc8-afa5-79805fd59ef8" />

### Extra-dark dimming (below 0%)

When your monitor's minimum hardware brightness is still too bright, Solaris can dim further — down to −100% — using a lightweight screen overlay. The overlay is click-through (no input lag), invisible to screenshots and screen sharing (OBS, Discord, Zoom), and capped at 85% opacity so you never accidentally black out the screen.

### Color temperature

Modifies the display gamma ramp at the GPU level, so it works on all screens — including laptops and monitors without DDC/CI. Range: 6500 K (daylight) → 1000 K (candlelight). Can be set globally or per-monitor.

### Game mode

Automatically detects fullscreen games and locks brightness and color temperature to fixed values (e.g. 80%, 6500 K) until you exit. Configurable delay when alt-tabbing to avoid flickering. Supports whitelist and blacklist by executable name.

<img width="965" height="647" alt="Game mode settings" src="https://github.com/user-attachments/assets/2c2f9d40-af44-4e7f-858c-8460842aa6cd" />

### Per-app profiles

Override brightness and/or color temperature for specific applications. Ships with 25 built-in rules for creative software (Photoshop, DaVinci Resolve, Blender, Figma, etc.) that lock color temperature to 6500 K for accurate color work. You can add your own rules with custom curves, fixed values, or inherit global settings. Configurable exit delay so settings don't flicker when switching between apps.

<img width="954" height="663" alt="Per-app profile overrides" src="https://github.com/user-attachments/assets/b35bdcdb-091c-4344-888d-25696edd6f9a" />

### Weather influence

Brightness adjusts based on current weather conditions — dims during overcast, rain, or snow, stays normal on clear days. Color temperature can also shift warmer during bad weather. Weather data comes from WeatherAPI.com, with Open-Meteo as a fallback. The dashboard shows animated weather backgrounds.

### Global hotkeys

Bind keyboard shortcuts to common actions: brightness up/down, next/previous preset, toggle auto mode. Step size is configurable.

<img width="985" height="541" alt="Hotkey configuration" src="https://github.com/user-attachments/assets/1b8301c3-eeff-41b0-b240-2d76551cb641" />

### Location

Coordinates can be set automatically via GPS, by searching for a city (Mapbox geocoding), or by clicking on an interactive map. Your choice is saved between sessions.

![Location picker with interactive map](https://github.com/user-attachments/assets/a984424a-3b9e-45de-8c8d-a601f4b8b2d0)

### Auto-updates

Checks for new releases on GitHub at startup and every 24 hours. Downloads are verified with SHA-256 and validated against GitHub's SLSA Artifact Attestations to ensure they were built by CI from the open-source code. The native updater (`solaris_updater.exe`, C++17) creates a backup before applying and rolls back automatically on failure.

> [!NOTE]
> Custom builds (`IS_OFFICIAL_RELEASE=false`) have auto-updates disabled. Updating from a custom build to an official release may reset saved API keys due to Windows DPAPI encryption scope.

---

## Sleep integration

Solaris can incorporate your sleep data to fine-tune brightness and color temperature throughout the day. Three modes are available: a **permanent schedule** (set your sleep/wake times once and the app uses them every day — no API or external apps needed), a **local API** for integration with desktop sleep trackers, and **Google Fit** sync.

<img width="787" height="653" alt="Sleep integration screen" src="https://github.com/user-attachments/assets/94ee4ba4-6a71-4227-b05e-1d858a9917c4" />

When enabled, four circadian models are applied:

- **Wind-down** — gradually reduces brightness and warms the screen before bedtime; restores daytime settings before expected wake-up.
- **Bio-morning** — shifts the circadian anchor if you wake earlier or later than usual.
- **Sleep pressure** — after 16+ hours awake, gently dims and warms the screen to reduce strain.
- **Sleep debt** — if your last sleep was under 6.5 hours, maintains a softer lighting profile for the next day.

### Local sleep API

A built-in HTTP server (default port `45321`, toggle it in the Sleep tab) accepts sleep data from desktop trackers or scripts. Binds to `127.0.0.1` by default; LAN mode (`0.0.0.0`) requires API token authentication. Operates independently from the Control API.

**Endpoints:**

```
POST /api/sleep/sessions   — push sleep session history (JSON array)
POST /api/sleep/status     — report real-time sleep state ({"is_sleeping": true})
```

### Google Fit

Syncs sleep history from Google Fit. Because Google classifies sleep data as a restricted scope, official builds don't ship with credentials — you use your own:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Configure OAuth consent, add `fitness.sleep.read` scope, add yourself as test user.
3. Create a Desktop OAuth Client ID.
4. Paste Client ID and Client Secret into **Settings → API Keys** in the app (or into `.env` for build-time config).

---

## Control API, webhooks & WebSocket

Solaris runs a local HTTP + WebSocket server that lets external tools (Home Assistant, Stream Deck, Node-RED, custom scripts) query state, change settings, and subscribe to events.

<img width="970" height="435" alt="Control API dashboard" src="https://github.com/user-attachments/assets/29a6a90b-c8b5-43d3-b57a-84e5a2fe0b39" />

**Highlights:**

- 28 action commands — `set_brightness` (−100 to 100), `set_temperature` (1000–6500 K), preset management, app override management, and more.
- Monitors can be targeted by friendly slugs (`display-1`, `dell-u2720q`, `primary`) or system paths.
- Token-based auth with granular per-scope permissions. Rate limiting, CORS/CSWSH protection, DNS rebinding guard.
- 23 outbound webhook event types with HMAC-SHA256 signatures, SSRF protection, WAL buffer, and dead letter queue.
- WebSocket at `/api/v1/ws` — bidirectional JSON, request correlation via `cmd_id`, selective module subscriptions.
- Interactive OpenAPI docs at `/api/v1/docs`.

<img width="821" height="601" alt="API key management" src="https://github.com/user-attachments/assets/a8e1d799-61eb-4885-877d-5fcef55ee14d" />

Full documentation is in [`docs/`](docs/):

| Document                               | Contents                                                        |
| :------------------------------------- | :-------------------------------------------------------------- |
| [Architecture & Security](docs/API.md) | Auth formats, security pipeline, RFC 7807 errors, OpenAPI setup |
| [REST Endpoints](docs/REST_API.md)     | State endpoints, action command catalog, friendly slugs         |
| [Webhooks](docs/WEBHOOKS.md)           | Event catalog, HMAC signatures, SSRF protection, DLQ            |
| [WebSocket](docs/WEBSOCKET.md)         | Connection, subscriptions, `cmd_id` correlation                 |

---

## API keys

Advanced features (Mapbox maps, WeatherAPI weather, Google Fit) require API credentials. You don't need to rebuild — keys can be entered at runtime in **Settings → API Keys**.

<img width="838" height="560" alt="API key settings" src="https://github.com/user-attachments/assets/36035901-cb73-407c-96bf-62437f8b56fc" />

Keys take effect immediately — no restart needed. They're stored locally and encrypted with Windows DPAPI (bound to your Windows user account and device). Runtime keys override any build-time `.env` values.

**Without keys, Solaris still works** — core circadian brightness and color temperature are fully functional. Missing keys only affect specific integrations:

| Integration     | Without key                                                |
| :-------------- | :--------------------------------------------------------- |
| Interactive map | Shows a padlock; coordinates can still be entered manually |
| WeatherAPI      | Falls back to Open-Meteo (free, no key needed)             |
| Google Fit      | Disabled; local sleep API still works                      |

---

## Getting started

### Download

Grab the latest `.zip` from [Releases](https://github.com/maksim0-debug/Solaris/releases), extract, run `solaris.exe`.

### Build from source

**Requirements:** Flutter SDK (stable), Windows 10/11. DDC/CI-capable monitors for hardware brightness (color temperature works without it).

```bash
git clone https://github.com/maksim0-debug/Solaris.git
cd solaris
cp .env.example .env       # optional: fill in API keys
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

Release build:

```bash
flutter build windows
```

---

## Tech stack

- **Framework:** Flutter (Windows desktop)
- **State:** Riverpod (AsyncNotifiers, StreamProviders)
- **Hardware:** Dart FFI + win32 for DDC/CI brightness; Win32 GDI for GPU gamma ramp; native C++ overlay for sub-zero dimming
- **Solar math:** Spherical trigonometry (solar_calculator, sunrise_sunset_calc)
- **APIs:** WeatherAPI.com, Open-Meteo, Mapbox, Google Fit
- **Updater:** C++17 with miniz, SLSA attestation verification

## Project structure

```
lib/
├── l10n/        # Localization (English, Russian, Ukrainian)
├── models/      # Data structures
├── providers/   # Feature logic (weather, temperature, lifecycle)
├── screens/     # UI screens
├── services/    # Core services (monitor control, solar math, hotkeys)
├── theme/       # Styling
└── widgets/     # Reusable UI components
```

## Legal

- [Privacy Policy](https://maksim0-debug.github.io/Solaris/docs)
- [MIT License](LICENSE)
- [miniz](https://github.com/richgel999/miniz) (MIT) — compression library used by the updater
