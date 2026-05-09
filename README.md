# ReClaim
> Reclaim your focus.

## What It Does
ReClaim is a next-generation focus and behavioral intelligence platform. It uses native Android accessibility services to provide real-time friction and blocking for distracting apps, while tracking cognitive drift and craving patterns to help users build long-term digital wellness.

## Tech Stack
- **Frontend**: Flutter + Android Native (Kotlin)
- **Backend**: Node.js + TypeScript + Express
- **Database**: PostgreSQL + Firebase Auth
- **Infrastructure**: Docker + Docker Compose

## Security Architecture
- **RS256 Asymmetric JWT Signing**: High-security token management.
- **Keystore-backed Encrypted Storage**: Secure on-device data persistence.
- **Refresh Token Rotation**: mitagating session theft risks.
- **Full Login Audit Trail**: Comprehensive tracking of access events.
- **FLAG_SECURE**: Protection against screen scraping and screenshots.

## Setup
1. Clone the repository.
2. Run `docker-compose up -d` in the root directory.
3. Configure `.env` in `services/api/` with your credentials.
4. Open `apps/mobile` in Android Studio/VS Code and run on an Android device.

## Key Features
- **Cognitive Drift Engine™**: Tracks behavioral fragmentation.
- **Smart Friction Layer**: Adds intentional delays to distracting apps.
- **Brain Mirror™ Dashboard**: Real-time visualization of cognitive performance.
- **Hard Block Mode**: Native-level app blocking that can't be easily bypassed.
