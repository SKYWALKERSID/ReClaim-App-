import { buildPatternInsights } from "../domain/services/patternEngine.js";
import { computeDailyReward } from "../domain/services/rewardEngine.js";
function isoDateOnly(date) {
    return date.toISOString().slice(0, 10);
}
function csvEscape(field) {
    if (field === null || field === undefined)
        return '""';
    const s = String(field).replace(/"/g, '""');
    const unsafe = /^[=+\-@\t\r]/;
    // Prefix unsafe leading characters with a single quote to prevent formula injection
    return unsafe.test(s) ? `"'${s}"` : `"${s}"`;
}
export class AnalyticsService {
    repository;
    notificationService;
    constructor(repository, notificationService) {
        this.repository = repository;
        this.notificationService = notificationService;
    }
    async upsertCommitment(commitment) {
        await this.repository.upsertUser(commitment.userId);
        await this.repository.upsertCommitment(commitment);
    }
    async getCommitment(userId) {
        return this.repository.getCommitment(userId);
    }
    async registerDevice(userId, deviceId, model, osVersion, fcmToken) {
        await this.repository.registerDevice(userId, deviceId, model, osVersion, fcmToken);
    }
    async getDevices(userId) {
        return this.repository.getDevices(userId);
    }
    async unregisterDevice(userId, deviceId) {
        await this.repository.unregisterDevice(userId, deviceId);
    }
    async ingestEvents(events) {
        if (events.length === 0) {
            return 0;
        }
        const userIds = [...new Set(events.map((e) => e.userId))];
        await Promise.all(userIds.map((id) => this.repository.upsertUser(id)));
        return this.repository.insertUsageEvents(events);
    }
    async computeDailyAnalytics(userId, dateKey, timeZone) {
        const commitment = await this.repository.getCommitment(userId);
        if (!commitment) {
            const err = new Error("Commitment not found. Create a commitment first.");
            err.statusCode = 404;
            err.code = "COMMITMENT_NOT_FOUND";
            throw err;
        }
        const events = await this.repository.getUsageEventsForDate(userId, dateKey);
        const usageEvents = events.filter((event) => event.eventType === "usage");
        const snapshotTotals = usageEvents
            .map((event) => event.metadata?.snapshotTotalMinutes)
            .filter((value) => typeof value === "number");
        const totalScreenMinutes = snapshotTotals.length > 0
            ? Math.max(...snapshotTotals)
            : usageEvents.reduce((sum, event) => sum + Math.round(event.durationSeconds / 60), 0);
        const blockedAttempts = events.filter((event) => event.eventType === "blocked_attempt").length;
        const overridesUsed = events.filter((event) => event.eventType === "override").length;
        const distractionMinutes = usageEvents
            .filter((event) => commitment.blacklist.includes(event.packageName))
            .reduce((sum, event) => sum + Math.round(event.durationSeconds / 60), 0);
        const insights = buildPatternInsights({
            events,
            distractionPackages: new Set(commitment.blacklist),
            timeZone
        });
        const previousStreak = await this.repository.getPreviousStreakDays(userId, dateKey);
        const reward = computeDailyReward({
            withinLimit: totalScreenMinutes <= commitment.dailyLimitMinutes,
            completedFocusSessions: Math.floor(events.filter((e) => e.metadata?.focusSessionCompleted === true).length),
            overridesUsed,
            lateNightMinutes: insights.lateNightMinutes,
            previousStreakDays: previousStreak
        });
        const metrics = {
            userId,
            dateKey,
            totalScreenMinutes,
            blockedAttempts,
            overridesUsed,
            distractionMinutes,
            focusMinutes: usageEvents
                .filter((event) => {
                if (typeof event.metadata?.snapshotTotalMinutes === "number") {
                    return false;
                }
                return event.metadata?.focus === true;
            })
                .reduce((sum, event) => sum + Math.round(event.durationSeconds / 60), 0),
            lateNightMinutes: insights.lateNightMinutes,
            appSwitches: Math.round(insights.appSwitchesPerHour * 24)
        };
        const appBreakdown = await this.repository.getAppBreakdown(userId, dateKey, dateKey);
        const categoryBreakdown = await this.repository.getCategoryBreakdown(userId, dateKey, dateKey);
        // Persist computed analytics (all three upserts)
        await this.repository.upsertDailyAnalytics(metrics, insights, reward);
        await this.repository.upsertDailySummary(userId, dateKey, totalScreenMinutes, categoryBreakdown, appBreakdown);
        await this.repository.upsertInsightSnapshot(userId, dateKey, insights.peakUsageHour, insights.excessiveUsageFlags, insights.recommendations);
        return {
            metrics,
            insights,
            reward,
            appBreakdown,
            categoryBreakdown
        };
    }
    async computeWeeklyReport(userId, dateTo, timeZone) {
        const end = new Date(`${dateTo}T00:00:00.000Z`);
        const start = new Date(end);
        start.setUTCDate(start.getUTCDate() - 6);
        const dateFrom = isoDateOnly(start);
        const events = await this.repository.getUsageEventsForRange(userId, dateFrom, dateTo);
        const appBreakdown = await this.repository.getAppBreakdown(userId, dateFrom, dateTo);
        const categoryBreakdown = await this.repository.getCategoryBreakdown(userId, dateFrom, dateTo);
        const trends = await this.repository.getWeeklyTrends(userId, dateFrom, dateTo);
        const commitment = await this.repository.getCommitment(userId);
        const distractionPackages = new Set(commitment?.blacklist ?? []);
        const insights = buildPatternInsights({
            events,
            distractionPackages,
            timeZone
        });
        const priorWeekEnd = new Date(start);
        priorWeekEnd.setUTCDate(priorWeekEnd.getUTCDate() - 1);
        const priorWeekStart = new Date(priorWeekEnd);
        priorWeekStart.setUTCDate(priorWeekStart.getUTCDate() - 6);
        const previousTrends = await this.repository.getWeeklyTrends(userId, isoDateOnly(priorWeekStart), isoDateOnly(priorWeekEnd));
        const currentTotal = trends.reduce((sum, point) => sum + point.totalScreenMinutes, 0);
        const previousTotal = previousTrends.reduce((sum, point) => sum + point.totalScreenMinutes, 0);
        const socialMinutes = categoryBreakdown
            .filter((item) => item.category === "social")
            .reduce((sum, item) => sum + item.totalMinutes, 0);
        const previousSocialBreakdown = await this.repository.getCategoryBreakdown(userId, isoDateOnly(priorWeekStart), isoDateOnly(priorWeekEnd));
        const previousSocialMinutes = previousSocialBreakdown
            .filter((item) => item.category === "social")
            .reduce((sum, item) => sum + item.totalMinutes, 0);
        const recommendations = [...insights.recommendations];
        if (socialMinutes > 0 && previousSocialMinutes > 0) {
            const increase = Math.round(((socialMinutes - previousSocialMinutes) / previousSocialMinutes) * 100);
            if (increase >= 10) {
                recommendations.unshift(`Social media usage increased by ${increase}% compared with last week.`);
            }
        }
        if (currentTotal > previousTotal && previousTotal > 0) {
            const increase = Math.round(((currentTotal - previousTotal) / previousTotal) * 100);
            if (increase >= 10) {
                recommendations.unshift(`Total screen time increased by ${increase}% compared with last week.`);
            }
        }
        const hourStr = String(insights.peakUsageHour).padStart(2, '0');
        recommendations.unshift(`You use your phone most around ${hourStr}:00.`);
        return {
            userId,
            dateFrom,
            dateTo,
            trends,
            appBreakdown,
            categoryBreakdown,
            insights,
            recommendations
        };
    }
    async getExportData(userId, dateFrom, dateTo) {
        return this.repository.getUsageEventsForRange(userId, dateFrom, dateTo);
    }
    convertToCsv(events) {
        const header = "userId,packageName,startedAt,endedAt,durationSeconds,eventType,category\n";
        const rows = events.map((e) => {
            const category = typeof e.metadata?.category === "string" ? e.metadata.category : "";
            return [
                csvEscape(e.userId),
                csvEscape(e.packageName),
                csvEscape(e.startedAt),
                csvEscape(e.endedAt),
                csvEscape(e.durationSeconds),
                csvEscape(e.eventType),
                csvEscape(category)
            ].join(",");
        });
        return header + rows.join("\n");
    }
    async sendTestNudge(userId) {
        await this.notificationService.sendNudge(userId, "Stay Focused!", "You are doing great! You have 45 minutes left in your daily limit.");
    }
}
