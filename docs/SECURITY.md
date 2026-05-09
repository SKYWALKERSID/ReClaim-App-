# Security Architecture - ReClaim

## Overview
ReClaim implements a multi-layered security model to protect user focus and data integrity.

## Key Security Features
- **RS256 Asymmetric JWT Signing**: Ensures that tokens are signed with a private key and verified with a public key, preventing token forgery.
- **Keystore-backed Encrypted Storage**: Sensitive data on Android is stored using `EncryptedSharedPreferences` backed by the Android Keystore.
- **Refresh Token Rotation**: Implements refresh token rotation with bcrypt hashing to mitigate token theft.
- **Full Login Audit Trail**: Tracks all login attempts and sessions for security monitoring.
- **FLAG_SECURE Protection**: Prevents screenshots and screen recording on sensitive application screens.

## Security Mitigations
- **Certificate Pinning**: (Planned) To prevent Man-in-the-Middle (MitM) attacks.
- **Root Detection**: (Planned) Using RootBeer to detect compromised devices.
- **Rate Limiting**: Implemented on authentication endpoints to prevent brute-force attacks.
