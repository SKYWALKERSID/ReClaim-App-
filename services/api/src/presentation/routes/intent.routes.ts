import { Router } from 'express';
import { intentBatchSchema } from '../schemas/intent.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

/**
 * POST /v1/intents/batch
 * Upserts a batch of intent events captured by the Android native layer.
 * Requires a valid Bearer JWT — userId is always sourced from the verified token, not from headers.
 */
router.post('/batch', async (req, res) => {
  try {
    const validated = intentBatchSchema.parse(req.body);

    // userId is extracted from the verified JWT payload set by authMiddleware on the parent /v1 router.
    // Never trust x-user-id headers — they can be forged by any caller.
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED', message: 'Valid Bearer token required.' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (const event of validated.events) {
        await client.query(
          `INSERT INTO intent_events (user_id, app_package, intent_choice, trigger_reason, timestamp, synced)
           VALUES ($1, $2, $3, $4, $5, TRUE)`,
          [
            userId,
            event.app_package,
            event.intent_choice,
            event.trigger_reason,
            new Date(event.timestamp)
          ]
        );
      }

      await client.query('COMMIT');
      res.status(201).json({ success: true, count: validated.events.length });
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
