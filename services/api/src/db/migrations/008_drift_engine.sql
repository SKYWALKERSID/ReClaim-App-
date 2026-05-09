-- Migration 008: Cognitive Drift Sessions
CREATE TABLE drift_sessions (
    session_id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    app_package TEXT NOT NULL,
    start_time BIGINT NOT NULL,
    end_time BIGINT,
    peak_drift_score INT DEFAULT 0,
    avg_drift_score INT DEFAULT 0,
    fragmentation_index INT DEFAULT 0,
    reopen_count INT DEFAULT 0,
    failed_exits INT DEFAULT 0,
    feed_exposure_seconds INT DEFAULT 0,
    intent_confidence FLOAT DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drift_user_time ON drift_sessions(user_id, start_time DESC);
