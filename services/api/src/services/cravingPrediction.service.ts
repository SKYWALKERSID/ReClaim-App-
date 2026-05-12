import { pool } from '../db/pool.js';
import { logger } from "../utils/logger.js";

export class CravingPredictionService {
  async predictForUser(userId: string) {
    try {
      // 1. Analyze hourly drift clusters over the last 7 days
      // We look for hours where drift score is consistently high (>60)
      const query = `
        SELECT 
          EXTRACT(HOUR FROM TO_TIMESTAMP(start_time / 1000)) as hour,
          AVG(avg_drift_score) as avg_drift,
          COUNT(*) as session_count
        FROM drift_sessions
        WHERE user_id = $1 AND start_time > (EXTRACT(EPOCH FROM NOW()) - 604800) * 1000
        GROUP BY hour
        HAVING AVG(avg_drift_score) > 50
        ORDER BY avg_drift DESC
        LIMIT 3
      `;
      
      const result = await pool.query(query, [userId]);
      const clusters = result.rows;

      // 2. Clear old predicted windows for today
      await pool.query('DELETE FROM craving_windows WHERE user_id = $1 AND window_start > NOW()', [userId]);

      // 3. Create windows for the top predicted hours
      for (const cluster of clusters) {
        const hour = parseInt(cluster.hour);
        const probability = Math.min(0.95, (cluster.avg_drift / 100) + (cluster.session_count / 50));
        
        const start = new Date();
        start.setHours(hour, 0, 0, 0);
        
        // If the hour has already passed today, predict for tomorrow
        if (start < new Date()) {
          start.setDate(start.getDate() + 1);
        }

        const end = new Date(start);
        end.setHours(start.getHours() + 1);

        await pool.query(
          `INSERT INTO craving_windows (user_id, probability, window_start, window_end, dominant_trigger)
           VALUES ($1, $2, $3, $4, $5)`,
          [userId, probability, start, end, 'Historical Cluster']
        );
      }

      logger.info(`Generated ${clusters.length} craving windows for user ${userId}`);
    } catch (error) {
      logger.error('Error predicting craving windows', error);
    }
  }

  async getAllUsers() {
    const result = await pool.query('SELECT id FROM users');
    return result.rows.map((r: { id: string }) => r.id);
  }
}
