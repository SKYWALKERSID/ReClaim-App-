---
title: ReClaim™ Technical Requirements Document
version: 1.0
status: Pre-Release
date: 2026-05-12
classification: Confidential
---

# 1. COVER PAGE & DOCUMENT CONTROL

**Product Name:** ReClaim™  
**Document Type:** Technical Requirements Document (TRD)  
**Version:** 1.0  
**Status:** Pre-Release  
**Date:** 2026-05-12  
**Author:** Antigravity (Senior Architect)  
**Reviewer:** [NEEDS INPUT: CTO / Lead Architect]

### Revision History
| Version | Date | Author | Changes |
| :--- | :--- | :--- | :--- |
| 1.0 | 2026-05-12 | Antigravity | Initial TRD based on v1.0 codebase audit. |

**Related Documents:**
- [Product Requirements Document (PRD)](ReClaim_PRD.md)
- [Codebase Reference Guide](generate_complete_reference.js)

---

# 2. TECHNICAL OVERVIEW

ReClaim™ is an attention-governance system architected across two distinct planes: the **Execution Plane** (Mobile) and the **Intelligence Plane** (Backend). The system utilizes hardware-level hooks on Android to enforce behavioral policies determined by high-latency cognitive analysis in the backend.

### Technical Decisions Matrix
| Decision | Chosen Approach | Alternatives | Rationale |
| :--- | :--- | :--- | :--- |
| **Mobile Framework** | Flutter | React Native | Superior bridge performance for Accessibility Service interactions. |
| **Enforcement** | Accessibility Services | MDM / VPN | Accessibility Services provide granular per-package lifecycle events without network overhead. |
| **Auth** | RS256 JWT | HS256 (Symmetric) | Allows partners to verify identity using only public keys, improving security posture. |
| **State Mgmt** | Riverpod | Bloc / Provider | Compile-time safety and better handling of asynchronous dependency injection. |

---

# 3. SYSTEM ARCHITECTURE

## 3.1 High-Level Architecture
| Component | Technology | Responsibility |
| :--- | :--- | :--- |
| **Execution Plane** | Flutter/Kotlin | Real-time event interception, friction injection, UI rendering. |
| **Intelligence Plane** | Node.js/TS | Cognitive drift scoring, policy evaluation, partner API gateway. |
| **Persistence** | PostgreSQL | Relational storage for high-frequency usage logs and scores. |
| **Identity** | Firebase Auth | User authentication, session management, OAuth provider sync. |

## 3.2 Mobile Architecture (Execution Plane)
- **Native Layer (Kotlin):** The `FocusEnforcer` class extends `AccessibilityService` to listen for `TYPE_WINDOW_STATE_CHANGED`. It communicates with the Flutter layer via `MethodChannel`.
- **Flutter Layer:** Uses Riverpod for managing the `PolicyProvider` and `AnalyticsProvider`. Communicates with the backend via a DIO-based `BackendService`.
- **Offline Resilience:** The `FocusPolicyStore` (Kotlin) caches enforcement rules locally in `EncryptedSharedPreferences` to ensure blocking works without 4G/Wi-Fi.

## 3.3 Backend Architecture (Intelligence Plane)
- **Middleware Layer:** Standardized Zod validation (`validate.middleware.ts`) and JWT auth verification.
- **Service Layer:** `PatternEngine` handles the heavy math for CDE; `PolicyService` evaluates commitment compliance.

---

# 4. API SPECIFICATION

## 4.1 Authentication
**Flow:** Client authenticates with Firebase → Receives Firebase ID Token → Exchanges for ReClaim RS256 JWT via `/v1/auth/login`.

**JWT Claims:**
| Claim | Type | Description |
| :--- | :--- | :--- |
| `userId` | UUID | Unique internal identifier. |
| `role` | String | `user`, `admin`, or `partner`. |
| `exp` | Number | 24-hour expiry (standard). |

## 4.2 API Reference (Summary)

**POST /analytics/log**
- **Description:** Ingests a batch of usage events.
- **Request Body (Zod):** `z.object({ events: z.array(usageEventSchema) })`
- **Response 200:** `{ success: true, processedCount: number }`

**GET /analytics/scores**
- **Description:** Returns current Drift and Fragmentation scores.
- **Response 200:** `{ userId, driftScore, fragmentationIndex, timestamp }`

**POST /policies**
- **Description:** Creates a new app-blocking policy/commitment.
- **Request Body (Zod):** `z.object({ packageName: z.string(), delayMs: z.number() })`

---

# 5. DATABASE SCHEMA

### Table: usage_logs
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | Primary Key | Unique log ID. |
| `user_id` | UUID | Foreign Key | Owner of the event. |
| `package_name` | String | Not Null | The app that was launched. |
| `timestamp` | TIMESTAMPTZ | Not Null | Exact time of event. |

### Table: drift_scores
| Column | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | UUID | Primary Key | One entry per user. |
| `drift_score` | FLOAT | 0.0 | Calculated attention variance. |
| `updated_at` | TIMESTAMPTZ | NOW() | Last CDE run. |

---

# 6. PROPRIETARY ENGINE SPECIFICATIONS

## 6.1 Cognitive Drift Engine™ (CDE)

**Fragmentation Index (FI):**
$$FI = (\frac{UniqueApps}{TotalEvents}) \times (\frac{Transitions}{WindowLength})$$
- **Goal:** Quantifies app-hopping behavior. High FI indicates low attention span.

**Drift Score (DS):**
$$DS = \sigma(SessionStartTimes) + \alpha(FI)$$
- **$\sigma$:** Standard deviation of time-of-day app opens (measures impulsivity).
- **$\alpha$:** Weighting factor (default 0.65).

## 6.2 Variable Latency Friction Engine
- **Logic:** `latency = base_delay * (1 + DS/100)`.
- **Enforcement:** Kotlin `AccessibilityService` injects a full-screen overlay with a non-cancellable timer before allowing package focus.

---

# 7. SECURITY ARCHITECTURE

- **RS256 JWT:** Private key stored in `services/api/.env` (and secret manager in production). Public key shared with partner APIs.
- **Android Keystore:** `SafeCode` hashes are generated and verified inside the TEE (Trusted Execution Environment), making them resistant to brute-force or memory inspection.
- **Rate Limiting:** `express-rate-limit` applied to `/auth` (10 requests/15min) and `/analytics` (100 batches/hour).

---

# 11. TECHNICAL CONSTRAINTS & DECISIONS

**ADR-004: Android Accessibility Services**
- **Status:** Accepted.
- **Context:** Need to intercept app launches without root access.
- **Decision:** Implement `AccessibilityService`.
- **Consequence:** Requires manual user permission grant; high battery overhead if handlers are blocking.

---

# 13. APPENDICES

**A. Dependency Versions**
- `flutter`: 3.22.0
- `express`: 4.19.2
- `zod`: 3.23.8
- `typescript`: 5.4.5
- `pg`: 8.11.5

**B. Technical Glossary**
- **Execution Plane:** The local mobile environment where policies are enforced.
- **Intelligence Plane:** The cloud environment where behavioral math is computed.
