// scripts/generate_icons.mjs
// Generates all web and Android PNG icons from icon_source.svg
// Run from repo root: node scripts/generate_icons.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { Resvg } from '@resvg/resvg-js';

const svg = readFileSync('icon_source.svg');

function render(size, padding = 0) {
  const padded = Math.round(size * padding);
  const inner = size - padded * 2;
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: inner },
    background: 'transparent',
  });
  const rendered = resvg.render();
  const buf = rendered.asPng();

  if (padding === 0) return buf;

  // Create padded canvas: write PNG at offset padded,padded on size×size transparent canvas
  // Resvg doesn't support canvas offset directly — use a wrapper SVG
  const wrapper = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
    <image href="data:image/png;base64,${buf.toString('base64')}"
           x="${padded}" y="${padded}" width="${inner}" height="${inner}"/>
  </svg>`;
  const resvg2 = new Resvg(Buffer.from(wrapper), {
    fitTo: { mode: 'width', value: size },
    background: 'transparent',
  });
  return resvg2.render().asPng();
}

function renderWithBg(size, bgColor, padding = 0) {
  const padded = Math.round(size * padding);
  const inner = size - padded * 2;
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: inner },
    background: 'transparent',
  });
  const iconBuf = resvg.render().asPng();
  const wrapper = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
    <rect width="${size}" height="${size}" fill="${bgColor}"/>
    <image href="data:image/png;base64,${iconBuf.toString('base64')}"
           x="${padded}" y="${padded}" width="${inner}" height="${inner}"/>
  </svg>`;
  const resvg2 = new Resvg(Buffer.from(wrapper), {
    fitTo: { mode: 'width', value: size },
    background: bgColor,
  });
  return resvg2.render().asPng();
}

// --- Web icons ---
const webDir = 'web/icons';
mkdirSync(webDir, { recursive: true });

// Standard PWA icons — teal background, icon centred with 15% padding
writeFileSync(`${webDir}/Icon-192.png`,          renderWithBg(192, '#0D7377', 0.15));
writeFileSync(`${webDir}/Icon-512.png`,          renderWithBg(512, '#0D7377', 0.15));
// Maskable icons — more padding (safe zone = inner 80% of canvas)
writeFileSync(`${webDir}/Icon-maskable-192.png`, renderWithBg(192, '#0D7377', 0.1));
writeFileSync(`${webDir}/Icon-maskable-512.png`, renderWithBg(512, '#0D7377', 0.1));

// Favicon — 32×32, transparent background
writeFileSync('web/favicon.png', render(32));

console.log('✓ Web icons generated');

// --- Android mipmap icons ---
const densities = [
  { name: 'mdpi',    size: 48  },
  { name: 'hdpi',    size: 72  },
  { name: 'xhdpi',   size: 96  },
  { name: 'xxhdpi',  size: 144 },
  { name: 'xxxhdpi', size: 192 },
];

for (const { name, size } of densities) {
  const dir = `android/app/src/main/res/mipmap-${name}`;
  mkdirSync(dir, { recursive: true });

  // ic_launcher — teal background, 15% padding
  writeFileSync(`${dir}/ic_launcher.png`,       renderWithBg(size, '#0D7377', 0.15));
  // ic_launcher_round — same
  writeFileSync(`${dir}/ic_launcher_round.png`, renderWithBg(size, '#0D7377', 0.15));
  // ic_launcher_foreground — transparent background, icon fills 66% (adaptive icon foreground layer)
  writeFileSync(`${dir}/ic_launcher_foreground.png`, render(size, 0.17));

  console.log(`✓ Android ${name} (${size}px)`);
}

console.log('\n✅ All icons generated successfully.');
