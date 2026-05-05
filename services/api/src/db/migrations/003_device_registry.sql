-- Migration: 003_device_registry
-- Description: Add device tracking for cross-device support

CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    model TEXT,
    os_version TEXT,
    fcm_token TEXT,
    last_sync_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
