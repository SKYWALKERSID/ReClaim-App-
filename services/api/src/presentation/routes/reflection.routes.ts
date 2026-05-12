import { Router } from 'express';
import { reflectionBatchSchema } from '../schemas/reflection.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

/**
 * POST /v1/analytics/reflection/sync
 * Upserts a batch of reflection events from the Android native layer.
 * Requires a valid Bearer JWT — authMiddleware is applied on the parent /v1 router.
 */
router.post('/sync', async (req, res) => {
  try {
    const { events } = reflectionBatchSchema.parse(req.body);
    const userId = req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED', message: 'Valid Bearer token required.' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const event of events) {
        await client.query(
          `INSERT INTO reflection_events (user_id, session_id, prompt_type, response, drift_score, timestamp)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [userId, event.session_id, event.prompt_type, event.response, event.drift_score, event.timestamp]
        );
      }
      await client.query('COMMIT');
      res.status(200).json({ success: true, count: events.length });
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
