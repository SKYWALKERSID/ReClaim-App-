# ReClaim Enforcement Suite

**ReClaim** is a focus-enforcement platform built to move beyond passive screen-time tracking into real-time blocking, local analytics, and deliberate habit change.

## Vision
Break the dopamine loop by combining native Android enforcement with a calm, premium interface.

## Project Architecture

1. **`apps/mobile`**
   The current ReClaim Flutter app with the native Kotlin enforcement bridge.
2. **`apps/android-native`**
   A legacy Kotlin-only prototype kept as a secondary reference path.
3. **`services/api`**
   The Node.js and TypeScript backend for auth, analytics, devices, and rewards.

## Key Features
- **Native enforcement**: Blocks distracting apps through Android accessibility and overlay services.
- **Usage insights**: Tracks daily and weekly behavior with local-first device data.
- **Rewards and streaks**: Adds progression and accountability on top of strict limits.
- **Premium UI**: Keeps the main product surface clean and intentional instead of utilitarian.

## Tech Stack
- **Frontend**: Flutter
- **Native Android**: Kotlin
- **Backend**: Express.js, TypeScript, PostgreSQL
- **Infrastructure**: Docker-ready API service

## Documentation
- [Folder Architecture](docs/FOLDER_GUIDE.md)
- [API Specification](docs/API_DESIGN.md)
- [Database Schema](docs/DB_SCHEMA.md)
- [Core Algorithms](docs/ALGORITHMS.md)
- [Judges Guide](HACKATHON_STUDY_GUIDE.md)

## Submission Notes
This monorepo contains the current ReClaim mobile app, the supporting API, and the Android enforcement layer that powers the live blocking experience.
