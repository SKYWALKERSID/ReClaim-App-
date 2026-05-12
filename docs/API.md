# ReClaim™ API Reference

The ReClaim API is a high-performance RESTful service built with Node.js and TypeScript. It utilizes **RS256 JWT** asymmetric authentication and strict **Zod** schema validation for all inputs.

---

## 🔐 Authentication

### Header-Based
All requests (except public auth routes) must include the Authorization header:
```http
Authorization: Bearer <JWT_TOKEN>
```

### Service-to-Service (x-api-key)
Internal services can authenticate using a static API key. Note that when using this method, a `userId` must typically be provided in the request body to identify the target user.
```http
x-api-key: <YOUR_API_KEY>
```

---

## 📊 Analytics & Ingestion

### Ingest Batch Events
`POST /analytics/events`
Uploads a batch of usage events, blocked attempts, or overrides.
- **Rate Limit**: 20 requests per minute.
- **Payload**: `events: UsageEvent[]`

### Get Daily Summary
`GET /analytics/daily/:userId`
Returns metrics (total screen time, app switches), insights, and reward data for a specific day.
- **Params**: `date` (YYYY-MM-DD), `timeZone`

### Get Weekly Report
`GET /analytics/weekly/:userId`
Returns a 7-day trend analysis including behavioral recommendations.

### Data Export
`GET /export/:userId`
Streamed download of usage history.
- **Formats**: `json`, `csv`

---

## 📋 Commitment & Policy

### Update Commitment
`POST /commitments`
Configures user limits, focus windows, and package lists (blacklist/whitelist).

### Evaluate Policy
`GET /policy/:userId`
The core enforcement endpoint. Returns the current state: `normal`, `focus_only`, or `locked` based on usage vs. commitment.

### Rewards Summary
`GET /rewards/:userId`
Returns current points, streaks, and earned badges.

---

## 🧠 Intelligence & Drift

### Drift Session Sync
`POST /drift/sync`
Synchronizes high-fidelity session data from the **Cognitive Drift Engine™**.
- **Fields**: `peak_drift_score`, `fragmentation_index`, `feed_exposure_seconds`, `intent_confidence`.

### Craving Prediction
`GET /cravings/active`
Returns the currently predicted high-risk window for behavioral lapses.

---

## 📱 Device & Notifications

### Device Registry
`GET /devices` | `POST /devices` | `DELETE /devices/:deviceId`
Manages FCM tokens and device metadata for synchronization and nudges.

### Test Nudge
`POST /nudge`
Triggers an immediate push notification to all registered devices.

---

## 🤝 Social Accountability

### Buddy Management
`GET /social/buddies` | `POST /social/buddies`
Manages the accountability network. Users can see their buddies' discipline status.

### Challenges
`GET /social/challenges` | `POST /social/challenges/join`
Browse and participate in community focus challenges.

---

## 🛡️ Admin & Health

### System Stats
`GET /admin/stats`
Returns system-wide totals (users, events, devices) and health status.
- **Header**: `x-admin-key` (Timing-safe comparison)

### Health Check
`GET /health`
Verifies database connectivity and service readiness.

---

## 🔢 Response Codes

| Code | Description |
| --- | --- |
| `200 OK` | Request successful. |
| `201 Created` | Resource created (e.g., event ingested). |
| `202 Accepted` | Processing batch data asynchronously. |
| `400 Bad Request` | Zod validation failed. |
| `401 Unauthorized` | Invalid or expired token. |
| `403 Forbidden` | Scope mismatch or invalid admin key. |
| `429 Too Many Requests` | Rate limit hit. |
| `500 Server Error` | Backend failure. |

---
*ReClaim API Spec v2.0.0*
*Last Verified: May 11, 2026*
