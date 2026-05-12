const fs = require('fs');
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  HeadingLevel,
  AlignmentType,
  BorderStyle,
  Table,
  TableRow,
  TableCell,
  WidthType,
  PageBreak,
  Header,
  Footer,
  PageNumber,
} = require('docx');

// ──────────────────────────────────────────────────────────────────────────
// UTILITIES FOR CLEANER CONTENT BUILDING
// ──────────────────────────────────────────────────────────────────────────

const h1 = (text) => new Paragraph({ text, heading: HeadingLevel.HEADING_1, spacing: { before: 400, after: 200 } });
const h2 = (text) => new Paragraph({ text, heading: HeadingLevel.HEADING_2, spacing: { before: 300, after: 150 } });
const h3 = (text) => new Paragraph({ text, heading: HeadingLevel.HEADING_3, spacing: { before: 200, after: 100 } });

const para = (text) => new Paragraph({
  children: [new TextRun({ text, size: 24, font: 'Calibri' })],
  spacing: { after: 200 },
  alignment: AlignmentType.JUSTIFY,
});

const bullet = (text) => new Paragraph({
  children: [new TextRun({ text: `• ${text}`, size: 24, font: 'Calibri' })],
  indent: { left: 720 },
  spacing: { after: 100 },
});

const numbered = (text, index) => new Paragraph({
  children: [new TextRun({ text: `${index}. ${text}`, size: 24, font: 'Calibri' })],
  indent: { left: 720 },
  spacing: { after: 100 },
});

const code = (text) => new Paragraph({
  children: [new TextRun({ text, size: 18, font: 'Courier New', color: '2E86AB' })],
  shading: { fill: 'F4F4F4' },
  indent: { left: 360 },
  spacing: { before: 40, after: 40 },
});

const divider = () => new Paragraph({
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '2E86AB', space: 1 } },
  spacing: { after: 400 },
});

const sp = () => [new Paragraph({ text: '', spacing: { after: 200 } })];

const pageBreak = () => new Paragraph({ children: [new PageBreak()] });

const advancedNote = (text) => new Paragraph({
  children: [
    new TextRun({ text: 'TECHNICAL SPECIFICATION: ', bold: true, color: '2E86AB', size: 20 }),
    new TextRun({ text, size: 20, italics: true, color: '333333' }),
  ],
  shading: { fill: 'EBF5FB' },
  border: { left: { style: BorderStyle.SINGLE, size: 20, color: '2E86AB', space: 10 } },
  indent: { left: 360 },
  spacing: { before: 200, after: 200 },
});

const beginnerNote = (text) => new Paragraph({
  children: [
    new TextRun({ text: 'CONCEPTUAL ANALOGY: ', bold: true, color: '2E86AB', size: 20 }),
    new TextRun({ text, size: 20, italics: true, color: '333333' }),
  ],
  shading: { fill: 'FEF9E7' },
  border: { left: { style: BorderStyle.SINGLE, size: 20, color: 'F1C40F', space: 10 } },
  indent: { left: 360 },
  spacing: { before: 200, after: 200 },
});

// Helper to create a table from a headers array and a rows array (array of arrays)
function makeTable(headers, rows, widths) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: headers.map((h, i) => new TableCell({
          children: [new Paragraph({ text: h, bold: true, size: 20, color: 'FFFFFF' })],
          shading: { fill: '2E86AB' },
          width: widths ? { size: widths[i], type: WidthType.DXA } : null,
        })),
      }),
      ...rows.map(row => new TableRow({
        children: row.map(cellText => new TableCell({
          children: [new Paragraph({ text: cellText, size: 18 })],
          spacing: { top: 100, bottom: 100 },
        })),
      })),
    ],
  });
}

// ──────────────────────────────────────────────────────────────────────────
// PART 1 — MISSION, PSYCHOLOGY & ARCHITECTURE
// ──────────────────────────────────────────────────────────────────────────
function buildPart1() {
  const out = [];

  out.push(h1('PART 1 — MISSION, PSYCHOLOGY & ARCHITECTURE'), divider());

  // CH1
  out.push(h2('Chapter 1: The ReClaim™ Mission — Fighting Back at Scale'));
  out.push(para('ReClaim™ is a high-performance behavioural enforcement platform for Android designed to counteract addictive engineering through system-level intervention. Unlike traditional productivity tools that rely on user willpower, ReClaim implements physical and cognitive barriers at the architectural layer.'));
  out.push(advancedNote('Technically, ReClaim functions as a system-level interceptor. It utilizes Android\'s AccessibilityService API to monitor the TYPE_WINDOW_STATE_CHANGED event stream. When a restricted package is detected, the service evaluates the enforcement policy and conditionally executes a redirect or overlay intent before the target application can fully render its interface.'));
  out.push(...sp());
  out.push(h3('1.1 The Core Premise'));
  out.push(para('ReClaim is built on the neuroscientific insight that the "gap" between an impulse (the desire to check an app) and the action (opening it) is where rational decision-making occurs. By intentionally engineering this gap to be longer, ReClaim provides the prefrontal cortex with sufficient time to override the automatic habit loop.'));
  out.push(h3('1.2 Who Is ReClaim For?'));
  out.push(makeTable(
    ['User Type', 'Primary Problem', 'Enforcement Strategy'],
    [
      ['Knowledge Workers', 'Context-switching destroys deep work', 'Hard block during Deep Focus sessions'],
      ['Students', 'Social media interference with study', 'Friction-based delays for distracting domains'],
      ['Security-Conscious Users', 'Privacy concerns with data-hungry apps', 'Brain Mirror™ auditing and safe code overrides'],
      ['General Users', 'Digital addiction and excessive screen time', 'Cognitive Drift monitoring and behavioral nudges'],
    ],
    [3120, 3120, 3120]
  ));
  out.push(...sp());
  out.push(h3('1.3 Technical Differentiation'));
  out.push(para('Most "focus apps" operate at the application layer, which is easily bypassed. ReClaim operates as a Foreground Service with Accessibility privileges, ensuring enforcement that cannot be dismissed with a single tap. This system-level dominance is the foundation of our "counter-engineering" approach.'));

  out.push(pageBreak());

  // CH2
  out.push(h2('Chapter 2: The Problem Space — Engineering Digital Addiction'));
  out.push(para('To effectively solve digital addiction, we must understand the engineering behind it. Social platforms utilize intermittent variable reward systems—the same psychological mechanics found in gambling—to maximize user retention and screen time.'));
  out.push(h3('2.1 The Scale of Cognitive Erosion'));
  out.push(makeTable(
    ['Metric', 'Current Industry Reality'],
    [
      ['Daily Screen Time (Global Avg)', '6 hours 58 minutes'],
      ['Check Frequency', '96+ times per day'],
      ['Task-Switching Loss', '~2.5 hours per knowledge worker per day'],
      ['Focus Regain Time', '23 minutes average to reach deep focus after interruption'],
    ],
    [4680, 4680]
  ));
  out.push(...sp());
  out.push(h3('2.2 The Attention Economy Mechanism'));
  out.push(para('Tech infrastructure is optimized for extraction. Infinite scroll, predictive push notifications, and social validation loops are designed to overwhelm the brain\'s executive function. ReClaim treats attention as a protected system resource, applying access control policies and rate limiting at the infrastructure level.'));
  out.push(advancedNote('From a systems architecture perspective, attention is treated as a non-renewable compute resource. ReClaim applies access-control lists (ACLs) to applications, rate-limits access frequency via the Friction Layer, and provides real-time observability through the Brain Mirror™ dashboard to manage this resource like a mission-critical infrastructure asset.'));

  out.push(pageBreak());

  // CH3
  out.push(h2('Chapter 3: The Psychology of Behavioral Cycles & Cognitive Drift'));
  out.push(h3('3.1 Dopamine and Anticipation Loops'));
  out.push(para('Dopamine is the neurotransmitter of anticipation, not necessarily reward. In the digital context, the notification "ping" triggers a dopamine surge before the user even sees the content. This creates a compulsive checking cycle. ReClaim breaks this cycle at the "Routine" stage of the habit loop.'));
  out.push(h3('3.2 Breaking the Habit Loop'));
  out.push(para('A habit loop consists of a Cue, a Routine, and a Reward. ReClaim intervenes directly in the Routine. When an automated trigger occurs, ReClaim inserts a mandatory friction delay. This pause re-engages the prefrontal cortex, which behavioral economics shows can reduce impulsive action by up to 67% with just a 20-second delay.'));
  out.push(h3('3.3 The Cognitive Drift Engine™ (v2.0 Metrics)'));
  out.push(para('ReClaim utilizes a multi-dimensional measurement system to quantify cognitive state in real time:'));
  out.push(makeTable(
    ['Metric', 'Technical Definition', 'Significance'],
    [
      ['Fragmentation Index', 'Rate of context-switching between productivity and distraction contexts.', 'Indicates the scattered state of attention.'],
      ['Drift Score', 'Interaction velocity and session duration weighted by app category.', 'Real-time quantification of attention decay.'],
      ['Cognitive Pulse™', 'Frequency of switches between high-dopamine and low-dopamine states.', 'Identifies frantic or compulsive behavior cycles.'],
      ['Craving Windows', 'Predicted time periods of high lapse probability based on historical data.', 'Enables proactive enforcement tightening.'],
      ['Lifetime Drift™', 'The integral of the Drift Score over the user\'s full engagement history.', 'Measures cumulative cognitive cost of distraction.'],
      ['Memory Streams™', 'Temporal mapping of attention across different application domains.', 'Allows for forensic auditing of productivity gaps.'],
    ],
    [2500, 3120, 3600]
  ));
  out.push(...sp());
  out.push(advancedNote('The Fragmentation Index is computed by the Kotlin-layer CognitiveDriftEngine class. It monitors the sequence of package transitions and calculates a decay-weighted score based on the delta between "Focus" (Productive) and "Distraction" (Restricted) app usage. The engine utilizes a sliding window algorithm to ensure the score reflects current cognitive state while smoothing out outliers.'));

  out.push(pageBreak());

  // CH4
  out.push(h2('Chapter 4: The Friction Layer — Engineering Intentionality'));
  out.push(para('The Friction Layer is the primary enforcement mechanism of ReClaim. It introduces mandatory latency between the user\'s impulse and the application launch.'));
  out.push(h3('4.1 Modes of Enforcement'));
  out.push(makeTable(
    ['Mode', 'Mechanism', 'Use Case'],
    [
      ['Smart Friction', 'Timed delay (5-60s) + reflection prompt via Flutter overlay.', 'Standard daily habit mitigation.'],
      ['Hard Block', 'Intent redirection to a reflection screen with cooling-off timer.', 'Deep Focus sessions / Strict enforcement.'],
      ['Cognitive Nudge', 'Non-blocking overlay displaying real-time Drift Score.', 'Awareness-only monitoring mode.'],
    ],
    [2340, 3780, 3240]
  ));
  out.push(h3('4.2 The Technical Sequence of Smart Friction'));
  out.push(numbered('User initiates application launch (e.g., TikTok).', 1));
  out.push(numbered('ActivityManager broadcasts TYPE_WINDOW_STATE_CHANGED.', 2));
  out.push(numbered('Kotlin AccessibilityService intercepts the event and identifies the package.', 3));
  out.push(numbered('The service queries the local policy database (EncryptedSharedPrefs).', 4));
  out.push(numbered('The service triggers a full-screen Flutter overlay via MethodChannel.', 5));
  out.push(numbered('The overlay renders a countdown and reflection prompt above the target app.', 6));
  out.push(numbered('The target app is only accessible once the timer expires and the overlay is dismissed.', 7));

  out.push(pageBreak());

  // CH5 (RESTORED ARCHITECTURE DIAGRAM)
  out.push(h2('Chapter 5: System Architecture & Flowchart'));
  out.push(para('ReClaim is built as a high-security monorepo consisting of a Flutter mobile client, a Kotlin native service, and a Node.js backend.'));
  const mermaidLines = [
    'graph TB',
    '    subgraph "Mobile Client (Android Device)"',
    '        subgraph "Presentation Plane (Flutter UI)"',
    '            UI[Brain Mirror™ Dashboard]',
    '            SEC_S[Sensitive Screens - FLAG_SECURE]',
    '            SET[Policy Configuration]',
    '        end',
    '        subgraph "Bridge Layer"',
    '            MC[MethodChannel Bridge]',
    '        end',
    '        subgraph "Execution Plane (Kotlin Native)"',
    '            ACC[Accessibility Service]',
    '            CDE[Cognitive Drift Engine™]',
    '            INT[Intent Interception]',
    '            OVR[Overlay Rendering]',
    '            FRI[Friction Layer]',
    '        end',
    '        subgraph "Secure Storage (Hardware-Backed)"',
    '            TEE[Android Trusted Execution Environment]',
    '            KEY[Hardware Keystore]',
    '            ESP[Encrypted Shared Prefs - AES-256-GCM]',
    '        end',
    '    end',
    '',
    '    subgraph "Network & Security"',
    '        TLS[TLS 1.3 Encryption]',
    '        JWT[RS256 JWT Authentication]',
    '    end',
    '',
    '    subgraph "Intelligence Plane (Node.js Backend)"',
    '        subgraph "API Gateway (Express.js)"',
    '            HLM[Helmet.js - HSTS/CSP]',
    '            RL[Rate Limiting]',
    '            ZOD[Zod Schema Validation]',
    '            AUTH[Auth Handler]',
    '        end',
    '        subgraph "Core Services"',
    '            AS[Analytics Service]',
    '            RE[Reward Engine]',
    '            PE[Pattern Engine]',
    '            NE[Notification Engine]',
    '        end',
    '        subgraph "Persistence"',
    '            PG[(PostgreSQL 14)]',
    '        end',
    '    end',
    '',
    '    UI <--> MC',
    '    SET <--> MC',
    '    MC <--> ACC',
    '    ACC --> CDE',
    '    CDE --> INT',
    '    INT --> FRI',
    '    FRI --> OVR',
    '    ACC -.-> ESP',
    '    UI -.-> ESP',
    '    KEY --- TEE',
    '    ESP -.-> KEY',
    '    MC <==> TLS',
    '    TLS <==> AUTH',
    '    AUTH --> JWT',
    '    AUTH --> AS',
    '    AS --> RE',
    '    AS --> PE',
    '    PE --> NE',
    '    AS <--> PG',
    '    RE <--> PG'
  ];
  mermaidLines.forEach(l => out.push(code(l)));
  out.push(...sp());
  out.push(h3('5.1 Component Breakdown'));
  out.push(makeTable(
    ['Layer', 'Component', 'Description'],
    [
      ['Execution Plane', 'Accessibility Service', 'System-level listener monitoring app transitions.'],
      ['', 'Cognitive Drift Engine™', 'Real-time processor for interaction velocity and behavior.'],
      ['', 'Friction Layer', 'Implements intentional latency and reflection prompts.'],
      ['Presentation Plane', 'Brain Mirror™ Dashboard', 'High-fidelity Flutter UI providing cognitive insights.'],
      ['Security Layer', 'Hardware Keystore', 'RS256 keys stored in the device\'s TEE.'],
    ],
    [3120, 3120, 3120]
  ));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// PART 2 — DESIGN SYSTEM & UI/UX
// ──────────────────────────────────────────────────────────────────────────
function buildPart2() {
  const out = [];

  out.push(h1('PART 2 — DESIGN SYSTEM & UI/UX'), divider());

  // CH6
  out.push(h2('Chapter 6: UI/UX Philosophy & Design Principles'));
  out.push(para('ReClaim\'s design philosophy is grounded in a single paradox: an app designed to fight addictive design must itself avoid being addictive. Every design decision is therefore made with intentional restraint.'));
  out.push(h3('6.1 Core Design Principles'));
  out.push(makeTable(
    ['Principle', 'Meaning', 'Implementation'],
    [
      ['Intentional Minimalism', 'Show only what is necessary', 'Single-action screens; max 3 interactive elements.'],
      ['Calm Technology', 'Inform without demanding attention', 'Muted palette, no notification badges.'],
      ['Data as Mirror', 'Neutral presentation of behavior', 'Brain Mirror™ presents raw data without judgement.'],
    ],
    [2340, 2340, 4680]
  ));
  out.push(pageBreak());

  // CH7
  out.push(h2('Chapter 7: Glassmorphism & Visual Language'));
  out.push(para('ReClaim utilizing Glassmorphism—semi-transparent elements with BackdropFilter—to create a deep, focused aesthetic.'));
  out.push(h3('7.1 Technical Implementation'));
  out.push(code('// Glassmorphism card in Flutter'));
  out.push(code('ClipRRect('));
  out.push(code('  borderRadius: BorderRadius.circular(16),'));
  out.push(code('  child: BackdropFilter('));
  out.push(code('    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),'));
  out.push(code('    child: Container( ... ),'));
  out.push(code('  ),'));
  out.push(code(')'));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// PART 3 — MOBILE ARCHITECTURE (FLUTTER & KOTLIN)
// ──────────────────────────────────────────────────────────────────────────
function buildPart3() {
  const out = [];
  out.push(h1('PART 3 — MOBILE ARCHITECTURE (FLUTTER & KOTLIN)'), divider());

  // CH11 (RESTORED AUTH SCREENS)
  out.push(h2('Chapter 11: User Onboarding & Auth Screens'));
  out.push(para('Onboarding is a critical security phase where the user establishes their identity and configures their SafeCode™ and Accessibility permissions.'));
  out.push(h3('11.1 Authentication Screens'));
  out.push(makeTable(
    ['Screen', 'Purpose', 'Key Components'],
    [
      ['LoginScreen', 'Secure entry into the platform', 'Firebase Auth integration, JWT exchange.'],
      ['SignupScreen', 'User registration and profile creation', 'Email validation, Password hardening.'],
      ['SafeCodeSetup', 'Creation of the 4-digit emergency override', 'Argon2 hashing, Keystore storage.'],
      ['PermissionWizard', 'Guided system permission requests', 'Accessibility, Overlay, and Usage Stats access.'],
    ],
    [2340, 2340, 4680]
  ));
  out.push(...sp());
  out.push(advancedNote('Auth screens use FLAG_SECURE to prevent system-level screenshots or screen recordings of sensitive input fields. The transition from Firebase identity to ReClaim session occurs via a POST /auth/firebase-login call which returns a hardware-bound RS256 JWT.'));

  out.push(pageBreak());

  // Rest of Part 3...
  out.push(h2('Chapter 12: Flutter Architecture & Monorepo Structure'));
  out.push(code('apps/mobile/'));
  out.push(code('├── lib/'));
  out.push(code('│   ├── screens/        # UI Layers (Flutter)'));
  out.push(code('│   ├── widgets/        # Reusable Design System Components'));
  out.push(code('│   ├── providers/      # State Management (Riverpod)'));
  out.push(code('│   └── services/       # API and Native Bridge Clients'));
  out.push(code('└── android/app/src/main/kotlin/'));
  out.push(code('    └── com/reclaim/    # Native Execution Plane (Kotlin)'));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// PART 4 — BACKEND ARCHITECTURE (NODE.JS & POSTGRES)
// ──────────────────────────────────────────────────────────────────────────
function buildPart4() {
  const out = [];
  out.push(h1('PART 4 — BACKEND ARCHITECTURE (NODE.JS & POSTGRES)'), divider());

  out.push(h2('Chapter 21: API Design — Every Endpoint Explained'));
  out.push(h3('21.1 Authentication Endpoints'));
  out.push(makeTable(
    ['Method', 'Endpoint', 'Auth Required', 'Response', 'Description'],
    [
      ['POST', '/auth/firebase-login', 'No', '{ token, user }', 'Exchange Firebase ID token for ReClaim JWT'],
      ['POST', '/auth/refresh', 'No', '{ token }', 'Issue new JWT from refresh token'],
      ['POST', '/auth/logout', 'JWT', '{ success }', 'Invalidate refresh token'],
    ],
    [900, 2340, 1200, 2340, 0]
  ));

  out.push(pageBreak());

  out.push(h2('Chapter 22: Authentication Flow — JWT & RS256'));
  out.push(para('ReClaim utilizes asymmetric RS256 JWTs. The private key remains secure on the backend, while the public key is used for verification across distributed services.'));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// PART 5 — CYBERSECURITY (RESTORED)
// ──────────────────────────────────────────────────────────────────────────
function buildPart5() {
  const out = [];
  out.push(h1('PART 5 — CYBERSECURITY'), divider());

  out.push(h2('Chapter 38: SafeCode™ — The Final Barrier'));
  out.push(para('SafeCode™ is the emergency override mechanism. It implements 4-digit verification with a mandatory 60-second cooling-off period to prevent impulsive overrides.'));
  out.push(advancedNote('SafeCode hashes are stored in the Android Keystore (hardware-backed). The comparison logic is executed within the AccessibilityService to ensure immediate enforcement even if the main UI process is killed.'));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// PART 6 — DEVOPS & DEPLOYMENT
// ──────────────────────────────────────────────────────────────────────────
function buildPart6() {
  const out = [];
  out.push(h1('PART 6 — DEVOPS & DEPLOYMENT'), divider());

  out.push(h2('Chapter 39: Automated Setup and Deployment'));
  out.push(code('npm run setup  # Automates RS256 keygen, Firebase config, and migrations'));
  out.push(code('docker compose up -d # Spins up PostgreSQL and API in hardened containers'));

  out.push(pageBreak());

  return out;
}

// ──────────────────────────────────────────────────────────────────────────
// MAIN BUILD FUNCTION
// ──────────────────────────────────────────────────────────────────────────
async function buildDocument() {
  console.log('🚀 Starting ReClaim Product Bible v2.0 Generation...');

  const sections = [
    ...buildPart1(),
    ...buildPart2(),
    ...buildPart3(),
    ...buildPart4(),
    ...buildPart5(),
    ...buildPart6(),
  ];

  const doc = new Document({
    title: 'ReClaim Product Bible v2.0',
    description: 'The definitive technical source of truth for ReClaim.',
    sections: [{
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: {
        default: new Header({
          children: [
            new Paragraph({
              border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: '2E86AB', space: 2 } },
              children: [
                new TextRun({ text: 'ReClaim™ — Technical Book & Product Bible', size: 18, color: '666666', font: 'Arial' }),
                new TextRun({ text: '\t', size: 18 }),
                new TextRun({ text: 'v2.0 | Confidential', size: 18, color: '666666', font: 'Arial' }),
              ],
              tabStops: [{ type: 'right', position: 9360 }],
            }),
          ],
        }),
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              border: { top: { style: BorderStyle.SINGLE, size: 4, color: '2E86AB', space: 2 } },
              alignment: AlignmentType.CENTER,
              children: [
                new TextRun({ text: 'Page ', size: 18, color: '666666', font: 'Arial' }),
                PageNumber.CURRENT,
                new TextRun({ text: '  |  ReClaim™ — github.com/SKYWALKERSID/ReClaim-App-', size: 18, color: '666666', font: 'Arial' }),
              ],
            }),
          ],
        }),
      },
      children: sections,
    }],
  });

  const buffer = await Packer.toBuffer(doc);
  const outputPath = 'C:\\Users\\siddh\\Desktop\\ReClaim_Technical_Book_v2.0.docx';
  fs.writeFileSync(outputPath, buffer);
  console.log(`✅ Document written to: ${outputPath}`);
  console.log(`📄 File size: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
}

buildDocument().catch(err => {
  console.error('❌ Generation Error:', err);
  process.exit(1);
});
