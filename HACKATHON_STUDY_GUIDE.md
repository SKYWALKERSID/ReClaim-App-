# HACKATHON PRESENTATION GUIDE: ReClaim (ReClaim)

## 1. EXECUTIVE SUMMARY
**ReClaim** is a cross-platform mobile application designed to break the "Dopamine Loop" of digital addiction. Unlike traditional screen-time trackers that only provide passive data, ReClaim uses **Native Android Enforcement** to actively reclaim your focus.

---

## 2. THE PROBLEM (THE "WHY")
Digital addiction is engineered. Apps use "variable reward" schedules to keep users scrolling. 
*   **The Statistic**: The average person checks their phone 58 times a day.
*   **The Gap**: Current solutions (Apple/Google Screen Time) are too easy to bypass (the "Ignore for today" button).

---

## 3. THE SOLUTION (THE "HOW")
ReClaim stands out by being **Enforcement-First**. It provides a "Hard Mode" for focus that is technically difficult to bypass, combined with a premium, calming UI that makes ReClaim feel like a luxury, not a chore.

---

## 4. TECH STACK & RATIONALE (The "Judge" Questions)

### **Frontend: Flutter (Google)**
*   **Why?**: We chose Flutter for its high-performance rendering engine (Skia/Impeller) which allowed us to implement **Glassmorphism** and complex **Particle Systems**. In a hackathon, design is 50% of the battle.
*   **Key Library**: `MethodChannel` for bridging Flutter's UI with Android's system-level APIs.

### **Native Layer: Android (Kotlin)**
*   **Why?**: Flutter alone cannot block other apps. We built a native **Accessibility Service** and used **UsageStatsManager** to hook into the Android OS core.
*   **The Innovation**: We implemented a "Background Enforcement Loop" that runs as a Foreground Service to ensure the OS doesn't kill our focus engine.

### **Backend: Node.js, TypeScript & Express**
*   **Why?**: We used TypeScript for strict type safety across our API.
*   **Database**: PostgreSQL for relational data (users, habits, streaks).
*   **Security**: JWT (JSON Web Tokens) for stateless, secure authentication.

---

## 5. BEHIND THE SCENES: HOW IT WORKS

### **A. The Accessibility Engine**
When you open a "Blacklisted" app (like Instagram), our Android **AccessibilityService** detects a `TYPE_WINDOW_STATE_CHANGED` event. 
1.  It checks the package name against our **EnforcementManager**.
2.  If it's blocked, it immediately launches a **Foreground Overlay Window** (`SYSTEM_ALERT_WINDOW`).
3.  This overlay sits *above* the blocked app, effectively preventing any interaction until the focus session ends.

### **B. The Usage Pipeline**
We use the **UsageStatsManager** to query the OS for precise usage down to the millisecond. This data is processed locally to protect privacy and then synced to our backend for long-term "Focus Trends."

---

## 6. UNIQUE VALUE PROPOSITION (UVP)
*   **Un-bypassable Focus**: Our use of Native Accessibility hooks makes it significantly harder to "cheat" than standard apps.
*   **Gamified Discipline**: We use a custom **Gamification Engine** that awards "Zen Points" and badges for streaks, turning self-control into a game.
*   **Premium Aesthetics**: We moved away from "utilitarian" designs to a high-end, immersive UI to reduce the "scarcity mindset" of quitting social media.

---

## 7. POTENTIAL JUDGE CROSS-QUESTIONS

**Q1: How do you handle privacy?**
> "We follow a Privacy-by-Design approach. Sensitive usage data is processed in the Native Kotlin layer. Only aggregated 'Zen Scores' are synced to the cloud, ensuring your specific app browsing history stays on your device."

**Q2: What happens if the app crashes? Does it unblock everything?**
> "We've implemented a **Watchdog Pattern**. Our Enforcement Service is a 'Foreground Service' with a high priority. If it crashes, the Android OS automatically restarts it within seconds. We also use asynchronous state refreshing to ensure the UI stays responsive while the 'Enforcement Engine' works in the background."

**Q3: How does it impact battery life?**
> "Great question. We optimized the enforcement loop by using **Event-Driven triggers** instead of 'Polling.' We only check the state when the user switches apps, which results in near-zero CPU idle usage."

---

## 8. FUTURE ROADMAP
*   **AI Focus Assistant**: Using LLMs to analyze usage patterns and suggest "Digital Detox" schedules.
*   **Group Focus**: Syncing focus sessions with friends for accountability.
*   **Cross-Device Sync**: Blocking your browser on Chrome while your phone is in Zen Mode.

