export type FocusWindow = {
  start: string; // HH:mm
  end: string; // HH:mm
  daysOfWeek: number[]; // 1=Mon ... 7=Sun
};

export type Commitment = {
  userId?: string;
  dailyLimitMinutes: number;
  focusWindows: FocusWindow[];
  whitelist: string[];
  blacklist: string[];
  allowWhatsApp: boolean;
  maxOverridesPerDay: number;
  rewardSystemEnabled: boolean;
};

export type UserPreferences = {
  preferredFocusStart?: string;
  preferredFocusEnd?: string;
  strictModeEnabled?: boolean;
  notificationsEnabled?: boolean;
};

export type UsageEvent = {
  userId: string;
  packageName: string;
  startedAt: string;
  endedAt: string;
  durationSeconds: number;
  eventType: "usage" | "blocked_attempt" | "override";
  metadata?: Record<string, unknown>;
};

export type UsageLog = {
  userId: string;
  appName: string;
  category: string;
  startTime: string;
  endTime: string;
  durationSeconds: number;
};

export type DailyMetrics = {
  userId: string;
  dateKey: string;
  totalScreenMinutes: number;
  blockedAttempts: number;
  overridesUsed: number;
  distractionMinutes: number;
  focusMinutes: number;
  lateNightMinutes: number;
  appSwitches: number;
};

export type AppBreakdown = {
  appName: string;
  category: string;
  totalMinutes: number;
};

export type CategoryBreakdown = {
  category: string;
  totalMinutes: number;
};

export type PatternInsights = {
  distractionRiskScore: number;
  appSwitchesPerHour: number;
  lateNightMinutes: number;
  peakUsageHour: number;
  longestContinuousSessionMinutes: number;
  excessiveUsageFlags: string[];
  recommendations: string[];
  prediction?: {
    tomorrowRisk: "low" | "medium" | "high";
    reason: string;
  };
};

export type RewardResult = {
  pointsEarned: number;
  streakDays: number;
  badges: string[];
  level: "Beginner" | "Disciplined" | "Focus Pro";
  summary: string;
};

export type PolicyEvaluation = {
  status: "normal" | "focus_only" | "locked";
  reason: string;
  remainingDailyMinutes: number;
  overridesRemaining: number;
  blockedPackages: string[];
};

export type WeeklyTrendPoint = {
  dateKey: string;
  totalScreenMinutes: number;
  distractionMinutes: number;
  rewardPoints: number;
};

export type WeeklyReport = {
  userId: string;
  dateFrom: string;
  dateTo: string;
  trends: WeeklyTrendPoint[];
  appBreakdown: AppBreakdown[];
  categoryBreakdown: CategoryBreakdown[];
  insights: PatternInsights;
  recommendations: string[];
};
