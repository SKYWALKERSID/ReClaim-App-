import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { pool } from '../../db/pool.js';

const router = Router();

router.get('/active', authMiddleware, async (req, res) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const query = `
      SELECT * FROM craving_windows 
      WHERE user_id = $1 
      AND window_start <= NOW() 
      AND window_end >= NOW()
      ORDER BY probability DESC
      LIMIT 1
    `;
    
    const result = await pool.query(query, [userId]);
    res.status(200).json(result.rows[0] || null);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch craving windows' });
  }
});

export default router;
