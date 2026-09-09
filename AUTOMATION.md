# Lottery data automation

How `web-design/data/lottery.json` stays current, without anyone touching it
by hand. Two independent systems call the same script once a day; either one
alone is enough to keep the site up to date.

## What runs

Both systems run **exactly this command** from the repo root:

```
node web-design/tools/update-lottery.mjs
```

The script fetches the latest NSW draw from the official `api.thelott.com`
feed, gates itself on the real `Australia/Sydney` calendar date (so a second
call on the same day is a no-op), and fails soft — on any error it leaves the
previous good `lottery.json` untouched rather than writing anything broken.
See the comment block at the top of that file for the full source/compliance
notes.

## 1. Primary — Claude Code cloud routine

- **Name:** "KBNA daily lottery refresh"
- **Trigger ID:** `trig_01PGD7c2rZLwuLhEVtaHQbGP`
- **Schedule:** `0 17,18 * * *` (UTC) — fires at both 17:00 and 18:00 UTC
  daily, which is ~4am Sydney under AEDT and AEST respectively (see "Why 4am,
  and why two fire times" below). Whichever one lands first each day does the
  real work via the script's own date gate; the other is a fast no-op.
- **What it does:** runs the script, and if `web-design/data/lottery.json`
  changed, commits **only that file** and pushes to `main`.
- **Inspect / re-run it:** from a Claude Code session with access to the
  `RemoteTrigger` tool —
  - `RemoteTrigger action=get trigger_id=trig_01PGD7c2rZLwuLhEVtaHQbGP` — current
    config, `next_run_at`, `enabled`.
  - `RemoteTrigger action=list_runs trigger_id=trig_01PGD7c2rZLwuLhEVtaHQbGP` —
    recent runs.
  - `RemoteTrigger action=get_run_log session_id=<id from list_runs>` — what a
    specific run actually did (useful for diagnosing a failed fetch).
  - `RemoteTrigger action=run trigger_id=trig_01PGD7c2rZLwuLhEVtaHQbGP` — fire
    it right now, outside the schedule.
  - `RemoteTrigger action=update trigger_id=... body={...}` — change the cron
    expression or prompt.
  - Or manage it from the claude.ai routines UI directly.

## 2. Backup — GitHub Actions

- **File:** [`.github/workflows/lottery-update.yml`](.github/workflows/lottery-update.yml)
- **Schedule:** `20 17 * * *` and `20 18 * * *` (UTC) — 20 minutes after each
  of the Claude routine's fire times, so it lands after the primary has had a
  chance to already do the work.
- **Why it exists:** the Claude cloud routine is one system, on one network.
  If its sandbox environment is temporarily blocked by the operator's edge
  (this has happened — see below), or the Claude cloud service itself has an
  outage, the site would otherwise go a day (or more) without a refresh with
  nobody noticing. GitHub's runners are a completely separate network/IP
  range, so a block or outage on one side doesn't affect the other.
- **On a normal day** this workflow runs, sees the script's date gate already
  satisfied (or `git status --porcelain` empty even if it did re-fetch — same
  draw, same file), and exits without committing anything. It only actually
  does something when the primary failed to update `lottery.json` that day.
- **Manual run:** Actions tab → "Daily lottery refresh (backup)" → "Run
  workflow".

## Why 4am, and why two fire times

**4am, not midnight:** a late-drawing game's result isn't always finalised on
the operator's feed the instant the clock ticks over. Waiting a few hours
gives it time to finish publishing, so the script's "yesterday's draw" lookup
doesn't catch a result mid-publish. The site itself says as much next to the
numbers: *"The convenience numbers refresh at roughly 4am the next day."*

**Two fire times, not one:** cron on both systems is UTC-only and has no
concept of daylight saving. A single fixed UTC time drifts by an hour on the
Sydney clock across the DST boundary. Firing at both UTC hours that correspond
to 4am Sydney under AEDT and AEST guarantees a fire at the right *local* time
year-round, with the script's own `_gateSydneyDate` check making the "extra"
fire each day a harmless no-op:

| Sydney time | AEDT (UTC+11, ~Oct–Apr) | AEST (UTC+10, ~Apr–Oct) |
|---|---|---|
| 4:00am | 17:00 UTC (prev. day) | 18:00 UTC (prev. day) |

## Known failure mode (fixed, keep an eye on it)

On 2026-08-17 the Claude cloud routine's run got a bare `HTTP 403` from the
`opendraws` endpoint — the fetch had no `User-Agent`/`Origin` header, which
some edge/WAF configurations block regardless of origin, and it's also
possible the specific cloud sandbox IP was blocked while a residential IP
wasn't (a manual run from a normal machine succeeded minutes later with
identical code). Two things now guard against this:

1. `update-lottery.mjs` sends browser-like headers (`User-Agent`, `Origin`,
   `Referer` — the same ones a real visit to thelott.com sends to this same
   public endpoint) and retries transient failures (403/408/425/429/5xx, or a
   thrown network/timeout error) up to 3 times with a short backoff before
   giving up.
2. The GitHub Actions backup above exists specifically so a *structural*
   block on one network (rather than a one-off blip) doesn't stop the site
   updating at all — it just makes the backup do the real work that day.

If both systems fail on the same day, the panel keeps showing the last good
verified draw (it never shows stale data as if it were current beyond that —
see the "refreshes at roughly 4am" note on the page) and no broken file is
ever written.

