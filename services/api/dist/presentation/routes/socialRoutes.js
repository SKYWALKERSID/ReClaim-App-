import { Router } from "express";
import { z } from "zod";
export function buildSocialRoutes(repository) {
    const router = Router();
    function requireUserJwt(req, res) {
        if (req.user.role === "service") {
            res.status(403).json({
                error: "Forbidden",
                code: "FORBIDDEN",
                message: "Social features require a user JWT (Bearer), not x-api-key.",
            });
            return false;
        }
        return true;
    }
    /**
     * @openapi
     * /social/buddies:
     *   get:
     *     summary: Get user buddies
     *     tags: [Social]
     */
    router.get("/buddies", async (req, res, next) => {
        try {
            if (!requireUserJwt(req, res)) {
                return;
            }
            const userId = req.user.userId;
            const buddies = await repository.getBuddies(userId);
            res.json(buddies);
        }
        catch (e) {
            next(e);
        }
    });
    /**
     * @openapi
     * /social/buddies:
     *   post:
     *     summary: Add a buddy
     *     tags: [Social]
     */
    router.post("/buddies", async (req, res, next) => {
        try {
            if (!requireUserJwt(req, res)) {
                return;
            }
            const userId = req.user.userId;
            const { buddyId } = z.object({ buddyId: z.string().uuid() }).parse(req.body);
            await repository.addBuddy(userId, buddyId);
            res.status(201).json({ message: "Buddy added" });
        }
        catch (e) {
            next(e);
        }
    });
    /**
     * @openapi
     * /social/challenges:
     *   get:
     *     summary: Get active challenges
     *     tags: [Social]
     */
    router.get("/challenges", async (req, res, next) => {
        try {
            const challenges = await repository.getActiveChallenges();
            res.json(challenges);
        }
        catch (e) {
            next(e);
        }
    });
    /**
     * @openapi
     * /social/challenges/join:
     *   post:
     *     summary: Join a challenge
     *     tags: [Social]
     */
    router.post("/challenges/join", async (req, res, next) => {
        try {
            if (!requireUserJwt(req, res)) {
                return;
            }
            const userId = req.user.userId;
            const { challengeId } = z.object({ challengeId: z.string().uuid() }).parse(req.body);
            await repository.joinChallenge(challengeId, userId);
            res.json({ message: "Joined challenge" });
        }
        catch (e) {
            next(e);
        }
    });
    return router;
}
