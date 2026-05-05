import test from "node:test";
import assert from "node:assert/strict";
import { computeDailyReward } from "../src/domain/services/rewardEngine.js";

test("reward points increase for disciplined behavior", () => {
  const result = computeDailyReward({
    withinLimit: true,
    completedFocusSessions: 2,
    overridesUsed: 0,
    lateNightMinutes: 5,
    previousStreakDays: 2
  });

  assert.equal(result.pointsEarned, 105);
  assert.equal(result.streakDays, 3);
  assert.equal(result.level, "Beginner");
  assert.ok(result.badges.includes("Distraction Free Day"));
});

test("streak resets when over limit", () => {
  const result = computeDailyReward({
    withinLimit: false,
    completedFocusSessions: 1,
    overridesUsed: 1,
    lateNightMinutes: 60,
    previousStreakDays: 5
  });

  assert.equal(result.streakDays, 0);
  assert.equal(result.pointsEarned, 10);
});
