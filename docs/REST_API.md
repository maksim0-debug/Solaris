# Solaris Control API v1 — REST Endpoints & Action Control System

This document provides a comprehensive REST endpoint reference for **Solaris Control API v1**, including state query endpoints, per-monitor resolution via Friendly Slugs, and complete documentation for all **26 Action Control System commands** (`POST /api/v1/control`).

---

## 📑 Table of Contents
1. [State Query Endpoints](#-state-query-endpoints)
   - `GET /api/v1/health`
   - `GET /api/v1/status`
   - `GET /api/v1/presets`
   - `GET /api/v1/solar`
   - `GET /api/v1/sleep/sessions`
2. [Per-Monitor Endpoints & Slug Resolver](#-per-monitor-endpoints--slug-resolver)
   - `GET /api/v1/monitors`
   - `GET /api/v1/monitors/:slug`
   - `POST /api/v1/monitors/:slug/control`
3. [Action Control System (`POST /api/v1/control`)](#-action-control-system-post-apiv1control)
   - [Single Action vs. Batch Execution](#single-action-vs-batch-execution)
   - [Catalog of All 26 Action Commands](#catalog-of-all-26-action-commands)

---

## 🔍 State Query Endpoints

### 1. `GET /api/v1/health`
Lightweight health check endpoint. Useful for liveness probes, load balancers, and status pinging.

* **Authentication**: Not required / Optional
* **Response (HTTP 200 OK)**:
```json
{
  "status": "ok",
  "version": "1.0.36",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-24T10:45:00.000Z"
}
```

---

### 2. `GET /api/v1/status`
Returns the complete application state graph: connected monitors, hardware brightness/temperature readings, active presets, solar elevation/azimuth, weather adjustments, sleep tracking engine status, smart circadian state, and LAN API server configuration.

* **Authentication**: Required (`X-API-Key` or `Authorization: Bearer`)
* **Response (HTTP 200 OK)**:
```json
{
  "version": "1.0.36",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-24T10:45:00.000Z",
  "monitors": [
    {
      "id": "\\\\.\\DISPLAY1",
      "name": "LG UltraGear 27GP850",
      "friendly_name": "LG UltraGear A1F9",
      "slug": "lg-ultragear-a1f9",
      "device_id_hash": "a1f9b3c4...",
      "is_primary": true,
      "brightness": {
        "current": 80,
        "target": 80.0,
        "offset": 0.0,
        "mode": "auto",
        "active_preset": "bright",
        "active_user_preset": null
      },
      "temperature": {
        "enabled": true,
        "current": 5500,
        "target": 5500,
        "mode": "auto",
        "active_preset": "cool",
        "active_user_preset": null
      }
    }
  ],
  "solar": {
    "elevation": 42.5,
    "azimuth": 185.3,
    "zenith": 47.5,
    "progress": 0.65,
    "current_phase": "day",
    "next_event": {
      "type": "sunset",
      "in_seconds": 18400
    },
    "uv_index": 4.2,
    "spectral_intensity": 0.88
  },
  "weather": {
    "temperature_celsius": 24.5,
    "condition": "Clear",
    "is_day": true,
    "brightness_adjustment_active": true,
    "temperature_adjustment_active": false,
    "intensity": 0.2
  },
  "sleep": {
    "is_sleeping": false,
    "last_session_end": "2026-07-24T06:30:00.000Z"
  },
  "gaming_mode": {
    "is_active": false,
    "active_process": null
  },
  "smart_circadian": {
    "enabled": true,
    "wind_down_active": false,
    "sleep_pressure": 0.35,
    "sleep_debt_minutes": 12
  },
  "api_server": {
    "port": 45321,
    "lan_access_enabled": false
  }
}
```

---

### 3. `GET /api/v1/presets`
Returns all built-in brightness presets, color temperature presets, and custom user-defined presets.

* **Response (HTTP 200 OK)**:
```json
{
  "brightness_presets": [
    { "type": "brightest", "value": 100.0 },
    { "type": "bright", "value": 80.0 },
    { "type": "dim", "value": 40.0 },
    { "type": "dimmest", "value": 15.0 }
  ],
  "temperature_presets": [
    { "type": "coolest", "kelvin": 6500 },
    { "type": "cool", "kelvin": 5500 },
    { "type": "warm", "kelvin": 4500 },
    { "type": "warmest", "kelvin": 3300 }
  ],
  "user_presets": []
}
```

---

### 4. `GET /api/v1/solar`
Returns real-time solar tracking parameters, elevation, azimuth, zenith angle, day phase, and upcoming solar events (sunset/sunrise).

---

### 5. `GET /api/v1/sleep/sessions`
Returns paginated sleep tracking sessions stored in the SQLite database.

* **Query Parameters**:
  * `limit` (optional, default `10`, max `100`): Number of sessions to return.
  * `offset` (optional, default `0`): Pagination offset.
* **Example**: `GET /api/v1/sleep/sessions?limit=5&offset=0`
* **Response (HTTP 200 OK)**:
```json
{
  "total": 44,
  "limit": 5,
  "offset": 0,
  "sessions": [
    {
      "id": "session_1721800000",
      "start_time": "2026-07-23T22:30:00.000Z",
      "end_time": "2026-07-24T06:30:00.000Z",
      "duration_minutes": 480,
      "efficiency": 0.94
    }
  ]
}
```

---

## 🖥️ Per-Monitor Endpoints & Slug Resolver

Solaris Control API features a **Friendly Slug Resolver** (`MonitorSlugResolver`) allowing monitors to be targeted by easy-to-read identifiers instead of long Windows device paths (`\\\\.\\DISPLAY1`).

### Supported Slug Matchers:
1. **Ordinal Slugs**: `display-1`, `display-2`, `display-3`
2. **Friendly Name Slugs**: `lg-ultragear-a1f9`, `dell-u2720q-e34b` (Generated from Monitor Name + 4-char Device ID hash)
3. **Keyword Slugs**: `primary`, `main` (Resolves to primary display), `all` (Targets all displays).

---

### 1. `GET /api/v1/monitors`
Returns a list of all currently connected physical monitors with their calculated slugs.

---

### 2. `GET /api/v1/monitors/:slug`
Returns detailed status for a single monitor identified by `:slug` (e.g. `display-1` or `lg-ultragear-a1f9`).

---

### 3. `POST /api/v1/monitors/:slug/control`
Executes an action command targeting the monitor specified in `:slug`. This is an alias for `POST /api/v1/control` with `monitor_id` pre-filled by `:slug`.

---

## ⚙️ Action Control System (`POST /api/v1/control`)

The Action Control System provides a single mutation gateway supporting **26 action types** for controlling all aspects of Solaris.

### Single Action vs. Batch Execution

#### Single Action Payload:
```json
{
  "action": "set_brightness",
  "value": 85.0,
  "monitor_id": "display-1"
}
```

#### Batch Execution Payload:
Batch payloads allow executing multiple commands in a single HTTP request.
* `actions` (array of action objects): List of actions to execute sequentially.
* `fail_fast` (boolean, optional, default `false`): If `true`, batch execution stops immediately on the first error.

```json
{
  "fail_fast": true,
  "actions": [
    { "action": "set_brightness", "value": 75.0 },
    { "action": "set_temperature", "value": 5000 }
  ]
}
```

> [!NOTE]
> **HTTP Status Codes for Actions**:
> Actions that apply hardware-level DDC/CI adjustments or debounced smooth transitions return **`HTTP 202 Accepted`**. Immediate state toggles return **`HTTP 200 OK`**.

---

### Catalog of All 26 Action Commands

#### 1. `set_brightness`
Sets manual monitor brightness level (0.0 to 100.0%). Automatically disables Auto Brightness.
* **HTTP Status**: `202 Accepted`
* **Fields**: `value` (double, `0.0..100.0`, required), `monitor_id` (string, optional, default `"all"`).
* **Payload**:
```json
{ "action": "set_brightness", "value": 80.0, "monitor_id": "display-1" }
```

#### 2. `set_auto_brightness`
Enables or disables automatic brightness adjustment based on solar/circadian algorithm.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_auto_brightness", "enabled": true }
```

#### 3. `toggle_auto_brightness`
Toggles automatic brightness mode on/off.
* **HTTP Status**: `200 OK`
* **Payload**:
```json
{ "action": "toggle_auto_brightness" }
```

#### 4. `set_temperature`
Sets manual color temperature in Kelvin (3300 K to 6500 K). Automatically disables Auto Temperature.
* **HTTP Status**: `202 Accepted`
* **Fields**: `value` (integer Kelvin, `3300..6500`, required), `monitor_id` (string, optional).
* **Payload**:
```json
{ "action": "set_temperature", "value": 4500 }
```

#### 5. `set_color_temperature_enabled`
Master toggle for color temperature software/hardware filtering.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_color_temperature_enabled", "enabled": true }
```

#### 6. `set_auto_temperature`
Enables or disables automatic color temperature curve adjustments.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_auto_temperature", "enabled": true }
```

#### 7. `toggle_auto_temperature`
Toggles automatic color temperature mode on/off.
* **HTTP Status**: `200 OK`
* **Payload**:
```json
{ "action": "toggle_auto_temperature" }
```

#### 8. `set_brightness_preset`
Applies a built-in brightness preset.
* **HTTP Status**: `200 OK`
* **Fields**: `preset` (string: `"brightest"`, `"bright"`, `"dim"`, `"dimmest"`, required).
* **Payload**:
```json
{ "action": "set_brightness_preset", "preset": "bright" }
```

#### 9. `set_temperature_preset`
Applies a built-in color temperature preset.
* **HTTP Status**: `200 OK`
* **Fields**: `preset` (string: `"coolest"`, `"cool"`, `"warm"`, `"warmest"`, required).
* **Payload**:
```json
{ "action": "set_temperature_preset", "preset": "warm" }
```

#### 10. `set_user_preset`
Applies a custom user-created preset by ID.
* **HTTP Status**: `200 OK`
* **Fields**: `id` (string, required).
* **Payload**:
```json
{ "action": "set_user_preset", "id": "preset_work_mode" }
```

#### 11. `cycle_preset`
Cycles to the next or previous preset in sequence.
* **HTTP Status**: `200 OK`
* **Fields**: `direction` (string: `"next"` or `"previous"`, optional, default `"next"`).
* **Payload**:
```json
{ "action": "cycle_preset", "direction": "next" }
```

#### 12. `set_game_mode`
Enables or disables Gaming Mode override manually.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_game_mode", "enabled": true }
```

#### 13. `set_game_mode_brightness`
Configures target brightness level applied during Gaming Mode activation.
* **HTTP Status**: `202 Accepted`
* **Fields**: `value` (double, `0.0..100.0`, required).
* **Payload**:
```json
{ "action": "set_game_mode_brightness", "value": 90.0 }
```

#### 14. `manage_game_mode_whitelist`
Adds or removes executable process names from automatic Gaming Mode detection whitelist.
* **HTTP Status**: `200 OK`
* **Fields**: `op` (string: `"add"` or `"remove"`, required), `app` (string process name e.g. `"cyberpunk2077.exe"`, required).
* **Payload**:
```json
{ "action": "manage_game_mode_whitelist", "op": "add", "app": "cyberpunk2077.exe" }
```

#### 15. `set_monitor_offset`
Applies a relative brightness offset (-50.0% to +50.0%) to a specific monitor.
* **HTTP Status**: `202 Accepted`
* **Fields**: `offset` (double, `-50.0..50.0`, required), `monitor_id` (string, optional).
* **Payload**:
```json
{ "action": "set_monitor_offset", "monitor_id": "display-2", "offset": -10.0 }
```

#### 16. `set_weather_adjustment`
Toggles weather-driven brightness and temperature dynamic compensation.
* **HTTP Status**: `200 OK`
* **Fields**: `brightness` (boolean, optional), `temperature` (boolean, optional).
* **Payload**:
```json
{ "action": "set_weather_adjustment", "brightness": true, "temperature": false }
```

#### 17. `set_weather_temperature_adjustment`
Toggles temperature weather compensation specifically.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_weather_temperature_adjustment", "enabled": true }
```

#### 18. `set_weather_intensity`
Configures weather adjustment intensity factor (0.0 to 1.0).
* **HTTP Status**: `202 Accepted`
* **Fields**: `value` (double, `0.0..1.0`, required).
* **Payload**:
```json
{ "action": "set_weather_intensity", "value": 0.5 }
```

#### 19. `set_smart_circadian`
Master toggle for Smart Circadian rhythm engine.
* **HTTP Status**: `200 OK`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_smart_circadian", "enabled": true }
```

#### 20. `set_smart_circadian_submodules`
Toggles individual sub-modules of the Smart Circadian algorithm.
* **HTTP Status**: `200 OK`
* **Fields**: `wind_down` (bool), `time_shift` (bool), `sleep_pressure` (bool), `sleep_debt` (bool).
* **Payload**:
```json
{
  "action": "set_smart_circadian_submodules",
  "wind_down": true,
  "sleep_pressure": true
}
```

#### 21. `set_map_animations`
Controls map GUI particle weather animation effects.
* **HTTP Status**: `200 OK`
* **Fields**: `rain` (bool), `snow` (bool), `thunder` (bool), `cloud` (bool).
* **Payload**:
```json
{ "action": "set_map_animations", "rain": true, "snow": false }
```

#### 22. `set_manual_location`
Sets manual geographic coordinates for solar calculations.
* **HTTP Status**: `200 OK`
* **Fields**: `latitude` (double, `-90.0..90.0`, required), `longitude` (double, `-180.0..180.0`, required).
* **Payload**:
```json
{ "action": "set_manual_location", "latitude": 50.4501, "longitude": 30.5234 }
```

#### 23. `set_weather_provider`
Configures weather data provider service.
* **HTTP Status**: `200 OK`
* **Fields**: `provider` (string: `"openMeteo"`, `"weatherApi"`, `"auto"`, required).
* **Payload**:
```json
{ "action": "set_weather_provider", "provider": "openMeteo" }
```

#### 24. `trigger_sun_sync`
Forces immediate recalculation and API refetch for solar position and weather.
* **HTTP Status**: `200 OK`
* **Payload**:
```json
{ "action": "trigger_sun_sync" }
```

#### 25. `push_sleep_status`
Pushes sleep state relay status from external tracking applications (e.g. mobile app, smart watch, Home Assistant) without polluting SQLite session history.
* **HTTP Status**: `200 OK`
* **Fields**: `is_sleeping` (boolean, required).
* **Payload**:
```json
{ "action": "push_sleep_status", "is_sleeping": true }
```

#### 26. `clear_failed_webhooks`
Clears dead-letter queue (DLQ) entries for a specific webhook ID.
* **HTTP Status**: `200 OK`
* **Fields**: `webhook_id` (string, required).
* **Payload**:
```json
{ "action": "clear_failed_webhooks", "webhook_id": "wh_123456" }
```
