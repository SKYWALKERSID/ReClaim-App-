import { Router } from "express";
import { pool } from "../../db/pool.js";
import { lastPurgeTime } from "../../jobs/purging.job.js";
import crypto from "crypto";

export function buildAdminRoutes() {
  const router = Router();

  /**
   * @openapi
   * /admin/stats:
   *   get:
   *     summary: Get system-wide statistics for admin dashboard
   *     tags: [Admin]
   */
  router.get("/stats", async (req, res, next) => {
    const adminKey = req.header("x-admin-key");
    const expectedKey = process.env.ADMIN_KEY;

    if (!adminKey || !expectedKey) {
      res.status(403).json({ error: "Forbidden", code: "FORBIDDEN", message: "Admin access required" });
      return;
    }

    // Timing-safe comparison
    const adminKeyBuffer = Buffer.from(adminKey);
    const expectedKeyBuffer = Buffer.from(expectedKey);

    if (adminKeyBuffer.length !== expectedKeyBuffer.length || !crypto.timingSafeEqual(adminKeyBuffer, expectedKeyBuffer)) {
      res.status(403).json({ error: "Forbidden", code: "FORBIDDEN", message: "Admin access required" });
      return;
    }

    try {
      const usersCount = await pool.query("SELECT COUNT(*)::int as count FROM users");
      const eventsCount = await pool.query("SELECT COUNT(*)::int as count FROM usage_events");
      const devicesCount = await pool.query("SELECT COUNT(*)::int as count FROM devices");
      const activeChallenges = await pool.query("SELECT COUNT(*)::int as count FROM challenges WHERE end_time > NOW()");

      res.json({
        totalUsers: usersCount.rows[0].count,
        totalEvents: eventsCount.rows[0].count,
        totalDevices: devicesCount.rows[0].count,
        activeChallenges: activeChallenges.rows[0].count,
        systemStatus: "healthy",
        lastPurge: lastPurgeTime ? lastPurgeTime.toISOString() : "Never"
      });
    } catch (e) {
      next(e);
    }
  });

  return router;
}
