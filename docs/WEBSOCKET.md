# Solaris Real-Time WebSocket API — Developer Guide

This document describes the architecture, protocol specification, Granular Security protections, subscription model, command correlation, and event broadcasting for the **Solaris Real-Time WebSocket API** (`ws://localhost:45321/api/v1/ws`).

---

## 📌 Protocol Overview

The WebSocket Streaming API provides a full-duplex, low-latency communication channel for real-time applications, dashboard widgets, and background daemons.

### Key Capabilities:
* **Real-time State Pushes**: Instant updates when monitor brightness, color temperature, solar position, or sleep status changes (`type: "update"`).
* **Selective Subscriptions & Unsubscribe**: Clients can dynamically filter or unsubscribe from specific topic streams using `subscribe` and `unsubscribe` message types.
* **Granular Data Privacy & Snapshot Protection**: Initial `snapshot` frame (`_buildSnapshotMap`) and real-time broadcasts (`broadcastModule`, `broadcastEvent`) are filtered dynamically according to per-key `ApiPermissionsConfig`.
* **Dynamic Runtime Subscription Revocation**: Toggling read permissions in the host GUI automatically revokes active topic subscriptions and sends `subscription_revoked` frames without severing TCP/WS connections.
* **Connection Concurrency Limit**: Maximum 20 simultaneous active WebSocket connections (`maxClients = 20`). Upgrade attempts exceeding this limit are rejected with `HTTP 503 Service Unavailable`.
* **Reactive Disconnect Revocation (Code 4001)**: Instant socket termination with WebSocket status code `4001` when an API key is deleted, token is regenerated, or `requireLocalToken` is enabled.
* **Bi-directional Command Execution**: Execute any of the 28 Action Control System commands over WebSocket with response correlation IDs (`cmd_id`) subject to category permissions (`allowedCategories`).
* **Slow Consumer OOM Protection**: Automatic client disconnection if unconsumed pending frame buffer exceeds 512 KB (`1008`).

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
GET /api/v1/ws?token=sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567 HTTP/1.1
Host: localhost:45321
Upgrade: websocket
Connection: Upgrade
```

#### Format B: Subprotocol Header (Standard browser WebSocket API)
```javascript
const token = 'sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567';
const socket = new WebSocket('ws://localhost:45321/api/v1/ws', [`bearer.${token}`]);
```

#### Format C: Request Header
```http
X-API-Key: sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567
```
or standard Authorization header:
```http
Authorization: Bearer sol_sec_ae1302d9e99a8b6aad30264417a64cec8ac1b17c20f5abc5cea38b5dea368eae01234567
```

---

## ⚡ Disconnect & Reactive Revocation Status Codes

When a WebSocket connection closes, Solaris transmits precise status codes and reason strings:

| Close Code | Reason String | Trigger Condition |
| :--- | :--- | :--- |
| `1000` | Normal Closure | Client gracefully disconnected. |
| `1001` | `Solaris API Server Stopping` / `PC Entering Sleep Mode` | Host user or OS turned off Control API server or PC entered sleep state. |
| `1001` | `Heartbeat failed` | Socket heartbeat timeout (ping/pong failure). |
| `1008` | `Slow Consumer: Pending buffer limit exceeded 512 KB` | Pending frame queue exceeded 512 KB memory limit. |
| `4001` | `Key Revoked` | Host user deleted the API key associated with this connection. |
| `4001` | `Token Regenerated` | Host user regenerated the secret token for this key. |
| `4001` | `Local Auth Required` | Host user enabled `requireLocalToken = true` while an anonymous socket was open. |

---

## 🛡️ Initial Snapshot Frame

Upon connection, Solaris sends an initial `snapshot` frame containing current subsystem states.

```json
{
  "type": "snapshot",
  "data": {
    "version": "1.1.0",
    "timestamp": "2026-07-25T14:30:00.000Z",
    "monitors": [
      {
        "id": "\\\\.\\DISPLAY1",
        "name": "LG UltraGear 27GP850",
        "friendly_name": "LG UltraGear A1F9",
        "slug": "display-1",
        "device_id_hash": "a1f9",
        "is_primary": true,
        "brightness": { "current": 80, "target": 80.0, "offset": 0.0, "mode": "auto" },
        "temperature": { "enabled": true, "current": 5500, "target": 5500, "mode": "auto" },
        "game_mode": { "enabled": true, "active": false }
      }
    ],
    "solar": {
      "elevation": 42.5,
      "azimuth": 185.3,
      "zenith": 47.5,
      "progress": 0.65,
      "current_phase": "day",
      "uv_index": 4.2,
      "spectral_intensity": 0.88
    },
    "weather": {
      "available": true,
      "temperature_celsius": 24.5,
      "weather_code": 0
    },
    "sleep": {
      "is_sleeping": false,
      "sessions_count": 12,
      "last_session_end": "2026-07-25T07:00:00.000Z"
    },
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
        "temperature_override": 6500.0
      }
    }
  }
}
```

---

## 📡 Subscriptions and Unsubscribe Model

### Selective Subscriptions (`type: "subscribe"`)
Subscribing adds modules to the client's active subscription set.
```json
{
  "type": "subscribe",
  "modules": ["solar", "monitors"]
}
```
**Response (`type: "subscribed"`)**:
```json
{
  "type": "subscribed",
  "active_modules": ["solar", "monitors"]
}
```

#### Subscription Denied Control Frame (`type: "subscription_denied"`):
Emitted if a client attempts to subscribe to a module disabled in its API key permissions:
```json
{
  "type": "subscription_denied",
  "module": "solar",
  "reason": "Read access disabled in API permissions"
}
```

#### Runtime Subscription Revocation Frame (`type: "subscription_revoked"`):
Emitted asynchronously when a host user disables read access for a module while a socket is active:
```json
{
  "type": "subscription_revoked",
  "module": "solar"
}
```

### Unsubscribing (`type: "unsubscribe"`)
```json
{
  "type": "unsubscribe",
  "modules": ["automation"]
}
```
**Response (`type: "unsubscribed"`)**:
```json
{
  "type": "unsubscribed",
  "active_modules": ["solar", "monitors"]
}
```

---

## ⚡ Real-Time Module & Event Broadcast Frames

### Module Update Frame (`type: "update"`)
```json
{
  "type": "update",
  "module": "solar",
  "timestamp": "2026-07-25T14:30:00.000Z",
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

---

### 💓 Heartbeat & Ping / Pong Control Frames

Every 30 seconds, the Solaris API server broadcasts a heartbeat ping to active WebSocket clients:

```json
{
  "type": "ping",
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

Clients may also send a ping to verify connection liveness:
```json
{
  "type": "ping"
}
```
**Server Response**:
```json
{
  "type": "pong",
  "timestamp": "2026-07-25T14:30:00.000Z"
}
```

### System Event Frame (`type: "event"`)
```json
{
  "type": "event",
  "event": "on_system_resume",
  "timestamp": "2026-07-25T14:30:00.000Z",
  "data": {
    "timestamp": "2026-07-25T14:30:00.000Z"
  }
}
```

### App Override Configuration Changed Event Frame (`type: "event"`)
Broadcasted when per-application profile rules or exit delay settings are updated:
```json
{
  "type": "event",
  "event": "app_override_changed",
  "timestamp": "2026-07-25T14:30:00.000Z",
  "data": {
    "app_overrides": [ ... ],
    "exit_delay_seconds": 5
  }
}
```

### Active Process Event Frame (`type: "event"`)
Broadcasted when the foreground process changes or a per-app override rule applies:
```json
{
  "type": "event",
  "event": "active_process_changed",
  "timestamp": "2026-07-25T14:30:00.000Z",
  "data": {
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
}
```

### Hardware Error Event Frame (`type: "event"`)
Broadcasted when a DDC/CI read/write error or I2C bus collision is detected:
```json
{
  "type": "event",
  "event": "on_hardware_error",
  "timestamp": "2026-07-25T14:30:00.000Z",
  "data": {
    "detail": "DDC/CI I2C Bus NAK on display \\\\.\\DISPLAY1",
    "timestamp": "2026-07-25T14:30:00.000Z"
  }
}
```

---

## 🎯 Command Execution via WebSocket (`cmd_id` Correlation)

### Request Frame Schema (`type: "command"`):
```json
{
  "type": "command",
  "cmd_id": "ws-cmd-001",
  "action": "set_brightness",
  "value": 90.0,
  "monitor_id": "display-1"
}
```

### Success Response (`type: "response"`):
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
