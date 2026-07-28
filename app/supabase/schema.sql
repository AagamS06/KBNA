-- ============================================================================
-- Knightsbridge Newsagency — Supabase schema
-- Apply in the Supabase SQL editor (project region: ap-southeast-2 / Sydney).
--
-- This is the server side of the app's ShopRepository. It mirrors the local
-- sqflite schema the owner app runs on, so the two stay in lockstep:
--   * products         — attributes + a DERIVED stock_cached (never written to
--                        directly; a trigger recomputes it from the ledger)
--   * stock_movements  — the APPEND-ONLY ledger that stock_cached is built from
--   * orders/order_items — reservations placed on the website
--   * public_products  — the read-only VIEW the static website fetches
--
-- The design (ledger + trigger recompute + auto-hold) is 01-architecture.md
-- §2.4/§2.8; the app's local recompute in local_repository.dart reproduces it
-- so offline conflict resolution is union-of-movements + recompute (§4.4.1).
-- Written for a 1–2 user shop: any authenticated user is "the owner".
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------- products: attributes only; stock_cached is derived --------------
create table if not exists products (
  id                   uuid primary key default gen_random_uuid(),
  legacy_id            integer,                     -- the 1..12 ids from the seed
  name                 text        not null check (length(name) between 1 and 120),
  description          text        not null default '',
  price_cents          integer     not null check (price_cents >= 0),
  low_stock_threshold  integer     not null default 3 check (low_stock_threshold >= 0),
  tag                  text        not null,
  active               boolean     not null default true,   -- soft delete
  held                 boolean     not null default false,  -- hidden from customers
  image_url            text,
  image_credit         jsonb,                       -- Openverse licence block, verbatim
  barcode              text,                        -- scanner lookup (app addition)
  stock_cached         integer     not null default 0,       -- DERIVED. Never write directly.
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid references auth.users(id)
);

create index if not exists products_active_idx  on products (active) where active;
create index if not exists products_tag_idx     on products (tag);
create index if not exists products_barcode_idx on products (barcode) where barcode is not null;

-- ---------- stock_movements: the append-only truth about stock --------------
-- kind = 'count'    -> a stocktake. counted_to is absolute; delta ignored.
-- kind = 'sale'     -> an order took units. delta is negative.
-- kind = 'delivery' -> stock arrived. delta is positive.
-- kind = 'waste'    -> damaged / returned. delta is negative.
-- kind = 'adjust'   -> a manual correction.
create table if not exists stock_movements (
  id               uuid primary key default gen_random_uuid(),
  product_id       uuid not null references products(id) on delete cascade,
  kind             text not null check (kind in ('count','sale','delivery','waste','adjust')),
  delta            integer,          -- null for 'count'
  counted_to       integer,          -- non-null only for 'count'
  occurred_at      timestamptz not null,   -- CLIENT wall-clock time of the action
  recorded_at      timestamptz not null default now(),  -- server receipt time (pull cursor)
  source           text not null check (source in ('app','web_order','system')),
  order_id         uuid,
  note             text,
  idempotency_key  text not null unique,   -- client-generated; makes retry safe (§4.3)
  created_by       uuid references auth.users(id)
);

create index if not exists sm_product_time_idx on stock_movements (product_id, occurred_at desc);
create index if not exists sm_recorded_idx     on stock_movements (recorded_at);

-- ---------- orders: reservations from the website ---------------------------
create table if not exists orders (
  id             uuid primary key default gen_random_uuid(),
  reference      text unique not null,          -- human-readable, e.g. 'KN-4821'
  customer_name  text,
  customer_phone text,
  customer_email text,
  status         text not null default 'pending'
                 check (status in ('pending','ready','collected','cancelled')),
  total_cents    integer not null,
  payment_method text not null default 'Reserve',
  payment_status text not null default 'unpaid'  -- room for phase 2
                 check (payment_status in ('unpaid','paid','refunded')),
  payment_ref    text,
  note           text,
  created_at     timestamptz not null default now(),
  collected_at   timestamptz
);

create table if not exists order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  product_id   uuid not null references products(id),
  name_at_time text    not null,     -- snapshot: name must not change retroactively
  price_cents  integer not null,     -- snapshot: honour the price shown at reservation
  qty          integer not null check (qty > 0)
);

-- ---------- devices: where to send a push (FCM/APNs, wired later) ------------
create table if not exists devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  push_token  text unique not null,
  platform    text not null check (platform in ('ios','android')),
  last_seen   timestamptz not null default now()
);

-- ---------- alerts_sent: dedupe so an alert fires once, not on every write ---
create table if not exists alerts_sent (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,          -- 'low_stock' | 'new_order'
  subject_id  uuid not null,          -- product id or order id
  sent_at     timestamptz not null default now()
);
create unique index if not exists alerts_dedupe_idx
  on alerts_sent (kind, subject_id, (date_trunc('day', sent_at)));

-- ============================================================================
-- Derived stock: stock_cached is maintained by a trigger, never by app code.
-- Baseline = the most recent stocktake; then every later non-count movement is
-- re-applied. Result is independent of the order movements ARRIVE in — the
-- CRDT-shaped guarantee that makes offline sync correct (§2.4 / §4.4.1).
-- ============================================================================
create or replace function recalc_stock(p_product uuid) returns void
language plpgsql as $$
declare
  base_at  timestamptz;
  base_qty integer;
  result   integer;
begin
  select occurred_at, counted_to into base_at, base_qty
  from stock_movements
  where product_id = p_product and kind = 'count'
  order by occurred_at desc limit 1;

  if base_at is null then
    base_at := '-infinity'::timestamptz;
    base_qty := 0;
  end if;

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

drop trigger if exists stock_movements_recalc on stock_movements;
create trigger stock_movements_recalc
  after insert or update or delete on stock_movements
  for each row execute function trg_recalc_stock();

-- ============================================================================
-- Auto-hold: hide at/below the alert level; auto-release once restocked.
-- Preserves store.fulfilOrder() from the old website (§2.8). Runs no matter
-- whether stock moved from an online order or an offline edit that later synced.
-- ============================================================================
create or replace function trg_auto_hold() returns trigger
language plpgsql as $$
begin
  if new.stock_cached <= new.low_stock_threshold and not new.held then
    new.held := true;
  elsif new.stock_cached > new.low_stock_threshold and old.held
        and old.stock_cached <= old.low_stock_threshold then
    new.held := false;
  end if;
  return new;
end $$;

drop trigger if exists products_auto_hold on products;
create trigger products_auto_hold
  before update of stock_cached on products
  for each row execute function trg_auto_hold();

-- ============================================================================
-- The view the website reads. Never let anon read `products` directly (it has
-- updated_by and internal fields). Shaped exactly like the old product object
-- so js/app.js's productCardHTML() needs no change (§2.5).
-- ============================================================================
create or replace view public_products as
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

-- ============================================================================
-- Row Level Security. RLS is the entire security model — get it wrong and the
-- anon key ships a write-capable database to the internet (§2.6).
-- ============================================================================
alter table products        enable row level security;
alter table stock_movements enable row level security;
alter table orders          enable row level security;
alter table order_items     enable row level security;
alter table devices         enable row level security;
alter table alerts_sent     enable row level security;

-- Public (anon): NOTHING. Not even select. The website reads the VIEW only,
-- which runs with the definer's rights via the grant above.
-- NOTE: on newer Postgres a view defaults to security_invoker; if anon can't
-- read public_products, set `alter view public_products set (security_invoker = off);`
-- (verify against your provisioned Postgres version — 01-architecture.md §2.6).

-- Owner (any authenticated user — a 1–2 person shop): full control of the shop.
drop policy if exists owner_all_products on products;
create policy owner_all_products on products
  for all to authenticated using (true) with check (true);

drop policy if exists owner_all_movements on stock_movements;
create policy owner_all_movements on stock_movements
  for all to authenticated using (true) with check (true);

-- Orders are never inserted by the browser (a customer could set total to 0 or
-- reserve 10,000 papers). Creation goes through the create-reservation Edge
-- Function (§2.7). The app only reads and advances an order's status.
drop policy if exists owner_read_orders on orders;
create policy owner_read_orders on orders
  for select to authenticated using (true);
drop policy if exists owner_update_orders on orders;
create policy owner_update_orders on orders
  for update to authenticated using (true) with check (true);

drop policy if exists owner_read_order_items on order_items;
create policy owner_read_order_items on order_items
  for select to authenticated using (true);

drop policy if exists own_devices on devices;
create policy own_devices on devices
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- alerts_sent is written only by the server (service role bypasses RLS); no
-- authenticated policy is granted, so it is invisible to the app.

-- ============================================================================
-- Defence in depth. RLS is the primary control, but revoke table-level grants
-- from anon/public as well, so a future policy mistake can't silently expose a
-- base table. The website only ever touches the view.
-- ============================================================================
revoke all on products        from anon, public;
revoke all on stock_movements from anon, public;
revoke all on orders          from anon, public;
revoke all on order_items     from anon, public;
revoke all on devices         from anon, public;
revoke all on alerts_sent     from anon, public;

-- The public view must read `products` with the DEFINER's rights, not the
-- anon caller's (who is denied above). On PostgreSQL 15+ views default to
-- security_invoker = true, which would make anon's read fail — pin it off.
-- (Harmless on older Postgres that lacks the option; drop this line there.)
alter view public_products set (security_invoker = off);

-- Pin a safe search_path on the trigger functions so a planted object in a
-- writable schema can't shadow a built-in they call (search-path hijack).
alter function recalc_stock(uuid)  set search_path = pg_catalog, public;
alter function trg_recalc_stock()  set search_path = pg_catalog, public;
alter function trg_auto_hold()     set search_path = pg_catalog, public;

-- ============================================================================
-- Reminder: disable public sign-ups (Authentication → Providers → Email →
-- "Enable sign ups" OFF) and provision the two owner accounts by hand (§3.2).
-- Also: keep the SERVICE ROLE key server-side only (Edge Functions / the
-- lottery-style Actions), NEVER in the app or the website — it bypasses RLS.
-- The app ships only the ANON key, which these policies make safe to expose.
-- ============================================================================
