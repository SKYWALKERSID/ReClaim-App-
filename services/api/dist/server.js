import { buildApp } from "./app.js";
import { env } from "./config/env.js";
import { gracefulShutdownDB } from "./db/pool.js";
import { logger } from "./infrastructure/logger.js";
const app = buildApp();
const server = app.listen(env.port, () => {
    logger.info(`focus-minimalism-api listening on port ${env.port}`);
});
function gracefulShutdown(signal) {
    logger.info(`[server] ${signal} received. Closing HTTP server...`);
    server.close(async (err) => {
        if (err) {
            logger.error("[server] Error closing HTTP server:", err);
        }
        else {
            logger.info("[server] HTTP server closed.");
        }
        await gracefulShutdownDB();
        process.exit(err ? 1 : 0);
    });
}
process.on("SIGINT", () => gracefulShutdown("SIGINT"));
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
