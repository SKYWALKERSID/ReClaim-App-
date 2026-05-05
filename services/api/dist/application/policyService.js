function getLocalDayAndTime(now, timeZone) {
    const weekday = new Intl.DateTimeFormat("en-US", {
        timeZone,
        weekday: "short"
    }).format(now);
    const dayMap = {
        Mon: 1,
        Tue: 2,
        Wed: 3,
        Thu: 4,
        Fri: 5,
        Sat: 6,
        Sun: 7
    };
    const hhmm = new Intl.DateTimeFormat("en-GB", {
        timeZone,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
    }).format(now);
    let dayOfWeek = dayMap[weekday];
    if (dayOfWeek === undefined) {
        dayOfWeek = now.getDay() || 7; // ISO 1-7 fallback
    }
    return {
        dayOfWeek,
        hhmm
    };
}
function inWindow(now, start, end) {
    if (start <= end) {
        return now >= start && now <= end;
    }
    return now >= start || now <= end;
}
export function evaluatePolicy(input, timeZone) {
    const { dayOfWeek, hhmm } = getLocalDayAndTime(input.now, timeZone);
    const inFocusWindow = input.commitment.focusWindows.some((window) => {
        return window.daysOfWeek.includes(dayOfWeek) && inWindow(hhmm, window.start, window.end);
    });
    const remainingDailyMinutes = Math.max(0, input.commitment.dailyLimitMinutes - input.metrics.totalScreenMinutes);
    const overridesRemaining = Math.max(0, input.commitment.maxOverridesPerDay - input.overridesUsedToday);
    if (remainingDailyMinutes <= 0) {
        return {
            status: "locked",
            reason: "Daily screen time limit reached.",
            remainingDailyMinutes,
            overridesRemaining,
            blockedPackages: input.commitment.blacklist
        };
    }
    if (inFocusWindow) {
        return {
            status: "focus_only",
            reason: "Focus window active.",
            remainingDailyMinutes,
            overridesRemaining,
            blockedPackages: input.commitment.blacklist
        };
    }
    return {
        status: "normal",
        reason: "Normal usage window.",
        remainingDailyMinutes,
        overridesRemaining,
        blockedPackages: []
    };
}
