export function todayKeyUtc(): string {
  return new Date().toISOString().slice(0, 10);
}
