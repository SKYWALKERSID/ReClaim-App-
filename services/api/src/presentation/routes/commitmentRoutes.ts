import { Router } from "express";
import { AnalyticsService } from "../../application/analyticsService.js";
import { commitmentSchema, userIdParamSchema } from "../validation/schemas.js";

export function buildCommitmentRoutes(service: AnalyticsService): Router {
  const router = Router();

  /**
   * @openapi
   * /commitments:
   *   post:
   *     summary: Save user commitment
   *     description: Updates or creates a new screen-time commitment for the user.
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *             required: [dailyLimitMinutes]
   *             properties:
   *               dailyLimitMinutes: { type: integer, minimum: 15, maximum: 1440 }
   *               focusWindows: { type: array, items: { type: object } }
   *               whitelist: { type: array, items: { type: string } }
   *               blacklist: { type: array, items: { type: string } }
   *               maxOverrides: { type: integer, default: 2 }
   *     responses:
   *       201:
   *         description: Commitment saved successfully
   */
  router.post("/commitments", async (request, response, next) => {
    try {
      const commitment = commitmentSchema.parse(request.body);
      if (request.user!.role === "service") {
        if (!commitment.userId) {
          response.status(400).json({
            error: "Bad Request",
            code: "BAD_REQUEST",
            message: "userId is required in the body when authenticating with x-api-key.",
          });
          return;
        }
      } else {
        commitment.userId = request.user!.userId;
      }
      await service.upsertCommitment(commitment);
      response.status(201).json({ status: "saved" });
    } catch (error) {
      next(error);
    }
  });

  /**
   * @openapi
   * /commitments/me:
   *   get:
   *     summary: Get user commitment
   *     responses:
   *       200:
   *         description: User commitment details
   *       404:
   *         description: Commitment not found
   */
  router.get("/commitments/me", async (request, response, next) => {
    try {
      if (request.user!.role === "service") {
        response.status(403).json({
          error: "Forbidden",
          code: "FORBIDDEN",
          message: "Use GET /policy/:userId or include user scope with a user JWT.",
        });
        return;
      }
      const userId = request.user!.userId;
      const commitment = await service.getCommitment(userId);
      if (!commitment) {
        response.status(404).json({ error: "Commitment not found", code: "NOT_FOUND" });
        return;
      }
      response.json(commitment);
    } catch (error) {
      next(error);
    }
  });

  return router;
}
