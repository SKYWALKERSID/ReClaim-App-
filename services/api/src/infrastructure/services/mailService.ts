import nodemailer from 'nodemailer';
import { logger } from '../../utils/logger.js';

export class MailService {
  private static transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  static async sendOTP(to: string, otp: string) {
    if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
      // TODO: SMTP_USER and SMTP_PASS should be added to validated env config (env.ts)
      logger.warn('[MailService] SMTP credentials missing. OTP logged at debug level (dev only):');
      logger.debug(`[MailService] [DEV OTP] ${otp} for ${to}`);
      return;
    }

    const mailOptions = {
      from: `"ReClaim Security" <${process.env.SMTP_USER}>`,
      to,
      subject: 'Your ReClaim Recovery Code',
      html: `
        <div style="font-family: sans-serif; padding: 20px; color: #333;">
          <h2>Security Verification</h2>
          <p>You requested a recovery code for your ReClaim SafeCode.</p>
          <div style="background: #f4f4f4; padding: 20px; border-radius: 10px; font-size: 24px; font-weight: bold; text-align: center; letter-spacing: 5px;">
            ${otp}
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this, please secure your account immediately.</p>
        </div>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      logger.info(`[MailService] OTP sent to ${to}`);
    } catch (error) {
      logger.error('[MailService] Failed to send OTP email:', { error: String(error) });
      throw new Error('Failed to send email');
    }
  }
}
