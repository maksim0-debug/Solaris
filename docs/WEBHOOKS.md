# Solaris Outbound Webhooks Engine — Developer Guide

This document describes the architecture, event catalog, security controls, delivery guarantees, Granular ACL requirements, and integration patterns for the **Solaris Outbound Webhooks Engine**.

---

## 📌 Architecture Overview

The Outbound Webhooks Engine enables Solaris to broadcast state changes, solar position updates, gaming profile transitions, hardware events, and sleep tracking status asynchronously to external web servers (e.g. Home Assistant, Node-RED, custom HTTP endpoints).

```
[ Solaris Event Stream ]
         │
         ▼
[ Webhook Filter Engine ] ──(Matches event subscriptions & Granular ACL)
         │
         ▼
[ Write-Ahead Log Buffer (WAL) ] ──(Persists event delivery state)
         │
         ▼
[ SSRF Protection & IP-Pinning Client ] ──(Blocks loopback/private IPs, performs TLS SNI Handshake)
         │
         ▼
[ HMAC-SHA256 Delivery ] ──(Signs headers: X-Solaris-Signature)
         │
         ├──(HTTP 2xx Success) ──► [ Transaction Marked Completed ]
         └──(Fail / Retry) ────► [ Exponential Backoff Retry ] ────► [ Dead Letter Queue (DLQ) ]
```

### Resilience & Network Constraints Features
* **Asynchronous WAL Buffer**: Prevents delivery loss during temporary network hiccups or system restarts.
* **Network Timeouts**: Request Timeout `10s`, Connection Timeout `5s`, DNS Lookup Timeout `5s`, Max Redirects `3`, Max Concurrent Deliveries `5`.
* **Retry Schedule**: Up to 3 retry attempts with exponential backoff (`1s`, `2s`).
* **Dead Letter Queue (DLQ)**: Failed deliveries after max retries are moved to DLQ for manual inspection, filtering, and clearing.
* **Auto-Disable Protection Guard**: If a webhook fails 10 consecutive delivery attempts (`failureCount >= 10`), Solaris automatically sets `isEnabled = false` to prevent flood and network waste. Successful delivery automatically resets `failureCount = 0`.
* **Privacy Sanitization**: Automatically masks sensitive weather coordinates and location data in payload data.

---

## 🛠️ Management REST Endpoints & Granular Security

All webhook administration endpoints are guarded by **Solaris Granular Security & Per-Action Precision (`ApiPermissionsConfig`)**:
* **Read Operations** (`GET /api/v1/webhooks`, `GET /api/v1/webhooks/dlq`, `GET /api/v1/webhooks/events`): Require category `system` in `allowedCategories`.
* **Mutating Operations** (`POST /api/v1/webhooks`, `DELETE /api/v1/webhooks/:id`, `POST /api/v1/webhooks/:id/test`, `POST /api/v1/webhooks/dlq/retry`): Require `isReadOnly = false`, category `system` in `allowedCategories`, AND canonical action `manage_webhooks` in `allowedActions` (or `allowedActions == null`).
* **Alias Shortcut (`clear_failed_webhooks`)**: Executing `{"action": "clear_failed_webhooks", "webhook_id": "wh_123"}` via `POST /api/v1/control` filters and clears dead-letter entries for that specific webhook.

---

### 1. `GET /api/v1/webhooks`
Returns all configured outbound webhooks. `secretKey` and `customHeaders` entries are DPAPI-encrypted at rest (`KeyObfuscator.encrypt`).

* **Response (HTTP 200 OK)**:
```json
{
  "total": 1,
  "webhooks": [
    {
      "id": "wh_1784978461855",
      "url": "https://ha.example.com/api/webhook/solaris_events",
      "name": "Home Assistant Automation",
      "events": ["on_sunset", "on_sunrise"],
      "isEnabled": true,
      "secretKey": "enc_dpapi_secret_key_string",
      "customHeaders": { "X-Custom-Auth": "enc_dpapi_header_token" },
      "failureCount": 0,
      "createdAt": "2026-07-25T12:00:00.000Z",
      "lastTriggeredAt": "2026-07-25T14:30:00.000Z"
    }
  ]
}
```

---

### 2. `POST /api/v1/webhooks`
Creates or updates a webhook endpoint configuration. Accepts either `custom_headers` or `headers` object.

* **Payload**:
```json
{
  "name": "Home Assistant Automation",
  "url": "https://ha.example.com/api/webhook/solaris_events",
  "events": ["on_day_phase_changed", "on_game_mode_activated", "on_hardware_error"],
  "isEnabled": true,
  "secretKey": "my_super_secret_hmac_key",
  "custom_headers": {
    "X-Custom-Auth": "SecretToken123"
  }
}
```

* **Response (HTTP 201 Created)**:
```json
{
  "status": "created",
  "webhook": {
    "id": "wh_1784978461855",
    "url": "https://ha.example.com/api/webhook/solaris_events",
    "name": "Home Assistant Automation",
    "events": ["on_day_phase_changed", "on_game_mode_activated", "on_hardware_error"],
    "isEnabled": true,
    "secretKey": "enc_dpapi_secret_key_string",
    "customHeaders": { "X-Custom-Auth": "enc_dpapi_header_token" },
    "failureCount": 0,
    "createdAt": "2026-07-25T14:30:00.000Z",
    "lastTriggeredAt": null
  }
}
```

---

### 3. `DELETE /api/v1/webhooks/:id`
Deletes a webhook configuration by ID.

* **Response (HTTP 200 OK)**: `{"status": "ok", "deleted_id": "wh_1784978461855"}`

---

### 4. `GET /api/v1/webhooks/events`
Returns all supported webhook event type identifiers and wire names.

* **Response (HTTP 200 OK)**:
```json
{
  "events": [
    { "type": "onSunrise", "wire_name": "on_sunrise" },
    { "type": "onSunset", "wire_name": "on_sunset" },
    { "type": "onDayPhaseChanged", "wire_name": "on_day_phase_changed" },
    { "type": "onGameModeActivated", "wire_name": "on_game_mode_activated" },
    { "type": "onGameModeDeactivated", "wire_name": "on_game_mode_deactivated" },
    { "type": "onAutoBrightnessToggled", "wire_name": "on_auto_brightness_toggled" },
    { "type": "onSystemResume", "wire_name": "on_system_resume" },
    { "type": "onHardwareError", "wire_name": "on_hardware_error" }
  ]
}
```

---

## ⚡ Webhook Event Catalog

Solaris defines 23 distinct webhook event types across 6 functional groups. The engine currently dispatches 8 core system events:

### Currently Dispatched Events (8 Events):
1. `on_sunrise`: Solar elevation crosses horizon upwards (0°).
2. `on_sunset`: Solar elevation crosses horizon downwards (0°).
3. `on_day_phase_changed`: Day phase transitions (e.g. `day` -> `sunset` -> `night`).
4. `on_game_mode_activated`: Whitelisted game process detected & Gaming Mode activated.
5. `on_game_mode_deactivated`: Game process exited & Gaming Mode deactivated.
6. `on_auto_brightness_toggled`: Automatic brightness adjustment state toggled.
7. `on_system_resume`: Windows power state resumes from S3/S4 sleep/hibernate.
8. `on_hardware_error`: Physical DDC/CI read/write error or I2C bus collision detected.

---

## 🔒 Security Architecture: SSRF, IP-Pinning & HMAC

### HMAC-SHA256 Signature Verification
When a webhook is configured with a `secretKey`, Solaris includes cryptographic signature headers on every HTTP POST delivery:

#### Delivery Headers:
```http
Content-Type: application/json; charset=utf-8
User-Agent: Solaris/1.1.0
X-Solaris-Event: on_day_phase_changed
X-Solaris-Delivery-Id: deliv-9f8a3b1c-7e6d-4a5b
X-Solaris-Timestamp: 2026-07-31T22:40:48.123Z
X-Solaris-Signature: sha256=a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e
```

#### Signature Calculation Algorithm:
```
signature_input = deliveryId + "." + timestamp + "." + raw_json_payload
signature = "sha256=" + HMAC-SHA256(secretKey, signature_input).toHexString()
```

> [!NOTE]
> **DLQ Capacity Limit**: Dead Letter Queue retains up to **100 entries** (`maxDlqEntries = 100`). Older failed transactions are pruned automatically upon capacity overflow.

#### Verifying Signature in Node.js / Express:
```javascript
const crypto = require('crypto');

function verifySolarisWebhook(req, secretKey) {
  const deliveryId = req.headers['x-solaris-delivery-id'];
  const timestamp = req.headers['x-solaris-timestamp'];
  const signatureHeader = req.headers['x-solaris-signature'];
  // Use raw unparsed request body buffer to preserve exact JSON byte encoding
  const rawBody = req.rawBody || JSON.stringify(req.body);

  const signatureInput = `${deliveryId}.${timestamp}.${rawBody}`;
  const expectedSignature = 'sha256=' + crypto
    .createHmac('sha256', secretKey)
    .update(signatureInput)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signatureHeader),
    Buffer.from(expectedSignature)
  );
}
```
