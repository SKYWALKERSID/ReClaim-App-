-- 004_social_accountability.sql

-- Buddies Table (Follow system)
CREATE TABLE IF NOT EXISTS buddies (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    buddy_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'accepted', -- 'pending', 'accepted', 'blocked'
    PRIMARY KEY (user_id, buddy_id)
);

-- Group Challenges Table
CREATE TABLE IF NOT EXISTS challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    target_focus_minutes INTEGER NOT NULL,
    challenge_type TEXT DEFAULT 'group_total', -- 'individual_comp', 'group_total'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Challenge Participants
CREATE TABLE IF NOT EXISTS challenge_participants (
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    current_progress_minutes INTEGER DEFAULT 0,
    PRIMARY KEY (challenge_id, user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_buddies_user ON buddies(user_id);
CREATE INDEX IF NOT EXISTS idx_challenges_times ON challenges(start_time, end_time);
