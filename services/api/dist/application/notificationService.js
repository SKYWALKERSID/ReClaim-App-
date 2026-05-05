import admin from "firebase-admin";
/**
 * NotificationService handles sending push notifications to registered devices via FCM.
 */
export class NotificationService {
    repository;
    isInitialized = false;
    constructor(repository) {
        this.repository = repository;
        this._initializeFirebase();
    }
    _initializeFirebase() {
        try {
            if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
                console.warn("[NotificationService] FIREBASE_SERVICE_ACCOUNT not set. Running in mock mode.");
                return;
            }
            if (!admin.apps.length) {
                const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
                admin.initializeApp({
                    credential: admin.credential.cert(serviceAccount),
                });
                this.isInitialized = true;
                console.log("[NotificationService] Firebase Admin initialized");
            }
        }
        catch (e) {
            console.error("[NotificationService] Firebase Admin init failed with invalid credentials:", e);
        }
    }
    /**
     * Sends a notification to all devices registered to a user.
     */
    async sendNudge(userId, title, body) {
        const devices = await this.repository.getDevices(userId);
        const tokens = devices.map(d => d.fcmToken).filter(t => !!t);
        if (tokens.length === 0) {
            console.log(`[NotificationService] No FCM tokens found for User ${userId}`);
            return { sent: 0, failed: 0 };
        }
        if (!this.isInitialized) {
            console.log(`[NotificationService] [MOCK] Sending nudge to ${tokens.length} devices for User ${userId}: ${title}`);
            return { sent: tokens.length, failed: 0 };
        }
        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens,
                notification: { title, body },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "focus_nudge",
                        icon: "ic_notification",
                        color: "#6366f1"
                    }
                }
            });
            console.log(`[NotificationService] FCM batch sent: ${response.successCount} success, ${response.failureCount} failure`);
            return { sent: response.successCount, failed: response.failureCount };
        }
        catch (e) {
            console.error("[NotificationService] FCM send failed:", e);
            return { sent: 0, failed: tokens.length };
        }
    }
}
