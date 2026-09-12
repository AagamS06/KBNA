# Lottery data automation

How `web-design/data/lottery.json` stays current, without anyone touching it
by hand. Two GitHub Actions workflows call the same script once a day; either
one alone is enough to keep the site up to date. Both run on GitHub's free
tier — the whole pipeline has no ongoing cost.

## What runs

Both workflows run **exactly this command** from the repo root:

```
node web-design/tools/update-lottery.mjs
```

The script fetches the latest NSW draw from the official `api.thelott.com`
feed, gates itself on the real `Australia/Sydney` calendar date (so a second
call on the same day is a no-op), and fails soft — on any error it leaves the
previous good `lottery.json` untouched rather than writing anything broken.
See the comment block at the top of that file for the full source/compliance
notes.

## 1. Primary — GitHub Actions

- **File:** [`.github/workflows/lottery-update.yml`](.github/workflows/lottery-update.yml)
- **Schedule:** `0 12 * * *` and `0 13 * * *` (UTC) — the two UTC hours that
  correspond to 11pm Sydney under AEDT (UTC+11, ~Oct–Apr) and AEST (UTC+10,
  ~Apr–Oct). Whichever fires first each day does the real work; the second
  is a no-op via the script's Sydney-date gate.
- **What it does:** runs the script, and if `web-design/data/lottery.json`
  changed, commits **only that file** with the message
  `chore(lottery): refresh daily draw` and pushes to `main`.
- **Manual run:** GitHub → Actions tab → "Daily lottery refresh (primary)" →
  "Run workflow".

## 2. Safety net — GitHub Actions

- **File:** [`.github/workflows/lottery-safety-net.yml`](.github/workflows/lottery-safety-net.yml)
- **Schedule:** `30 12 * * *` and `30 13 * * *` (UTC) — 30 minutes after the
  primary's fire times.
- **Why it exists:** the primary could miss a fire for lots of small reasons
  (workflow paused, a transient GitHub Actions incident in one region, a
  one-off API 5xx that outlasts the primary's retry budget). The safety net
  runs the same script; on a normal day the Sydney-date gate makes it a fast
  no-op, and only on a bad day for the primary does it actually commit.
- **Commit message when it does work:** `chore(lottery): refresh daily draw
  (safety net)`.

Both workflows share the same concurrency group (`lottery-update`) so two
runs can't race the same file.

## Why 11pm, and why two fire times per workflow

**11pm the same night as the draw:** the operator's headline draws close at
8:30pm Sydney and the feed usually finishes publishing final results within
the following hour or two. Firing at 11pm the same day catches the numbers
the same evening the draw ran, rather than the next morning, so a customer
who checks after their evening ticket-check already sees the result up.

**Two fire times per workflow, not one:** GitHub Actions cron is UTC-only and
has no concept of daylight saving. A single fixed UTC time drifts by an hour
on the Sydney clock across the DST boundary. Firing at both UTC hours that
correspond to 11pm Sydney under AEDT and AEST guarantees a fire at the right
*local* time year-round; the script's own `_gateSydneyDate` check makes the
"extra" fire each day a harmless no-op.

| Sydney time | AEDT (UTC+11, ~Oct–Apr) | AEST (UTC+10, ~Apr–Oct) |
|---|---|---|
| 11:00pm | 12:00 UTC (same day) | 13:00 UTC (same day) |
| 11:30pm | 12:30 UTC (same day) | 13:30 UTC (same day) |

## Never use `[skip ci]` in the commit message

Vercel treats `[skip ci]`, `[ci skip]`, `[no ci]`, `[skip vercel]`, and
`[vercel skip]` as opt-out signals and silently skips the deployment. If
either workflow's commit message includes any of those, the fresh
`lottery.json` sits on GitHub without ever reaching `kbna.vercel.app`. Both
workflows commit with plain `chore(lottery): refresh daily draw` (or
` (safety net)`) for exactly this reason. Neither workflow is triggered by
`push` events, so there's no CI-loop risk from dropping the tag.

## Known failure mode (fixed, keep an eye on it)

On 2026-08-17 an earlier Anthropic-cloud-based run of this script got a bare
`HTTP 403` from `opendraws` — the fetch had no `User-Agent`/`Origin` header,
which some edge/WAF configurations block regardless of origin, and it's also
possible that specific cloud sandbox's IP was blocked while a residential IP
wasn't. `update-lottery.mjs` now sends browser-like headers (`User-Agent`,
`Origin`, `Referer` — the same ones a real visit to thelott.com sends to
this same public endpoint) and retries transient failures (403/408/425/429/
5xx, or a thrown network/timeout error) up to 3 times with a short backoff
before giving up.

If both workflows fail on the same day, the panel keeps showing the last
good verified draw (it never shows stale data as if it were current beyond
that — see the "refreshes early in the morning" note on the page) and no
broken file is ever written.
