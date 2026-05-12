# ReClaim™ Behavioral Algorithms

ReClaim's unique value proposition is its ability to quantify and intervene in digital behavior using data-driven algorithms.

---

## 1. Cognitive Drift Engine™ (CDE)

The CDE quantifies the state of a user's attention during a session.

### Fragmentation Index ($\mathcal{F}$)
Measures how "scattered" the user's attention is based on rapid app-switching.

$$\mathcal{F} = \frac{\sum_{i=1}^{n} \text{Weight}(P_i)}{T_{\text{total}}}$$

- **High Fragmentation ($\mathcal{F} > 0.5$)**: Triggers the **Hard Friction** layer.
- **Low Fragmentation ($\mathcal{F} < 0.2$)**: Indicates a "Flow State," rewards bonus points.

### Drift Score ($D$)
A real-time metric (0.0 to 1.0) based on interaction velocity and feed exposure time.

---

## 2. Dynamic Friction Layer

Instead of static blocks, ReClaim uses **Variable Latency Response ($L$)**.

$$L = L_{\text{base}} \times (1 + \alpha D)$$

As the user's **Drift Score** ($D$) increases (indicating fatigue or mindless scrolling), the countdown timer before opening a restricted app increases automatically. This forces a longer "Reflection Gap."

---

## 3. Pattern Recognition & Risk Scoring

The **PatternEngine** analyzes historical clusters to assign a **Distraction Risk Score**.

### Risk Calculation Components:
1. **App Switches Per Hour**: High frequency indicates "digital restlessness."
2. **Late-Night Usage**: Weighted heavily (0.9 multiplier) due to its impact on sleep and next-day willpower.
3. **Continuous Session Length**: Flags sessions >30m in "Red" category apps.

### Tomorrow's Prediction:
The system predicts the user's focus quality for the next day based on today's performance. High late-night usage triggers a "Willpower Fatigue" warning for the next morning.

---

## 4. The Discipline Quotient (DQ)

DQ is a rolling metric of a user's digital autonomy.

### Reward Calculation:
- **Base Points**: 50 per compliant day.
- **Bonus**: 10 per completed 25m Focus Session.
- **Multiplier**: Streak bonus grows by 2.5% per consecutive day (capped at 50%).
- **Deduction**: Overrides and Late-night usage deduct points directly from the DQ.

---

## 5. Intent Verification

When a user attempts to open a "Red" app, the **Intent Recognition** algorithm (v0.7) evaluates the context.
- If the user has a **High Drift Score**, the system asks for a **Reflection Prompt** ("Is this intentional?").
- If the user is in **Deep Focus Mode**, the **SafeCode™** barrier is activated, requiring a 4-digit security code stored in the hardware vault.

---
*Technical Specification: ReClaim Intelligence Suite v2.1*
*Last Verified: May 11, 2026*
