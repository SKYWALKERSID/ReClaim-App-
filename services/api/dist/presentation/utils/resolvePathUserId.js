import { userIdParamSchema } from "../validation/schemas.js";
/** Resolves `:userId` path param: JWT users may only access their own id; API-key clients may access the path id. */
export function resolvePathUserId(req, res) {
    const parsed = userIdParamSchema.safeParse(req.params);
    if (!parsed.success) {
        res.status(400).json({ error: "Invalid userId", code: "BAD_REQUEST" });
        return null;
    }
    const { userId } = parsed.data;
    const u = req.user;
    if (u.role === "service") {
        return userId;
    }
    if (userId !== u.userId) {
        res.status(403).json({
            error: "Forbidden",
            code: "FORBIDDEN",
            message: "Cannot access another user's data",
        });
        return null;
    }
    return userId;
}
