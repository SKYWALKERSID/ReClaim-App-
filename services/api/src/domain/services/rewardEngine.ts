import { RewardResult } from "../types/index.js";

function resolveLevel(streakDays: number): string {
  if (streakDays >= 21) {
    return "Focus Pro";
  }
  if (streakDays >= 7) {
    return "Disciplined";
  }
  return "Beginner";
}

export function computeDailyReward(input: {
  withinLimit: boolean;
  completedFocusSessions: number;
  overridesUsed: number;
  lateNightMinutes: number;
  previousStreakDays: number;
}): RewardResult {
  const badges: string[] = [];
  let points = 0;

  if (input.withinLimit) {
    points += 50;
    badges.push("Distraction Free Day");
  }

  points += Math.min(input.completedFocusSessions, 3) * 10;

  if (input.overridesUsed === 0) {
    points += 20;
    badges.push("No Escape Token");
  }

  if (input.lateNightMinutes <= 15) {
    points += 15;
    badges.push("Night Guard");
  }

  const streakDays = input.withinLimit ? input.previousStreakDays + 1 : 0;

  if (streakDays >= 3) {
    badges.push(`${streakDays}-Day Discipline Streak`);
  }

  const level = resolveLevel(streakDays);

  return {
    pointsEarned: points,
    streakDays,
    badges,
    level,
    summary: input.withinLimit
      ? "Disciplined day completed."
      : "Limit missed today. Streak reset for a clean restart tomorrow."
  };
}
