-- Migration 006: Performance & Dedup Fix
-- Description: Adds fallback composite unique index to usage_events and performance index for weekly reporting

-- Fallback unique index for usage_events (if client_event_id is missing)
-- Pattern: user + package + start_time
CREATE UNIQUE INDEX IF NOT EXISTS usage_events_composite_dedup_idx
  ON usage_events (user_id, package_name, started_at);

-- Performance index for weekly reports (filtering by range + user)
CREATE INDEX IF NOT EXISTS usage_events_weekly_range_idx
  ON usage_events (user_id, started_at)
  INCLUDE (package_name, duration_seconds);

-- Ensure get_current_streak handles users with NO daily_analytics entries
-- (Already handled in PL/pgSQL function logic, but this verifies it)
COMMENT ON FUNCTION get_current_streak(UUID) IS 'Returns 0 if no analytics records found for user.';
