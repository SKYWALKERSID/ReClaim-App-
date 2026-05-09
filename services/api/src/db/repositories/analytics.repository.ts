import QueryStream from "pg-query-stream";
import { pool } from "../pool.js";
import {
  AppBreakdown,
  CategoryBreakdown,
  Commitment,
  DailyMetrics,
  RewardResult,
  UsageEvent,
  UserPreferences,
  WeeklyTrendPoint
} from "../../domain/types/index.js";

// ── Unified category classification ──
// Single source of truth used by both ingestion and queries.

const CATEGORY_RULES: Array<{ patterns: string[]; category: string }> = [
  { patterns: ["instagram", "facebook", "twitter", "reddit", "snapchat", "tiktok", "linkedin", "pinterest", "tumblr"], category: "social" },
  { patterns: ["youtube", "netflix", "spotify", "primevideo", "hotstar", "twitch", "disney", "hulu", "hbomax", "gaana", "saavn"], category: "entertainment" },
  { patterns: ["whatsapp", "telegram", "message", "dialer", "sms", "signal", "discord", "skype", "zoom", "teams", "meet"], category: "communication" },
  { patterns: ["chrome", "docs", "gmail", "calendar", "sheets", "drive", "notion", "slack", "trello", "asana", "evernote", "obsidian", "keep"], category: "productivity" },
  { patterns: ["calculator", "clock", "settings", "camera", "gallery", "files", "browser", "contacts", "weather", "compass"], category: "utility" },
];

export function inferCategory(packageName: string): string {
  const normalized = packageName.toLowerCase();
  for (const rule of CATEGORY_RULES) {
    if (rule.patterns.some((pattern) => normalized.includes(pattern))) {
      return rule.category;
    }
  }
  return "other";
}

function usageCategory(event: UsageEvent): string {
  const category = event.metadata?.category;
  return typeof category === "string" && category.length > 0
    ? category
    : inferCategory(event.packageName);
}

// ── Repository ──

export class AnalyticsRepository {
  async upsertUser(userId: string, preferences?: UserPreferences): Promise<void> {
    await pool.query(
      `INSERT INTO users (id, preferences)
       VALUES ($1, $2::jsonb)
       ON CONFLICT (id)
       DO UPDATE SET preferences = COALESCE(users.preferences, '{}'::jsonb) || EXCLUDED.preferences`,
      [userId, JSON.stringify(preferences ?? {})]
    );
  }

  async registerDevice(userId: string, deviceId: string, model?: string, osVersion?: string, fcmToken?: string): Promise<void> {
    await pool.query(
      `INSERT INTO devices (user_id, device_id, model, os_version, fcm_token, last_sync_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (user_id, device_id)
       DO UPDATE SET
         model = COALESCE(EXCLUDED.model, devices.model),
         os_version = COALESCE(EXCLUDED.os_version, devices.os_version),
         fcm_token = COALESCE(EXCLUDED.fcm_token, devices.fcm_token),
         last_sync_at = NOW()`,
      [userId, deviceId, model, osVersion, fcmToken]
    );
  }

  async upsertCommitment(commitment: Commitment): Promise<void> {
    await pool.query(
      `INSERT INTO commitments (
        user_id,
        daily_limit_minutes,
        focus_windows,
        whitelist_packages,
        blacklist_packages,
        allow_whatsapp,
        max_overrides_per_day,
        reward_system_enabled,
        updated_at
      ) VALUES ($1, $2, $3::jsonb, $4, $5, $6, $7, $8, NOW())
      ON CONFLICT (user_id)
      DO UPDATE SET
        daily_limit_minutes = EXCLUDED.daily_limit_minutes,
        focus_windows = EXCLUDED.focus_windows,
        whitelist_packages = EXCLUDED.whitelist_packages,
        blacklist_packages = EXCLUDED.blacklist_packages,
        allow_whatsapp = EXCLUDED.allow_whatsapp,
        max_overrides_per_day = EXCLUDED.max_overrides_per_day,
        reward_system_enabled = EXCLUDED.reward_system_enabled,
        updated_at = NOW()`,
      [
        commitment.userId,
        commitment.dailyLimitMinutes,
        JSON.stringify(commitment.focusWindows),
        commitment.whitelist,
        commitment.blacklist,
        commitment.allowWhatsApp,
        commitment.maxOverridesPerDay,
        commitment.rewardSystemEnabled
      ]
    );
  }

  async getCommitment(userId: string): Promise<Commitment | null> {
    const result = await pool.query(
      `SELECT user_id,
              daily_limit_minutes,
              focus_windows,
              whitelist_packages,
              blacklist_packages,
              allow_whatsapp,
              max_overrides_per_day,
              reward_system_enabled
       FROM commitments
       WHERE user_id = $1`,
      [userId]
    );

    if (result.rowCount === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      userId: row.user_id,
      dailyLimitMinutes: row.daily_limit_minutes,
      focusWindows: row.focus_windows,
      whitelist: row.whitelist_packages,
      blacklist: row.blacklist_packages,
      allowWhatsApp: row.allow_whatsapp,
      maxOverridesPerDay: row.max_overrides_per_day,
      rewardSystemEnabled: row.reward_system_enabled
    };
  }

  // ── Batch event ingestion with dedup ──
  async insertUsageEvents(events: UsageEvent[]): Promise<number> {
    if (events.length === 0) return 0;

    const client = await pool.connect();
    let insertedCount = 0;

    try {
      await client.query("BEGIN");

      // Batch insert into usage_events (with ON CONFLICT skip for idempotency)
      const eventValues: unknown[] = [];
      const eventPlaceholders: string[] = [];
      let paramIndex = 1;

      for (const event of events) {
        const clientEventId = typeof event.metadata?.clientEventId === "string"
          ? event.metadata.clientEventId
          : null;

        eventPlaceholders.push(
          `($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, $${paramIndex + 5}, $${paramIndex + 6}::jsonb, $${paramIndex + 7})`
        );
        eventValues.push(
          event.userId,
          event.packageName,
          event.startedAt,
          event.endedAt,
          event.durationSeconds,
          event.eventType,
          JSON.stringify(event.metadata ?? {}),
          clientEventId
        );
        paramIndex += 8;
      }

      const eventResult = await client.query(
        `INSERT INTO usage_events (
          user_id, package_name, started_at, ended_at,
          duration_seconds, event_type, metadata, client_event_id
        ) VALUES ${eventPlaceholders.join(", ")}
        ON CONFLICT (user_id, client_event_id)
          WHERE client_event_id IS NOT NULL
        DO NOTHING`,
        eventValues
      );
      insertedCount = eventResult.rowCount ?? 0;

      // Batch insert usage_logs for actual usage events (skip snapshots)
      const usageLogs = events.filter((e) => {
        if (e.eventType !== "usage") return false;
        return typeof e.metadata?.snapshotTotalMinutes !== "number";
      });

      if (usageLogs.length > 0) {
        const logValues: unknown[] = [];
        const logPlaceholders: string[] = [];
        let logParam = 1;

        for (const event of usageLogs) {
          logPlaceholders.push(
            `($${logParam}, $${logParam + 1}, $${logParam + 2}, $${logParam + 3}, $${logParam + 4}, $${logParam + 5})`
          );
          logValues.push(
            event.userId,
            event.packageName,
            usageCategory(event),
            event.startedAt,
            event.endedAt,
            event.durationSeconds
          );
          logParam += 6;
        }

        await client.query(
          `INSERT INTO usage_logs (
            user_id, app_name, category, start_time, end_time, duration_seconds
          ) VALUES ${logPlaceholders.join(", ")}
          ON CONFLICT (user_id, app_name, start_time, end_time)
          DO NOTHING`,
          logValues
        );
      }

      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }

    return insertedCount;
  }

  async getUsageEventsForDate(userId: string, dateKey: string): Promise<UsageEvent[]> {
    const result = await pool.query(
      `SELECT user_id, package_name, started_at, ended_at, duration_seconds, event_type, metadata
       FROM usage_events
       WHERE user_id = $1
         AND started_at::date = $2::date
       ORDER BY started_at ASC`,
      [userId, dateKey]
    );

    return result.rows.map((row: any) => ({
      userId: row.user_id,
      packageName: row.package_name,
      startedAt: row.started_at.toISOString(),
      endedAt: row.ended_at.toISOString(),
      durationSeconds: row.duration_seconds,
      eventType: row.event_type,
      metadata: row.metadata
    }));
  }

  async getUsageEventsForRange(userId: string, dateFrom: string, dateTo: string): Promise<UsageEvent[]> {
    const result = await pool.query(
      `SELECT user_id, package_name, started_at, ended_at, duration_seconds, event_type, metadata
       FROM usage_events
       WHERE user_id = $1
         AND started_at::date BETWEEN $2::date AND $3::date
       ORDER BY started_at ASC`,
      [userId, dateFrom, dateTo]
    );

    return result.rows.map((row: any) => ({
      userId: row.user_id,
      packageName: row.package_name,
      startedAt: row.started_at.toISOString(),
      endedAt: row.ended_at.toISOString(),
      durationSeconds: row.duration_seconds,
      eventType: row.event_type,
      metadata: row.metadata
    }));
  }

  async getUsageEventsStream(userId: string, dateFrom: string, dateTo: string): Promise<{ stream: QueryStream; client: any }> {
    const client = await pool.connect();
    const query = new QueryStream(
      `SELECT user_id, package_name, started_at, ended_at, duration_seconds, event_type, metadata
       FROM usage_events
       WHERE user_id = $1
         AND started_at::date BETWEEN $2::date AND $3::date
       ORDER BY started_at ASC`,
      [userId, dateFrom, dateTo]
    );
    return { stream: client.query(query), client };
  }

  async getDailyMetrics(userId: string, dateKey: string): Promise<DailyMetrics | null> {
    const result = await pool.query(
      `SELECT user_id, date_key, total_screen_minutes, blocked_attempts, overrides_used,
              distraction_minutes, focus_minutes, late_night_minutes, app_switches
       FROM daily_analytics
       WHERE user_id = $1 AND date_key = $2::date`,
      [userId, dateKey]
    );

    if (result.rowCount === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      userId: row.user_id,
      dateKey: row.date_key.toISOString().slice(0, 10),
      totalScreenMinutes: row.total_screen_minutes,
      blockedAttempts: row.blocked_attempts,
      overridesUsed: row.overrides_used,
      distractionMinutes: row.distraction_minutes,
      focusMinutes: row.focus_minutes,
      lateNightMinutes: row.late_night_minutes,
      appSwitches: row.app_switches
    };
  }

  async getPreviousStreakDays(userId: string, dateKey: string): Promise<number> {
    const result = await pool.query(
      `SELECT streak_days
       FROM daily_analytics
       WHERE user_id = $1 AND date_key < $2::date
       ORDER BY date_key DESC
       LIMIT 1`,
      [userId, dateKey]
    );

    return result.rowCount === 0 ? 0 : result.rows[0].streak_days;
  }

  async upsertDailyAnalytics(
    metrics: DailyMetrics,
    insights: Record<string, unknown>,
    reward: RewardResult
  ): Promise<void> {
    await pool.query(
      `INSERT INTO daily_analytics (
        user_id, date_key, total_screen_minutes, blocked_attempts, overrides_used,
        distraction_minutes, focus_minutes, late_night_minutes, app_switches,
        reward_points, streak_days, badges, insights, updated_at
      ) VALUES (
        $1, $2::date, $3, $4, $5, $6, $7, $8, $9,
        $10, $11, $12, $13::jsonb, NOW()
      )
      ON CONFLICT (user_id, date_key)
      DO UPDATE SET
        total_screen_minutes = EXCLUDED.total_screen_minutes,
        blocked_attempts = EXCLUDED.blocked_attempts,
        overrides_used = EXCLUDED.overrides_used,
        distraction_minutes = EXCLUDED.distraction_minutes,
        focus_minutes = EXCLUDED.focus_minutes,
        late_night_minutes = EXCLUDED.late_night_minutes,
        app_switches = EXCLUDED.app_switches,
        reward_points = EXCLUDED.reward_points,
        streak_days = EXCLUDED.streak_days,
        badges = EXCLUDED.badges,
        insights = EXCLUDED.insights,
        updated_at = NOW()`,
      [
        metrics.userId,
        metrics.dateKey,
        metrics.totalScreenMinutes,
        metrics.blockedAttempts,
        metrics.overridesUsed,
        metrics.distractionMinutes,
        metrics.focusMinutes,
        metrics.lateNightMinutes,
        metrics.appSwitches,
        reward.pointsEarned,
        reward.streakDays,
        reward.badges,
        JSON.stringify(insights)
      ]
    );
  }

  async upsertDailySummary(
    userId: string,
    dateKey: string,
    totalScreenTimeMinutes: number,
    categoryBreakdown: CategoryBreakdown[],
    appBreakdown: AppBreakdown[]
  ): Promise<void> {
    await pool.query(
      `INSERT INTO daily_summaries (
        user_id, date_key, total_screen_time_minutes,
        category_breakdown, app_breakdown, updated_at
      ) VALUES ($1, $2::date, $3, $4::jsonb, $5::jsonb, NOW())
      ON CONFLICT (user_id, date_key)
      DO UPDATE SET
        total_screen_time_minutes = EXCLUDED.total_screen_time_minutes,
        category_breakdown = EXCLUDED.category_breakdown,
        app_breakdown = EXCLUDED.app_breakdown,
        updated_at = NOW()`,
      [
        userId,
        dateKey,
        totalScreenTimeMinutes,
        JSON.stringify(categoryBreakdown),
        JSON.stringify(appBreakdown)
      ]
    );
  }

  async upsertInsightSnapshot(
    userId: string,
    dateKey: string,
    peakUsageHour: number,
    excessiveUsageFlags: string[],
    recommendationSummary: string[]
  ): Promise<void> {
    await pool.query(
      `INSERT INTO insight_snapshots (
        user_id, date_key, peak_usage_hour,
        excessive_usage_flags, recommendation_summary, created_at
      ) VALUES ($1, $2::date, $3, $4, $5::jsonb, NOW())
      ON CONFLICT (user_id, date_key)
      DO UPDATE SET
        peak_usage_hour = EXCLUDED.peak_usage_hour,
        excessive_usage_flags = EXCLUDED.excessive_usage_flags,
        recommendation_summary = EXCLUDED.recommendation_summary,
        created_at = NOW()`,
      [userId, dateKey, peakUsageHour, excessiveUsageFlags, JSON.stringify(recommendationSummary)]
    );
  }

  async getWeeklyTrends(userId: string, dateFrom: string, dateTo: string): Promise<WeeklyTrendPoint[]> {
    const result = await pool.query(
      `SELECT date_key, total_screen_minutes, distraction_minutes, reward_points
       FROM daily_analytics
       WHERE user_id = $1
         AND date_key BETWEEN $2::date AND $3::date
       ORDER BY date_key ASC`,
      [userId, dateFrom, dateTo]
    );

    return result.rows.map((row: { date_key: Date; total_screen_minutes: number; distraction_minutes: number; reward_points: number }) => ({
      dateKey: row.date_key.toISOString().slice(0, 10),
      totalScreenMinutes: row.total_screen_minutes,
      distractionMinutes: row.distraction_minutes,
      rewardPoints: row.reward_points
    }));
  }

  async getAppBreakdown(userId: string, dateFrom: string, dateTo: string): Promise<AppBreakdown[]> {
    const result = await pool.query(
      `SELECT app_name, category, SUM(duration_seconds) AS duration_seconds
       FROM usage_logs
       WHERE user_id = $1
         AND start_time::date BETWEEN $2::date AND $3::date
       GROUP BY app_name, category
       ORDER BY SUM(duration_seconds) DESC
       LIMIT 8`,
      [userId, dateFrom, dateTo]
    );

    return result.rows.map((row: { app_name: string; category: string; duration_seconds: string | number }) => ({
      appName: row.app_name,
      category: row.category,
      totalMinutes: Math.round(Number(row.duration_seconds) / 60)
    }));
  }

  async getCategoryBreakdown(userId: string, dateFrom: string, dateTo: string): Promise<CategoryBreakdown[]> {
    const result = await pool.query(
      `SELECT category, SUM(duration_seconds) AS duration_seconds
       FROM usage_logs
       WHERE user_id = $1
         AND start_time::date BETWEEN $2::date AND $3::date
       GROUP BY category
       ORDER BY SUM(duration_seconds) DESC`,
      [userId, dateFrom, dateTo]
    );

    return result.rows.map((row: { category: string; duration_seconds: string | number }) => ({
      category: row.category,
      totalMinutes: Math.round(Number(row.duration_seconds) / 60)
    }));
  }

  async getRewardSummary(
    userId: string,
    dateKey: string
  ): Promise<{
    points: number;
    streakDays: number;
    badges: string[];
    insights: Record<string, unknown>;
  } | null> {
    const result = await pool.query(
      `SELECT reward_points, streak_days, badges, insights
       FROM daily_analytics
       WHERE user_id = $1 AND date_key = $2::date`,
      [userId, dateKey]
    );

    if (result.rowCount === 0) {
      return null;
    }

    return {
      points: result.rows[0].reward_points,
      streakDays: result.rows[0].streak_days,
      badges: result.rows[0].badges,
      insights: result.rows[0].insights
    };
  }

  async getDevices(userId: string): Promise<Array<{ deviceId: string; model?: string; osVersion?: string; fcmToken?: string; lastSyncAt: string }>> {
    const result = await pool.query(
      "SELECT device_id, model, os_version, fcm_token, last_sync_at FROM devices WHERE user_id = $1 ORDER BY last_sync_at DESC",
      [userId]
    );
    return result.rows.map((row: Record<string, unknown>) => ({
      deviceId: row.device_id as string,
      model: row.model as string | undefined,
      osVersion: row.os_version as string | undefined,
      fcmToken: row.fcm_token as string | undefined,
      lastSyncAt: (row.last_sync_at as Date).toISOString()
    }));
  }

  async unregisterDevice(userId: string, deviceId: string): Promise<void> {
    await pool.query(
      "DELETE FROM devices WHERE user_id = $1 AND device_id = $2",
      [userId, deviceId]
    );
  }

  // ── Maintenance ──

  async runRetentionCleanup(retentionDays: number = 90): Promise<number> {
    const result = await pool.query(
      "SELECT cleanup_old_events($1) AS deleted",
      [retentionDays]
    );
    return result.rows[0]?.deleted ?? 0;
  }
}
