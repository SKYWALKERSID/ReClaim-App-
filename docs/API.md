# ReClaim™ API Reference

The ReClaim API is a RESTful service protected by RS256 JWT authentication.

---

## 🔐 Authentication

### Header
All requests except `/auth` must include the Authorization header.
```http
Authorization: Bearer <JWT_TOKEN>
```

### API Keys (Service-to-Service)
Internal services can authenticate using a static API key.
```http
x-api-key: <YOUR_API_KEY>
```

---

## 📊 Analytics Endpoints

### 1. Ingest Events
`POST /analytics/events`
Uploads a batch of usage events, blocked attempts, or overrides.

**Request Body:**
```json
{
  "events": [
    {
      "packageName": "com.instagram.android",
      "startedAt": "2026-05-09T20:00:00Z",
      "endedAt": "2026-05-09T20:15:00Z",
      "durationSeconds": 900,
      "eventType": "usage"
    }
  ]
}
```

### 2. Get Daily Summary
`GET /analytics/daily/:userId?date=YYYY-MM-DD&timeZone=UTC`
Returns metrics, insights, and reward data for a specific day.

---

## 📋 Commitment Endpoints

### 1. Save Commitment
`POST /commitments`
Saves or updates the user's screen-time limits and focus windows.

**Request Body:**
```json
{
  "dailyLimitMinutes": 120,
  "focusWindows": [
    { "start": "09:00", "end": "17:00", "daysOfWeek": [1,2,3,4,5] }
  ],
  "blacklist": ["com.tiktok.android", "com.reddit.frontpage"]
}
```

---

## 🧠 Intelligence Endpoints

### 1. Get Drift Score
`GET /intelligence/drift/:userId`
Returns the real-time attention drift score and fragmentation index.

### 2. Get Craving Windows
`GET /intelligence/cravings/:userId`
Returns predicted high-risk windows for behavioral lapses.

---

## 📱 Device Endpoints

### 1. Register Device
`POST /devices`
Registers a device for FCM push notifications.

---

## 🛡️ Response Codes

| Code | Description |
| --- | --- |
| `200 OK` | Request successful. |
| `201 Created` | Resource created (e.g., event ingested). |
| `400 Bad Request` | Validation failed (Zod error). |
| `401 Unauthorized` | Invalid or expired token. |
| `429 Too Many Requests` | Rate limit exceeded. |
| `500 Server Error` | Unexpected backend failure. |

---
*ReClaim API Spec v1.0.0*
