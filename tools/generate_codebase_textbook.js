const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "docs", "generated");
const MD_PATH = path.join(OUTPUT_DIR, "ReClaim_Codebase_Textbook.md");
const HTML_PATH = path.join(OUTPUT_DIR, "ReClaim_Codebase_Textbook.html");
const PDF_PATH = path.join(OUTPUT_DIR, "ReClaim_Codebase_Textbook.pdf");

const TEXT_EXTENSIONS = new Set([
  ".md",
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".dart",
  ".kt",
  ".java",
  ".xml",
  ".json",
  ".yaml",
  ".yml",
  ".sql",
  ".gradle",
  ".properties",
  ".ps1",
  ".py",
  ".txt",
  ".bat",
  ".pro",
  ".example",
  ".dockerignore",
  ".lock",
  "",
]);

const CONFIG_FILE_NAMES = new Set([
  ".env.example",
  ".gitignore",
  "package.json",
  "package-lock.json",
  "pubspec.yaml",
  "pubspec.lock",
  "analysis_options.yaml",
  "docker-compose.yml",
  "tsconfig.json",
  "gradle.properties",
  "settings.gradle",
  "build.gradle",
  "AndroidManifest.xml",
  "google-services.json.example",
  "proguard-rules.pro",
  "gradle-wrapper.properties",
]);

const CHAPTERS = [
  { key: "config", title: "CHAPTER 1: CONFIGURATION & ENVIRONMENT" },
  { key: "core", title: "CHAPTER 2: CORE MODULES" },
  { key: "api", title: "CHAPTER 3: APIs & ROUTES" },
  { key: "db", title: "CHAPTER 4: DATABASE LAYER" },
  { key: "services", title: "CHAPTER 5: SERVICES & BUSINESS LOGIC" },
  { key: "utils", title: "CHAPTER 6: UTILITIES & HELPERS" },
  { key: "middleware", title: "CHAPTER 7: MIDDLEWARE & INTERCEPTORS" },
  { key: "integrations", title: "CHAPTER 8: INTEGRATIONS & THIRD-PARTY SERVICES" },
  { key: "tests", title: "CHAPTER 9: TESTS" },
  { key: "misc", title: "CHAPTER 10: SCRIPTS & MISCELLANEOUS" },
];

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function toPosix(inputPath) {
  return inputPath.split(path.sep).join("/");
}

function readTextMaybe(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const base = path.basename(filePath);
  if (!TEXT_EXTENSIONS.has(ext) && !TEXT_EXTENSIONS.has(base)) {
    return null;
  }
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return null;
  }
}

function gitTrackedFiles() {
  try {
    const output = execFileSync("git", ["ls-files", "-z"], {
      cwd: ROOT,
      encoding: "utf8",
      maxBuffer: 20 * 1024 * 1024,
    });
    return output.split("\0").filter(Boolean).map(toPosix);
  } catch {
    return listFilesFallback(ROOT).map((filePath) => toPosix(path.relative(ROOT, filePath)));
  }
}

function listFilesFallback(dirPath) {
  const results = [];
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    if ([".git", "node_modules", "build", ".gradle", ".dart_tool", ".idea", ".vscode"].includes(entry.name)) {
      continue;
    }
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      results.push(...listFilesFallback(fullPath));
    } else {
      results.push(fullPath);
    }
  }
  return results;
}

function classifyFile(relPath) {
  const ext = path.extname(relPath).toLowerCase();
  const normalized = toPosix(relPath);
  const base = path.basename(normalized);

  if (
    CONFIG_FILE_NAMES.has(base) ||
    normalized.endsWith(".env.example") ||
    normalized.includes("/gradle/wrapper/gradle-wrapper.properties") ||
    normalized.includes("/app/src/main/AndroidManifest.xml")
  ) {
    return "config";
  }
  if (normalized.includes("/tests/") || normalized.endsWith(".test.ts")) {
    return "tests";
  }
  if (normalized.includes("/presentation/middleware/")) {
    return "middleware";
  }
  if (normalized.includes("/presentation/routes/") || normalized.includes("/presentation/controllers/")) {
    return "api";
  }
  if (
    normalized.includes("/db/") ||
    normalized.includes("/migrations/") ||
    normalized.includes("/repositories/") ||
    normalized.includes("/room/") ||
    normalized.endsWith("DatabaseHelper.kt") ||
    normalized.endsWith("Contract.kt") ||
    normalized.endsWith("AppCategoryMapping.kt")
  ) {
    return "db";
  }
  if (
    normalized.includes("/services/") ||
    normalized.includes("/jobs/") ||
    normalized.includes("/engine/") ||
    normalized.includes("/enforcement/") ||
    normalized.includes("/backend/sync/") ||
    normalized.includes("/backend/bridge/") ||
    normalized.includes("/backend/receivers/") ||
    normalized.includes("/backend/services/") ||
    normalized.endsWith("ApiClient.kt") ||
    normalized.endsWith("Models.kt")
  ) {
    return "services";
  }
  if (
    normalized.includes("/utils/") ||
    normalized.includes("/constants/") ||
    normalized.endsWith("PermissionUtils.kt") ||
    normalized.endsWith("GeneratedPluginRegistrant.java")
  ) {
    return "utils";
  }
  if (
    normalized.includes("google-services") ||
    normalized.includes("firebase") ||
    normalized.endsWith("generateKeys.js") ||
    normalized.endsWith("docker-compose.yml") ||
    normalized.endsWith("Dockerfile") ||
    normalized.endsWith("docker-compose.yaml") ||
    normalized.endsWith("auth_service.dart") ||
    normalized.endsWith("backend_service.dart") ||
    normalized.endsWith("api_service.dart")
  ) {
    return "integrations";
  }
  if (
    ext === ".ps1" ||
    ext === ".svg" ||
    ext === ".png" ||
    ext === ".docx" ||
    ext === ".jar" ||
    ext === ".keystore" ||
    ext === ".txt" ||
    normalized.startsWith(".github/") ||
    normalized.startsWith("docs/") ||
    normalized.startsWith("Misc/") ||
    normalized.startsWith("info word docs/") ||
    normalized.endsWith(".log")
  ) {
    return "misc";
  }
  return "core";
}

function summarizePurpose(relPath, content) {
  const normalized = toPosix(relPath);
  const base = path.basename(normalized);
  const ext = path.extname(normalized).toLowerCase();

  if (normalized === "apps/mobile/lib/main.dart") return "Flutter mobile application entry point.";
  if (normalized === "services/api/src/server.ts") return "Node.js HTTP server bootstrap and process lifecycle manager.";
  if (normalized === "services/api/src/app.ts") return "Express application assembler that wires middleware, services, and route trees.";
  if (normalized.endsWith("AndroidManifest.xml")) return "Android application manifest that declares components, permissions, and process-level configuration.";
  if (normalized.includes("/presentation/routes/")) return `Express route module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/presentation/controllers/")) return `HTTP controller module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/services/")) return `Service-layer module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/jobs/")) return `Scheduled or background job module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/migrations/")) return `Database migration script ${base} that changes the PostgreSQL schema or data.`;
  if (normalized.includes("/repositories/")) return `Repository module that encapsulates database access for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/room/")) return `Android Room persistence component for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/engine/")) return `Native Kotlin engine module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/enforcement/")) return `Native enforcement module for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/screens/")) return `Flutter screen widget for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/widgets/")) return `Reusable Flutter widget for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.includes("/constants/")) return `Shared Flutter configuration or styling constant file for ${base.replace(/\.[^.]+$/, "")}.`;
  if (normalized.startsWith("docs/")) return `Repository documentation artifact named ${base}.`;
  if (normalized.startsWith("Misc/")) return `Miscellaneous project artifact named ${base}.`;
  if (normalized.startsWith(".github/")) return `GitHub automation or contribution support file ${base}.`;
  if (normalized.endsWith("package.json")) return "Node.js package manifest describing scripts and dependencies.";
  if (normalized.endsWith("package-lock.json")) return "NPM lockfile pinning the resolved dependency graph.";
  if (normalized.endsWith("pubspec.yaml")) return "Flutter package manifest defining Dart dependencies, metadata, and assets.";
  if (normalized.endsWith("pubspec.lock")) return "Flutter lockfile pinning resolved Dart package versions.";
  if (normalized.endsWith(".svg")) return "Vector diagram asset.";
  if (normalized.endsWith(".png")) return "Raster image asset.";
  if (normalized.endsWith(".docx")) return "Binary Word document artifact included in the repository.";
  if (normalized.endsWith(".jar")) return "Third-party Gradle wrapper binary required to bootstrap Gradle.";
  if (normalized.endsWith(".keystore")) return "Android debug signing keystore.";
  if (normalized.endsWith(".log") || normalized.endsWith(".txt")) return "Text artifact, report, or captured build/runtime log.";
  if (normalized.endsWith(".ps1")) return "PowerShell automation script for local setup or runtime orchestration.";
  if (normalized.endsWith(".gradle")) return "Gradle build configuration file.";
  if (normalized.endsWith(".properties")) return "Properties configuration file.";
  if (normalized.endsWith(".yml") || normalized.endsWith(".yaml")) return "YAML configuration file.";
  if (normalized.endsWith(".sql")) return "SQL migration or schema definition file.";
  if (content) {
    const heading = content.split(/\r?\n/).find((line) => line.trim().startsWith("#"));
    if (heading) return heading.replace(/^#+\s*/, "").trim();
  }
  return `Repository file ${base}.`;
}

function detectTech(relPath, content, imports) {
  const normalized = toPosix(relPath);
  const ext = path.extname(normalized).toLowerCase();
  const externalImports = imports.external.map((item) => item.from);

  if (normalized.endsWith(".dart")) return ["Dart", "Flutter", ...dedupe(externalImports)];
  if (normalized.endsWith(".kt")) return ["Kotlin", "Android SDK", ...dedupe(externalImports)];
  if (normalized.endsWith(".java")) return ["Java", "Flutter Android embedding", ...dedupe(externalImports)];
  if (normalized.endsWith(".ts")) return ["TypeScript", "Node.js", ...dedupe(externalImports)];
  if (normalized.endsWith(".js")) return ["JavaScript", "Node.js", ...dedupe(externalImports)];
  if (normalized.endsWith(".sql")) return ["SQL", "PostgreSQL"];
  if (normalized.endsWith(".gradle")) return ["Gradle", "Android build system"];
  if (normalized.endsWith(".xml")) return ["XML", normalized.includes("AndroidManifest") ? "Android app manifest" : "Android resource XML"];
  if (normalized.endsWith(".yaml") || normalized.endsWith(".yml")) {
    if (normalized.includes("pubspec")) return ["YAML", "Flutter package configuration"];
    if (normalized.includes("docker-compose")) return ["YAML", "Docker Compose"];
    if (normalized.includes(".github/workflows")) return ["YAML", "GitHub Actions"];
    return ["YAML"];
  }
  if (normalized.endsWith(".properties")) return ["Java properties format"];
  if (normalized.endsWith(".ps1")) return ["PowerShell"];
  if (normalized.endsWith(".py")) return ["Python"];
  if (normalized.endsWith(".md")) return ["Markdown"];
  if (normalized.endsWith(".json")) return ["JSON"];
  if (normalized.endsWith(".docx")) return ["Microsoft Word document"];
  if (normalized.endsWith(".svg")) return ["SVG"];
  if (normalized.endsWith(".png")) return ["PNG image"];
  if (normalized.endsWith(".jar")) return ["Java archive"];
  if (normalized.endsWith(".bat")) return ["Batch script"];
  if (content && externalImports.length) return dedupe(externalImports);
  return [ext || "plain text"];
}

function parseImports(relPath, content) {
  if (!content) return { all: [], local: [], external: [] };
  const imports = [];
  const add = (from, raw) => {
    if (!from) return;
    const record = { from, raw };
    imports.push(record);
  };

  const jsImport = /\bimport\s+(?:[^'"]+?\s+from\s+)?["']([^"']+)["'];?/g;
  const jsRequire = /\brequire\(\s*["']([^"']+)["']\s*\)/g;
  const dartImport = /\bimport\s+['"]([^'"]+)['"];?/g;
  const kotlinImport = /^\s*import\s+([A-Za-z0-9_.*]+)/gm;

  for (const match of content.matchAll(jsImport)) add(match[1], match[0]);
  for (const match of content.matchAll(jsRequire)) add(match[1], match[0]);
  for (const match of content.matchAll(dartImport)) add(match[1], match[0]);
  for (const match of content.matchAll(kotlinImport)) add(match[1], match[0]);

  const local = [];
  const external = [];
  for (const item of imports) {
    if (
      item.from.startsWith(".") ||
      item.from.startsWith("/") ||
      item.from.startsWith("package:reclaim_mobile") ||
      item.from.startsWith("package:reclaim")
    ) {
      local.push(item);
    } else {
      external.push(item);
    }
  }
  return { all: dedupeObjects(imports, "from"), local: dedupeObjects(local, "from"), external: dedupeObjects(external, "from") };
}

function parseExports(relPath, content) {
  if (!content) return [];
  const ext = path.extname(relPath).toLowerCase();
  const exports = [];

  if (ext === ".ts" || ext === ".js") {
    for (const match of content.matchAll(/\bexport\s+(?:default\s+)?(?:class|function|const|let|var|async function|type|interface|enum)\s+([A-Za-z0-9_]+)/g)) {
      exports.push(match[1]);
    }
    for (const match of content.matchAll(/\bexport\s*\{([^}]+)\}/g)) {
      const names = match[1].split(",").map((part) => part.trim().split(/\s+as\s+/i)[0].trim()).filter(Boolean);
      exports.push(...names);
    }
    if (content.includes("export default")) {
      const defaultMatch = content.match(/\bexport\s+default\s+([A-Za-z0-9_]+)/);
      exports.push(defaultMatch ? `default (${defaultMatch[1]})` : "default export");
    }
  } else if (ext === ".dart") {
    const classes = Array.from(content.matchAll(/\bclass\s+([A-Za-z0-9_]+)/g)).map((match) => match[1]);
    exports.push(...classes);
    if (content.includes("main(")) exports.push("main");
  } else if (ext === ".kt" || ext === ".java") {
    const pkg = content.match(/^\s*package\s+([A-Za-z0-9_.]+)/m);
    if (pkg) exports.push(`package ${pkg[1]}`);
    const declarations = Array.from(content.matchAll(/\b(?:data\s+class|class|object|interface|enum\s+class)\s+([A-Za-z0-9_]+)/g)).map((match) => match[1]);
    exports.push(...declarations);
  } else if (ext === ".sql") {
    exports.push(...Array.from(content.matchAll(/\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z0-9_."-]+)/gi)).map((match) => match[1]));
  }

  return dedupe(exports);
}

function extractBlocks(content) {
  if (!content) return [];
  const lines = content.split(/\r?\n/);
  const markers = [];
  const pushMarker = (index, kind, label) => {
    if (index < 0 || index >= lines.length) return;
    markers.push({ index, kind, label });
  };

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line) continue;
    if (/^import\b/.test(line)) pushMarker(i, "imports", "Imports dependencies.");
    else if (/^(export\s+)?(async\s+)?function\b/.test(line)) pushMarker(i, "function", `Defines function ${extractName(line)}.`.trim());
    else if (/^(const|let|var)\s+[A-Za-z0-9_]+\s*=/.test(line)) pushMarker(i, "binding", `Initializes ${extractName(line)}.`.trim());
    else if (/^(export\s+)?class\b/.test(line)) pushMarker(i, "class", `Defines class ${extractClassName(line)}.`.trim());
    else if (/^(data\s+class|class|object|interface|enum\s+class)\b/.test(line)) pushMarker(i, "class", `Defines ${extractClassName(line)}.`.trim());
    else if (/^\s*fun\s+[A-Za-z0-9_]+\s*\(/.test(line)) pushMarker(i, "function", `Implements ${extractFunName(line)}.`.trim());
    else if (/^\s*router\.(get|post|put|patch|delete)\(/.test(line)) {
      const route = line.match(/router\.(get|post|put|patch|delete)\(\s*["'`]([^"'`]+)/);
      pushMarker(i, "route", route ? `Registers ${route[1].toUpperCase()} ${route[2]}.` : "Registers an Express route.");
    } else if (/^\s*app\.use\(/.test(line)) {
      pushMarker(i, "middleware", "Attaches middleware or sub-router.");
    } else if (/^\s*(CREATE|ALTER|INSERT|UPDATE|DELETE)\b/i.test(line)) {
      pushMarker(i, "sql", `${line.split(/\s+/).slice(0, 4).join(" ")} statement.`.trim());
    } else if (/^\s*void\s+main\s*\(/.test(line) || /^\s*fun\s+main\s*\(/.test(line)) {
      pushMarker(i, "entry", "Entry point function.");
    } else if (/^\s*runApp\(/.test(line)) {
      pushMarker(i, "entry", "Launches the Flutter widget tree.");
    }
  }

  markers.sort((a, b) => a.index - b.index);
  const deduped = markers.filter((marker, index) => index === 0 || marker.index !== markers[index - 1].index);

  if (deduped.length === 0) {
    return summarizeByChunk(lines);
  }

  const blocks = [];
  for (let i = 0; i < deduped.length; i += 1) {
    const start = deduped[i].index + 1;
    const end = (i + 1 < deduped.length ? deduped[i + 1].index : lines.length) || lines.length;
    blocks.push({
      start,
      end,
      description: deduped[i].label,
    });
  }
  return blocks;
}

function summarizeByChunk(lines) {
  const blocks = [];
  const chunkSize = 25;
  for (let i = 0; i < lines.length; i += chunkSize) {
    const start = i + 1;
    const end = Math.min(lines.length, i + chunkSize);
    const first = (lines[i] || "").trim();
    blocks.push({
      start,
      end,
      description: first ? `General logic and declarations around "${truncate(first, 80)}".` : "Whitespace or separator region.",
    });
  }
  return blocks;
}

function extractName(line) {
  const match = line.match(/(?:function|const|let|var)\s+([A-Za-z0-9_]+)/);
  return match ? match[1] : "anonymous symbol";
}

function extractClassName(line) {
  const match = line.match(/\b(?:class|object|interface|enum\s+class|data\s+class)\s+([A-Za-z0-9_]+)/);
  return match ? match[1] : "unnamed type";
}

function extractFunName(line) {
  const match = line.match(/\bfun\s+([A-Za-z0-9_]+)/);
  return match ? match[1] : "unnamed function";
}

function parseBraceLanguage(relPath, content) {
  const classes = [];
  const functions = [];
  const constants = [];
  if (!content) return { classes, functions, constants };

  const ext = path.extname(relPath).toLowerCase();

  for (const match of content.matchAll(/\b(?:export\s+)?class\s+([A-Za-z0-9_]+)(?:\s+extends\s+([A-Za-z0-9_]+))?/g)) {
    classes.push(parseClassBody(content, match.index, match[0], match[1], match[2] || null, ext));
  }
  for (const match of content.matchAll(/\b(?:data\s+class|class|object|interface|enum\s+class)\s+([A-Za-z0-9_]+)(?:\s*:\s*([^{\n]+))?/g)) {
    classes.push(parseClassBody(content, match.index, match[0], match[1], (match[2] || "").trim() || null, ext));
  }
  for (const match of content.matchAll(/\bclass\s+([A-Za-z0-9_]+)(?:\s+extends\s+([A-Za-z0-9_]+))?/g)) {
    if (ext === ".dart") classes.push(parseClassBody(content, match.index, match[0], match[1], match[2] || null, ext));
  }

  for (const match of content.matchAll(/\b(?:export\s+)?(?:async\s+)?function\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)/g)) {
    functions.push({
      name: match[1],
      signature: `${match[1]}(${normalizeParams(match[2])})`,
      details: "Top-level function declaration.",
    });
  }
  for (const match of content.matchAll(/^\s*fun\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)(?::\s*([A-Za-z0-9_<>,.? ]+))?/gm)) {
    functions.push({
      name: match[1],
      signature: `${match[1]}(${normalizeParams(match[2])})${match[3] ? `: ${match[3].trim()}` : ""}`,
      details: "Kotlin function declaration.",
    });
  }
  for (const match of content.matchAll(/^\s*(?:Future<[^>]+>|FutureOr<[^>]+>|Widget|void|bool|int|double|String|dynamic|List<[^>]+>|Map<[^>]+>|Set<[^>]+>|[A-Z][A-Za-z0-9_<>,? ]+)\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)/gm)) {
    functions.push({
      name: match[1],
      signature: `${match[1]}(${normalizeParams(match[2])})`,
      details: "Dart function or method declaration.",
    });
  }

  for (const match of content.matchAll(/^\s*(?:export\s+)?const\s+([A-Za-z0-9_]+)/gm)) {
    constants.push(match[1]);
  }
  for (const match of content.matchAll(/^\s*private\s+const\s+val\s+([A-Za-z0-9_]+)/gm)) {
    constants.push(match[1]);
  }
  for (const match of content.matchAll(/^\s*const\s+([A-Za-z0-9_]+)/gm)) {
    constants.push(match[1]);
  }

  return {
    classes: dedupeByName(classes),
    functions: dedupeByName(functions),
    constants: dedupe(constants),
  };
}

function parseClassBody(content, matchIndex, header, name, inherits, ext) {
  const startBrace = content.indexOf("{", matchIndex);
  if (startBrace === -1) {
    return {
      name,
      inherits,
      attributes: [],
      methods: [],
      details: ext === ".kt" && header.startsWith("object ") ? "Kotlin singleton object." : "Type declaration.",
    };
  }
  let depth = 0;
  let endBrace = startBrace;
  for (let i = startBrace; i < content.length; i += 1) {
    const ch = content[i];
    if (ch === "{") depth += 1;
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        endBrace = i;
        break;
      }
    }
  }
  const body = content.slice(startBrace + 1, endBrace);
  const attributes = [];
  const methods = [];

  if (ext === ".kt" || ext === ".java") {
    for (const match of body.matchAll(/^\s*(?:@Volatile\s+)?(?:private|public|protected|internal)?\s*(?:lateinit\s+)?(?:val|var)\s+([A-Za-z0-9_]+)(?::\s*([^=]+))?/gm)) {
      attributes.push({
        name: match[1],
        type: (match[2] || "").trim() || "inferred",
      });
    }
    for (const match of body.matchAll(/^\s*fun\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)(?::\s*([A-Za-z0-9_<>,.? ]+))?/gm)) {
      methods.push({
        name: match[1],
        signature: `${match[1]}(${normalizeParams(match[2])})${match[3] ? `: ${match[3].trim()}` : ""}`,
      });
    }
  } else if (ext === ".dart") {
    for (const match of body.matchAll(/^\s*(?:final|late|static|const)?\s*(?:[A-Za-z0-9_<>,? ]+)\s+([A-Za-z0-9_]+)\s*(?:=|;)/gm)) {
      attributes.push({
        name: match[1],
        type: "Dart field or state member",
      });
    }
    for (const match of body.matchAll(/^\s*(?:@override\s+)?(?:static\s+)?(?:Future<[^>]+>|FutureOr<[^>]+>|Widget|void|bool|int|double|String|dynamic|List<[^>]+>|Map<[^>]+>|Set<[^>]+>|[A-Z][A-Za-z0-9_<>,? ]+)\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)/gm)) {
      methods.push({
        name: match[1],
        signature: `${match[1]}(${normalizeParams(match[2])})`,
      });
    }
  } else {
    for (const match of body.matchAll(/^\s*(?:public|private|protected|readonly|static)?\s*([A-Za-z0-9_]+)\s*[:=]/gm)) {
      attributes.push({
        name: match[1],
        type: "JS/TS field or property",
      });
    }
    for (const match of body.matchAll(/^\s*(?:public|private|protected|static|async|get|set)?\s*([A-Za-z0-9_]+)\s*\(([^)]*)\)\s*[:{]/gm)) {
      if (!["if", "for", "while", "switch", "catch"].includes(match[1])) {
        methods.push({
          name: match[1],
          signature: `${match[1]}(${normalizeParams(match[2])})`,
        });
      }
    }
  }

  return {
    name,
    inherits,
    attributes: dedupeByName(attributes),
    methods: dedupeByName(methods),
    details: ext === ".kt" && header.startsWith("object ") ? "Kotlin singleton object." : "Type declaration with encapsulated behavior.",
  };
}

function normalizeParams(params) {
  return params
    .split(",")
    .map((part) => part.trim().replace(/\s+/g, " "))
    .filter(Boolean)
    .join(", ");
}

function parseRoutes(content) {
  if (!content) return [];
  const routes = [];
  const regex = /router\.(get|post|put|patch|delete)\(\s*["'`]([^"'`]+)["'`]([\s\S]*?)(?=\n\s*router\.(?:get|post|put|patch|delete)\(|\n\s*return router|\n\s*return;|\n\})/g;
  for (const match of content.matchAll(regex)) {
    const method = match[1].toUpperCase();
    const routePath = match[2];
    const block = match[0];
    const validations = Array.from(block.matchAll(/([A-Za-z0-9_]+Schema)\.parse/g)).map((m) => m[1]);
    if (block.includes("z.object(")) validations.push("inline z.object validation");
    const serviceCalls = Array.from(block.matchAll(/\bservice\.([A-Za-z0-9_]+)/g)).map((m) => `service.${m[1]}`);
    const statuses = Array.from(block.matchAll(/response\.status\((\d+)\)/g)).map((m) => m[1]);
    const middleware = [];
    if (block.includes("rateLimiter(")) middleware.push("rateLimiter");
    if (block.includes("authMiddleware")) middleware.push("authMiddleware");
    routes.push({
      method,
      path: routePath,
      validations: dedupe(validations),
      serviceCalls: dedupe(serviceCalls),
      statuses: dedupe(statuses),
      middleware: dedupe(middleware),
    });
  }
  return routes;
}

function parseSql(content) {
  if (!content) return { tables: [], statements: [] };
  const tables = [];
  for (const match of content.matchAll(/\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z0-9_."-]+)\s*\(([\s\S]*?)\);/gi)) {
    const tableName = match[1].replace(/"/g, "");
    const fields = match[2]
      .split(/\r?\n/)
      .map((line) => line.trim().replace(/,$/, ""))
      .filter((line) => line && !/^(CONSTRAINT|PRIMARY KEY|FOREIGN KEY|UNIQUE|CHECK)\b/i.test(line))
      .map((line) => line.split(/\s+/).slice(0, 2).join(" "));
    tables.push({ tableName, fields });
  }
  const statements = Array.from(content.matchAll(/\b(CREATE TABLE|ALTER TABLE|CREATE INDEX|INSERT INTO|UPDATE|DELETE FROM)\b/gi)).map((m) => m[1].toUpperCase());
  return { tables, statements: dedupe(statements) };
}

function parseSimpleConfig(relPath, content) {
  if (!content) return [];
  const normalized = toPosix(relPath);
  const ext = path.extname(normalized).toLowerCase();
  const entries = [];

  if (normalized.endsWith(".env.example")) {
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
      const idx = trimmed.indexOf("=");
      entries.push({ key: trimmed.slice(0, idx), value: trimmed.slice(idx + 1) });
    }
    return entries;
  }

  if (normalized.endsWith("env.ts")) {
    for (const match of content.matchAll(/process\.env\.([A-Z0-9_]+)/g)) {
      entries.push({ key: match[1], value: "Referenced in env.ts" });
    }
    return dedupeObjects(entries, "key");
  }

  if (ext === ".properties") {
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
      const idx = trimmed.indexOf("=");
      entries.push({ key: trimmed.slice(0, idx).trim(), value: trimmed.slice(idx + 1).trim() });
    }
    return entries;
  }

  if (ext === ".yaml" || ext === ".yml") {
    for (const line of content.split(/\r?\n/)) {
      if (/^\s*[A-Za-z0-9_.-]+:\s*/.test(line)) {
        const match = line.match(/^\s*([A-Za-z0-9_.-]+):\s*(.*)$/);
        if (match) entries.push({ key: match[1], value: match[2] || "" });
      }
    }
    return entries;
  }

  if (ext === ".json") {
    try {
      const json = JSON.parse(content);
      flattenJson(json).forEach((item) => entries.push(item));
      return entries;
    } catch {
      return [];
    }
  }

  if (ext === ".gradle") {
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      const match = trimmed.match(/^([A-Za-z0-9_.-]+)\s+["']?([^"']+)["']?$/);
      if (match && !trimmed.startsWith("//") && !trimmed.startsWith("implementation")) {
        entries.push({ key: match[1], value: match[2] });
      }
    }
    return entries.slice(0, 80);
  }

  return entries;
}

function flattenJson(obj, prefix = "") {
  const results = [];
  if (Array.isArray(obj)) {
    obj.forEach((value, index) => {
      results.push(...flattenJson(value, `${prefix}[${index}]`));
    });
    return results;
  }
  if (obj && typeof obj === "object") {
    for (const [key, value] of Object.entries(obj)) {
      const nextKey = prefix ? `${prefix}.${key}` : key;
      if (value && typeof value === "object") {
        results.push(...flattenJson(value, nextKey));
      } else {
        results.push({ key: nextKey, value: String(value) });
      }
    }
    return results;
  }
  if (prefix) results.push({ key: prefix, value: String(obj) });
  return results;
}

function analyzeFile(relPath) {
  const fullPath = path.join(ROOT, relPath);
  const stat = fs.statSync(fullPath);
  const content = readTextMaybe(fullPath);
  const imports = parseImports(relPath, content);
  const exportsList = parseExports(relPath, content);
  const braceAnalysis = parseBraceLanguage(relPath, content);
  const routeInfo = parseRoutes(content);
  const sqlInfo = parseSql(content);
  const configEntries = parseSimpleConfig(relPath, content);
  const logicBlocks = extractBlocks(content);
  const chapter = classifyFile(relPath);

  return {
    relPath: toPosix(relPath),
    fullPath,
    size: stat.size,
    lineCount: content ? content.split(/\r?\n/).length : null,
    chapter,
    content,
    purpose: summarizePurpose(relPath, content),
    imports,
    exportsList,
    classes: braceAnalysis.classes,
    functions: braceAnalysis.functions,
    constants: braceAnalysis.constants,
    routes: routeInfo,
    sql: sqlInfo,
    configEntries,
    logicBlocks,
    tech: detectTech(relPath, content, imports),
    notes: collectNotes(relPath, content),
  };
}

function collectNotes(relPath, content) {
  const notes = [];
  if (!content) {
    notes.push("Binary or opaque artifact: source-level line logic is not inspectable without format-specific tooling.");
    return notes;
  }
  if (/TODO|FIXME|HACK|UNCLEAR/gi.test(content)) {
    const hits = Array.from(content.matchAll(/(TODO|FIXME|HACK|UNCLEAR)[: ]?(.*)/gi))
      .slice(0, 6)
      .map((match) => `${match[1].toUpperCase()}: ${truncate(match[2].trim() || "marker present", 100)}`);
    notes.push(...hits);
  }
  if (relPath.endsWith("GeneratedPluginRegistrant.java")) {
    notes.push("Generated Flutter embedding file; changes are usually overwritten by Flutter tooling.");
  }
  if (relPath.endsWith(".lock") || relPath.endsWith("package-lock.json")) {
    notes.push("Lockfile: designed for deterministic dependency resolution rather than manual editing.");
  }
  if (relPath.endsWith(".jar") || relPath.endsWith(".keystore")) {
    notes.push("Opaque binary artifact; treat it as an externally produced dependency or credential-bearing file.");
  }
  return dedupe(notes);
}

function buildDependencyReference(files) {
  const deps = [];

  const rootPackage = readJsonIfExists(path.join(ROOT, "package.json"));
  const apiPackage = readJsonIfExists(path.join(ROOT, "services", "api", "package.json"));
  const pubspec = readYamlLike(path.join(ROOT, "apps", "mobile", "pubspec.yaml"));
  const mobileGradle = readTextMaybe(path.join(ROOT, "apps", "mobile", "android", "app", "build.gradle"));
  const nativeGradle = readTextMaybe(path.join(ROOT, "apps", "android-native", "app", "build.gradle"));

  if (rootPackage) {
    addPackageDeps(deps, "Root NPM", rootPackage.dependencies || {}, files);
    addPackageDeps(deps, "Root NPM dev", rootPackage.devDependencies || {}, files);
  }
  if (apiPackage) {
    addPackageDeps(deps, "API NPM", apiPackage.dependencies || {}, files);
    addPackageDeps(deps, "API NPM dev", apiPackage.devDependencies || {}, files);
  }
  if (pubspec) {
    addPackageDeps(deps, "Flutter pub", pubspec.dependencies || {}, files, "dart");
    addPackageDeps(deps, "Flutter pub dev", pubspec.dev_dependencies || {}, files, "dart");
  }

  for (const [label, text] of [
    ["Mobile Gradle", mobileGradle],
    ["Native Gradle", nativeGradle],
  ]) {
    if (!text) continue;
    for (const match of text.matchAll(/\b(?:implementation|ksp|platform)\s+(?:platform\()?"([^"]+)"/g)) {
      const notation = match[1];
      const name = notation.split(":").slice(0, 2).join(":");
      const version = notation.split(":")[2] || "managed by BoM or variable";
      deps.push({
        ecosystem: label,
        name,
        version,
        why: `Declared in ${label} build.gradle.`,
        files: guessAndroidUsageFiles(name, files),
      });
    }
  }

  return deps.sort((a, b) => a.name.localeCompare(b.name));
}

function addPackageDeps(target, ecosystem, depMap, files, mode = "node") {
  for (const [name, version] of Object.entries(depMap)) {
    target.push({
      ecosystem,
      name,
      version: typeof version === "string" ? version : JSON.stringify(version),
      why: explainDependency(name),
      files: findUsageFiles(name, files, mode),
    });
  }
}

function explainDependency(name) {
  const known = {
    express: "HTTP server and routing layer for the API.",
    zod: "Input schema validation.",
    pg: "PostgreSQL client access.",
    "firebase-admin": "Server-side Firebase token verification.",
    jsonwebtoken: "JWT creation and verification.",
    winston: "Structured logging.",
    nodemailer: "Outbound email delivery.",
    cors: "Cross-origin request handling.",
    helmet: "Security headers.",
    "express-rate-limit": "Basic request throttling.",
    "node-cron": "Background scheduling.",
    flutter: "Flutter SDK runtime.",
    shared_preferences: "On-device key-value storage.",
    http: "Simple HTTP client in Flutter.",
    dio: "Richer HTTP client in Flutter.",
    firebase_core: "Firebase initialization in Flutter.",
    firebase_messaging: "Push messaging.",
    firebase_auth: "Client authentication.",
    "google_sign_in": "Google sign-in flow.",
    "flutter_secure_storage": "Secure client-side storage.",
    "androidx.room:room-runtime": "Android Room ORM runtime.",
    "androidx.room:room-ktx": "Kotlin extensions for Room.",
    "androidx.work:work-runtime-ktx": "Background work scheduling.",
  };
  return known[name] || "Direct dependency declared by the project.";
}

function guessAndroidUsageFiles(notation, files) {
  const lower = notation.toLowerCase();
  let probes = [];
  if (lower.includes("room")) probes = ["room", "Dao", "Entity", "LocalDatabase"];
  else if (lower.includes("firebase")) probes = ["Firebase", "Messaging"];
  else if (lower.includes("work-runtime")) probes = ["Worker"];
  else if (lower.includes("material")) probes = ["material", "AppCompat"];
  else probes = [notation.split(":").pop().replace(/[-.]/g, "")];

  const results = [];
  for (const file of files) {
    if (!file.content) continue;
    if (probes.some((probe) => file.content.toLowerCase().includes(probe.toLowerCase()))) {
      results.push(file.relPath);
    }
  }
  return results.slice(0, 8);
}

function findUsageFiles(depName, files, mode = "node") {
  const hits = [];
  const pattern =
    mode === "dart"
      ? new RegExp(`package:${escapeRegex(depName)}(?:/|['"])`, "i")
      : new RegExp(`(?:from|require|import)\\s*[^\\n]*["']${escapeRegex(depName)}(?:/|["'])`, "i");
  for (const file of files) {
    if (!file.content) continue;
    if (pattern.test(file.content)) hits.push(file.relPath);
  }
  return hits.slice(0, 12);
}

function buildGlossary(files) {
  const glossary = [
    ["API", "Application Programming Interface; in this repo it usually means the Express backend."],
    ["CORS", "Cross-Origin Resource Sharing; browser rule set controlled by the backend."],
    ["DAO", "Data Access Object; Room interface that reads and writes local Android tables."],
    ["Drift", "Behavioral state used by ReClaim to describe cognitive distraction or fragmentation."],
    ["FCM", "Firebase Cloud Messaging; push notification transport used by mobile and backend notification flows."],
    ["JWT", "JSON Web Token used for backend session authentication."],
    ["OTP", "One-time password used for uninstall or override confirmation flows."],
    ["PRD", "Product Requirements Document."],
    ["Room", "Android persistence library built on SQLite."],
    ["SafeCode", "In-app override code used by the enforcement layer."],
    ["TRD", "Technical Requirements Document."],
    ["Usage Stats", "Android usage history exposed by UsageStatsManager."],
    ["WorkManager", "Android API for scheduled or deferred background tasks."],
    ["Zod", "TypeScript validation library used on HTTP payloads."],
  ];

  const seen = new Set(glossary.map(([term]) => term));
  for (const file of files) {
    if (!file.content) continue;
    const tokens = file.content.match(/\b[A-Z][A-Z0-9_]{2,}\b/g) || [];
    for (const token of tokens) {
      if (seen.has(token)) continue;
      if (["TODO", "FIXME", "HTTP", "JSON", "UUID", "SQL", "XML", "SDK", "JWT"].includes(token)) continue;
      seen.add(token);
      glossary.push([token, `Acronym or constant token present in the codebase; inspect files containing "${token}" for repo-specific meaning.`]);
      if (glossary.length > 35) break;
    }
    if (glossary.length > 35) break;
  }
  return glossary.sort((a, b) => a[0].localeCompare(b[0]));
}

function readJsonIfExists(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function readYamlLike(filePath) {
  const text = readTextMaybe(filePath);
  if (!text) return null;
  const root = {};
  let currentSection = null;
  for (const rawLine of text.split(/\r?\n/)) {
    if (!rawLine.trim() || rawLine.trim().startsWith("#")) continue;
    const topMatch = rawLine.match(/^([A-Za-z0-9_.-]+):\s*(.*)$/);
    if (topMatch && !rawLine.startsWith(" ")) {
      const key = topMatch[1];
      const value = topMatch[2];
      if (!value) {
        root[key] = {};
        currentSection = key;
      } else {
        root[key] = value;
        currentSection = key;
      }
      continue;
    }
    const nestedMatch = rawLine.match(/^\s{2}([A-Za-z0-9_.-]+):\s*(.*)$/);
    if (nestedMatch && currentSection && root[currentSection] && typeof root[currentSection] === "object") {
      root[currentSection][nestedMatch[1]] = nestedMatch[2];
    }
  }
  return root;
}

function dedupe(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function dedupeByName(values) {
  const map = new Map();
  for (const value of values) {
    if (!value || !value.name) continue;
    if (!map.has(value.name)) map.set(value.name, value);
  }
  return Array.from(map.values());
}

function dedupeObjects(values, key) {
  const map = new Map();
  for (const value of values) {
    if (!value || !value[key]) continue;
    if (!map.has(value[key])) map.set(value[key], value);
  }
  return Array.from(map.values());
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function truncate(value, maxLength) {
  if (!value) return value;
  return value.length <= maxLength ? value : `${value.slice(0, maxLength - 3)}...`;
}

function fileTreeSummary(files) {
  const directories = new Map();
  for (const file of files) {
    const top = file.relPath.split("/")[0];
    directories.set(top, (directories.get(top) || 0) + 1);
  }
  return Array.from(directories.entries())
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([dir, count]) => `- ${dir}: ${count} tracked files under this top-level area.`);
}

function buildIndexSection(files) {
  const lines = [];
  lines.push("# INDEX");
  lines.push("");
  lines.push("## Table of Contents");
  lines.push("1. CHAPTER 0: PROJECT OVERVIEW");
  lines.push("2. CHAPTER 1: CONFIGURATION & ENVIRONMENT");
  lines.push("3. CHAPTER 2: CORE MODULES");
  lines.push("4. CHAPTER 3: APIs & ROUTES");
  lines.push("5. CHAPTER 4: DATABASE LAYER");
  lines.push("6. CHAPTER 5: SERVICES & BUSINESS LOGIC");
  lines.push("7. CHAPTER 6: UTILITIES & HELPERS");
  lines.push("8. CHAPTER 7: MIDDLEWARE & INTERCEPTORS");
  lines.push("9. CHAPTER 8: INTEGRATIONS & THIRD-PARTY SERVICES");
  lines.push("10. CHAPTER 9: TESTS");
  lines.push("11. CHAPTER 10: SCRIPTS & MISCELLANEOUS");
  lines.push("12. CHAPTER 11: DEPENDENCY REFERENCE");
  lines.push("13. CHAPTER 12: GLOSSARY");
  lines.push("");
  lines.push("## Chapter -> File Index");
  for (const chapter of CHAPTERS) {
    const scoped = chapterFiles(files, chapter.key);
    lines.push(`### ${chapter.title}`);
    lines.push(`Total files: ${scoped.length}`);
    for (const file of scoped) {
      lines.push(`- ${file.relPath}`);
    }
    lines.push("");
  }
  lines.push("## Alphabetical File Index");
  const sorted = [...files].sort((a, b) => a.relPath.localeCompare(b.relPath));
  for (const file of sorted) {
    lines.push(`- ${file.relPath}`);
  }
  lines.push("");
  return lines.join("\n");
}

function chapterFiles(files, chapterKey) {
  return files.filter((file) => file.chapter === chapterKey).sort((a, b) => a.relPath.localeCompare(b.relPath));
}

function markdownEscape(text) {
  return String(text).replace(/\|/g, "\\|");
}

function renderFileSection(file) {
  const lines = [];
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push(`📄 FILE: ${file.relPath}`);
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push(`📌 PURPOSE: ${file.purpose}`);
  lines.push(`🔧 TECH USED: ${file.tech.join(", ") || "UNCLEAR: no text-readable tech markers detected."}`);
  lines.push(`📦 IMPORTS: ${file.imports.all.length ? file.imports.all.map((item) => item.from).join(", ") : "None or binary file."}`);
  lines.push(`📤 EXPORTS: ${file.exportsList.length ? file.exportsList.join(", ") : "No explicit export surface detected."}`);
  lines.push(`📊 FILE FACTS: size=${file.size} bytes${file.lineCount ? `, lines=${file.lineCount}` : ""}`);

  if (file.classes.length) {
    lines.push("");
    lines.push("🏛️ CLASSES:");
    for (const cls of file.classes) {
      lines.push(`  ┌─ ${cls.name}`);
      lines.push(`  │  ├─ Purpose: ${cls.details}`);
      lines.push(`  │  ├─ Inherits: ${cls.inherits || "None detected."}`);
      lines.push("  │  ├─ ATTRIBUTES:");
      if (cls.attributes.length) {
        for (const attr of cls.attributes) {
          lines.push(`  │  │   • ${attr.name} (${attr.type || "type not explicit"}) — stores state or configuration used by ${cls.name}.`);
        }
      } else {
        lines.push("  │  │   • None detected by static scan.");
      }
      lines.push("  │  └─ METHODS:");
      if (cls.methods.length) {
        for (const method of cls.methods) {
          lines.push(`  │      • ${method.signature}`);
          lines.push("  │        → Static scan indicates method logic is implemented inside the class body.");
        }
      } else {
        lines.push("  │      • No methods detected by static scan.");
      }
    }
  }

  if (file.functions.length) {
    lines.push("");
    lines.push("⚙️ FUNCTIONS:");
    for (const fn of file.functions) {
      lines.push(`  • ${fn.signature}`);
      lines.push(`    Logic: ${fn.details}`);
    }
  }

  if (file.constants.length) {
    lines.push("");
    lines.push(`🔣 CONSTANTS / ENUM-LIKE SYMBOLS: ${file.constants.join(", ")}`);
  }

  if (file.routes.length) {
    lines.push("");
    lines.push("🌐 ROUTES / ENDPOINTS:");
    for (const route of file.routes) {
      lines.push(`  • ${route.method} ${route.path}`);
      lines.push(`    Validation: ${route.validations.join(", ") || "No explicit schema parse detected in static scan."}`);
      lines.push(`    Middleware: ${route.middleware.join(", ") || "Router-level or app-level middleware only."}`);
      lines.push(`    Service Calls: ${route.serviceCalls.join(", ") || "No service.* call detected in this block."}`);
      lines.push(`    Status Codes Seen: ${route.statuses.join(", ") || "Implicit default success/error flow."}`);
    }
  }

  if (file.sql.tables.length) {
    lines.push("");
    lines.push("🗄️ DATABASE OBJECTS:");
    for (const table of file.sql.tables) {
      lines.push(`  • Table: ${table.tableName}`);
      lines.push(`    Fields seen: ${table.fields.join(", ") || "UNCLEAR: fields not parsed cleanly."}`);
    }
  }
  if (file.sql.statements.length) {
    lines.push(`  • Statement types: ${file.sql.statements.join(", ")}`);
  }

  if (file.configEntries.length) {
    lines.push("");
    lines.push("⚙️ CONFIG KEYS / VARIABLES:");
    for (const entry of file.configEntries.slice(0, 60)) {
      lines.push(`  • ${entry.key} = ${entry.value || "(empty/default not explicit)"}`);
    }
    if (file.configEntries.length > 60) {
      lines.push(`  • ... ${file.configEntries.length - 60} additional keys omitted from inline view to keep this section readable.`);
    }
  }

  if (file.logicBlocks.length) {
    lines.push("");
    lines.push("🧭 START-TO-FINISH LOGIC WALKTHROUGH:");
    for (const block of file.logicBlocks.slice(0, 40)) {
      lines.push(`  • Lines ${block.start}-${block.end}: ${block.description}`);
    }
    if (file.logicBlocks.length > 40) {
      lines.push(`  • Additional blocks detected: ${file.logicBlocks.length - 40}`);
    }
  }

  const connections = dedupe([
    ...file.imports.local.map((item) => item.from),
    ...file.routes.flatMap((route) => route.serviceCalls),
  ]);
  lines.push("");
  lines.push(`🔗 CONNECTS TO: ${connections.length ? connections.join(", ") : "No direct local links detected by static scan."}`);
  lines.push(`⚠️ NOTES: ${file.notes.length ? file.notes.join(" | ") : "No special warnings detected."}`);
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("");
  return lines.join("\n");
}

function buildOverview(files) {
  const lines = [];
  lines.push("# CHAPTER 0: PROJECT OVERVIEW");
  lines.push("");
  lines.push("## Project name, purpose, and problem it solves");
  lines.push("ReClaim is a multi-surface digital focus and behavioral enforcement project. The repo combines a Flutter mobile shell, a native Android app, and a TypeScript backend API to monitor usage, compute attention-related metrics, and enforce limits or interventions.");
  lines.push("");
  lines.push("Problem framing inferred from the codebase:");
  lines.push("- The mobile layers gather device-side usage and enforce daily/focus rules.");
  lines.push("- The backend persists analytics, policy, social, reflection, friction, drift, and notification data.");
  lines.push("- The repo includes product, architecture, security, and study-guide documents that support delivery and evaluation.");
  lines.push("");
  lines.push("## High-level architecture diagram (ASCII)");
  lines.push("```text");
  lines.push("+----------------------+        +---------------------------+");
  lines.push("| Flutter app          | <----> | Kotlin bridge / Android  |");
  lines.push("| apps/mobile/lib      |        | apps/mobile/android      |");
  lines.push("+----------+-----------+        +-------------+-------------+");
  lines.push("           |                                      |");
  lines.push("           v                                      v");
  lines.push("+----------------------+        +---------------------------+");
  lines.push("| Backend API          | <----> | PostgreSQL schema + local |");
  lines.push("| services/api/src     |        | persistence layers        |");
  lines.push("+----------------------+        +---------------------------+");
  lines.push("```");
  lines.push("");
  lines.push("## Tech stack summary");
  lines.push("- Languages: TypeScript, JavaScript, Dart, Kotlin, Java, SQL, PowerShell, Python, YAML, XML, Markdown.");
  lines.push("- Backend: Node.js, Express, Zod, PostgreSQL, Winston, Firebase Admin, Nodemailer.");
  lines.push("- Mobile UI: Flutter, Firebase Core/Auth/Messaging, Dio, SharedPreferences, fl_chart.");
  lines.push("- Android native: Kotlin, Android Accessibility APIs, WorkManager, Room, UsageStatsManager, AlarmManager.");
  lines.push("- Tooling: Gradle, Docker Compose, GitHub Actions, PowerShell setup scripts.");
  lines.push("");
  lines.push("## Folder/module structure");
  lines.push(...fileTreeSummary(files));
  lines.push("");
  lines.push("## Entry points");
  lines.push("- `apps/mobile/lib/main.dart`: Flutter runtime entry point.");
  lines.push("- `services/api/src/server.ts`: backend runtime entry point.");
  lines.push("- `apps/android-native/app/src/main/kotlin/com/minimalism/focus/MainActivity.kt`: native Android UI entry point.");
  lines.push("- `reclaim-setup.ps1` and `reclaim-run.ps1`: local orchestration entry points.");
  lines.push("");
  lines.push("## Data flow overview");
  lines.push("1. Flutter starts, initializes Firebase, and negotiates backend auth.");
  lines.push("2. Kotlin/Android components observe app usage, local focus state, and enforcement conditions.");
  lines.push("3. Local mobile services bridge data between Flutter, Android, and backend endpoints.");
  lines.push("4. Express routes validate requests, delegate to services/repositories, and persist to PostgreSQL.");
  lines.push("5. Background jobs and workers sync analytics, reflection, craving, friction, and notification state.");
  lines.push("");
  lines.push("## Key design patterns used");
  lines.push("- Repository pattern: `services/api/src/db/repositories/*`.");
  lines.push("- Service layer: `services/api/src/services/*`, mobile service files, and native engines.");
  lines.push("- Middleware chain: Express middleware under `services/api/src/presentation/middleware`.");
  lines.push("- Builder/factory style app assembly: `buildApp`, `buildAnalyticsRoutes`, `buildPolicyRoutes`, and similar functions.");
  lines.push("- Singleton object pattern: Kotlin `object` declarations such as `EnforcementManager`.");
  lines.push("- DAO pattern: Android Room DAO files under `apps/mobile/android/app/src/main/kotlin/.../room`.");
  lines.push("");
  lines.push("## Quick Reference Card");
  lines.push(`- Total tracked files in scope: ${files.length}`);
  lines.push(`- Primary runtimes: Flutter mobile app, native Android app, Node.js API`);
  lines.push(`- Primary persistence surfaces: PostgreSQL, Android local persistence, SharedPreferences/Room-like local stores`);
  lines.push("");
  return lines.join("\n");
}

function buildChapter(chapterMeta, files) {
  const scopedFiles = chapterFiles(files, chapterMeta.key);
  const lines = [];
  lines.push(`# ${chapterMeta.title}`);
  lines.push("");
  lines.push(`Files in this chapter: ${scopedFiles.length}`);
  lines.push("");
  for (const file of scopedFiles) {
    lines.push(renderFileSection(file));
  }
  lines.push("## Quick Reference Card");
  lines.push(`- File count: ${scopedFiles.length}`);
  lines.push(`- Representative files: ${scopedFiles.slice(0, 8).map((file) => `\`${file.relPath}\``).join(", ") || "None"}`);
  lines.push("");
  return lines.join("\n");
}

function buildDependencyChapter(depReference) {
  const lines = [];
  lines.push("# CHAPTER 11: DEPENDENCY REFERENCE");
  lines.push("");
  lines.push("This chapter lists direct dependencies declared by the manifests in this repository. Lockfiles are documented separately as resolution artifacts.");
  lines.push("");
  for (const dep of depReference) {
    lines.push(`- ${dep.name} (${dep.version}) [${dep.ecosystem}]`);
    lines.push(`  Why: ${dep.why}`);
    lines.push(`  Used by: ${dep.files.length ? dep.files.join(", ") : "No direct import match found by static scan; dependency may be runtime-only or indirectly used."}`);
  }
  lines.push("");
  return lines.join("\n");
}

function buildGlossaryChapter(glossary) {
  const lines = [];
  lines.push("# CHAPTER 12: GLOSSARY");
  lines.push("");
  for (const [term, definition] of glossary) {
    lines.push(`- ${term}: ${definition}`);
  }
  lines.push("");
  return lines.join("\n");
}

function buildFrontMatter(files) {
  return [
    "# ReClaim Codebase Textbook",
    "",
    "Generated from the tracked repository contents in `git ls-files` scope.",
    "",
    "Scope assumptions:",
    "- Included: tracked project files, including source, docs, workflow files, logs, and binary artifacts that are actually part of the repository.",
    "- Excluded from analysis scope unless tracked: generated caches such as `node_modules`, `.gradle`, `.dart_tool`, and transient build outputs.",
    "- For binary files such as `.docx`, `.jar`, `.png`, and `.keystore`, the documentation records purpose and repository role; it cannot provide line-by-line logic because no source text is embedded in a plain-text form.",
    "",
    `Generated on: ${new Date().toISOString()}`,
    `Total tracked files analyzed: ${files.length}`,
    "",
  ].join("\n");
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function replaceInlineCode(text) {
  return escapeHtml(text).replace(/`([^`]+)`/g, "<code>$1</code>");
}

function renderHtmlFromMarkdown(markdown) {
  const lines = markdown.split(/\r?\n/);
  const out = [];
  let i = 0;
  let inCodeBlock = false;
  let inUl = false;
  let inOl = false;
  let inFileCard = false;

  const closeLists = () => {
    if (inUl) {
      out.push("</ul>");
      inUl = false;
    }
    if (inOl) {
      out.push("</ol>");
      inOl = false;
    }
  };

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (trimmed === "```text" || trimmed === "```" || trimmed.startsWith("```")) {
      closeLists();
      if (!inCodeBlock) {
        out.push("<pre class=\"code-block\">");
        inCodeBlock = true;
      } else {
        out.push("</pre>");
        inCodeBlock = false;
      }
      i += 1;
      continue;
    }

    if (inCodeBlock) {
      out.push(escapeHtml(line));
      i += 1;
      continue;
    }

    if (trimmed.startsWith("━━━━━━━━") || trimmed.startsWith("â")) {
      closeLists();
      if (!inFileCard) {
        out.push("<section class=\"file-card\">");
        inFileCard = true;
      } else {
        out.push("</section>");
        inFileCard = false;
      }
      i += 1;
      continue;
    }

    if (!trimmed) {
      closeLists();
      out.push("<div class=\"spacer\"></div>");
      i += 1;
      continue;
    }

    if (trimmed.startsWith("# ")) {
      closeLists();
      out.push(`<h1>${replaceInlineCode(trimmed.slice(2))}</h1>`);
      i += 1;
      continue;
    }
    if (trimmed.startsWith("## ")) {
      closeLists();
      out.push(`<h2>${replaceInlineCode(trimmed.slice(3))}</h2>`);
      i += 1;
      continue;
    }
    if (trimmed.startsWith("### ")) {
      closeLists();
      out.push(`<h3>${replaceInlineCode(trimmed.slice(4))}</h3>`);
      i += 1;
      continue;
    }

    const numberedMatch = trimmed.match(/^(\d+)\.\s+(.*)$/);
    if (numberedMatch) {
      if (!inOl) {
        closeLists();
        out.push("<ol>");
        inOl = true;
      }
      out.push(`<li>${replaceInlineCode(numberedMatch[2])}</li>`);
      i += 1;
      continue;
    }

    if (trimmed.startsWith("- ")) {
      if (!inUl) {
        closeLists();
        out.push("<ul>");
        inUl = true;
      }
      out.push(`<li>${replaceInlineCode(trimmed.slice(2))}</li>`);
      i += 1;
      continue;
    }

    if (trimmed.startsWith("• ") || trimmed.startsWith("â€¢ ")) {
      if (!inUl) {
        closeLists();
        out.push("<ul>");
        inUl = true;
      }
      out.push(`<li>${replaceInlineCode(trimmed.replace(/^([•]|â€¢)\s+/, ""))}</li>`);
      i += 1;
      continue;
    }

    const infoPrefixes = ["📄 FILE:", "📌 PURPOSE:", "🔧 TECH USED:", "📦 IMPORTS:", "📤 EXPORTS:", "📊 FILE FACTS:", "🔗 CONNECTS TO:", "⚠️ NOTES:"];
    const prefix = infoPrefixes.find((p) => trimmed.startsWith(p));
    if (prefix) {
      closeLists();
      const body = replaceInlineCode(trimmed.slice(prefix.length).trim());
      out.push(`<p class="kv"><strong>${escapeHtml(prefix)}</strong> ${body}</p>`);
      i += 1;
      continue;
    }

    closeLists();
    out.push(`<p>${replaceInlineCode(trimmed)}</p>`);
    i += 1;
  }

  closeLists();
  if (inCodeBlock) out.push("</pre>");
  if (inFileCard) out.push("</section>");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>ReClaim Codebase Textbook</title>
  <style>
    :root {
      --bg: #eef1f5;
      --paper: #ffffff;
      --text: #0f172a;
      --muted: #475569;
      --brand: #0f4c81;
      --line: #d6dee8;
      --card: #f8fafc;
      --code-bg: #0b1220;
      --code-text: #dbe7ff;
    }
    body {
      margin: 0;
      background: radial-gradient(circle at top right, #e5edf7 0%, var(--bg) 42%, #e9eef4 100%);
      color: var(--text);
      font-family: "Segoe UI", "Calibri", sans-serif;
      line-height: 1.55;
      -webkit-font-smoothing: antialiased;
    }
    .page {
      max-width: 1060px;
      margin: 0 auto;
      background: var(--paper);
      padding: 36px 44px 64px;
      box-shadow: 0 4px 24px rgba(12, 20, 35, 0.08);
      box-sizing: border-box;
    }
    h1, h2, h3 {
      margin: 20px 0 10px;
      color: var(--brand);
      font-family: "Segoe UI Semibold", "Calibri", sans-serif;
      page-break-after: avoid;
    }
    h1 {
      font-size: 26px;
      border-bottom: 2px solid var(--line);
      padding-bottom: 8px;
    }
    h2 { font-size: 20px; }
    h3 { font-size: 16px; color: #1e3a5f; }
    p {
      margin: 6px 0;
      font-size: 12px;
      color: var(--text);
      page-break-inside: avoid;
    }
    p.kv {
      background: var(--card);
      border: 1px solid var(--line);
      border-left: 4px solid #7ea2c7;
      padding: 6px 9px;
      border-radius: 6px;
    }
    ul, ol {
      margin: 6px 0 10px 20px;
      padding: 0 0 0 14px;
    }
    li {
      margin: 2px 0;
      font-size: 12px;
      color: #1e293b;
    }
    code {
      background: #eaf1f8;
      border: 1px solid #cfdeee;
      padding: 1px 4px;
      border-radius: 4px;
      font-family: "Consolas", "Courier New", monospace;
      font-size: 11px;
    }
    pre.code-block {
      margin: 8px 0 12px;
      padding: 10px 12px;
      background: var(--code-bg);
      color: var(--code-text);
      border-radius: 8px;
      font-size: 10px;
      line-height: 1.45;
      white-space: pre-wrap;
      word-break: break-word;
      page-break-inside: avoid;
      font-family: "Consolas", "Courier New", monospace;
    }
    .file-card {
      margin: 14px 0;
      padding: 12px;
      border: 1px solid var(--line);
      border-radius: 10px;
      background: linear-gradient(180deg, #fcfdff 0%, #f7fafe 100%);
      page-break-inside: avoid;
    }
    .spacer { height: 6px; }
    @media print {
      body { background: #fff; }
      .page {
        max-width: none;
        margin: 0;
        padding: 14mm 12mm 14mm;
        box-shadow: none;
      }
      .file-card { break-inside: avoid; }
    }
  </style>
</head>
<body>
  <main class="page">
    ${out.join("\n")}
  </main>
</body>
</html>`;
}

async function renderPdfWithPlaywright() {
  const nodeModulesDir = "C:\\Users\\siddh\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules";
  const browserCandidates = [
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
  ].filter((candidate) => fs.existsSync(candidate));
  const executablePath = browserCandidates[0] || null;
  const playwrightScript = path.join(OUTPUT_DIR, "render_pdf.js");
  fs.writeFileSync(
    playwrightScript,
    `const { chromium } = require(${JSON.stringify(path.join(nodeModulesDir, "playwright"))});\n` +
      `const path = require("path");\n` +
      `const htmlPath = ${JSON.stringify(HTML_PATH)};\n` +
      `const pdfPath = ${JSON.stringify(PDF_PATH)};\n` +
      `const executablePath = ${JSON.stringify(executablePath)};\n` +
      `(async () => {\n` +
      `  const browser = await chromium.launch(executablePath ? { headless: true, executablePath } : { headless: true });\n` +
      `  const page = await browser.newPage();\n` +
      `  await page.goto('file:///' + htmlPath.replace(/\\\\/g, '/'), { waitUntil: 'load' });\n` +
      `  await page.pdf({ path: pdfPath, format: 'A4', printBackground: true, margin: { top: '12mm', right: '10mm', bottom: '12mm', left: '10mm' } });\n` +
      `  await browser.close();\n` +
      `})();\n`
  );

  const result = spawnSync(process.execPath, [playwrightScript], {
    cwd: ROOT,
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`PDF render failed: ${result.stderr || result.stdout}`);
  }
}

function verifyPdfPageCount() {
  const data = fs.readFileSync(PDF_PATH);
  const text = data.toString("latin1");
  const pages = (text.match(/\/Type\s*\/Page\b/g) || []).length;
  return pages;
}

async function main() {
  ensureDir(OUTPUT_DIR);

  const relPaths = gitTrackedFiles();
  const files = relPaths.map(analyzeFile);

  const parts = [];
  parts.push(buildFrontMatter(files));
  parts.push(buildIndexSection(files));
  parts.push(buildOverview(files));
  for (const chapter of CHAPTERS) {
    parts.push(buildChapter(chapter, files));
  }
  const dependencyReference = buildDependencyReference(files);
  parts.push(buildDependencyChapter(dependencyReference));
  parts.push(buildGlossaryChapter(buildGlossary(files)));

  const markdown = parts.join("\n\n");
  fs.writeFileSync(MD_PATH, markdown, "utf8");

  const html = renderHtmlFromMarkdown(markdown);
  fs.writeFileSync(HTML_PATH, html, "utf8");

  await renderPdfWithPlaywright();

  const pageCount = verifyPdfPageCount();
  const summary = {
    markdown: MD_PATH,
    html: HTML_PATH,
    pdf: PDF_PATH,
    filesAnalyzed: files.length,
    pdfPagesApprox: pageCount,
  };
  fs.writeFileSync(path.join(OUTPUT_DIR, "generation_summary.json"), JSON.stringify(summary, null, 2), "utf8");
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exit(1);
});
