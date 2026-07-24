# Solaris Outbound Webhooks Engine — Developer Guide

This document describes the architecture, event catalog, security controls, delivery guarantees, and integration patterns for the **Solaris Outbound Webhooks Engine**.

---

## 📌 Architecture Overview

The Outbound Webhooks Engine enables Solaris to broadcast state changes, solar position updates, gaming profile transitions, hardware events, and sleep tracking status asynchronously to external web servers (e.g. Home Assistant, Node-RED, custom HTTP endpoints).

```
[ Solaris Event Stream ]
         │
         ▼
[ Webhook Filter Engine ] ──(Matches event subscriptions)
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

## 🛠️ Management REST Endpoints

### 1. `GET /api/v1/webhooks`
Returns all configured outbound webhooks.

---

### 2. `POST /api/v1/webhooks`
Creates or updates a webhook endpoint configuration.

* **Payload**:
```json
{
  "name": "Home Assistant Automation",
  "url": "https://ha.example.com/api/webhook/solaris_events",
  "events": ["on_day_phase_changed", "on_sleep_status_changed", "on_hardware_error"],
  "is_enabled": true,
  "secret_key": "my_super_secret_hmac_key",
  "custom_headers": {
    "X-Custom-Auth": "SecretToken123"
  }
}
```

---

### 3. `DELETE /api/v1/webhooks/:id`
Deletes a webhook configuration by ID.

---

### 4. `GET /api/v1/webhooks/dlq`
Returns entries from the Dead Letter Queue (failed deliveries that exceeded retry attempts).

---

## ⚡ Complete Webhook Event Catalog (23 Events)

Solaris supports 23 distinct webhook event types categorized into 6 functional groups:

### 1. Solar & Twilight Events
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_sunrise` | Solar elevation crosses horizon upwards (0°). |
| `on_sunset` | Solar elevation crosses horizon downwards (0°). |
| `on_civil_twilight_begin` | Civil twilight begins (-6° solar elevation). |
| `on_civil_twilight_end` | Civil twilight ends (-6° solar elevation). |
| `on_golden_hour_begin` | Golden hour begins (6° solar elevation). |
| `on_golden_hour_end` | Golden hour ends (6° solar elevation). |
| `on_day_phase_changed` | Day phase transitions (e.g. `day` -> `sunset` -> `night` -> `sunrise`). |

### 2. Weather & Location (Privacy-First)
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_weather_updated` | New weather condition or temperature fetch completed. |
| `on_location_changed` | Geographic coordinates updated (latitude/longitude sanitized). |

### 3. Control & Preset Events
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_brightness_preset_changed` | Active brightness preset modified (`brightest`, `bright`, `dim`, `dimmest`). |
| `on_temperature_preset_changed`| Active color temperature preset modified (`coolest`, `cool`, `warm`, `warmest`). |
| `on_auto_brightness_toggled` | Automatic brightness adjustment state toggled. |
| `on_auto_temperature_toggled` | Automatic temperature adjustment state toggled. |
| `on_brightness_threshold_crossed`| Target display brightness crosses configured threshold limit. |

### 4. Gaming Mode Events
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_game_mode_activated` | Whitelisted game process detected & Gaming Mode activated. |
| `on_game_mode_deactivated` | Game process exited & Gaming Mode deactivated. |

### 5. Smart Circadian & Sleep Events
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_wind_down_started` | Circadian Wind Down phase initiated before target bedtime. |
| `on_sleep_status_changed` | User sleep state changes (asleep vs. awake). |

### 6. System & Hardware Events
| Event Name (`wireName`) | Trigger Condition |
| :--- | :--- |
| `on_monitor_connected` | Physical monitor plugged in or DDC/CI handle discovered. |
| `on_monitor_disconnected` | Physical monitor unplugged or display connection lost. |
| `on_api_server_started` | Solaris Control API server listening socket started. |
| `on_system_resume` | Windows power state resumes from S3/S4 sleep/hibernate (`WM_POWERBROADCAST`). |
| `on_hardware_error` | Physical DDC/CI read/write error or I2C bus collision detected. |

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
When a webhook is configured with a `secret_key`, Solaris includes cryptographic signature headers on every HTTP POST delivery:

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
signature = HMAC-SHA256(secret_key, signature_input).toHexString()
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
