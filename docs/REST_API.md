# Solaris Control API v1 — REST Endpoints & Action Control System

This document provides a comprehensive REST endpoint reference for **Solaris Control API v1**, including state query endpoints, Granular Security masking rules (`ApiPermissionsFilter`), per-monitor resolution via Friendly Slugs, and complete documentation for all **28 Action Control System commands** (`POST /api/v1/control`).

---

## 📑 Table of Contents
1. [State Query Endpoints & Granular Data Privacy](#-state-query-endpoints--granular-data-privacy)
   - `GET /api/v1/health` (Unrestricted Liveness Probe)
   - `GET /api/v1/status` (Full State Snapshot & Masking)
   - `GET /api/v1/presets` (Partial Presets Masking)
   - `GET /api/v1/solar`
   - `GET /api/v1/sleep/sessions`
   - `GET /api/v1/docs` (Interactive RapiDoc Playground)
   - `GET /api/v1/openapi.json` (Dynamic OpenAPI 3.0.3 Spec)
2. [Per-Monitor Endpoints & Slug Resolver](#-per-monitor-endpoints--slug-resolver)
   - `GET /api/v1/monitors`
   - `GET /api/v1/monitors/:slug`
   - `POST /api/v1/monitors/:slug/brightness`
   - `POST /api/v1/monitors/:slug/temperature`
3. [Per-App Overrides Endpoints (`/api/v1/app-overrides`)](#-per-app-overrides-endpoints-apiv1app-overrides)
   - `GET /api/v1/app-overrides`
   - `GET /api/v1/app-overrides/active`
   - `POST /api/v1/app-overrides`
   - `DELETE /api/v1/app-overrides/:exe`
   - `POST /api/v1/app-overrides/reset-builtin`
4. [Action Control System (`POST /api/v1/control`)](#%EF%B8%8F-action-control-system-post-apiv1control)
   - [Single Action vs. Batch Execution](#single-action-vs-batch-execution)
   - [Pre-Flight ACL Batch Pass & Fail-Fast Execution](#pre-flight-acl-batch-pass--fail-fast-execution)
   - [Privilege Escalation Protection](#privilege-escalation-protection)
   - [Catalog of All 28 Canonical Action Commands](#catalog-of-all-28-canonical-action-commands)
5. [Webhook & Sleep Integration Endpoints](#-webhook--sleep-integration-endpoints)
   - `/api/v1/webhooks*`
   - `GET /api/v1/webhooks/events`
   - `/api/v1/sleep/*` & `/api/sleep/*`

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
  "version": "1.3.2+1",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-25T14:30:00.000Z",
  "subsystems": {
    "solaris_control": true,
    "sleep_integration": true
  }
}
```

* **Subsystems Breakdown (`subsystems`)**:
  * `solaris_control`: Indicates whether Solaris Control API endpoints (`/api/v1/control`, `/api/v1/monitors`, etc.) are currently enabled.
  * `sleep_integration`: Indicates whether Sleep Integration API endpoints (`/api/sleep/*`, `/api/v1/sleep/*`) are currently enabled.
  * If a subsystem is toggled off in the application settings, calling its endpoints yields `HTTP 503 Service Unavailable` (RFC 7807), while `/api/v1/health` remains healthy (`200 OK`).

---

### 2. `GET /api/v1/status`
Returns the complete application state graph: connected monitors, hardware brightness/temperature readings, active presets, solar elevation/azimuth, weather adjustments, sleep tracking engine status, smart circadian state, and LAN API server configuration.

* **Authentication**: Required (`X-API-Key` or `Authorization: Bearer`).
* **Granular Masking Rules (`ApiPermissionsFilter`)**:
  * If `allowReadMonitors = false`: Root section `monitors` is omitted.
  * If `allowReadSolar = false`: Root section `solar` is omitted.
  * If `allowReadWeather = false`: Root section `weather` is omitted. All `weather_*` adjustment fields inside `automation` are stripped.
  * If `allowReadSleep = false`: Root section `sleep` is omitted.
  * If `allowReadCircadian = false`: Root section `smart_circadian` is omitted. All `circadian_*` fields inside `automation` are stripped.
  * **Sub-filtering of `smart_circadian`**: When `allowReadCircadian = true` but `allowReadSleep = false`, the `smart_circadian` block remains present with day phases, but sensitive sleep metrics (`sleep_pressure`, `sleep_debt`) are stripped.
  * If category `system` is disabled in `allowedCategories`: Root section `server` is omitted.

* **Response (HTTP 200 OK)**:
```json
{
  "version": "1.3.2+1",
  "uptime_seconds": 14250,
  "timestamp": "2026-07-25T14:30:00.000Z",
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
    "available": true,
    "cloud_cover": 20,
    "temperature_celsius": 24.5,
    "weather_code": 0,
    "uv_index": 4.2,
    "provider": "auto"
  },
  "monitors": [
    {
      "id": "\\\\.\\DISPLAY1",
      "name": "LG UltraGear 27GP850",
      "friendly_name": "LG UltraGear A1F9",
      "slug": "display-1",
      "device_id_hash": "a1f9",
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
  "automation": {
    "auto_brightness": true,
    "auto_temperature": true,
    "color_temperature_hardware_enabled": true,
    "weather_brightness_adjustment": true,
    "weather_temperature_adjustment": true,
    "weather_adjustment_intensity": 0.45,
    "smart_circadian": true,
    "game_mode": {
      "enabled": true,
      "active": false,
      "brightness_override": 80.0,
      "temperature_enabled": true,
      "temperature_override": 6500.0,
      "whitelist_count": 5,
      "blacklist_count": 0
    },
    "multi_monitor_offset": false,
    "map_animations": {
      "rain": true,
      "snow": true,
      "thunder": true,
      "cloud": true
    }
  },
  "smart_circadian": {
    "master_enabled": true,
    "submodules": {
      "wind_down_master": true,
      "time_shift_master": true,
      "sleep_pressure_master": true,
      "sleep_debt_master": true
    },
    "wind_down": { "active": false, "impact_brightness": 0.0, "impact_temperature": 0 },
    "sleep_pressure": { "active": false, "impact_brightness": 0.0, "impact_temperature": 0 },
    "sleep_debt": { "active": false, "impact_brightness": 0.0, "impact_temperature": 0 },
    "time_shift": { "active": false, "offset_minutes": 0 }
  },
  "sleep": {
    "is_sleeping": false,
    "sessions_count": 12,
    "last_session_end": "2026-07-24T06:30:00.000Z"
  },
  "server": {
    "port": 45321,
    "bind_address": "127.0.0.1",
    "lan_access": false,
    "rate_limit_per_minute": 120
  }
}
```

---

### 3. `GET /api/v1/presets`
Returns all built-in brightness presets, color temperature presets, active preset selections, and custom user-defined presets.

* **Granular Filtering**:
  * If `allowReadMonitors = false`: Section `brightness` is omitted.
  * If `allowReadCircadian = false`: Section `temperature` is omitted.
  * If BOTH `allowReadMonitors = false` AND `allowReadCircadian = false`: Returns `HTTP 403 Forbidden`.

* **Response (HTTP 200 OK)**:
```json
{
  "brightness": {
    "system": ["brightest", "bright", "dim", "dimmest"],
    "user": [
      { "id": "preset_172180000", "name": "Work Mode", "active": false }
    ],
    "active": {
      "type": "system",
      "name": "bright"
    }
  },
  "temperature": {
    "system": ["coolest", "cool", "warm", "warmest"],
    "user": [],
    "active": {
      "type": "system",
      "name": "cool"
    }
  }
}
```

---

### 4. `GET /api/v1/solar`
Returns real-time solar tracking parameters, elevation, azimuth, zenith angle, day phase, upcoming solar events, and trends.

* **Granular Security**: Returns `HTTP 403 Forbidden` if `allowReadSolar = false`.
* **Response (HTTP 200 OK)**:
```json
{
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
  "spectral_intensity": 0.88,
  "trends": {
    "elevation": 0.05,
    "azimuth": 0.12,
    "zenith": -0.05
  }
}
```

---

### 5. `GET /api/v1/sleep/sessions`
Returns paginated sleep tracking sessions stored in memory/database.

* **Query Parameters**:
  * `limit` (optional, default `50`, range `1..200`): Number of sessions to return.
  * `offset` (optional, default `0`): Pagination offset.
  * `from` (optional, ISO-8601 DateTime): Filter sessions starting from date.
  * `to` (optional, ISO-8601 DateTime): Filter sessions starting before date.
* **Granular Security**: Returns `HTTP 403 Forbidden` if `allowReadSleep = false`.
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
      "source": "auto"
    }
  ]
}
```

---

### 6. `GET /api/v1/docs`
Hosts the embedded interactive **RapiDoc** HTML playground (`<rapi-doc>`).
* **Authentication**: Not required / Public.
* **Security Headers**: Served with strict Content Security Policy (`script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com`).
* **Response (HTTP 200 OK)**: Returns HTML content rendering the interactive documentation UI.

---

### 7. `GET /api/v1/openapi.json`
Generates a dynamic **OpenAPI 3.0.3 Specification** JSON document.
* **Authentication**: Not required / Public.
* **Dynamic Scoping**: Automatically annotates endpoint descriptions and ACL requirements based on the active API permission configuration.
* **Response (HTTP 200 OK)**: Returns complete OpenAPI 3.0.3 JSON schema.

---

## 🖥️ Per-Monitor Endpoints & Slug Resolver

Solaris Control API features a **Friendly Slug Resolver** (`MonitorSlugResolver`) allowing monitors to be targeted by easy-to-read identifiers instead of long Windows device paths (`\\\\.\\DISPLAY1`).

### Supported Slug Matchers:
1. **Ordinal Slugs**: `display-1`, `display-2`, `display-3` (Recommended)
2. **Friendly Name Slugs**: `lg-ultragear-a1f9`, `dell-u2720q-e34b`
3. **Keyword Slugs**: `primary`, `main` (Resolves to primary display), `all` (Targets all displays).

---

### 1. `GET /api/v1/monitors`
Returns a list of all currently connected physical monitors.
* **Granular Security**: Rejects with `HTTP 403 Forbidden` if `allowReadMonitors = false`.
* **Response (HTTP 200 OK)**:
```json
{
  "count": 1,
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
        "active_preset": "cool"
      },
      "game_mode": {
        "enabled": true,
        "active": false
      }
    }
  ],
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

---

### 2. `GET /api/v1/monitors/:slug`
Returns status summary for a single monitor identified by `:slug`.
* **Granular Security**: Rejects with `HTTP 403 Forbidden` if `allowReadMonitors = false`.
* **Response (HTTP 200 OK)**:
```json
{
  "id": "\\\\.\\DISPLAY1",
  "name": "LG UltraGear 27GP850",
  "friendly_name": "LG UltraGear A1F9",
  "is_primary": true,
  "real_brightness": 80,
  "real_temperature": 5500,
  "brightness_offset": 0.0,
  "smart_circadian_enabled": true,
  "weather_adjustment_enabled": true,
  "game_mode": {
    "enabled": true,
    "active": false
  },
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

---

### 3. Point-Mutation Endpoints

* **`POST /api/v1/monitors/:slug/brightness`**: Body `{"value": 75.0}` (double, `0.0..100.0`)
* **`POST /api/v1/monitors/:slug/temperature`**: Body `{"value": 5000}` (integer Kelvin, `3300..6500`)
* **`POST /api/v1/monitors/:slug/game-mode`**: Body `{"enabled": true}` (boolean)
* **Granular Security**: Blocked with `HTTP 403 Forbidden` if `isReadOnly = true` or category `monitors` / `gaming` is disabled.

#### Example Request:
```http
POST /api/v1/monitors/display-1/brightness HTTP/1.1
Content-Type: application/json
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567

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

#### Example Game Mode Request:
```http
POST /api/v1/monitors/display-2/game-mode HTTP/1.1
Content-Type: application/json
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567

{
  "enabled": false
}
```

#### Example Game Mode Response (HTTP 200 OK):
```json
{
  "status": "ok",
  "action": "set_monitor_game_mode",
  "slug": "display-2",
  "target_monitor": "\\\\.\\DISPLAY2",
  "game_mode": {
    "enabled": false
  },
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

---

## 🎯 Per-App Overrides Endpoints (`/api/v1/app-overrides`)

### 1. `GET /api/v1/app-overrides`
Returns all configured per-application override rules and hold interval.

### 2. `GET /api/v1/app-overrides/active`
Queries the current foreground Win32 process, window title, game status, applied profile rule, and evaluated brightness/temperature state.

* **Response (HTTP 200 OK)**:
```json
{
  "active_process": "photoshop.exe",
  "window_title": "Adobe Photoshop 2026",
  "is_gaming": false,
  "applied_override": {
    "exeName": "photoshop.exe",
    "appDisplayName": "Adobe Photoshop",
    "isEnabled": true,
    "isBuiltIn": true,
    "brightnessMode": "global",
    "temperatureMode": "fixed",
    "fixedTemperature": 6500.0
  },
  "evaluated_brightness": 80.0,
  "evaluated_temperature": 6500.0
}
```

### 3. `POST /api/v1/app-overrides`
Creates or updates a per-application override rule (`AppOverrideRule`).

* **Validation & Security Rules (`ApiAppOverridesHandler`)**:
  * `exeName` MUST be a valid executable filename matching regex `^[a-z0-9_\-\.]+\.exe$` (e.g. `photoshop.exe`, `game_client.exe`).
  * **Path Traversal Guard**: Any `exeName` containing path traversal sequences (`/`, `\`, `..`) is rejected immediately with `HTTP 400 Bad Request`.

### 4. `DELETE /api/v1/app-overrides/:exe`
Removes a custom per-application override rule by executable name. Enforces the same Path Traversal and filename regex validation.

### 5. `POST /api/v1/app-overrides/reset-builtin`
Restores factory built-in app override rules to their default settings.

---

## ⚙️ Action Control System (`POST /api/v1/control`)

The Action Control System provides a unified mutation gateway supporting **28 canonical action types** and **17 convenience aliases**.

### Single Action vs. Batch Execution

#### Batch Execution Payload:
* `actions` (array of action objects): List of actions to execute sequentially.
* `mode` (string, optional: `"fail_fast"` or `"continue"`, default `"fail_fast"`).

```json
{
  "mode": "fail_fast",
  "actions": [
    { "action": "set_brightness", "value": 75.0 },
    { "action": "set_temperature", "value": 5000 }
  ]
}
```

---

### Catalog of All 28 Canonical Action Commands

Below is the complete reference of all 28 canonical action commands supported by `POST /api/v1/control`, grouped into 7 permission categories.

#### Category 1: `monitors` (3 Actions)
* **`set_brightness`** (Alias: `set_monitor_brightness`)
  * **Payload**: `{"action": "set_brightness", "value": 80.0, "monitor_id": "display-1"}`
  * **Parameters**: `value` (double, `0.0..100.0`), `monitor_id` / `slug` (optional string target display).
* **`set_temperature`** (Alias: `set_monitor_temperature`)
  * **Payload**: `{"action": "set_temperature", "value": 5500, "monitor_id": "display-1"}`
  * **Parameters**: `value` (integer Kelvin, `3300..6500`), `monitor_id` / `slug` (optional).
* **`set_monitor_offset`**
  * **Payload**: `{"action": "set_monitor_offset", "offset": -10.0, "monitor_id": "display-2"}`
  * **Parameters**: `offset` (double, `-50.0..+50.0`), `monitor_id` / `slug` (required).

#### Category 2: `presets` (7 Actions)
* **`set_brightness_preset`** (Aliases: `brightest`, `bright`, `dim`, `dimmest`)
  * **Payload**: `{"action": "set_brightness_preset", "preset": "bright"}`
  * **Parameters**: `preset` (string: `"brightest"`, `"bright"`, `"dim"`, `"dimmest"`).
* **`set_temperature_preset`** (Aliases: `coolest`, `cool`, `warm`, `warmest`)
  * **Payload**: `{"action": "set_temperature_preset", "preset": "cool"}`
  * **Parameters**: `preset` (string: `"coolest"`, `"cool"`, `"warm"`, `"warmest"`).
* **`set_user_preset`**
  * **Payload**: `{"action": "set_user_preset", "id": "preset_172180000"}`
  * **Parameters**: `id` (string).
* **`cycle_preset`**
  * **Payload**: `{"action": "cycle_preset", "direction": "next"}`
  * **Parameters**: `direction` (`"next"` | `"previous"`). *Note: The `type` key is ignored by the backend engine; it always cycles brightness presets.*
* **`get_app_overrides`**
  * Handled via `GET /api/v1/app-overrides`.
* **`manage_app_overrides`**
  * Handled via `POST /api/v1/app-overrides` or `DELETE /api/v1/app-overrides/:exe`.
* **`reset_builtin_app_overrides`**
  * Handled via `POST /api/v1/app-overrides/reset-builtin`.

#### Category 3: `circadian` (4 Actions)
* **`set_auto_brightness`** (Alias: `toggle_auto_brightness`)
  * **Payload**: `{"action": "set_auto_brightness", "enabled": true}`
  * **Parameters**: `enabled` (boolean).
* **`set_auto_temperature`** (Aliases: `toggle_auto_temperature`, `set_color_temperature_enabled`)
  * **Payload**: `{"action": "set_auto_temperature", "enabled": true}`
  * **Parameters**: `enabled` (boolean).
* **`set_smart_circadian`**
  * **Payload**: `{"action": "set_smart_circadian", "enabled": true}`
  * **Parameters**: `enabled` (boolean).
* **`set_smart_circadian_submodules`**
  * **Payload**: `{"action": "set_smart_circadian_submodules", "wind_down": true, "time_shift": true, "sleep_pressure": true, "sleep_debt": true}`
  * **Parameters**: Submodule boolean flags.

#### Category 4: `gaming` (3 Actions)
* **`set_game_mode`**
  * **Payload**: `{"action": "set_game_mode", "enabled": true, "monitor": "display-1"}`
  * **Parameters**: `enabled` (boolean, required), `monitor` / `monitor_id` (string, optional - `"all"`, `"primary"`, `"display-1"`, etc.).
* **`set_game_mode_brightness`**
  * **Payload**: `{"action": "set_game_mode_brightness", "value": 85.0}`
  * **Parameters**: `value` (double, `0.0..100.0`).
* **`manage_game_mode_whitelist`**
  * **Payload**: `{"action": "manage_game_mode_whitelist", "op": "add", "app": "cyberpunk2077.exe"}`
  * **Parameters**: `op` (`"add"` or `"remove"`), `app` (string executable filename).

#### Category 5: `environment` (6 Actions)
* **`set_weather_adjustment`**
  * **Payload**: `{"action": "set_weather_adjustment", "brightness": true, "temperature": true}`
  * **Parameters**: `brightness` (boolean), `temperature` (boolean).
* **`set_weather_temperature_adjustment`**
  * **Payload**: `{"action": "set_weather_temperature_adjustment", "enabled": true}`
  * **Parameters**: `enabled` (boolean).
* **`set_weather_intensity`**
  * **Payload**: `{"action": "set_weather_intensity", "value": 0.5}`
  * **Parameters**: `value` (double, `0.0..1.0`).
* **`set_manual_location`**
  * **Payload**: `{"action": "set_manual_location", "latitude": 50.4501, "longitude": 30.5234, "city": "Kyiv"}`
  * **Parameters**: `latitude` (double), `longitude` (double), `city` (string).
* **`set_weather_provider`** (Aliases: `openmeteo`, `weatherapi`, `auto`)
  * **Payload**: `{"action": "set_weather_provider", "provider": "auto"}`
  * **Parameters**: `provider` (string: `"auto"`, `"openmeteo"`, `"weatherapi"`).
* **`trigger_sun_sync`**
  * **Payload**: `{"action": "trigger_sun_sync"}`

#### Category 6: `sleep` (1 Action)
* **`push_sleep_status`**
  * **Payload**: `{"action": "push_sleep_status", "is_sleeping": true}`
  * **Parameters**: `is_sleeping` (boolean).

#### Category 7: `system` (4 Actions)
* **`manage_webhooks`** (Alias: `clear_failed_webhooks`)
  * **Payload**: `{"action": "manage_webhooks", "sub_action": "clear_failed", "webhook_id": "wh_123"}`
  * **Parameters**: `sub_action` / `webhook_id`.
* **`set_map_animations`**
  * **Payload**: `{"action": "set_map_animations", "rain": true, "snow": true, "thunder": true, "cloud": true}`
  * **Parameters**: Animation boolean flags.
* **`on_system_resume`**
  * Internal event signal triggered when the OS resumes from sleep. *(Dispatched via EventBus / WebSockets).*
* **`on_hardware_error`**
  * Internal event signal triggered on DDC/CI read/write errors. *(Dispatched via EventBus / WebSockets).*

## 🔔 Webhook & Sleep Integration Endpoints

### Webhook Management (`/api/v1/webhooks*`)
* `GET /api/v1/webhooks`, `GET /api/v1/webhooks/dlq`
* `GET /api/v1/webhooks/events`: Returns all available event type identifiers.
* `POST /api/v1/webhooks`: Creates webhook.
* `DELETE /api/v1/webhooks/:id`, `POST /api/v1/webhooks/:id/test`, `POST /api/v1/webhooks/dlq/retry`.

### Sleep Integration Endpoints (`/api/v1/sleep/*` & `/api/sleep/*`)
Solaris exposes canonical `/api/v1/sleep/*` endpoints while maintaining legacy `/api/sleep/*` aliases for 100% backward compatibility with external integrations (Sleep as Android, Tasker, automation scripts):

> [!NOTE]
> **Decoupled Subsystem Lifecycle**: Sleep endpoints (`/api/v1/sleep/*` and legacy `/api/sleep/*`) are governed independently via the **Sleep Integration API** switch on the "Sleep" screen. If disabled, they return RFC 7807 `503 Service Unavailable` (`Sleep Integration API Disabled`). Disabling the general Solaris Control API in Settings does NOT deactivate or interfere with Sleep API endpoints.

* **`GET /api/v1/sleep/status`** (Alias: `GET /api/sleep/status`): Returns current sleep tracking state.
  * **ACL**: Requires `allowReadSleep = true`.
  * **Response (HTTP 200 OK)**:
    ```json
    {
      "status": "success",
      "is_sleeping": false,
      "sessions_count": 12,
      "last_fetch": "2026-07-24T06:30:00.000Z"
    }
    ```
* **`POST /api/v1/sleep/status`** (Alias: `POST /api/sleep/status`): Updates sleep tracking state.
  * **ACL**: Requires category `sleep` and action `push_sleep_status`.
  * **Payload**: `{"is_sleeping": true}`
  * **Response (HTTP 200 OK)**: `{"status": "success"}`
* **`POST /api/v1/sleep/sessions`** (Alias: `POST /api/sleep/sessions`): Pushes external sleep sessions array.
  * **ACL**: Requires category `sleep` and action `push_sleep_status`.
  * **Payload**: `[{"id": "session_123", "start_time": "...", "end_time": "...", "duration_minutes": 480}]`
  * **Response (HTTP 200 OK)**: `{"status": "success"}`
* **`GET /api/v1/sleep/sessions`** (Alias: `GET /api/sleep/sessions`): Returns paginated sleep history (see [State Query Endpoints](#5-get-apiv1sleepsessions)).
