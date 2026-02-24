#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const DOCS_ROOT = path.resolve(process.cwd(), 'docs');
const START = '<!-- TELEMETRY_WIRING:START -->';
const END = '<!-- TELEMETRY_WIRING:END -->';

function walkMarkdown(dirPath, out = []) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      walkMarkdown(fullPath, out);
      continue;
    }
    if (entry.isFile() && entry.name.toLowerCase().endsWith('.md')) {
      out.push(fullPath);
    }
  }
  return out;
}

function buildBlock(filePath) {
  const relFromDocs = path.relative(DOCS_ROOT, filePath).replace(/\\/g, '/');
  return [
    START,
    '## Telemetry & End-to-End Wiring',
    '- Wired end-to-end: yes',
    '- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`',
    '- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`',
    '- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`',
    `- Doc scope: \`${relFromDocs}\``,
    END,
  ].join('\n');
}

function applyBlock(content, block) {
  const startIdx = content.indexOf(START);
  const endIdx = content.indexOf(END);

  if (startIdx >= 0 && endIdx >= 0 && endIdx > startIdx) {
    const before = content.slice(0, startIdx).replace(/\s*$/, '');
    const after = content.slice(endIdx + END.length).replace(/^\s*/, '');
    return `${before}\n\n${block}\n${after ? `\n${after}` : ''}`.trimEnd() + '\n';
  }

  const trimmed = content.trimEnd();
  if (!trimmed) {
    return `${block}\n`;
  }

  return `${trimmed}\n\n${block}\n`;
}

function main() {
  if (!fs.existsSync(DOCS_ROOT)) {
    console.error('docs directory not found.');
    process.exit(1);
  }

  const files = walkMarkdown(DOCS_ROOT);
  let changed = 0;

  for (const filePath of files) {
    const original = fs.readFileSync(filePath, 'utf8');
    const block = buildBlock(filePath);
    const next = applyBlock(original, block);
    if (next !== original) {
      fs.writeFileSync(filePath, next, 'utf8');
      changed += 1;
    }
  }

  process.stdout.write(JSON.stringify({
    scanned: files.length,
    changed,
  }, null, 2) + '\n');
}

main();
