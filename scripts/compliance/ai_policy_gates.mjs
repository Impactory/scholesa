import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const ROOT = process.cwd();
const OUT_DIR = path.join(ROOT, "audit-pack", "reports");
fs.mkdirSync(OUT_DIR, { recursive: true });

const ts = new Date().toISOString();
let gitSha = "unknown";
try {
  gitSha = execSync("git rev-parse HEAD", { encoding: "utf8" }).trim();
} catch {
  gitSha = "unknown";
}

const EXCLUDE_DIRS = new Set([
  "node_modules",".git","dist","build",".next",".firebase","coverage",
  ".turbo",".cache",".parcel-cache",".vercel",".netlify",".pnpm-store"
]);

// External AI vendors/endpoints (expand as needed)
const BANNED_DOMAINS = [
  "api.openai.com",
  "api.anthropic.com",
  "generativelanguage.googleapis.com",
  "ai.google.dev",
  "aiplatform.googleapis.com",
  "api.cohere.ai",
  "api.groq.com",
  "api.mistral",
  "together.ai",
  "replicate.com",
  "inference.hf.co",
  "api.deepgram.com",
  "api.assemblyai.com",
  "api.elevenlabs.io",
  "speech.googleapis.com",         // Google Speech-to-Text
  "texttospeech.googleapis.com"    // Google Text-to-Speech
];

// SDKs you want to ban in runtime code
const BANNED_PACKAGES = [
  "@google/generative-ai","google-genai","@google-cloud/vertexai",
  "openai","@azure/openai","anthropic","@anthropic-ai/sdk",
  "cohere","cohere-ai","mistralai","groq-sdk","together-ai","replicate",
  "huggingface","@huggingface/inference",
  "deepgram","assemblyai","elevenlabs"
];

// Key refs (presence in repo is usually a compliance red flag)
const KEY_PATTERNS = [
  "OPENAI_API_KEY","ANTHROPIC_API_KEY","GEMINI_API_KEY","GOOGLE_API_KEY",
  "DEEPGRAM_API_KEY","ASSEMBLYAI_API_KEY","ELEVENLABS_API_KEY",
  "COHERE_API_KEY","MISTRAL_API_KEY","GROQ_API_KEY","HF_TOKEN"
];

function walk(dir, files=[]) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.isDirectory()) {
      if (EXCLUDE_DIRS.has(ent.name)) continue;
      walk(path.join(dir, ent.name), files);
    } else {
      files.push(path.join(dir, ent.name));
    }
  }
  return files;
}

function isTextLike(p) {
  const base = path.basename(p);
  const ext = path.extname(p).toLowerCase();
  if (base.startsWith(".env")) return true;
  return new Set([
    ".js",".mjs",".cjs",".ts",".tsx",".jsx",
    ".py",".go",".java",".kt",".rb",".php",".cs",
    ".yaml",".yml",".json",".md",".txt",".toml",".ini",".sh"
  ]).has(ext);
}

function readText(p) {
  try { return fs.readFileSync(p, "utf8"); } catch { return null; }
}

function scanFile(rel, txt) {
  const hits = [];

  for (const d of BANNED_DOMAINS) {
    if (txt.includes(d)) hits.push({ type: "domain", value: d, file: rel });
  }
  for (const k of KEY_PATTERNS) {
    if (txt.includes(k)) hits.push({ type: "key_ref", value: k, file: rel });
  }

  return hits;
}

function scanDependencies() {
  const hits = [];
  const files = walk(ROOT).filter(p => path.basename(p) === "package.json");
  for (const f of files) {
    const txt = readText(f);
    if (!txt) continue;
    let pkg;
    try { pkg = JSON.parse(txt); } catch { continue; }
    const deps = {
      ...(pkg.dependencies||{}),
      ...(pkg.devDependencies||{}),
      ...(pkg.optionalDependencies||{})
    };
    for (const p of BANNED_PACKAGES) {
      if (deps[p]) hits.push({ type: "package", value: p, version: deps[p], file: path.relative(ROOT, f) });
    }
  }
  return hits;
}

const files = walk(ROOT);
let refHits = [];
for (const f of files) {
  if (!isTextLike(f)) continue;
  const txt = readText(f);
  if (!txt) continue;
  refHits = refHits.concat(scanFile(path.relative(ROOT, f), txt));
}

const depHits = scanDependencies();

const report = {
  reportId: "ai-policy-gates",
  timestamp: ts,
  gitSha,
  pass: (refHits.length === 0 && depHits.length === 0),
  findings: {
    dependencyHits: depHits,
    referenceHits: refHits
  },
  policy: {
    bannedDomains: BANNED_DOMAINS,
    bannedPackages: BANNED_PACKAGES,
    bannedKeyRefs: KEY_PATTERNS
  }
};

const outPath = path.join(OUT_DIR, "ai-policy-gates.json");
fs.writeFileSync(outPath, JSON.stringify(report, null, 2));

if (!report.pass) {
  console.error("AI POLICY GATES FAILED. See:", outPath);
  process.exit(254);
} else {
  console.log("AI POLICY GATES PASSED. Report:", outPath);
}
