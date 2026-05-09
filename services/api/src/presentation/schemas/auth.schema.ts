import { z } from 'zod';

export const loginSchema = z.object({
  idToken: z.string().min(1),
  deviceId: z.string().optional(),
}).strict();

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
}).strict();

export const logoutSchema = z.object({
  refreshToken: z.string().min(1),
}).strict();
