export interface UsageEvent {
  userId: string;
  packageName: string;
  startedAt: string;
  endedAt: string;
  durationSeconds: number;
  eventType: "usage" | "blocked_attempt" | "override";
  metadata?: Record<string, any>;
}

export interface Commitment {
  userId: string;
  dailyLimitMinutes: number;
  focusWindows: Array<{
    start: string;
    end: string;
    daysOfWeek: number[];
  }>;
  whitelist: string[];
  blacklist: string[];
  allowWhatsApp: boolean;
  maxOverridesPerDay: number;
  rewardSystemEnabled: boolean;
}

export interface DailyMetrics {
  userId: string;
  dateKey: string;
  totalScreenMinutes: number;
  blockedAttempts: number;
  overridesUsed: number;
  distractionMinutes: number;
  focusMinutes: number;
  lateNightMinutes: number;
  appSwitches: number;
}

export interface RewardResult {
  pointsEarned: number;
  streakDays: number;
  level: string;
  badges: string[];
  summary?: string;
}

export interface PolicyEvaluation {
  status: "normal" | "focus_only" | "locked";
  reason: string;
  remainingDailyMinutes: number;
  overridesRemaining: number;
  blockedPackages: string[];
}

export interface AppBreakdown {
  appName: string;
  category: string;
  totalMinutes: number;
}

export interface CategoryBreakdown {
  category: string;
  totalMinutes: number;
}

export interface WeeklyTrendPoint {
  dateKey: string;
  totalScreenMinutes: number;
  distractionMinutes: number;
  rewardPoints: number;
}

export interface WeeklyReport {
  userId: string;
  dateFrom: string;
  dateTo: string;
  trends: WeeklyTrendPoint[];
  appBreakdown: AppBreakdown[];
  categoryBreakdown: CategoryBreakdown[];
  insights: any;
  recommendations: string[];
}

export interface UserPreferences {
  theme?: string;
  notificationsEnabled?: boolean;
}
