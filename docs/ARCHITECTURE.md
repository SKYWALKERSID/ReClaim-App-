# Architecture Overview - ReClaim

## Technology Stack
- **Frontend**: Flutter + Android Native (Kotlin)
- **Backend**: Node.js + TypeScript + Express
- **Database**: PostgreSQL (Prisma ORM) + Firebase Auth
- **Infrastructure**: Docker + Docker Compose

## Component Breakdown
- **apps/mobile**: Flutter application containing the UI and business logic.
- **apps/mobile/android**: Native Kotlin layer for accessibility services, blocking overlays, and behavioral engines.
- **services/api**: Node.js backend providing API services, authentication, and notification management.

## Data Flow
1. User interacts with the Flutter UI.
2. Flutter communicates with the Native Kotlin layer via MethodChannels.
3. Native layer manages low-level Android services (Accessibility, WorkManager).
4. Backend services handle synchronization, notifications, and long-term analytics.
