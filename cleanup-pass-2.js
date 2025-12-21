const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const COLORS = { reset: "\x1b[0m", green: "\x1b[32m", yellow: "\x1b[33m" };

const FILES_TO_REMOVE = [
  'page.tsx',                 // Legacy root dashboard (moved to app/[locale]/(protected)/site)
  'registerServiceWorker.ts'  // Legacy SW helper (moved to src/lib/pwa)
];

console.log(`${COLORS.yellow}=== Cleaning up Legacy Files (Pass 2) ===${COLORS.reset}`);

FILES_TO_REMOVE.forEach(file => {
  const filePath = path.join(ROOT, file);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    console.log(`${COLORS.green}Deleted legacy file: ${file}${COLORS.reset}`);
  } else {
    console.log(`File already gone: ${file}`);
  }
});

console.log(`\n${COLORS.green}Cleanup complete. You are now VIBE compliant!${COLORS.reset}`);