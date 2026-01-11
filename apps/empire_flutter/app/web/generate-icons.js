#!/usr/bin/env node
/**
 * Scholesa Icon Generator
 * 
 * Generates PNG icons from the SVG source for web/PWA
 * Run: node generate-icons.js
 * 
 * Prerequisites:
 *   npm install sharp
 */

const fs = require('fs');
const path = require('path');

async function generateIcons() {
  const svgPath = path.join(__dirname, 'icons', 'icon.svg');
  const iconsDir = path.join(__dirname, 'icons');
  
  const svgContent = fs.readFileSync(svgPath, 'utf8');
  
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
    
    for (const { name, size } of sizes) {
      const outputPath = path.join(iconsDir, name);
      const isMaskable = name.includes('maskable');
      const padding = isMaskable ? Math.floor(size * 0.1) : 0;
      const innerSize = size - (padding * 2);
      
      let buffer;
      if (isMaskable) {
        buffer = await sharp(Buffer.from(svgContent))
          .resize(innerSize, innerSize)
          .extend({
            top: padding,
            bottom: padding,
            left: padding,
            right: padding,
            background: { r: 59, g: 130, b: 246, alpha: 1 }
          })
          .png()
          .toBuffer();
      } else {
        buffer = await sharp(Buffer.from(svgContent))
          .resize(size, size)
          .png()
          .toBuffer();
      }
      
      fs.writeFileSync(outputPath, buffer);
      console.log(`✓ Generated ${name} (${size}x${size})`);
    }
    
    const faviconBuffer = await sharp(Buffer.from(svgContent))
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
