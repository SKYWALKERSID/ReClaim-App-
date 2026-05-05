import rateLimit from "express-rate-limit";
export function rateLimiter(options) {
    return rateLimit({
        windowMs: options.windowMs,
        max: options.max,
        standardHeaders: true,
        legacyHeaders: false,
        keyGenerator: (req) => `${options.keyPrefix ?? "rl"}:${req.ip}`,
        message: {
            error: "Too Many Requests",
            code: "RATE_LIMIT_EXCEEDED",
            message: `Please try again later.`
        }
    });
}
