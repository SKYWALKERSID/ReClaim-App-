# Key Algorithms

## 1) Enforcement Decision (Android native)

Location: `apps/mobile/android/app/src/main/kotlin/com/reclaim/app/flutter/enforcement/EnforcementManager.kt`

Priority order:

1. If app is in whitelist -> allow
2. If temporary emergency grace exists -> allow
3. If policy status is `locked` -> block
4. If current time is inside focus window -> block non-whitelist
5. If today usage >= daily limit -> block
6. Else allow

This order prevents loopholes while keeping emergency flow deterministic.

## 2) Pattern Detection

Location: `services/api/src/domain/services/patternEngine.ts`

Computed signals:

- `appSwitchesPerHour`
- `lateNightMinutes` (23:00-05:00 local)
- `distractionMinutes` (blacklist package usage)
- Ignores synthetic snapshot events (`metadata.snapshotTotalMinutes`)

Risk score:

`risk = min(100, round(distraction*0.8 + lateNight*0.9 + appSwitchesPerHour*10))`

Recommendations are generated only when signals cross practical thresholds.

## 3) Reward Logic (Minimal, Non-addictive)

Location: `services/api/src/domain/services/rewardEngine.ts`

Rules:

- +50 for staying within daily limit
- +10 per completed focus session (max 3/day)
- +20 if no overrides used
- +15 for low late-night usage
- Streak increments only if within limit; resets otherwise
- Level progression:
  - `Beginner`: 0-6 streak
  - `Disciplined`: 7-20 streak
  - `Focus Pro`: 21+ streak

Design goal: reinforce discipline without engagement loops.

## 4) Policy Evaluation (API)

Location: `services/api/src/application/policyService.ts`

Inputs: commitment + daily metrics + local time window.

Outputs:

- `normal`
- `focus_only`
- `locked`

Includes `remainingDailyMinutes`, `overridesRemaining`, and the effective block set used by client-side enforcers.

## 5) Snapshot Reconciliation

Location: `services/api/src/application/analyticsService.ts`

- Client uploads periodic usage snapshot events with `metadata.snapshotTotalMinutes`.
- Daily total screen minutes uses the max snapshot value for the day.
- This avoids double-counting if sync runs multiple times.
