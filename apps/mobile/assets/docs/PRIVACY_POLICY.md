# ReClaim™ Privacy Policy

ReClaim is built on the principle of **Informed Autonomy**. We believe that your behavioral data should be used to empower you, not exploit you.

---

## 1. Data Collection

### Behavioral Metadata
We collect anonymized package usage data, including:
- Package identifiers (e.g., `com.instagram.android`).
- Start and end times of app sessions.
- Blocked attempts and intentional overrides.

### Sensitive Input
**ReClaim DOES NOT collect or transmit:**
- Text input (keystrokes) from other apps.
- Passwords or payment details.
- Screen content (except for intentional intent detection).

### AI Coaching Data
When you use the AI Habit Coach, we collect:
- **Chat Messages**: The content of your conversation with the AI.
- **Goal/Habit Context**: Relevant progress stats and titles are shared with the AI to provide personalized advice.
- **AI Processing**: Data is processed via **Google Gemini**. We do not use your chat history to train public AI models.

---

## 2. Accessibility Service Usage

ReClaim uses the Android Accessibility Service API to provide its core behavioral enforcement.
- **Purpose**: To detect when a high-distraction app is launched and to overlay reflection prompts.
- **Permission**: Users must explicitly grant this permission.
- **Privacy**: No accessibility events are logged beyond package name transitions.

---

## 3. Data Storage & Security

### On-Device
Data is stored in an encrypted SQLite database and protected by the Android Keystore.

### Cloud Synchronization
Metrics are synced to a hardened PostgreSQL database for long-term analytics. All transmission is encrypted via TLS.

---

## 4. Your Rights

- **Data Export**: You can request an export of your behavioral logs at any time.
- **Deletion**: You can wipe your account and all associated metrics, including AI chat history, instantly.
- **Transparency**: Our core enforcement algorithms and AI guardrails are documented in `docs/`.

---
*Effective Date: May 14, 2026*
*Version: 1.1.0*
