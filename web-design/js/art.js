/* Knightsbridge Newsagency — original SVG artwork.
   Everything is drawn in code: no image files, no external requests, works offline.
   Motif: offset print registration — layered shapes slightly misaligned, the way
   a newspaper press lays down colour.

   Palette is the logo's: signal red #E1251B (with #A11009 as its deeper second
   pass), black #111111, paper white #FAFAFA. Nothing else. */

const ART_INK = '#111111';
const ART_PAPER = '#FAFAFA';

/* ---------------- Hero slides ---------------- */
const HERO_SLIDES = [
  {
    id: 'press',
    eyebrow: 'Every morning',
    heading: 'Fresh off the press',
    body: 'Papers on the shelf before your coffee cools. Weekday and weekend editions, held for regulars.',
    cta: { label: 'Shop papers', href: 'shop.html?tag=Paper' },
    accent: '#E1251B',
    svg: () => `
      <svg viewBox="0 0 800 520" role="img" aria-label="Illustration of folded newspapers stacked in front of a rising sun" preserveAspectRatio="xMidYMid slice">
        <rect width="800" height="520" fill="#1C1C1C"/>
        <circle cx="600" cy="150" r="120" fill="#FFFFFF" opacity="0.95"/>
        <circle cx="588" cy="162" r="120" fill="#E1251B" opacity="0.45"/>
        <g opacity="0.16" stroke="#FAFAFA" stroke-width="2">
          ${Array.from({ length: 9 }, (_, i) => `<line x1="0" y1="${60 + i * 52}" x2="800" y2="${60 + i * 52}"/>`).join('')}
        </g>
        <g transform="translate(90 210) rotate(-6)">
          <rect width="380" height="250" rx="8" fill="#FAFAFA"/>
          <rect x="26" y="26" width="200" height="26" rx="4" fill="#111111"/>
          <rect x="26" y="66" width="140" height="12" rx="3" fill="#9A9A9A"/>
          <rect x="26" y="96" width="150" height="120" rx="4" fill="#A11009"/>
          <g fill="#D0D0D0">
            ${Array.from({ length: 7 }, (_, i) => `<rect x="196" y="${96 + i * 18}" width="158" height="8" rx="4"/>`).join('')}
          </g>
        </g>
        <g transform="translate(150 262) rotate(4)">
          <rect width="380" height="250" rx="8" fill="#FAFAFA" opacity="0.97"/>
          <rect x="26" y="26" width="260" height="30" rx="4" fill="#E1251B"/>
          <rect x="26" y="72" width="120" height="12" rx="3" fill="#9A9A9A"/>
          <g fill="#D0D0D0">
            ${Array.from({ length: 8 }, (_, i) => `<rect x="26" y="${104 + i * 18}" width="${140 - (i % 3) * 22}" height="8" rx="4"/>`).join('')}
            ${Array.from({ length: 8 }, (_, i) => `<rect x="196" y="${104 + i * 18}" width="${158 - (i % 4) * 18}" height="8" rx="4"/>`).join('')}
          </g>
        </g>
      </svg>`
  },
  {
    id: 'mags',
    eyebrow: 'Weekly & monthly',
    heading: 'Magazines, puzzles, crosswords',
    body: 'The biggest wall in the shop. Puzzlers, glossies, motoring, craft — and the ones you can never find elsewhere.',
    cta: { label: 'Shop magazines', href: 'shop.html?tag=Magazine' },
    accent: '#A11009',
    svg: () => `
      <svg viewBox="0 0 800 520" role="img" aria-label="Illustration of magazines fanned out with a crossword grid" preserveAspectRatio="xMidYMid slice">
        <rect width="800" height="520" fill="#232323"/>
        <g opacity="0.25">
          <circle cx="150" cy="90" r="180" fill="#A11009"/>
          <circle cx="170" cy="110" r="180" fill="#FFFFFF" opacity="0.5"/>
        </g>
        <g transform="translate(70 130)">
          ${[0, 1, 2].map((i) => `
            <g transform="translate(${i * 62} ${i * 14}) rotate(${-10 + i * 5} 110 170)">
              <rect width="220" height="300" rx="10" fill="${['#E1251B', '#FAFAFA', '#A11009'][i]}"/>
              <rect x="20" y="22" width="${140 - i * 20}" height="22" rx="4" fill="${i === 1 ? '#111111' : '#FAFAFA'}" opacity="0.85"/>
              <circle cx="110" cy="150" r="52" fill="${i === 1 ? '#111111' : '#FAFAFA'}" opacity="0.15"/>
              <rect x="20" y="238" width="180" height="10" rx="5" fill="${i === 1 ? '#111111' : '#FAFAFA'}" opacity="0.35"/>
              <rect x="20" y="258" width="120" height="10" rx="5" fill="${i === 1 ? '#111111' : '#FAFAFA'}" opacity="0.25"/>
            </g>`).join('')}
        </g>
        <g transform="translate(470 150)">
          <rect width="264" height="264" rx="10" fill="#FAFAFA"/>
          ${Array.from({ length: 36 }, (_, i) => {
            const r = Math.floor(i / 6), c = i % 6;
            const filled = [0, 3, 7, 10, 14, 19, 22, 26, 31, 35].includes(i);
            return `<rect x="${12 + c * 40}" y="${12 + r * 40}" width="36" height="36" rx="3" fill="${filled ? '#111111' : '#E6E6E6'}"/>`;
          }).join('')}
        </g>
      </svg>`
  },
  {
    id: 'cards',
    eyebrow: 'For the moments that matter',
    heading: 'Cards, gifts and wrap',
    body: 'Birthdays, sympathy, new baby, just because. Pick the card and the wrap in one stop.',
    cta: { label: 'Shop cards & gifts', href: 'shop.html?tag=Cards' },
    accent: '#FFFFFF',
    svg: () => `
      <svg viewBox="0 0 800 520" role="img" aria-label="Illustration of a greeting card envelope with confetti and a wrapped gift" preserveAspectRatio="xMidYMid slice">
        <rect width="800" height="520" fill="#1A1A1A"/>
        <g opacity="0.85">
          ${Array.from({ length: 26 }, (_, i) => {
            const x = (i * 137) % 780 + 10, y = (i * 211) % 480 + 20;
            const c = ['#FFFFFF', '#E1251B', '#A11009', '#FAFAFA'][i % 4];
            return `<rect x="${x}" y="${y}" width="14" height="6" rx="3" fill="${c}" opacity="0.7" transform="rotate(${(i * 47) % 360} ${x + 7} ${y + 3})"/>`;
          }).join('')}
        </g>
        <g transform="translate(90 160)">
          <rect width="330" height="230" rx="10" fill="#FAFAFA"/>
          <path d="M0 10 L165 140 L330 10 L330 0 L0 0 Z" fill="#E6E6E6"/>
          <path d="M0 12 L165 142 L330 12" fill="none" stroke="#111111" stroke-width="4" opacity="0.5"/>
          <path d="M132 176 a26 26 0 0 1 33 -22 a26 26 0 0 1 33 22 c0 26 -33 44 -33 44 s-33 -18 -33 -44 z" fill="#E1251B"/>
        </g>
        <g transform="translate(470 150)">
          <rect y="70" width="250" height="200" rx="8" fill="#A11009"/>
          <rect x="105" y="70" width="40" height="200" fill="#FFFFFF"/>
          <rect y="140" width="250" height="34" fill="#FFFFFF"/>
          <rect y="40" width="250" height="44" rx="8" fill="#7D0C07"/>
          <rect x="105" y="40" width="40" height="44" fill="#FFFFFF"/>
          <path d="M125 40 c-40 0 -56 -46 -18 -46 c24 0 22 30 18 46 z" fill="#E1251B"/>
          <path d="M125 40 c40 0 56 -46 18 -46 c-24 0 -22 30 -18 46 z" fill="#E1251B"/>
        </g>
      </svg>`
  },
  {
    id: 'lotto',
    eyebrow: 'Have a go',
    heading: 'Lotto, toys and little treats',
    body: 'A lucky shop with a lucky counter. Grab a ticket, a scratchie, or something small for the kids.',
    cta: { label: 'Shop toys & lotto', href: 'shop.html?tag=Toys' },
    accent: '#E1251B',
    svg: () => `
      <svg viewBox="0 0 800 520" role="img" aria-label="Illustration of numbered lottery balls and a toy car" preserveAspectRatio="xMidYMid slice">
        <rect width="800" height="520" fill="#111111"/>
        <g opacity="0.3">
          ${Array.from({ length: 5 }, (_, i) => `<circle cx="${120 + i * 160}" cy="${i % 2 ? 420 : 90}" r="${70 + i * 8}" fill="${['#E1251B', '#FFFFFF', '#A11009'][i % 3]}" opacity="0.35"/>`).join('')}
        </g>
        <g transform="translate(70 150)">
          ${[7, 12, 24, 38].map((n, i) => `
            <g transform="translate(${i * 130} ${i % 2 ? 40 : 0})">
              <circle cx="60" cy="60" r="58" fill="#FAFAFA"/>
              <circle cx="60" cy="60" r="58" fill="none" stroke="${['#E1251B', '#111111', '#A11009', '#E1251B'][i]}" stroke-width="9"/>
              <text x="60" y="76" text-anchor="middle" font-family="Verdana, sans-serif" font-weight="700" font-size="44" fill="#111111">${n}</text>
            </g>`).join('')}
        </g>
        <g transform="translate(500 330)">
          <rect x="10" y="34" width="210" height="46" rx="14" fill="#E1251B"/>
          <path d="M46 34 h118 l32 0 v-4 a26 26 0 0 0 -26 -26 h-92 a26 26 0 0 0 -26 26 z" fill="#FF6E63"/>
          <rect x="70" y="12" width="90" height="24" rx="8" fill="#D6D6D6"/>
          <circle cx="62" cy="86" r="22" fill="#111111"/><circle cx="62" cy="86" r="9" fill="#D0D0D0"/>
          <circle cx="178" cy="86" r="22" fill="#111111"/><circle cx="178" cy="86" r="9" fill="#D0D0D0"/>
        </g>
      </svg>`
  }
];

/* ---------------- Category thumbnails for product cards ---------------- */
const TAG_ART = {
  Paper: { bg: '#1C1C1C', fg: '#FAFAFA', accent: '#E1251B' },
  Magazine: { bg: '#232323', fg: '#FFFFFF', accent: '#A11009' },
  Cards: { bg: '#1A1A1A', fg: '#FAFAFA', accent: '#E1251B' },
  Gifts: { bg: '#282828', fg: '#FFFFFF', accent: '#A11009' },
  Toys: { bg: '#202020', fg: '#FF6E63', accent: '#FFFFFF' },
  Stationery: { bg: '#2B2B2B', fg: '#D6D6D6', accent: '#FFFFFF' },
  Lottery: { bg: '#111111', fg: '#FFFFFF', accent: '#E1251B' }
};

const FALLBACK_PALETTES = [
  { bg: '#1C1C1C', fg: '#FFFFFF', accent: '#E1251B' },
  { bg: '#232323', fg: '#D6D6D6', accent: '#A11009' },
  { bg: '#1A1A1A', fg: '#FF6E63', accent: '#FFFFFF' },
  { bg: '#282828', fg: '#FAFAFA', accent: '#A11009' }
];

function paletteFor(tag) {
  if (TAG_ART[tag]) return TAG_ART[tag];
  let h = 0;
  for (let i = 0; i < tag.length; i++) h = (h * 31 + tag.charCodeAt(i)) >>> 0;
  return FALLBACK_PALETTES[h % FALLBACK_PALETTES.length];
}

/** Deterministic geometric thumbnail for a product card. Decorative — hidden from
 *  screen readers, since the product name directly above already says what it is. */
function tagThumb(tag, seedText = '') {
  const p = paletteFor(tag);
  let h = 0;
  const s = tag + seedText;
  for (let i = 0; i < s.length; i++) h = (h * 33 + s.charCodeAt(i)) >>> 0;
  const rnd = (n) => { h = (h * 1103515245 + 12345) >>> 0; return h % n; };

  const shapes = Array.from({ length: 5 }, (_, i) => {
    const x = rnd(300) + 20, y = rnd(120) + 15, r = rnd(46) + 26;
    const fill = i % 2 ? p.accent : p.fg;
    const op = 0.18 + (i % 3) * 0.12;
    return rnd(2)
      ? `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" opacity="${op}"/>`
      : `<rect x="${x}" y="${y}" width="${r * 1.6}" height="${r}" rx="8" fill="${fill}" opacity="${op}" transform="rotate(${rnd(40) - 20} ${x} ${y})"/>`;
  }).join('');

  return `
    <svg viewBox="0 0 400 170" aria-hidden="true" focusable="false" preserveAspectRatio="xMidYMid slice">
      <rect width="400" height="170" fill="${p.bg}"/>
      ${shapes}
      <g opacity="0.14" stroke="${p.fg}" stroke-width="1.5">
        ${Array.from({ length: 6 }, (_, i) => `<line x1="0" y1="${18 + i * 28}" x2="400" y2="${18 + i * 28}"/>`).join('')}
      </g>
      <rect x="0" y="150" width="400" height="20" fill="${p.accent}" opacity="0.9"/>
    </svg>`;
}
