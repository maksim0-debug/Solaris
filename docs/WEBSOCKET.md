# Solaris Real-Time WebSocket API — Developer Guide

This document describes the architecture, protocol specification, Granular Security protections, subscription model, command correlation, and event broadcasting for the **Solaris Real-Time WebSocket API** (`ws://localhost:45321/api/v1/ws`).

---

## 📌 Protocol Overview

The WebSocket Streaming API provides a full-duplex, low-latency communication channel for real-time applications, dashboard widgets, and background daemons.

### Key Capabilities:
* **Real-time State Pushes**: Instant updates when monitor brightness, color temperature, solar position, or sleep status changes.
* **Granular Data Privacy & Snapshot Protection**: Initial `snapshot` frame (`_buildSnapshotMap`) and real-time broadcasts (`broadcastModule`, `broadcastEvent`) are filtered dynamically according to per-key `ApiPermissionsConfig`.
* **Dynamic Runtime Subscription Revocation**: Toggling read permissions in the host GUI automatically revokes active topic subscriptions and sends `subscription_revoked` frames without severing TCP/WS connections.
* **Reactive Disconnect Revocation (Code 4001)**: Instant socket termination with WebSocket status code `4001` when an API key is deleted, token is regenerated, or `requireLocalToken` is enabled.
* **Bi-directional Command Execution**: Execute any of the 26 Action Control System commands over WebSocket with response correlation IDs (`cmd_id`) subject to category permissions (`allowedCategories`).
* **Windows Power & Hardware Error Broadcasts**: Broadcasts S3/S4 sleep/resume system events (`WM_POWERBROADCAST`) and DDC/CI physical hardware errors.
* **Slow Consumer OOM Protection & Zero Memory Leak Guard**: Automatic client disconnection if unconsumed pending frame buffer exceeds 512 KB (`1008`), and client sub-maps (`_subscriptionsPerClient`) are pruned cleanly on disconnect.

---

## 🔑 Connection & Handshake Authentication

### Endpoint URL:
```http
ws://localhost:45321/api/v1/ws
```
or over LAN (if LAN mode enabled):
```http
ws://<SOLARIS_HOST_IP>:45321/api/v1/ws
```

### Passing Auth Tokens

Tokens can be passed using any of the following 3 formats:

#### Format A: Query Parameter (Most convenient for web clients)
```http
GET /api/v1/ws?token=sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae HTTP/1.1
Host: localhost:45321
Upgrade: websocket
Connection: Upgrade
```

#### Format B: Subprotocol Header (Standard browser WebSocket API)
```javascript
const token = 'sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae';
const socket = new WebSocket('ws://localhost:45321/api/v1/ws', [`bearer.${token}`]);
```

#### Format C: Request Header
```http
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae
```

> [!CAUTION]
> **Cross-Site WebSocket Hijacking (CSWSH) Guard**: WebSockets originating from browser origins (carrying an `Origin` header) will be rejected with HTTP 403 unless a valid auth token is supplied.
>
> **requireLocalToken Enforcement**: When `requireLocalToken = true` is enabled in GUI, anonymous localhost connections without a valid token are rejected with `HTTP 401 Unauthorized`.

---

## ⚡ Disconnect & Reactive Revocation Status Codes

When a WebSocket connection closes, Solaris transmits precise status codes and reason strings:

| Close Code | Reason String | Trigger Condition |
| :--- | :--- | :--- |
| `1000` | Normal Closure | Client gracefully disconnected. |
| `1001` | `Solaris API Server Stopping` | Host user turned off Control API server in GUI. |
| `1008` | `Slow Consumer OOM Guard` | Pending frame queue exceeded 512 KB memory limit. |
| `4001` | `Key Revoked` | Host user deleted the API key associated with this connection. |
| `4001` | `Token Regenerated` | Host user regenerated the secret token for this key. |
| `4001` | `Local Auth Required` | Host user enabled `requireLocalToken = true` while an anonymous socket was open. |

---

## 🛡️ Granular Security, Per-Action ACL & Snapshot Protection

Upon connection, Solaris sends an initial `snapshot` frame containing current subsystem states.

### Snapshot Masking Rules (`_buildSnapshotMap` & `ApiPermissionsFilter`):
* `monitors`: Key omitted if `allowReadMonitors = false`.
* `solar`: Key omitted if `allowReadSolar = false`.
* `weather`: Key omitted if `allowReadWeather = false`.
* `sleep`: Key omitted if `allowReadSleep = false`.
* `automation`: Key-level masking removes `weather_*` fields if `allowReadWeather = false`, and `circadian_*` fields if `allowReadCircadian = false`.
* `smart_circadian`: Sensitive sleep metrics (`sleep_pressure`, `sleep_debt`) are stripped if `allowReadSleep = false`.

#### Example Initial Snapshot Frame:
```json
{
  "type": "snapshot",
  "data": {
    "monitors": [ ... ],
    "solar": { "elevation": 42.5, "current_phase": "day" },
    "automation": { "auto_brightness": true, "game_mode": false },
    "smart_circadian": { "enabled": true, "current_phase": "day" }
  }
}
```

### Per-Action Broadcast Event Isolation (`broadcastEvent`)
In addition to read-flag telemetry filtering, outbound WebSocket system events (`broadcastEvent`) are evaluated against per-client action permissions:
* Mutating system broadcast events are filtered via `clientPermissions.isActionAllowed(eventName)`.
* If a connected client's API key has prohibited the specific action (e.g. `manage_webhooks` or `on_hardware_error`), the broadcast frame is cleanly suppressed for that specific socket without leaking data or terminating the connection.

---

## 📡 Message Frame Structure

All WebSocket messages are JSON objects containing a `type` string field.

### Heartbeat Ping/Pong
Solaris sends a periodic heartbeat ping frame every **30 seconds**:
```json
{
  "type": "ping",
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```
Clients may respond with a pong frame or send application-level pings:
```json
{
  "type": "pong",
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

---

## 🎯 Command Execution via WebSocket (`cmd_id` Correlation)

Clients can send commands over the WebSocket connection using the `command` type message.

### Request Frame Schema:
* `type`: `"command"` (required)
* `cmd_id`: Unique correlation string generated by client (required)
* `action`: Action command name from the 26 supported actions (required)
* Additional action payload fields.

#### Example Command Request:
```json
{
  "type": "command",
  "cmd_id": "ws-cmd-001",
  "action": "set_brightness",
  "value": 90.0,
  "monitor_id": "display-1"
}
```

### Response Frame Schema (`type: "response"`):
Solaris responds with a `response` frame matching the client's `cmd_id`:

#### Success Response:
```json
{
  "type": "response",
  "cmd_id": "ws-cmd-001",
  "status": "ok",
  "action": "set_brightness",
  "applied": {
    "value": 90.0,
    "monitor_id": "display-1"
  },
  "error": null,
  "message": null
}
```

#### Error Response (Validation Failure):
```json
{
  "type": "response",
  "cmd_id": "ws-cmd-001",
  "status": "error",
  "action": "set_brightness",
  "error": "Validation Error",
  "message": "Field 'value' must be a number between 0.0 and 100.0."
}
```

#### Error Response (Forbidden by Granular Permissions / Read-Only):
```json
{
  "type": "response",
  "cmd_id": "ws-cmd-001",
  "status": "error",
  "action": "set_brightness",
  "error": "Forbidden",
  "message": "Action category \"monitors\" is disabled in API permissions settings."
}
```

#### Error Response (Privilege Escalation Guard):
```json
{
  "type": "response",
  "cmd_id": "ws-cmd-esc",
  "status": "error",
  "action": "set_brightness",
  "error": "Forbidden",
  "message": "Modifying API permissions or keys via WebSocket commands is strictly prohibited."
}
```

---

## 🔔 Selective Subscriptions & Dynamic Runtime Revocation

By default, newly connected WebSocket clients receive updates across all module channels. Clients can filter module updates by sending a `subscribe` or `unsubscribe` frame.

### Available State Modules:
* `"solar"`: Real-time solar position, elevation, azimuth, UV index, and day phase.
* `"monitors"`: Connected physical displays, brightness, color temperature, and slugs.
* `"sleep"`: Real-time sleep tracking state and pushed relay status.
* `"automation"`: Auto Brightness, Auto Temperature, and Gaming Mode status.
* `"system"`: Windows Power state (S3/S4 sleep/resume) and physical DDC/CI hardware errors.

### Subscription Frame Example:
```json
{
  "type": "subscribe",
  "modules": ["solar", "monitors"]
}
```

### Confirmation Frame (`type: "subscribed"`):
```json
{
  "type": "subscribed",
  "active_modules": ["solar", "monitors"]
}
```

### Unsubscribe Frame Example:
```json
{
  "type": "unsubscribe",
  "modules": ["automation"]
}
```

### Subscription Denial (`subscription_denied`)
If a client attempts to subscribe to a module whose read flag is disabled (e.g. `allowReadSleep = false`), Solaris rejects the module and responds with a `subscription_denied` frame:
```json
{
  "type": "subscription_denied",
  "module": "sleep",
  "reason": "Read access to resource \"sleep\" is disabled in host API permissions settings."
}
```

### Dynamic Runtime Subscription Revocation (`subscription_revoked`)
If the host user toggles an API permission flag OFF in the Flutter GUI (`ApiPermissionsDialog`) while WebSocket clients are connected:
1. `WebSocketService` detects the setting change via `ref.listen(settingsProvider)`.
2. A **synchronous atomic audit** is performed over active subscription contexts.
3. The disabled module topic is revoked from active subscription sets.
4. Solaris transmits a `subscription_revoked` frame to affected clients **without closing the WebSocket connection**:

```json
{
  "type": "subscription_revoked",
  "module": "sleep",
  "reason": "Read permission for this module was disabled by host user in GUI"
}
```

---

## ⚡ Real-Time Module Broadcast Frames

### 1. Solar Module (`"solar"`)
```json
{
  "type": "module_update",
  "module": "solar",
  "data": {
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
  }
}
```

### 2. System & Power Events (`"system"`)
Broadcasting Windows OS power state changes (`WM_POWERBROADCAST` S3/S4 transitions) and hardware bus failures:

```json
{
  "type": "system_event",
  "event": "on_system_suspend",
  "data": {
    "reason": "S3 Sleep State Entered",
    "timestamp": "2026-07-25T03:00:00.000Z"
  }
}
```

Hardware DDC/CI Read/Write Failure Broadcast:
```json
{
  "type": "system_event",
  "event": "on_hardware_error",
  "data": {
    "monitor_slug": "lg-ultragear-a1f9",
    "error_code": "I2C_ACK_FAILURE",
    "message": "Failed to communicate with monitor handle via DDC/CI bus."
  }
}
```

