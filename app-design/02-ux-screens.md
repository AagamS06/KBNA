# Knightsbridge Newsagency — Owner App
## UX and screen-by-screen interface specification

**Document:** 02-ux-screens
**Platforms:** iOS 16+ and Android 10+ (API 29+)
**Audience:** one person — the shop owner. Non-technical, 40s–60s, phone in one hand, customer in front of them.
**Replaces:** `knightsbridge-static/owner.html`
**Design language source:** `knightsbridge-static/style.css`

---

## 0. The one-sentence brief

This is not a shop app and not a consumer app. It is **a counter tool that happens to also do paperwork** — so the interface is optimised, in order, for: *look something up fast*, *change a number fast*, *hide something from the website fast*, and only then for everything else.

Two principles drive every decision below.

**P1 — The counter never waits for the network.**
Every read (price, stock, tag, hold state) and every write (adjust count, hold, edit) happens against a local copy of the data and succeeds instantly. Sync is a background concern the owner is told about but never blocked by. The only genuinely online feature is the automatic photo lookup, and it already fails softly on the website.

**P2 — The bottom of the screen belongs to the thumb.**
On a 6.7" phone the top 40% of the display is unreachable one-handed. Anything the owner touches while serving a customer lives in the bottom 420 pt. This overrides platform habit where the two conflict, and Section 4 says exactly where and why.

---

## 1. Information architecture

### 1.1 Decision: a three-item bottom tab bar

```
┌──────────────────────────────────────────┐
│                                          │
│              (screen content)            │
│                                          │
├──────────────────────────────────────────┤
│    ▤            ☰            ▦           │
│  Today        Stock        Orders        │
└──────────────────────────────────────────┘
```

**Three top-level destinations: Today, Stock, Orders.**

### 1.2 Why a tab bar and not a drawer

| Consideration | Verdict |
|---|---|
| Number of destinations | 3. A drawer is only worth its cost above ~5. |
| Discoverability | A drawer hides everything behind a hamburger. For one non-technical user who opens the app under pressure, every top-level destination must be *visible without an action*. |
| Reach | A bottom tab bar is the single most thumb-reachable control surface on a phone. A drawer handle sits in the top-left — the worst corner for a right-handed one-handed grip. |
| Task switching | The owner bounces between "what's low" and "find this item" constantly. Tabs preserve each destination's scroll position and state; a drawer resets the mental model each time. |
| Platform fit | Native on both: `UITabBarController` (iOS), `NavigationBar` (Material 3). No custom pattern to learn. |

A drawer would be correct if this app had multiple user roles, or a long tail of rarely-visited sections. It has neither.

### 1.3 Why Settings is not a fourth tab

Settings is opened a handful of times a year (change password, change shop details, look at removed items). Giving it 25% of the permanent navigation real estate would be a mis-weighting, and it would shrink the three tabs that matter.

Settings lives as a **gear icon in the top-right of the Today screen's nav bar** — a convention both platforms already teach, present on exactly one screen so it is never ambiguous where it lives. Today's screen is also where the account is represented, so the pairing reads naturally.

The rejected alternative — a "More" tab — is worse: non-technical users reliably lose things inside "More".

### 1.4 Full map

```
Today  (tab 1, default on cold start)
 ├── Settings                        [gear, top-right]
 │    ├── Sign-in details
 │    ├── Shop details
 │    ├── Alerts
 │    ├── Appearance
 │    ├── Removed items  ──► Item detail (restore)
 │    ├── Help
 │    └── Advanced ──► Reset all data
 ├── Low-stock item row ──► Item detail
 └── Recent order row   ──► Order detail

Stock  (tab 2)
 ├── [bottom-anchored search]
 ├── Category filter chips
 ├── Item row  ──► Item detail  ──► Edit item
 │                              └─► Remove (confirm)
 └── + Add item ──► Add item form ──► Category picker
                                  └─► Photo options

Orders (tab 3)
 └── Order row ──► Order detail ──► Share / Export
```

Maximum depth from any tab to any screen: **3**. Nothing in this app is four levels deep.

### 1.5 Launch behaviour ("sticky tab")

- Cold start after more than 4 hours away → **Today**. The owner is starting a shift; they want the alerts.
- Cold start or resume within 4 hours → **the tab they were last on**. Mid-shift, that is almost always Stock, which saves one tap on the most frequent task of the day.
- Launched from a home-screen quick action → straight to that destination (Section 3.4).

---

## 2. Screen-by-screen specifications

Wireframes are drawn at a nominal 390 × 844 pt viewport. `[ ]` is a tappable control. `▸` is a disclosure. Every wireframe shows the default state; states are enumerated beneath it.

---

### 2.1 Sign in

**Purpose.** Prove it's the owner, once, then get out of the way. This screen should be seen roughly twice a year.

**Layout.**

```
┌──────────────────────────────────────────┐
│                                          │  ← no nav bar, no back
│                                          │
│                                          │
│   ██  KNIGHTSBRIDGE                      │  ← red mark + wordmark
│       NEWSAGENCY                         │
│                                          │
│   OWNER SIGN-IN                          │  ← eyebrow, 12pt, tracked
│                                          │
│   Sign in to manage                      │  ← H1, 28pt ExtraBold
│   your stock.                            │
│                                          │
│   Email address                          │
│   ┌────────────────────────────────────┐ │
│   │ owner@knightsbridgenews.com.au     │ │  ← 52pt tall
│   └────────────────────────────────────┘ │
│                                          │
│   Password                          [👁] │  ← show/hide, 48×48
│   ┌────────────────────────────────────┐ │
│   │ ••••••••••••                       │ │
│   └────────────────────────────────────┘ │
│                                          │
│   [ Sign in                         (→) ]│  ← pill, red, arrow badge
│                                          │
│   [ Use Face ID instead ]                │  ← text button, if enrolled
│                                          │
│   [ I've forgotten my password ]         │  ← text button
│                                          │
├──────────────────────────────────────────┤
│   Shop 5, 159 Ridgecrop Drive            │  ← quiet footer, 13pt
│   Castle Hill NSW 2154                   │
└──────────────────────────────────────────┘
```

**Elements.**

| Element | Spec |
|---|---|
| Logo mark | Red square with white "K", 44 × 44. Decorative — `accessibilityElementsHidden`. |
| Eyebrow "OWNER SIGN-IN" | 12 pt / 700 / +0.18em / uppercase / red (`#B3140C` light, `#FF6E63` dark). Purely decorative to a screen reader; the H1 carries meaning. |
| Email field | `textContentType: username`, keyboard `emailAddress`, autocapitalisation off, autocorrect off. Prefilled from Keychain / Credential Manager if previously saved. |
| Password field | `textContentType: password`, secure. Reveal toggle is a real 48 × 48 button labelled "Show password" / "Hide password", state announced. |
| Sign in | Full-width pill, `#C81A12` fill, white 17 pt/600 label, circular white arrow badge on the right (the site's signature CTA). Height 56. Disabled until both fields are non-empty. |
| Face ID / Fingerprint | Shown only after a successful password sign-in has enrolled it. Label matches the hardware: "Use Face ID", "Use Touch ID", "Use fingerprint". |
| Forgot password | Opens the recovery sheet (2.1 states). |

**Behaviour.** On success the biometric prompt appears automatically on every subsequent launch, before the form is even shown — so the steady-state cost of sign-in is a glance, not a typed password.

**States.**

- **Idle** — as drawn. Sign in button disabled (40% opacity, still readable, plus `accessibilityTraits: .notEnabled`).
- **Loading** — button label swaps to "Signing in…" with an inline spinner replacing the arrow badge. Fields become non-editable but stay legible (never grey out to unreadable). Button announces "Signing in, please wait".
- **Error — wrong details** —
  ```
  ┌────────────────────────────────────────┐
  │ ⊗  That email or password isn't right. │  ← red hairline border,
  │    Check for a stray space, then try   │     red tint wash bg
  │    again.                              │
  └────────────────────────────────────────┘
  ```
  Appears directly above the Sign in button, `role="alert"` / `accessibilityLiveRegion: assertive`, focus moved to it. Both fields get a red 2 pt border **and** the ⊗ glyph, so the error is not carried by colour alone. Password is cleared; email is not.
- **Error — no internet** — "You're not connected to the internet. Sign-in needs a connection just this once — after that the app works offline." Button: **Try again**.
- **Error — offline but previously signed in** — does not occur. A returning owner is signed in from the local session and never sees this screen without a connection.
- **Locked out** — after 8 wrong attempts: "Too many tries. Wait 5 minutes and have another go." Countdown shown as live text.
- **Empty / first run** — see Section 7.1.
- **Recovery sheet** — half-height sheet: "We'll email a reset link to the address on file. It's the address ending **…au**." with a masked hint, and one button, "Send the link". Success replaces the sheet content with "Check your email. The link works for 30 minutes."

---

### 2.2 Today (home / dashboard)

**Purpose.** Answer, in one glance from arm's length: *is anything wrong, and what happened while I wasn't looking?*

**Layout.**

```
┌──────────────────────────────────────────┐
│ Today                              [⚙]   │  ← large title, gear
│ Thursday 24 July                         │  ← 15pt muted subtitle
├──────────────────────────────────────────┤
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ⚠  NEEDS ATTENTION                   │ │  ← red border card
│ │                                      │ │
│ │ 3 items are low or on hold           │ │  ← H2 22pt
│ │                                      │ │
│ │ Scented Candle — Vanilla             │ │
│ │ 2 left · alert at 3 · ON HOLD        │ │
│ │                        [ Release ]▸  │ │
│ │ ───────────────────────────────────  │ │
│ │ National Geographic                  │ │
│ │ 3 left · alert at 3                  │ │
│ │                        [ Restock  ]▸ │ │
│ │ ───────────────────────────────────  │ │
│ │ Sympathy Card                        │ │
│ │ 4 left · alert at 4                  │ │
│ │                        [ Restock  ]▸ │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ AT A GLANCE                              │  ← eyebrow
│ ┌──────────────┐  ┌──────────────┐       │
│ │      47      │  │      12      │       │
│ │ items in     │  │ on the       │       │
│ │ stock        │  │ website      │       │
│ └──────────────┘  └──────────────┘       │
│                                          │
│ RECENT ONLINE ORDERS                     │
│ ┌──────────────────────────────────────┐ │
│ │ Today, 9:14 am           $17.40    ▸ │ │
│ │ 3 items · Card                       │ │
│ │ ───────────────────────────────────  │ │
│ │ Yesterday, 4:02 pm       $6.20     ▸ │ │
│ │ 1 item · PayPal                      │ │
│ └──────────────────────────────────────┘ │
│ [ See all orders ]                       │
│                                          │
│           Everything is saved. ✓         │  ← sync line, 13pt
├──────────────────────────────────────────┤
│    ▤            ☰            ▦           │
│  Today        Stock        Orders        │
└──────────────────────────────────────────┘
```

**Elements.**

| Element | Spec |
|---|---|
| Large title "Today" | 34 pt / 800. Collapses to a 17 pt centred inline title on scroll (iOS large-title behaviour; Android `LargeTopAppBar` with the same collapse). |
| Date subtitle | Formatted to the device locale, `en-AU` default: "Thursday 24 July". |
| Gear | 48 × 48 hit target, 24 pt glyph. Label: "Settings". |
| Needs attention card | Only rendered when count > 0. 1.5 pt `#B3140C` border, `#FDECEB` wash (light) / `#2A1110` (dark), ⚠ glyph, and the word count in text — three redundant signals, none of them colour alone. |
| Low-stock row | Item name (17 pt/700), then a status line: `{n} left · alert at {t}` and, if held, ` · ON HOLD` as an uppercase 12 pt pill. Trailing button is contextual: **Release** if held, **Restock** if merely low. |
| Stat tiles | Two flat cards, hairline border. Big number 34 pt/800, label 13 pt. "Items in stock" = active items. "On the website" = active AND not held. Tapping either opens Stock pre-filtered. |
| Recent orders | Newest 3. Row = relative timestamp, total (tabular figures, right-aligned), item count and payment method. |
| Sync line | Persistent, quiet, bottom of scroll. Four possible strings — see states. |

**Behaviour.** Pull-to-refresh re-syncs. The Needs attention card is the only element that ever animates in; it uses a 200 ms fade, suppressed under Reduce Motion.

**States.**

- **Loading (cold, no cached data)** — skeleton placeholders in the exact shape of the final cards, no spinner. Announces "Loading your shop".
- **Loading (cached data present)** — cached content shown immediately; a 2 pt red progress hairline under the nav bar indicates refresh. Never a blocking spinner.
- **All good (empty attention state)** — the red card is replaced by:
  ```
  ┌──────────────────────────────────────┐
  │ ✓  ALL GOOD                          │
  │                                      │
  │ Nothing needs your attention.        │
  │ Every item is above its alert level. │
  └──────────────────────────────────────┘
  ```
  Black hairline border, no red. (The site's rule: red means *look at this*, black means *all good*. Success is deliberately not green — the palette has no green.)
- **Empty shop (no items at all)** — the whole body is replaced by a single centred block: "Your stock list is empty. / Add the first thing you sell and it'll show up here." with a primary **Add your first item** pill.
- **No orders yet** — the orders card reads "No online orders yet. They'll appear here the moment one comes in." and the "See all orders" button is hidden.
- **Offline** — a persistent, non-dismissable strip pinned directly under the nav bar:
  ```
  ┌──────────────────────────────────────────┐
  │ ⌁  No internet. You can still do         │
  │    everything — we'll save it up.        │
  └──────────────────────────────────────────┘
  ```
  Black background, white text, 44 pt tall. Not red: offline is not an error, and reserving red for genuine problems is what keeps red meaningful.
- **Sync line, four strings** — "Everything is saved. ✓" / "Saving…" / "3 changes waiting for the internet." / "Some changes didn't save. [Fix this]". Only the last is red, and it carries a glyph too.
- **Error — couldn't load** — the body is replaced by: "We couldn't reach your shop's information just now. Nothing is lost." + **Try again** + "Your last saved copy is from 8:02 am. [Use that instead]".

---

### 2.3 Stock list

**Purpose.** The screen the owner lives in. Find any item in under three seconds, and change it without leaving the list.

**Layout.**

```
┌──────────────────────────────────────────┐
│ Stock                            [ + ]   │  ← large title, add
│ 47 items                                 │
├──────────────────────────────────────────┤
│  ⟨ [All] [Paper] [Magazine] [Cards] …  ⟩ │  ← horizontal chip rail
├──────────────────────────────────────────┤
│ ┌──────────────────────────────────────┐ │
│ │ The Daily Telegraph (Weekday)        │ │
│ │ Paper                                │ │
│ │ $2.60          [ − ]  40  [ + ]      │ │  ← 48×48 steppers
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ National Geographic          ▎LOW    │ │  ← red left rule + word
│ │ Magazine                             │ │
│ │ $14.50         [ − ]   3  [ + ]      │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ Scented Candle — Vanilla   ▎ON HOLD  │ │
│ │ Gifts · hidden from customers        │ │
│ │ $12.95         [ − ]   2  [ + ]      │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ Birthday Card — Classic Range        │ │
│ │ Cards                                │ │
│ │ $7.95          [ − ]  25  [ + ]      │ │
│ └──────────────────────────────────────┘ │
│                    ⋮                     │
├──────────────────────────────────────────┤
│ ┌──────────────────────────────────────┐ │
│ │ 🔍  Search stock                     │ │  ← BOTTOM-ANCHORED
│ └──────────────────────────────────────┘ │     56pt, always visible
├──────────────────────────────────────────┤
│    ▤            ☰            ▦           │
│  Today        Stock        Orders        │
└──────────────────────────────────────────┘
```

**The one unusual decision: the search field is at the bottom.**

Search is the single most-used control in the app and it is used while holding a customer's newspaper in the other hand. A top-anchored search bar on a 6.7" phone sits roughly 700 pt from the thumb's resting position; a bottom-anchored one sits at about 120 pt. Safari and Chrome both moved their address bars down for the same reason. It stays pinned above the tab bar at all scroll positions and is not hidden by scrolling.

**Row anatomy.**

```
┌────────────────────────────────────────────┐
│ ┃ Item name                    ▎STATUS     │  16pt padding
│ ┃ Category · optional note                 │
│ ┃ $Price          [ − ]   n   [ + ]        │
└────────────────────────────────────────────┘
   ↑                  ↑       ↑
   4pt red rule    48×48    tabular
   (low/held only) targets  figures, 20pt/800
```

| Element | Spec |
|---|---|
| Name | 17 pt / 700 Plus Jakarta Sans, truncates to two lines. |
| Status pill | Uppercase 11 pt / 700, tracked. `LOW`, `ON HOLD`, `SOLD OUT`. Accompanied by a 4 pt red rule on the row's leading edge. Never colour alone: the word is always present. |
| Category line | 15 pt Atkinson Hyperlegible, muted. Appends "· hidden from customers" when held. |
| Price | 20 pt / 800, tabular figures, so prices align down the column and are scannable. |
| Stepper | Two 48 × 48 circular buttons with a 1.5 pt `#8A8A8A` border, flanking a 20 pt/800 tabular count. `−` disabled at 0 (60% opacity + `.notEnabled`). |
| Row body | Tapping anywhere that is *not* the stepper opens Item detail. |

**Gestures.**

- **Swipe leading→trailing (right on LTR)**: reveals **Hold** / **Release** — full-height red action with a text label, never an icon alone.
- **Swipe trailing→leading (left on LTR)**: reveals **Edit** (black) and **Remove** (red).
- **Long press**: opens a context menu with Hold/Release, Edit, Duplicate, Remove. This is the *primary* discoverable path on Android, where swipe-to-action is not a taught convention (Section 4.4).
- **Long press on the count**: opens the number-pad sheet (2.3, "Set count sheet").

**Sorting and filtering.**

- Default sort: **Needs attention first** (held, then sold out, then low), then A–Z. The owner's most likely reason to open Stock without searching is to deal with a problem.
- Chip rail: `All`, then each distinct tag from the data, in the site's order (Magazine, Paper, Toys, Cards, Stationery, Gifts, Lottery), then any custom tags A–Z. Chips are 48 pt tall pills; the active chip is a red fill with white text **plus** a `✓` glyph.
- A sort control lives in the search field's trailing edge as a small `⇅` button (48 × 48): Needs attention / A–Z / Price / Stock level / Recently changed.

**Search behaviour.**

- Matches on name, then category, then description. Case- and accent-insensitive, matches on word starts as well as substrings, so "tel" finds "The Daily **Tel**egraph".
- Filters live, per keystroke, against local data — zero latency, works offline.
- The matched substring is shown in **bold**, not in red (red is reserved for state).
- A `✕` clear button (48 × 48) appears inside the field once there is text.
- Result count is announced politely to screen readers: "4 items found".

**States.**

- **Loading** — 6 skeleton rows.
- **Empty (no items)** — "Nothing in your stock list yet." + **Add your first item**.
- **Empty (no search results)** — "Nothing matches "candel". / Check the spelling, or add it as a new item." + a secondary **Add "candel" as a new item** button that pre-fills the name field. This turns a dead end into a shortcut.
- **Empty (filter returns nothing)** — "No items tagged Lottery." + **Show all items**.
- **Offline** — identical. The list is local. The only difference is the offline strip and a small `⌁` on rows with unsynced changes.
- **Saving a stepper change** — optimistic. The number changes instantly. If the eventual write fails, the row shows a red `⌁ not saved` pill and the sync line on Today updates. Never a spinner on a stepper.
- **Undo** — every stepper tap and every hold/release raises a snackbar for 6 seconds: "Sold one Daily Telegraph. [Undo]". Repeated taps coalesce into one snackbar: "Sold 4 Daily Telegraph. [Undo]" — undoing reverts all four.

**Set count sheet** (long-press the count, or tap the count in Item detail):

```
┌──────────────────────────────────────────┐
│              ▁▁▁▁▁▁                      │  ← grabber
│                                          │
│   National Geographic                    │
│   How many are on the shelf?             │
│                                          │
│          ┌───────────────┐               │
│          │      12       │               │  ← 44pt, tabular
│          └───────────────┘               │
│                                          │
│   [ 1 ] [ 2 ] [ 3 ]                      │
│   [ 4 ] [ 5 ] [ 6 ]                      │  ← 64×64 keys
│   [ 7 ] [ 8 ] [ 9 ]                      │
│   [ ✕ ] [ 0 ] [ ⌫ ]                      │
│                                          │
│   [ Save                             ]   │
└──────────────────────────────────────────┘
```

A purpose-built pad, not the system keyboard: bigger keys, no letters, no autocorrect, and it opens instantly. Keys are 64 × 64 — well beyond the minimum, because this is used while distracted.

---

### 2.4 Item detail

**Purpose.** The full picture of one item, and the launch point for editing. Deliberately read-mostly: the things done in a hurry are already possible from the list.

**Layout.**

```
┌──────────────────────────────────────────┐
│ ‹ Stock                          [ ⋯ ]   │
├──────────────────────────────────────────┤
│ ┌──────────────────────────────────────┐ │
│ │                                      │ │  ← photo, 16:9,
│ │          (product photo)             │ │    or generated
│ │                                      │ │    category artwork
│ └──────────────────────────────────────┘ │
│ Photo from Flickr · CC BY 2.0            │  ← credit, 12pt, if any
│                                          │
│ MAGAZINE                                 │  ← eyebrow
│ National Geographic                      │  ← H1 28pt
│ Current monthly issue.                   │  ← body 17pt
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ▎ON HOLD — hidden from customers     │ │
│ │  Stock fell to its alert level, so   │ │
│ │  we took it off the website for you. │ │
│ │                     [ Put it back ]  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ Price                            $14.50  │
│ ────────────────────────────────────────  │
│ On the shelf         [ − ]  3  [ + ]     │
│ ────────────────────────────────────────  │
│ Warn me at                            3  │
│ ────────────────────────────────────────  │
│ On the website                       No  │
│ ────────────────────────────────────────  │
│ Last changed          Today, 8:14 am     │
│                                          │
├──────────────────────────────────────────┤
│ [ Edit this item                     ]   │  ← sticky, thumb zone
└──────────────────────────────────────────┘
```

**Elements.**

| Element | Spec |
|---|---|
| Photo | 16:9. Falls back to generated category artwork (as the website does) when `image_url` is absent or fails. Never a broken-image glyph. |
| Credit line | Rendered only when `image_credit` exists. 12 pt muted. The licence link opens in the in-app browser. |
| Eyebrow | The `tag`, uppercase, tracked, red. |
| Status card | Present only when held / low / sold out. Explains *why* in a sentence, and offers the single corrective action. |
| Detail rows | Label left, value right, 56 pt tall, hairline separator. "On the shelf" carries a live stepper. Everything else is read-only here. |
| `⋯` menu | Hold/Release · Duplicate · Share item details · Remove item. |
| Sticky footer | Full-width **Edit this item** pill, black outline. Sits in the thumb zone rather than as a nav-bar "Edit" (Section 4.2). |

**States.**
Loading: skeleton with the photo block grey. Error (item no longer exists): full-screen "This item has been removed. [Back to stock]". Offline: unchanged, with `⌁ Saved on this phone` on the "Last changed" row. Removed item (opened from Settings → Removed items): the footer button becomes **Put this item back**, and the whole screen is shown at 70% opacity with a "REMOVED" banner.

---

### 2.5 Add / edit item

**Purpose.** One form, two modes, matching the website's shared add/edit view. Long, so it is designed to be *interruptible* — the owner will be pulled away halfway through.

**Layout (Add mode).**

```
┌──────────────────────────────────────────┐
│ [Cancel]      Add item                   │  ← iOS: nav bar
│                                          │     Android: ✕ + title
├──────────────────────────────────────────┤
│                                          │
│ What is it?                              │  ← section eyebrow
│                                          │
│ Item name                        Needed  │
│ ┌──────────────────────────────────────┐ │
│ │                                      │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ A short description             Optional │
│ ┌──────────────────────────────────────┐ │
│ │                                      │ │
│ │                                      │ │
│ └──────────────────────────────────────┘ │
│ Customers see this on the website.       │  ← hint 15pt muted
│                                          │
│ Numbers                                  │
│                                          │
│ Price                            Needed  │
│ ┌──────────────────────────────────────┐ │
│ │ $  6.50                              │ │  ← decimal pad
│ └──────────────────────────────────────┘ │
│ Type it the way you'd say it: 6.50       │
│                                          │
│ How many on the shelf            Needed  │
│ ┌────────────────┐                       │
│ │ [ − ]  0  [ + ]│                       │
│ └────────────────┘                       │
│                                          │
│ Warn me when it drops to                 │
│ ┌────────────────┐                       │
│ │ [ − ]  3  [ + ]│                       │
│ └────────────────┘                       │
│ We'll also take it off the website at    │
│ this level, so nobody buys what you       │
│ haven't got.                             │
│                                          │
│ Category                                 │
│ ┌──────────────────────────────────────┐ │
│ │ Magazine                           ▸ │ │  ← opens picker
│ └──────────────────────────────────────┘ │
│                                          │
│ Photo                                    │
│ ┌──────────────────────────────────────┐ │
│ │  ⊕  Add a photo                      │ │
│ │     Or leave it — we'll find one      │ │
│ │     for you when you save.            │ │
│ └──────────────────────────────────────┘ │
│                                          │
├──────────────────────────────────────────┤
│ [ Add item                           ]   │  ← sticky primary
└──────────────────────────────────────────┘
```

**Edit mode differences.** Title "Edit item". Primary button "Save changes". An extra section appears above the footer:

```
│ On the website                           │
│ ┌──────────────────────────────────────┐ │
│ │ Show this to customers        [ ●━ ] │ │  ← switch, on
│ └──────────────────────────────────────┘ │
│ Turn this off to keep an item in your    │
│ list but hide it from the website.       │
│                                          │
│ [ Remove this item ]                     │  ← red outline, not fill
```

Note the inversion of the website's checkbox: `held` is stored as-is, but presented as the positive statement "Show this to customers". Non-technical users read positives faster than negatives, and "held" is jargon.

**Elements and rules.**

| Element | Spec |
|---|---|
| Field labels | 15 pt / 600 Plus Jakarta Sans, above the field. Never placeholder-only labels. |
| Needed / Optional | 13 pt muted text at the trailing edge of the label row. The word "Needed", not an asterisk — asterisks require a legend, words don't. |
| Text fields | 52 pt tall, 12 pt radius, 1.5 pt `#8A8A8A` border, 17 pt Atkinson body. Focus: 2 pt black border (light) / white (dark) plus a 3 pt `#2B6CFF` focus ring on keyboard/switch-control focus. |
| Price | Currency prefix is a fixed, non-editable `$` inside the field. `decimalPad` keyboard. Accepts `6.5`, `6.50`, `$6.50`, `650c`; normalises on blur to `6.50`. Stored as `price_cents`. |
| Stock / threshold | Steppers, not text fields — 90% of the time the value is small and a stepper is faster and error-proof. Tapping the number opens the number pad for large values. |
| Category | A row that pushes to the picker, showing the current value. Not a wheel, not a spinner. |
| Photo | See 2.5.1. |
| Sticky footer | The primary action is bottom-anchored on **both** platforms. See Section 4.2. |

**Validation.**

- **Inline, on blur, never on keystroke.** Typing "6." must not flash an error.
- On submit with problems: the footer button does not proceed; the screen scrolls to the first problem field; that field gets a 2 pt red border, a ⊗ glyph and a message below it; and a summary is announced.
- Messages are specific and human:
  - "Give this item a name so you can find it later."
  - "Put in a price. If it's free, put 0."
  - "That price doesn't look right. Try something like 6.50."
  - "How many are on the shelf? Put 0 if you've run out."
  - "Pick a category so it lands in the right place on the website."

**States.**

- **Idle / dirty** — once any field changes, the footer button becomes enabled and a Cancel now triggers the discard confirmation.
- **Saving** — footer label → "Saving…", spinner replaces any arrow badge, fields locked but legible.
- **Saving, finding a photo** — footer label → "Finding a photo…" (mirrors the website's honest reporting of the one step that touches the internet). Below it, a cancel-ish escape: "[Skip the photo and save now]".
- **Success** — sheet dismisses; the Stock list scrolls to the new/edited row and flashes a 600 ms black outline (suppressed under Reduce Motion, which instead just scrolls to it); snackbar: "National Geographic added. [Undo]".
- **Error — save failed while offline** — *does not block*. The item is saved locally and the snackbar reads "Saved on this phone. It'll go up to the website when you're back online."
- **Error — save rejected by the server** — remains on the form, red banner at the top: "We couldn't save that. {plain reason} Nothing you typed is lost." with **Try again**.
- **Error — photo lookup failed** — never blocks. The item saves; a quiet note appears on the row: "Saved without a photo — we'll use the category artwork."
- **Interrupted** — a draft is written to disk on every field blur and on backgrounding. Returning to Add item within 24 hours shows: "You started adding 'Scented Candle' yesterday. [Pick up where you left off] [Start fresh]".
- **Discard confirmation** — on Cancel with unsaved changes: a platform-appropriate confirmation (Section 4.5) titled "Throw away your changes?" with **Keep editing** / **Throw away** (destructive).

#### 2.5.1 Photo options sheet

Tapping the photo block opens a sheet with four choices, in the order the website ranks them:

```
┌──────────────────────────────────────────┐
│              ▁▁▁▁▁▁                      │
│   Add a photo                            │
│                                          │
│  📷  Take a photo                     ▸  │
│  🖼  Choose from your photos          ▸  │
│  🔗  Paste a web address              ▸  │
│  ✨  Find one for me                  ▸  │
│                                          │
│  A supplier's own product shot always    │
│  looks best. If you haven't got one,     │
│  "Find one for me" searches photos that  │
│  are free to use in a shop, and adds the │
│  credit line for you.                    │
│                                          │
│  [ Cancel ]                              │
└──────────────────────────────────────────┘
```

"Find one for me" is disabled with the sub-label "Needs the internet" when offline. Everything else works offline.

#### 2.5.2 Category picker

```
┌──────────────────────────────────────────┐
│ ‹ Back        Category                   │
├──────────────────────────────────────────┤
│  Magazine                             ✓  │
│  Paper                                   │
│  Toys                                    │
│  Cards                                   │
│  Stationery                              │
│  Gifts                                   │
│  Lottery                                 │
│ ──────────────────────────────────────── │
│  YOUR OWN                                │
│  Drinks                                  │
│  Phone Credit                            │
│ ──────────────────────────────────────── │
│  ⊕ Add a new category                    │
└──────────────────────────────────────────┘
```

56 pt rows. Selection is a `✓` glyph **and** a bold label — not a colour change. "Add a new category" opens a single-field sheet with the hint "For example: Drinks, Phone Credit, Party Supplies." Selecting a row applies and pops immediately — no separate Done button.

---

### 2.6 Orders

#### 2.6.1 Orders list

```
┌──────────────────────────────────────────┐
│ Orders                                   │
│ 14 online orders                         │
├──────────────────────────────────────────┤
│  TODAY                                   │  ← sticky section header
│ ┌──────────────────────────────────────┐ │
│ │ 9:14 am                    $17.40  ▸ │ │
│ │ 3 items · Card                       │ │
│ └──────────────────────────────────────┘ │
│  YESTERDAY                               │
│ ┌──────────────────────────────────────┐ │
│ │ 4:02 pm                     $6.20  ▸ │ │
│ │ 1 item · PayPal                      │ │
│ └──────────────────────────────────────┘ │
│  EARLIER                                 │
│ ┌──────────────────────────────────────┐ │
│ │ Tue 22 Jul, 11:31 am       $32.85  ▸ │ │
│ │ 5 items · Card                       │ │
│ └──────────────────────────────────────┘ │
├──────────────────────────────────────────┤
│    ▤            ☰            ▦           │
│  Today        Stock        Orders        │
└──────────────────────────────────────────┘
```

Grouped by Today / Yesterday / Earlier. Totals right-aligned in tabular figures. Newest first. Empty state: "No online orders yet. / When someone buys from the website, it'll land here." Offline: shows the cached list with the offline strip; no functional loss, because orders are read-only.

#### 2.6.2 Order detail

```
┌──────────────────────────────────────────┐
│ ‹ Orders                        [ ⇪ ]    │  ← share
├──────────────────────────────────────────┤
│                                          │
│ ONLINE ORDER                             │
│ Thursday 24 July, 9:14 am                │  ← H1 28pt
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ National Geographic                  │ │
│ │ 1 × $14.50                   $14.50  │ │
│ │ ───────────────────────────────────  │ │
│ │ Matchbox Diecast Car                 │ │
│ │ 2 × $5.00                    $10.00  │ │
│ │ ───────────────────────────────────  │ │
│ │ Total                        $24.50  │ │  ← 22pt/800
│ └──────────────────────────────────────┘ │
│                                          │
│ Paid with                          Card  │
│ ──────────────────────────────────────── │
│ Reference                     KN-100482  │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ⚠  This order took 2 items below     │ │
│ │    their alert level, so we put them │ │
│ │    on hold for you.                  │ │
│ │                    [ See those two ] │ │
│ └──────────────────────────────────────┘ │
│                                          │
├──────────────────────────────────────────┤
│ [ Share this order                   ]   │
└──────────────────────────────────────────┘
```

Line-item rows show name, `qty × unit price`, and line total. The auto-hold notice reproduces the behaviour already in `fulfilOrder()` and, critically, *explains* it — the website silently holds items and the owner has to work out why. Reference number is long-pressable to copy.

Share exports a plain-text receipt through the platform share sheet (Section 4.3), for forwarding to a bookkeeper.

---

### 2.7 Settings

```
┌──────────────────────────────────────────┐
│ ‹ Today       Settings                   │
├──────────────────────────────────────────┤
│  YOU                                     │
│  Sign-in details                      ▸  │
│  Use Face ID to sign in        [ ●━ ]    │
│                                          │
│  YOUR SHOP                               │
│  Shop details                         ▸  │
│  Categories                           ▸  │
│                                          │
│  ALERTS                                  │
│  Tell me when stock is low     [ ●━ ]    │
│  Tell me about new orders      [ ●━ ]    │
│  Quiet hours          9:00 pm – 7:00 am ▸│
│                                          │
│  HOW IT LOOKS                            │
│  Appearance              Match phone  ▸  │
│  Bigger buttons                [ ━○ ]    │
│  Buttons on the left           [ ━○ ]    │
│                                          │
│  TIDYING UP                              │
│  Removed items                    (3) ▸  │
│                                          │
│  HELP                                    │
│  How this app works                   ▸  │
│  Contact support                      ▸  │
│                                          │
│  [ Sign out ]                            │
│                                          │
│  Knightsbridge Newsagency · v1.0 (14)    │
│  Last synced 9:22 am                     │
│                                          │
│  [ Start again with sample stock ]       │  ← red outline
└──────────────────────────────────────────┘
```

| Setting | Notes |
|---|---|
| Sign-in details | Pushes to a form with Email, Current password, New password, Confirm. Requires the current password — the website did not, and it should. Success: "Your sign-in details are saved. You'll use the new ones next time." |
| Shop details | Name, address, phone. Read-only display of what appears on the website. |
| Categories | Rename, reorder, delete unused custom tags. Deleting a tag in use is blocked with: "4 items use 'Drinks'. Move them to another category first." |
| Quiet hours | Uses the platform date/time picker (Section 4.6). |
| Appearance | Match phone / Always light / Always dark. |
| **Bigger buttons** | Raises every touch target from 48 to 56 pt and bumps the base type one step. An accessibility affordance offered *in plain language*, not buried. |
| **Buttons on the left** | Mirrors row-trailing controls (steppers, disclosures) to the leading edge for left-handed thumbs. Also flips swipe-action direction. |
| Removed items | The `active: false` archive. Each row can be restored or permanently deleted. This is what makes "Remove" safe. |
| Sign out | Confirmation: "Sign out? You'll need your email and password to get back in." |
| Start again with sample stock | The website's reset. Guarded by a two-step confirmation requiring the owner to type the word `ERASE`, because it is unrecoverable. Copy: "This wipes every item, every order and your settings, and puts the sample stock back. There is no undo." |

---

### 2.8 State reference (applies to every screen)

| State | Rule |
|---|---|
| **Loading** | Skeletons that match the final shape. Spinners only inside buttons. Never a full-screen spinner over content that already exists. |
| **Empty** | Always a sentence explaining what would be here, plus the one action that fills it. Never just "No data". |
| **Error** | Says what happened, whether anything was lost, and what to do. One primary recovery button. |
| **Offline** | An informational black strip, never red. All local functions remain enabled; only genuinely online functions are disabled, each with a "Needs the internet" sub-label. |
| **Success** | A 6-second snackbar above the tab bar with an Undo where reversible. Never a modal "OK" dialog for something that worked. |
| **Partial / stale** | Show the data with a timestamp: "Last updated 8:02 am". Stale data beats no data at the counter. |

---

## 3. The counter test

*Scenario: three people in the queue, the phone is in the owner's left hand, a customer is holding out a magazine.*

### 3.1 Task A — check a price

**Target: 1 tap and 2 typed characters, all within the bottom 200 pt.**

```
Resume app  ──►  already on Stock (sticky tab, §1.5)
   │
   ├─ tap 1 ──► bottom search field, keyboard opens
   │
   ├─ type "na"  ──► list filters live, local, zero latency
   │
   └─ READ:  National Geographic  ·  $14.50
             (20pt/800 tabular, ~1/3 up the screen)
```

- **Taps: 1.** Reads: 0. Screens changed: 0.
- Cold start with Today active: **2 taps** (Stock tab, then search).
- From locked phone: **0 in-app taps** — see 3.4.
- The price is rendered at 20 pt ExtraBold, so it is readable at arm's length without lifting the phone.

Rejected alternative: a dedicated "Price check" screen. It would be one tap *more*, not fewer, and it would duplicate the search that already exists.

### 3.2 Task B — adjust a stock count

**Target: 1 tap per unit sold, from the same list, without navigating anywhere.**

```
(already searched, or scrolled to the item)
   │
   └─ tap the [ − ] on the row  ──►  count 40 → 39
                                     haptic tick
                                     snackbar "Sold one. [Undo]"
```

- **Taps: 1** per unit. Four of the same item = 4 taps, coalesced into one Undo.
- Bulk correction (stocktake, delivery arrives): **long-press the count → number pad → type → Save = 1 press + digits + 1 tap.**
- The stepper is on the row itself, so this task requires **no navigation at all**. This is the single biggest win over the website, where adjusting stock meant Edit → scroll → change → Save → back: five interactions and a full page change.
- The `−` and `+` sit at the row's trailing edge, 48 × 48, at least 8 pt apart so a fat-thumb miss cannot hit the wrong one. The "Buttons on the left" setting mirrors them.

### 3.3 Task C — mark an item on hold

**Target: one gesture, no confirmation, reversible.**

```
Primary (iOS-native, offered on both):
   swipe the row right  ──►  full-height red "Hold" action
                        ──►  release  ──►  done
                             snackbar "Taken off the website. [Undo]"
   Gestures: 1.  Taps: 0.

Equal-peer path (primary on Android):
   long-press the row  ──►  context menu  ──►  "Take off the website"
   Taps: 2 (one long, one short).

From the Needs attention card on Today:
   tap [ Release ]  ──►  done.   Taps: 1.
```

- No confirmation dialogue. Holding is trivially reversible and the snackbar carries Undo — a confirmation here would cost a tap on every single use to protect against a mistake that costs zero.
- The action label is written in the owner's words — **"Take off the website"** / **"Put back on the website"** — not "hold" / "unhold". The stored field stays `held`; the vocabulary does not leak into the interface.

### 3.4 Below one tap: entry points outside the app

| Entry point | Result |
|---|---|
| **Home-screen quick action** (long-press the app icon; iOS `UIApplicationShortcutItem` / Android `ShortcutInfo`) | "Check a price" → opens Stock with search focused and the keyboard up. "Add an item" → opens the Add form. |
| **Home-screen widget** (small, 2×2) | Shows the low-stock count and the top low item. Tapping it deep-links to Today's attention card. |
| **Lock-screen / Quick Settings** | iOS Control Center control and Android Quick Settings tile, both "Check a price". |
| **Siri / Google Assistant shortcut** | "Knightsbridge price check" → same destination. Genuinely hands-free while holding a customer's goods. |

### 3.5 One-handed reach map

```
┌──────────────────────────────────────────┐  ↑
│  Nav bar / large title / gear            │  │ HARD REACH
│  ─────────────────────────────────────── │  │ Read-only, or
│                                          │  │ actions with a
│  Scrolling content — read, tap to open   │  │ duplicate below
│                                          │  ↓
│  ······································  │  ← 424pt from bottom
│                                          │  ↑
│  Item rows: name, price, [−] n [+]       │  │ EASY REACH
│                                          │  │ Everything that
├──────────────────────────────────────────┤  │ is done under
│  🔍  Search stock                    ⇅   │  │ pressure lives
├──────────────────────────────────────────┤  │ in here.
│    Today       Stock       Orders        │  ↓
└──────────────────────────────────────────┘
```

Rules that fall out of this:
1. Every screen's **primary action is a full-width sticky footer button**, never a nav-bar item.
2. The **search field is bottom-anchored** on Stock.
3. **Snackbars appear above the tab bar**, so the Undo button is in the easy zone.
4. **Sheets are bottom sheets**, and their action buttons sit at the bottom of the sheet, not the top.
5. The nav bar carries only Cancel, Back, and the settings gear — reversible or infrequent things.

---

## 4. Platform conventions

### 4.1 Where a single shared design is correct

Colour, type scale, spacing, copy, information architecture, the row anatomy, the stepper, the bottom search bar, the counter interactions, the empty/error/offline state machine, and every accessibility label. These are the product. Divergence here would double the maintenance cost and buy nothing, because there is exactly one user and they use exactly one phone.

### 4.2 Where they must differ

| Area | iOS | Android | Why |
|---|---|---|---|
| **Tab bar** | `UITabBar`, glyph above label, translucent material, safe-area inset | Material 3 `NavigationBar`, 80 dp, active indicator pill behind the icon, `onSecondaryContainer`-equivalent tint (here: black pill, white glyph) | Each platform's users read the *shape* of the bar as "these are the sections". |
| **Back** | `‹ Stock` in the nav bar with the parent's title; interactive edge-swipe back from the left edge must work on every pushed screen | `←` arrow, no title; **system back gesture and back button** must do the same thing as the arrow; Android 14+ predictive-back animation supported | Android's system back is not optional and must never be a dead end or an app exit from a pushed screen. |
| **Modal dismissal** | Sheets have a grabber and swipe-down-to-dismiss. If the form is dirty, swipe-down triggers the discard confirmation rather than dismissing silently. | Full-screen dialog with `✕` at the top-left. System back triggers the same discard confirmation. | |
| **Primary action placement** | *Deliberate deviation.* iOS convention puts "Save" in the nav bar's trailing corner. This app puts it in a sticky footer instead. | Matches Material's "full-screen dialog" pattern less exactly too, but Material has no strong opposing rule. | The nav-bar corner is the hardest pixel on the phone to reach one-handed. Correctness for this user beats platform habit; the deviation is consistent across every screen, so it is learned once. iOS's own recent apps (Wallet, Fitness) increasingly do the same. |
| **Cancel placement** | Nav bar, leading corner | `✕`, leading corner | Cancel is *supposed* to be slightly hard to hit. |
| **Text case** | Title Case on buttons ("Add Item" → here softened to sentence case for readability; see note) | Sentence case | Note: this app uses **sentence case on both**, because its button labels are short sentences ("Take off the website"), and Title Case On A Sentence Reads Badly. This is a conscious, documented exception. |
| **Switches** | `UISwitch`, trailing edge of the row, whole row is not tappable | Material `Switch` with a check glyph in the on-state thumb, trailing edge, whole row is tappable | Material's on-state glyph is exactly the "never colour alone" behaviour we want; iOS gets a `ON`/`OFF` text label alongside instead. |
| **Swipe actions on rows** | Native `UISwipeActionsConfiguration`, expected behaviour | Available, but the **long-press context menu is the taught path** and is surfaced with a one-time coach mark | Android users are not reliably trained on swipe-to-action; iOS users are. Both paths exist on both platforms; only the emphasis differs. |
| **Haptics** | `UIImpactFeedbackGenerator(.light)` on each stepper tap, `.warning` notification on a validation failure | `HapticFeedbackConstants.CLOCK_TICK` on steppers, `REJECT` on failure | |
| **Type** | Dynamic Type via text styles; both custom fonts registered as scaled fonts | `sp` units throughout; respects `fontScale` and Display Size independently | |
| **Snackbar/toast** | No native equivalent — a custom bottom banner, 6 s, swipe-to-dismiss, above the tab bar | Material `Snackbar` with an action, `LENGTH_LONG`, anchored to the `NavigationBar` | |
| **Status of "saved"** | Nothing system-level | Optionally a persistent low-priority notification while changes are queued offline | Android users expect the notification shade to report background work. |

### 4.3 Share

Order detail's share uses the **system share sheet on both**: `UIActivityViewController` (iOS) and `Intent.ACTION_SEND` with a chooser (Android). Payload is `text/plain` — a formatted receipt. No custom share UI, ever: the owner already knows their own share sheet, and the destinations (Mail, Messages, WhatsApp) are theirs, not ours.

### 4.4 Destructive-action confirmation

| Action | Confirmation | Pattern |
|---|---|---|
| Adjust stock count | **None** | Undo snackbar |
| Hold / release | **None** | Undo snackbar |
| Discard unsaved form | **Yes** | iOS: action sheet from the bottom, "Throw Away Changes" in red destructive style. Android: `AlertDialog`, "Throw away" as the confirming text button. |
| Remove an item | **Yes** | Same patterns. Copy: "Remove National Geographic? It comes off the website and out of your list. You can put it back from Settings → Removed items." Buttons: **Keep it** / **Remove**. |
| Permanently delete a removed item | **Yes** | Copy explicitly says "This one can't be undone." |
| Sign out | **Yes** | Low-stakes; simple dialog. |
| Reset all data | **Yes, twice** | Dialog → typed `ERASE` confirmation screen. |

Two rules on both platforms:
1. **The destructive button is never the default / auto-focused one.** Hardware Enter or a mistaken double-tap must not destroy anything.
2. **Red is never the only signal.** Every destructive button also carries the destructive verb in its label and a `⊗` glyph, so it works in greyscale and for a red-blind user.

### 4.5 Date and time pickers

Only used for Quiet hours and for filtering orders by date. iOS uses the compact `UIDatePicker` that expands inline into a wheel; Android uses the Material `TimePicker`/`DatePicker` **with the keyboard-entry toggle enabled**, because typing a time is faster than dragging a clock face and Material's dial alone is a known usability trap for older users.

### 4.6 Notifications

iOS: `UNUserNotificationCenter`, permission requested *at the moment the owner switches "Tell me when stock is low" on* — never at first launch. Android 13+: `POST_NOTIFICATIONS` requested at the same moment. Copy at the point of the ask: "We'll send you a note when something drops to its alert level. Nothing else."

---

## 5. Design system

### 5.1 Colour

The palette is three colours. Everything else is a tint, shade or opacity of them — exactly as `style.css` already does with `--hot-btn`, `--hot-ink` and `--hot-dark`.

**Base**

| Name | Value |
|---|---|
| Signal red | `#E1251B` |
| Black | `#111111` |
| White | `#FFFFFF` |

**Derived ramp** (each entry exists for one contrast reason)

| Token | Light | Dark | Contrast on its background | Use |
|---|---|---|---|---|
| `surface` | `#FFFFFF` | `#111111` | — | Page background |
| `surface-raised` | `#F6F6F6` | `#1C1C1C` | — | Cards, grouped rows |
| `text-primary` | `#111111` | `#FFFFFF` | 18.9:1 | Names, values, headings |
| `text-secondary` | `#5C5C5C` | `#A8A8A8` | 6.7:1 / 7.9:1 | Hints, categories, timestamps |
| `text-red` | `#B3140C` | `#FF6E63` | 7.0:1 / 6.9:1 | Eyebrows, error text, destructive labels |
| `fill-red` | `#C81A12` | `#C81A12` | white on it = 5.8:1 | Primary buttons, active chips |
| `accent-red` | `#E1251B` | `#E1251B` | non-text | Rules, the 4 pt status bar on rows, the logo mark |
| `line-hairline` | `#E6E6E6` | `rgba(255,255,255,0.14)` | decorative | Card and row separators |
| `line-control` | `#8A8A8A` | `rgba(255,255,255,0.55)` | 3.45:1 / 6.2:1 | Borders that *define* a control (WCAG 1.4.11) |
| `wash-red` | `#FDECEB` | `#2A1110` | — | Error / attention card backgrounds |
| `focus` | `#2B6CFF` | `#2B6CFF` | 3:1+ on both | Keyboard / switch-control focus ring only |

**The critical rule, stated once:** `#E1251B` on `#111111` is **4.0:1 and fails AA**. Red text on a dark background is always `#FF6E63` (6.9:1). `#E1251B` on dark is permitted only as a non-text graphic element — a rule, a bar, a fill behind white text.

`#2B6CFF` is the only colour outside the palette. It is a system focus indicator, not brand, and it exists because a red focus ring on a red button is invisible. It appears only when navigating by keyboard or switch control.

**Dark mode is a real design, not an inversion.** Elevation is expressed by lightening the surface (`#111111` → `#1C1C1C` → `#262626`), never by shadow. Card borders switch from a dark hairline to a light one. Red button fills stay identical, because white-on-`#C81A12` clears AA on any background. Photos are dimmed 8% in dark mode so a white product shot doesn't glare at 6 a.m.

### 5.2 Type

**Families.** Plus Jakarta Sans (400/500/600/700/800) for headings, UI labels, buttons, numbers. Atkinson Hyperlegible (400/700 + italic) for body copy, descriptions and hints. Both bundled in the app — no network fetch, no fallback flash.

The split is not decorative: Atkinson Hyperlegible was drawn to disambiguate similar glyphs for low-vision readers, which is precisely what a 55-year-old reading a product description at 6 a.m. needs. Plus Jakarta's tight, geometric caps carry the brand at heading sizes where legibility is not at risk.

**Scale** (values at default Dynamic Type / `fontScale 1.0`)

| Token | Size / Line | Family, weight, tracking | Used for |
|---|---|---|---|
| `display` | 34 / 38 | Jakarta 800, −0.03em | Large nav titles |
| `title-1` | 28 / 33 | Jakarta 800, −0.03em | Screen H1, item name on detail |
| `title-2` | 22 / 28 | Jakarta 700, −0.025em | Card headings, order totals |
| `title-3` | 18 / 24 | Jakarta 700, −0.015em | Grouped section headings |
| `eyebrow` | 12 / 16 | Jakarta 700, +0.18em, uppercase | Section labels above headings |
| `label` | 15 / 20 | Jakarta 600 | Field labels, tab bar, settings rows |
| `button` | 17 / 22 | Jakarta 600 | All button labels |
| `body` | 17 / 26 | Atkinson 400 | Descriptions, explanatory copy |
| `body-strong` | 17 / 26 | Atkinson 700 | Item names in lists |
| `secondary` | 15 / 22 | Atkinson 400 | Hints, categories, sub-lines |
| `caption` | 13 / 18 | Atkinson 400 | Timestamps, photo credits, version |
| `pill` | 11 / 14 | Jakarta 700, +0.12em, uppercase | LOW / ON HOLD / SOLD OUT |
| `number-l` | 28 / 32 | Jakarta 800, tabular | Stat tiles, order totals |
| `number-m` | 20 / 24 | Jakarta 800, tabular | Prices and counts in list rows |

Line-height ratios sit between 1.15 (headings) and 1.53 (body). The website runs body at 1.75 — generous for a wide desktop measure, too airy for a 390 pt phone column, so it is tightened to 1.53, which still clears WCAG 1.4.12's 1.5 requirement.

**Tabular figures are mandatory** on every price and count. Proportional digits make a column of prices ragged and slow to scan.

### 5.3 Spacing

A 4 pt base scale. Only these values are legal.

| Token | pt | Typical use |
|---|---|---|
| `s-1` | 4 | Glyph-to-label |
| `s-2` | 8 | Inside a pill, between stacked labels |
| `s-3` | 12 | Between a label and its field |
| `s-4` | 16 | **Default.** Screen gutter, card padding, row padding |
| `s-5` | 20 | Between cards |
| `s-6` | 24 | Between form fields |
| `s-7` | 32 | Between form sections |
| `s-8` | 40 | Above a section eyebrow |
| `s-9` | 56 | Top of a screen's first content block |
| `s-10` | 72 | Empty-state vertical padding |

Screen gutter is 16 pt. Cards are inset 16 pt from the screen edge and padded 16 pt inside. Minimum gap between two adjacent touch targets: 8 pt.

**Radii.** Card 20 (matches the site's `--r-card`). Control/field 12. Sheet top corners 28. Pill / stepper / chip 999.

**Elevation.** None. The site uses hairline borders instead of drop shadows and the app keeps that: flat surfaces, 1 pt `line-hairline` borders. The only exceptions are the sticky footer (a 1 pt top hairline plus a background blur) and bottom sheets (a system scrim).

### 5.4 Component inventory

| # | Component | Variants | Min height |
|---|---|---|---|
| 1 | **Pill button** | Primary (red fill/white), Secondary (outline black), Destructive (outline red), Text-only | 56 (footer), 48 (inline) |
| 2 | **Arrow-badge CTA** | The site's signature: pill + circular arrow. Reserved for the one leading action on a screen — Sign in, Add your first item. | 56 |
| 3 | **Icon button** | Nav bar, row trailing, sheet | 48 × 48 |
| 4 | **Stepper** | − / value / +, with disabled ends | 48 |
| 5 | **Stock row** | Default, Low, On hold, Sold out, Unsynced | 88 |
| 6 | **Order row** | Default | 72 |
| 7 | **Settings row** | Disclosure, Switch, Value, Destructive | 56 |
| 8 | **Detail row** | Label + value, Label + stepper | 56 |
| 9 | **Card** | Flat, Attention (red border + wash), Good (black border) | — |
| 10 | **Stat tile** | Number + label | 96 |
| 11 | **Status pill** | LOW, ON HOLD, SOLD OUT, REMOVED | 22 |
| 12 | **Filter chip** | Default, Active (red fill + ✓) | 48 |
| 13 | **Eyebrow** | Red, muted | — |
| 14 | **Text field** | Default, Focused, Error, Disabled, With prefix | 52 |
| 15 | **Text area** | Default, Focused, Error | 96 |
| 16 | **Search field** | Bottom-anchored, with clear + sort | 56 |
| 17 | **Number pad sheet** | — | — |
| 18 | **Bottom sheet** | Half, Full, with grabber | — |
| 19 | **Snackbar** | With action, without | 56 |
| 20 | **Banner strip** | Offline (black), Error (red) | 44 |
| 21 | **Inline message** | Error, Info, Success | — |
| 22 | **Section header** | Eyebrow, Sticky list header | 40 |
| 23 | **Empty state** | Glyph + sentence + action | — |
| 24 | **Skeleton** | Row, Card, Photo | matches target |
| 25 | **Tab bar item** | Default, Selected, With badge | 56 |
| 26 | **Coach mark** | One-time tip bubble with dismiss | — |
| 27 | **Photo block** | Photo, Generated artwork, Add prompt | 16:9 |

### 5.5 Iconography

**Approach: use each platform's own icon set, mapped one-for-one.** SF Symbols on iOS, Material Symbols Rounded on Android. Shipping a single custom set would look consistent in a design file and slightly foreign on both devices; for a non-technical user, a familiar glyph beats a bespoke one every time.

Rules: 24 pt optical size, Medium/400 weight, `text-primary` colour by default, never `accent-red` except on a destructive action, and **never the sole label for an action**. Every icon-only control has a visible text label somewhere in reach, or is one of six universally understood glyphs (back, close, add, search, settings, share).

| Meaning | iOS (SF Symbol) | Android (Material Symbol) |
|---|---|---|
| Today tab | `storefront` | `storefront` |
| Stock tab | `list.bullet.rectangle` | `inventory_2` |
| Orders tab | `bag` | `receipt_long` |
| Settings | `gearshape` | `settings` |
| Add | `plus` | `add` |
| Search | `magnifyingglass` | `search` |
| Sort | `arrow.up.arrow.down` | `swap_vert` |
| Clear | `xmark.circle.fill` | `cancel` |
| Back | `chevron.left` | `arrow_back` |
| Close | `xmark` | `close` |
| Disclosure | `chevron.right` | `chevron_right` |
| Share | `square.and.arrow.up` | `share` |
| Attention | `exclamationmark.triangle` | `warning` |
| All good | `checkmark` | `check` |
| Error | `xmark.octagon` | `error` |
| Offline | `wifi.slash` | `wifi_off` |
| Not synced | `arrow.triangle.2.circlepath` | `sync_problem` |
| Photo | `photo` | `image` |
| Camera | `camera` | `photo_camera` |
| Hide from site | `eye.slash` | `visibility_off` |
| Show on site | `eye` | `visibility` |
| Remove | `trash` | `delete` |
| Restore | `arrow.uturn.backward` | `restore_from_trash` |
| Decrease | `minus` | `remove` |
| Increase | `plus` | `add` |

### 5.6 Motion

Durations: 150 ms (state change), 250 ms (push/pop, sheet), 350 ms (large-title collapse). Curve: standard ease-out on entry, ease-in on exit. Under **Reduce Motion / Remove animations**, every transition becomes a cross-fade at 100 ms, the row-highlight flash becomes a static 2-second outline, and the tab bar's indicator jumps rather than slides. No parallax, no bounce, no shared-element transitions anywhere in the app.

---

## 6. Accessibility

Target: **WCAG 2.1 AA**, matching and slightly exceeding the website's 2.0 AA baseline.

### 6.1 Touch targets

Minimum **48 × 48 pt** for every interactive element — above the 44 pt requirement, matching the website's existing 48 px targets and Material's 48 dp guidance. Minimum 8 pt clear space between adjacent targets. Number-pad keys are 64 × 64. The "Bigger buttons" setting raises the floor to 56 pt everywhere.

Where a visual element is smaller than 48 (a status pill, a photo credit link), the *hit area* is still expanded to 48 with a transparent inset.

### 6.2 Text sizing

- **iOS:** every text style is registered with `UIFontMetrics` and scales through the full Dynamic Type range, including the five accessibility sizes (up to ~310%).
- **Android:** all text in `sp`; layouts tested at `fontScale` 1.0, 1.3, 1.5 and 2.0, and at the largest Display Size.
- **Reflow.** Above ~200% scaling, every horizontal pairing breaks to a vertical stack: the stock row becomes name → status → price → stepper on its own line; detail rows become label above value; the chip rail becomes a wrapped two-line grid. No text is ever truncated to fit at large sizes — containers grow.
- **Never** a fixed-height container around scalable text. Never `maxLines` on a value the owner needs to read.
- The horizontal chip rail is the one scrolling-in-two-directions risk; above 200% it converts to a wrapped grid so the page scrolls in one axis only.

### 6.3 Screen reader — VoiceOver and TalkBack

Every control has a label, a role, a value where applicable, and a hint only where the outcome isn't obvious.

**The stock row** is grouped into one accessibility element with custom actions, so the owner swipes past four items in four swipes, not sixteen:

```
Label:   "National Geographic, Magazine"
Value:   "$14.50, 3 on the shelf, low stock, on hold, hidden from customers"
Actions: "Add one" · "Remove one" · "Put back on the website" ·
         "Edit" · "Set the count" · "Remove item"
Trait:   button   (activating opens the item)
```

Custom actions are `UIAccessibilityCustomAction` on iOS and `AccessibilityNodeInfo.addAction` on Android — reachable from the VoiceOver rotor and the TalkBack Actions menu, and *equivalent in power to the swipe gestures*. This is what makes the counter interactions in Section 3 accessible rather than sighted-only.

**Label catalogue (extract).**

| Control | Label | Value / Hint |
|---|---|---|
| `−` stepper | "Remove one" | Hint: "Lowers the number on the shelf by one." |
| `+` stepper | "Add one" | Hint: "Raises the number on the shelf by one." |
| Count text | "On the shelf" | Value: "3". Adjustable trait; volume-key / swipe-up-down increments on both platforms. |
| Search field | "Search stock" | Hint: "Type part of an item's name." |
| Clear search | "Clear the search" | — |
| Sort button | "Change the order" | Value: "Needs attention first" |
| Filter chip | "Magazine" | Value: "Selected" / "Not selected". Trait: button + selected. |
| Status pill | *(not focusable — folded into the row's value)* | — |
| Photo | The item name + "photo" | Or "No photo — showing category artwork" |
| Photo credit | "Photo credit: Flickr, Creative Commons BY 2.0. Opens the licence." | Link trait |
| Settings gear | "Settings" | — |
| Reveal password | "Show password" / "Hide password" | State announced on toggle |
| Sticky primary | Its visible text | — |
| Offline strip | "No internet. You can still make changes and we'll save them up." | `liveRegion: polite`, announced once on change |
| Snackbar | Its text + the action | `liveRegion: polite` |
| Error banner | Its text | `liveRegion: assertive`, focus moved to it |
| Tab bar item | "Today" / "Stock" / "Orders" | Value: "tab 2 of 3, selected" |
| Attention card | "Needs attention. 3 items are low or on hold." | Heading trait on the count line |

**Announcements.** Stock changes announce the *result*, not the event: "Daily Telegraph, 39 on the shelf". Held items announce "Taken off the website". Saving announces "Saved". Search announces the result count after a 500 ms debounce.

**Headings and order.** Every screen exposes a heading hierarchy (`accessibilityTraits: .header` / `AccessibilityHeading`) so rotor/heading navigation works. Focus order follows visual order, top to bottom, and is explicitly set where a sticky footer would otherwise be read out of place — the footer button is last.

**Focus management.** Pushing a screen moves focus to its title. Dismissing a sheet returns focus to the control that opened it. An error moves focus to the error. Nothing steals focus while the owner is typing.

### 6.4 Contrast

All values computed against the surface they sit on.

| Pair | Ratio | Requirement | Result |
|---|---|---|---|
| `#111111` on white | 18.9:1 | 4.5 | pass |
| white on `#111111` | 18.9:1 | 4.5 | pass |
| `#5C5C5C` on white | 6.7:1 | 4.5 | pass |
| `#A8A8A8` on `#111111` | 7.9:1 | 4.5 | pass |
| `#B3140C` on white | 7.0:1 | 4.5 | pass |
| **`#FF6E63` on `#111111`** | **6.9:1** | 4.5 | **pass — the mandated dark-mode red** |
| **`#E1251B` on `#111111`** | **4.0:1** | 4.5 | **FAIL — never used for text on dark** |
| `#E1251B` on white | 4.7:1 | 4.5 | passes, but `#B3140C` is used instead for headroom at small sizes |
| white on `#C81A12` | 5.8:1 | 4.5 | pass — primary button |
| `#8A8A8A` control border on white | 3.5:1 | 3.0 (1.4.11) | pass |
| `rgba(255,255,255,.55)` border on `#111111` | 6.2:1 | 3.0 | pass |
| `#E1251B` 4 pt status rule on white | 4.7:1 | 3.0 | pass (non-text) |
| `#2B6CFF` focus ring on white | 4.5:1 | 3.0 | pass |

### 6.5 Never colour alone

Every state is carried by at least two channels. Verified by reviewing every screen in greyscale and under a deuteranopia/protanopia simulation.

| State | Colour | Text | Shape / glyph |
|---|---|---|---|
| Low stock | Red rule + red pill | "LOW" | 4 pt leading rule |
| On hold | Red rule + red pill | "ON HOLD" + "hidden from customers" | 4 pt leading rule + `eye.slash` |
| Sold out | Red rule | "SOLD OUT" | 4 pt leading rule |
| Needs attention card | Red border + wash | "3 items are low or on hold" | ⚠ glyph |
| All-good card | Black border | "Nothing needs your attention" | ✓ glyph |
| Field error | Red border | The message text | ⊗ glyph + 2 pt border weight change |
| Destructive button | Red outline | The destructive verb | ⊗ glyph |
| Selected chip | Red fill | — | ✓ glyph + bold weight |
| Selected tab | — | Label always visible | Filled glyph vs outlined + M3 indicator pill |
| Switch on/off | — | "ON"/"OFF" (iOS) | Check glyph in thumb (Android) |
| Unsynced row | — | "not saved" | `sync_problem` glyph |

### 6.6 Other

- **Motion.** Honours Reduce Motion / Remove animations (5.6). No content moves without the owner's input.
- **Orientation.** Portrait and landscape both supported; never locked. Landscape reflows the two stat tiles into a row of four and widens the content column to a 640 pt max measure.
- **Keyboard and switch control.** Full traversal order, a visible 3 pt `#2B6CFF` focus ring on every focusable element, and no keyboard traps. Hardware Return submits a form; Escape cancels.
- **Timing.** Nothing expires. The snackbar's Undo is 6 seconds — but the same undo is also available from the item's history for the rest of the session, so a slow reader never loses the option (WCAG 2.2.1).
- **Errors.** Every error is identified in text, associated programmatically with its field (`accessibilityLabelledBy`), and offers a suggestion (WCAG 3.3.1, 3.3.3).
- **Language.** `lang="en-AU"`. Currency formatted as AUD. Dates as "Thursday 24 July".

---

## 7. Onboarding and error recovery

### 7.1 First run

Four screens, then the owner is in. It can be finished in under a minute, and the tips can be skipped.

```
1. WELCOME                 2. SIGN IN            3. FACE ID
┌──────────────────┐      ┌──────────────────┐  ┌──────────────────┐
│                  │      │  OWNER SIGN-IN   │  │      [ ⊙ ]       │
│  ██ KNIGHTSBRIDGE│      │                  │  │                  │
│     NEWSAGENCY   │      │  Sign in to      │  │  Skip the        │
│                  │      │  manage your     │  │  password next   │
│  Your shop,      │      │  stock.          │  │  time?           │
│  in your pocket. │      │                  │  │                  │
│                  │      │  Email           │  │  Use Face ID and │
│  Change prices,  │      │  ┌────────────┐  │  │  you'll be in    │
│  count stock and │      │  └────────────┘  │  │  before the      │
│  see your online │      │  Password        │  │  queue moves.    │
│  orders — from   │      │  ┌────────────┐  │  │                  │
│  behind the      │      │  └────────────┘  │  │ [ Turn on    ]   │
│  counter.        │      │                  │  │ [ Not now    ]   │
│                  │      │ [ Sign in   (→)] │  │                  │
│ [ Get started(→)]│      │                  │  │                  │
└──────────────────┘      └──────────────────┘  └──────────────────┘

4. THREE TIPS  (swipeable, "Skip" always visible top-right)
┌──────────────────────────────────────────┐
│                                 [ Skip ] │
│                                          │
│   ┌────────────────────────────────────┐ │
│   │ Daily Telegraph                    │ │
│   │ $2.60      [ − ]  40  [ + ]        │ │  ← live, tappable
│   └────────────────────────────────────┘ │     demo row
│                                          │
│   Sold one? Tap the minus.               │
│                                          │
│   No menus, no saving. The number        │
│   changes straight away, and you can     │
│   undo it if you slip.                   │
│                                          │
│              ● ○ ○                       │
│   [ Next                             ]   │
└──────────────────────────────────────────┘
```

The three tips, in this order — matching Section 3's three tasks:
1. **"Sold one? Tap the minus."** The demo row is real and tappable; the owner performs the gesture rather than reading about it.
2. **"Looking for a price? Search is at the bottom."** With the search bar shown in place, so the unusual position is explained the one time it needs to be.
3. **"Run out? Take it off the website."** Demonstrates the swipe *and* says "or press and hold the item — same thing".

After the tips, the owner lands on **Today**, with one coach mark: a small bubble pointing at the gear — "Your settings live here." — dismissed by tapping anywhere.

**If the stock list is empty on first run**, Today shows the empty state (2.2) and the Add item form opens with a gentle first-time header: "Let's put in the first thing you sell. A newspaper is a good one to start with."

**What first run deliberately does not do:** ask for notification permission (deferred to the moment it's switched on), ask for photo-library permission (deferred to the first photo), show a tour of every screen, or require a profile to be filled in.

### 7.2 Error recovery — the plain-English catalogue

Rules for every message in this app:

- **Say what happened, in the owner's words.** Not "Error 500". Not "Request failed". Not "Sync conflict".
- **Say whether anything was lost.** This is the question the owner is actually asking, and almost always the answer is "nothing".
- **Give one obvious button.** Two at most.
- **Never blame the owner.** "That email or password isn't right" — not "invalid credentials".
- **No jargon.** Banned words: sync, error, invalid, failed, exception, timeout, server, token, session, cache, offline (the word "internet" is used instead), null, unauthorised.

| What went wrong | What the owner sees | Buttons |
|---|---|---|
| Wrong sign-in details | "That email or password isn't right. Check for a stray space, then try again." | *(inline, no button)* |
| Too many attempts | "Too many tries. Wait five minutes and have another go." | — |
| Forgotten password | "We'll email a reset link to the address on file. The link works for 30 minutes." | Send the link |
| No internet, general | "No internet. You can still do everything — we'll save it up." | *(black strip, no button)* |
| No internet, photo lookup | "We can't look for a photo without the internet. Your item is saved either way — it'll use the category artwork for now." | Save anyway · Add a photo myself |
| Save couldn't reach the website | "Saved on this phone. It'll go up to the website as soon as you're back online." | *(snackbar)* |
| Changes stuck for over an hour | "Some changes haven't made it to the website yet. Nothing is lost — they're safe on this phone." | Try now · See what's waiting |
| Save rejected | "We couldn't save that. Nothing you typed is lost." | Try again |
| Same item changed elsewhere | "This item was changed somewhere else while you were editing. Which do you want to keep?" — with both versions shown side by side, the differing fields in bold | Keep mine · Keep the other one |
| Item opened but since removed | "This item has been removed." | Back to stock · Put it back |
| Signed out unexpectedly | "You've been signed out. It happens after a long time away — nothing is lost." | Sign in |
| App can't load its data | "We couldn't open your shop's information. Nothing is lost, and this is our problem, not yours." | Try again · Contact support |
| Photo won't display | *(silent)* — falls back to generated category artwork, exactly as the website does | — |
| Camera/photos permission refused | "The app can't see your photos. You can turn that on in your phone's settings, or paste a web address instead." | Open settings · Paste an address |
| Notification permission refused | "Alerts are switched off in your phone's settings. You'll still see everything on the Today screen." | Open settings · That's fine |
| Removing an item in use | "Remove National Geographic? It comes off the website and out of your list. You can put it back from Settings → Removed items." | Keep it · Remove |
| Deleting a category in use | "4 items use 'Drinks'. Move them to another category first, then you can delete it." | See those 4 items · OK |
| App updated, data needs migrating | "Getting your shop ready — this only happens once." with a progress bar | — |
| Something genuinely unexpected | "Something went wrong that we didn't expect. Nothing is lost. If it keeps happening, tell us and we'll fix it." | Try again · Tell us what happened |

**The "Tell us what happened" path** opens a pre-filled email through the share/mail composer, with the app version, the device model and the last few actions attached as plain text the owner can read and edit before sending. Nothing is transmitted without them pressing send.

---

## 8. Traceability — every `owner.html` capability accounted for

| Website capability | Where it lives in the app | Notes |
|---|---|---|
| Sign in | 2.1 Sign in | Plus biometrics, plus password recovery (new). |
| Sign out | 2.7 Settings → Sign out | Was a header button; moved because it is rare and destructive-ish. |
| Add stock item | 2.5 Add item, from Stock's `+` | |
| Edit stock item | 2.5 Edit item, from Item detail | Plus inline stock/hold editing in the list, which the website had no equivalent for. |
| Remove stock item (`active: false`) | 2.4 `⋯` menu, 2.3 swipe, 2.5 footer | Now recoverable via Settings → Removed items, which is what `active: false` was always for. |
| Set price (`price_cents`) | 2.5 Price field | Dollars in, cents stored. |
| Set stock count (`stock`) | 2.3 row stepper · 2.4 detail stepper · 2.5 form · number pad | Four paths, because this is the most common write. |
| Category tag (`tag`) + "Other" | 2.5.2 Category picker | Defaults preserved in the site's order; custom tags get their own group. |
| Low-stock alert level (`low_stock_threshold`) | 2.5 "Warn me when it drops to" | Renamed from jargon; the auto-hold consequence is now explained inline. |
| Put items on hold (`held`) | 2.3 swipe / long-press · 2.4 status card · 2.5 "Show this to customers" switch · 2.2 Today card | Presented as a positive ("show"), never as "held". |
| Low-stock alert box | 2.2 Needs attention card | Plus optional push notifications. |
| View order history | 2.6.1 Orders tab | Grouped by day. |
| Order line detail | 2.6.2 Order detail | New — the website only had a comma-joined string. |
| Change sign-in details | 2.7 Settings → Sign-in details | Now requires the current password. |
| Description (`description`) | 2.5 "A short description" | |
| Photo (`image_url`) | 2.5.1 Photo options sheet | Four sources, ranked as the site ranks them. |
| Photo credit (`image_credit`) | 2.4 credit line under the photo | Licence link opens in-app. |
| Auto-found photo on save | 2.5 "Finding a photo…" button state | Honest reporting preserved; never blocks the save. |
| Generated category artwork fallback | 2.4, 2.5.1, 5.4 #27 | Silent fallback, as on the site. |
| Reset demo data | 2.7 Settings → Start again with sample stock | Two-step, typed confirmation. |
| Auto-hold on low stock after an order | 2.6.2 order notice + 2.2 attention card | Now *explained* rather than silent. |

---

## 9. Open questions for the build

1. **Multiple devices.** The spec assumes one phone. If the owner ever adds a tablet at the counter or a second staff phone, the conflict dialogue in 7.2 becomes load-bearing and needs proper last-write-wins-with-review semantics.
2. **Barcode scanning.** Not specified, because the current data model has no barcode field. It would collapse the "check a price" task to zero taps and is the highest-value single addition to this app — worth a `barcode` field on the product record now, even if the scanner ships later.
3. **Printing.** No print path is specified. If the shop wants shelf labels, that is a separate flow.
4. **Order fulfilment.** Orders are read-only here, matching the website. If online orders ever need marking as collected, Order detail needs a state machine and Orders needs a filter.
