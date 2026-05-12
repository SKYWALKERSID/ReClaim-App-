import { Router } from "express";
import { AuthController } from "../controllers/auth.controller.js";
import { validate } from "../middleware/validate.middleware.js";
import { loginSchema, refreshSchema, logoutSchema } from "../schemas/auth.schema.js";
import { authLimiter, refreshLimiter, logoutLimiter } from "../middleware/rateLimit.middleware.js";

export function buildAuthRoutes(): Router {
  const router = Router();
  const controller = new AuthController();

  /**
   * @openapi
   * /auth/login:
   *   post:
   *     summary: Production Login
   *     description: Verifies Firebase ID Token, upserts user, and returns RS256 JWT pair.
   *     tags: [Auth]
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/LoginRequest'
   *     responses:
   *       200:
   *         description: Success
   *       401:
   *         description: Invalid credentials
   */
  router.post("/auth/login", authLimiter, validate(loginSchema), (req, res, next) => controller.login(req, res, next));

  /**
   * @openapi
   * /auth/refresh:
   *   post:
   *     summary: Refresh Access Token
   *     description: Rotates refresh token and issues new access token.
   *     tags: [Auth]
   */
  router.post("/auth/refresh", refreshLimiter, validate(refreshSchema), (req, res, next) => controller.refresh(req, res, next));

  /**
   * @openapi
   * /auth/logout:
   *   post:
   *     summary: Revoke Session
   *     description: Deletes the refresh token from the database.
   *     tags: [Auth]
   */
  router.post("/auth/logout", logoutLimiter, validate(logoutSchema), (req, res, next) => controller.logout(req, res, next));
  
  router.post("/auth/otp/send", (req, res) => controller.sendOTP(req, res));
  router.post("/auth/otp/verify", (req, res) => controller.verifyOTP(req, res));

  return router;
}
