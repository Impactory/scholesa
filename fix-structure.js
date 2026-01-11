const fs = require('fs');
const path = require('path');

const COLORS = { reset: "\x1b[0m", green: "\x1b[32m", yellow: "\x1b[33m", red: "\x1b[31m", cyan: "\x1b[36m" };
const ROOT = process.cwd();

function moveFile(src, dest) {
  const srcPath = path.join(ROOT, src);
  const destPath = path.join(ROOT, dest);
  
  if (fs.existsSync(srcPath)) {
    const destDir = path.dirname(destPath);
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    
    // If dest exists, we might be overwriting a placeholder.
    if (fs.existsSync(destPath)) {
      console.log(`${COLORS.yellow}Overwriting existing ${dest}...${COLORS.reset}`);
      fs.unlinkSync(destPath);
    }
    
    fs.renameSync(srcPath, destPath);
    console.log(`${COLORS.green}Moved ${src} -> ${dest}${COLORS.reset}`);
  }
}

function moveDirContent(srcRel, destRel) {
  // Find the actual locale dir
  const appDir = path.join(ROOT, 'app');
  if (!fs.existsSync(appDir)) return;
  
  const locales = fs.readdirSync(appDir).filter(f => f.startsWith('[') && f.endsWith(']'));
  if (locales.length === 0) return;
  const locale = locales[0]; // Assume first locale found

  const src = srcRel.replace('[locale]', locale);
  const dest = destRel.replace('[locale]', locale);
  
  const srcPath = path.join(ROOT, src);
  const destPath = path.join(ROOT, dest);

  if (fs.existsSync(srcPath)) {
    if (!fs.existsSync(destPath)) {
      fs.mkdirSync(destPath, { recursive: true });
    }

    const files = fs.readdirSync(srcPath);
    files.forEach(file => {
      const srcFile = path.join(srcPath, file);
      const destFile = path.join(destPath, file);
      
      // Overwrite dest
      if (fs.existsSync(destFile)) fs.unlinkSync(destFile);
      
      fs.renameSync(srcFile, destFile);
    });
    
    // Remove empty src dir
    fs.rmdirSync(srcPath);
    console.log(`${COLORS.green}Merged content of ${src} into ${dest}${COLORS.reset}`);
  }
}

function run() {
  console.log(`${COLORS.cyan}=== Restructuring Project ===${COLORS.reset}`);

  // 1. Move Root Files to src/lib
  moveFile('createUser.ts', 'src/lib/auth/createUser.ts');
  moveFile('collections.ts', 'src/lib/firestore/collections.ts');
  moveFile('getUserRoleServer.ts', 'src/lib/auth/getUserRoleServer.ts');

  // 2. Delete Duplicate SW Register (since we have one in src/lib/pwa)
  const swLegacy = path.join(ROOT, 'registerServiceWorker.ts');
  const swNew = path.join(ROOT, 'src/lib/pwa/registerServiceWorker.ts');
  if (fs.existsSync(swLegacy) && fs.existsSync(swNew)) {
    fs.unlinkSync(swLegacy);
    console.log(`${COLORS.green}Deleted duplicate registerServiceWorker.ts (kept src/lib/pwa version)${COLORS.reset}`);
  }

  // 3. Move Site Dashboard (root page.tsx) to (protected)/site
  // We need to find the locale first
  const appDir = path.join(ROOT, 'app');
  if (fs.existsSync(appDir)) {
    const locales = fs.readdirSync(appDir).filter(f => f.startsWith('[') && f.endsWith(']'));
    if (locales.length > 0) {
      const locale = locales[0];
      moveFile('page.tsx', `app/${locale}/(protected)/site/page.tsx`);
      
      // 4. Fix Duplicate Login
      moveDirContent('app/[locale]/login', 'app/[locale]/(auth)/login');
    }
  }

  console.log(`${COLORS.cyan}Restructure complete.${COLORS.reset}`);
}

run();