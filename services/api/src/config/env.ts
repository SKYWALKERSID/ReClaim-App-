import dotenv from "dotenv";

dotenv.config();

function readRequired(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const parsedPort = Number(process.env.PORT ?? 4000);
if (!Number.isInteger(parsedPort)) {
  throw new Error("PORT must be a valid integer");
}

const nodeEnv = process.env.NODE_ENV ?? "development";
const apiKeysStr = process.env.API_KEYS || process.env.X_API_KEY || "";
const parsedApiKeys = apiKeysStr.split(",").map((k) => k.trim()).filter(Boolean);

if (nodeEnv === "production" && parsedApiKeys.length === 0) {
  throw new Error("API_KEYS or X_API_KEY must not be empty in production");
}

function readJwtSecret(): string {
  const v = process.env.JWT_SECRET?.trim();
  if (v) {
    return v;
  }
  const inferTestRunner =
    nodeEnv === "test" ||
    process.env.npm_lifecycle_event === "test" ||
    process.argv.includes("--test");
  if (inferTestRunner) {
    return "test-only-jwt-secret-min-32-characters-long!!";
  }
  throw new Error("JWT_SECRET environment variable is required (use a long random string, e.g. openssl rand -hex 32)");
}

export const env = {
  nodeEnv,
  port: parsedPort,
  jwtSecret: readJwtSecret(),
  jwtPrivateKey: (process.env.JWT_PRIVATE_KEY || "").replace(/\\n/g, "\n"),
  jwtPublicKey: (process.env.JWT_PUBLIC_KEY || "").replace(/\\n/g, "\n"),
  jwtAccessExpiry: process.env.JWT_ACCESS_EXPIRY ?? "15m",
  jwtRefreshExpiry: process.env.JWT_REFRESH_EXPIRY ?? "7d",
  databaseUrl: readRequired("DATABASE_URL"),
  defaultTimeZone: process.env.DEFAULT_TIMEZONE ?? "Asia/Kolkata",
  eventRetentionDays: Number(process.env.EVENT_RETENTION_DAYS ?? 90),
  maxEventsPerBatch: Number(process.env.MAX_EVENTS_PER_BATCH ?? 500),
  corsOrigins: process.env.CORS_ORIGINS ?? "*",
  apiKeys: parsedApiKeys,
  geminiApiKey: process.env.GEMINI_API_KEY ?? "",
} as const;
