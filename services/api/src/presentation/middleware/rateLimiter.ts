import rateLimit from "express-rate-limit";

export function rateLimiter(
  options: { windowMs: number; max: number; keyPrefix?: string }
) {
  return rateLimit({
    windowMs: options.windowMs,
    max: options.max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => `${options.keyPrefix ?? "rl"}:${req.ip}`,
    validate: { ip: false },
    message: {
      error: "Too Many Requests",
      code: "RATE_LIMIT_EXCEEDED",
      message: `Please try again later.`
    }
  });
}
