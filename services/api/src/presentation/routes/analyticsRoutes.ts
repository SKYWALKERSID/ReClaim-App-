import { Router } from "express";
import { z } from "zod";
import { AnalyticsService } from "../../services/analytics.service.js";
import {
  eventsPayloadSchema,
  dailyQuerySchema,
  weeklyQuerySchema,
  userIdParamSchema,
  deviceRegistrationSchema,
} from "../schemas/schemas.js";
import { rateLimiter } from "../middleware/rateLimiter.js";
import { UsageEvent } from "../../domain/types/index.js";
import { resolvePathUserId } from "../utils/resolvePathUserId.js";

export function buildAnalyticsRoutes(service: AnalyticsService): Router {
  const router = Router();
  
  // Strict rate limit for event ingestion (20 per minute)
  const ingestionLimiter = rateLimiter({ windowMs: 60 * 1000, max: 20, keyPrefix: "ingestion" });

  /**
   * @openapi
   * /notifications/nudge:
   *   post:
   *     summary: Send nudge notification
   *     description: Sends a push notification to all devices of a user.
   *     responses:
   *       200:
   *         description: Nudge sent
   */
  router.post("/notifications/nudge", async (request, response, next) => {
    try {
      const { userId, title, body } = z.object({
        userId: z.string().min(1),
        title: z.string().min(1),
        body: z.string().min(1)
      }).parse({ ...request.body, userId: request.user!.role === 'admin' ? request.body.userId : request.user!.userId });

      await service.sendNudge(userId, title, body);
      response.status(200).json({ status: "ok" });
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /notifications/token:
   *   post:
   *     summary: Update notification token
   *     description: Registers or updates the FCM token for push notifications.
   *     responses:
   *       200:
   *         description: Token updated
   */
  router.post("/notifications/token", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({ error: "Forbidden", message: "User JWT required." });
        return;
      }
      const { fcmToken, deviceId } = z.object({
        fcmToken: z.string().min(1),
        deviceId: z.string().min(1)
      }).parse(request.body);

      const userId = request.user!.userId;
      // Re-use registerDevice logic but only for the purpose of push notification tokens
      await service.registerDevice(userId, deviceId, undefined, undefined, fcmToken);
      response.status(200).json({ status: "ok" });
    } catch (error) {
      next(error);
    }
  });


  /**
   * @openapi
   * /analytics/daily/{userId}:
   *   get:
   *     summary: Get daily analytics
   *     parameters:
   *       - in: path
   *         name: userId
   *         required: true
   *         schema: { type: string, format: uuid }
   *       - in: query
   *         name: date
   *         schema: { type: string, format: date }
   *       - in: query
   *         name: timeZone
   *         schema: { type: string }
   *     responses:
   *       200:
   *         description: Daily analytics summary
   */
  router.get("/analytics/daily/:userId", async (request, response, next) => {
    try {
      const userId = resolvePathUserId(request, response);
      if (userId === null) {
        return;
      }
      const query = dailyQuerySchema.parse(request.query);
      const dateKey = query.date ?? new Date().toISOString().slice(0, 10);
      const result = await service.computeDailyAnalytics(userId, dateKey, query.timeZone);
      response.setHeader("Cache-Control", "private, max-age=60");
      response.json(result);
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /analytics/weekly/{userId}:
   *   get:
   *     summary: Get weekly trend report
   *     parameters:
   *       - in: path
   *         name: userId
   *         required: true
   *         schema: { type: string, format: uuid }
   *     responses:
   *       200:
   *         description: Weekly trends and recommendations
   */
  router.get("/analytics/weekly/:userId", async (request, response, next) => {
    try {
      const userId = resolvePathUserId(request, response);
      if (userId === null) {
        return;
      }
      const query = weeklyQuerySchema.parse(request.query);
      const dateTo = query.dateTo ?? new Date().toISOString().slice(0, 10);
      const result = await service.computeWeeklyReport(userId, dateTo, query.timeZone);
      response.setHeader("Cache-Control", "private, max-age=60");
      response.json(result);
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /export/{userId}:
   *   get:
   *     summary: Export user data
   *     description: Download usage history in JSON or CSV format.
   *     parameters:
   *       - in: path
   *         name: userId
   *         required: true
   *         schema: { type: string, format: uuid }
   *       - in: query
   *         name: format
   *         schema: { type: string, enum: [json, csv] }
   *     responses:
   *       200:
   *         description: Export file
   */
  router.get("/export/:userId", async (request, response, next) => {
    try {
      const userId = resolvePathUserId(request, response);
      if (userId === null) return;
      
      const { dateFrom, dateTo, format } = z.object({
        dateFrom: z.string().optional(),
        dateTo: z.string().optional(),
        format: z.enum(["json", "csv"]).default("json")
      }).parse(request.query);

      const today = new Date().toISOString().slice(0, 10);
      const from = dateFrom ?? today;
      const to = dateTo ?? today;

      const { stream, client } = await service.getExportStream(userId, from, to);

      if (format === "csv") {
        response.setHeader("Content-Type", "text/csv");
        response.setHeader("Content-Disposition", `attachment; filename=export_${userId}_${from}_${to}.csv`);
        response.write("userId,packageName,startedAt,endedAt,durationSeconds,eventType,category\n");
        
        stream.on("data", (row) => {
          response.write(service.formatEventAsCsvLine(row) + "\n");
        });
      } else {
        response.setHeader("Content-Type", "application/json");
        response.write("[");
        let first = true;
        stream.on("data", (row) => {
          if (!first) response.write(",");
          response.write(JSON.stringify({
            userId: row.user_id,
            packageName: row.package_name,
            startedAt: row.started_at.toISOString(),
            endedAt: row.ended_at.toISOString(),
            durationSeconds: row.duration_seconds,
            eventType: row.event_type,
            metadata: row.metadata
          }));
          first = false;
        });
      }

      stream.on("end", () => {
        if (format === "json") response.write("]");
        response.end();
        client.release();
      });

      stream.on("error", (err) => {
        client.release();
        next(err);
      });

      request.on("close", () => {
        client.release();
      });

    } catch (error) {
      next(error);
    }
  });





  return router;
}
