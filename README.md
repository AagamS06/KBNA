# Knightsbridge Newsagency

Website and owner app for **Knightsbridge Newsagency** — Shop 5, 159 Ridgecrop
Drive, Castle Hill NSW 2154, Australia. Papers, magazines, cards, gifts, toys
and lotto. Open 7 days (weekdays 8am–6pm, weekends 8am–4pm).

This repo holds three things: the public website, a cross-platform owner app,
and the design specs that drive them.

## What's here

| Path | What it is |
|---|---|
| [`web-design/`](web-design/) | The public website — static HTML/CSS/JS, no build step. Shop, cart, reviews, gallery, daily lottery panel. |
| [`app/`](app/) | The owner app — Flutter (iOS + Android). Stock, orders, photos, settings. Replaces the old web owner portal. |
| [`app-design/`](app-design/) | Architecture, UX, and photo-integration specifications. |
| [`.github/workflows/`](.github/workflows/) | CI, and the daily lottery-results updater. |

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

## The owner app

Flutter (Dart 3, Material 3, Riverpod, go_router). Local-first: it runs fully
offline on a seeded local database, and syncs to Supabase when a backend is
configured. Photos come from the phone's own picker (so iCloud / Google Photos
appear as sources), with EXIF/GPS stripped.

**Run it (needs the Flutter SDK + VS Code Flutter extension):**
```bash
cd app
flutter create .          # generates the android/ios platform folders
flutter pub get
flutter run               # runs local-only; no backend needed
```
Full run and publish steps: [`app/README.md`](app/README.md),
[`app/DEPLOYMENT.md`](app/DEPLOYMENT.md),
[`app/STORE-READINESS.md`](app/STORE-READINESS.md).

## The lottery panel

A GitHub Action ([`.github/workflows/lottery-update.yml`](.github/workflows/lottery-update.yml))
runs at Sydney midnight, pulls the latest NSW draw's winning numbers from the
official `api.thelott.com` feed, and writes `web-design/data/lottery.json`. The
home page shows it under the hero. Only facts (numbers, jackpot) are used; the
draw badge is an own-drawn SVG and the poster slot is an owner-supplied local
file — no scraped posters or trademarked logos.

## Security

- Website: Content-Security-Policy on every page, edge headers (`_headers` /
  `.htaccess`), `security.txt`. See [`web-design/HOSTING-SECURITY.md`](web-design/HOSTING-SECURITY.md).
- App: only the Supabase anon key ships; Row Level Security is the authorisation
  model. See [`app/SECURITY.md`](app/SECURITY.md) and
  [`app/supabase/schema.sql`](app/supabase/schema.sql).
- Reporting: [`SECURITY.md`](SECURITY.md).

## Branches

- **`KBNA-App`** — the full project (app + website + lottery + specs). Active line.
- **`KBNA-Web`** — a website-only snapshot.
- **`main`** — landing branch; receives the full project when the open PR merges.

## Status

Website is production-ready (swap the placeholder domain first). App core is
built and read-verified; barcode-scanner, analytics, and click-&-collect
screens are the next round. Publishing to the App Store / Google Play needs the
developer accounts, signing, a real Supabase project, and a domain — all listed
in [`app/STORE-READINESS.md`](app/STORE-READINESS.md).

## Licence

© Knightsbridge Newsagency. All rights reserved. See [`LICENSE`](LICENSE).
