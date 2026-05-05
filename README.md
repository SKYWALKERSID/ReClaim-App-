# ReClaim: ReClaim Enforcement Suite

**ReClaim** is a high-performance ReClaim platform designed to reclaim focus through strict native enforcement and beautiful, distraction-free design.

## 🚀 Vision
Breaking the dopamine loop by moving beyond passive tracking to active, native-level focus enforcement.

## 📱 Project Architecture

1. **`apps/mobile` (The Premium Experience)**
   - **Recommended Demo Path**: Our flagship Flutter implementation.
   - **Tech**: Flutter (Dart) with a Native Kotlin bridge.
   - **Features**: Immersive glassmorphism UI, real-time usage insights, and "Hard Mode" focus sessions.
   
2. **`apps/android-native` (The Core Engine)**
   - Technical foundation providing the underlying Accessibility and Enforcement APIs.
   - Directly interfaces with Android's `UsageStatsManager` and `WindowManager`.

3. **`services/api` (The Intelligence Layer)**
   - **Tech**: Node.js + TypeScript + PostgreSQL.
   - **Role**: Secure data synchronization, cross-device trends, and rewards logic.

---

## ✨ Key Features
- **Native Enforcement**: Unlike standard apps, ReClaim uses Android Accessibility hooks to physically block distracting apps during focus sessions.
- **Usage Insights**: Deep-dive analytics into digital habits with local-first privacy.
- **Gamified Discipline**: Earn Zen Points and badges for maintaining focus streaks.
- **Premium Design**: Calming, high-end aesthetics designed to reduce digital anxiety.

## 🛠 Tech Stack
- **Frontend**: Flutter 3.x (Glassmorphism, Particle Systems)
- **Native**: Kotlin (Accessibility Service, Foreground Services)
- **Backend**: Express.js (TypeScript), PostgreSQL, JWT Auth
- **Infrastructure**: Docker-ready for easy deployment

---

## 📂 Documentation
- [Folder Architecture](docs/FOLDER_GUIDE.md)
- [API Specification](docs/API_DESIGN.md)
- [Database Schema](docs/DB_SCHEMA.md)
- [Core Algorithms](docs/ALGORITHMS.md)
- [Judges Guide](HACKATHON_STUDY_GUIDE.md)

---

## 🏆 Submission Notes
This monorepo represents a production-hardened version of the ReClaim suite. All native-to-flutter bridges have been verified for stability, and the enforcement engine is optimized for high-responsiveness and low battery consumption.


