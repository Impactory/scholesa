#!/usr/bin/env node
/**
 * Scholesa Icon Generator
 * 
 * Generates PNG icons from the authoritative launcher PNG source for web/PWA
 * Run: node generate-icons.js
 * 
 * Prerequisites:
 *   npm install sharp
 */

const fs = require('fs');
const path = require('path');

async function generateIcons() {
  const sourcePngPath = path.join(__dirname, '..', 'assets', 'icons', 'android', 'android-launchericon-512-512.png');
  const iconsDir = path.join(__dirname, 'icons');

  if (!fs.existsSync(sourcePngPath)) {
    throw new Error(`Authoritative PNG source not found: ${sourcePngPath}`);
  }
  
  const sizes = [
    { name: 'favicon-16x16.png', size: 16 },
    { name: 'favicon-32x32.png', size: 32 },
    { name: 'Icon-192.png', size: 192 },
    { name: 'Icon-512.png', size: 512 },
    { name: 'Icon-maskable-192.png', size: 192 },
    { name: 'Icon-maskable-512.png', size: 512 },
  ];

  try {
    const sharp = require('sharp');
    const sourceBuffer = fs.readFileSync(sourcePngPath);
    
    for (const { name, size } of sizes) {
      const outputPath = path.join(iconsDir, name);
      const isMaskable = name.includes('maskable');
      const padding = isMaskable ? Math.floor(size * 0.1) : 0;
      const innerSize = size - (padding * 2);
      
      let buffer;
      if (isMaskable) {
        buffer = await sharp(sourceBuffer)
          .resize(innerSize, innerSize)
          .extend({
            top: padding,
            bottom: padding,
            left: padding,
            right: padding,
            background: { r: 14, g: 165, b: 233, alpha: 1 }
          })
          .png()
          .toBuffer();
      } else {
        buffer = await sharp(sourceBuffer)
          .resize(size, size)
          .png()
          .toBuffer();
      }
      
      fs.writeFileSync(outputPath, buffer);
      console.log(`✓ Generated ${name} (${size}x${size})`);
    }
    
    const faviconBuffer = await sharp(sourceBuffer)
      .resize(32, 32)
      .png()
      .toBuffer();
    fs.writeFileSync(path.join(iconsDir, 'favicon.ico'), faviconBuffer);
    console.log('✓ Generated favicon.ico');
    
    console.log('\n✅ All icons generated successfully!');
    
  } catch (err) {
    if (err.code === 'MODULE_NOT_FOUND') {
      console.log('Sharp not installed.');
      console.log('\nTo generate PNG icons:');
      console.log('  npm install sharp && node generate-icons.js');
      console.log('\nOr open generate-icons.html in browser.\n');
    } else {
      throw err;
    }
  }
}

generateIcons().catch(console.error);
