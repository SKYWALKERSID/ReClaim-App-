import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export interface TokenPayload {
  userId: string;
  role?: string;
  deviceId?: string;
}

export function signAccessToken(payload: TokenPayload): string {
  if (!env.jwtPrivateKey) throw new Error('JWT_PRIVATE_KEY is not configured');
  
  return jwt.sign(payload, env.jwtPrivateKey, {
    algorithm: 'RS256',
    expiresIn: env.jwtAccessExpiry as any,
  });
}

export function signRefreshToken(payload: TokenPayload): string {
  if (!env.jwtPrivateKey) throw new Error('JWT_PRIVATE_KEY is not configured');

  return jwt.sign(payload, env.jwtPrivateKey, {
    algorithm: 'RS256',
    expiresIn: env.jwtRefreshExpiry as any,
  });
}

export function verifyToken(token: string): TokenPayload {
  if (!env.jwtPublicKey) throw new Error('JWT_PUBLIC_KEY is not configured');

  try {
    return jwt.verify(token, env.jwtPublicKey, {
      algorithms: ['RS256'],
    }) as TokenPayload;
  } catch (err) {
    throw new Error('Invalid or expired token');
  }
}
