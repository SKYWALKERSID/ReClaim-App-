# Security Policy

## Supported Versions

ReClaim is currently in a pre-release state. We support the latest commit on the `main` branch.

| Version | Supported          |
| ------- | ------------------ |
| v1.0.x  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of ReClaim seriously. If you discover a security vulnerability, please do not open a public issue. Instead, follow these steps:

1. Send an email to the maintainers (security@reclaim.app — *Placeholder*).
2. Provide a detailed description of the vulnerability and steps to reproduce it.
3. Allow up to 48 hours for a response.
4. We will coordinate a fix and follow responsible disclosure practices.

## Security Architecture

ReClaim implements several layers of defense to protect user data and behavioral integrity:

### 1. Cryptographic Identity
- **RS256 JWT**: All API requests are authenticated using RS256 signed JSON Web Tokens.
- **Asymmetric Validation**: The backend holds the private key; public keys are distributed for token validation where necessary.

### 2. On-Device Protection
- **Hardware-Backed Keystore**: On Android, cryptographic keys are stored in the TEE (Trusted Execution Environment) or SE (Secure Element).
- **Encrypted Shared Preferences**: All local sensitive data (tokens, user settings) is encrypted using `AES-256-GCM`.
- **Screen Privacy**: `FLAG_SECURE` is enabled on sensitive screens (Login, Settings) to prevent screen recording and snapshots.

### 3. Backend Hardening
- **Helmet.js**: Implements various HTTP headers for security (CSP, HSTS, etc.).
- **Rate Limiting**: Brute-force protection on authentication and sensitive ingestion endpoints.
- **Zod Validation**: Strict schema enforcement for all incoming payloads to prevent injection attacks.

### 4. AI Coaching Security (Gemini Integration)
- **Input Sanitization**: All user messages are stripped of XML/HTML tags and jailbreak patterns before being processed by the AI model.
- **Crisis Guardrails**: Real-time keyword monitoring detects distress or self-harm triggers, immediately appending standardized crisis support resources to AI responses.
- **Server-Side Sessions**: Chat history is maintained securely on the server (linked to User ID) rather than client-side, preventing context manipulation.
- **Audit Logging**: All AI interactions are logged with token usage and status codes to monitor for anomalous behavior or costs.

## Data Privacy

ReClaim is designed to minimize data leakage:
- **Usage Telemetry**: Only anonymized package usage and duration data are synced to the backend for analytics computation.
- **Accessibility Privacy**: The Accessibility Service does NOT log text input or sensitive window content. It only monitors package name transitions for enforcement.
