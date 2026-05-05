import jwt from "jsonwebtoken";
import { env } from "../../config/env.js";
import { API_KEY_SERVICE_USER } from "../../config/authConstants.js";
/** Paths under `app.use("/v1", authMiddleware)` use `req.path` without the `/v1` prefix. */
const publicPaths = new Set(["/health", "/auth/anonymous"]);
export function authMiddleware(req, res, next) {
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
        const decoded = jwt.verify(token, env.jwtSecret);
        req.user = decoded;
        next();
    }
    catch (error) {
        res.status(401).json({
            error: "Invalid Token",
            code: "UNAUTHORIZED",
            message: "The provided token is invalid or expired."
        });
    }
}
