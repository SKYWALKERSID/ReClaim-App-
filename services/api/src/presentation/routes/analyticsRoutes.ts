import { Router } from "express";
import { z } from "zod";
import { AnalyticsService } from "../../application/analyticsService.js";
import {
  eventsPayloadSchema,
  dailyQuerySchema,
  weeklyQuerySchema,
  userIdParamSchema,
  deviceRegistrationSchema,
} from "../validation/schemas.js";
import { rateLimiter } from "../middleware/rateLimiter.js";
import { UsageEvent } from "../../domain/types/index.js";
import { resolvePathUserId } from "../utils/resolvePathUserId.js";

export function buildAnalyticsRoutes(service: AnalyticsService): Router {
  const router = Router();
  
  // Strict rate limit for event ingestion (20 per minute)
  const ingestionLimiter = rateLimiter({ windowMs: 60 * 1000, max: 20, keyPrefix: "ingestion" });

  /**
   * @openapi
   * /analytics/events:
   *   post:
   *     summary: Ingest usage events
   *     description: Uploads a batch of usage events, blocked attempts, or overrides.
   *     security:
   *       - ApiKeyAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *             properties:
   *               events:
   *                 type: array
   *                 items: { type: object }
   *     responses:
   *       202:
   *         description: Accepted for processing
   */
  router.post("/analytics/events", ingestionLimiter, async (request, response, next) => {
    try {
      const { events } = eventsPayloadSchema.parse(request.body);

      let toIngest: UsageEvent[];
      if (request.user!.role === "service") {
        const ids = new Set(
          events.map((e) => e.userId).filter((x): x is string => typeof x === "string" && x.length > 0)
        );
        if (ids.size !== 1) {
          response.status(400).json({
            error: "Bad Request",
            code: "BAD_REQUEST",
            message: "When using x-api-key, every event must include the same userId.",
          });
          return;
        }
        const uid = [...ids][0]!;
        toIngest = events.map((e) => ({ ...e, userId: uid })) as UsageEvent[];
      } else {
        const uid = request.user!.userId;
        toIngest = events.map((e) => ({ ...e, userId: uid })) as UsageEvent[];
      }

      const inserted = await service.ingestEvents(toIngest);
      response.status(202).json({
        status: "accepted",
        received: events.length,
        inserted,
      });
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

  /**
   * @openapi
   * /devices:
   *   get:
   *     summary: List registered devices
   *     responses:
   *       200:
   *         description: List of devices
   *   post:
   *     summary: Register device
   *     description: Links a device to a user account for push notifications and sync.
   *     responses:
   *       200:
   *         description: Device registered
   */
  router.get("/devices", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({
          error: "Forbidden",
          code: "FORBIDDEN",
          message: "Device registry requires a user JWT.",
        });
        return;
      }
      const userId = request.user!.userId;
      const devices = await service.getDevices(userId);
      response.json(devices);
    } catch (error) {
      next(error);
    }
  });

  router.post("/devices", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({
          error: "Forbidden",
          code: "FORBIDDEN",
          message: "Device registry requires a user JWT.",
        });
        return;
      }
      const body = deviceRegistrationSchema.parse(request.body);
      const userId = request.user!.userId;
      await service.registerDevice(userId, body.deviceId, body.model, body.osVersion, body.fcmToken);
      response.status(201).json({ status: "registered" });
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /devices/{deviceId}:
   *   delete:
   *     summary: Unregister device
   *     parameters:
   *       - in: path
   *         name: deviceId
   *         required: true
   *         schema: { type: string }
   *     responses:
   *       200:
   *         description: Device unregistered
   */
  router.delete("/devices/:deviceId", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({
          error: "Forbidden",
          code: "FORBIDDEN",
          message: "Device registry requires a user JWT.",
        });
        return;
      }
      const userId = request.user!.userId;
      const { deviceId } = request.params;
      await service.unregisterDevice(userId, deviceId);
      response.status(200).json({ status: "unregistered" });
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /test-nudge:
   *   post:
   *     summary: Send test nudge
   *     description: Triggers a test push notification to the user's devices.
   *     responses:
   *       200:
   *         description: Nudge sent
   */
  router.post("/test-nudge", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({
          error: "Forbidden",
          code: "FORBIDDEN",
          message: "Test nudge requires a user JWT.",
        });
        return;
      }
      const userId = request.user!.userId;
      await service.sendTestNudge(userId);
      response.status(200).json({ status: "nudge_sent" });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
