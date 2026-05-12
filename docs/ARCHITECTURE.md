# ReClaim™ System Architecture

ReClaim is a high-performance behavioral autonomy platform. Its architecture is designed for **Real-Time Enforcement**, **Cognitive Awareness**, and **Social Accountability**.

---

## 🏗️ The Four Planes

The system is organized into four distinct planes of operation:

### 1. Execution Plane (Mobile Native - Kotlin)
The "Heart" of the system.
- **Accessibility Service**: Intercepts `TYPE_WINDOW_STATE_CHANGED` events to detect app transitions.
- **Cognitive Drift Engine™**: Processes high-frequency interaction data (scrolling velocity, session fragmenting) locally on the device.
- **SafeCode™ Vault**: Manages emergency overrides using the Android Keystore (TEE).

### 2. Presentation Plane (Mobile UI - Flutter)
The "Mirror" of the system.
- **Brain Mirror™ Dashboard**: Renders real-time drift metrics and fragmentation charts.
- **Reactive State**: Uses **Riverpod** to synchronize backend data with local enforcement states.
- **MethodChannel Bridge**: Secure serial bridge between the Flutter event loop and the Native Core.

### 3. Intelligence Plane (Backend - Node.js/TS)
The "Brain" of the system.
- **PatternEngine**: Analyzes time-series data to identify "Craving Windows" and behavioral lapses.
- **RewardEngine**: Calculates the Discipline Quotient and manages the points/badges economy.
- **Clean Service Layers**: Separates Domain logic from Persistence (PostgreSQL) and Presentation (Express).

### 4. Social Plane (Accountability Network)
The "Shield" of the system.
- **Buddy Network**: Facilitates peer-to-peer accountability without compromising privacy.
- **Challenge Engine**: Orchestrates community-wide focus events and streak competitions.

---

## 🛡️ Security & Privacy Architecture

### Identity (RS256)
Authentication is strictly managed via asymmetric signatures.
- **Private Key**: Resides in a hardened backend environment.
- **Public Key**: Bundled with the mobile client to verify JWT integrity.
- **Token Rotation**: Short-lived access tokens (15m) with hardware-bound refresh tokens.

### Data Sovereignty
- **Privacy First**: Accessibility services are configured with `canRetrieveWindowContent = false`. We monitor *when* you use apps, not *what* you do inside them.
- **Encryption**: AES-256-GCM for all at-rest data. TLS 1.3 for all transit.

---

## ⚙️ Tech Stack Summary

| Layer | Technology |
| --- | --- |
| **Frontend** | Flutter 3.x, Riverpod, GoRouter |
| **Native** | Kotlin, Android Accessibility API, TEE |
| **Backend** | Node.js 20, TypeScript, Express |
| **Database** | PostgreSQL 14 (Partitioned) |
| **Auth** | Firebase Auth (Identity) + Custom RS256 JWT (Session) |
| **DevOps** | GitHub Actions, Docker, Node-Cron |

---
*Document Version: 2.0.0*
*Last Verified: May 11, 2026*
