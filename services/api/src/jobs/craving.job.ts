import cron from 'node-cron';
import { CravingPredictionService } from '../services/cravingPrediction.service.js';
import { logger } from "../utils/logger.js";
import { NotificationService } from "../services/notification.service.js";
import { AnalyticsRepository } from "../db/repositories/analytics.repository.js";
import { pool } from '../db/pool.js';

export function startCravingWorker() {
  const predictionService = new CravingPredictionService();
  const repo = new AnalyticsRepository();
  const notificationService = new NotificationService(repo);

  // Run every 30 minutes
  cron.schedule('*/30 * * * *', async () => {
    logger.info('Running Craving Window Prediction Worker');
    const userIds = await predictionService.getAllUsers();
    
    for (const userId of userIds) {
      await predictionService.predictForUser(userId);
      await checkAndNotify(userId, notificationService);
    }
  });
}

async function checkAndNotify(userId: string, notificationService: NotificationService) {
  // Check if a window starts in the next 15-20 minutes
  const now = new Date();
  const fifteenMinsFromNow = new Date(now.getTime() + 15 * 60000);
  const twentyMinsFromNow = new Date(now.getTime() + 20 * 60000);

  const query = `
    SELECT * FROM craving_windows 
    WHERE user_id = $1 
    AND window_start BETWEEN $2 AND $3
    LIMIT 1
  `;
  
  const result = await pool.query(query, [userId, fifteenMinsFromNow, twentyMinsFromNow]);
  
  if (result.rows.length > 0) {
    logger.info(`Sending craving warning to user ${userId}`);
    await notificationService.sendNotification(userId, {
      title: "Incoming High-Risk Window",
      body: "We've detected a typical drift window approaching. Stay intentional.",
      data: { type: "CRAVING_WINDOW_APPROACHING" }
    });
  }
}
