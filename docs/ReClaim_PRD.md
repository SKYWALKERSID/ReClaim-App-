---
title: ReClaim™ Product Requirements Document
version: 1.0
status: Pre-Release
date: 2026-05-12
classification: Confidential
---

# 1. COVER PAGE & DOCUMENT CONTROL

**Product Name:** ReClaim™  
**Document Type:** Product Requirements Document (PRD)  
**Version:** 1.0  
**Status:** Pre-Release  
**Date:** 2026-05-12  
**Author:** Antigravity (Senior Product Manager)  
**Reviewer:** [NEEDS INPUT: Engineering Lead / Stakeholder]

### Revision History
| Version | Date | Author | Changes |
| :--- | :--- | :--- | :--- |
| 1.0 | 2026-05-12 | Antigravity | Initial PRD for v1.0 Pre-Launch / Pre-Release stage. |

---

# 2. EXECUTIVE SUMMARY

ReClaim™ is an advanced behavioral enforcement and data intelligence platform designed to transition users from passive digital consumption to active attention governance. Unlike standard screen-time trackers that merely report usage, ReClaim™ intervenes at the hardware level using proprietary cognitive scoring to break recursive habit loops.

The platform solves the "Attention Fragmentation" crisis—where users lose the ability to sustain deep focus due to high-frequency app-switching and impulsive digital "drifting." ReClaim™ is built for high-performance individuals, knowledge workers, and parents who require non-bypassable behavioral safeguards.

**Key Proprietary Differentiators:**
- **Cognitive Drift Engine™ (CDE):** Real-time scoring of attention fragmentation using variance-based pattern analysis.
- **Variable Latency Friction:** Dynamic injection of app-launch delays that scale based on the user's current Drift Score.
- **Brain Mirror™:** A high-fidelity behavioral data visualization layer that turns raw usage logs into a reflection of cognitive state.

**Current Stage:** Pre-Release / Near Launch. Core execution (Android/Flutter) and intelligence (Node.js/PostgreSQL) planes are functional and undergoing security hardening.

---

# 3. PROBLEM STATEMENT

### The Attention Crisis
Modern digital interfaces are engineered for "infinite scroll" and high-dopamine feedback loops, leading to a state of **Cognitive Drift**. Users experience a "fragmented attention" syndrome where they switch apps impulsively, often without conscious intent.

### Pain Points
- **Fragmented Attention:** Frequent switching between social media and productive apps destroys deep work capability.
- **Behavioral Blindness:** Users are unaware of the *patterns* of their drift, seeing only time-spent metrics which are trailing indicators.
- **Bypassable Constraints:** Standard blockers are easily disabled in moments of low willpower.

### Market Gap
Existing solutions like Apple Screen Time and Google Digital Wellbeing are "passive reporters." They provide data but fail to enforce change. Gamified apps like Forest are entirely voluntary. ReClaim™ fills the gap between **Motivation** and **Enforcement** by providing a hardware-backed, score-driven intervention loop.

---

# 3.5 COMPETITIVE LANDSCAPE & MARKET GAP ANALYSIS

## 3.5.1 EXISTING SOLUTIONS IN THE MARKET

| Competitor | Category | Core Approach | Platforms | Target User | Pricing Model |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Apple Screen Time** | OS Native | Passive limits & reporting | iOS/macOS | General users | Free (Native) |
| **Google Wellbeing** | OS Native | Usage charts & grayscale | Android | General users | Free (Native) |
| **Opal** | Focus/Blocker | AI sessions & AppShield | iOS | High-performers | Subscription |
| **Forest** | Gamification | Virtual tree growing | iOS/Android | Students | One-time/Freemium |
| **Freedom** | Static Blocker | Scheduled cross-device blocks | All | Writers/Pros | Subscription |
| **RescueTime** | Analytics | Automatic time categorization | Desktop/Mobile | Freelancers | Subscription |
| **One Sec** | Friction | Deep breath before app launch | iOS/Android | Impulse-shoppers | Freemium |

### Key Competitor Analysis

**Opal (iOS)**
- **Strength:** Best-in-class iOS UI and "Deep Focus" UX.
- **Limitation:** iOS only. Relies on VPN/Configuration profiles which can be flaky. No cognitive scoring engine.
- **Gap:** Lacks the Android-level deep system hooks (Accessibility Services) that ReClaim™ leverages for non-bypassable enforcement.

**Freedom**
- **Strength:** Excellent cross-platform sync (Windows/Mac/iOS/Android).
- **Limitation:** "Dumb" blocking. Blocks are static and manual. It doesn't know *why* you are being blocked.
- **Gap:** No adaptive friction. Freedom is a wall; ReClaim™ is a variable-viscosity barrier.

**RescueTime**
- **Strength:** Massive historical data and automatic categorization of thousands of apps/sites.
- **Limitation:** Zero enforcement. It tells you that you failed, but it doesn't stop you from failing in real-time.
- **Gap:** No real-time friction engine or hardware-level intervention.

---

## 3.5.2 FEATURE COMPARISON MATRIX

| Feature | ReClaim™ | Opal | Forest | Freedom | RescueTime | Apple ST |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Behavioral Enforcement** | ✅ Full | 🔶 Partial | ❌ None | ✅ Full | ❌ None | 🔶 Partial |
| **Variable Latency Friction**| ✅ Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Cognitive Drift Scoring** | ✅ Full | ❌ None | ❌ None | ❌ None | 🔶 Partial | ❌ None |
| **Hardware-Backed Security** | ✅ Full | ❌ None | ❌ None | ❌ None | ❌ None | 🔒 OS Only |
| **Android Deep Hooks** | ✅ Full | ❌ None | 🔶 Partial | 🔶 Partial | 🔶 Partial | 🔒 N/A |
| **Non-Bypassable Mode** | ✅ Full | 🔶 Partial | ❌ None | ✅ Full | ❌ None | 🔶 Partial |
| **Developer API** | ✅ Full | ❌ None | ❌ None | ❌ None | ✅ Full | ❌ None |

---

## 3.5.3 COMPETITOR PROFILE CARDS

**COMPETITOR: One Sec**
- **Core Mechanism:** Triggers a 10-second breathing exercise before opening a distracting app.
- **Strength:** High immediate friction that breaks the "muscle memory" of opening an app.
- **Gap vs ReClaim™:** The friction is static (always 10s). It doesn't scale based on total daily drift. It has no backend intelligence or social accountability plane.

---

## 3.5.4 THE GAP ANALYSIS

**GAP-001: Passive tracking vs active behavioral enforcement**
Existing tools report history. ReClaim™ changes the future by injecting friction *before* the habit loop completes.

**GAP-002: Time-based limits vs cognitive pattern analysis**
A user might spend 2 hours on YouTube watching tutorials (Low Drift) or 2 hours switching every 30 seconds between 5 apps (High Drift). Competitors treat these the same; ReClaim™ distinguishes them.

**GAP-007: The Tracking-to-Enforcement Loop**
No competitor closes the loop: **TRACK → SCORE → ENFORCE → REFLECT**.
- RescueTime tracks.
- Freedom enforces.
- ReClaim™ does both, using the **CDE Score** to modulate the **Friction Engine**.

---

## 3.5.5 RECLAIM™ COMPETITIVE ADVANTAGES

- **ADVANTAGE-001: Cognitive Drift Engine™:** A proprietary math layer that quantifies attention fragmentation index.
- **ADVANTAGE-002: Keystore-Backed SafeCode:** Emergency overrides use hardware-backed security, preventing local uninstallation or data tampering.
- **ADVANTAGE-003: Variable Latency:** Friction that feels "alive"—it gets harder to enter apps as your focus decays.

---

## 3.5.6 POSITIONING STATEMENTS

1. **For the Self-Improver:** For high-performers who find themselves "drifting" into mindless scrolling, ReClaim™ is a behavioral governance platform that restores deep focus. Unlike Opal, ReClaim™ uses hardware-backed friction and cognitive scoring to adapt to your mental state.
2. **For the Parent:** For parents who want to ensure their children develop attention discipline, ReClaim™ is an enforcement engine that prevents app-hopping. Unlike Family Link, it teaches the *value* of focus via the Brain Mirror™.
3. **For the Enterprise:** ReClaim™ is a Digital Wellness API that allows organizations to measure and improve the "Focus Health" of their workforce with hardware-level security and privacy-first scoring.

---

# 4. PRODUCT VISION & GOALS

## 4.1 Vision Statement
To become the world's standard behavioral operating system for the attention economy.

## 4.2 Product Goals (Pre-Launch)
| Goal | Metric | Target | Timeframe |
| :--- | :--- | :--- | :--- |
| **System Reliability** | Enforcement Success Rate | 99.9% | Launch |
| **Drift Accuracy** | CDE Pattern Match | >90% | Launch |
| **Security** | SafeCode Integrity | Zero known bypasses | Launch |

## 4.3 Non-Goals
- **Screen Time Tracking for iOS:** v1.0 is Android-focused for deep enforcement.
- **Web Content Blocking:** v1.0 focuses on App-level behavior.

---

# 5. TARGET USERS & PERSONAS

**1. The Self-Improver (Ethan, 28, Software Engineer)**
- **Motivation:** Regain 2 hours of deep work daily.
- **Pain Point:** Opens Twitter "accidentally" every time a compile takes more than 10 seconds.
- **ReClaim™ Use:** Uses Variable Latency Friction to make "quick checks" annoying.

**2. The Integration Partner (Sarah, 34, CTO of Wellness Startup)**
- **Motivation:** Needs behavioral data to power a coaching app.
- **ReClaim™ Use:** Integrates with the Developer API to pull user Drift Scores.

---

# 6. USER STORIES & ACCEPTANCE CRITERIA

### 6.3 Cognitive Drift Engine™
**Story:** As a user, I want my behavior to be scored so I can see my focus health objectively.  
**Acceptance Criteria:**  
- **GIVEN** a user has switched apps more than 5 times in 2 minutes  
- **WHEN** the CDE processes the log  
- **THEN** the Fragmentation Index must increase by at least 15 points.

### 6.4 Variable Latency Friction
**Story:** As a user, I want the app to be harder to open when I am drifting so I am discouraged from impulsive use.  
**Acceptance Criteria:**  
- **GIVEN** a Drift Score > 70  
- **WHEN** the user attempts to launch a restricted app  
- **THEN** the Android native layer must inject a 5,000ms delay before the app UI is visible.

---

# 7. FEATURE LIST & PRIORITISATION

| Feature | Description | Priority | MVP | Phase |
| :--- | :--- | :--- | :--- | :--- |
| **Accessibility Enforcer** | Native Android blocking hooks | P0 | Yes | MVP |
| **CDE Score Calculation** | Backend logic for drift/fragmentation | P0 | Yes | MVP |
| **Brain Mirror™ Dash** | Flutter visualization of usage | P1 | Yes | MVP |
| **Variable Latency** | Score-driven app launch delays | P0 | Yes | MVP |
| **Social Buddies** | Shared accountability streaks | P2 | No | v1.1 |

---

# 8. FUNCTIONAL REQUIREMENTS

**FR-CDE-001: Pattern Ingestion**
- **Input:** JSON batch of usage logs from mobile device.
- **Processing:** Calculate variance in session duration and frequency of app-to-app transitions.
- **Output:** Updated `drift_score` and `fragmentation_index` in PostgreSQL.

**FR-VLF-002: Dynamic Latency Calculation**
- **Processing:** `latency_ms = base_config_ms * (1 + current_drift_score/100)`.
- **Constraint:** Maximum latency cap of 15,000ms.

---

# 9. NON-FUNCTIONAL REQUIREMENTS

- **9.1 Performance:** CDE scoring must complete within 500ms of log ingestion.
- **9.2 Security:** All JWTs must use RS256. SafeCode overrides must be rate-limited (max 3 attempts/hour).
- **9.3 Reliability:** Offline enforcement must work using locally cached `FocusPolicy`.

---

# 10. USER FLOWS

**10.2 App Launch with Latency Friction**
1. User taps "Instagram" icon.
2. Android Accessibility Service intercepts `TYPE_WINDOW_STATE_CHANGED`.
3. Service checks `FocusPolicyStore` (Local).
4. Service identifies "Instagram" as restricted and calculates current latency.
5. Service displays "Attention Friction" overlay with a countdown timer.
6. User must wait for timer to expire before "Enter" button enables.

---

# 11. OUT OF SCOPE (v1.0)

| Feature | Reason | Target |
| :--- | :--- | :--- |
| **iOS Enforcement** | Platform sandbox restrictions | v2.0 |
| **Video Analytics** | High compute/privacy cost | v2.0 |

---

# 12. SUCCESS METRICS & KPIs

| Metric | Target | Method |
| :--- | :--- | :--- |
| **D7 Retention** | >45% | Firebase Analytics |
| **Drift Reduction** | -20% avg/user | CDE Score Trend |
| **SafeCode Use** | <5% of blocks | Backend Audit Logs |

---

# 13. RISKS & MITIGATIONS

- **Risk:** Google Play Store banning Accessibility Services for blocking.  
- **Mitigation:** Use "Accessibility for Behavioral Health" category and provide clear user consent + opt-out.
- **Risk:** Firebase Auth latency affecting login.  
- **Mitigation:** Local session caching with 24h TTL.

---

# 14. APPENDICES

**A. Glossary**
- **Cognitive Drift:** The state of un-directed, fragmented attention.
- **SafeCode:** A 6-digit biometric-backed emergency override.

**B. Related Documents**
- [Technical Reference Guide](generate_complete_reference.js)
- [Backend API Spec](API.md)
