# ReClaim™ System Architecture Flowchart

This diagram illustrates the multi-plane architecture of the ReClaim platform, highlighting the interaction between the **Execution Plane** (Native Android), the **Presentation Plane** (Flutter), and the **Intelligence Plane** (TypeScript Backend).

```mermaid
graph TB
    %% Definitions
    subgraph "Mobile Client (Android Device)"
        subgraph "Presentation Plane (Flutter UI)"
            UI[Brain Mirror™ Dashboard]
            SEC_S[Sensitive Screens - FLAG_SECURE]
            SET[Policy Configuration]
        end

        subgraph "Bridge Layer"
            MC[MethodChannel Bridge]
        end

        subgraph "Execution Plane (Kotlin Native)"
            ACC[Accessibility Service]
            CDE[Cognitive Drift Engine™]
            INT[Intent Interception]
            OVR[Overlay Rendering]
            FRI[Friction Layer]
        end

        subgraph "Secure Storage (Hardware-Backed)"
            TEE[Android Trusted Execution Environment]
            KEY[Hardware Keystore]
            ESP[Encrypted Shared Prefs - AES-256-GCM]
        end
    end

    subgraph "Network & Security"
        TLS[TLS 1.3 Encryption]
        JWT[RS256 JWT Authentication]
    end

    subgraph "Intelligence Plane (Node.js Backend)"
        subgraph "API Gateway (Express.js)"
            HLM[Helmet.js - HSTS/CSP]
            RL[Rate Limiting]
            ZOD[Zod Schema Validation]
            AUTH[Auth Handler]
        end

        subgraph "Core Services"
            AS[Analytics Service]
            RE[Reward Engine]
            PE[Pattern Engine]
            NE[Notification Engine]
        end

        subgraph "Persistence"
            PG[(PostgreSQL 14)]
        end
    end

    %% Interactions
    UI <--> MC
    SET <--> MC
    MC <--> ACC
    ACC --> CDE
    CDE --> INT
    INT --> FRI
    FRI --> OVR
    
    %% Storage Interactions
    ACC -.-> ESP
    UI -.-> ESP
    KEY --- TEE
    ESP -.-> KEY

    %% External Connections
    MC <==> TLS
    TLS <==> AUTH
    AUTH --> JWT
    
    %% Backend Logic
    AUTH --> AS
    AS --> RE
    AS --> PE
    PE --> NE
    AS <--> PG
    RE <--> PG
    
    %% Styling
    style TEE fill:#f96,stroke:#333,stroke-width:2px
    style KEY fill:#f96,stroke:#333,stroke-width:2px
    style ACC fill:#3498db,stroke:#fff,color:#fff
    style CDE fill:#3498db,stroke:#fff,color:#fff
    style PG fill:#2ecc71,stroke:#333,stroke-width:2px
    style JWT fill:#e74c3c,stroke:#fff,color:#fff
```

### Component Breakdown

| Layer | Component | Description |
| :--- | :--- | :--- |
| **Execution Plane** | Accessibility Service | System-level listener monitoring app transitions and interactions. |
| | Cognitive Drift Engine™ | Real-time processor for interaction velocity and behavioral fragmentation. |
| | Friction Layer | Implements intentional latency and reflection prompts before distraction. |
| **Presentation Plane** | Brain Mirror™ Dashboard | High-fidelity Flutter UI providing cognitive insights and data viz. |
| | Secure Screens | Uses `FLAG_SECURE` to prevent unauthorized snapshots/recordings. |
| **Intelligence Plane** | Analytics Service | Backend processor for weekly reports and longitudinal drift tracking. |
| | Reward Engine | Calculates behavioral bonuses and autonomy scores. |
| | PostgreSQL | Hardened persistence layer with `pg-query-stream` for performance. |
| **Security Layer** | Hardware Keystore | RS256 keys stored in the device's Trusted Execution Environment (TEE). |
| | RS256 JWT | Asymmetric authentication ensuring non-repudiation and integrity. |
