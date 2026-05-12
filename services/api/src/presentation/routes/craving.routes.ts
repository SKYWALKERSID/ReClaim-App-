import { Router } from 'express';
import { pool } from '../../db/pool.js';

const router = Router();

/**
 * GET /v1/analytics/craving/active
 * Returns the currently active craving window for the authenticated user, if any.
 * Requires a valid Bearer JWT — authMiddleware is applied on the parent /v1 router.
 */
router.get('/active', async (req, res) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED', message: 'Valid Bearer token required.' });
      return;
    }

    const result = await pool.query(
      `SELECT * FROM craving_windows
       WHERE user_id = $1
         AND window_start <= NOW()
         AND window_end   >= NOW()
       ORDER BY probability DESC
       LIMIT 1`,
      [userId]
    );

    res.status(200).json(result.rows[0] ?? null);
  } catch (error: any) {
    res.status(500).json({ error: 'Internal Server Error', code: 'INTERNAL_ERROR', message: 'Failed to fetch craving windows.' });
  }
});

export default router;
