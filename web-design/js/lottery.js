/* Knightsbridge Newsagency — home-page lottery panel.

   Reads data/lottery.json and fills #lottery-panel, or leaves it hidden if the
   file is absent / invalid / unreachable (e.g. opened from file://). Read-only:
   a later daily job overwrites the JSON; this never writes it.

   See data/README.md for the full data contract. Nothing here embeds a
   trademarked logo or a scraped poster — the badge is drawn here as SVG, and
   poster/logo slots only ever load LOCAL owner-supplied files. */

/* Colour guard — each game tints the badge with its own brand colour. Only a
   plain #RRGGBB (or #RGB) hex is accepted, so the value is always a safe token
   to drop into an SVG fill / a style attribute (never arbitrary text). */
function safeBadgeColour(c) {
  const v = String(c || '').trim();
  return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(v) ? v : '#E1251B';
}

/* Own, trademark-free SVG badge: game name + a palette colour. No external art. */
function lotteryBadgeSVG(game, colour) {
  const c = safeBadgeColour(colour);
  const name = esc(String(game || 'Lottery').toUpperCase());
  // textLength makes any game name fit the ticket width without overflow.
  return `
    <svg class="lottery-badge-svg" viewBox="0 0 300 200" role="img"
         aria-label="${esc(game || 'Lottery')} draw">
      <rect x="6" y="6" width="288" height="188" rx="20" fill="${c}"/>
      <circle cx="150" cy="78" r="46" fill="#FFFFFF"/>
      <path d="M150 44 l9.5 19.3 21.3 3.1 -15.4 15 3.6 21.2 -19-10 -19 10 3.6 -21.2 -15.4 -15 21.3 -3.1z"
            fill="${c}"/>
      <rect x="30" y="140" width="240" height="34" rx="8" fill="#FFFFFF"/>
      <text x="150" y="163" text-anchor="middle" textLength="220" lengthAdjust="spacingAndGlyphs"
            font-family="'Plus Jakarta Sans','Segoe UI',sans-serif" font-weight="800"
            font-size="22" letter-spacing="1" fill="#111111">${name}</text>
      <circle cx="6" cy="100" r="10" fill="#FFFFFF"/>
      <circle cx="294" cy="100" r="10" fill="#FFFFFF"/>
    </svg>`;
}

function lotteryBallsHTML(nums, cls) {
  return (Array.isArray(nums) ? nums : [])
    .map((n) => `<li class="lottery-ball ${cls}">${esc(n)}</li>`)
    .join('');
}

function formatDrawDate(iso) {
  if (!iso) return '';
  const d = new Date(iso + (iso.length === 10 ? 'T00:00:00' : ''));
  if (isNaN(d)) return esc(iso);
  try {
    return d.toLocaleDateString('en-AU', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  } catch { return esc(iso); }
}

/** Mount the panel. Silent no-op on any failure. */
function initLotteryPanel(mountId, src = 'data/lottery.json') {
  const panel = document.getElementById(mountId);
  if (!panel || typeof fetch !== 'function') return;

  fetch(src, { cache: 'no-cache' })
    .then((res) => (res && res.ok ? res.json() : Promise.reject(new Error('no data'))))
    .then((data) => {
      // VERIFIED GATE (non-negotiable): the panel only ever shows numbers that
      // the daily workflow fetched from the official operator feed and stamped
      // `verified: true`. Any sample/placeholder/hand-edited file (verified
      // false or absent) stays HIDDEN, so unverified numbers can never be shown
      // to a customer as a real draw. See data/README.md.
      if (!data || data.verified !== true) return;
      if (!data.game || !Array.isArray(data.winningNumbers) || !data.winningNumbers.length) {
        return; // not enough to show — stay hidden
      }
      renderLotteryPanel(panel, data);
    })
    .catch(() => { /* absent / offline / malformed — panel stays hidden */ });
}

function renderLotteryPanel(panel, d) {
  const drawLine = [
    d.drawNumber != null ? `Draw ${esc(d.drawNumber)}` : '',
    formatDrawDate(d.drawDate)
  ].filter(Boolean).join(' · ');

  // Logo slot: local, owner-licensed image if supplied; else our own SVG badge.
  const badge = d.logoSlot
    ? `<img class="lottery-badge-img" src="${esc(d.logoSlot)}" alt="${esc(d.game)} badge"
            width="300" height="200" data-lotto-badge-fallback loading="lazy">`
    : lotteryBadgeSVG(d.game, d.badgeColour);

  const supp = (Array.isArray(d.supplementary) && d.supplementary.length)
    ? `<span class="lottery-divider" aria-hidden="true">+</span>
       <span class="visually-hidden">Supplementary numbers</span>
       ${lotteryBallsHTML(d.supplementary, 'lottery-ball--supp')}`
    : '';

  const pb = (d.powerball != null && d.powerball !== '')
    ? `<span class="lottery-divider" aria-hidden="true">+</span>
       <span class="visually-hidden">Powerball</span>
       <li class="lottery-ball lottery-ball--pb">${esc(d.powerball)}</li>`
    : '';

  const poster = d.posterSlot
    ? `<div class="lottery-poster">
         <img src="${esc(d.posterSlot)}" alt="${esc(d.game)} poster" loading="lazy" data-lotto-poster>
       </div>`
    : '';

  const cta = d.ctaHref
    ? `<a class="btn btn-primary btn-arrow btn-small" href="${esc(d.ctaHref)}" target="_blank" rel="noopener">
         Check your numbers</a>`
    : '';

  const updated = d.updated
    ? `<p class="lottery-updated">Updated ${esc(formatDrawDate(d.updated))}</p>`
    : '';

  panel.innerHTML = `
    <div class="band-inner lottery-inner">
      <div class="lottery-head">
        <span class="eyebrow">Latest draw</span>
        <div class="lottery-badge">${badge}</div>
      </div>
      <div class="lottery-body">
        <h2 class="lottery-game">${esc(d.game)}</h2>
        ${drawLine ? `<p class="lottery-draw">${drawLine}</p>` : ''}
        <ul class="lottery-balls" aria-label="Winning numbers">
          ${lotteryBallsHTML(d.winningNumbers, '')}
          ${supp}
          ${pb}
        </ul>
        ${d.jackpot ? `<p class="lottery-jackpot" style="background:${safeBadgeColour(d.nextBadgeColour)};border-color:${safeBadgeColour(d.nextBadgeColour)}">${esc(d.jackpot)}</p>` : ''}
        <div class="lottery-actions">${cta}</div>
        ${updated}
      </div>
      ${poster}
    </div>
    <p class="lottery-disclaimer">Numbers shown for convenience — always confirm your ticket in store or with the official operator.</p>`;

  // Poster: hide the whole slot if the local file is missing.
  const posterImg = panel.querySelector('[data-lotto-poster]');
  if (posterImg) {
    posterImg.addEventListener('error', () => {
      const slot = posterImg.closest('.lottery-poster');
      if (slot) slot.remove();
    }, { once: true });
  }
  // Owner-supplied badge image failed? Fall back to the drawn SVG badge.
  const badgeImg = panel.querySelector('[data-lotto-badge-fallback]');
  if (badgeImg) {
    badgeImg.addEventListener('error', () => {
      const holder = badgeImg.closest('.lottery-badge');
      if (holder) holder.innerHTML = lotteryBadgeSVG(d.game, d.badgeColour);
    }, { once: true });
  }

  panel.hidden = false;
}
