-- Migration 014: Login Audit Table
-- Security: Tracks all login attempts to detect brute-force and credential stuffing.

CREATE TABLE IF NOT EXISTS login_audit (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        REFERENCES users(id) ON DELETE SET NULL,
  ip_address     INET,
  device_id      TEXT,
  success        BOOLEAN     NOT NULL,
  failure_reason TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for security monitoring and trend analysis
CREATE INDEX IF NOT EXISTS login_audit_user_idx ON login_audit(user_id);
CREATE INDEX IF NOT EXISTS login_audit_created_at_idx ON login_audit(created_at DESC);
CREATE INDEX IF NOT EXISTS login_audit_ip_idx ON login_audit(ip_address);
