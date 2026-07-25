# Lottery panel — data contract

The home page (`index.html`) shows a **daily lottery results panel** in the hero
area. It is driven entirely by one file:

```
web-design/data/lottery.json
```

The renderer is `js/lottery.js`, mounted into `#lottery-panel` on the home page.

## How it behaves

- **File present and valid** → the panel fills in and reveals itself.
- **File missing, empty, malformed, or blocked** (including opening the site
  from `file://`, where `fetch` of a local JSON is blocked) → the panel stays
  hidden. Nothing breaks, no error is shown. This is the default state shipped.
- It is **read-only**. `js/lottery.js` never writes the file. A later job
  (cron, the owner app, a paste-in) overwrites `lottery.json` once a day.

## The fields

| Field            | Type            | Required | Notes |
|------------------|-----------------|----------|-------|
| `game`           | string          | yes      | Game name, e.g. `"Saturday Lotto"`. Drawn into the SVG badge. |
| `drawNumber`     | integer         | no       | Shown as `Draw 4512`. |
| `drawDate`       | string (ISO date) | no     | `YYYY-MM-DD`; rendered in en-AU long form. |
| `winningNumbers` | number[]        | yes      | Main numbers, in draw order. Rendered as filled balls. |
| `supplementary`  | number[]        | no       | Rendered as outlined balls after a divider. |
| `powerball`      | number \| null  | no       | Single Powerball number, rendered as a highlighted ball. |
| `jackpot`        | string          | no       | Free-text line under the numbers. |
| `badgeColour`    | string (hex)    | no       | Badge colour. **Palette only:** `#E1251B`, `#111111`, `#FF6E63`. Others snap to `#E1251B`. |
| `logoSlot`       | string (local path) | no   | Optional owner-licensed badge image under `assets/lottery/`. **Local only.** Empty → own SVG badge. |
| `posterSlot`     | string (local path) | no   | Optional owner-supplied poster under `assets/lottery/`. **Local only.** Missing file → slot hides. |
| `ctaHref`        | string (URL)    | no       | Link for the "Check your numbers" button. Omit → no button. |
| `updated`        | string (ISO datetime) | no | Shown as a small "Updated …" note. |

## Hard rules (read before you wire up a feed)

1. **No trademarked logos, no scraped posters.** `logoSlot` and `posterSlot`
   are *local* asset paths under `web-design/assets/lottery/` for images the
   owner is licensed to use. Never point them at an external URL, a lottery
   operator's logo, or a scraped poster. The default (empty `logoSlot`) draws
   the site's **own** SVG badge — game name + palette colour — which is always
   safe to ship.
2. **Palette is fixed** — red `#E1251B`, black `#111111`, white, plus
   `#FF6E63` for red on dark. `badgeColour` is validated against this set.
3. **Paths are relative** so the site keeps working from a sub-folder and, for
   local assets, from `file://`.
4. **Degrade silently.** Any problem loading or parsing the file must leave the
   panel hidden, never half-rendered.

## For the next agent

The seam is already in place — you do **not** need to restructure the page:

- Markup: `<section id="lottery-panel" class="band lottery-band" hidden …>` sits
  directly under the hero in `index.html`.
- Renderer: `js/lottery.js` exposes `initLotteryPanel('lottery-panel', 'data/lottery.json')`,
  already called from `js/page-home.js`.
- Styles: `.lottery-*` rules live in `style.css`.
- SVG badge: `lotteryBadgeSVG(game, colour)` in `js/lottery.js` draws the
  trademark-free badge. Extend it there.

Drop owner-supplied local images into `web-design/assets/lottery/` and reference
them by relative path in the JSON. That's the whole integration.
