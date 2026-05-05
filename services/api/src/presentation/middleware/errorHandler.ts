import { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";
import { env } from "../../config/env.js";
import { logger } from "../../infrastructure/logger.js";

type AppError = Error & {
  statusCode?: number;
  code?: string;
};

export function errorHandler(
  err: AppError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Zod validation errors → 400
  if (err instanceof ZodError) {
    res.status(400).json({
      error: "Validation failed",
      code: "VALIDATION_ERROR",
      details: err.issues.map((issue) => ({
        path: issue.path.join("."),
        message: issue.message,
      })),
    });
    return;
  }

  // Known application errors
  const statusCode = err.statusCode ?? 500;
  const code = err.code ?? "INTERNAL_ERROR";
  const message = statusCode < 500 ? err.message : "An unexpected error occurred.";

  // Log full error server-side (never leak stack to client in production)
  if (statusCode >= 500) {
    logger.error(err.message, {
      code,
      requestId: _req.requestId,
      userId: _req.user?.userId,
      stack: env.nodeEnv === "development" ? err.stack : undefined,
    });
  }

  res.status(statusCode).json({
    error: message,
    code,
    ...(env.nodeEnv === "development" && statusCode >= 500
      ? { debug: err.message, stack: err.stack }
      : {}),
  });
}

// Helper to create typed application errors
export function createAppError(
  message: string,
  statusCode: number,
  code: string
): AppError {
  const err = new Error(message) as AppError;
  err.statusCode = statusCode;
  err.code = code;
  return err;
}
