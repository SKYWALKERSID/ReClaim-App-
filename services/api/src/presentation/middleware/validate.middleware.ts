import { Request, Response, NextFunction } from 'express';
import { ZodObject, ZodError } from 'zod';

export const validate = (schema: ZodObject<any, any, any>) => async (req: Request, res: Response, next: NextFunction) => {
  try {
    await schema.parseAsync(req.body);
    return next();
  } catch (error) {
    // Return generic error for security
    return res.status(400).json({ error: 'Invalid request data' });
  }
};
