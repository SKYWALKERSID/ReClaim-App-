import { v4 as uuidv4 } from "uuid";
export function requestIdMiddleware(req, res, next) {
    const requestId = req.header("x-request-id") || uuidv4();
    req.requestId = requestId;
    res.setHeader("x-request-id", requestId);
    next();
}
