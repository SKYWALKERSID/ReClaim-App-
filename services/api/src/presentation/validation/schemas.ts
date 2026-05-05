import { z } from "zod";
import { env } from "../../config/env.js";

// ── Shared primitives ──

const uuidString = z.string().regex(
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
  "Must be a valid UUID"
);
const packageName = z.string().min(1).max(200);
const dateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD format");
const isoDateTime = z.string().datetime();
const timeZone = z.string().min(1).max(100).default("Asia/Kolkata");

// ── Focus window ──

const focusWindowSchema = z.object({
  start: z.string().regex(/^\d{2}:\d{2}$/, "Expected HH:mm"),
  end: z.string().regex(/^\d{2}:\d{2}$/, "Expected HH:mm"),
  daysOfWeek: z.array(z.number().int().min(1).max(7)).min(1).max(7),
});

// ── Commitment ──

export const commitmentSchema = z.object({
  userId: uuidString.optional(),
  dailyLimitMinutes: z.number().int().min(15).max(1440),
  focusWindows: z.array(focusWindowSchema).max(20).default([]),
  whitelist: z.array(packageName).max(100).default([]),
  blacklist: z.array(packageName).max(100).default([]),
  allowWhatsApp: z.boolean().default(true),
  maxOverridesPerDay: z.number().int().min(0).max(10).default(2),
  rewardSystemEnabled: z.boolean().default(true),
});

export type ValidatedCommitment = z.infer<typeof commitmentSchema>;

// ── Usage event ──

const usageEventSchema = z.object({
  userId: uuidString.optional(),
  packageName: packageName,
  startedAt: isoDateTime,
  endedAt: isoDateTime,
  durationSeconds: z.number().int().min(0).max(86_400),
  eventType: z.enum(["usage", "blocked_attempt", "override"]),
  metadata: z.record(z.string(), z.unknown()).optional().default({}),
  clientEventId: z.string().max(200).optional(),
}).refine((e) => new Date(e.endedAt) >= new Date(e.startedAt), {
  message: "endedAt must be greater than or equal to startedAt"
});

export const eventsPayloadSchema = z.object({
  events: z.array(usageEventSchema).min(1).max(env.maxEventsPerBatch),
});

export type ValidatedEvent = z.infer<typeof usageEventSchema>;

// ── Query params ──

export const dailyQuerySchema = z.object({
  date: dateString.optional(),
  timeZone: timeZone,
});

export const weeklyQuerySchema = z.object({
  dateTo: dateString.optional(),
  timeZone: timeZone,
});

export const rewardQuerySchema = z.object({
  date: dateString.optional(),
});

export const userIdParamSchema = z.object({
  userId: uuidString,
});

export const deviceRegistrationSchema = z.object({
  userId: uuidString.optional(),
  deviceId: z.string().min(1).max(200),
  model: z.string().max(200).optional(),
  osVersion: z.string().max(50).optional(),
  fcmToken: z.string().max(500).optional(),
});
