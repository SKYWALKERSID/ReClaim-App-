import { Router } from "express";
import jwt from "jsonwebtoken";
import { randomUUID } from "crypto";
import { env } from "../../config/env.js";
import { pool } from "../../db/pool.js";
export function buildAuthRoutes() {
    const router = Router();
    /**
     * @openapi
     * /auth/anonymous:
     *   post:
     *     summary: Anonymous Authentication
     *     description: Generates a new userId and returns a long-lived JWT. Use this token in the Authorization header for future requests.
     *     responses:
     *       201:
     *         description: Successfully created anonymous user and generated token
     *         content:
     *           application/json:
     *             schema:
     *               type: object
     *               properties:
     *                 token: { type: string }
     *                 userId: { type: string, format: uuid }
     */
    router.post("/auth/anonymous", async (req, res, next) => {
        try {
            // 1. Generate a new UUID
            const userId = randomUUID();
            // 2. Insert into users table
            const query = `
        INSERT INTO users (id, preferences, created_at)
        VALUES ($1, '{}'::jsonb, NOW())
        RETURNING id
      `;
            await pool.query(query, [userId]);
            const token = jwt.sign({ userId, role: "user" }, env.jwtSecret, { expiresIn: "1h" });
            res.status(201).json({
                token,
                userId
            });
        }
        catch (error) {
            next(error);
        }
    });
    return router;
}
