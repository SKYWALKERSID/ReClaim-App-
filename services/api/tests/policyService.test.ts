import test from "node:test";
import assert from "node:assert/strict";
import { evaluatePolicy } from "../src/application/policyService.js";

const mockCommitment = {
  userId: "u1",
  dailyLimitMinutes: 120,
  focusWindows: [
    { start: "09:00", end: "17:00", daysOfWeek: [1, 2, 3, 4, 5] }
  ],
  whitelistPackages: ["com.android.settings"],
  blacklistPackages: ["com.instagram.android"],
  allowWhatsApp: true,
  maxOverridesPerDay: 2,
  rewardSystemEnabled: true
};

const mockMetrics = {
  userId: "u1",
  dateKey: "2026-05-03",
  totalScreenMinutes: 30,
  blockedAttempts: 0,
  overridesUsed: 0,
  distractionMinutes: 10,
  focusMinutes: 0,
  lateNightMinutes: 0,
  appSwitches: 5
};

test("policy service returns normal state outside windows", () => {
  const result = evaluatePolicy({
    commitment: mockCommitment,
    metrics: mockMetrics,
    now: new Date("2026-05-03T20:00:00Z"), // Sunday evening
    overridesUsedToday: 0
  }, "UTC");

  assert.equal(result.status, "normal");
});

test("policy service returns focus_only state during focus window", () => {
  const result = evaluatePolicy({
    commitment: mockCommitment,
    metrics: mockMetrics,
    now: new Date("2026-05-04T10:00:00Z"), // Monday morning
    overridesUsedToday: 0
  }, "UTC");

  assert.equal(result.status, "focus_only");
});

test("policy service returns locked state when over limit", () => {
  const overLimitMetrics = { ...mockMetrics, totalScreenMinutes: 130 };
  const result = evaluatePolicy({
    commitment: mockCommitment,
    metrics: overLimitMetrics,
    now: new Date("2026-05-03T20:00:00Z"),
    overridesUsedToday: 0
  }, "UTC");

  assert.equal(result.status, "locked");
});
