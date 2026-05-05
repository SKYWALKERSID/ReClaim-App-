import { PatternInsights, UsageEvent } from "../types/index.js";

type BuildInsightsInput = {
  events: UsageEvent[];
  distractionPackages: Set<string>;
  timeZone: string;
};

function getLocalHour(dateIso: string, timeZone: string): number {
  const date = new Date(dateIso);
  const formatted = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "2-digit",
    hour12: false
  }).format(date);
  return Number(formatted);
}

export function buildPatternInsights(input: BuildInsightsInput): PatternInsights {
  const usageEvents = input.events
    .filter((event) => {
      if (event.eventType !== "usage") {
        return false;
      }
      return typeof event.metadata?.snapshotTotalMinutes !== "number";
    })
    .sort((a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt));

  const totalHoursTracked = Math.max(
    1,
    (Date.parse(usageEvents.at(-1)?.endedAt ?? new Date().toISOString()) -
      Date.parse(usageEvents.at(0)?.startedAt ?? new Date().toISOString())) /
      (1000 * 60 * 60)
  );

  let appSwitches = 0;
  let lateNightMinutes = 0;
  let distractionMinutes = 0;
  let longestContinuousSessionMinutes = 0;
  const hourlyUsage = new Array<number>(24).fill(0);

  for (let i = 0; i < usageEvents.length; i += 1) {
    const event = usageEvents[i];
    const hour = getLocalHour(event.startedAt, input.timeZone);
    const durationMinutes = Math.round(event.durationSeconds / 60);

    hourlyUsage[hour] += durationMinutes;
    longestContinuousSessionMinutes = Math.max(longestContinuousSessionMinutes, durationMinutes);

    if (hour >= 23 || hour < 5) {
      lateNightMinutes += durationMinutes;
    }

    if (input.distractionPackages.has(event.packageName)) {
      distractionMinutes += durationMinutes;
    }

    if (i > 0) {
      const previous = usageEvents[i - 1];
      if (previous.packageName !== event.packageName) {
        const gapSeconds =
          (Date.parse(event.startedAt) - Date.parse(previous.endedAt)) / 1000;
        if (gapSeconds <= 45) {
          appSwitches += 1;
        }
      }
    }
  }

  const appSwitchesPerHour = Number((appSwitches / totalHoursTracked).toFixed(2));
  const peakUsageHour = hourlyUsage.reduce((bestHour, value, index, array) => {
    return value > array[bestHour] ? index : bestHour;
  }, 0);
  const excessiveUsageFlags: string[] = [];

  if (longestContinuousSessionMinutes >= 60) {
    excessiveUsageFlags.push("long_continuous_session");
  } else if (longestContinuousSessionMinutes >= 30) {
    excessiveUsageFlags.push("extended_session");
  }

  if (appSwitchesPerHour > 18) {
    excessiveUsageFlags.push("frequent_app_switching");
  }

  if (lateNightMinutes > 30) {
    excessiveUsageFlags.push("late_night_usage");
  }

  const riskScore = Math.min(
    100,
    Math.round(
      distractionMinutes * 0.8 +
        lateNightMinutes * 0.9 +
        appSwitchesPerHour * 10 +
        longestContinuousSessionMinutes * 0.35
    )
  );

  const recommendations: string[] = [];
  if (longestContinuousSessionMinutes >= 45) {
    recommendations.push("Break long sessions with a 10-minute nudge at the 30-minute mark.");
  }
  if (lateNightMinutes > 30) {
    recommendations.push("Enable strict late-night lock from 11 PM to 6 AM.");
  }
  if (appSwitchesPerHour > 18) {
    recommendations.push("Add 15-minute focus windows to reduce rapid app hopping.");
  }
  if (distractionMinutes > 60) {
    recommendations.push("Move one high-distraction app into full-day blocked mode.");
  }
  if (recommendations.length === 0) {
    recommendations.push("Current pattern is stable. Keep limits unchanged for consistency.");
  }

  return {
    distractionRiskScore: riskScore,
    appSwitchesPerHour,
    lateNightMinutes,
    peakUsageHour,
    longestContinuousSessionMinutes,
    excessiveUsageFlags,
    recommendations,
    prediction: {
      tomorrowRisk: riskScore > 75 || lateNightMinutes > 45 ? "high" : riskScore > 40 ? "medium" : "low" as const,
      reason:
        riskScore > 75
          ? "High risk due to intensive distraction patterns today. Expect willpower fatigue tomorrow."
          : lateNightMinutes > 45
          ? "Late-night usage detected. Tomorrow's focus will likely be compromised by sleep debt."
          : riskScore > 40
          ? "Moderate usage levels. Stay consistent to maintain current discipline."
          : "Excellent control today. Tomorrow's focus window looks clear."
    }
  };
}
