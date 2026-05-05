-- Migration 001: Core schema
-- Idempotent — safe to re-run

CREATE TABLE IF NOT EXISTS schema_migrations (
  version   TEXT        PRIMARY KEY,
  name      TEXT        NOT NULL DEFAULT '',
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id          UUID        PRIMARY KEY,
  preferences JSONB       NOT NULL DEFAULT '{}'::JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS commitments (
  user_id              UUID    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_limit_minutes  INTEGER NOT NULL CHECK (daily_limit_minutes BETWEEN 15 AND 1440),
  focus_windows        JSONB   NOT NULL DEFAULT '[]'::JSONB,
  whitelist_packages   TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
  blacklist_packages   TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
  allow_whatsapp       BOOLEAN NOT NULL DEFAULT TRUE,
  max_overrides_per_day INTEGER NOT NULL DEFAULT 2 CHECK (max_overrides_per_day BETWEEN 0 AND 10),
  reward_system_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usage_events (
  id               BIGSERIAL   PRIMARY KEY,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  package_name     TEXT        NOT NULL,
  started_at       TIMESTAMPTZ NOT NULL,
  ended_at         TIMESTAMPTZ NOT NULL,
  duration_seconds INTEGER     NOT NULL CHECK (duration_seconds >= 0),
  event_type       TEXT        NOT NULL CHECK (event_type IN ('usage', 'blocked_attempt', 'override')),
  metadata         JSONB       NOT NULL DEFAULT '{}'::JSONB,
  client_event_id  TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS usage_events_user_started_idx
  ON usage_events (user_id, started_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS usage_events_idempotency_idx
  ON usage_events (user_id, client_event_id)
  WHERE client_event_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS daily_analytics (
  user_id              UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date_key             DATE    NOT NULL,
  total_screen_minutes INTEGER NOT NULL DEFAULT 0,
  blocked_attempts     INTEGER NOT NULL DEFAULT 0,
  overrides_used       INTEGER NOT NULL DEFAULT 0,
  distraction_minutes  INTEGER NOT NULL DEFAULT 0,
  focus_minutes        INTEGER NOT NULL DEFAULT 0,
  late_night_minutes   INTEGER NOT NULL DEFAULT 0,
  app_switches         INTEGER NOT NULL DEFAULT 0,
  reward_points        INTEGER NOT NULL DEFAULT 0,
  streak_days          INTEGER NOT NULL DEFAULT 0,
  badges               TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[],
  insights             JSONB   NOT NULL DEFAULT '{}'::JSONB,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, date_key)
);
