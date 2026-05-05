import { Router } from "express";
import { evaluatePolicy } from "../../application/policyService.js";
import { AnalyticsRepository } from "../../infrastructure/analyticsRepository.js";
import {
  dailyQuerySchema,
  rewardQuerySchema,
} from "../validation/schemas.js";
import { resolvePathUserId } from "../utils/resolvePathUserId.js";

export function buildPolicyRoutes(repository: AnalyticsRepository): Router {
  const router = Router();

  /**
   * @openapi
   * /policy/{userId}:
   *   get:
   *     summary: Get active policy
   *     description: Evaluates user commitment against current usage to determine if apps should be blocked.
   *     parameters:
   *       - in: path
   *         name: userId
   *         required: true
   *         schema: { type: string, format: uuid }
   *     responses:
   *       200:
   *         description: Policy state (normal, focus_only, or locked)
   */
  router.get("/policy/:userId", async (request, response, next) => {
    try {
      const userId = resolvePathUserId(request, response);
      if (userId === null) {
        return;
      }
      const query = dailyQuerySchema.parse(request.query);
      const dateKey = query.date ?? new Date().toISOString().slice(0, 10);

      const commitment = await repository.getCommitment(userId);
      if (!commitment) {
        response.status(404).json({ error: "Commitment not found", code: "NOT_FOUND" });
        return;
      }

      const metrics =
        (await repository.getDailyMetrics(userId, dateKey)) ?? {
          userId,
          dateKey,
          totalScreenMinutes: 0,
          blockedAttempts: 0,
          overridesUsed: 0,
          distractionMinutes: 0,
          focusMinutes: 0,
          lateNightMinutes: 0,
          appSwitches: 0
        };

      const policy = evaluatePolicy(
        {
          commitment,
          metrics,
          now: new Date(),
          overridesUsedToday: metrics.overridesUsed
        },
        query.timeZone
      );

      response.json(policy);
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /rewards/{userId}:
   *   get:
   *     summary: Get rewards summary
   *     parameters:
   *       - in: path
   *         name: userId
   *         required: true
   *         schema: { type: string, format: uuid }
   *     responses:
   *       200:
   *         description: Rewards and points summary
   */
  router.get("/rewards/:userId", async (request, response, next) => {
    try {
      const userId = resolvePathUserId(request, response);
      if (userId === null) {
        return;
      }
      const query = rewardQuerySchema.parse(request.query);
      const dateKey = query.date ?? new Date().toISOString().slice(0, 10);

      const summary = await repository.getRewardSummary(userId, dateKey);
      if (!summary) {
        response.status(404).json({ error: "No reward data for date.", code: "NOT_FOUND" });
        return;
      }
      response.json(summary);
    } catch (error) {
      next(error);
    }
  });

  return router;
}
