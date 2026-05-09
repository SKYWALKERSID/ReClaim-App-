-- Migration 012: Add Firebase UID and Profile Columns to Users
-- Security: Links Firebase Auth identity to PostgreSQL records reliably.

ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS firebase_uid TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS email TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS plan_type TEXT NOT NULL DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS onboarding_complete BOOLEAN NOT NULL DEFAULT FALSE;

-- Index for fast lookup during login/upsert
CREATE INDEX IF NOT EXISTS users_firebase_uid_idx ON users(firebase_uid);
