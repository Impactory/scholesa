const fs = require('fs');
const path = require('path');

const functionsRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(functionsRoot, '..');
const srcRoot = path.join(functionsRoot, 'src');
const firebaseJsonPath = path.join(repoRoot, 'firebase.json');
const packageJsonPath = path.join(functionsRoot, 'package.json');

const requiredEntryModules = [
  'index.ts',
  'workflowOps.ts',
  'bosRuntime.ts',
  'coppaOps.ts',
  'telemetryAggregator.ts',
];

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function collectTsFiles(dirPath) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      return collectTsFiles(fullPath);
    }
    if (!entry.isFile() || !entry.name.endsWith('.ts')) {
      return [];
    }
    return [fullPath];
  });
}

function relativeToFunctions(filePath) {
  return path.relative(functionsRoot, filePath);
}

const failures = [];

const firebaseJson = readJson(firebaseJsonPath);
const functionsConfig = firebaseJson.functions;
if (!functionsConfig || functionsConfig.source !== 'functions') {
  failures.push('firebase.json must point the default functions source at "functions".');
}
if (!functionsConfig || functionsConfig.runtime !== 'nodejs24') {
  failures.push('firebase.json must pin Functions runtime to nodejs24 for Gen 2 deploys.');
}

const packageJson = readJson(packageJsonPath);
const firebaseFunctionsVersion =
  packageJson.dependencies && packageJson.dependencies['firebase-functions'];
if (typeof firebaseFunctionsVersion !== 'string') {
  failures.push('functions/package.json must declare firebase-functions in dependencies.');
}

const sourceFiles = collectTsFiles(srcRoot).filter((filePath) => {
  return !filePath.endsWith('.test.ts') && !filePath.endsWith('.spec.ts');
});

for (const filePath of sourceFiles) {
  const content = fs.readFileSync(filePath, 'utf8');
  const relPath = relativeToFunctions(filePath);
  if (content.includes('firebase-functions/v1/')) {
    failures.push(`${relPath} still imports firebase-functions/v1 APIs.`);
  }
  if (content.includes('runWith(')) {
    failures.push(`${relPath} still uses runWith(), which indicates legacy Gen 1 runtime configuration.`);
  }
}

for (const moduleName of requiredEntryModules) {
  const modulePath = path.join(srcRoot, moduleName);
  const content = fs.readFileSync(modulePath, 'utf8');
  if (!content.includes("./gen2Runtime'") && !content.includes('./gen2Runtime"')) {
    failures.push(`src/${moduleName} must import ./gen2Runtime so shared Gen 2 defaults are applied.`);
  }
}

if (failures.length > 0) {
  console.error('Gen 2 deployment verification failed:\n');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log('Gen 2 deployment verification passed.');
console.log(`- Checked ${sourceFiles.length} non-test TypeScript files`);
console.log(`- Verified shared runtime bootstrap in ${requiredEntryModules.length} v2 entry modules`);
console.log(`- Runtime: ${functionsConfig.runtime}`);
console.log(`- firebase-functions: ${firebaseFunctionsVersion}`);
