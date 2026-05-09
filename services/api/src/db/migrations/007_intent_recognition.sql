-- Migration: 007_intent_recognition
-- Created: 2026-05-08

CREATE TABLE intent_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_id UUID,
    app_package TEXT NOT NULL,
    intent_choice TEXT NOT NULL,
    trigger_reason TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_intent_events_user_id ON intent_events(user_id);
CREATE INDEX idx_intent_events_timestamp ON intent_events(timestamp);
