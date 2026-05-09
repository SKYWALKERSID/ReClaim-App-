-- Migration 009: Smart Friction Layer
CREATE TABLE friction_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    app_package TEXT NOT NULL,
    friction_type TEXT NOT NULL,
    drift_score INT DEFAULT 0,
    overridden BOOLEAN DEFAULT FALSE,
    timestamp BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_friction_user_time ON friction_events(user_id, timestamp DESC);
