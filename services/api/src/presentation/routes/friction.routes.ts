import { Router } from 'express';
import { frictionBatchSchema } from '../schemas/friction.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

/**
 * POST /v1/analytics/friction/sync
 * Upserts a batch of friction intervention events from the Android native layer.
 * Requires a valid Bearer JWT — authMiddleware is applied on the parent /v1 router.
 */
router.post('/sync', async (req, res) => {
  try {
    const { events } = frictionBatchSchema.parse(req.body);
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
          `INSERT INTO friction_events (user_id, app_package, friction_type, drift_score, overridden, timestamp)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [userId, event.app_package, event.friction_type, event.drift_score, event.overridden, event.timestamp]
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
