#!/usr/bin/env node
/* Knightsbridge Newsagency — daily lottery-results refresher.
 *
 * Writes web-design/data/lottery.json (the panel's data contract — see
 * ../data/README.md) from the most recent NSW Lotteries headline draw, plus the
 * next draw's advertised jackpot. Zero dependencies: Node 18+ built-in fetch and
 * Intl only. The front-end (js/lottery.js) is read-only and never writes this.
 *
 * SOURCE — official operator feed. The Lott (Australia's official lottery
 * operator, which NSW Lotteries trades under) serves its own website/app from a
 * public, unauthenticated JSON API at api.thelott.com. We call two endpoints:
 *   POST /svc/sales/vmax/web/data/lotto/latestresults  -> winning numbers
 *   POST /svc/sales/vmax/web/data/lotto/opendraws       -> next draw + jackpot
 * These return FACTS: winning numbers, draw numbers, draw dates, advertised
 * Division 1 amounts. Facts are fine to store and display.
 *
 * COMPLIANCE (see also ../data/README.md and ../../.github/workflows/lottery-update.yml):
 *   - Winning numbers / draw numbers / jackpot amounts are facts -> published.
 *   - We NEVER fetch, hotlink or store any poster or trademarked game logo. The
 *     API returns DrawLogoUrl fields pointing at media.tatts.com images — we
 *     deliberately IGNORE them. The panel's "logo" is the site's own SVG badge
 *     (lotteryBadgeSVG in js/lottery.js). posterSlot/logoSlot stay LOCAL,
 *     owner-supplied paths and are preserved untouched across every refresh.
 *   - Fail soft: on any error we leave the previous good lottery.json in place
 *     and never write a broken/empty file.
 *
 * USAGE:
 *   node tools/update-lottery.mjs            # refresh data/lottery.json in place
 *   node tools/update-lottery.mjs --dry-run  # print the JSON, write nothing
 *   node tools/update-lottery.mjs --help
 */

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_FILE = resolve(__dirname, '..', 'data', 'lottery.json');

const API_BASE = 'https://api.thelott.com/svc/sales/vmax/web/data/lotto';
const COMPANY_ID = 'NSWLotteries';
const TIMEZONE = 'Australia/Sydney';
const FETCH_TIMEOUT_MS = 20000;
const CTA_HREF = 'https://www.thelott.com/results';

/* ---- game catalogue -------------------------------------------------------
 * Only the mainstream, ball-number headline games the shop sells. Each maps a
 * Sydney weekday (0=Sun..6=Sat) to the game that draws that night. Lucky
 * Lotteries / The Pools / Lotto Strike are intentionally excluded (ticket-style
 * or add-on games that don't fit the panel). badgeColour is restricted to the
 * site palette; js/lottery.js snaps anything else back to #E1251B anyway. */
// Set for Life is deliberately EXCLUDED from both the latest-draw pick and the
// next-draw line (owner's choice), so it never appears in GAMES.
// badgeColour is each game's own brand colour, used to tint the shop's own
// (trademark-free) SVG badge and the next-draw highlight.
const GAMES = {
  Powerball:                  { name: 'Powerball',       badgeColour: '#3653A4', hasPowerball: true },
  OzLotto:                    { name: 'Oz Lotto',        badgeColour: '#005000' },
  TattsLotto:                 { name: 'Saturday Lotto',  badgeColour: '#DC392D' },
  MondayWednesdayFridayLotto: { name: 'Weekday Windfall',badgeColour: '#583788' },
};

// When more than one headline game draws on the same night, this is the order
// the shop wants shown (higher = shown first). Powerball, then Saturday Lotto,
// then Oz Lotto, then Weekday Windfall, then Lucky Lotteries, then Super
// Jackpot, then Set for Life (draws nightly, so it's the lowest priority).
// Lucky Lotteries / Super Jackpot only apply if the feed returns them.
const PRIORITY = [
  'Powerball',
  'TattsLotto',                    // Saturday Lotto
  'OzLotto',
  'MondayWednesdayFridayLotto',    // Weekday Windfall
  'LuckyLotteries',
  'SuperJackpot',
];
const priorityOf = (id) => {
  const i = PRIORITY.indexOf(id);
  return i === -1 ? 999 : i;
};

/* ---- Sydney date helpers (DST-correct via Intl, no deps) ------------------ */

// 'YYYY-MM-DD' for a given instant in Sydney.
function sydneyDate(d = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(d);
}

// Weekday index 0=Sun..6=Sat for a 'YYYY-MM-DD' string (noon-anchored, DST-safe).
function weekdayOf(isoDate) {
  const dow = new Intl.DateTimeFormat('en-US', { timeZone: TIMEZONE, weekday: 'short' })
    .format(new Date(isoDate + 'T12:00:00Z'));
  return { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }[dow];
}

// Yesterday (Sydney), as 'YYYY-MM-DD'.
function sydneyYesterday(now = new Date()) {
  const today = sydneyDate(now);
  const dt = new Date(today + 'T12:00:00Z');
  dt.setUTCDate(dt.getUTCDate() - 1);
  return dt.toISOString().slice(0, 10);
}

// Current Sydney UTC offset string, e.g. '+11:00' (AEDT) or '+10:00' (AEST).
function sydneyOffset(d = new Date()) {
  const name = new Intl.DateTimeFormat('en-US', {
    timeZone: TIMEZONE, timeZoneName: 'longOffset',
  }).formatToParts(d).find((p) => p.type === 'timeZoneName')?.value || 'GMT+10';
  const m = name.match(/GMT([+-])(\d{1,2})(?::?(\d{2}))?/);
  if (!m) return '+10:00';
  return `${m[1]}${m[2].padStart(2, '0')}:${m[3] || '00'}`;
}

// Full ISO timestamp for "now" expressed with the Sydney offset.
function sydneyNowISO(now = new Date()) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: TIMEZONE, year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
    }).formatToParts(now).map((x) => [x.type, x.value])
  );
  let hour = p.hour === '24' ? '00' : p.hour;
  return `${p.year}-${p.month}-${p.day}T${hour}:${p.minute}:${p.second}${sydneyOffset(now)}`;
}

/* ---- API ------------------------------------------------------------------ */

async function apiPost(path, body) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(`${API_BASE}/${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`${path} -> HTTP ${res.status}`);
    const json = await res.json();
    if (json && json.Success === false) {
      throw new Error(`${path} -> API error ${JSON.stringify(json.ErrorInfo || {})}`);
    }
    return json;
  } finally {
    clearTimeout(timer);
  }
}

/* ---- formatting ----------------------------------------------------------- */

// 20000000 -> "$20 Million", 4800000 -> "$4.8 Million", 800000 -> "$800,000".
function formatMoney(amount) {
  const n = Number(amount);
  if (!isFinite(n) || n <= 1) return '';
  if (n >= 1e6) {
    const m = n / 1e6;
    const s = Number.isInteger(m) ? String(m) : m.toFixed(1).replace(/\.0$/, '');
    return `$${s} Million`;
  }
  return `$${Math.round(n).toLocaleString('en-AU')}`;
}

// "Thu 30 Jul" for a 'YYYY-MM-DD'.
function shortDate(isoDate) {
  return new Intl.DateTimeFormat('en-AU', {
    timeZone: TIMEZONE, weekday: 'short', day: 'numeric', month: 'short',
  }).format(new Date(isoDate + 'T12:00:00Z'));
}

/* ---- core ----------------------------------------------------------------- */

function pickResult(drawResults, now) {
  const byProduct = {};
  for (const r of drawResults || []) {
    if (!GAMES[r.ProductId]) continue;                 // headline games only
    if (!Array.isArray(r.PrimaryNumbers) || !r.PrimaryNumbers.length) continue;
    const cur = byProduct[r.ProductId];
    if (!cur || r.DrawDate > cur.DrawDate) byProduct[r.ProductId] = r;
  }

  const target = sydneyYesterday(now);

  // Primary path: among every game that drew on the target night, show the
  // highest-priority one (Powerball > Saturday Lotto > Oz Lotto > Weekday
  // Windfall > Lucky Lotteries > Super Jackpot > Set for Life).
  const onNight = Object.values(byProduct)
    .filter((r) => r.DrawDate.slice(0, 10) === target)
    .sort((a, b) => priorityOf(a.ProductId) - priorityOf(b.ProductId));
  if (onNight.length) {
    return { result: onNight[0], path: `priority-on-night (${onNight[0].ProductId} for ${target})` };
  }

  // Fallback: most recently published headline draw across all games. Covers the
  // AEST 23:00 cron edge, public-holiday draw shifts, and late-publishing.
  let best = null;
  for (const r of Object.values(byProduct)) {
    if (r.DrawDate.slice(0, 10) > sydneyDate(now)) continue; // ignore future
    if (!best || r.DrawDate > best.DrawDate) best = r;
  }
  if (best) return { result: best, path: `most-recent-published (${best.ProductId})` };
  return { result: null, path: 'none' };
}

// The next draw OVERALL — the soonest upcoming headline draw of ANY game, not
// just the same series as the last result. So after Monday's Weekday Windfall
// result, "next" is Tuesday's Oz Lotto (with its jackpot), not next Monday.
// opendraws only returns draws still open (undrawn), so the earliest is next.
// Never advertise Set for Life as the NEXT draw — it draws nightly, so it would
// always win on date. The next draw is the closest-dated game from the priority
// list EXCLUDING Set for Life (date first, then the priority order as a tiebreak
// when two games draw the same night).
const NEXT_DRAW_EXCLUDE = new Set(['SetForLife744']);
function nextDrawOverall(openDraws) {
  const upcoming = (openDraws || [])
    .filter((d) => GAMES[d.ProductId] && d.DrawDate && !NEXT_DRAW_EXCLUDE.has(d.ProductId))
    .sort((a, b) =>
      a.DrawDate.localeCompare(b.DrawDate) ||
      (priorityOf(a.ProductId) - priorityOf(b.ProductId)));
  return upcoming[0] || null;
}

function buildRecord(result, next, prev, now) {
  const game = GAMES[result.ProductId];
  const primary = result.PrimaryNumbers.slice();
  const secondary = Array.isArray(result.SecondaryNumbers) ? result.SecondaryNumbers.slice() : [];

  let winningNumbers = primary;
  let supplementary = secondary;
  let powerball = null;
  if (game.hasPowerball) {
    powerball = secondary.length ? secondary[0] : null; // Powerball = SecondaryNumbers[0]
    supplementary = [];
  }

  // The next draw is whatever draws soonest OVERALL (any game), named with ITS
  // own game — not the last result's series.
  const nextGameDef = next && GAMES[next.ProductId] ? GAMES[next.ProductId] : null;
  const nextGameName = nextGameDef ? nextGameDef.name : '';
  let jackpot = '';
  if (next && nextGameName) {
    const when = shortDate(next.DrawDate.slice(0, 10));
    const amt = formatMoney(next.Div1Amount);
    if (amt) {
      const est = next.IsDiv1Estimated ? ' est.' : '';
      jackpot = `Next draw — ${nextGameName} ${when}: ${amt}${est}`;
    }
  }

  return {
    // Only data built from a real operator-feed fetch is ever stamped verified.
    // js/lottery.js keeps the panel HIDDEN unless verified === true, so a
    // sample/placeholder/hand-edited file can never be shown as a real draw.
    verified: true,
    game: game.name,
    drawNumber: result.DrawNumber,
    drawDate: result.DrawDate.slice(0, 10),
    winningNumbers,
    supplementary,
    powerball,
    jackpot,
    // The next draw overall (any game), for a front-end that wants it separately.
    nextGame: nextGameName,
    nextDrawDate: next ? next.DrawDate.slice(0, 10) : '',
    nextBadgeColour: nextGameDef ? nextGameDef.badgeColour : '',
    badgeColour: game.badgeColour,
    // Owner-supplied LOCAL paths — preserved verbatim, never set by this job.
    logoSlot: (prev && typeof prev.logoSlot === 'string') ? prev.logoSlot : '',
    posterSlot: (prev && typeof prev.posterSlot === 'string') ? prev.posterSlot : '',
    ctaHref: CTA_HREF,
    updated: sydneyNowISO(now),
  };
}

// True when the meaningful content differs (ignore the `updated` timestamp so an
// unchanged draw doesn't churn a commit every run).
function contentChanged(next, prev) {
  if (!prev) return true;
  const keys = ['verified', 'game', 'drawNumber', 'drawDate', 'winningNumbers', 'supplementary',
    'powerball', 'jackpot', 'nextGame', 'nextDrawDate', 'nextBadgeColour', 'badgeColour', 'logoSlot', 'posterSlot', 'ctaHref'];
  return keys.some((k) => JSON.stringify(next[k]) !== JSON.stringify(prev?.[k]));
}

async function readPrev() {
  try {
    return JSON.parse(await readFile(DATA_FILE, 'utf8'));
  } catch {
    return null;
  }
}

/* ---- main ----------------------------------------------------------------- */

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    console.log('Usage: node tools/update-lottery.mjs [--dry-run]');
    return 0;
  }
  const dryRun = args.includes('--dry-run');
  const now = new Date();
  const todaySyd = sydneyDate(now);
  const prev = await readPrev();

  // Sydney-date gate. GitHub cron is UTC-only, so we schedule TWO crons
  // (13:00 & 14:00 UTC) to straddle Sydney midnight across AEDT/AEST; this gate
  // makes the job effectively act once per real Sydney day. If we already
  // produced a file for today's Sydney date, skip the network entirely.
  if (!dryRun && prev && prev._gateSydneyDate === todaySyd) {
    console.log(`[skip] already refreshed for Sydney date ${todaySyd}.`);
    return 0;
  }

  let latest, open;
  try {
    [latest, open] = await Promise.all([
      apiPost('latestresults', { CompanyId: COMPANY_ID, MaxDrawCountPerProduct: 1 }),
      apiPost('opendraws', { CompanyId: COMPANY_ID }),
    ]);
  } catch (err) {
    // Fail soft — leave the previous good file untouched.
    console.error(`[fail-soft] fetch failed: ${err.message}. Keeping existing lottery.json.`);
    return 0;
  }

  const { result, path } = pickResult(latest?.DrawResults, now);
  if (!result) {
    console.error('[fail-soft] no usable headline result found. Keeping existing lottery.json.');
    return 0;
  }

  const next = nextDrawOverall(open?.Draws);
  const record = buildRecord(result, next, prev, now);

  // Sanity: never write an empty/broken record.
  if (!record.game || !Array.isArray(record.winningNumbers) || !record.winningNumbers.length) {
    console.error('[fail-soft] built record was invalid. Keeping existing lottery.json.');
    return 0;
  }

  console.log(`[ok] selected via ${path}: ${record.game} draw ${record.drawNumber} (${record.drawDate}) ` +
    `-> ${record.winningNumbers.join(', ')}` +
    (record.powerball != null ? ` PB ${record.powerball}` : '') +
    (record.supplementary.length ? ` + supp ${record.supplementary.join(', ')}` : ''));

  if (dryRun) {
    console.log('--- dry run (nothing written) ---');
    console.log(JSON.stringify(record, null, 2));
    return 0;
  }

  if (!contentChanged(record, prev)) {
    console.log('[no-change] latest draw already reflected — not rewriting (no commit).');
    return 0;
  }

  const out = { ...record, _gateSydneyDate: todaySyd };
  await writeFile(DATA_FILE, JSON.stringify(out, null, 2) + '\n', 'utf8');
  console.log(`[written] ${DATA_FILE}`);
  return 0;
}

// Set exitCode rather than force process.exit(): letting the event loop drain
// naturally lets the fetch/undici sockets close cleanly (a hard exit mid-close
// trips a libuv assertion on Windows/Node 24). The process still ends promptly
// once the keep-alive sockets time out — there is no other pending work.
main().then((code) => {
  process.exitCode = code;
}).catch((err) => {
  // Absolute last resort — still fail soft (exit 0, file untouched).
  console.error(`[fail-soft] unexpected: ${err && (err.stack || err)}`);
  process.exitCode = 0;
});
