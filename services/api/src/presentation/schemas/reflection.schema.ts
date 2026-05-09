import { z } from 'zod';

export const reflectionEventSchema = z.object({
  session_id: z.string().optional(),
  prompt_type: z.string(),
  response: z.string(),
  drift_score: z.number().min(0).max(100),
  timestamp: z.number(),
});

export const reflectionBatchSchema = z.object({
  events: z.array(reflectionEventSchema),
});
