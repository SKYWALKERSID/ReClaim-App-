import { z } from 'zod';

export const driftSessionSchema = z.object({
  session_id: z.string().uuid(),
  app_package: z.string(),
  start_time: z.number(),
  end_time: z.number().nullable(),
  peak_drift_score: z.number().min(0).max(100),
  avg_drift_score: z.number().min(0).max(100),
  fragmentation_index: z.number().min(0).max(100),
  reopen_count: z.number().min(0),
  failed_exits: z.number().min(0),
  feed_exposure_seconds: z.number().min(0),
  intent_confidence: z.number().min(0).max(1),
});

export const driftBatchSchema = z.object({
  sessions: z.array(driftSessionSchema),
});
