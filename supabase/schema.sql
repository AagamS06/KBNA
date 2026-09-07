-- ============================================================================
-- Knightsbridge Newsagency — Supabase schema (v1)
--
-- Apply once in the Supabase SQL Editor. Safe to re-run (idempotent).
--
-- Two sections:
--   1. LOGIN     — staff_accounts, hard-capped at 5, with SMS-notify phone
--   2. PRODUCTS  — products, stock_movements ledger, orders, order_items
--
-- The website reads `public_products` with the anon key; everything writeable
-- is locked to signed-in staff via RLS.
--
-- After running this file, complete the post-install steps at the bottom
-- (turn off public sign-ups, seed staff via Auth → Users, insert their
-- staff_accounts rows).
-- ============================================================================

create extension if not exists "pgcrypto";

-- ============================================================================
-- 1. LOGIN
-- ============================================================================

-- Supabase Auth handles email/password. This row adds a display name, an
-- SMS phone number (E.164 format so the Edge Function can just dial it),
-- and an opt-in flag. Keyed 1:1 to auth.users.
create table if not exists staff_accounts (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text        not null check (length(display_name) between 1 and 60),
  phone_e164   text        check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),  -- e.g. +61412345678
  sms_notify   boolean     not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Hard cap: max 5 staff. Any INSERT past the cap is rejected. Deleting a
-- row frees a slot.
create or replace function trg_staff_cap() returns trigger
language plpgsql as $$
begin
  if (select count(*) from staff_accounts) >= 5 then
    raise exception 'Staff account limit reached (5).';
  end if;
  return new;
end $$;

drop trigger if exists staff_accounts_cap on staff_accounts;
create trigger staff_accounts_cap
  before insert on staff_accounts
  for each row execute function trg_staff_cap();

-- ============================================================================
-- 2. PRODUCTS
-- ============================================================================

-- Attributes only. `stock_cached` is DERIVED from the ledger below — never
-- write to it directly; the trigger recomputes it on every stock movement.
create table if not exists products (
  id                   uuid primary key default gen_random_uuid(),
  name                 text        not null check (length(name) between 1 and 120),
  description          text        not null default '',
  price_cents          integer     not null check (price_cents >= 0),
  low_stock_threshold  integer     not null default 3 check (low_stock_threshold >= 0),
  tag                  text        not null,               -- 'Paper', 'Cards', 'Gifts', ...
  active               boolean     not null default true,  -- soft delete
  held                 boolean     not null default false, -- auto-hidden when low
  image_url            text,
  stock_cached         integer     not null default 0,     -- DERIVED
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid references auth.users(id)
);

create index if not exists products_active_idx on products (active) where active;
create index if not exists products_tag_idx    on products (tag);

-- Append-only stock ledger. Every count/sale/delivery/waste/adjust lands
-- here; stock_cached is rebuilt from the most recent 'count' + every delta
-- since. That makes offline edits and race conditions safe.
create table if not exists stock_movements (
  id               uuid primary key default gen_random_uuid(),
  product_id       uuid not null references products(id) on delete cascade,
  kind             text not null check (kind in ('count','sale','delivery','waste','adjust')),
  delta            integer,          -- null for 'count'
  counted_to       integer,          -- non-null only for 'count'
  occurred_at      timestamptz not null,
  recorded_at      timestamptz not null default now(),
  source           text not null check (source in ('web_admin','web_order','system')),
  order_id         uuid,
  note             text,
  idempotency_key  text not null unique,
  created_by       uuid references auth.users(id)
);

create index if not exists sm_product_time_idx on stock_movements (product_id, occurred_at desc);

-- Reservations from the website. Payment happens at the counter, so there's
-- no payment_status here — just the collection lifecycle.
create table if not exists orders (
  id             uuid primary key default gen_random_uuid(),
  reference      text unique not null,          -- 'KN-4821' style
  customer_name  text,
  customer_phone text,
  customer_email text,
  status         text not null default 'pending'
                 check (status in ('pending','ready','collected','cancelled')),
  total_cents    integer not null,
  note           text,
  created_at     timestamptz not null default now(),
  ready_at       timestamptz,
  collected_at   timestamptz
);

create table if not exists order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  product_id   uuid not null references products(id),
  name_at_time text    not null,     -- snapshot: name mustn't change retroactively
  price_cents  integer not null,     -- snapshot: honour price at reservation
  qty          integer not null check (qty > 0)
);

-- Web-push subscriptions for the dashboard's "new order" alert (Phase 4).
-- One row per browser per staff account.
create table if not exists push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- STOCK RECALC — rebuild stock_cached whenever the ledger changes
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
    base_at  := '-infinity'::timestamptz;
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
-- AUTO-HOLD — hide at/below the alert level, release when restocked
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
-- PUBLIC VIEW — the only thing the website's anon key can read
-- ============================================================================
create or replace view public_products as
select id, name, description, price_cents,
       stock_cached as stock,
       low_stock_threshold, tag, held, image_url
from products
where active;

grant select on public_products to anon;
-- Postgres 15+: pin the view to run with the definer's rights (anon can't
-- read the base products table thanks to the RLS below).
alter view public_products set (security_invoker = off);

-- ============================================================================
-- ROW LEVEL SECURITY — the real security model. Get this wrong and the anon
-- key shipped in the website becomes a write-capable database key.
-- ============================================================================
alter table staff_accounts     enable row level security;
alter table products           enable row level security;
alter table stock_movements    enable row level security;
alter table orders             enable row level security;
alter table order_items        enable row level security;
alter table push_subscriptions enable row level security;

-- Anon: NOTHING direct. All customer reads go via public_products.
revoke all on staff_accounts, products, stock_movements, orders,
              order_items, push_subscriptions from anon, public;

-- Staff can read/update their OWN profile row, and read everyone's names
-- (so the admin dashboard can list them).
drop policy if exists staff_read_self   on staff_accounts;
drop policy if exists staff_update_self on staff_accounts;
drop policy if exists staff_read_all    on staff_accounts;
create policy staff_read_self   on staff_accounts for select to authenticated using (user_id = auth.uid());
create policy staff_update_self on staff_accounts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy staff_read_all    on staff_accounts for select to authenticated using (true);

-- Any signed-in staff = full control of the shop's products + stock.
drop policy if exists staff_all_products  on products;
drop policy if exists staff_all_movements on stock_movements;
create policy staff_all_products  on products        for all to authenticated using (true) with check (true);
create policy staff_all_movements on stock_movements for all to authenticated using (true) with check (true);

-- Orders are inserted by an Edge Function ONLY (never by the browser using
-- the anon key — otherwise a customer could reserve 10,000 papers with
-- total_cents = 0). Staff read + advance status.
drop policy if exists staff_read_orders      on orders;
drop policy if exists staff_update_orders    on orders;
drop policy if exists staff_read_order_items on order_items;
create policy staff_read_orders      on orders      for select to authenticated using (true);
create policy staff_update_orders    on orders      for update to authenticated using (true) with check (true);
create policy staff_read_order_items on order_items for select to authenticated using (true);

-- Each staff sees only their own push subscriptions.
drop policy if exists own_push_subs on push_subscriptions;
create policy own_push_subs on push_subscriptions
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Search-path hardening on trigger functions (defence-in-depth).
alter function trg_staff_cap()    set search_path = pg_catalog, public;
alter function recalc_stock(uuid) set search_path = pg_catalog, public;
alter function trg_recalc_stock() set search_path = pg_catalog, public;
alter function trg_auto_hold()    set search_path = pg_catalog, public;

-- ============================================================================
-- POST-INSTALL CHECKLIST (do these in the Supabase Studio UI)
-- ============================================================================
-- 1. Authentication → Providers → Email → turn OFF "Enable sign ups".
--    Staff accounts get created by you, not by anyone with the URL.
-- 2. Authentication → Users → Add user (email + password) for each staff
--    member (up to 5). Copy each user's UUID.
-- 3. SQL Editor — insert the profile row for each user:
--
--      insert into staff_accounts (user_id, display_name, phone_e164)
--      values ('<paste the auth user id here>', 'Aagam', '+61412345678');
--
-- 4. Add products either through the admin dashboard once it's built, or
--    directly:
--
--      insert into products (name, description, price_cents, tag)
--      values ('Daily Telegraph', 'Weekday edition', 380, 'Paper');
--
-- 5. IMPORTANT: the service_role key (Project Settings → API) bypasses RLS.
--    Never ship it in the website or the admin JS. Its only homes are
--    Supabase Edge Functions and GitHub Actions secrets.
