-- Migration 003: Production hardening
-- Adds performance indexes, dedup support, and analytics helpers

-- Fast event-type filtering (blocked_attempt count, override count)
CREATE INDEX IF NOT EXISTS usage_events_user_type_idx
  ON usage_events (user_id, event_type, started_at DESC);

-- Fast category breakdown queries
CREATE INDEX IF NOT EXISTS usage_logs_user_category_idx
  ON usage_logs (user_id, category, start_time DESC);

-- Fast streak lookups (ORDER BY date_key DESC LIMIT 1)
CREATE INDEX IF NOT EXISTS daily_analytics_streak_idx
  ON daily_analytics (user_id, date_key DESC);

-- Dedup index for usage_logs (prevent double-insert on re-sync)
CREATE UNIQUE INDEX IF NOT EXISTS usage_logs_dedup_idx
  ON usage_logs (user_id, app_name, start_time, end_time);

-- Add created_at to usage_events if missing (for retention queries)
ALTER TABLE usage_events
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Add client_event_id to usage_events if missing (for idempotency)
ALTER TABLE usage_events
  ADD COLUMN IF NOT EXISTS client_event_id TEXT;

-- Function: clean up old raw events (call via cron or scheduled job)
CREATE OR REPLACE FUNCTION cleanup_old_events(retention_days INTEGER DEFAULT 90)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_events INTEGER;
  deleted_logs INTEGER;
BEGIN
  DELETE FROM usage_events
  WHERE started_at < NOW() - (retention_days || ' days')::INTERVAL;
  GET DIAGNOSTICS deleted_events = ROW_COUNT;

  DELETE FROM usage_logs
  WHERE start_time < NOW() - (retention_days || ' days')::INTERVAL;
  GET DIAGNOSTICS deleted_logs = ROW_COUNT;

  RETURN deleted_events + deleted_logs;
END;
$$;

-- Function: get user streak (avoids repeated app-level query)
CREATE OR REPLACE FUNCTION get_current_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  streak INTEGER := 0;
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT date_key, streak_days
    FROM daily_analytics
    WHERE user_id = p_user_id
    ORDER BY date_key DESC
    LIMIT 1
  LOOP
    streak := rec.streak_days;
  END LOOP;
  RETURN streak;
END;
$$;
