import { Router } from "express";
import { pool } from "../../db/pool.js";
export const healthRoutes = Router();
/**
 * @openapi
 * /health:
 *   get:
 *     summary: Health check
 *     description: Returns the status of the API and database connectivity.
 *     responses:
 *       200:
 *         description: OK
 *       503:
 *         description: Service Unavailable (Database disconnected)
 */
healthRoutes.get("/health", async (_req, res) => {
    let dbOk = false;
    try {
        await pool.query("SELECT 1");
        dbOk = true;
    }
    catch {
        dbOk = false;
    }
    const status = dbOk ? "ok" : "degraded";
    const statusCode = dbOk ? 200 : 503;
    res.status(statusCode).json({
        status,
        service: "focus-minimalism-api",
        database: dbOk ? "connected" : "unreachable",
        timestamp: new Date().toISOString(),
    });
});
/**
 * @openapi
 * /metrics:
 *   get:
 *     summary: System metrics
 *     description: Returns uptime, memory usage, and database pool status.
 *     responses:
 *       200:
 *         description: OK
 */
healthRoutes.get("/metrics", (req, res) => {
    res.json({
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        database: {
            totalConnections: pool.totalCount,
            idleConnections: pool.idleCount,
            waitingRequests: pool.waitingCount
        },
        timestamp: new Date().toISOString()
    });
});
