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
[ HMAC-SHA256 Delivery ] ──(Signs headers: X-Solaris-Signature-256)
         │
         ├──(HTTP 2xx Success) ──► [ Transaction Marked Completed ]
         └──(Fail / Retry) ────► [ Exponential Backoff Retry ] ────► [ Dead Letter Queue (DLQ) ]
```

### Resilience Features
* **Asynchronous WAL Buffer**: Prevents delivery loss during temporary network hiccups or system restarts.
* **Exponential Backoff**: Automatic retry schedule (`5s`, `15s`, `45s`, `2m`, `5m`) up to max attempt limits.
* **Dead Letter Queue (DLQ)**: Failed deliveries after max retries are moved to DLQ for manual inspection and replay via REST API.
* **Privacy Sanitization**: Automatically masks sensitive hardware identifiers (e.g. serial numbers, PnP IDs, API keys) in error logs and payloads.

---

## 🛠️ Management REST Endpoints & Granular Security

All webhook administration endpoints are guarded by **Solaris Granular Security (`ApiPermissionsConfig`)**:
* **Read Operations** (`GET /api/v1/webhooks`, `GET /api/v1/webhooks/dlq`): Require category `system` in `allowedCategories`.
* **Mutating Operations** (`POST /api/v1/webhooks`, `DELETE /api/v1/webhooks/:id`, `POST /api/v1/webhooks/:id/test`, `POST /api/v1/webhooks/dlq/retry`): Require `isReadOnly = false` AND category `system` in `allowedCategories`.
* **Violation Response**: Rejects with `HTTP 403 Forbidden` (`Action Category Prohibited` or `Read-Only Mode Enabled`).

### 1. `GET /api/v1/webhooks`
Returns all configured outbound webhooks.

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
      "secretKey": "my_super_secret_hmac_key"
    }
  ]
}
```

---

### 2. `POST /api/v1/webhooks`
Creates or updates a webhook endpoint configuration.

* **Payload**:
```json
{
  "name": "Home Assistant Automation",
  "url": "https://ha.example.com/api/webhook/solaris_events",
  "events": ["on_day_phase_changed", "on_sleep_status_changed", "on_hardware_error"],
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
    "events": ["on_day_phase_changed", "on_sleep_status_changed", "on_hardware_error"],
    "isEnabled": true,
    "secretKey": "my_super_secret_hmac_key"
  }
}
```

---

### 3. `DELETE /api/v1/webhooks/:id`
Deletes a webhook configuration by ID.

* **Response (HTTP 200 OK)**: `{"status": "deleted", "id": "wh_1784978461855"}`

---

### 4. `GET /api/v1/webhooks/dlq`
Returns entries from the Dead Letter Queue (failed deliveries that exceeded retry attempts).

---

### 5. `POST /api/v1/webhooks/dlq/retry`
Retries execution of dead-lettered webhook payloads.

---

### 6. Cleared Failed Webhooks via Control API (`clear_failed_webhooks`)
Dead-letter entries for a specific webhook can also be cleared via the Action Control System (`POST /api/v1/control`):
```json
{
  "action": "clear_failed_webhooks",
  "webhook_id": "wh_1784978461855"
}
```

---

## ⚡ Complete Webhook Event Catalog (23 Events)

Solaris supports 23 distinct webhook event types categorized into 6 functional groups:

### 1. Solar & Twilight Events
| Event Name (`wireName`) | Trigger Condition | Required Read Flag |
| :--- | :--- | :--- |
| `on_sunrise` | Solar elevation crosses horizon upwards (0°). | `allowReadSolar` |
| `on_sunset` | Solar elevation crosses horizon downwards (0°). | `allowReadSolar` |
| `on_civil_twilight_begin` | Civil twilight begins (-6° solar elevation). | `allowReadSolar` |
| `on_civil_twilight_end` | Civil twilight ends (-6° solar elevation). | `allowReadSolar` |
| `on_golden_hour_begin` | Golden hour begins (6° solar elevation). | `allowReadSolar` |
| `on_golden_hour_end` | Golden hour ends (6° solar elevation). | `allowReadSolar` |
| `on_day_phase_changed` | Day phase transitions (e.g. `day` -> `sunset` -> `night` -> `sunrise`). | `allowReadSolar` |

### 2. Weather & Location (Privacy-First)
| Event Name (`wireName`) | Trigger Condition | Required Read Flag |
| :--- | :--- | :--- |
| `on_weather_updated` | New weather condition or temperature fetch completed. | `allowReadWeather` |
| `on_location_changed` | Geographic coordinates updated (latitude/longitude sanitized). | `allowReadWeather` |

### 3. Control & Preset Events
| Event Name (`wireName`) | Trigger Condition | Required Category |
| :--- | :--- | :--- |
| `on_brightness_preset_changed` | Active brightness preset modified (`brightest`, `bright`, `dim`, `dimmest`). | `presets` |
| `on_temperature_preset_changed`| Active color temperature preset modified (`coolest`, `cool`, `warm`, `warmest`). | `presets` |
| `on_auto_brightness_toggled` | Automatic brightness adjustment state toggled. | `circadian` |
| `on_auto_temperature_toggled` | Automatic temperature adjustment state toggled. | `circadian` |
| `on_brightness_threshold_crossed`| Target display brightness crosses configured threshold limit. | `monitors` |

### 4. Gaming Mode Events
| Event Name (`wireName`) | Trigger Condition | Required Category |
| :--- | :--- | :--- |
| `on_game_mode_activated` | Whitelisted game process detected & Gaming Mode activated. | `gaming` |
| `on_game_mode_deactivated` | Game process exited & Gaming Mode deactivated. | `gaming` |

### 5. Smart Circadian & Sleep Events
| Event Name (`wireName`) | Trigger Condition | Required Read Flag |
| :--- | :--- | :--- |
| `on_wind_down_started` | Circadian Wind Down phase initiated before target bedtime. | `allowReadCircadian` |
| `on_sleep_status_changed` | User sleep state changes (asleep vs. awake). | `allowReadSleep` |

### 6. System & Hardware Events
| Event Name (`wireName`) | Trigger Condition | Required Category |
| :--- | :--- | :--- |
| `on_monitor_connected` | Physical monitor plugged in or DDC/CI handle discovered. | `monitors` |
| `on_monitor_disconnected` | Physical monitor unplugged or display connection lost. | `monitors` |
| `on_api_server_started` | Solaris Control API server listening socket started. | `system` |
| `on_system_resume` | Windows power state resumes from S3/S4 sleep/hibernate (`WM_POWERBROADCAST`). | `system` |
| `on_hardware_error` | Physical DDC/CI read/write error or I2C bus collision detected. | `system` |

---

## 🔒 Security Architecture: SSRF, IP-Pinning & HMAC

### 1. SSRF Protection (`SsrfValidator`)
Outbound webhooks reject URLs pointing to loopback, local, or private IP spaces to prevent **Server-Side Request Forgery (SSRF)** attacks targeting internal infrastructure:
* **Blocked IPv4 Ranges**: `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`.
* **Blocked IPv6 Ranges**: `::1/128`, `fe80::/10`, `ff00::/8`.

### 2. True IP-Pinning & TLS SNI Handshake (`SsrfSafeHttpClient`)
To prevent DNS Rebinding attacks during execution:
1. Solaris resolves domain names using an isolated DNS lookup step.
2. The HTTP request is made directly to the resolved public IP.
3. For HTTPS URLs, `SsrfSafeHttpClient` performs explicit **TLS Server Name Indication (SNI)** handshakes using `SecureSocket.secure()` to verify certificate host validity.

### 3. HMAC-SHA256 Signature Verification
When a webhook is configured with a `secretKey`, Solaris includes cryptographic signature headers on every HTTP POST delivery:

#### Delivery Headers:
```http
Content-Type: application/json
X-Solaris-Event: on_day_phase_changed
X-Solaris-Delivery: del_9f8a3b1c-7e6d-4a5b
X-Solaris-Timestamp: 1721817900
X-Solaris-Signature-256: sha256=a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e
```

#### Signature Calculation Algorithm:
```
signature_input = timestamp + "." + raw_json_payload
signature = HMAC-SHA256(secretKey, signature_input).toHexString()
```

#### Verifying Signature in Node.js / Express:
```javascript
const crypto = require('crypto');

function verifySolarisWebhook(req, secretKey) {
  const timestamp = req.headers['x-solaris-timestamp'];
  const signatureHeader = req.headers['x-solaris-signature-256'];
  const rawBody = JSON.stringify(req.body);

  const signatureInput = `${timestamp}.${rawBody}`;
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
