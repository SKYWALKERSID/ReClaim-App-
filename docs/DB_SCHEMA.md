# ReClaim™ Database Schema

ReClaim uses PostgreSQL 14 with a modular, scalable schema optimized for time-series ingestion and relational social accountability.

---

## 🏗️ Core Tables

### 1. `users`
- `id`: UUID (Primary Key)
- `firebase_uid`: VARCHAR(255) (Unique) - Synced with Google Identity.
- `preferences`: JSONB - User-specific UI/Notification settings.
- `created_at`: TIMESTAMPTZ

### 2. `usage_events`
- `id`: BIGSERIAL (Primary Key)
- `user_id`: UUID (FK -> users.id)
- `package_name`: TEXT
- `started_at`: TIMESTAMPTZ
- `ended_at`: TIMESTAMPTZ
- `duration_seconds`: INTEGER
- `event_type`: TEXT (usage, blocked_attempt, override)
- `metadata`: JSONB (Includes `snapshotTotalMinutes`, `category`)
- `client_event_id`: TEXT (For idempotency)

### 3. `commitments`
- `user_id`: UUID (Primary Key, FK -> users.id)
- `daily_limit_minutes`: INTEGER
- `focus_windows`: JSONB
- `whitelist_packages`: TEXT[]
- `blacklist_packages`: TEXT[]
- `allow_whatsapp`: BOOLEAN
- `max_overrides_per_day`: INTEGER
- `reward_system_enabled`: BOOLEAN

---

## 🧠 Intelligence Plane

### 4. `drift_sessions`
High-resolution metrics from the Cognitive Drift Engine™.
- `session_id`: UUID (Primary Key)
- `user_id`: UUID
- `app_package`: TEXT
- `peak_drift_score`: DECIMAL(3,2)
- `fragmentation_index`: DECIMAL(3,2)
- `reopen_count`: INTEGER
- `feed_exposure_seconds`: INTEGER
- `intent_confidence`: DECIMAL(3,2)

### 5. `craving_windows`
Predicted risk clusters.
- `id`: UUID (Primary Key)
- `user_id`: UUID
- `window_start`: TIMESTAMPTZ
- `window_end`: TIMESTAMPTZ
- `probability`: DECIMAL(3,2)

---

## 🤝 Social & Auth

### 6. `buddies`
- `user_id`: UUID
- `buddy_id`: UUID
- `status`: TEXT (pending, accepted)

### 7. `challenges`
- `id`: UUID (Primary Key)
- `title`: TEXT
- `goal_minutes`: INTEGER
- `start_time`: TIMESTAMPTZ
- `end_time`: TIMESTAMPTZ

### 8. `refresh_tokens`
- `id`: UUID (Primary Key)
- `user_id`: UUID
- `token_hash`: TEXT
- `expires_at`: TIMESTAMPTZ
- `is_revoked`: BOOLEAN

---

## 📈 Optimization & Integrity

### Partitioning
`usage_events` is range-partitioned by `started_at`. Current strategy partitions by month.

### Indexes
- `usage_events_idempotency_idx`: Partial unique index on `client_event_id` to prevent duplicate ingestion.
- `usage_events_user_started_idx`: Optimized for reverse-chronological dashboard fetches.

### Maintenance
- `purging.job.ts`: Automatically prunes events older than 90 days.
- `daily_analytics` is refreshed every 4 hours via background worker.

---
*Schema Version: 2.0.14*
*Last Verified: May 11, 2026*
