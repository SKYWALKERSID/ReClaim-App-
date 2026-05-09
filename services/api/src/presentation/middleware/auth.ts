import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { env } from "../../config/env.js";
import { API_KEY_SERVICE_USER } from "../../config/authConstants.js";

/** Paths under `app.use("/v1", authMiddleware)` use `req.path` without the `/v1` prefix. */
const publicPaths = new Set(["/health", "/auth/anonymous", "/auth/login", "/auth/refresh", "/auth/logout"]);

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        role: string;
        deviceId?: string;
      };
    }
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Public routes
  if (publicPaths.has(req.path)) {
    return next();
  }

  const authHeader = req.header("authorization");
  const apiKey = req.header("x-api-key");

  if (apiKey && env.apiKeys.includes(apiKey)) {
    req.user = { userId: API_KEY_SERVICE_USER.userId, role: API_KEY_SERVICE_USER.role };
    return next();
  }

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({
      error: "Unauthorized",
      code: "UNAUTHORIZED",
      message: "A valid Authorization: Bearer token is required."
    });
    return;
  }

  const token = authHeader.split(" ")[1];

  try {
    if (!env.jwtPublicKey) {
      throw new Error("JWT_PUBLIC_KEY is not configured on the server.");
    }
    const decoded = jwt.verify(token, env.jwtPublicKey, { algorithms: ["RS256"] }) as any;
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({
      error: "Invalid Token",
      code: "UNAUTHORIZED",
      message: "The provided token is invalid or expired."
    });
  }
}
