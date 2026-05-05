import winston from "winston";
import { env } from "../config/env.js";
const { combine, timestamp, json, colorize, printf, errors } = winston.format;
const logFormat = printf(({ level, message, timestamp, stack, requestId, userId, ...meta }) => {
    return `${timestamp} [${level}]${requestId ? ` [${requestId}]` : ""}${userId ? ` [${userId}]` : ""}: ${stack || message} ${Object.keys(meta).length ? JSON.stringify(meta) : ""}`;
});
export const logger = winston.createLogger({
    level: env.nodeEnv === "production" ? "info" : "debug",
    format: combine(errors({ stack: true }), timestamp(), env.nodeEnv === "production" ? json() : combine(colorize(), logFormat)),
    transports: [
        new winston.transports.Console(),
    ],
    defaultMeta: { service: "focus-minimalism-api" },
});
