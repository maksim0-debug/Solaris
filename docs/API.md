# Solaris Control API v1 — Architecture & Core Guide

Welcome to the official developer documentation for **Solaris Control API v1**. This document covers the high-level architecture, security layer, authentication schemes, **Granular Security & Data Privacy Framework**, RFC 7807 error format, rate-limiting, and interactive OpenAPI documentation for Solaris.

---

## 📌 Overview

**Solaris Control API v1** is an embedded, high-performance, asynchronous REST and WebSocket API server built directly into the Solaris Flutter application. It allows third-party integrations (Home Assistant, BitFocus Companion, Stream Deck, Raycast, custom scripts, and external automation services) to monitor and control monitor parameters, color temperature, circadian rhythm engines, gaming profiles, and sleep states.

### Key Architecture Features
* **Zero External Dependencies**: Built directly on `dart:io` `HttpServer` with zero third-party HTTP framework dependencies.
* **Asynchronous Trie-Router**: Fast path-segment matching with support for dynamic path variables (e.g. `:slug`).
* **7-Layer Defense & Isolation Pipeline**: Built-in protection against Host Header Spoofing/DNS Rebinding, Payload Buffer Overflows, Unsupported Media Types, CSWSH (Cross-Site WebSocket Hijacking), Drive-by attacks, and **Granular Zero-Trust ACL Isolation**.
* **Headless-Safe Execution (`safeStateMutator`)**: State mutations are deferred via `Future.microtask()` to avoid Flutter widget rendering cycle conflicts (`setState() or markNeedsBuild() called during build`).
* **OpenAPI 3.0.3 Spec & Swagger UI**: Built-in Swagger UI interactive playground hosted at `/api/v1/docs` with dynamic permission status annotations.

---

## 🔒 Network Modes & Security Architecture

Solaris Control API can operate in two distinct binding modes configurable via the application settings:

1. **Localhost Only (Default)**: Bound strictly to loopback interfaces (`127.0.0.1`, `::1`). No external LAN traffic is accepted.
2. **LAN Access Mode**: Bound to `0.0.0.0` or `::` (all network interfaces).
   * Automatically configures Windows Defender Firewall rules via `WindowsFirewallService` with a 3-stage UAC elevation fallback (`netsh` direct -> `powershell -Verb RunAs` -> fallback).
   * All old rules with prefix `Solaris_Control_API_*` are automatically pruned prior to rule updates.

### 7-Layer Defense Pipeline

Every HTTP and WebSocket request flows sequentially through 7 security layers:

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
 7. Constant-Time Auth Guard (Constant-time SHA-256 token comparison)
         │
         ▼
 8. Granular ACL & Data Privacy Guard (ApiPermissionsChecker & ApiPermissionsFilter)
         │
         ▼
[ Route Handler / Controller ]
```

---

## 🛡️ Granular Security & Data Privacy Access Control Framework

Solaris Control API v1 incorporates an enterprise-grade Zero-Trust access control system (`ApiPermissionsConfig`) configured locally via the Flutter GUI (`ApiPermissionsDialog`).

### 1. Data Sharing Flags (Read Permissions)
Controls visibility of telemetry and subsystem data in `GET /api/v1/status`, queries, and WebSocket streaming:
* `allowReadMonitors`: Physical monitor metadata, brightness & color temperature readings.
* `allowReadSolar`: Solar elevation, azimuth, zenith angle, day phase, and twilight events.
* `allowReadWeather`: Weather condition, temperature, and intensity adjustments.
* `allowReadSleep`: Asleep/awake status, last session end, and historical sleep records.
* `allowReadCircadian`: Smart Circadian phase tracking and auto-adjustment parameters.

> [!NOTE]
> **Granular Masking (`ApiPermissionsFilter`)**: Disabling a read flag automatically redacts the corresponding root section and performs key-level masking on composite objects (`automation`, `smart_circadian`, `presets`). For example, when `allowReadSleep = false`, sleep metrics (`sleep_pressure`, `sleep_debt`) are automatically pruned from `smart_circadian` without stripping circadian day-phase info.

### 2. Control Mutation Categories (`allowedCategories`)
Mutating commands (`POST /api/v1/control`, point-mutations, webhooks, and WebSocket commands) require explicit permission for their respective category:
1. `monitors`: Direct brightness/temperature adjustments (`set_brightness`, `set_temperature`, `set_monitor_offset`).
2. `presets`: Brightness/temperature/user preset switching (`set_brightness_preset`, `cycle_preset`).
3. `circadian`: Auto-brightness, auto-temperature, and Smart Circadian toggles (`set_auto_brightness`, `set_smart_circadian`).
4. `gaming`: Gaming mode activation and process whitelist management (`set_game_mode`, `manage_game_mode_whitelist`).
5. `environment`: Weather intensity and manual coordinates (`set_weather_adjustment`, `set_manual_location`, `trigger_sun_sync`).
6. `sleep`: Sleep status overrides (`push_sleep_status`).
7. `system`: System animations, failed webhook management (`clear_failed_webhooks`, `set_map_animations`).

### 3. Read-Only Mode (`isReadOnly`)
When `isReadOnly = true` is enabled in the host GUI:
* ALL mutation attempts (`POST /api/v1/control`, `POST /api/v1/monitors/:slug/*`, `POST /api/v1/webhooks*`, `POST /api/sleep/*`) are immediately rejected with `HTTP 403 Forbidden` (`Read-Only Mode Enabled`).
* Public liveness probe `GET /api/v1/health` remains 100% accessible.

### 4. Universal Privilege Escalation Guard
To prevent external API clients or WebSocket payloads from tampering with permission configurations, `ApiControlHandler` enforces an immediate rejection rule:
* Any mutation payload containing `apiPermissions` or permission keys is rejected with `HTTP 403 Forbidden` (`Privilege Escalation Prohibited`).
* API permissions can ONLY be modified locally by the host user via the Flutter GUI `ApiPermissionsDialog`.

---

## 🔑 Authentication

Authentication uses an **API Access Token** generated in the Solaris GUI (Settings -> API Keys).

Tokens can be passed using any of the following standard methods:

### 1. HTTP Request Header (Recommended for REST)
```http
X-API-Key: your_secret_api_token_here
```
or standard HTTP Bearer token:
```http
Authorization: Bearer your_secret_api_token_here
```

### 2. URL Query Parameter (Recommended for WebSocket / Simple Scripts)
```http
GET /api/v1/status?token=your_secret_api_token_here HTTP/1.1
```

### 3. WebSocket Subprotocol Header
```http
Sec-WebSocket-Protocol: bearer.your_secret_api_token_here
```

> [!IMPORTANT]
> **Constant-Time Verification**: Auth checks perform a SHA-256 `constantTimeEquals` hash comparison to protect against timing side-channel attacks. Rejections trigger HTTP 401 Unauthorized responses.

---

## ⚠️ Standard Error Format (RFC 7807)

All non-2xx responses from Solaris Control API return `application/problem+json` formatted strictly according to [RFC 7807 (Problem Details for HTTP APIs)](https://tools.ietf.org/html/rfc7807).

### Error Schema
```json
{
  "type": "https://solaris.local/errors/access-denied",
  "title": "Action Category Prohibited",
  "status": 403,
  "detail": "Action category \"gaming\" is disabled in API permissions settings.",
  "instance": "/api/v1/control"
}
```

### Common HTTP Error Statuses

| HTTP Status | Error Type Slug | Description |
| :--- | :--- | :--- |
| `400 Bad Request` | `/errors/bad-request` | Invalid JSON syntax or unparseable payload structure. |
| `401 Unauthorized` | `/errors/unauthorized` | Missing, empty, or invalid API access token. |
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
