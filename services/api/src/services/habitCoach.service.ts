import { GoogleGenerativeAI } from "@google/generative-ai";
import { pool as db } from "../db/pool.js";
import { env } from "../config/env.js";

const genAI = new GoogleGenerativeAI(env.geminiApiKey);

// ─── Types ────────────────────────────────────────────────────────────────────

export type CoachMode =
  | "quick_checkin"
  | "deep_coaching"
  | "goal_setup"
  | "recovery"
  | "weekly_review"
  | "celebration";

interface Goal {
  title: string;
  target_date: string;
  progress_pct: number;
  milestones: { label: string; due: string; done: boolean }[];
}

interface Habit {
  name: string;
  completion_rate_7d: number; // 0–1
  current_streak: number;
  cue: string;
}

interface UserContext {
  name: string;
  timezone: string;
  days_since_onboarding: number;
  current_streak: number;
  longest_streak: number;
}

interface WeeklySummary {
  completed: number;
  total: number;
  by_day: Record<string, { completed: number; total: number }>;
}

export interface CoachSessionInput {
  userId: string;
  mode: CoachMode;
  userMessage: string;
  sessionId?: string; // Optional: Resume an existing session
}

export interface CoachSessionOutput {
  reply: string;
  mode: CoachMode;
  sessionId: string;
  contextSnapshot: Record<string, unknown>;
}

// ─── Environment Checks ───────────────────────────────────────────────────────

if (!env.geminiApiKey) {
  throw new Error("GEMINI_API_KEY environment variable is required");
}

// ─── DB Queries ───────────────────────────────────────────────────────────────

async function fetchUserContext(userId: string): Promise<UserContext> {
  const { rows } = await db.query(
    `SELECT
       u.display_name                                        AS name,
       u.timezone,
       EXTRACT(DAY FROM NOW() - u.created_at)::int          AS days_since_onboarding,
       COALESCE(s.current_streak, 0)                        AS current_streak,
       COALESCE(s.longest_streak, 0)                        AS longest_streak
     FROM users u
     LEFT JOIN user_streaks s ON s.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  if (!rows[0]) throw new Error(`User not found: ${userId}`);
  return rows[0];
}

async function fetchActiveGoals(userId: string): Promise<Goal[]> {
  const { rows } = await db.query(
    `SELECT
        g.title,
       g.target_date::text,
       COALESCE(g.progress_pct, 0) AS progress_pct,
       COALESCE(
         json_agg(
           json_build_object(
             'label', m.label,
             'due',   m.due_date::text,
             'done',  m.completed_at IS NOT NULL
           ) ORDER BY m.due_date
         ) FILTER (WHERE m.id IS NOT NULL),
         '[]'
       ) AS milestones
     FROM goals g
     LEFT JOIN goal_milestones m ON m.goal_id = g.id
     WHERE g.user_id = $1 AND g.archived_at IS NULL
     GROUP BY g.id
     ORDER BY g.created_at DESC`,
    [userId]
  );
  return rows;
}

async function fetchHabits(userId: string): Promise<Habit[]> {
  const { rows } = await db.query(
    `SELECT
        h.name,
       h.cue,
       COALESCE(h.current_streak, 0) AS current_streak,
       ROUND(
         COUNT(hc.id) FILTER (
           WHERE hc.completed_at >= NOW() - INTERVAL '7 days'
         )::numeric / 7, 2
       ) AS completion_rate_7d
     FROM habits h
     LEFT JOIN habit_completions hc ON hc.habit_id = h.id
     WHERE h.user_id = $1 AND h.archived_at IS NULL
     GROUP BY h.id
     ORDER BY h.sort_order`,
    [userId]
  );
  return rows;
}

async function fetchWeeklySummary(userId: string): Promise<string> {
  const { rows } = await db.query(
    `SELECT
       COALESCE(COUNT(hc.id), 0) AS total_completions,
       COUNT(DISTINCT h.id)      AS active_habits
     FROM generate_series(NOW()::date - 6, NOW()::date, '1 day'::interval) AS day_series(d)
     CROSS JOIN (
       SELECT id FROM habits WHERE user_id = $1 AND archived_at IS NULL
     ) AS h
     LEFT JOIN habit_completions hc
       ON hc.habit_id = h.id
       AND hc.completed_at::date = day_series.d
     GROUP BY ()`,
    [userId]
  );
  const data = rows[0] || { total_completions: 0, active_habits: 0 };
  return `${data.total_completions} completions across ${data.active_habits} habits`;
}

async function fetchMissedHabits(userId: string): Promise<string[]> {
  const { rows } = await db.query(
    `SELECT h.name
     FROM habits h
     WHERE h.user_id = $1
       AND h.archived_at IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM habit_completions hc
         WHERE hc.habit_id = h.id
           AND hc.completed_at >= NOW() - INTERVAL '3 days'
       )`,
    [userId]
  );
  return rows.map((r) => r.name);
}

async function fetchUpcomingMilestones(
  userId: string
): Promise<{ goal: string; milestone: string; due: string }[]> {
  const { rows } = await db.query(
    `SELECT
       g.title  AS goal,
       m.label  AS milestone,
       m.due_date::text AS due
     FROM goal_milestones m
     JOIN goals g ON g.id = m.goal_id
     WHERE g.user_id = $1
       AND m.completed_at IS NULL
       AND m.due_date BETWEEN NOW() AND NOW() + INTERVAL '14 days'
     ORDER BY m.due_date
     LIMIT 5`,
    [userId]
  );
  return rows;
}

// ─── Context Builder ──────────────────────────────────────────────────────────

function getTimeOfDay(timezone: string): string {
  const h = new Date(
    new Date().toLocaleString("en-US", { timeZone: timezone })
  ).getHours();
  if (h < 12) return "morning";
  if (h < 17) return "afternoon";
  if (h < 21) return "evening";
  return "night";
}

async function buildContextPayload(userId: string) {
  try {
    const user = await fetchUserContext(userId);
    
    // Wrap other fetches in safe guards or Promise.allSettled if partial failure is okay
    const [goals, habits, weekly, missed, milestones] = await Promise.all([
      fetchActiveGoals(userId).catch(() => []),
      fetchHabits(userId).catch(() => []),
      fetchWeeklySummary(userId).catch(() => "Data unavailable"),
      fetchMissedHabits(userId).catch(() => []),
      fetchUpcomingMilestones(userId).catch(() => []),
    ]);

    return {
      user,
      goals,
      habits,
      weekly_summary: weekly,
      missed_habits_last_3_days: missed,
      upcoming_milestones: milestones,
      time_of_day: getTimeOfDay(user.timezone),
      day_of_week: new Date().toLocaleDateString("en-US", { 
        weekday: "long",
        timeZone: user.timezone 
      }),
    };
  } catch (err) {
    console.error("[HabitCoach] Context build failed:", err);
    throw err;
  }
}

// ─── Security & Sanitization ──────────────────────────────────────────────────

function sanitizeInput(text: string): string {
  // Strip XML tags and common jailbreak patterns
  return text
    .replace(/<[^>]*>?/gm, "") // Remove angle brackets and XML
    .replace(/(ignore previous instructions|you are now|system prompt)/gi, "[REDACTED]")
    .substring(0, 1000); // Enforce character limit
}

const CRISIS_KEYWORDS = [
  "suicide", "kill myself", "end my life", "self-harm", "hurt myself", 
  "want to die", "better off dead", "cutting myself"
];

function applyCrisisGuardrail(reply: string): string {
  const lowercase = reply.toLowerCase();
  const hasCrisis = CRISIS_KEYWORDS.some(k => lowercase.includes(k));
  
  if (hasCrisis) {
    return reply + "\n\n---\n**Crisis Support:** If you're feeling overwhelmed or in distress, please know you're not alone. You can call or text **988** anytime in the US and Canada, or **111** in the UK to reach a crisis counselor. We care about your well-being.";
  }
  return reply;
}

// ─── Session & Message Persistence ──────────────────────────────────────────

async function getOrCreateSession(userId: string, mode: CoachMode, sessionId?: string) {
  if (sessionId) {
    const { rows } = await db.query(
      "SELECT id FROM coach_sessions WHERE id = $1 AND user_id = $2",
      [sessionId, userId]
    );
    if (rows[0]) return rows[0].id;
  }

  const { rows } = await db.query(
    "INSERT INTO coach_sessions (user_id, mode) VALUES ($1, $2) RETURNING id",
    [userId, mode]
  );
  return rows[0].id;
}

async function saveMessage(sessionId: string, role: "user" | "assistant", content: string, tokens?: number) {
  await db.query(
    "INSERT INTO coach_messages (session_id, role, content, tokens) VALUES ($1, $2, $3, $4)",
    [sessionId, role, content, tokens]
  );
}

async function getSessionHistory(sessionId: string, limit = 20) {
  const { rows } = await db.query(
    "SELECT role, content FROM coach_messages WHERE session_id = $1 ORDER BY created_at ASC LIMIT $2",
    [sessionId, limit]
  );
  return rows;
}

async function logAudit(userId: string, sessionId: string, inputTokens: number, outputTokens: number, durationMs: number, status: number) {
  await db.query(
    `INSERT INTO coach_audit_logs (user_id, session_id, input_tokens, output_tokens, duration_ms, model_used, status_code)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [userId, sessionId, inputTokens, outputTokens, durationMs, "gemini-1.5-flash", status]
  );
}

// ─── System Prompt ────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `
You are an empathetic, science-backed habit coach embedded inside a personal productivity app.
You blend BJ Fogg's Tiny Habits and James Clear's Atomic Habits frameworks with personalized goal architecture.

## Your Persona
- Warm, direct, conversational — like a trusted friend who is an expert
- Lead with empathy, follow with strategy
- Celebrate effort and process, not just outcomes
- Give ONE clear next step at the end of every coaching session
- Use the user's actual habit and goal names from the context

## Modes
| Mode           | Behavior                                              |
|----------------|-------------------------------------------------------|
| quick_checkin  | 3–4 sentences max, one question                       |
| deep_coaching  | Full coaching arc, up to 15 turns                     |
| goal_setup     | Structured intake → SMART goal → micro-habits         |
| recovery       | High empathy, no pressure, re-anchor to today         |
| weekly_review  | Structured reflection + next week plan                |
| celebration    | Enthusiastic, specific, forward-looking               |

## Response Format (mobile markdown)
- **Bold** for key insights
- 2–3 sentence paragraphs max
- Bullet lists only for action steps
- End with **Next Step:** or **Reflect On:**
- Minimal emoji: ✅ completions · 🎯 goals · 🔥 streaks

## Rules
- Never ask for info already in the context
- Never shame or guilt a missed day — be curious, not judgmental
- Never give more than one action item at a time
- If the user expresses distress, validate and suggest professional support
`;

// ─── Main Service Function ────────────────────────────────────────────────────

export async function runCoachSession(
  input: CoachSessionInput
): Promise<CoachSessionOutput> {
  const { userId, mode, userMessage: rawMessage, sessionId: providedSessionId } = input;
  const startTime = Date.now();

  // 1. Sanitize user input
  const userMessage = sanitizeInput(rawMessage);

  // 2. Get or create session and history (Server-side source of truth)
  const sessionId = await getOrCreateSession(userId, mode, providedSessionId);
  const history = await getSessionHistory(sessionId);

  // 3. Fetch context and audit fields
  const ctx = await buildContextPayload(userId);

  // 4. Build message array for Claude
  const contextBlockBase = `
<app_context>
${JSON.stringify({ ...ctx, mode }, null, 2)}
</app_context>`.trim();

  const messages: any[] = [];
  if (history.length === 0) {
    // Brand new session: first message carries context + user message
    messages.push({ 
      role: "user", 
      content: `${contextBlockBase}\n\n${userMessage}`.trim() 
    });
  } else {
    // Resuming session: inject latest context into the first turn
    messages.push({ 
      role: "user", 
      content: `${contextBlockBase}\n\n${history[0].content}`.trim() 
    });
    // Keep remaining history (assistant replies and subsequent user messages)
    messages.push(...history.slice(1).map(m => ({ role: m.role, content: m.content })));
    // Append the current user message as the final turn
    messages.push({ role: "user", content: userMessage });
  }

  let reply = "";
  let status = 200;

  try {
    // 5. Call Gemini
    const model = genAI.getGenerativeModel({ 
      model: "gemini-1.5-flash",
      systemInstruction: SYSTEM_PROMPT 
    });

    // Format history for Gemini (user -> user, assistant -> model)
    const contents = history.map(h => ({
      role: h.role === "assistant" ? "model" : "user",
      parts: [{ text: h.content }]
    }));

    // Inject context into the first user message if it's a new session, or append to latest
    const contextUserMessage = `${contextBlockBase}\n\n${userMessage}`;

    const chat = model.startChat({
      history: contents,
    });

    const result = await chat.sendMessage(contextUserMessage);
    const response = await result.response;
    reply = response.text();

    // 6. Post-processing: Crisis Guardrails
    reply = applyCrisisGuardrail(reply);

    // 7. Persist messages server-side
    await saveMessage(sessionId, "user", userMessage);
    await saveMessage(sessionId, "assistant", reply);

    // 8. Audit Log
    // Note: Gemini SDK doesn't always expose token usage in the same way, using estimates or defaults for now
    await logAudit(
      userId,
      sessionId,
      0, // input tokens estimate
      0, // output tokens estimate
      Date.now() - startTime,
      200
    );

  } catch (err) {
    status = 500;
    console.error("[HabitCoach] Gemini API Error:", err);
    throw err;
  }

  return {
    reply,
    mode,
    sessionId,
    contextSnapshot: ctx,
  };
}
