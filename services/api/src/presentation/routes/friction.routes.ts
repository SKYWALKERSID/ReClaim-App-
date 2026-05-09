import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { frictionBatchSchema } from '../schemas/friction.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

router.post('/sync', authMiddleware, async (req, res) => {
  try {
    const { events } = frictionBatchSchema.parse(req.body);
    const userId = req.user?.userId;

    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

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
  } catch (err) {
    res.status(400).json({ error: 'Invalid payload' });
  }
});

export default router;
