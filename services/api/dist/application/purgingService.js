import { logger } from "../infrastructure/logger.js";
export let lastPurgeTime = null;
/**
 * PurgingService handles the automated deletion of old event data.
 */
export class PurgingService {
    repository;
    retentionDays;
    intervalId;
    constructor(repository, retentionDays = 90) {
        this.repository = repository;
        this.retentionDays = retentionDays;
    }
    /**
     * Starts the periodic cleanup job (every 24 hours).
     */
    start() {
        logger.info(`[PurgingService] Starting daily cleanup (Retention: ${this.retentionDays} days)`);
        // Run once on startup
        this.execute();
        // Schedule for every 24 hours
        this.intervalId = setInterval(() => {
            this.execute();
        }, 24 * 60 * 60 * 1000);
    }
    /**
     * Stops the scheduled job.
     */
    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
    }
    isRunning = false;
    async execute() {
        if (this.isRunning)
            return;
        this.isRunning = true;
        try {
            const deleted = await this.repository.runRetentionCleanup(this.retentionDays);
            lastPurgeTime = new Date();
            logger.info(`[PurgingService] Cleanup successful. Deleted ${deleted} old usage events.`);
        }
        catch (error) {
            logger.error("[PurgingService] Cleanup failed:", error);
        }
        finally {
            this.isRunning = false;
        }
    }
}
