# API Design — Production Reference

Base URL: `http://localhost:4000/v1`  
Content-Type: `application/json`  
Authentication: `x-api-key` header (required for all routes except `/health`)
Validation: Zod v4 (all inputs validated, errors return field-level details)

### Rate Limiting
- **General**: 100 requests per minute per IP.
- **Ingestion**: 20 requests per minute per IP.
- Headers included in responses:
  - `X-RateLimit-Limit`: Maximum requests allowed in the window.
  - `X-RateLimit-Remaining`: Remaining requests in the current window.
  - `X-RateLimit-Reset`: UTC timestamp when the window resets.

---

## Endpoints

### `GET /v1/health`

System health check with database connectivity verification.

**Response 200:**
```json
{
  "status": "ok",
  "service": "reclaim-api",
  "database": "connected",
  "timestamp": "2026-05-03T16:31:59.142Z"
}
```

**Response 503** (database unreachable):
```json
{
  "status": "degraded",
  "service": "reclaim-api",
  "database": "unreachable",
  "timestamp": "2026-05-03T16:31:59.142Z"
}
```

---

### `POST /v1/commitments`

Save or update a user's ReClaim commitment.

**Request Body:**
```json
{
  "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "dailyLimitMinutes": 120,
  "focusWindows": [
    { "start": "09:00", "end": "12:00", "daysOfWeek": [1, 2, 3, 4, 5] }
  ],
  "whitelistPackages": ["com.android.chrome", "com.whatsapp"],
  "blacklistPackages": ["com.instagram.android", "com.google.android.youtube"],
  "allowWhatsApp": true,
  "maxOverridesPerDay": 2,
  "rewardSystemEnabled": true
}
```

**Validation Rules:**
| Field | Rule |
|---|---|
| `userId` | Required. Must be a valid UUID. |
| `dailyLimitMinutes` | Required. Integer, 15–1440. |
| `focusWindows` | Optional. Array of `{start: "HH:mm", end: "HH:mm", daysOfWeek: [1-7]}`. Max 20. |
| `whitelistPackages` | Optional. Array of strings, max 100 entries. |
| `blacklistPackages` | Optional. Array of strings, max 100 entries. |
| `allowWhatsApp` | Optional. Boolean, defaults to `true`. |
| `maxOverridesPerDay` | Optional. Integer, 0–10, defaults to 2. |
| `rewardSystemEnabled` | Optional. Boolean, defaults to `true`. |

**Response 201:** `{"status": "saved"}`  
**Response 400:** Validation error with field-level details.

---

### `GET /v1/commitments/:userId`

Retrieve a user's current commitment.

**Response 200:**
```json
{
  "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "dailyLimitMinutes": 120,
  "focusWindows": [],
  "whitelistPackages": ["com.android.chrome"],
  "blacklistPackages": ["com.instagram.android"],
  "allowWhatsApp": true,
  "maxOverridesPerDay": 2,
  "rewardSystemEnabled": true
}
```

**Response 404:** `{"error": "Commitment not found", "code": "NOT_FOUND"}`

---

### `POST /v1/analytics/events`

Ingest usage events from the Android device. Supports batch ingestion (up to 500 events) with idempotent dedup.

**Request Body:**
```json
{
  "events": [
    {
      "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
      "packageName": "com.instagram.android",
      "startedAt": "2026-05-03T10:00:00.000Z",
      "endedAt": "2026-05-03T10:30:00.000Z",
      "durationSeconds": 1800,
      "eventType": "usage",
      "metadata": { "clientEventId": "evt-001" }
    }
  ]
}
```

**Validation Rules:**
| Field | Rule |
|---|---|
| `events` | Required. Array, 1–500 items. |
| `events[].userId` | Required. Valid UUID. |
| `events[].packageName` | Required. String, 1–200 chars. |
| `events[].startedAt` | Required. ISO 8601 datetime. |
| `events[].endedAt` | Required. ISO 8601 datetime. |
| `events[].durationSeconds` | Required. Integer, 0–86400. |
| `events[].eventType` | Required. One of: `usage`, `blocked_attempt`, `override`. |
| `events[].metadata` | Optional. JSON object. |
| `events[].clientEventId` | Optional. String. Enables idempotent dedup — resending the same `clientEventId` for the same `userId` is silently skipped. |

**Response 202:**
```json
{
  "status": "accepted",
  "received": 2,
  "inserted": 1
}
```

The `inserted` count may be less than `received` if duplicates were skipped.

---

### `GET /v1/analytics/daily/:userId`

Compute and return daily analytics for a given date.

**Query Parameters:**
| Param | Type | Default | Description |
|---|---|---|---|
| `date` | `YYYY-MM-DD` | Today | Date to compute analytics for |
| `timeZone` | String | `Asia/Kolkata` | IANA timezone for time-of-day calculations |

**Response 200:**
```json
{
  "metrics": {
    "userId": "...",
    "dateKey": "2026-05-03",
    "totalScreenMinutes": 75,
    "blockedAttempts": 0,
    "overridesUsed": 0,
    "distractionMinutes": 30,
    "focusMinutes": 0,
    "lateNightMinutes": 0,
    "appSwitches": 0
  },
  "insights": {
    "distractionRiskScore": 40,
    "appSwitchesPerHour": 0,
    "lateNightMinutes": 0,
    "peakUsageHour": 16,
    "longestContinuousSessionMinutes": 45,
    "excessiveUsageFlags": ["extended_session"],
    "recommendations": ["Break long sessions with a 10-minute nudge at the 30-minute mark."]
  },
  "reward": {
    "pointsEarned": 85,
    "streakDays": 1,
    "badges": ["Distraction Free Day", "No Escape Token", "Night Guard"],
    "level": "Beginner",
    "summary": "Disciplined day completed."
  },
  "appBreakdown": [
    { "appName": "com.android.chrome", "category": "productivity", "totalMinutes": 45 }
  ],
  "categoryBreakdown": [
    { "category": "productivity", "totalMinutes": 45 },
    { "category": "social", "totalMinutes": 30 }
  ]
}
```

---

### `GET /v1/analytics/weekly/:userId`

Compute and return weekly analytics with week-over-week comparisons.

**Query Parameters:**
| Param | Type | Default | Description |
|---|---|---|---|
| `dateTo` | `YYYY-MM-DD` | Today | End date of the 7-day window |
| `timeZone` | String | `Asia/Kolkata` | IANA timezone |

**Response 200:** Full weekly report with trends, breakdowns, insights, and recommendations.

---

### `GET /v1/policy/:userId`

Evaluate the current enforcement policy based on today's usage.

**Query Parameters:**
| Param | Type | Default |
|---|---|---|
| `date` | `YYYY-MM-DD` | Today |
| `timeZone` | String | `Asia/Kolkata` |

**Response 200:**
```json
{
  "status": "normal",
  "reason": "Normal usage window.",
  "remainingDailyMinutes": 45,
  "overridesRemaining": 2,
  "blockedPackages": []
}
```

Policy `status` values: `normal`, `focus_only`, `locked`.

---

### `GET /v1/rewards/:userId`

Get reward data (points, streak, badges) for a specific date.

**Query Parameters:**
| Param | Type | Default |
|---|---|---|
| `date` | `YYYY-MM-DD` | Today |

**Response 200:**
```json
{
  "points": 85,
  "streakDays": 1,
  "badges": ["Distraction Free Day", "No Escape Token", "Night Guard"],
  "insights": { ... }
}
```

---

### `POST /v1/devices`

Register a hardware device for cross-device sync and FCM support.

**Request Body:**
```json
{
  "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "deviceId": "android-abc-123",
  "model": "Pixel 6 Pro",
  "osVersion": "13",
  "fcmToken": "fcm-token-string"
}
```

**Response 200:** `{"status": "registered"}`

---

### `GET /v1/export/:userId`

Export user usage data in JSON or CSV format.

**Query Parameters:**
| Param | Type | Default | Description |
|---|---|---|---|
| `dateFrom` | `YYYY-MM-DD` | Today | Start date |
| `dateTo` | `YYYY-MM-DD` | Today | End date |
| `format` | `json` \| `csv` | `json` | Output format |

**Response 200:** JSON array or CSV file stream.

---

## Error Responses

### Validation Error (400)
```json
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "details": [
    { "path": "userId", "message": "Must be a valid UUID" },
    { "path": "dailyLimitMinutes", "message": "Invalid input: expected number, received undefined" }
  ]
}
```

### Not Found (404)
```json
{
  "error": "Commitment not found",
  "code": "NOT_FOUND"
}
```

### Server Error (500)
```json
{
  "error": "An unexpected error occurred.",
  "code": "INTERNAL_ERROR"
}
```

In development mode, 500 errors also include `debug` (error message) and `stack` (stack trace).


