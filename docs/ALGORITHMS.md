# ReClaim™ Behavioral Algorithms

ReClaim utilizes proprietary algorithms to model attention fragmentation and enforce behavioral discipline.

---

## 1. Cognitive Drift Engine™ (CDE)

The CDE quantifies the "decay" of human attention during digital interaction.

### The Fragmentation Index ($\mathcal{F}$)
The Fragmentation Index measures the volatility of context switching. 

$$\mathcal{F} = \frac{\sum_{i=1}^{n} \Delta P_i}{T_{total}}$$

Where:
- $n$ is the number of app transitions.
- $\Delta P_i$ is a weight assigned to the switch (higher for switching to "Red" category apps).
- $T_{total}$ is the total interaction time.

**Thresholds:**
- **$\mathcal{F} < 0.2$**: Focused State.
- **$0.2 \le \mathcal{F} < 0.5$**: Mild Drift.
- **$\mathcal{F} \ge 0.5$**: High Fragmentation (Triggers Hard Friction).

---

## 2. The Friction Layer Algorithm

The Friction Layer breaks the automaticity of app-opening habits.

### Variable Latency Response ($L$)
The delay injected before an app opens is not static; it scales based on the user's current Drift Score ($D$).

$$L = L_{base} \times (1 + \alpha D)$$

Where:
- $L_{base}$ is the user's configured minimum friction (e.g., 5s).
- $\alpha$ is the sensitivity coefficient.
- $D$ is the current Drift Score (0.0 to 1.0).

**Logic Flow:**
1. Package transition detected via `AccessibilityService`.
2. Check if package is in `Blacklist`.
3. If True, calculate $L$.
4. Launch `FrictionOverlay` and hold for $L$ seconds.
5. Surface a **Reflection Prompt** (e.g., "Is this intentional?").
6. On confirmation, permit intent; otherwise, terminate.

---

## 3. Craving Window Prediction

ReClaim analyzes historical usage clusters to predict future lapses.

**Cluster Analysis:**
1. Group `UsageEvents` by hour of day over a 7-day rolling window.
2. Calculate the standard deviation of starting times.
3. If a cluster has high density ($N > 3$) and high average $D$, mark as a **High-Risk Window**.
4. Trigger a **Pre-emptive Nudge** 15 minutes before the predicted window start.

---

## 4. Reward System (Discipline Points)

Points are awarded based on adherence to the "Discipline Quotient."

**Daily Points ($P$):**
$$P = 50_{base} + (FocusSessions \times 10) + (StreakDays \times 2.5)$$
*Deductions apply for late-night usage or excessive overrides.*

---
*Technical Specification: ReClaim Intelligence Suite*
