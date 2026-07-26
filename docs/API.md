# Solaris Control API v1 — Architecture & Core Guide

Welcome to the official developer documentation for **Solaris Control API v1**. This document covers the high-level architecture, security layer, **Multiple Scoped API Keys Architecture**, authentication schemes, **Per-Action Precision & Granular Security Framework**, RFC 7807 error format, rate-limiting, and interactive OpenAPI documentation for Solaris.

---

## 📌 Overview

**Solaris Control API v1** is an embedded, high-performance, asynchronous REST and WebSocket API server built directly into the Solaris Flutter application. It allows third-party integrations (Home Assistant, BitFocus Companion, Stream Deck, Raycast, custom scripts, and external automation services) to monitor and control monitor parameters, color temperature, circadian rhythm engines, gaming profiles, and sleep states.

### Key Architecture Features
* **Zero External Dependencies**: Built directly on `dart:io` `HttpServer` with zero third-party HTTP framework dependencies.
* **Multiple Scoped API Keys Architecture**: Granular per-client authentication keys (`ApiKeyEntry`) with individual names, access scope configurations (`ApiPermissionsConfig`), and DPAPI token security.
* **Per-Action Precision Engine**: Fine-grained access control supporting **25 canonical actions** across 7 categories, 17 alias mappings (`getCanonicalAction`), and Clean Storage Protocol.
* **Tri-State Accordion UI**: Interactive Flutter GUI (`ApiPermissionsDialog`) with `ExpansionTile` accordions, Tri-State master checkboxes (`true`/`false`/`null`), click isolation in `leading`, and dynamic scope chips.
* **Asynchronous Trie-Router**: Fast path-segment matching with support for dynamic path variables (e.g. `:slug`).
* **8-Layer Defense & Isolation Pipeline**: Built-in protection against Host Header Spoofing/DNS Rebinding, Payload Buffer Overflows, Unsupported Media Types, CSWSH (Cross-Site WebSocket Hijacking), Drive-by attacks, and **Granular Zero-Trust ACL Isolation**.
* **Headless-Safe Execution (`safeStateMutator`)**: State mutations are deferred via `Future.microtask()` to avoid Flutter widget rendering cycle conflicts (`setState() or markNeedsBuild() called during build`).
* **OpenAPI 3.0.3 Spec & Swagger UI**: Built-in Swagger UI interactive playground hosted at `/api/v1/docs` with dynamic permission status annotations.

---

## 🔒 Network Modes & Security Architecture

Solaris Control API can operate in two distinct binding modes configurable via application settings:

1. **Localhost Only (Default)**: Bound strictly to loopback interfaces (`127.0.0.1`, `::1`). No external LAN traffic is accepted.
2. **LAN Access Mode**: Bound to `0.0.0.0` or `::` (all network interfaces).
   * Automatically configures Windows Defender Firewall rules via `WindowsFirewallService` with a 3-stage UAC elevation fallback (`netsh` direct -> `powershell -Verb RunAs` -> fallback).
   * All old rules with prefix `Solaris_Control_API_*` are automatically pruned prior to rule updates.

### Local Authorization Requirement (`requireLocalToken`)
By default, anonymous requests from loopback (`127.0.0.1`) are permitted if no key authentication is required. When **"Require Authorization for Local Requests"** (`requireLocalToken = true`) is enabled in the host GUI:
* ALL incoming HTTP and WebSocket requests (including localhost `127.0.0.1`) MUST supply a valid API key token.
* Requests without a token are rejected immediately with `HTTP 401 Unauthorized`.
* Public liveness probe `GET /api/v1/health` remains **100% unrestricted** under all configurations.

---

### 8-Layer Defense Pipeline

Every HTTP and WebSocket request flows sequentially through 8 security layers:

```
[ Incoming Request ]
         │
         ▼
 1. Security Headers Middleware (X-Content-Type-Options, X-Frame-Options, strict CSP for /api/v1/docs)
         │
         ▼
 2. Payload Size Guard (Rejects payloads > 64 KB with HTTP 413)
         │
         ▼
 3. Content-Type Guard (Enforces application/json on POST/PUT/DELETE)
         │
         ▼
 4. Host Header Validation Guard (30s TTL interface cache against DNS Rebinding)
         │
         ▼
 5. CORS & CSWSH / Drive-by Guard (Cross-Origin requests require valid X-API-Key)
         │
         ▼
 6. LruCache Rate Limiter (Per-IP token bucket rate limiting, default 120 req/min)
         │
         ▼
 7. Constant-Time Auth & requireLocalToken Guard (Constant-time SHA-256 token lookup via constantTimeEquals)
         │
         ▼
 8. Granular ACL & Data Privacy Guard (ApiPermissionsChecker & ApiPermissionsFilter per-action scoping)
         │
         ▼
[ Route Handler / Controller ]
```

---

## 🛡️ Granular Security & Per-Action Precision Framework

Solaris Control API v1 incorporates an enterprise-grade Zero-Trust access control system (`ApiPermissionsConfig`) configured locally per-key via the Flutter GUI (`ApiKeysManagementDialog` & `ApiPermissionsDialog`).

### 1. Data Sharing Flags (Read Permissions)
Controls visibility of telemetry and subsystem data in `GET /api/v1/status`, queries, and WebSocket streaming:
* `allowReadMonitors`: Physical monitor metadata, brightness & color temperature readings.
* `allowReadSolar`: Solar elevation, azimuth, zenith angle, day phase, and twilight events.
* `allowReadWeather`: Weather condition, temperature, and intensity adjustments.
* `allowReadSleep`: Asleep/awake status, last session end, and historical sleep records.
* `allowReadCircadian`: Smart Circadian phase tracking and auto-adjustment parameters.

> [!NOTE]
> **Granular Masking (`ApiPermissionsFilter`)**: Disabling a read flag automatically redacts the corresponding root section and performs key-level masking on composite objects (`automation`, `smart_circadian`, `presets`). For example, when `allowReadSleep = false`, sleep metrics (`sleep_pressure`, `sleep_debt`) are automatically pruned from `smart_circadian` without stripping circadian day-phase info.

### 2. Per-Action Precision (25 Canonical Actions & 7 Categories)
In addition to 7 high-level categories (`allowedCategories`), permissions can be constrained to **25 fine-grained canonical actions** (`allowedActions` set):

| Category (`ApiActionCategory`) | Actions Count | Canonical Action Keys (`allowedActions`) |
| :--- | :---: | :--- |
| **`monitors`** | 3 | `set_brightness`, `set_temperature`, `set_monitor_offset` |
| **`presets`** | 4 | `set_brightness_preset`, `set_temperature_preset`, `set_user_preset`, `cycle_preset` |
| **`circadian`** | 4 | `set_auto_brightness`, `set_auto_temperature`, `set_smart_circadian`, `set_smart_circadian_submodules` |
| **`gaming`** | 3 | `set_game_mode`, `set_game_mode_brightness`, `manage_game_mode_whitelist` |
| **`environment`** | 6 | `set_weather_adjustment`, `set_weather_temperature_adjustment`, `set_weather_intensity`, `set_manual_location`, `set_weather_provider`, `trigger_sun_sync` |
| **`sleep`** | 1 | `push_sleep_status` |
| **`system`** | 4 | `manage_webhooks`, `set_map_animations`, `on_system_resume`, `on_hardware_error` |

### 3. Alias Normalization Table (`getCanonicalAction`)
Incoming requests (REST API, WebSocket commands, or internal triggers) undergo automatic alias canonicalization before permission evaluation:

| Incoming Action / Alias | Canonical Action Key | Parent Category |
| :--- | :--- | :--- |
| `set_monitor_brightness` | `set_brightness` | `monitors` |
| `set_monitor_temperature` | `set_temperature` | `monitors` |
| `brightest`, `bright`, `dim`, `dimmest` | `set_brightness_preset` | `presets` |
| `coolest`, `cool`, `warm`, `warmest` | `set_temperature_preset` | `presets` |
| `toggle_auto_brightness` | `set_auto_brightness` | `circadian` |
| `toggle_auto_temperature`, `set_color_temperature_enabled` | `set_auto_temperature` | `circadian` |
| `openmeteo`, `weatherapi`, `auto` | `set_weather_provider` | `environment` |
| `clear_failed_webhooks` | `manage_webhooks` | `system` |

### 4. Clean Storage Protocol (Auto-Reset to Null)
To maintain 100% backward compatibility and minimal storage footprint:
* When `allowedActions` contains all 25 canonical actions, `toJson()` automatically omits `allowedActions` (`allowedActions = null`).
* `fromJson()` automatically converts a full 25-action set back into `null`.
* `allowedActions == null` represents full standard permission for all actions within enabled categories.

### 5. Tri-State Accordion GUI Architecture
The Flutter GUI (`ApiPermissionsDialog`) renders permissions using a 2-level Accordion UI:
* **7 Category Accordions (`ExpansionTile`)**: Each category header features a Tri-State master checkbox:
  * `true` (Checked 🟢): All canonical actions of this category are explicitly granted.
  * `false` (Unchecked ⚪): Category is disabled (`allowedCategories` does not contain category).
  * `null` (Indeterminate / Dash 🟠): Category enabled, `allowedActions == null` (inherit default full access).
* **Click Isolation in `leading`**: Tapping the master checkbox in `leading` is wrapped in `GestureDetector`/`InkWell` to prevent unintended expansion/collapsing of the accordion body.
* **Scope Summary Chips (`apiKeysGranularActionChip`)**: In `ApiKeysManagementDialog`, keys display green `"7 of 7 categories"` chips when `allowedActions == null`, or orange `"Allowed N of 25 actions"` chips when a granular subset ($N < 25$) is configured.
* **Localization (EN / RU / UK)**: All 25 actions are fully localized in `app_en.arb`, `app_ru.arb`, and `app_uk.arb`.

### 6. Read-Only Mode (`isReadOnly`)
When `isReadOnly = true` is enabled for a specific key or globally:
* ALL mutation attempts (`POST /api/v1/control`, `POST /api/v1/monitors/:slug/*`, `POST /api/v1/webhooks*`, `POST /api/sleep/*`) are immediately rejected with `HTTP 403 Forbidden` (`Read-Only Mode Enabled`).
* Public liveness probe `GET /api/v1/health` remains 100% accessible.

### 7. Universal Privilege Escalation Guard
To prevent external API clients or WebSocket payloads from tampering with permission configurations, `ApiControlHandler` enforces an immediate rejection rule:
* Any mutation payload containing `apiPermissions` or permission keys is rejected with `HTTP 403 Forbidden` (`Privilege Escalation Prohibited`).
* API permissions can ONLY be modified locally by the host user via the Flutter GUI `ApiPermissionsDialog`.

---

## 🔑 Multiple Scoped API Keys System

Solaris manages access tokens through a **Multiple Scoped API Keys System** (`ApiKeyEntry`). Each key possesses an isolated security context and granular scope.

### Key Attributes (`ApiKeyEntry`)
* `id`: Unique string identifier (e.g. `key_1721800000123`).
* `name`: Custom human-readable label (e.g. `"Home Assistant Key"`, `"Stream Deck"`). Max 50 chars, auto-trimmed.
* `token`: Cryptographically secure random token starting with prefix `sol_sec_` (68 characters total).
* `createdAt`: UTC timestamp of creation.
* `lastUsedAt`: UTC timestamp of most recent successful request execution.
* `permissions`: Independent `ApiPermissionsConfig` instance controlling read flags and mutation categories.

### Single Key Protection Guard
To prevent accidental total lockout, Solaris enforces a strict Single Key Protection Guard:
* The system WILL NOT allow deleting or revoking the sole remaining API key in the application.
* Attempts to delete the final key via Notifier or GUI are rejected with `SingleKeyProtectionException`, and the delete icon 🗑️ is disabled in the GUI.

### Windows DPAPI Storage & Fallback Banner
* On Windows, API keys are encrypted at rest using DPAPI (`crypt32.dll`) via `win32` API bindings.
* If a Windows user password change prevents DPAPI decryption, Solaris safely regenerates fallback key structures and displays an un-dismissible orange warning banner (`ApiSettingsCard`) until acknowledged by the user.

---

## 🌐 Passing Auth Tokens

Tokens can be passed using any of the following standard methods:

### 1. HTTP Request Header (Recommended for REST)
```http
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae
```
or standard HTTP Bearer token:
```http
Authorization: Bearer sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae
```

### 2. URL Query Parameter (Recommended for WebSocket / Simple Scripts)
```http
GET /api/v1/status?token=sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae HTTP/1.1
```

### 3. WebSocket Subprotocol Header
```http
Sec-WebSocket-Protocol: bearer.sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae
```

> [!IMPORTANT]
> **Constant-Time Verification**: Auth checks perform a SHA-256 `constantTimeEquals` hash comparison across all stored keys to protect against timing side-channel attacks. Rejections trigger `HTTP 401 Unauthorized` responses.

---

## ⚡ WebSocket Disconnect & Revocation Status Codes

When WebSocket sessions end, Solaris transmits explicit status codes:

| Code | Reason String | Trigger Condition |
| :--- | :--- | :--- |
| `1000` | Normal Closure | Client gracefully disconnected. |
| `1001` | `Solaris API Server Stopping` | Host user turned off Control API server in GUI. |
| `1008` | `Slow Consumer OOM Guard` | Unconsumed client frame buffer exceeded 512 KB threshold. |
| `4001` | `Key Revoked` | Host user revoked/deleted the key associated with this connection. |
| `4001` | `Token Regenerated` | Host user regenerated the secret token for this key. |
| `4001` | `Local Auth Required` | Host user enabled `requireLocalToken = true` while an anonymous socket was open. |

---

## ⚠️ Standard Error Format (RFC 7807)

All non-2xx responses from Solaris Control API return `application/problem+json` formatted strictly according to [RFC 7807 (Problem Details for HTTP APIs)](https://tools.ietf.org/html/rfc7807).

### Error Schema Example
```json
{
  "type": "https://solaris.local/errors/access-denied",
  "title": "Action Category Prohibited",
  "status": 403,
  "detail": "Action category \"gaming\" is disabled in API permissions settings.",
  "instance": "/api/v1/control",
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

### Common HTTP Error Statuses

| HTTP Status | Error Type Slug | Description |
| :--- | :--- | :--- |
| `400 Bad Request` | `/errors/bad-request` | Invalid JSON syntax or missing required field (e.g. `'value'`). |
| `401 Unauthorized` | `/errors/unauthorized` | Missing, empty, or invalid API access token (or `requireLocalToken` enforced). |
| `403 Forbidden` | `/errors/access-denied` | Mutation disabled by Read-Only mode, category prohibited, or Privilege Escalation Guard. |
| `403 Forbidden` | `/errors/drive-by-blocked` | Untrusted Origin/Referer header without valid API token (Drive-by protection). |
| `404 Not Found` | `/errors/not-found` | Unknown endpoint or requested monitor slug/ID was not found. |
| `413 Payload Too Large`| `/errors/payload-too-large`| Request body exceeds 64 KB (65,536 bytes). |
| `415 Unsupported Media`| `/errors/unsupported-media-type`| Mutating request (POST) sent without `Content-Type: application/json`. |
| `422 Unprocessable` | `/errors/unprocessable-entity` | Invalid parameter values or unknown action command name. |
| `429 Too Many Requests`| `/errors/rate-limit-exceeded`| Rate limit quota exceeded (per-IP limit). |
| `500 Internal Error` | `/errors/internal-server-error`| Unexpected internal server exception. |

---

## 📖 Interactive Documentation & OpenAPI 3.0.3

Solaris Control API embeds an interactive **Swagger UI** endpoint and an **OpenAPI 3.0.3 JSON Spec** generator.

* **Swagger UI Documentation**: `GET http://localhost:45321/api/v1/docs`
* **OpenAPI 3.0.3 JSON Spec**: `GET http://localhost:45321/api/v1/openapi.json`

The Swagger UI allows developers to inspect models, view interactive request schemas, and execute API calls directly from their browser.

> [!NOTE]
> **Dynamic OpenAPI Generation**: `OpenApiSpec.generateSpec` dynamically reflects active API permissions. Restricted endpoints automatically display `403 Forbidden` response schemas, and mutation endpoints reflect `[READ-ONLY MODE ACTIVE]` annotations when Read-Only mode is enabled in GUI.
