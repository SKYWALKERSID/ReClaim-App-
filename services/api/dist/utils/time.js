export function todayKeyUtc() {
    return new Date().toISOString().slice(0, 10);
}
