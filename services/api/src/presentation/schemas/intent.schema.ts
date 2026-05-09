import { z } from 'zod';

export const intentEventSchema = z.object({
  app_package: z.string(),
  intent_choice: z.string(),
  trigger_reason: z.string().optional(),
  timestamp: z.string().or(z.number()), // Supports ISO string or epoch
});

export const intentBatchSchema = z.object({
  events: z.array(intentEventSchema),
});

export type IntentEventInput = z.infer<typeof intentEventSchema>;
export type IntentBatchInput = z.infer<typeof intentBatchSchema>;
