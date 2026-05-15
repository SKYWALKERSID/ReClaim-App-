import { Router, Request, Response } from "express";
import { z } from "zod";
import rateLimit from "express-rate-limit";
import { runCoachSession, CoachMode } from "../../services/habitCoach.service.js";

const router = Router();

// ─── Security: Specialized Rate Limiting ──────────────────────────────────────

const coachRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20, // 20 requests per hour per user
  keyGenerator: (req: Request) => req.user?.id || req.ip || "anonymous",
  message: { error: "Coaching session limit reached. Please try again in an hour." },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false },
});

// ─── Validation: Zod Schemas ──────────────────────────────────────────────────

const chatSchema = z.object({
  mode: z.enum([
    "quick_checkin",
    "deep_coaching",
    "goal_setup",
    "recovery",
    "weekly_review",
    "celebration",
  ]),
  message: z.string().min(1).max(1000).trim(),
  sessionId: z.string().uuid().optional(),
});

/**
 * POST /v1/coach/chat
 * Body: { mode, message, sessionId? }
 * Returns: { reply, mode, sessionId, contextSnapshot }
 */
router.post("/chat", coachRateLimiter, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // Validate input
    const validation = chatSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({ 
        error: "Invalid request data", 
        details: validation.error.format() 
      });
    }

    const { mode, message, sessionId } = validation.data;

    const result = await runCoachSession({
      userId,
      mode,
      userMessage: message,
      sessionId,
    });

    const { contextSnapshot, ...clientSafeResult } = result;
    return res.json(clientSafeResult);
  } catch (err) {
    console.error("[HabitCoach] error:", err);
    return res.status(500).json({ error: "Coach session failed" });
  }
});

/**
 * GET /v1/coach/mode-hint
 * Returns the recommended mode based on current time + user state
 */
router.get("/mode-hint", coachRateLimiter, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // Simple heuristic using user's local time if available, or server time
    // In a real app, we'd fetch the user's timezone from the DB first.
    // For now, we'll stick to a simple time-of-day logic.
    const hour = new Date().getHours();
    const dayOfWeek = new Date().getDay(); // 0 = Sun

    let mode: CoachMode = "quick_checkin";

    if (dayOfWeek === 0 && hour >= 18) mode = "weekly_review";
    else if (hour >= 6 && hour < 10) mode = "quick_checkin";
    else mode = "deep_coaching";

    return res.json({ mode });
  } catch (err) {
    return res.status(500).json({ error: "Mode hint failed" });
  }
});

/**
 * GET /v1/coach/widget-nudge
 * Returns a short, personalized nudge for the Home Screen widget.
 */
router.get("/widget-nudge", coachRateLimiter, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const nudge = await runCoachSession({
      userId,
      mode: "quick_checkin",
      userMessage: "Generate a 10-word motivational nudge for my home screen widget based on my current progress. Keep it snappy and personal.",
      sessionId: undefined, // Don't persist this one as a full chat session
    });

    // Strip contextSnapshot from the return object
    const { contextSnapshot, ...clientSafeResult } = nudge;
    
    // Strip Markdown for the widget display
    const cleanNudge = clientSafeResult.reply.replace(/[\*\#\`\_]/g, "").substring(0, 80);

    return res.json({ nudge: cleanNudge });
  } catch (err) {
    console.error("[HabitCoach] Nudge error:", err);
    return res.json({ nudge: "Keep going! You're doing great." });
  }
});

export default router;
