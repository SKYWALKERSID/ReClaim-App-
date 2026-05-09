import { z } from 'zod';

export const frictionEventSchema = z.object({
  app_package: z.string(),
  friction_type: z.string(),
  drift_score: z.number().min(0).max(100),
  overridden: z.boolean(),
  timestamp: z.number(),
});

export const frictionBatchSchema = z.object({
  events: z.array(frictionEventSchema),
});
