import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerUi from "swagger-ui-express";
import { env } from "./config/env.js";
import { AnalyticsService } from "./services/analytics.service.js";
import { AnalyticsRepository } from "./db/repositories/analytics.repository.js";
import { NotificationService } from "./services/notification.service.js";
import { PurgingService } from "./jobs/purging.job.js";
import { errorHandler } from "./presentation/middleware/errorHandler.js";
import { buildAnalyticsRoutes } from "./presentation/routes/analyticsRoutes.js";
import { buildCommitmentRoutes } from "./presentation/routes/commitmentRoutes.js";
import { healthRoutes } from "./presentation/routes/healthRoutes.js";
import { buildPolicyRoutes } from "./presentation/routes/policyRoutes.js";
import { buildSocialRoutes } from "./presentation/routes/socialRoutes.js";
import { buildAdminRoutes } from "./presentation/routes/adminRoutes.js";
import { buildAuthRoutes } from "./presentation/routes/authRoutes.js";
import { SocialRepository } from "./db/repositories/social.repository.js";
import { authMiddleware } from "./presentation/middleware/auth.js";
import { rateLimiter } from "./presentation/middleware/rateLimiter.js";
import { requestIdMiddleware } from "./presentation/middleware/requestId.js";
import { logger } from "./utils/logger.js";
import intentRoutes from "./presentation/routes/intent.routes.js";
import driftRoutes from "./presentation/routes/drift.routes.js";
import frictionRoutes from "./presentation/routes/friction.routes.js";
import reflectionRoutes from "./presentation/routes/reflection.routes.js";
import cravingRoutes from "./presentation/routes/craving.routes.js";

export function buildApp() {
  const repository = new AnalyticsRepository();
  const socialRepository = new SocialRepository();
  const notificationService = new NotificationService(repository);
  const analyticsService = new AnalyticsService(repository, notificationService);
  
  // Data Retention
  const purgingService = new PurgingService(repository, env.eventRetentionDays);
  if (process.env.NODE_ENV !== "test") {
    purgingService.start();
  }

  const app = express();
  app.set("trust proxy", 1); // Trust first proxy for rate limiting
  app.set("etag", "strong");

  app.use(requestIdMiddleware);

  // Security headers
  app.use(helmet());

  // CORS — restrict in production
  if (env.corsOrigins === "*" && env.nodeEnv === "production") {
    throw new Error("CORS_ORIGINS cannot be '*' in production");
  }
  const corsOptions: cors.CorsOptions =
    env.corsOrigins === "*"
      ? {}
      : { origin: env.corsOrigins.split(",").map((o) => o.trim()) };
  app.use(cors(corsOptions));
  
  // General rate limit (100 per minute)
  app.use(rateLimiter({ windowMs: 60 * 1000, max: 100, keyPrefix: "general" }));

  // Body parsing with size limit
  app.use(express.json({ limit: "1mb" }));

  // Request logging
  app.use(morgan(env.nodeEnv === "development" ? "dev" : "combined"));
  
  // Swagger Documentation
  const swaggerOptions = {
    definition: {
      openapi: "3.0.0",
      info: {
        title: "ReClaim API",
        version: "1.0.0",
        description: "Production-hardened API for monitoring and enforcing ReClaim.",
      },
      servers: [{ url: process.env.PUBLIC_API_URL ?? `http://localhost:${env.port}/v1` }],
      components: {
        securitySchemes: {
          ApiKeyAuth: {
            type: "apiKey",
            in: "header",
            name: "x-api-key",
          },
          BearerAuth: {
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
          },
        },
      },
      security: [{ ApiKeyAuth: [] }, { BearerAuth: [] }],
    },
    apis: ["./src/presentation/routes/*.ts"],
  };
  const specs = swaggerJsdoc(swaggerOptions);
  
  // Authentication (all v1 routes except health are protected by authMiddleware internally)
  app.use("/v1", authMiddleware);

  if (env.nodeEnv !== "production") {
    app.use("/v1/docs", swaggerUi.serve, swaggerUi.setup(specs));
  }

  // Routes
  app.use("/v1", healthRoutes);
  app.use("/v1", buildAuthRoutes());
  app.use("/v1", buildCommitmentRoutes(analyticsService));
  app.use("/v1", buildAnalyticsRoutes(analyticsService));
  app.use("/v1", buildPolicyRoutes(repository));
  app.use("/v1/social", buildSocialRoutes(socialRepository));
  app.use("/v1/admin", buildAdminRoutes());
  app.use("/v1/intents", intentRoutes);
  app.use("/v1/analytics/drift", driftRoutes);
  app.use("/v1/analytics/friction", frictionRoutes);
  app.use("/v1/analytics/reflection", reflectionRoutes);
  app.use("/v1/analytics/craving", cravingRoutes);

  // Global error handler (must be last)
  app.use(errorHandler);

  return app;
}

