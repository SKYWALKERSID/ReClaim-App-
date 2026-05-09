# ReClaim
> Reclaim your focus.

## ReClaim: Stop scrolling, start living.

Most "focus apps" are just glorified timers that are way too easy to ignore. I built ReClaim because I was tired of the endless scroll and needed a tool that actually had teeth. 

ReClaim doesn't just ask you to be productive; it forces a pause. Using Android’s native accessibility services, it creates a "Friction Layer"—intentional delays that break the dopamine loop of opening social media. If you're in a deep focus session, it uses "Hard Blocking" to make distracting apps virtually inaccessible, so you can't just cheat your way back to a feed.

What makes it different is the **Cognitive Drift Engine™**. Instead of just counting minutes, it tracks how fragmented your attention becomes throughout the day. The **Brain Mirror™** dashboard gives you a live look at your mental state, showing you exactly when your brain starts to "drift" so you can take a break before you burn out.

## Key Features
*   **Real Blocking:** Native-level enforcement that you can't just swipe away.
*   **The Friction Layer:** Adds intentional friction to distracting apps to break the habit of "mindless opening."
*   **Drift Tracking:** Visualizes your mental fragmentation and "craving windows."
*   **Privacy First:** Everything is handled with high-security RS256 signing and encrypted local storage.

## Tech Stack
- **Frontend**: Flutter + Android Native (Kotlin)
- **Backend**: Node.js + TypeScript + Express
- **Database**: PostgreSQL + Firebase Auth
- **Infrastructure**: Docker + Docker Compose

## Security Architecture
- **RS256 Asymmetric JWT Signing**: High-security token management.
- **Keystore-backed Encrypted Storage**: Secure on-device data persistence.
- **Refresh Token Rotation**: Mitigating session theft risks.
- **Full Login Audit Trail**: Comprehensive tracking of access events.
- **FLAG_SECURE**: Protection against screen scraping and screenshots.

## Setup
1. Clone the repository.
2. Run `docker-compose up -d` in the root directory.
3. Configure `.env` in `services/api/` with your credentials.
4. Open `apps/mobile` in Android Studio/VS Code and run on an Android device.

---
Built for people who are serious about getting their time back.
