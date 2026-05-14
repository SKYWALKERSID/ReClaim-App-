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

## 🧬 Modularization & Evolution Strategy

ReClaim utilizes a dual-module Android architecture to balance rapid R&D with production stability:

1.  **Core Native R&D (`apps/android-native`)**: 
    - A standalone Kotlin module used for mastering low-level system hooks (Accessibility, TEE, UsageStats).
    - Serves as the "Reference Engine" for performance benchmarking without UI overhead.
2.  **Flutter Production (`apps/mobile`)**: 
    - Integrates the native engines with a high-fidelity **Presentation Plane**.
    - Uses the **MethodChannel Bridge** to drive the dynamic "Brain Mirror™" interface.

---

## 📈 Behavioral Mathematics

The system relies on three core algorithms to quantify the user's state:

1.  **Fragmentation Index (FI)**:
    $$FI = \frac{\sum (Weights_{app} \times Transitions)}{TotalSessionTime}$$
    *Logic: High FI (>0.5) triggers Hard Friction.*
2.  **Drift Score (DS)**: 
    Real-time velocity and interaction depth measurement. 
    *Logic: DS > 0.7 flags high-risk behavioral decay.*
3.  **Discipline Quotient (DQ)**: 
    $$DQ = (DailyPoints + FocusBonus) \times StreakMultiplier - NightPenalties$$

---

## ⚙️ Tech Stack Summary

| Layer | Technology |
| --- | --- |
| **Frontend** | Flutter 3.x, Riverpod, MPAndroidChart |
| **Native** | Kotlin, Room Persistence, Android TEE |
| **Backend** | Node.js 20, TypeScript, Express, Zod |
| **Database** | PostgreSQL 14 (Partitioned) |
| **Auth** | Firebase Auth (Identity) + Custom RS256 JWT (Session) |
| **Security** | AES-256-GCM, FLAG_SECURE, RSA-256 |

---
*Document Version: 2.1.0*
*Last Verified: May 14, 2026 (Final Run)*
