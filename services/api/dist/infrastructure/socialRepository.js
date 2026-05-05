import { pool } from "../db/pool.js";
export class SocialRepository {
    async addBuddy(userId, buddyId) {
        await pool.query(`INSERT INTO buddies (user_id, buddy_id, status)
       VALUES ($1, $2, 'accepted')
       ON CONFLICT (user_id, buddy_id) DO NOTHING`, [userId, buddyId]);
    }
    async getBuddies(userId) {
        const result = await pool.query(`SELECT b.buddy_id as "buddyId", b.status, u.preferences->>'name' as "buddyName"
       FROM buddies b
       JOIN users u ON b.buddy_id = u.id
       WHERE b.user_id = $1`, [userId]);
        return result.rows;
    }
    async createChallenge(data) {
        const result = await pool.query(`INSERT INTO challenges (title, creator_id, start_time, end_time, target_focus_minutes)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`, [data.title, data.creatorId, data.startTime, data.endTime, data.targetFocusMinutes]);
        return result.rows[0].id;
    }
    async joinChallenge(challengeId, userId) {
        await pool.query(`INSERT INTO challenge_participants (challenge_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`, [challengeId, userId]);
    }
    async getActiveChallenges() {
        const result = await pool.query(`SELECT c.id, c.title, c.start_time as "startTime", c.end_time as "endTime", 
              c.target_focus_minutes as "targetFocusMinutes",
              COUNT(cp.user_id)::int as "participantsCount"
       FROM challenges c
       LEFT JOIN challenge_participants cp ON c.id = cp.challenge_id
       WHERE c.end_time > NOW()
       GROUP BY c.id`);
        return result.rows;
    }
}
