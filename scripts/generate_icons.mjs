// scripts/generate_icons.mjs
// Generates all web and Android PNG icons from icon_source.svg
// Run from repo root: node scripts/generate_icons.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { Resvg } from '@resvg/resvg-js';

// Read SVG as string and inject white background rect before rasterising
const svgStr = readFileSync('assets/images/reflect-icon-dark.svg', 'utf8');
const svg = Buffer.from(
  svgStr.replace(/(<svg[^>]*>)/, '$1<rect width="100%" height="100%" fill="#FFFFFF"/>'),
);

function render(size, padding = 0) {
  const padded = Math.round(size * padding);
  const inner = size - padded * 2;
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: inner },
    background: 'white',
  });
  const buf = resvg.render().asPng();

  if (padding === 0) return buf;

  // Create padded canvas with white background
  const wrapper = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
    <rect width="${size}" height="${size}" fill="#FFFFFF"/>
    <image href="data:image/png;base64,${buf.toString('base64')}"
           x="${padded}" y="${padded}" width="${inner}" height="${inner}"/>
  </svg>`;
  const resvg2 = new Resvg(Buffer.from(wrapper), {
    fitTo: { mode: 'width', value: size },
    background: 'white',
  });
  return resvg2.render().asPng();
}

// --- Web icons ---
const webDir = 'web/icons';
mkdirSync(webDir, { recursive: true });

// Standard PWA icons — white background, icon centred with 5% padding
writeFileSync(`${webDir}/Icon-192.png`,          render(192, 0.05));
writeFileSync(`${webDir}/Icon-512.png`,          render(512, 0.05));
// Maskable icons — more padding (safe zone = inner 80% of canvas)
writeFileSync(`${webDir}/Icon-maskable-192.png`, render(192, 0.08));
writeFileSync(`${webDir}/Icon-maskable-512.png`, render(512, 0.08));

// Favicon — 32×32, white background
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

  // ic_launcher — white background, 5% padding
  writeFileSync(`${dir}/ic_launcher.png`,            render(size, 0.05));
  // ic_launcher_round — same
  writeFileSync(`${dir}/ic_launcher_round.png`,      render(size, 0.05));
  // ic_launcher_foreground — white background, icon fills ~90%
  writeFileSync(`${dir}/ic_launcher_foreground.png`, render(size, 0.05));

  console.log(`✓ Android ${name} (${size}px)`);
}

console.log('\n✅ All icons generated successfully.');
