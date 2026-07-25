# Knightsbridge Newsagency — Owner App: Technical Architecture

**Document 01 of the app design set.**
Status: proposal for sign-off. Nothing here has been built yet.

**Subject:** the native iOS + Android app that replaces `owner.html`, and the
backend that has to appear underneath it so the public website keeps working.

**Business:** Knightsbridge Newsagency, Shop 5 / 159 Ridgecrop Drive, Castle Hill
NSW 2154. Newspapers, magazines, cards, stationery, gifts, toys, lottery. One to
two people run it. The owner is not technical and has no IT support.

**Prices** are quoted in the currency the vendor actually bills in (mostly USD),
with an AUD conversion at roughly **A$1.00 = US$0.65** for budgeting. Rates move;
treat AUD figures as indicative.

**Confidence markers** are used throughout. Anything marked
**[VERIFY]** is something I believe to be true but which you must confirm against
the vendor's own page before committing money or a schedule to it. Vendor pricing
and store policy change several times a year and my information has a cutoff.

---

## 0. What exists today, and what actually changes

### 0.1 The current system

The website at `knightsbridge-static/` is a plain-HTML site with no server, no
build step and no database. Everything lives in the visitor's own browser via
`localStorage`, driven by the `store` object in `js/app.js`.

Current product shape (from `js/app.js`):

```js
{ id, name, description, price_cents, stock, low_stock_threshold,
  tag, active, held, image_url, image_credit }
```

Current owner portal (`owner.html`) does exactly seven things:

1. Email + password sign-in (`store.login`, plaintext comparison, session in `sessionStorage`)
2. Add a stock item (with automatic Openverse photo lookup on save)
3. Edit a stock item (name, description, price, stock, threshold, tag, photo, held)
4. Remove a stock item (soft delete — sets `active: false`)
5. See a low-stock panel and release an auto-hold
6. See recent online orders
7. Change sign-in email/password, and reset all demo data

The auto-hold rule in `store.fulfilOrder()` is the one piece of real business
logic in the system: when an order drops an item to or below its
`low_stock_threshold`, the item flips `held: true` and disappears from the shop.

### 0.2 The thing that breaks

Today the owner portal and the shop are the *same browser*, so they share the
same `localStorage`. That is the only reason the current system appears to work.

The moment stock is edited on a phone, that shared storage is gone. The website
has no way to learn what the owner typed. **Removing the owner portal from the
website is not a UI change — it forces a backend into existence.** This is the
single largest piece of work in the project and section 2 is the most important
section of this document.

### 0.3 Scope decision: reserve-and-collect, not e-commerce

The current cart simulates Stripe and PayPal payments. **The MVP should not take
money.** The website should take *reservations* — "reserve online, pay at the
counter" — which is what the shop page already says it does ("Reserve online and
collect at the counter").

Reasons, in order of weight:

- Taking card payments means a Stripe account, an ABN and bank verification,
  refund handling, chargeback exposure, a returns policy, and Australian
  Consumer Law obligations on a shop that currently has none of it.
- It changes the app store review posture significantly (see §7.5).
- For a newsagency where the average basket is a $2.60 newspaper and a $7.95
  card, payment processing fees (Stripe AU domestic: **1.75% + A$0.30**
  **[VERIFY]**) eat 13% of a newspaper sale. The economics are bad.
- The customer is walking in to collect anyway. They can tap their card at the
  counter on a terminal the shop already owns.

Phase 2 can add Stripe Checkout, and the schema in §2.4 leaves room for it
(`orders.payment_status`, `orders.payment_ref`). But shipping payments in v1
roughly doubles the build and triples the compliance surface.

---

## 1. Stack recommendation

### 1.1 Recommendation: React Native via Expo (managed workflow), with EAS

**Pick Expo. Do not pick Flutter. Do not pick two native codebases.**

Target: **Expo SDK 52 or later** with the New Architecture enabled (it is the
default from SDK 52 onward) **[VERIFY the current SDK number at project start —
Expo ships roughly three SDKs a year and you want the newest stable one]**.

### 1.2 Why, specifically for this project

| Criterion | Expo / React Native | Flutter | Two native apps |
|---|---|---|---|
| Language reuse with existing site | **JavaScript/TypeScript — same as `app.js`** | Dart — a second language to learn and maintain | Swift + Kotlin — two more |
| Build machine needed | **None. EAS Build compiles iOS on cloud macOS workers** | Mac required for iOS release builds | Mac required |
| Store submission tooling | **`eas submit` — one command, handles both stores** | Fastlane, hand-configured | Fastlane ×2 |
| Ship a bug fix without store review | **`eas update` — OTA JS update, live in minutes** | Shorebird (third-party, paid) | Not possible |
| Offline SQLite | `expo-sqlite` (first-party, bundled) | `sqflite` / `drift` (community) | Native, but twice |
| Biometrics | `expo-local-authentication` | `local_auth` | Twice |
| Push | `expo-notifications` + Expo Push Service (free) | `firebase_messaging` | Twice |
| Realistic effort for this app | **~3–4 weeks solo** | ~4–5 weeks + Dart ramp-up | ~8–10 weeks |

The two decisive factors:

1. **No Mac required.** EAS Build runs iOS builds on Apple silicon workers in
   Expo's cloud. For a solo developer or a small agency this removes a
   A$1,500–3,000 hardware dependency and the entire "my Xcode broke" class of
   problem. Flutter cannot do this without renting CI macOS minutes and
   configuring Fastlane match, code signing and provisioning profiles by hand.

2. **`eas update` (OTA).** This app will be maintained by whoever built it, at
   low intensity, for years. Being able to fix "the stock number shows the wrong
   thing" in twenty minutes rather than in a 24–48h App Store review cycle is
   the difference between a maintainable engagement and an abandoned one.
   Apple permits OTA JS updates provided they don't change the app's primary
   purpose (Guideline 3.3.1 / 2.5.2) — bug fixes and copy changes are squarely
   allowed; adding a whole new feature area is not.

Flutter is the better *engineering* choice on raw render performance and
compile-time safety. This app renders a list of twelve to eighty products and
some forms. Render performance is not a constraint. Maintainability by one
person who already writes JavaScript is.

### 1.3 Concrete package list

```
expo                          ~52          runtime + config plugins
expo-router                   file-based navigation (typed routes)
expo-sqlite                   local-first store (§4)
expo-secure-store             Keychain / Android Keystore for the refresh token
expo-local-authentication     Face ID / Touch ID / Android biometric gate
expo-notifications            push registration + local notifications
expo-updates                  OTA JS updates
expo-image                    product thumbnails with disk caching
expo-image-picker             take a product photo with the phone camera
expo-network                  online/offline detection for the sync queue
@supabase/supabase-js         backend client (§2)
@tanstack/react-query         server-state cache; pairs well with the outbox
zod                           input validation shared with the Edge Functions
@expo-google-fonts/plus-jakarta-sans
@expo-google-fonts/atkinson-hyperlegible          [VERIFY package name]
@sentry/react-native          crash reporting (free tier)
```

Deliberately **not** included: Redux (React Query + SQLite is enough), any UI
kit (the brand is three colours — a hand-rolled component set is smaller than
theming NativeBase), WatermelonDB (over-engineered for ≤100 rows — see §4.6).

### 1.4 Brand tokens

The palette is exactly three colours. Define once, in `theme.ts`:

```ts
export const color = {
  red:       '#E1251B',  // signal red — the only accent
  redOnDark: '#FF6E63',  // required tint for red text on black (see note)
  ink:       '#111111',  // black
  paper:     '#FFFFFF',  // white
};
export const font = {
  heading: 'PlusJakartaSans_700Bold',      // headings, buttons, labels, numbers
  headingSemi: 'PlusJakartaSans_600SemiBold',
  body:    'AtkinsonHyperlegible_400Regular',
  bodyBold:'AtkinsonHyperlegible_700Bold',
};
```

**Contrast note, carried over from the website and non-negotiable:** `#E1251B`
on white measures **4.69:1** — it passes WCAG AA for normal text. `#E1251B` on
`#111111` measures **4.06:1** — it *fails*. The website already solves this with
`--hot-dark: #FF6E63` (`style.css` line 41). The app must use the same two-token
approach: `color.red` on light surfaces, `color.redOnDark` on dark ones. Never
put `color.red` text on a black background.

The owner is in their 40s–60s. Atkinson Hyperlegible was designed by the Braille
Institute for exactly this — keep body text at **17pt minimum**, stock numbers at
**24pt**, and every tap target at **48×48pt**. Do not use a smaller "compact"
density mode.

### 1.5 Build and release tooling

**EAS Build + EAS Submit + EAS Update.** Do not use Fastlane; Expo's tooling
wraps it and you avoid maintaining a `Fastfile`, a match repo and signing certs.

Three build profiles in `eas.json`:

| Profile | Purpose | Distribution |
|---|---|---|
| `development` | Dev client on the owner's and dev's devices | Internal (ad-hoc / APK) |
| `preview` | Owner acceptance testing before each release | TestFlight internal / Play internal testing |
| `production` | Store submission | `eas submit` |

Release command sequence, in full:

```bash
eas build --platform all --profile production
eas submit --platform ios --latest      # uploads to App Store Connect
eas submit --platform android --latest  # uploads to Play Console
# bug fix, no native change:
eas update --branch production --message "fix stock decimal display"
```

Credentials: let EAS manage them (`eas credentials`). It will generate and store
the iOS distribution certificate, provisioning profile and **APNs key** and the
Android upload keystore. **Back up the Android upload keystore** — losing it
means you can never update the Play listing again without Google's key-reset
process. Export it (`eas credentials` → download) and store it in the shop's
password manager alongside the store logins.

### 1.6 Cost of the stack

| Item | Price | Notes |
|---|---|---|
| **Expo EAS Free** | **US$0/mo** | Includes a monthly build allowance on the low-priority queue **[VERIFY current allowance — I believe it is 30 builds/month across both platforms, but Expo has changed this]** |
| Expo EAS Production | US$99/mo | Only if you need priority queue / higher concurrency. **You do not.** |
| Pay-per-build overage | ~US$1 Android / ~US$2 iOS **[VERIFY]** | Relevant only if you exceed free allowance |
| Expo Push Notifications | **US$0** | Unlimited, free, no plan required |
| EAS Update | **US$0** on free tier | Monthly active-user cap; this app has 1–2 users |
| Sentry Developer | **US$0** | 5k errors/month free tier |

**Realistic annual EAS spend for this project: $0.** A shop app ships perhaps
four to six native builds a year. Queue waits of 10–30 minutes on the free tier
are irrelevant at that cadence.

---

## 2. The backend problem

### 2.1 The requirement stated precisely

Once stock lives in the app, four things must be true simultaneously:

1. The **public website** shows current stock and prices without the owner
   touching it. The site must stay a plain static site — no Node server, no
   build step. That constraint is the whole character of the existing project.
2. A **customer reserving online** must decrement stock in a way the owner's
   phone sees.
3. The **owner's app** must work with no signal and reconcile later (§4).
4. The **push notification** for a new order must be generated by something
   that is awake when the app is not (§5).

Requirement 4 alone eliminates "no server". Something must be running.

### 2.2 Recommendation: Supabase, Sydney region (`ap-southeast-2`)

**Use Supabase.** Create the project in **ap-southeast-2 (Sydney)** — every
customer and the owner are within 40km of that data centre; picking us-east-1 by
accident adds ~200ms to every page load for no reason.

### 2.3 Why Supabase and not the alternatives

The decisive argument is narrow and specific: **PostgREST**.

Supabase exposes every table as a REST endpoint automatically. That means the
static website's product fetch is a single `fetch()` in a plain `<script>` tag
with **no SDK, no bundler, no build step** — preserving exactly the property that
makes the current site what it is:

```js
// js/api.js — the entire backend integration for the public website
const SUPABASE_URL = 'https://<project-ref>.supabase.co';
const SUPABASE_ANON_KEY = '<publishable anon key — safe to ship, RLS enforced>';

async function fetchProducts() {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/public_products?select=*&order=tag,name`,
    { headers: { apikey: SUPABASE_ANON_KEY,
                 Authorization: `Bearer ${SUPABASE_ANON_KEY}` } }
  );
  if (!res.ok) throw new Error('products ' + res.status);
  return res.json();   // [] of the same shape store.products() returns today
}
```

That is a drop-in replacement for `store.products()`. Nothing else about the
site's architecture has to change.

| Option | Verdict |
|---|---|
| **Supabase** | **Chosen.** Postgres (relational, matches the existing model), auto-REST for the static site, Auth, Edge Functions for push, Realtime, generous free tier, Sydney region. |
| Firebase / Firestore | Viable, but: NoSQL forces you to denormalise a model that is naturally relational; the static site needs the Firebase JS SDK bundled (~100KB+, and awkward without a build step); per-document read pricing makes a busy shop page unpredictable; and stock decrements need transactions that are more painful in Firestore than a Postgres `UPDATE ... RETURNING`. |
| Cloudflare D1 + Workers | Cheapest and fastest at the edge, but **you write the entire API yourself** — auth, sessions, password reset, row-level security, push fan-out. That is 2–3 weeks of work Supabase gives you free, and it is 2–3 weeks that a solo maintainer has to keep secure forever. Reject. |
| PocketBase | Excellent software, single Go binary, genuinely lovely. But **it needs a VPS you administer** — OS patching, TLS renewal, backups, disk monitoring. Handing a non-technical shopkeeper a system whose uptime depends on the developer remembering to patch a Hetzner box is irresponsible. Reject. |
| Neon / Turso + a small API | Same objection as D1: you're writing the API. Reject. |

**The honest counter-argument to Supabase:** it is a venture-funded company and
the free tier's terms are theirs to change. Mitigation: it is plain Postgres.
`pg_dump` produces a file that restores onto any Postgres anywhere. The exit
cost is genuinely low, unlike Firestore. Take the nightly dump described in §2.8
and this risk is bounded.

### 2.4 Data schema

Written as the migration you would actually run. Note the deliberate split
between `products` (attributes) and `stock_movements` (a ledger) — that split is
what makes §4's offline conflict resolution possible, and it is the single most
important design decision in this document.

```sql
-- ============================================================
-- 001_init.sql
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- products: attributes only, never a mutable stock scalar you write to
create table products (
  id                   uuid primary key default gen_random_uuid(),
  legacy_id            integer,                    -- the 1..12 ids from localStorage
  name                 text        not null check (length(name) between 1 and 120),
  description          text        not null default '',
  price_cents          integer     not null check (price_cents >= 0),
  low_stock_threshold  integer     not null default 3 check (low_stock_threshold >= 0),
  tag                  text        not null,
  active               boolean     not null default true,   -- soft delete
  held                 boolean     not null default false,  -- hidden from customers
  image_url            text,
  image_credit         jsonb,                      -- Openverse licence block, verbatim
  stock_cached         integer     not null default 0,       -- DERIVED. Never write directly.
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid references auth.users(id)
);

create index products_active_idx on products (active) where active;
create index products_tag_idx    on products (tag);

-- ---------- stock_movements: the append-only truth about stock
-- kind = 'count'    -> owner did a stocktake. counted_to is absolute. delta ignored.
-- kind = 'sale'     -> an order took units. delta is negative.
-- kind = 'delivery' -> stock arrived. delta is positive.
-- kind = 'waste'    -> damaged / returned to supplier. delta is negative.
create table stock_movements (
  id               uuid primary key default gen_random_uuid(),
  product_id       uuid not null references products(id) on delete cascade,
  kind             text not null check (kind in ('count','sale','delivery','waste','adjust')),
  delta            integer,          -- null for 'count'
  counted_to       integer,          -- non-null only for 'count'
  occurred_at      timestamptz not null,   -- CLIENT wall-clock time of the action
  recorded_at      timestamptz not null default now(),  -- when the server received it
  source           text not null check (source in ('app','web_order','system')),
  order_id         uuid,
  note             text,
  idempotency_key  text not null unique,   -- client-generated; makes retry safe
  created_by       uuid references auth.users(id)
);

create index sm_product_time_idx on stock_movements (product_id, occurred_at desc);

-- ---------- orders: reservations from the website
create table orders (
  id             uuid primary key default gen_random_uuid(),
  reference      text unique not null,          -- human-readable, e.g. 'KN-4821'
  customer_name  text not null,
  customer_phone text not null,
  customer_email text,
  status         text not null default 'pending'
                 check (status in ('pending','ready','collected','cancelled')),
  total_cents    integer not null,
  payment_status text not null default 'unpaid'  -- room for phase 2
                 check (payment_status in ('unpaid','paid','refunded')),
  payment_ref    text,
  note           text,
  created_at     timestamptz not null default now(),
  collected_at   timestamptz
);

create table order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  product_id   uuid not null references products(id),
  name_at_time text    not null,     -- snapshot: the name must not change retroactively
  price_cents  integer not null,     -- snapshot: honour the price shown at reservation
  qty          integer not null check (qty > 0)
);

-- ---------- devices: where to send a push
create table devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  expo_token  text unique not null,
  platform    text not null check (platform in ('ios','android')),
  last_seen   timestamptz not null default now()
);

-- ---------- notification log: so a low-stock alert fires once, not on every write
create table alerts_sent (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,          -- 'low_stock' | 'new_order'
  subject_id  uuid not null,          -- product id or order id
  sent_at     timestamptz not null default now()
);
create unique index alerts_dedupe_idx
  on alerts_sent (kind, subject_id, (date_trunc('day', sent_at)));
```

**The derived stock recalculation.** `stock_cached` is maintained by a trigger,
never by application code:

```sql
create or replace function recalc_stock(p_product uuid) returns void
language plpgsql as $$
declare
  base_at  timestamptz;
  base_qty integer;
  result   integer;
begin
  -- most recent stocktake wins as the baseline
  select occurred_at, counted_to into base_at, base_qty
  from stock_movements
  where product_id = p_product and kind = 'count'
  order by occurred_at desc limit 1;

  if base_at is null then
    base_at := '-infinity'::timestamptz;
    base_qty := 0;
  end if;

  -- then apply every non-count movement that happened AFTER that stocktake
  select base_qty + coalesce(sum(delta), 0) into result
  from stock_movements
  where product_id = p_product
    and kind <> 'count'
    and occurred_at > base_at;

  update products
     set stock_cached = greatest(0, result),
         updated_at   = now()
   where id = p_product;
end $$;

create or replace function trg_recalc_stock() returns trigger
language plpgsql as $$
begin
  perform recalc_stock(coalesce(new.product_id, old.product_id));
  return null;
end $$;

create trigger stock_movements_recalc
  after insert or update or delete on stock_movements
  for each row execute function trg_recalc_stock();
```

**Read this carefully, because it is the answer to the offline problem.** A
stocktake (`count`) sets a baseline *at a point in time*. Sales that happened
after that point are re-applied on top. So it does not matter in what order the
server *receives* the owner's offline stocktake and the website's online sale —
the result is the same. That is a CRDT-shaped guarantee obtained with forty
lines of PL/pgSQL. §4.4 works through the worked example.

### 2.5 The view the website reads

Never let the public read `products` directly — it has `updated_by` and internal
fields on it. Expose a view shaped exactly like today's product object so the
website's rendering code (`productCardHTML` in `js/app.js`) needs no changes:

```sql
create view public_products as
select
  id,
  name,
  description,
  price_cents,
  stock_cached as stock,
  low_stock_threshold,
  tag,
  held,
  image_url,
  image_credit
from products
where active;

grant select on public_products to anon;
```

### 2.6 Row Level Security

RLS is the entire security model. Get it wrong and the anon key ships a
write-capable database to the public internet.

```sql
alter table products        enable row level security;
alter table stock_movements enable row level security;
alter table orders          enable row level security;
alter table order_items     enable row level security;
alter table devices         enable row level security;

-- Public (anon): nothing. Not even select. The website reads the VIEW only.
-- Views run with the definer's rights, so `grant select on public_products to anon`
-- is the sole public read path.  [VERIFY: on newer Postgres you may need
-- `security_invoker = false` set explicitly on the view — check the Supabase
-- docs for the version your project is provisioned with.]

-- Owner (authenticated): full control of the shop.
create policy owner_all_products on products
  for all to authenticated using (true) with check (true);

create policy owner_all_movements on stock_movements
  for all to authenticated using (true) with check (true);

create policy owner_read_orders on orders
  for select to authenticated using (true);
create policy owner_update_orders on orders
  for update to authenticated using (true) with check (true);

create policy own_devices on devices
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
```

**Orders are never inserted by the browser.** A customer with the anon key must
not be able to write an order row directly — they could set `total_cents` to 0
or reserve 10,000 newspapers. Order creation goes through an Edge Function
(§2.7) which validates server-side.

### 2.7 The one piece of server code: `create-reservation`

A Supabase Edge Function (Deno, TypeScript). Roughly 80 lines. It is the only
custom backend code in the system.

```
POST /functions/v1/create-reservation
Body: { items: [{ product_id, qty }], customer_name, customer_phone,
        customer_email?, note? }
```

It must, inside a single transaction (call a Postgres function via RPC so it is
genuinely atomic):

1. Re-read every product's `price_cents`, `stock_cached`, `held`, `active` from
   the database. **Never trust prices or availability sent by the browser.**
2. Reject if any item is `held`, `!active`, or `qty > stock_cached`, returning
   which item failed so the site can say "sorry, only 2 left of that".
3. Insert `orders` + `order_items` with server-computed totals and snapshotted
   names/prices.
4. Insert one `stock_movements` row per item: `kind='sale'`,
   `delta = -qty`, `source='web_order'`, `occurred_at = now()`,
   `idempotency_key = order_id || ':' || product_id`.
5. The trigger recalculates `stock_cached`; a second trigger applies the
   auto-hold rule (§2.9).
6. Return `{ reference }` for the success page.
7. Fire the push notification (§5).

Rate limiting: cap by IP at, say, 10 reservations per hour, and add a simple
honeypot field to the form. A newsagency is not a high-value target, but an
unauthenticated public write endpoint always attracts junk.

### 2.8 Auto-hold — preserving the existing business rule

The behaviour in `store.fulfilOrder()` must survive the migration. It becomes a
trigger so it applies no matter whether stock moved because of an online order
or an offline edit that later synced:

```sql
create or replace function trg_auto_hold() returns trigger
language plpgsql as $$
begin
  if new.stock_cached <= new.low_stock_threshold and not new.held then
    new.held := true;                       -- hide from customers
  elsif new.stock_cached > new.low_stock_threshold and old.held
        and old.stock_cached <= old.low_stock_threshold then
    new.held := false;                      -- auto-release once restocked
  end if;
  return new;
end $$;

create trigger products_auto_hold
  before update of stock_cached on products
  for each row execute function trg_auto_hold();
```

One behavioural improvement over the current site: the existing code auto-holds
but never auto-releases — the owner has to press "Release hold" manually. The
`elsif` above releases the hold automatically once a delivery is recorded, which
is what the owner actually wants. Keep the manual override button as well.

### 2.9 What has to change on the website

Concrete file-by-file work. This is real but small — call it **two to three days**.

| File | Change |
|---|---|
| `js/app.js` | Gut `store`. Products, orders and owner credentials all leave. Keep the **cart** in `localStorage` (a cart is genuinely per-browser and belongs there). Keep `money()`, `esc()`, `productCardHTML()`, `renderShell()` unchanged. |
| `js/api.js` | **New.** ~60 lines: `fetchProducts()`, `createReservation()`, a 5-minute `sessionStorage` cache, and an offline fallback that renders the last-known product list with a "prices may have changed" banner. |
| `shop.html` | `render()` becomes `async`. Add a skeleton/loading state and an error state. The tag filter is now derived from fetched data, so build it after the fetch resolves rather than at script-parse time. |
| `cart.html` | Replace the two "Simulate payment" buttons with a **reservation form**: name, phone, optional email, optional note. On submit call `createReservation()`. Handle the "someone else just took the last one" rejection gracefully. |
| `success.html` | Show the real order `reference` returned by the server ("Quote KN-4821 at the counter") instead of the simulated receipt. |
| `owner.html` | **Delete the file.** |
| Footer in `js/app.js` | Remove the "Staff → Owner sign in" list item and the `owner.html` nav entry. Replace with nothing, or an "Our app" link if you list the store pages. |
| `demo-banner` in every page | Remove — it says data is stored in the browser and payments are simulated. Neither is true any more. |
| `index.html` | Home page product carousel now reads from `fetchProducts()`. |
| **Hosting** | The site currently runs from `file://`. It must move to a real origin — a browser will not let `file://` call the Supabase API under CORS, and you want HTTPS. **Cloudflare Pages** (free, drag-and-drop or Git-connected) or Netlify (free). |

Two things that specifically must not regress:

- **The Openverse photo lookup moves into the app**, not the website. `js/images.js`'s
  `findProductImage()` logic ports to the app almost verbatim — it's plain
  `fetch`. The resulting `image_url` and `image_credit` are stored in the
  database, so the website just renders what it is given and never calls
  Openverse for product photos again. This is a *better* arrangement: Openverse's
  rate limit (20/min, 200/day per address **[VERIFY current limits]**) was being
  consumed by every visitor's browser; now it is consumed once, by one phone,
  when an item is created. The **gallery** lookup on the home page can stay on
  the website with its existing 30-day `localStorage` cache, or better, move the
  six gallery photos into the database too.
- **The CC attribution line must keep rendering.** `image_credit` is stored as
  `jsonb` precisely so `imageCreditHTML()` keeps working unmodified. Dropping the
  credit is a licence breach.

### 2.10 What it costs per month

At this shop's scale: perhaps 80 products, 5–30 reservations a week, a few
hundred site visits a week, one or two app users.

| Service | Plan | Monthly | Notes |
|---|---|---|---|
| Supabase | **Free** | **US$0** | Free tier is ~500MB database, ~1GB file storage, ~5GB egress, 50k MAU **[VERIFY current limits]**. This shop will use well under 1% of the database allowance. |
| Cloudflare Pages | Free | **US$0** | Unlimited static requests, 500 builds/month |
| Expo EAS + Push + Update | Free | **US$0** | §1.6 |
| Sentry | Developer | **US$0** | |
| Apple Developer Program | Annual | **US$99/yr** ≈ A$149/yr **[VERIFY the AUD price — Apple bills locally]** | ≈ A$12.40/mo |
| Google Play Developer | One-time | **US$25 once** | Not recurring |
| Domain (.com.au) | Annual | ~A$20–35/yr | If not already owned |
| **Total ongoing** | | **≈ A$15–18/month** | Essentially just Apple's tax |
| **Year one total** | | **≈ A$230–260** | Including the one-off Play fee |

**Two real caveats on the free tier, and how to neutralise them:**

1. **Supabase pauses free projects after ~7 days of no activity** **[VERIFY the
   current inactivity window]**. A live shop website queried daily will not
   pause. But if the shop closes for a three-week Christmas break, it might.
   Mitigation: a free UptimeRobot or cron-job.org monitor hitting
   `/rest/v1/public_products?limit=1` every 15 minutes. Costs nothing, removes
   the risk entirely, and gives you uptime alerting as a bonus.

2. **The free tier has no point-in-time recovery.** Mitigation: a GitHub Actions
   workflow on a nightly `cron` running `pg_dump` into a private repo or an R2
   bucket. Free, ~15 lines of YAML, and the resulting SQL file restores onto any
   Postgres. Do this on day one, not after the first data loss.

**When you'd move to Supabase Pro (US$25/mo ≈ A$38/mo):** if the shop grows to
the point where losing a day of orders matters commercially, Pro buys daily
backups + 7-day PITR, no pausing, and email support. My recommendation is to
**start on Free with the two mitigations above** and tell the owner honestly:
"this runs for about fifteen dollars a month, and if the shop ever depends on it
for real money, it's another forty."

---

## 3. Auth

### 3.1 Design principle

There are one or two users, both of whom stand behind the same counter. Anything
resembling an identity provider, an SSO integration, an org/tenant model or a
role matrix is architecture astronautics. The requirement is: *the right person
gets in quickly; nobody else gets in; and when the owner forgets their password
at 5:40am with the papers to put out, they are not locked out.*

That last clause is the actual hard requirement.

### 3.2 Recommendation

**Supabase Auth, email + password, with an email OTP recovery path and a local
biometric gate.**

Concretely:

- **Two accounts, provisioned by the developer**, not self-signup:
  `owner@knightsbridgenews.com.au` and a second for the spouse/casual staff.
  Disable public signup entirely in the Supabase dashboard
  (Authentication → Providers → Email → "Enable sign ups" off). Nobody should be
  able to create an account against this project. This also sidesteps Apple's
  in-app account-deletion requirement (§7.4).
- **No email confirmation loop on first login** — the developer sets the initial
  password and hands it over in person or by phone.
- **Password minimum 10 characters.** Do not impose complexity rules; they push
  a non-technical user toward `Password1!` written on a Post-it under the till.
  Suggest a passphrase ("ridgecrop-papers-6am") in the onboarding screen copy.

### 3.3 Session persistence

This is the part that determines whether the owner finds the app usable.

- On successful login, Supabase returns an **access token** (JWT, ~1 hour) and a
  **refresh token** (long-lived).
- Store **only the refresh token** in `expo-secure-store`, which maps to the
  **iOS Keychain** and the **Android Keystore**. Do not put it in
  `AsyncStorage` — that is plain unencrypted files on disk.
- Set `expo-secure-store`'s `keychainAccessible: WHEN_UNLOCKED` so the token is
  unreadable while the phone is locked.
- Configure the Supabase client with `autoRefreshToken: true` and
  `persistSession: true` backed by a SecureStore adapter.
- **The owner should log in approximately once, ever.** Refresh tokens rotate
  silently. A re-login prompt should only appear if the refresh token is revoked
  or unused for 30+ days.

Set Supabase's refresh token expiry generously — a shop app that logs you out
because you took a week off is a support call.

### 3.4 Biometrics — and what they actually are

Use `expo-local-authentication` (Face ID, Touch ID, Android fingerprint/face).

**Be precise about the security model, because this is commonly misunderstood:**
biometrics here are a **local re-entry gate**, not an authentication factor
against the server. Supabase never sees a fingerprint. The flow is:

1. Refresh token sits encrypted in the Keychain/Keystore.
2. App comes to foreground after >2 minutes in background, or on cold start.
3. `LocalAuthentication.authenticateAsync()` prompts for Face ID.
4. On success, the app reads the token from SecureStore and exchanges it for an
   access token.
5. On failure, offer "Use password instead" — **always**. A cracked screen
   protector, a wet hand, sunglasses, or a phone the owner just replaced will
   all defeat biometrics, and there must never be a state where the only way in
   is a sensor that isn't working.

Ask for biometric enrolment **after** the first successful password login, with
copy the owner will understand: *"Use Face ID to open the app? You won't have to
type your password each time."* Not "Enable biometric authentication."

Also handle: device has no biometric hardware, biometrics enrolled but not for
this app, and biometrics enrolled after install. `hasHardwareAsync()` +
`isEnrolledAsync()` cover the first two.

### 3.5 Account recovery — the section that matters most

**Assume the owner will forget the password. Design for it as a certainty.**

Four layers, in order of how they'll actually be used:

**Layer 1 — Email OTP code (primary).**
"Forgot password" sends a **6-digit code** to the account email, entered in the
app, which then lets the owner set a new password.

Use an OTP code, **not a magic link.** Magic links on mobile require universal
links / app links to be configured perfectly, and they break when the email is
opened in a webmail tab on the shop's counter PC rather than on the phone — the
link then signs in the *wrong device*. A six-digit code the owner reads off one
screen and types into another works from any email client, on any device, every
time. This is a deliberate, opinionated choice against the more "modern" option.

**Layer 2 — the second account.**
Because there are two accounts, and both have full rights, one person forgetting
their password never stops the shop trading. This is the cheapest possible
redundancy and it is the reason to provision two accounts on day one even if the
shop is currently one person.

**Layer 3 — the break-glass card.**
Print a physical card at handover. Laminate it. It lives in the safe or the till
drawer, not next to the phone:

```
KNIGHTSBRIDGE NEWSAGENCY — SHOP APP
Sign-in email:  owner@knightsbridgenews.com.au
Password:       ______________________________
Second sign-in: ______________________________
If the code email doesn't arrive, ring:  <developer name>  <mobile>
```

This looks unfashionable. For a 1–2 person shop with no IT department it is more
reliable than any password manager the owner will not maintain.

**Layer 4 — developer reset.**
The developer retains Supabase dashboard access and can reset a password
directly. This must be written into the handover document with a named person
and a phone number. **Flagging this honestly: this is a bus-factor-of-one and a
standing trust relationship.** If the developer relationship ends, the handover
must include transferring Supabase project ownership to an email the shop
controls. Put a calendar reminder on it.

**The failure mode to design against explicitly:** the account email is
`owner@knightsbridgenews.com.au`. If that mailbox is hosted somewhere the owner
has also forgotten the password to, layers 1 and the recovery path both die at
once. During setup, **verify that the owner can actually receive and read mail
at the recovery address on their phone.** Test it. If they can't, use their
personal Gmail as the account email instead — less tidy, dramatically more
recoverable.

### 3.6 Explicitly out of scope

No SSO, no SAML, no Google/Apple social login (adds Apple's Sign in with Apple
requirement — see §7.4 — for no benefit), no MFA/TOTP (a second factor the owner
will lose is a lockout generator, not a security control), no roles/permissions
matrix, no audit log beyond `stock_movements.created_by`.

---

## 4. Offline behaviour

### 4.1 The environment

Shop 5 is an interior tenancy in a suburban shopping centre. Expect: no usable
mobile data in the stockroom, patchy 4G on the floor, and centre wifi that is
either absent, captive-portalled, or shared with fifty other tenants. Assume the
owner will do a Sunday-evening stocktake with **no connectivity at all** and
expect every keystroke to have stuck.

**The app must be fully functional offline for every operation except viewing
brand-new online orders.** Not "degrades gracefully" — fully functional.

### 4.2 Local-first storage

**`expo-sqlite` is the app's primary datastore. The network is a synchroniser,
not a dependency.** Every screen reads from SQLite. No screen ever awaits a
network call to render.

Three local tables:

```sql
-- mirror of the server's products, plus sync bookkeeping
CREATE TABLE local_products (
  id TEXT PRIMARY KEY, name TEXT, description TEXT,
  price_cents INTEGER, low_stock_threshold INTEGER, tag TEXT,
  active INTEGER, held INTEGER, image_url TEXT, image_credit TEXT,
  stock_cached INTEGER,
  server_updated_at TEXT,      -- last value the server gave us
  dirty INTEGER DEFAULT 0      -- 1 = has unsynced local attribute edits
);

-- local view of stock movements, including ones not yet sent
CREATE TABLE local_movements (
  id TEXT PRIMARY KEY, product_id TEXT, kind TEXT, delta INTEGER,
  counted_to INTEGER, occurred_at TEXT, idempotency_key TEXT UNIQUE,
  synced INTEGER DEFAULT 0
);

-- THE OUTBOX
CREATE TABLE outbox (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,  -- strict FIFO
  idempotency_key  TEXT UNIQUE NOT NULL,
  operation        TEXT NOT NULL,   -- 'upsert_product' | 'record_movement' | 'update_order'
  payload          TEXT NOT NULL,   -- JSON
  created_at       TEXT NOT NULL,
  attempts         INTEGER DEFAULT 0,
  last_error       TEXT,
  status           TEXT DEFAULT 'pending'  -- pending | sending | failed | done
);
```

### 4.3 The outbound sync queue

**Every mutation, online or offline, follows the same path.** There is no
"if online, write directly" branch — that branch is where sync bugs live.

```
user taps Save
   │
   ├─ 1. write to SQLite (local_products / local_movements)   ← synchronous
   ├─ 2. append a row to outbox with a UUIDv4 idempotency_key ← same transaction
   ├─ 3. UI re-renders from SQLite                            ← instant, always
   └─ 4. kick the sync worker (fire and forget)
```

Sync worker rules:

- **Strict FIFO by `outbox.id`.** Never parallelise. Order matters — creating a
  product then setting its stock must arrive in that order.
- **Triggers:** app foreground, network reconnect (`expo-network` listener),
  after any local mutation, and every 60s while foregrounded.
- **Retry:** exponential backoff — 1s, 2s, 4s, 8s… capped at 5 minutes. Never
  give up permanently on a 5xx or a network error.
- **Terminal failures** (4xx that isn't 401/408/429) mark the row `failed` and
  surface it in the UI. Never silently drop a write.
- **401** → attempt token refresh, then retry once; if that fails, pause the
  queue and prompt for login. Do not discard the queue on logout.
- **Idempotency:** the key goes in `stock_movements.idempotency_key`, which has
  a `unique` constraint. If the phone sent the request, lost signal before the
  response, and retries, the server returns a duplicate-key conflict which the
  client treats as **success**. This is why the constraint exists.

### 4.4 Conflict resolution

Two genuinely different problems, solved two different ways.

#### 4.4.1 Stock quantities — solved by the ledger, not by a merge

This is the scenario in the brief: *the owner edits stock offline while an online
order decrements the same item.*

Concretely: `National Geographic`, `stock = 8` this morning.

| Time | Event | Where |
|---|---|---|
| 14:00 | Owner, in the stockroom with no signal, counts the shelf and types **12** | Phone, offline |
| 14:30 | A customer reserves **2** online | Website → server |
| 17:00 | Owner comes back into signal; the outbox drains | Phone → server |

Naive last-write-wins gives **12** — the two reserved copies vanish, the shelf
and the system disagree, and a customer turns up to collect a magazine that
isn't there.

The ledger gives the right answer with no merge logic:

```
stock_movements for National Geographic
  kind=count,  counted_to=12, occurred_at=14:00, source=app        (arrived 17:00)
  kind=sale,   delta=-2,      occurred_at=14:30, source=web_order  (arrived 14:30)

recalc_stock():
  baseline = latest count  = 12 as at 14:00
  apply every non-count movement with occurred_at > 14:00:  -2
  stock_cached = 10        ✓
```

**Ten.** Correct, and — critically — **independent of arrival order.** Had the
outbox drained at 14:15 instead, the recalculation on receiving the 14:30 sale
would produce the same 10. This is why `occurred_at` is the client's wall-clock
time of the action and `recorded_at` is separate.

The same mechanism handles the reverse case (owner records a delivery of +20
offline while sales tick down online) and the multi-device case (owner's phone
and spouse's phone both offline) without any extra code.

**Two honest caveats:**

- **Clock skew.** `occurred_at` is client wall-clock. If the owner's phone clock
  is badly wrong, ordering breaks. Mitigation: on every sync response, compare
  the server's `Date` header to local time; if they differ by more than 5
  minutes, show a one-time warning ("Your phone's clock is wrong — please turn
  on automatic time") and record the measured skew on the movement row so it can
  be corrected forensically. Modern phones with automatic time are reliable, so
  this is a long-tail concern, not a common one.
- **Two offline stocktakes of the same item on two devices.** The later
  `occurred_at` wins outright and the earlier one is discarded from the
  baseline. This is correct behaviour (the later count is more current) but the
  earlier count's information is silently lost. For a two-person shop this is
  fine. Flag it as a known limitation.

#### 4.4.2 Product attributes — last-write-wins, per field

Name, description, price, tag, threshold, photo. These are not additive; there
is no merge semantics for "the price is $6.20" vs "the price is $6.50".

- Send only the fields the owner actually changed (dirty-field tracking), not
  the whole object. This alone eliminates the overwhelming majority of real
  conflicts — two people rarely edit the *same field* of the *same product*.
- Last write wins by `occurred_at`.
- **Except for price.** A price change is the one attribute where a silent
  overwrite has money attached to it. If the server's `price_cents` changed
  after the local edit's `occurred_at`, do not auto-resolve: apply the change,
  but raise an in-app notice — *"You set Woman's Day to $6.20 while offline, but
  it had already been changed to $6.50. It's now $6.20. Tap to change it back."*
  One tap to undo. This is a five-line special case and it prevents the only
  conflict class that costs the shop money.

#### 4.4.3 Deletes

Soft delete only (`active = false`), which is what the current site already does.
A soft delete is just another attribute write and needs no special handling. Never
hard-delete a product — `order_items.product_id` references it.

### 4.5 What the owner sees

Offline must be visible but not alarming. A non-technical user needs to know
their work is safe, not to be told about queue depth.

- **A persistent thin bar** under the header when offline or when the outbox is
  non-empty: `Offline — 3 changes will send when you're back on` in
  `color.red` on white. Never a modal, never a blocking dialog.
- **When the queue drains:** the bar turns to `All changes saved` for 3 seconds,
  then disappears.
- **Never disable a Save button because the app is offline.** Everything saves
  locally; the button always works.
- **Order list** shows `Last checked 4:15pm` when offline. This is the one
  genuinely degraded surface and the copy should say so plainly: *"New orders
  can't come through without a connection."*
- **A "Sync problems" screen**, reachable from settings, listing any `failed`
  outbox rows in plain English with a Retry button. This exists so that a
  support phone call can be resolved in thirty seconds.

### 4.6 Why not an off-the-shelf sync engine

WatermelonDB, PowerSync, ElectricSQL and Legend-State all solve this problem
more generally. For **≤100 products and ~2 users**, hand-rolling the outbox
above is perhaps 300 lines of well-understood code with no vendor and no
per-user cost, versus adopting a framework whose failure modes the maintainer
would have to learn.

**The escalation trigger, stated in advance:** if this app ever grows to
multiple stores, more than ~5 concurrent editors, or thousands of SKUs, replace
the hand-rolled outbox with **PowerSync** (which is purpose-built for
Supabase + SQLite and has a free tier **[VERIFY current pricing]**). The
ledger schema in §2.4 is compatible with that migration; it is the outbox that
gets replaced, not the data model. That is a deliberate design property.

---

## 5. Push notifications

### 5.1 What gets sent

Only two things, plus one digest. Notification discipline matters enormously
here — a shopkeeper who gets buzzed forty times a day turns notifications off,
and then misses the one that mattered.

| # | Trigger | Copy | Timing |
|---|---|---|---|
| 1 | New online reservation | `New order KN-4821 — Sarah, 3 items, $18.40` | Immediate |
| 2 | An item crosses its low-stock threshold | `Low stock: National Geographic — 3 left` | Immediate, **max once per item per day** |
| 3 | Morning digest | `4 items low, 2 orders waiting to collect` | 06:30 AEST daily, only if non-empty |

Rules baked into the design:

- **Quiet hours.** Nothing between 20:00 and 06:00 AEST except a new order,
  which is still worth knowing about. Make it configurable in-app.
- **Deduplication** via the `alerts_sent` table's unique index on
  `(kind, subject_id, day)`. Without this, an item hovering at the threshold
  generates a notification on every single sale. This is the most common way
  low-stock alerts become useless.
- **Deep links.** Tapping a new-order notification opens
  `knightsbridge://orders/<id>`, not the home screen. Configure the scheme in
  `app.json` and route it with Expo Router.
- **Local notifications too:** a low-stock condition detected *offline* by the
  app's own SQLite fires a **local** notification via `expo-notifications`
  immediately, with no server involved. The owner is standing in the shop; they
  should be told even with no signal.

### 5.2 Transport: Expo Push Service

Use **Expo's push service** (`https://exp.host/--/api/v2/push/send`) rather than
calling APNs and FCM directly. It is free and unlimited, it abstracts both
platforms behind one token format and one API call, and it handles the
receipt/error semantics (`DeviceNotRegistered`, etc.) that you would otherwise
implement twice.

The trade-off to state honestly: it puts a third party in the delivery path for
notifications. For a shop stock alert, that is an entirely acceptable
dependency. If it ever isn't, `expo-notifications` can be configured to hand you
raw APNs/FCM tokens instead and you swap the server-side call.

### 5.3 iOS / APNs setup

1. Apple Developer Program membership (§7.1) — **required before any push work
   at all**, including in development.
2. In the Apple Developer portal → **Certificates, Identifiers & Profiles → Keys**,
   create a key with **Apple Push Notifications service (APNs)** enabled.
   Download the `.p8` file. **Apple lets you download it exactly once.**
3. Easiest route: run `eas credentials` and let **EAS generate and manage the
   APNs key for you** — it creates it in your Apple account and stores it
   server-side. This is the recommended path and removes the "we lost the .p8"
   failure mode.
4. Enable the Push Notifications capability — Expo's config plugin does this
   automatically when `expo-notifications` is installed.
5. Request permission at the right moment: **not on first launch.** Show a
   plain-English pre-prompt after the owner's first successful sign-in
   (*"Get a buzz when an order comes in or something runs low?"*), and only call
   `requestPermissionsAsync()` if they say yes. iOS gives you exactly one shot
   at the system prompt; wasting it on a cold first launch is how apps end up
   with 30% opt-in.
6. **Push does not work in the iOS Simulator.** Physical device required for all
   testing.

### 5.4 Android / FCM setup

1. Create a Firebase project (free — you are using it *only* as an FCM
   transport, not as a backend).
2. Add an Android app with the package name `au.com.knightsbridgenews.owner`.
3. Download `google-services.json`, reference it from `app.json`
   (`android.googleServicesFile`), and **do not commit it to a public repo**.
4. Generate a **service account JSON** with the *Firebase Messaging API* role
   and upload it to Expo (`eas credentials`). This is **FCM v1**. The legacy
   FCM server key API was shut down by Google in mid-2024 — any tutorial telling
   you to paste a "Server Key" is out of date. **[VERIFY]**
5. Android 13+ requires the `POST_NOTIFICATIONS` runtime permission. Same
   pre-prompt pattern as iOS.
6. Define an Android notification channel (`orders`, importance HIGH) so the
   alert makes a sound. Without an explicit channel, Android silently assigns a
   default that may be silent.

### 5.5 What has to exist server-side

Everything below lives in Supabase — no separate server process.

**(a) Token registration.** On app start, after auth and after permission is
granted, the app calls `getExpoPushTokenAsync()` and upserts into `devices`.
Refresh `last_seen` on every app open. Prune rows not seen in 90 days.

**(b) The dispatcher — one Edge Function, `send-push`:**

```
POST /functions/v1/send-push   (service-role only, never callable by anon)
Body: { kind, subject_id, title, body, data }

1. Insert into alerts_sent — if the unique index rejects it, STOP (already sent today)
2. Select expo_token from devices for all authenticated owners
3. POST the batch to https://exp.host/--/api/v2/push/send
4. Read the receipt tickets; on DeviceNotRegistered, DELETE that devices row
```

**(c) Triggering it from the database.** Use a Postgres `AFTER INSERT` trigger
calling **`pg_net`** (`net.http_post`, available on Supabase) to invoke the Edge
Function asynchronously — critically, `pg_net` does not block the transaction,
so a slow push API can never make a customer's reservation time out.

```sql
create trigger notify_new_order
  after insert on orders
  for each row execute function trg_push_new_order();

create trigger notify_low_stock
  after update of stock_cached on products
  for each row when (new.stock_cached <= new.low_stock_threshold
                     and old.stock_cached > new.low_stock_threshold)
  execute function trg_push_low_stock();
```

Note the `when` clause: it fires only on the *crossing*, not on every update
while already below threshold. Combined with the `alerts_sent` dedupe, this is
belt and braces — and both are warranted, because the offline sync in §4 can
replay movements in ways that touch `stock_cached` repeatedly.

**(d) The morning digest.** `pg_cron` job at `30 20 * * *` UTC (= 06:30 AEST;
**note AEDT shifts this by an hour — either schedule in UTC and accept the
seasonal drift, or run the job hourly and gate on the Sydney local hour inside
the function. The second is more code and more correct**) calling a
`daily-digest` Edge Function.

**(e) Web fallback — recommended.** Push notification delivery is best-effort on
both platforms. For a **new order**, also send an email via **Resend** (free
tier: 3,000 emails/month, 100/day **[VERIFY]**) to the shop's address. Belt and
braces on the one notification where a miss costs a customer. This also gives
the owner a searchable record in a tool they already use.

---

## 6. Migration path

### 6.1 The data that actually needs migrating

Almost none. `SEED_PRODUCTS` in `js/app.js` is twelve demo items with invented
descriptions and stock levels. Any real stock figures live in the owner's head
and on the shelves, not in a browser.

**Do not build an elaborate localStorage export tool.** It would take a day and
migrate fictional data.

Instead:

**(a) Seed the twelve demo products as the starting catalogue.** They are real
product lines the shop actually sells (Daily Telegraph, Woman's Day,
That's Life Puzzler, Matchbox cars…). Convert `SEED_PRODUCTS` into a SQL seed
file with `legacy_id` preserved, `stock` set to **0**, and every item
`held = true`. The owner then does one guided stocktake in the app on day one,
which sets real numbers via `kind='count'` movements — and simultaneously
teaches them the app's core interaction. Two jobs, one task.

**(b) Provide a one-off export page as a safety net.** A single throwaway HTML
file — `migrate.html` — that the owner opens *once* in the browser where they've
been using the demo, which reads `localStorage` and produces a downloadable JSON
file. If it turns out they *have* been keeping real data there, you have it.
If not, you spent twenty minutes. Delete the file after cutover.

```js
// migrate.html — the whole thing
const dump = {
  products: JSON.parse(localStorage.getItem('kn.products') || '[]'),
  orders:   JSON.parse(localStorage.getItem('kn.orders')   || '[]'),
  exported: new Date().toISOString()
};
// → offer as a .json download; developer imports it with a Node script
```

**(c) Do not migrate credentials.** `kn.owner` holds a plaintext password
(`changeMe1234` by default). New accounts get new passwords set through Supabase
Auth. Never carry a plaintext password forward.

**(d) Do not migrate orders.** They are simulated. Archive the JSON; start
clean.

**(e) Openverse image URLs port as-is.** `image_url` and `image_credit` copy
straight into the new columns. Verify each URL still resolves during the import
(some Openverse-indexed hosts go away); where it 404s, null it out and the app's
generated category artwork takes over, exactly as the website already does.

### 6.2 Cutover sequence

**The governing rule: the owner must never, at any point, be without a working
way to change stock.** That means the old owner portal stays live and working
until the new app is proven in the owner's own hands. There is no big-bang
switch.

| Phase | Duration | What happens | How stock is managed |
|---|---|---|---|
| **0. Prep** | Week 0 | Supabase project (Sydney). Apply schema. Seed catalogue. **Start the Apple + Google enrolments now** — D-U-N-S and identity verification are the long pole (§7). | Old portal |
| **1. Backend live, site unchanged** | Week 1 | Deploy Supabase. Move the static site to Cloudflare Pages. Site still reads `localStorage`. Nothing user-visible changes. | Old portal |
| **2. Site reads Supabase (shadow)** | Week 2 | Deploy `js/api.js`. `shop.html`/`index.html` now read from the database. **`owner.html` still exists and still writes localStorage** — it is now decorative, but it is the fallback. Reservations still simulated. | **Developer edits stock via the Supabase dashboard on request** |
| **3. App to the owner's phone** | Weeks 3–4 | Internal build via TestFlight (iOS) and Play internal testing (Android). The owner uses it **alongside** the old portal for real. Collect the things that only surface in real use — the labels they misread, the flows that need one fewer tap. | **App + developer fallback** |
| **4. Reservations go live** | Week 5 | `cart.html` switches from simulated payment to real reservations via the Edge Function. Push notifications on. **This is the first irreversible step** — real customers can now place real orders. | **App** |
| **5. Old portal removed** | Week 6 | Delete `owner.html`. Remove the footer link and the demo banner. Only after the owner has independently managed a full week of stock in the app. | **App only** |
| **6. Store submission** | Weeks 5–8 | Submit to both stores. Note this runs *in parallel* with phases 4–5. | **App only** |

**Two safeguards that must be written into the plan, not assumed:**

1. **Phase 5 has an explicit gate, not a date.** The old portal is deleted when
   the owner says they're comfortable, not when the Gantt chart says week 6.
   Write the gate into the statement of work.

2. **The developer keeps Supabase dashboard access permanently** as the ultimate
   fallback for stock editing. If the app is broken on both phones at 5am, a
   phone call and a browser fixes it. State this explicitly in the handover
   document with a response-time expectation, so it is a known arrangement
   rather than an assumed favour.

**On store submission timing:** do not make the shop's ability to trade depend
on App Store approval. Phases 3–5 use TestFlight and Play internal testing,
neither of which requires public store approval. If Apple rejects the app under
4.2 (§7.3) and it takes three appeal rounds over six weeks, **the shop is
unaffected** — the owner is already using the app. This decoupling is the single
most important scheduling decision in the migration and it is why store
submission is last, not first.

**One caution on relying on TestFlight indefinitely:** TestFlight builds expire
after **90 days**, so the "just never ship to the store" strategy means a rebuild
and redistribution every quarter forever. Play internal testing does not expire
the same way. **[VERIFY both]** TestFlight is a bridge, not a destination.

---

## 7. App store submission

This section is where a small business app most often loses weeks. Read it
before writing any code, because two items on it (§7.1) have multi-week lead
times that are entirely outside your control.

### 7.1 Accounts, costs and — critically — lead times

| | Apple | Google |
|---|---|---|
| Programme | Apple Developer Program | Google Play Console |
| Cost | **US$99/year** (≈ A$149/yr **[VERIFY the AUD price]**) — recurring, and the app is **removed from sale** if it lapses | **US$25 one-time** |
| Individual/sole-trader enrolment | Allowed. Fast — often same day. App listed under the person's legal name. | Allowed |
| Organisation enrolment | Requires a **D-U-N-S number** and legal entity verification. App listed as "Knightsbridge Newsagency". | Organisation accounts require a **D-U-N-S number** **[VERIFY — Google's requirements here changed recently]** |
| D-U-N-S lead time | **Free from Dun & Bradstreet, but can take up to 30 days** | Same |
| Identity verification | 1–5 business days typically | Google requires ID/address verification; **allow 1–3 weeks** |

**Start these enrolments in week 0.** They are free or cheap, they are the
longest-lead item in the whole project, and nothing about them depends on the
code being finished.

**Decision to make early: individual or organisation?** Organisation gets you
"Knightsbridge Newsagency" as the seller name, which looks right, but costs a
D-U-N-S application. Individual is faster and lists the owner's personal legal
name publicly. For a shop app that only the owner uses, **individual enrolment
is the pragmatic choice** — nobody is browsing the store for it. If the app ever
becomes customer-facing, migrate then. **[VERIFY that Apple still permits
transferring apps between an individual and an organisation account — I believe
it does, but the process has conditions.]**

**One further wrinkle if you go organisation on Apple:** Apple's **Custom Apps**
distribution (via Apple Business Manager), which is genuinely the right
distribution channel for an internal business tool and bypasses public review
scrutiny entirely, requires an organisation account. That is a real argument in
the other direction. See §7.3.

**The Google Play 12-tester rule.** Personal developer accounts created from
late 2023 onward must run a closed test with **at least 12 testers for 14
continuous days** before applying for production access. **Organisation accounts
are exempt.** **[VERIFY — this policy has been revised at least once.]** For a
shop with two staff, finding twelve testers is a genuine obstacle. **This is a
strong reason to enrol on Google as an organisation**, even though individual is
the better call on Apple. The two decisions are independent — make them
independently.

### 7.2 Store listing assets

Budget half a day. Everything must come out of the three-colour palette.

- **App icon**: 1024×1024, no transparency, no rounded corners (the OS does
  that). A white `K` on `#E1251B`, or the shop's existing logo mark.
- **Screenshots**: iPhone 6.7" (1290×2796) and 6.5" — **[VERIFY the currently
  required device sizes; Apple revises this most years]**. Android needs a
  minimum of 2, at least 320px on the short edge.
- **Feature graphic** (Google only): 1024×500.
- **Description**: lead with what it does, plainly. "Manage stock, prices and
  online orders for Knightsbridge Newsagency."
- **Support URL** (required by Apple): a page on the shop's own site.
- **Privacy policy URL** (required by both, unconditionally): also on the shop's
  site. See §7.4.
- **Age rating**: 4+ / Everyone. No user-generated content, no ads, no
  in-app purchases.
- **Demo account**: §7.3.

### 7.3 Review risk — Guideline 4.2, and how to actually get through it

**This is the highest-probability failure in the project. Plan for a rejection.**

App Store Review Guideline **4.2 Minimum Functionality** says apps should offer
lasting value and not merely be a repackaged website or a thin utility. Guideline
**4.2.2** additionally targets apps that are "primarily marketing materials or
advertisements." An app whose entire audience is one shopkeeper is exactly the
profile a reviewer flags.

**Apple's likely responses, in descending order of probability:**

1. **Rejected under 4.2**, with the standard note suggesting the functionality
   would be better delivered as a web app.
2. **Rejected under 4.2.2/4.1** as a "single-company app", with a pointer to
   **Custom App distribution via Apple Business Manager** — which is Apple
   explicitly telling you it doesn't belong on the public store.
3. Approved without comment, because it is a functional business tool with real
   local data and offline behaviour.

Outcome 3 is entirely achievable, and here is how you make it likelier:

**(a) The app must not look like a website in a box.** These features, all of
which are in this spec anyway, are also the exact evidence a reviewer needs:

- **Offline operation** (§4) — impossible in a web page, and demonstrably native
- **Push notifications** (§5) — likewise
- **Biometric sign-in** (§3.4) — Face ID is a strong native signal
- **Camera capture** for product photos via `expo-image-picker` — add it
  specifically because it is a hardware capability
- **Barcode scanning** with `expo-camera`'s scanner to look up an item by its
  barcode. **This one is worth building for review reasons alone**, and it also
  happens to be the single most useful feature for someone counting magazines.
  It is unarguably native.
- A **home screen widget** or Live Activity showing today's order count would be
  further insurance, but is a meaningful build; hold it as an appeal card.

**(b) Give the reviewer a working demo account.** In App Store Connect's "App
Review Information", supply real credentials to a **separate seeded Supabase
account** with demo products, demo orders and a low-stock item already showing.
A reviewer who logs in and sees an empty screen rejects it in ninety seconds.
This is the most common avoidable rejection cause and it costs an hour to
prevent.

**(c) Write review notes that pre-empt the objection.** Two short paragraphs in
the review notes field, stating plainly: this is the stock-management tool for a
physical retail newsagency in Castle Hill, NSW; it works fully offline because
the shop's stockroom has no mobile reception; it uses the camera to scan
barcodes and Face ID to protect trading data; and the public website it feeds is
at `<url>`. Name the physical address. Reviewers respond to specificity.

**(d) If rejected, appeal before you rebuild.** Reply in Resolution Center
restating (c), and request a call — Apple's review team will phone you, and a
five-minute conversation resolves 4.2 disputes that three written rounds don't.
Only then consider the Custom App route.

**(e) The fallback that always works.** If Apple will not budge: **Apple Business
Manager Custom App** distribution. The app is distributed privately to the
shop's own organisation, is not publicly listed, and is reviewed against a
substantially lower bar because it is explicitly an internal tool. It requires
an organisation Apple Developer account (hence the D-U-N-S). **[VERIFY the
current Custom App requirements and whether ABM enrolment has an Australian
prerequisite beyond D-U-N-S.]**

**Google Play is materially easier.** There is no equivalent minimum-functionality
bar and single-business tools are routine. Expect approval, though review times
have become unpredictable — **budget up to 7 days for a first submission** rather
than the historic few hours.

**Honest recommendation to state to the owner up front:** *"There's a real chance
Apple pushes back on this, because they don't love apps built for one business.
It's usually solvable, but budget two to six weeks. Your shop won't be affected
either way — you'll already be using the app by then."* Setting that expectation
before submission is the difference between a manageable delay and a crisis.

### 7.4 Apple privacy nutrition labels

Declared in App Store Connect under App Privacy. For this app the honest
declaration is short — which is itself a selling point.

| Data type | Collected? | Linked to identity? | Tracking? | Purpose |
|---|---|---|---|---|
| Email address | **Yes** | Yes | No | App Functionality (sign-in) |
| Customer name / phone (from orders) | **Yes** | Yes | No | App Functionality |
| Crash data | **Yes** (Sentry) | **No** | No | App Functionality / Diagnostics |
| Performance data | Yes (Sentry) | No | No | Diagnostics |
| Photos | **No** | — | — | Camera images become a public product URL, not stored personal data — but declare if you store them in Supabase Storage |
| Location, contacts, advertising ID, browsing | **No** | — | — | Not collected |

Three specifics that catch people out:

- **Answer "Do you or your partners track users?" = No**, and mean it. Do not
  add Firebase Analytics, Meta SDK, or any attribution SDK. If you do, you
  trigger **App Tracking Transparency** and the `AppTrackingTransparency` prompt,
  which for this app would be absurd. Keeping analytics out is not just tidy —
  it removes an entire compliance surface.
- **Sentry must be configured not to send PII.** Set `sendDefaultPii: false` and
  scrub the user's email from event context. Otherwise "Crash data — not linked
  to you" becomes a false declaration.
- **Privacy manifests.** Since 2024 Apple requires a `PrivacyInfo.xcprivacy`
  declaring "required reason" API usage (file timestamps, user defaults, disk
  space, system boot time) and listing third-party SDKs. **Expo SDK 51+ generates
  this automatically** for its own modules, but you must verify that any
  non-Expo dependency you add is covered. **[VERIFY]**

**The privacy policy itself** must exist at a public URL before you can submit.
A one-page plain-English document on the shop's own site is sufficient. Note for
context: Australian businesses with annual turnover under **A$3 million** are
generally exempt from the Privacy Act 1988's Australian Privacy Principles
**[VERIFY — and note that reform to remove or narrow this small-business
exemption has been under active consideration, so check its current status]**.
The exemption does **not** remove Apple's and Google's own requirement for a
policy. Write one regardless. It is also simply the right thing to do when
you're holding customers' names and phone numbers.

**Account deletion (Guideline 5.1.1(v)).** Apps that let users *create* an
account must offer in-app account deletion. This app has **no self-signup** —
accounts are provisioned by the developer — which should place it outside the
requirement. **Reviewers do not always read it that way.** Cheapest insurance:
a "Delete my account" item in settings that opens a mailto/support link, plus
one line in the review notes stating that accounts cannot be created in-app.
**[VERIFY the current wording of 5.1.1(v) and its provisioned-account carve-out.]**

Also note: because there is no third-party social login, **Sign in with Apple
(4.8) is not triggered**. Adding "Sign in with Google" later would force you to
add Sign in with Apple too. Don't.

### 7.5 Google Play Data Safety

A separate form in Play Console, similar in substance but **not** auto-derived
from the Apple one — fill it in independently and keep the two consistent, as
inconsistency is a known audit trigger.

Declare:

- **Data collected:** Email address (account management, app functionality);
  Name and Phone number (app functionality — these are the *customer's*, entered
  by a third party through the website; the form has no perfect box for this, so
  declare it and explain in the description); Crash logs and Diagnostics.
- **Encrypted in transit:** **Yes** (TLS to Supabase throughout).
- **Users can request deletion:** **Yes** — and you must give a working URL or
  email that actually reaches someone.
- **Data shared with third parties:** **No.** Supabase, Expo and Sentry are
  processors, not recipients — but list them in the privacy policy.
- **Committed to the Play Families Policy:** No (not a children's app).

Also required in recent Play policy:

- **Target API level.** Play requires new apps to target a recent Android API
  level and raises the floor annually. Expo's SDK keeps pace, but **an app that
  is not rebuilt for two years will be pulled from the store.** Put an annual
  "rebuild and resubmit" reminder in the maintenance agreement. This is the most
  common way small business apps quietly die.
- **Photo and Video Permissions declaration** if you use `expo-image-picker`
  with broad media access. Use the **iOS limited photo library** / Android
  Photo Picker paths, or camera-only capture, and you can avoid the broad
  permission and its declaration form entirely. **Prefer camera-only.**

### 7.6 Ongoing obligations — the part that gets forgotten

| Obligation | Cadence | Consequence of missing |
|---|---|---|
| Apple Developer renewal | Annual, **US$99** | **App removed from sale**; push may stop |
| Android target API bump | Annual | App delisted for new installs |
| Expo SDK upgrade | ~Annual | Falls off supported builds |
| Privacy declarations review | On any dependency change | Store enforcement action |
| Renew expired iOS certificates | Handled by EAS | Build failures |

**Write these into the handover document with dates and put them in the shop's
calendar, not just the developer's.** The Apple renewal in particular: a lapsed
membership pulls the app and the owner will not know why.

---

## 8. Summary of costs

| | One-time | Annual | Notes |
|---|---|---|---|
| Google Play Console | US$25 | — | |
| Apple Developer Program | — | US$99 (≈A$149) | Recurring; app pulled if lapsed |
| Supabase | — | US$0 | Free tier; US$300/yr if Pro becomes warranted |
| Cloudflare Pages | — | US$0 | |
| Expo EAS (build/push/update) | — | US$0 | Free tier is ample at this cadence |
| Sentry | — | US$0 | |
| Domain (.com.au) | — | ~A$25 | If not already held |
| D-U-N-S number | Free | — | Up to 30 days lead time |
| **Total year 1** | | **≈ A$230–260** | |
| **Total year 2+** | | **≈ A$175** | |

Development effort, solo: **4–6 weeks** for app + backend + website changes,
plus 2–6 weeks of store-review calendar time running in parallel.

---

## 9. Open questions and flagged uncertainties

Consolidated so nothing marked **[VERIFY]** above gets lost.

**Must be confirmed before committing budget or schedule:**

1. Apple Developer Program price in **AUD** (Apple bills locally; US$99 is the
   US figure).
2. Whether Google Play's **12-testers-for-14-days** rule still applies to new
   personal accounts, and whether organisation accounts remain exempt. This
   materially changes the Google enrolment decision.
3. Whether Google Play still requires a **D-U-N-S** for organisation accounts.
4. Current **Supabase free tier** limits and the **inactivity-pause window**.
5. Current **Expo EAS free tier** build allowance and overage pricing.
6. Current **Apple Custom App / Apple Business Manager** requirements, and
   whether there is any Australia-specific prerequisite.
7. Current required **screenshot device sizes** for App Store Connect.
8. **TestFlight's 90-day build expiry** and the equivalent Play internal testing
   policy.
9. Whether **`@expo-google-fonts/atkinson-hyperlegible`** exists under that exact
   name; if not, bundle the TTFs directly with `expo-font` (the licence permits
   it — Atkinson Hyperlegible is under the SIL Open Font License).
10. Current status of the **Australian Privacy Act small-business exemption**
    (A$3M turnover threshold) — reform has been under consideration.
11. Whether **Postgres view `security_invoker`** semantics on the provisioned
    Supabase Postgres version require an explicit setting for the
    `public_products` RLS bypass to work as described.
12. Current **Openverse** rate limits, and whether an API key is now required.
13. Current wording of **Guideline 5.1.1(v)** and its provisioned-account
    carve-out.
14. **FCM legacy API shutdown** — I am confident this happened in mid-2024 and
    that FCM v1 + service account JSON is now mandatory, but confirm.

**Business decisions the owner must make:**

15. **Reserve-and-collect or real payments in v1?** This spec assumes
    reserve-and-collect (§0.3) and that assumption drives a lot of scope.
16. **One owner account or two?** §3.5 strongly recommends two.
17. **Which email address** is the account and recovery address — and can the
    owner definitely read mail at it on their phone today? Test this.
18. **Does the shop already own a domain**, and who controls the DNS?
19. **Who owns the Apple and Google accounts long-term** — the developer or the
    shop? Strongly recommend the shop, with the developer added as a user.
20. **Is there an ongoing maintenance agreement?** §7.6's annual obligations are
    not optional, and without a named person responsible the app has a
    predictable 18–24 month lifespan.

**Design risks I want to flag explicitly:**

21. **Clock skew** on the owner's phone breaks movement ordering (§4.4.1).
    Mitigated, not eliminated.
22. **Two simultaneous offline stocktakes** of the same product silently discard
    the earlier count (§4.4.1). Acceptable at this scale; document it.
23. **The developer is a single point of failure** for account recovery (§3.5,
    layer 4) and for the annual store obligations (§7.6). This is the largest
    non-technical risk in the project and it is not solved by anything in this
    document — it is solved by a written agreement.
24. **Apple 4.2 rejection** is the highest-probability schedule risk (§7.3).
    Mitigated by decoupling store approval from cutover (§6.2).

---

## 10. The alternative worth considering honestly

Before building any of this: **an installable PWA would deliver perhaps 80% of
this app's value at 30% of the cost and with zero store risk.** Service workers
give offline; the Web Push API now works on iOS 16.4+ for home-screen-installed
apps; IndexedDB gives local storage; and there is no Apple Developer fee, no
review, no annual API-level treadmill, and no D-U-N-S number.

What you genuinely lose: Face ID (WebAuthn is close but clunkier), reliable
background sync on iOS, barcode scanning quality, notification reliability on
iOS, and the "it's a real app" perception. iOS web push in particular requires
the user to have added the site to their home screen, and its reliability has
historically been weaker than native.

I am recommending the native app as specified, because the offline requirement
in §4.1 is severe, push reliability for new orders is a revenue-linked feature,
and a native app is what was asked for. But **if budget is the binding
constraint, the PWA is not a bad answer and it should be a conscious decision
rather than an unexamined one.** Raise it with the owner once, early, in these
terms — and then commit to whichever they choose.
