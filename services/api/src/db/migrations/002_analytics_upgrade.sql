-- Migration 002: Analytics upgrade
-- Idempotent — safe to re-run

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS preferences JSONB NOT NULL DEFAULT '{}'::JSONB;

CREATE TABLE IF NOT EXISTS usage_logs (
  id               BIGSERIAL   PRIMARY KEY,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app_name         TEXT        NOT NULL,
  category         TEXT        NOT NULL DEFAULT 'other'
                               CHECK (category IN ('social','communication','productivity','entertainment','utility','other')),
  start_time       TIMESTAMPTZ NOT NULL,
  end_time         TIMESTAMPTZ NOT NULL,
  duration_seconds INTEGER     NOT NULL CHECK (duration_seconds >= 0),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS usage_logs_user_start_idx
  ON usage_logs (user_id, start_time DESC);

CREATE TABLE IF NOT EXISTS daily_summaries (
  user_id                  UUID    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date_key                 DATE    NOT NULL,
  total_screen_time_minutes INTEGER NOT NULL DEFAULT 0,
  category_breakdown       JSONB   NOT NULL DEFAULT '[]'::JSONB,
  app_breakdown            JSONB   NOT NULL DEFAULT '[]'::JSONB,
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, date_key)
);

CREATE TABLE IF NOT EXISTS insight_snapshots (
  user_id                UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date_key               DATE   NOT NULL,
  peak_usage_hour        INTEGER NOT NULL DEFAULT 0 CHECK (peak_usage_hour BETWEEN 0 AND 23),
  excessive_usage_flags  TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  recommendation_summary JSONB  NOT NULL DEFAULT '[]'::JSONB,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, date_key)
);
