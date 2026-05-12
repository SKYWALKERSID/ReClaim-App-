import test from "node:test";
import assert from "node:assert/strict";
import { commitmentSchema, eventsPayloadSchema } from "../src/presentation/schemas/schemas.js";

test("validation schemas catch invalid UUIDs", () => {
  const invalid = {
    userId: "not-a-uuid",
    dailyLimitMinutes: 60,
    focusWindows: [],
    whitelist: [],
    blacklist: [],
    allowWhatsApp: true,
    maxOverridesPerDay: 2,
    rewardSystemEnabled: true
  };

  const result = commitmentSchema.safeParse(invalid);
  assert.equal(result.success, false);
});

test("validation schemas allow valid commitment", () => {
  const valid = {
    userId: "550e8400-e29b-41d4-a716-446655440000",
    dailyLimitMinutes: 60,
    focusWindows: [{ start: "10:00", end: "12:00", daysOfWeek: [1] }],
    whitelist: ["com.app"],
    blacklist: [],
    allowWhatsApp: true,
    maxOverridesPerDay: 2,
    rewardSystemEnabled: true
  };

  const result = commitmentSchema.safeParse(valid);
  assert.equal(result.success, true);
});

test("validation schemas enforce event payload limits", () => {
  const emptyPayload = { events: [] };
  const result = eventsPayloadSchema.safeParse(emptyPayload);
  assert.equal(result.success, false);
});
