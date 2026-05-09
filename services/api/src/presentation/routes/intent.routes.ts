import { Router, Request, Response } from 'express';
import { intentBatchSchema } from '../schemas/intent.schema.js';
import { pool } from '../../db/pool.js';

const router = Router();

router.post('/batch', async (req: Request, res: Response) => {
  try {
    const validated = intentBatchSchema.parse(req.body);
    const userId = req.headers['x-user-id'] as string; // Assuming user ID comes from header or auth middleware

    if (!userId) {
      return res.status(401).json({ error: 'User ID required' });
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
    res.status(400).json({ error: error.message });
  }
});

export default router;
