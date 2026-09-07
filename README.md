# Knightsbridge Newsagency

Website for **Knightsbridge Newsagency** — Shop 5, 159 Ridgecrop Drive, Castle
Hill NSW 2154, Australia. Papers, magazines, cards, gifts, toys and lotto.
Open 7 days (weekdays 8am–6pm, weekends 8am–4pm).

This repo holds the public website and the design specs that drive it. Owner
stock/order management is being folded back into the website (owner login area,
online reserve-and-collect with SMS + web-push notifications). The former
Flutter owner app has been retired and lives under the [`archive/flutter-owner-app`](https://github.com/AShah-01/KBNA/tree/archive/flutter-owner-app) branch
for reference only.

## What's here

| Path | What it is |
|---|---|
| [`web-design/`](web-design/) | The public website — static HTML/CSS/JS, no build step. Shop, cart, reviews, gallery, daily lottery panel. Owner admin area is being added under `web-design/admin/`. |
| [`app-design/`](app-design/) | Architecture, UX, and photo-integration specifications (from the archived Flutter app; still useful as reference for the web admin build-out). |
| Branch `archive/flutter-owner-app` | Retired Flutter owner app, preserved on its own branch. Kept for reference; no longer built or tested. Not present on `main`. |
| [`.github/workflows/`](.github/workflows/) | CI-related workflows. The daily lottery-results updater now runs as a Claude Code cloud routine (see below). |

## The website

Pure static — open [`web-design/index.html`](web-design/index.html) in a
browser, or host the folder as-is. Three-colour brand (signal red `#E1251B`,
black, white), Plus Jakarta Sans + Atkinson Hyperlegible, WCAG 2.1 AA, PWA,
SEO/schema.org, and a lottery panel fed daily from the official Lott results
feed. Owner stock management is **not** on the website — it lives in the app.

**Run it:** just open the folder's `index.html`, or serve it:
```bash
cd web-design && python -m http.server 8000   # then open http://localhost:8000
```

## The owner admin area (in progress)

The owner-side of the business — product/stock management, incoming online
orders, sign-in — is being built into the website under `web-design/admin/`,
gated by Supabase Auth (max 5 owner accounts). Customers can reserve items
online and collect in store; owners receive SMS + web-push notifications for
each new order and mark it ready/collected in the admin dashboard.

The retired Flutter app that used to do this lives on its own branch,
[`archive/flutter-owner-app`](https://github.com/AShah-01/KBNA/tree/archive/flutter-owner-app)
(not present on `main`); its Supabase schema at `app/supabase/schema.sql` on
that branch is the starting point for the web admin backend.

## The lottery panel

Refreshed once a day at ~4am Sydney time (not right at midnight, so results
have time to finish publishing on the operator's feed): a Claude Code cloud
routine runs primarily, and [`.github/workflows/lottery-update.yml`](.github/workflows/lottery-update.yml)
runs ~20 minutes later as a backup in case the cloud routine's environment is
unreachable or blocked. Both call the same script,
[`web-design/tools/update-lottery.mjs`](web-design/tools/update-lottery.mjs),
which pulls the latest NSW draw's winning numbers from the official
`api.thelott.com` feed and writes `web-design/data/lottery.json`. The home page
shows it under the hero. Only facts (numbers, jackpot) are used; the draw badge
is an own-drawn SVG and the poster slot is an owner-supplied local file — no
scraped posters or trademarked logos. See [`AUTOMATION.md`](AUTOMATION.md) for
how the schedule and the backup are wired up.

## Security

- Website: Content-Security-Policy on every page, edge headers (`_headers` /
  `.htaccess`), `security.txt`. See [`web-design/HOSTING-SECURITY.md`](web-design/HOSTING-SECURITY.md).
- Admin area (in progress): only the Supabase anon key ships; Row Level Security
  is the authorisation model. Schema lives on the `archive/flutter-owner-app`
  branch at `app/supabase/schema.sql`.
- Reporting: [`SECURITY.md`](SECURITY.md).

## Branches

- **`main`** — the active line for the website + admin build-out.
- **`archive/flutter-owner-app`** — retired Flutter owner app; reference only, never merged back.

## Status

Website is production-ready (swap the placeholder domain first). Owner admin
area (login, product/stock CRUD, incoming orders, SMS + web-push notifications)
is being built directly into the website; the retired Flutter app on the
`archive/flutter-owner-app` branch is reference material only.

## Licence

© Knightsbridge Newsagency. All rights reserved. See [`LICENSE`](LICENSE).
