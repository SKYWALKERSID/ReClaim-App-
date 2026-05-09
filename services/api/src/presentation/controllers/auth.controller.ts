import { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';
import { pool } from '../../db/pool.js';
import * as jwt from '../../utils/jwt.js';
import * as crypto from '../../utils/crypto.js';
import { env } from '../../config/env.js';

export class AuthController {
  async login(req: Request, res: Response, next: NextFunction) {
    const { idToken, deviceId } = req.body;
    const ip = req.ip;

    try {
      // 1. Verify Firebase ID Token
      const decodedToken = await admin.auth().verifyIdToken(idToken, true);
      const firebaseUid = decodedToken.uid;
      const email = decodedToken.email;

      // 2. Upsert User in PostgreSQL
      const upsertQuery = `
        INSERT INTO users (firebase_uid, email, preferences, created_at)
        VALUES ($1, $2, '{}'::jsonb, NOW())
        ON CONFLICT (firebase_uid) DO UPDATE 
        SET email = EXCLUDED.email
        RETURNING id, role
      `;
      const result = await pool.query(upsertQuery, [firebaseUid, email]);
      const user = result.rows[0];

      // 3. Issue Token Pair
      const accessToken = jwt.signAccessToken({ userId: user.id, role: user.role, deviceId });
      const refreshToken = jwt.signRefreshToken({ userId: user.id, deviceId });

      // 4. Store Refresh Token Hash
      const tokenHash = await crypto.hashToken(refreshToken);
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

      await pool.query(
        'INSERT INTO refresh_tokens (user_id, token_hash, device_id, expires_at) VALUES ($1, $2, $3, $4)',
        [user.id, tokenHash, deviceId, expiresAt]
      );

      // 5. Audit Logging
      await pool.query(
        'INSERT INTO login_audit (user_id, ip_address, device_id, success) VALUES ($1, $2, $3, $4)',
        [user.id, ip, deviceId, true]
      );

      res.status(200).json({ accessToken, refreshToken });
    } catch (error) {
      // Audit failure
      await pool.query(
        'INSERT INTO login_audit (ip_address, device_id, success, failure_reason) VALUES ($1, $2, $3, $4)',
        [ip, deviceId, false, 'Invalid credentials']
      );
      res.status(401).json({ error: 'Invalid email or password' });
    }
  }

  async refresh(req: Request, res: Response, next: NextFunction) {
    const { refreshToken } = req.body;

    try {
      // 1. Verify & Decode Token
      const decoded = jwt.verifyToken(refreshToken);
      const { userId } = decoded;

      // 2. Query Candidate Hashes
      const query = `
        SELECT id, token_hash FROM refresh_tokens 
        WHERE user_id = $1 AND revoked = FALSE AND expires_at > NOW()
      `;
      const result = await pool.query(query, [userId]);
      const candidates = result.rows;

      // 3. Loop and Compare
      let matchingRowId = null;
      for (const row of candidates) {
        const isMatch = await crypto.verifyHash(refreshToken, row.token_hash);
        if (isMatch) {
          matchingRowId = row.id;
          break;
        }
      }

      if (!matchingRowId) {
        return res.status(401).json({ error: 'Invalid refresh token' });
      }

      // 4. Rotate: Delete old, issue new pair
      await pool.query('DELETE FROM refresh_tokens WHERE id = $1', [matchingRowId]);

      const accessToken = jwt.signAccessToken({ userId, deviceId: decoded.deviceId });
      const newRefreshToken = jwt.signRefreshToken({ userId, deviceId: decoded.deviceId });
      const newTokenHash = await crypto.hashToken(newRefreshToken);
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      await pool.query(
        'INSERT INTO refresh_tokens (user_id, token_hash, device_id, expires_at) VALUES ($1, $2, $3, $4)',
        [userId, newTokenHash, decoded.deviceId, expiresAt]
      );

      res.status(200).json({ accessToken, refreshToken: newRefreshToken });
    } catch (error) {
      res.status(401).json({ error: 'Invalid refresh token' });
    }
  }

  async logout(req: Request, res: Response, next: NextFunction) {
    const { refreshToken } = req.body;

    try {
      const decoded = jwt.verifyToken(refreshToken);
      const { userId } = decoded;

      const query = `
        SELECT id, token_hash FROM refresh_tokens 
        WHERE user_id = $1 AND revoked = FALSE AND expires_at > NOW()
      `;
      const result = await pool.query(query, [userId]);
      
      let matchingRowId = null;
      for (const row of result.rows) {
        if (await crypto.verifyHash(refreshToken, row.token_hash)) {
          matchingRowId = row.id;
          break;
        }
      }

      if (matchingRowId) {
        await pool.query('DELETE FROM refresh_tokens WHERE id = $1', [matchingRowId]);
      }

      res.status(200).json({ message: 'Logged out successfully' });
    } catch (error) {
      // Still return 200 to not leak information
      res.status(200).json({ message: 'Logged out successfully' });
    }
  }
}
