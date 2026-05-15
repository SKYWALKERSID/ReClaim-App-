-- Migration 016: Habit Coach Security & Auditing
-- Implements server-side history, audit logging, and security tracking.

-- Coach Sessions (Server-side source of truth for conversations)
CREATE TABLE IF NOT EXISTS coach_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mode TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::JSONB,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Coach Messages (Server-side history storage)
CREATE TABLE IF NOT EXISTS coach_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES coach_sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    tokens INTEGER, -- Estimated or actual token count
    is_flagged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Coach Audit Logs (Cost attribution and anomaly detection)
CREATE TABLE IF NOT EXISTS coach_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES coach_sessions(id) ON DELETE SET NULL,
    input_tokens INTEGER NOT NULL,
    output_tokens INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    model_used TEXT NOT NULL,
    status_code INTEGER NOT NULL,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for security lookups and performance
CREATE INDEX IF NOT EXISTS idx_coach_sessions_user ON coach_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_coach_messages_session ON coach_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_coach_audit_logs_user ON coach_audit_logs(user_id, created_at DESC);

-- Ensure RLS-like partitioning: session lookups must always include user_id
-- (Implemented via application logic, but indexes support this)
