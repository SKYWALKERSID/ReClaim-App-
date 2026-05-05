import test from "node:test";
import assert from "node:assert/strict";
import { buildPatternInsights } from "../src/domain/services/patternEngine.js";

test("pattern engine calculates risk score correctly", () => {
  const events = [
    {
      userId: "u1",
      packageName: "com.instagram.android",
      startedAt: "2026-05-03T23:30:00Z",
      endedAt: "2026-05-03T23:45:00Z",
      durationSeconds: 900,
      eventType: "usage" as const
    },
    {
      userId: "u1",
      packageName: "com.whatsapp",
      startedAt: "2026-05-04T00:10:00Z",
      endedAt: "2026-05-04T00:20:00Z",
      durationSeconds: 600,
      eventType: "usage" as const
    }
  ];

  const result = buildPatternInsights({
    events,
    distractionPackages: new Set(["com.instagram.android"]),
    timeZone: "UTC"
  });

  assert.ok(result.distractionRiskScore > 0);
  assert.ok(result.lateNightMinutes > 0);
  assert.equal(result.peakUsageHour, 23);
  assert.ok(result.excessiveUsageFlags.includes("late_night_usage"));
});

test("pattern engine detects frequent app switching", () => {
  const events = [];
  const baseTime = Date.parse("2026-05-03T10:00:00Z");
  
  for (let i = 0; i < 20; i++) {
    const start = new Date(baseTime + (i * 60 * 1000));
    const end = new Date(baseTime + (i * 60 * 1000) + 30000);
    events.push({
      userId: "u1",
      packageName: i % 2 === 0 ? "app.a" : "app.b",
      startedAt: start.toISOString(),
      endedAt: end.toISOString(),
      durationSeconds: 30,
      eventType: "usage" as const
    });
  }

  const result = buildPatternInsights({
    events,
    distractionPackages: new Set(),
    timeZone: "UTC"
  });

  assert.ok(result.appSwitchesPerHour > 18);
  assert.ok(result.excessiveUsageFlags.includes("frequent_app_switching"));
});
