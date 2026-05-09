-- Migration 010: Reflection Layer
CREATE TABLE reflection_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    session_id TEXT,
    prompt_type TEXT NOT NULL,
    response TEXT,
    drift_score INT DEFAULT 0,
    timestamp BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_reflection_user_time ON reflection_events(user_id, timestamp DESC);
