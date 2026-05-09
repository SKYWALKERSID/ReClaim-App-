# ReClaim™ Database Schema

ReClaim uses PostgreSQL 14 as its primary relational engine, optimized for time-series ingestion of usage events and state-management of user commitments.

---

## 🏗️ Table Definitions

### 1. `users`
Core user identity (synced with Firebase Auth).
- `id`: UUID (Primary Key)
- `firebase_uid`: VARCHAR(255) (Unique)
- `email`: VARCHAR(255)
- `created_at`: TIMESTAMP

### 2. `usage_events`
Time-series data for app usage.
- `id`: BIGSERIAL (Primary Key)
- `user_id`: UUID (Foreign Key -> users.id)
- `package_name`: VARCHAR(255)
- `started_at`: TIMESTAMP
- `ended_at`: TIMESTAMP
- `duration_seconds`: INTEGER
- `event_type`: VARCHAR(50) (usage, blocked, override)

### 3. `commitments`
User-defined discipline policies.
- `id`: UUID (Primary Key)
- `user_id`: UUID (Foreign Key -> users.id)
- `daily_limit_minutes`: INTEGER
- `focus_windows`: JSONB (Array of windows)
- `blacklist`: TEXT[]
- `whitelist`: TEXT[]
- `max_overrides`: INTEGER

### 4. `daily_analytics`
Aggregated daily metrics.
- `id`: UUID (Primary Key)
- `user_id`: UUID
- `date`: DATE
- `total_usage_minutes`: INTEGER
- `drift_score`: DECIMAL(3,2)
- `points_earned`: INTEGER
- `was_compliant`: BOOLEAN

### 5. `craving_windows`
Predicted high-risk interaction clusters.
- `id`: UUID (Primary Key)
- `user_id`: UUID
- `window_start`: TIMESTAMP
- `window_end`: TIMESTAMP
- `confidence`: DECIMAL(3,2)

---

## 📈 Optimization Strategies

### 1. Partitioning
The `usage_events` table is designed for range-based partitioning by `started_at` to ensure fast queries as the dataset grows.

### 2. Indexes
- **Usage Events**: `CREATE INDEX idx_usage_user_time ON usage_events (user_id, started_at DESC);`
- **Commitments**: `CREATE INDEX idx_commitments_user ON commitments (user_id);`
- **Analytics**: `CREATE UNIQUE INDEX idx_analytics_user_date ON daily_analytics (user_id, date);`

### 3. Data Retention
A background cron job (`purging.job.ts`) automatically archives and prunes events older than 90 days from the hot storage.

---
*Schema Version: 1.0.14*
