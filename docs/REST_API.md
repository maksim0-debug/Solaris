# Solaris Control API v1 — REST Endpoints & Action Control System

This document provides a comprehensive REST endpoint reference for **Solaris Control API v1**, including state query endpoints, Granular Security masking rules (`ApiPermissionsFilter`), per-monitor resolution via Friendly Slugs, and complete documentation for all **26 Action Control System commands** (`POST /api/v1/control`).

---

## 📑 Table of Contents
1. [State Query Endpoints & Granular Data Privacy](#-state-query-endpoints--granular-data-privacy)
   - `GET /api/v1/health` (Unrestricted Liveness Probe)
   - `GET /api/v1/status` (Full State Snapshot & Masking)
   - `GET /api/v1/presets` (Partial Presets Masking)
   - `GET /api/v1/solar`
   - `GET /api/v1/sleep/sessions`
2. [Per-Monitor Endpoints & Slug Resolver](#-per-monitor-endpoints--slug-resolver)
   - `GET /api/v1/monitors`
   - `GET /api/v1/monitors/:slug`
   - `POST /api/v1/monitors/:slug/brightness`
   - `POST /api/v1/monitors/:slug/temperature`
   - `POST /api/v1/monitors/:slug/control`
3. [Action Control System (`POST /api/v1/control`)](#%EF%B8%8F-action-control-system-post-apiv1control)
   - [Single Action vs. Batch Execution](#single-action-vs-batch-execution)
   - [Pre-Flight ACL Batch Pass & Fail-Fast Execution](#pre-flight-acl-batch-pass--fail-fast-execution)
   - [Privilege Escalation Protection](#privilege-escalation-protection)
   - [Catalog of All 26 Action Commands (Mapped to 7 Categories)](#catalog-of-all-26-action-commands)
4. [Webhook & Legacy Sleep Endpoints](#-webhook--legacy-sleep-endpoints)
   - `/api/v1/webhooks*`
   - `/api/sleep/*`

---

## 🔍 State Query Endpoints & Granular Data Privacy

### 1. `GET /api/v1/health`
Lightweight health check endpoint. Useful for liveness probes, load balancers, and status pinging.

* **Authentication**: Not required / Optional.
* **Granular Security Note**: This endpoint is a public **Liveness Probe**. It remains **100% accessible** under all security configurations, even when `isReadOnly = true`, `requireLocalToken = true`, or all read flags are disabled.
* **Response (HTTP 200 OK)**:
```json
{
  "status": "ok",
  "version": "1.2.0",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

---

### 2. `GET /api/v1/status`
Returns the complete application state graph: connected monitors, hardware brightness/temperature readings, active presets, solar elevation/azimuth, weather adjustments, sleep tracking engine status, smart circadian state, and LAN API server configuration.

* **Authentication**: Required (`X-API-Key` or `Authorization: Bearer`). If `requireLocalToken = true` is enabled in GUI, requests without a token (even on `127.0.0.1`) return `HTTP 401 Unauthorized`.
* **Granular Masking Rules (`ApiPermissionsFilter`)**:
  * If `allowReadMonitors = false`: Root section `monitors` is completely omitted.
  * If `allowReadSolar = false`: Root section `solar` is omitted.
  * If `allowReadWeather = false`: Root section `weather` is omitted. All `weather_*` adjustment fields inside `automation` are stripped.
  * If `allowReadSleep = false`: Root section `sleep` is omitted.
  * If `allowReadCircadian = false`: Root section `smart_circadian` is omitted. All `circadian_*` fields inside `automation` are stripped.
  * **Sub-filtering of `smart_circadian`**: When `allowReadCircadian = true` but `allowReadSleep = false`, the `smart_circadian` block remains present with day phases, but sensitive sleep metrics (`sleep_pressure`, `sleep_debt`) and submodules (`sleep_pressure_master`, `sleep_debt_master`) are automatically stripped.
  * If category `system` is disabled in `allowedCategories`: Root section `server` is omitted.

* **Response (HTTP 200 OK)**:
```json
{
  "version": "1.2.0",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-25T14:30:00.000Z",
  "monitors": [
    {
      "id": "\\\\.\\DISPLAY1",
      "name": "LG UltraGear 27GP850",
      "friendly_name": "LG UltraGear A1F9",
      "slug": "display-1",
      "hardware_slug": "lg-ultragear-a1f9",
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
  "automation": {
    "auto_brightness": true,
    "auto_temperature": true,
    "game_mode": false
  },
  "smart_circadian": {
    "enabled": true,
    "current_phase": "day"
  },
  "server": {
    "port": 45321,
    "lan_access_enabled": false
  }
}
```

---

### 3. `GET /api/v1/presets`
Returns all built-in brightness presets, color temperature presets, and custom user-defined presets.

* **Granular Filtering**:
  * If `allowReadMonitors = false`: Section `brightness` is omitted.
  * If `allowReadCircadian = false`: Section `temperature` is omitted.
  * If BOTH `allowReadMonitors = false` AND `allowReadCircadian = false`: Returns `HTTP 403 Forbidden` (`Read Access Prohibited`).

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

* **Granular Security**: Returns `HTTP 403 Forbidden` (`Read Access Prohibited`) if `allowReadSolar = false`.

---

### 5. `GET /api/v1/sleep/sessions`
Returns paginated sleep tracking sessions stored in the SQLite database.

* **Query Parameters**:
  * `limit` (optional, default `10`, max `100`): Number of sessions to return.
  * `offset` (optional, default `0`): Pagination offset.
* **Granular Security**: Returns `HTTP 403 Forbidden` (`Read Access Prohibited`) if `allowReadSleep = false`.
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
1. **Ordinal Slugs**: `display-1`, `display-2`, `display-3` (Recommended)
2. **Friendly Name Slugs**: `lg-ultragear-a1f9`, `dell-u2720q-e34b` (Generated from Monitor Name + 4-char Device ID hash)
3. **Keyword Slugs**: `primary`, `main` (Resolves to primary display), `all` (Targets all displays).

---

### 1. `GET /api/v1/monitors`
Returns a list of all currently connected physical monitors with their calculated slugs.
* **Granular Security**: Rejects with `HTTP 403 Forbidden` if `allowReadMonitors = false`.
* **Per-Monitor Preset Isolation**: Each monitor object inside the `monitors` array returns its specific `active_preset` and `active_user_preset`. When `ALL MONITORS` mode is active, all connected displays automatically synchronize with the unified global preset (`'all'`).

---

### 2. `GET /api/v1/monitors/:slug`
Returns detailed status for a single monitor identified by `:slug` (e.g. `display-1` or `lg-ultragear-a1f9`).
* **Granular Security**: Rejects with `HTTP 403 Forbidden` if `allowReadMonitors = false`.

---

### 3. Point-Mutation Endpoints

> [!IMPORTANT]
> **Payload Field Name**: Point-mutation endpoints require the field name **`"value"`** (number). Passing `"brightness"` or `"temperature"` as key name will result in `HTTP 400 Bad Request`.

* **`POST /api/v1/monitors/:slug/brightness`**: Body `{"value": 75.0}` (double, `0.0..100.0`)
* **`POST /api/v1/monitors/:slug/temperature`**: Body `{"value": 5000}` (integer Kelvin, `3300..6500`)
* **`POST /api/v1/monitors/:slug/control`**: Executes an action command targeting `:slug`. Alias for `POST /api/v1/control` with `monitor_id` pre-filled.
* **Granular Security**: Blocked with `HTTP 403 Forbidden` if `isReadOnly = true` or if category `monitors` is disabled in `allowedCategories`.

#### Example Request:
```http
POST /api/v1/monitors/display-1/brightness HTTP/1.1
Content-Type: application/json
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae

{
  "value": 70.0
}
```

#### Example Response (HTTP 202 Accepted):
```json
{
  "status": "accepted",
  "action": "set_monitor_brightness",
  "slug": "display-1",
  "target_monitor": "\\\\.\\DISPLAY1",
  "queued": {
    "value": 70.0
  },
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

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
* `mode` (string, optional: `"fail_fast"` or `"continue"`, default `"fail_fast"`): Batch execution strategy.
* `fail_fast` (boolean, optional, legacy alias): If `true`, batch execution stops immediately on the first error.

```json
{
  "mode": "fail_fast",
  "actions": [
    { "action": "set_brightness", "value": 75.0 },
    { "action": "set_temperature", "value": 5000 }
  ]
}
```

> [!IMPORTANT]
> **Pre-flight ACL Batch Pass (`mode = "fail_fast"`)**: BEFORE executing any state mutation (`safeStateMutator`), the server performs a Pre-flight ACL pass over the entire `actions` array. If ANY command in the batch belongs to a prohibited category, the **ENTIRE request is rejected immediately with HTTP 403 Forbidden at line 0**, ensuring 100% atomic rollback without partial state application.
> 
> **Mode `"continue"`**: In `continue` mode, prohibited commands return individual `403` error objects in the results array while valid commands execute cleanly.

> [!NOTE]
> **HTTP Status Codes for Actions**:
> Actions that apply hardware-level DDC/CI adjustments or debounced smooth transitions return **`HTTP 202 Accepted`**. Immediate state toggles return **`HTTP 200 OK`**.

### Universal Privilege Escalation Guard
Any request payload containing keys `apiPermissions`, `permissions`, or nested access control toggles is rejected with `HTTP 403 Forbidden` (`Privilege Escalation Prohibited`).

---

### Catalog of All 26 Action Commands

#### 1. `set_brightness`
Sets manual monitor brightness level (0.0 to 100.0%). Automatically disables Auto Brightness.
* **HTTP Status**: `202 Accepted`
* **Permission Category**: `ApiActionCategory.monitors`
* **Fields**: `value` (double, `0.0..100.0`, required), `monitor_id` (string, optional, default `"all"`).
* **Payload**:
```json
{ "action": "set_brightness", "value": 80.0, "monitor_id": "display-1" }
```

#### 2. `set_auto_brightness`
Enables or disables automatic brightness adjustment based on solar/circadian algorithm.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_auto_brightness", "enabled": true }
```

#### 3. `toggle_auto_brightness`
Toggles automatic brightness mode on/off.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Payload**:
```json
{ "action": "toggle_auto_brightness" }
```

#### 4. `set_temperature`
Sets manual color temperature in Kelvin (3300 K to 6500 K). Automatically disables Auto Temperature.
* **HTTP Status**: `202 Accepted`
* **Permission Category**: `ApiActionCategory.monitors`
* **Fields**: `value` (integer Kelvin, `3300..6500`, required), `monitor_id` (string, optional).
* **Payload**:
```json
{ "action": "set_temperature", "value": 4500 }
```

#### 5. `set_color_temperature_enabled`
Master toggle for color temperature software/hardware filtering.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_color_temperature_enabled", "enabled": true }
```

#### 6. `set_auto_temperature`
Enables or disables automatic color temperature curve adjustments.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_auto_temperature", "enabled": true }
```

#### 7. `toggle_auto_temperature`
Toggles automatic color temperature mode on/off.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Payload**:
```json
{ "action": "toggle_auto_temperature" }
```

#### 8. `set_brightness_preset`
Applies a built-in brightness preset.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.presets`
* **Fields**: `preset` (string: `"brightest"`, `"bright"`, `"dim"`, `"dimmest"`, required).
* **Payload**:
```json
{ "action": "set_brightness_preset", "preset": "bright" }
```

#### 9. `set_temperature_preset`
Applies a built-in color temperature preset.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.presets`
* **Fields**: `preset` (string: `"coolest"`, `"cool"`, `"warm"`, `"warmest"`, required).
* **Payload**:
```json
{ "action": "set_temperature_preset", "preset": "warm" }
```

#### 10. `set_user_preset`
Applies a custom user-created preset by ID.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.presets`
* **Fields**: `id` (string, required).
* **Payload**:
```json
{ "action": "set_user_preset", "id": "preset_work_mode" }
```

#### 11. `cycle_preset`
Cycles to the next or previous preset in sequence.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.presets`
* **Fields**: `direction` (string: `"next"` or `"previous"`, optional, default `"next"`).
* **Payload**:
```json
{ "action": "cycle_preset", "direction": "next" }
```

#### 12. `set_game_mode`
Enables or disables Gaming Mode override manually.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.gaming`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_game_mode", "enabled": true }
```

#### 13. `set_game_mode_brightness`
Configures target brightness level applied during Gaming Mode activation.
* **HTTP Status**: `202 Accepted`
* **Permission Category**: `ApiActionCategory.gaming`
* **Fields**: `value` (double, `0.0..100.0`, required).
* **Payload**:
```json
{ "action": "set_game_mode_brightness", "value": 90.0 }
```

#### 14. `manage_game_mode_whitelist`
Adds or removes executable process names from automatic Gaming Mode detection whitelist.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.gaming`
* **Fields**: `op` (string: `"add"` or `"remove"`, required), `app` (string process name e.g. `"cyberpunk2077.exe"`, required).
* **Payload**:
```json
{ "action": "manage_game_mode_whitelist", "op": "add", "app": "cyberpunk2077.exe" }
```

#### 15. `set_monitor_offset`
Applies a relative brightness offset (-50.0% to +50.0%) to a specific monitor.
* **HTTP Status**: `202 Accepted`
* **Permission Category**: `ApiActionCategory.monitors`
* **Fields**: `offset` (double, `-50.0..50.0`, required), `monitor_id` (string, optional).
* **Payload**:
```json
{ "action": "set_monitor_offset", "monitor_id": "display-2", "offset": -10.0 }
```

#### 16. `set_weather_adjustment`
Toggles weather-driven brightness and temperature dynamic compensation.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.environment`
* **Fields**: `brightness` (boolean, optional), `temperature` (boolean, optional).
* **Payload**:
```json
{ "action": "set_weather_adjustment", "brightness": true, "temperature": false }
```

#### 17. `set_weather_temperature_adjustment`
Toggles temperature weather compensation specifically.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.environment`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_weather_temperature_adjustment", "enabled": true }
```

#### 18. `set_weather_intensity`
Configures weather adjustment intensity factor (0.0 to 1.0).
* **HTTP Status**: `202 Accepted`
* **Permission Category**: `ApiActionCategory.environment`
* **Fields**: `value` (double, `0.0..1.0`, required).
* **Payload**:
```json
{ "action": "set_weather_intensity", "value": 0.5 }
```

#### 19. `set_smart_circadian`
Master toggle for Smart Circadian rhythm engine.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
* **Fields**: `enabled` (boolean, required).
* **Payload**:
```json
{ "action": "set_smart_circadian", "enabled": true }
```

#### 20. `set_smart_circadian_submodules`
Toggles individual sub-modules of the Smart Circadian algorithm.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.circadian`
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
* **Permission Category**: `ApiActionCategory.system`
* **Fields**: `rain` (bool), `snow` (bool), `thunder` (bool), `cloud` (bool).
* **Payload**:
```json
{ "action": "set_map_animations", "rain": true, "snow": false }
```

#### 22. `set_manual_location`
Sets manual geographic coordinates for solar calculations.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.environment`
* **Fields**: `latitude` (double, `-90.0..90.0`, required), `longitude` (double, `-180.0..180.0`, required).
* **Payload**:
```json
{ "action": "set_manual_location", "latitude": 50.4501, "longitude": 30.5234 }
```

#### 23. `set_weather_provider`
Configures weather data provider service.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.environment`
* **Fields**: `provider` (string: `"openMeteo"`, `"weatherApi"`, `"auto"`, required).
* **Payload**:
```json
{ "action": "set_weather_provider", "provider": "openMeteo" }
```

#### 24. `trigger_sun_sync`
Forces immediate recalculation and API refetch for solar position and weather.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.environment`
* **Payload**:
```json
{ "action": "trigger_sun_sync" }
```

#### 25. `push_sleep_status`
Pushes sleep state relay status from external tracking applications (e.g. mobile app, smart watch, Home Assistant) without polluting SQLite session history.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.sleep`
* **Fields**: `is_sleeping` (boolean, required).
* **Payload**:
```json
{ "action": "push_sleep_status", "is_sleeping": true }
```

#### 26. `clear_failed_webhooks`
Clears dead-letter queue (DLQ) entries for a specific webhook ID.
* **HTTP Status**: `200 OK`
* **Permission Category**: `ApiActionCategory.system`
* **Fields**: `webhook_id` (string, required).
* **Payload**:
```json
{ "action": "clear_failed_webhooks", "webhook_id": "wh_123456" }
```

---

## 🔔 Webhook & Legacy Sleep Endpoints

### Webhook Management (`/api/v1/webhooks*`)
* `GET /api/v1/webhooks`, `GET /api/v1/webhooks/dlq`: Requires category `system` in `allowedCategories`.
* `POST /api/v1/webhooks`: Creates webhook. Response: `HTTP 201 Created` with body `{"status": "created", "webhook": {...}}`.
* `DELETE /api/v1/webhooks/:id`, `POST /api/v1/webhooks/:id/test`, `POST /api/v1/webhooks/dlq/retry`: Requires `isReadOnly = false` AND category `system`. Rejects with `HTTP 403 Forbidden` if restricted.

### Legacy Sleep Endpoints (`/api/sleep/*`)
* `GET /api/sleep/status`: Requires `allowReadSleep = true`.
* `POST /api/sleep/sessions`, `POST /api/sleep/status`: Requires `isReadOnly = false` and category `sleep` or `system`. Rejects with `HTTP 403 Forbidden` if restricted.
