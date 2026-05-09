import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { driftBatchSchema } from '../schemas/drift.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

router.post('/sync', authMiddleware, async (req, res) => {
  try {
    const { sessions } = driftBatchSchema.parse(req.body);
    const userId = req.headers['x-user-id'] as string;

    if (!sessions.length) {
      return res.status(200).json({ success: true, count: 0 });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const session of sessions) {
        await client.query(
          `INSERT INTO drift_sessions (
            session_id, user_id, app_package, start_time, end_time, 
            peak_drift_score, avg_drift_score, fragmentation_index, 
            reopen_count, failed_exits, feed_exposure_seconds, intent_confidence
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
          ON CONFLICT (session_id) DO UPDATE SET
            end_time = EXCLUDED.end_time,
            peak_drift_score = EXCLUDED.peak_drift_score,
            avg_drift_score = EXCLUDED.avg_drift_score,
            fragmentation_index = EXCLUDED.fragmentation_index`,
          [
            session.session_id, userId, session.app_package, 
            session.start_time, session.end_time,
            session.peak_drift_score, session.avg_drift_score, session.fragmentation_index,
            session.reopen_count, session.failed_exits, session.feed_exposure_seconds, session.intent_confidence
          ]
        );
      }
      await client.query('COMMIT');
      res.status(200).json({ success: true, count: sessions.length });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

export default router;
