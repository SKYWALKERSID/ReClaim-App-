import admin from "firebase-admin";
import { logger } from "../utils/logger.js";
import { AnalyticsRepository } from "../db/repositories/analytics.repository.js";

/**
 * NotificationService handles sending push notifications to registered devices via FCM.
 */
export class NotificationService {
  private isInitialized = false;

  constructor(private readonly repository: AnalyticsRepository) {
    this._initializeFirebase();
  }

  private _initializeFirebase() {
    try {
      let rawConfig = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (!rawConfig) {
        logger.warn("[NotificationService] FIREBASE_SERVICE_ACCOUNT not set. Running in mock mode.");
        return;
      }

      if (!admin.apps.length) {
        // Handle potential formatting issues from .env (outer quotes, etc.)
        rawConfig = rawConfig.trim();
        if ((rawConfig.startsWith("'") && rawConfig.endsWith("'")) || 
            (rawConfig.startsWith('"') && rawConfig.endsWith('"'))) {
          rawConfig = rawConfig.slice(1, -1);
        }

        let serviceAccount;
        try {
          serviceAccount = JSON.parse(rawConfig);
        } catch (parseError) {
          // If first parse fails, it's often due to literal newlines or bad escapes from .env
          // We convert literal newlines/CRs to escaped ones so JSON.parse can handle them
          const fixedConfig = rawConfig
            .replace(/\r/g, "\\r")
            .replace(/\n/g, "\\n")
            .replace(/\\([^"\\\/bfnrtu])/g, "$1");
          
          serviceAccount = JSON.parse(fixedConfig);
        }

        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
        this.isInitialized = true;
        logger.info("[NotificationService] Firebase Admin initialized successfully.");
      } else {
        // Firebase already initialized by a previous instance; re-use it.
        this.isInitialized = true;
      }
    } catch (e) {
      logger.error("[NotificationService] Firebase Admin init failed with invalid credentials:", { error: String(e) });
    }
  }

  /**
   * Sends a notification to all devices registered to a user.
   */
  async sendNudge(userId: string, title: string, body: string): Promise<{ sent: number; failed: number }> {
    return this.sendNotification(userId, { title, body });
  }

  /**
   * Sends a structured notification with optional data payload.
   */
  async sendNotification(
    userId: string, 
    notification: { title: string; body: string; data?: Record<string, string> }
  ): Promise<{ sent: number; failed: number }> {
    const devices = await this.repository.getDevices(userId);
    const tokens = devices.map(d => d.fcmToken).filter(t => !!t) as string[];

    if (tokens.length === 0) {
      logger.debug(`[NotificationService] No FCM tokens found for User ${userId}`);
      return { sent: 0, failed: 0 };
    }

    if (!this.isInitialized) {
      logger.info(`[NotificationService] [MOCK] Notification to ${tokens.length} device(s) for User ${userId}: "${notification.title}"`);
      return { sent: tokens.length, failed: 0 };
    }

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: notification.title, body: notification.body },
        data: notification.data,
        android: {
          priority: "high",
          notification: {
            channelId: "focus_nudge",
            icon: "ic_notification",
            color: "#6366f1"
          }
        }
      });

      logger.info(`[NotificationService] FCM batch result: ${response.successCount} sent, ${response.failureCount} failed.`);
      return { sent: response.successCount, failed: response.failureCount };
    } catch (e) {
      logger.error("[NotificationService] FCM sendEachForMulticast failed:", { error: String(e) });
      return { sent: 0, failed: tokens.length };
    }
  }
}
