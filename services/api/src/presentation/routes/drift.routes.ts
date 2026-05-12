import { Router } from 'express';
import { driftBatchSchema } from '../schemas/drift.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

/**
 * POST /v1/analytics/drift/sync
 * Upserts a batch of Cognitive Drift Engine session records from the Android native layer.
 * Requires a valid Bearer JWT — userId is always sourced from the verified token, not from headers.
 */
router.post('/sync', async (req, res) => {
  try {
    const { sessions } = driftBatchSchema.parse(req.body);

    // userId is extracted from the verified JWT payload set by authMiddleware on the parent /v1 router.
    // Never trust x-user-id headers — they can be forged by any caller.
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED', message: 'Valid Bearer token required.' });
      return;
    }

    if (!sessions.length) {
      res.status(200).json({ success: true, count: 0 });
      return;
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
    res.status(400).json({ error: 'Bad Request', code: 'BAD_REQUEST', message: error.message });
  }
});

export default router;
