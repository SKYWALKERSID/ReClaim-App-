import { MailService } from '../../infrastructure/services/mailService.js';
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
    } catch (error: any) {
      console.error("[AuthController] Login error:", error.message);
      // Audit failure
      await pool.query(
        'INSERT INTO login_audit (ip_address, device_id, success, failure_reason) VALUES ($1, $2, $3, $4)',
        [ip, deviceId, false, error.message || 'Invalid credentials']
      );
      res.status(401).json({ error: error.message || 'Invalid email or password' });
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
  async sendOTP(req: Request, res: Response) {
    const userId = req.user?.userId || req.body.userId;
    const { email: bodyEmail } = req.body;

    try {
      let email = bodyEmail;
      let finalUserId = userId;

      if (!email && userId) {
        const userResult = await pool.query('SELECT email FROM users WHERE id = $1', [userId]);
        if (userResult.rows.length > 0) {
          email = userResult.rows[0].email;
        }
      }

      if (!email) return res.status(400).json({ error: 'Email is required for OTP' });

      // If no userId (not logged in), try to find user by email
      if (!finalUserId) {
        const userResult = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
        if (userResult.rows.length > 0) {
          finalUserId = userResult.rows[0].id;
        }
      }

      if (!finalUserId) return res.status(404).json({ error: 'No account associated with this email' });

      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins

      // 2. Clear existing OTPs for this user
      await pool.query('DELETE FROM otp_verifications WHERE user_id = $1', [finalUserId]);
      
      // 3. Save new OTP
      await pool.query(
        'INSERT INTO otp_verifications (user_id, otp_code, expires_at) VALUES ($1, $2, $3)',
        [finalUserId, otp, expiresAt]
      );

      // 3. Send OTP
      await MailService.sendOTP(email, otp);
      
      res.status(200).json({ message: 'OTP sent to your registered Gmail' });
    } catch (error) {
      console.error('[AuthController] OTP send error:', error);
      res.status(500).json({ error: 'Failed to send OTP' });
    }
  }

  async verifyOTP(req: Request, res: Response) {
    const userId = req.user?.userId || req.body.userId;
    const { otp, email } = req.body;

    try {
      let finalUserId = userId;
      if (!finalUserId && email) {
        const userResult = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
        if (userResult.rows.length > 0) finalUserId = userResult.rows[0].id;
      }

      if (!finalUserId) return res.status(400).json({ error: 'User context missing' });

      const result = await pool.query(
        'SELECT * FROM otp_verifications WHERE user_id = $1 AND otp_code = $2 AND expires_at > NOW()',
        [finalUserId, otp]
      );

      if (result.rows.length === 0) {
        return res.status(400).json({ error: 'Invalid or expired OTP' });
      }

      // Cleanup
      await pool.query('DELETE FROM otp_verifications WHERE user_id = $1', [finalUserId]);

      res.status(200).json({ message: 'OTP verified successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Verification failed' });
    }
  }
}
