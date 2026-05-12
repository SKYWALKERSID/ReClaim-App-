import { Request, Response, NextFunction } from 'express';
import { type ZodTypeAny } from 'zod';

/**
 * validate(schema) — Express middleware factory for Zod body validation.
 * Parses req.body against the provided Zod schema asynchronously.
 * Returns a generic 400 on failure to avoid leaking schema structure.
 */
export const validate = (schema: ZodTypeAny) => async (req: Request, res: Response, next: NextFunction) => {
  try {
    await schema.parseAsync(req.body);
    return next();
  } catch {
    return res.status(400).json({ error: 'Bad Request', code: 'VALIDATION_ERROR', message: 'Invalid request data.' });
  }
};
