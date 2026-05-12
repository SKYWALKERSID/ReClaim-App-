const fs = require('fs');
const path = require('path');
const {
    Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
    HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
    PageNumber, PageBreak, LevelFormat, TableOfContents, Footer, Header,
    VerticalAlign, SectionType
} = require('docx');

// Setup output path - Workspace root as discussed
const outputPath = path.join(__dirname, 'ReClaim_Complete_Reference.docx');

// Colors
const C = {
    headerBg: 'D5E8F0',
    altRow1: 'FFFFFF',
    altRow2: 'F9F9F9',
    border: 'CCCCCC',
    codeBack: 'F5F5F5'
};

// Paragraph/Heading Styles
const styles = {
    paragraphStyles: [
        {
            id: "Normal",
            name: "Normal",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { font: "Arial", size: 24 }, // 12pt
            paragraph: { spacing: { line: 276 } } // 1.15 line spacing
        },
        {
            id: "Heading1",
            name: "Heading 1",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { font: "Arial", size: 64, bold: true }, // 32pt
            paragraph: { spacing: { before: 240, after: 240 }, outlineLevel: 0 }
        },
        {
            id: "Heading2",
            name: "Heading 2",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { font: "Arial", size: 56, bold: true }, // 28pt
            paragraph: { spacing: { before: 180, after: 180 }, outlineLevel: 1 }
        },
        {
            id: "Heading3",
            name: "Heading 3",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: { font: "Arial", size: 48, bold: true }, // 24pt
            paragraph: { spacing: { before: 120, after: 120 }, outlineLevel: 2 }
        }
    ]
};

// Helpers
function h1(text) { return new Paragraph({ text, heading: HeadingLevel.HEADING_1 }); }
function h2(text) { return new Paragraph({ text, heading: HeadingLevel.HEADING_2 }); }
function h3(text) { return new Paragraph({ text, heading: HeadingLevel.HEADING_3 }); }
function para(text) { return new Paragraph({ children: [new TextRun({ text, font: "Arial", size: 24 })], spacing: { before: 120, after: 120 } }); }
function code(text) { 
    return new Paragraph({ 
        children: [new TextRun({ text, font: "Courier New", size: 20 })],
        shading: { type: ShadingType.CLEAR, fill: C.codeBack },
        indent: { left: 480 }
    });
}
function bullet(text) {
    return new Paragraph({
        text,
        numbering: { reference: "bullets", level: 0 },
        spacing: { before: 80, after: 80 }
    });
}
function pageBreak() { return new Paragraph({ children: [new PageBreak()] }); }

function makeTable(headers, rows, customWidths = null) {
    const tableWidth = 10000; // DXA total approx
    const colWidth = Math.floor(tableWidth / headers.length);
    const colWidths = customWidths || Array(headers.length).fill(colWidth);

    const bdr = { style: BorderStyle.SINGLE, size: 2, color: C.border };
    const borders = { top: bdr, bottom: bdr, left: bdr, right: bdr };
    const cellMar = { top: 80, bottom: 80, left: 120, right: 120 };

    const trs = [];
    
    // Header
    trs.push(new TableRow({
        children: headers.map((h, i) => new TableCell({
            width: { size: colWidths[i], type: WidthType.DXA },
            borders, margins: cellMar,
            shading: { fill: C.headerBg, type: ShadingType.CLEAR },
            children: [new Paragraph({ children: [new TextRun({ text: h, bold: true, font: "Arial", size: 24 })] })]
        }))
    }));

    // Rows
    rows.forEach((r, i) => {
        const fill = i % 2 === 0 ? C.altRow1 : C.altRow2;
        trs.push(new TableRow({
            children: r.map((cText, j) => new TableCell({
                width: { size: colWidths[j], type: WidthType.DXA },
                borders, margins: cellMar,
                shading: { fill, type: ShadingType.CLEAR },
                children: [new Paragraph({ children: [new TextRun({ text: String(cText || '-'), font: "Arial", size: 24 })] })]
            }))
        }));
    });

    return new Table({ width: { size: tableWidth, type: WidthType.DXA }, columnWidths: colWidths, rows: trs });
}

// ---------------------------------------------------------
// REPOSITORY ANALYSIS (Deep Crawl)
// ---------------------------------------------------------

function walk(dir, results = []) {
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const fileLoc = path.join(dir, file);
        if (file === 'node_modules' || file === '.git' || file === 'build' || file === '.dart_tool') return;
        const stat = fs.statSync(fileLoc);
        if (stat.isDirectory()) {
            results.push({ rel: path.relative(__dirname, fileLoc), type: 'Directory' });
            walk(fileLoc, results);
        } else {
            results.push({ rel: path.relative(__dirname, fileLoc), type: 'File', size: stat.size });
        }
    });
    return results;
}

const allItems = walk(__dirname);
const repoRows = allItems.map(item => {
    let purpose = '-';
    let deps = '-';
    let usedBy = '-';
    
    if (item.type === 'File') {
        const ext = path.extname(item.rel);
        if (item.rel.includes('services/api')) purpose = 'Backend Service/Route';
        else if (item.rel.includes('apps/mobile/lib')) purpose = 'Mobile UI/Logic';
        else if (item.rel.includes('android')) purpose = 'Native Native Hook';
        else if (ext === '.sql') purpose = 'DB Migration';
        else if (ext === '.yaml') purpose = 'Configuration';
        
        // Quick dependency check
        if (['.ts', '.js', '.dart'].includes(ext)) {
            try {
                const content = fs.readFileSync(path.join(__dirname, item.rel), 'utf8');
                const imports = content.match(/(import|require|from)\s+['"](.+?)['"]/g);
                if (imports) deps = imports.length + ' imports';
            } catch(e) {}
        }
    }
    return [item.rel, item.type, purpose, deps, usedBy];
});

// ---------------------------------------------------------
// DOCX CONSTRUCTION
// ---------------------------------------------------------

const children = [];

// SECTION 1 - Cover
children.push(new Paragraph({ spacing: { before: 2000 } }));
children.push(new Paragraph({ 
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "ReClaim™", bold: true, size: 72, font: "Arial" })] 
}));
children.push(new Paragraph({ 
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Complete Technical & Policy Reference", size: 36, font: "Arial" })] 
}));
children.push(new Paragraph({ spacing: { before: 5000 } }));
children.push(new Paragraph({ 
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Version 2.1 | " + new Date().toLocaleDateString(), size: 24, font: "Arial" })] 
}));
children.push(new Paragraph({ 
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "CONFIDENTIALITY NOTICE: INTERNAL ONLY", bold: true, size: 24, font: "Arial", color: "FF0000" })] 
}));
children.push(pageBreak());

// SECTION 2 - TOC
children.push(h1("Table of Contents"));
children.push(new TableOfContents("Table of Contents", {
    hyperlink: true,
    headingStyleRange: "1-3",
}));
children.push(pageBreak());

// SECTION 3 - Overview
children.push(h1("SECTION 3 — Project Overview"));
children.push(para("ReClaim™ is a high-performance behavioral autonomy platform. It is designed to intervene in digital addiction patterns by introducing intentional friction and providing real-time cognitive awareness metrics."));
children.push(h2("System Philosophy"));
children.push(para("The system operates on the principle of 'Attention Governance'. Instead of simple blocks, it quantifies attention decay (Drift) and introduces variable latency based on cognitive load."));
children.push(h2("High-level Architecture"));
children.push(makeTable(
    ["Layer", "Technology", "Responsibility"],
    [
        ["Execution Plane", "Kotlin Native", "Accessibility interception & hardware-backed security"],
        ["Presentation Plane", "Flutter (Dart)", "Cross-platform UI and reactive state (Riverpod)"],
        ["Intelligence Plane", "Node.js (TypeScript)", "Pattern recognition and reward engine logic"],
        ["Database Layer", "PostgreSQL 14", "Persistent storage of behavioral events and policies"]
    ]
));
children.push(h2("Glossary of Proprietary Terms"));
children.push(bullet("Fragmentation Index: A 0-100 score measuring rapid app-switching density in 5-minute windows."));
children.push(bullet("Drift Score: A real-time decay metric (0-100) calculated from interaction velocity and feed exposure."));
children.push(bullet("SafeCode: A 4-digit code stored in the Android TEE used for emergency overrides."));
children.push(bullet("Cognitive Drift Engine™ (CDE): The core native engine calculating behavioral metrics."));
children.push(bullet("Variable Latency Friction: Intentional launch delays scaled by current Drift Score."));
children.push(bullet("Brain Mirror™: The visual representation layer of behavioral data in the Flutter app."));
children.push(pageBreak());

// SECTION 4 - Repository Structure
children.push(h1("SECTION 4 — Repository Structure"));
children.push(para("The ReClaim codebase is a monorepo containing mobile and backend services."));
children.push(makeTable(
    ["Path", "Type", "Purpose", "Deps", "Used By"],
    repoRows, // All items
    [4500, 1000, 2000, 1250, 1250]
));
children.push(pageBreak());

// SECTION 5 - Mobile App Walkthrough
children.push(h1("SECTION 5 — Mobile App: Full Code Walkthrough"));
children.push(h2("5.1 Flutter Architecture"));
children.push(para("The mobile app follows a reactive functional pattern using Riverpod for state management. Providers are decoupled from UI components."));
children.push(makeTable(
    ["Provider", "Manages", "Consumed By"],
    [
        ["authProvider", "Firebase session & JWT", "App entry, Account screen"],
        ["policyProvider", "Enforcement rules", "Accessibility bridge, Policy screen"],
        ["driftProvider", "Live metrics from CDE", "Brain Mirror dashboard"],
        ["eventProvider", "Local usage buffer", "Sync worker"]
    ]
));
children.push(h2("5.2 Screen & Widget Inventory"));
children.push(para("Key UI components located in /lib/widgets:"));
children.push(bullet("BrainMirrorChart: Custom Rive/Canvas visualization for Drift history."));
children.push(bullet("FrictionOverlay: Full-screen system overlay triggered during app launch."));
children.push(bullet("SafeCodePad: Secure PIN entry component with hardware verification logic."));
children.push(h2("5.3 Android Native Layer (Kotlin)"));
children.push(para("The Execution Plane resides in apps/mobile/android."));
children.push(bullet("ReclaimAccessibilityService: Listens for TYPE_WINDOW_STATE_CHANGED and TYPE_VIEW_SCROLLED."));
children.push(bullet("EnforcementManager: Coordinates blocking logic, checking Focus Windows and Daily Limits."));
children.push(bullet("Android Keystore: RS256 keys are stored in the TEE (Trusted Execution Environment) for token signing."));
children.push(h2("5.4 Variable Latency Friction — Mobile Side"));
children.push(para("Delay Calculation: L = Base_Delay * (1 + (DriftScore / 50)). If Drift Score is 100, delay is tripled."));
children.push(pageBreak());

// SECTION 6 - Backend Walkthrough
children.push(h1("SECTION 6 — Backend: Full Code Walkthrough"));
children.push(h2("6.1 Express.js Route Map"));
children.push(makeTable(
    ["Method", "Endpoint", "Controller", "Auth", "Desc"],
    [
        ["POST", "/auth/login", "auth.controller", "No", "Firebase verification & JWT issuance"],
        ["POST", "/auth/refresh", "auth.controller", "No", "Rotate refresh token"],
        ["POST", "/events/ingest", "analytics.controller", "Yes", "Batch upload of usage events"],
        ["GET", "/analytics/daily", "analytics.controller", "Yes", "Fetch daily stats & insights"],
        ["GET", "/drift/report", "drift.controller", "Yes", "Fetch weekly fragmentation insights"],
        ["GET", "/social/buddies", "social.controller", "Yes", "Fetch focus buddy statuses"],
        ["POST", "/social/challenges/join", "social.controller", "Yes", "Join collaborative focus challenge"],
        ["PUT", "/policy/sync", "policy.controller", "Yes", "Update user enforcement rules"]
    ]
));
children.push(h2("6.2 Sync Protocol & Ingestion"));
children.push(para("The system uses a 'Buffering' sync strategy. Usage events are stored in a local SQLite database on the device and uploaded every 15 minutes or when the app is opened."));
children.push(bullet("Client -> Server: POST /events/ingest with Zod-validated eventsPayloadSchema."));
children.push(bullet("Server -> DB: Batch UPSERT into usage_events table."));
children.push(bullet("Post-Processing: AnalyticsService computes screen time and drift patterns asynchronously."));

children.push(h2("6.3 Authentication Flow"));
children.push(para("1. Client obtains Firebase ID Token."));
children.push(para("2. Client sends ID Token to /auth/login."));
children.push(para("3. Server verifies ID Token with Firebase Admin SDK."));
children.push(para("4. Server generates RS256 JWT signed with private key."));
children.push(para("5. Client uses JWT for all subsequent requests."));

children.push(h2("6.4 PostgreSQL Database Schema (Master)"));
children.push(para("The database uses versioned migrations (001-014). Key tables include:"));
children.push(makeTable(
    ["Table", "Description", "Primary Key"],
    [
        ["users", "Master user records and authentication metadata", "id (UUID)"],
        ["usage_events", "Raw behavioral events (app starts, stops, scrolls)", "id (BIGSERIAL)"],
        ["drift_sessions", "Aggregated cognitive state per app session", "session_id (UUID)"],
        ["commitments", "User-defined limits and focus windows", "user_id (UUID)"],
        ["friction_events", "Log of intentional friction interventions", "id (BIGSERIAL)"],
        ["buddy_relationships", "Social graph mapping between users", "id (BIGSERIAL)"],
        ["challenges", "Collaborative focus events with participant lists", "id (UUID)"]
    ]
));

children.push(pageBreak());

// SECTION 7 - Proprietary Engines
children.push(h1("SECTION 7 — Proprietary Engines: Deep Dive"));
children.push(h2("7.1 Cognitive Drift Engine™ (CDE)"));
children.push(para("Location: apps/mobile/android/app/src/main/kotlin/.../engine/CognitiveDriftEngine.kt"));
children.push(para("The CDE runs in the Accessibility Service background process. It monitors interaction velocity and window transitions."));
children.push(h3("Drift Score (S) Calculation"));
children.push(code("S = (Reopens * 12) + (FailedExits * 15) + (SwitchDensity * 18) + (FeedMins * 4)"));
children.push(bullet("Reopens: Tapping an app within 30s of previous close."));
children.push(bullet("FailedExits: Closing an app within 5s of opening."));
children.push(bullet("SwitchDensity: Count of package name changes in trailing 300s."));
children.push(bullet("FeedMins: Accumulation of scroll duration in social packages."));

children.push(h2("7.2 Variable Latency Friction Engine"));
children.push(para("Friction is introduced via the FrictionOverlayService. It intercepts Intent launches and delays the release of the overlay based on S."));
children.push(code("L = clamp(Base_Delay * (1 + (S / 50)), 0s, 10s)"));

children.push(h2("7.3 Brain Mirror™ Layer"));
children.push(para("The Brain Mirror converts raw Drift scores into a 'Cognitive Heatmap'. It identifies 'Peak Volatility Hours' (PVH) and suggests 'Detox Windows'."));
children.push(pageBreak());

// SECTION 8 - Social Accountability Plane
children.push(h1("SECTION 8 — Social Accountability Plane"));
children.push(h2("8.1 Buddy Network"));
children.push(para("The Social Plane (Buddy Network) allows users to tether their enforcement policies. If a user attempts to bypass a 'Hard Block', their buddies receive a nudge."));
children.push(h2("8.2 Collaborative Challenges"));
children.push(para("Users can join 'Focus Sprints'. Success in these challenges earns 'Reputation Points' which lower future latency multipliers."));
children.push(pageBreak());

// SECTION 9 - Security Architecture
children.push(h1("SECTION 9 — Security Architecture"));
children.push(h2("9.1 Hardware-Backed Security"));
children.push(para("SafeCodes are not stored in plain text. They are hashed and verified within the Android Keystore."));
children.push(h2("9.2 Token Security"));
children.push(bullet("JWT Algorithm: RS256 (Asymmetric)"));
children.push(bullet("Refresh Strategy: Opaque 64-char refresh tokens stored in HTTP-only cookies."));
children.push(bullet("Payload Security: End-to-End TLS 1.3 with Certificate Pinning in Flutter."));
children.push(pageBreak());

// SECTION 10 - DevOps
children.push(h1("SECTION 10 — DevOps & Infrastructure"));
children.push(h2("10.1 Docker Setup"));
children.push(para("Services are containerized using Docker Compose. API and Database are isolated in a private bridge network."));
children.push(h2("10.2 CI/CD Pipeline"));
children.push(para("GitHub Actions workflow '.github/workflows/main.yml' runs tests on every push."));
children.push(pageBreak());

// SECTION 11 - Data Flows
children.push(h1("SECTION 11 — Data Flow Diagrams"));
children.push(h2("11.1 App Launch with Latency"));
children.push(para("1. User Taps App -> 2. Native Hook Detects -> 3. Drift Check -> 4. Overlay Render -> 5. Release Lock."));
children.push(h2("11.2 Behavioral Recording"));
children.push(para("1. Action -> 2. Local SQLite Insert -> 3. Periodic Sync -> 4. Zod Check -> 5. Postgres Save -> 6. CDE Recalc."));
children.push(pageBreak());

// SECTION 12 - Onboarding
children.push(h1("SECTION 12 — Developer Onboarding Checklist"));
children.push(para("To setup the environment:"));
children.push(bullet("Install Node.js 20+, Flutter 3.22+, and Docker Desktop."));
children.push(bullet("Run npm install in root and /services/api."));
children.push(bullet("Run 'docker-compose up -d' for the database."));
children.push(bullet("Configure .env with Firebase credentials."));
children.push(pageBreak());

// SECTION 13 - Appendices
children.push(h1("SECTION 13 — Appendices"));
children.push(h2("A. Full API Reference"));
children.push(para("Refer to documentation/API_SPEC.json for full Swagger definition."));
children.push(h2("B. Environment Master List"));
children.push(code("PORT, DATABASE_URL, FIREBASE_PROJECT_ID, JWT_SECRET, PRIVATE_KEY_PEM"));

// Final Document
const doc = new Document({
    styles: styles,
    numbering: {
        config: [
            {
                reference: "bullets",
                levels: [
                    {
                        level: 0,
                        format: LevelFormat.BULLET,
                        text: "●",
                        alignment: AlignmentType.LEFT,
                        style: {
                            paragraph: { indent: { left: 720, hanging: 360 } }
                        }
                    }
                ]
            }
        ]
    },
    sections: [
        {
            properties: {
                page: {
                    margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
                    size: { width: 12240, height: 15840 }
                }
            },
            headers: {
                default: new Header({
                    children: [
                        new Paragraph({
                            alignment: AlignmentType.RIGHT,
                            children: [new TextRun({ text: "ReClaim™ Technical Reference", size: 18, color: "999999" })]
                        })
                    ]
                })
            },
            footers: {
                default: new Footer({
                    children: [
                        new Paragraph({
                            alignment: AlignmentType.LEFT,
                            children: [
                                new TextRun({ text: "ReClaim™ Confidential" }),
                                new TextRun({ children: [PageNumber.CURRENT], })
                            ]
                        })
                    ]
                })
            },
            children: children
        }
    ]
});

Packer.toBuffer(doc).then((buffer) => {
    fs.writeFileSync(outputPath, buffer);
    console.log("SUCCESS: ReClaim_Complete_Reference.docx generated at " + outputPath);
});
