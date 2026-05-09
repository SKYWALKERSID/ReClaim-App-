-- Migration 011: Craving Window Prediction
CREATE TABLE craving_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    probability FLOAT NOT NULL,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    dominant_trigger TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_craving_user_start ON craving_windows(user_id, window_start);
