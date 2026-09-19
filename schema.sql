-- cwfqosp / cwfqosd shared Supabase schema
-- USA Free WiFi Tracker.
--
-- THIS PROJECT IS LIVE: cwfqosd/index.html and cwfqosp/index.html are already wired to the
-- shared "zwispqosdb" Supabase project (the same one the zwispqos/ISP-tracker family uses), and
-- the tables below are already created there. You do not need to run anything to get started.
--
-- IMPORTANT — what actually happened when this was set up (2026-09-19): the original version of
-- this file (see git history) assumed a brand-new project and included its own `admins` table
-- plus `is_admin()`/`has_write_access(p_site)` functions with an `id`-keyed admins schema. When
-- applied against the existing shared zwispqosdb project, that failed — `admins` already existed
-- there from the ISP-tracker family, but keyed on `user_id` (not `id`) and with extra break-glass
-- columns (`break_glass_eligible`, `break_glass_active`, `granted_by`). Rather than fork a second
-- admins table, cwfqosp now REUSES that existing table and its existing functions as-is. Only the
-- two sections below (wifi_qos_reports, wifi_status_reports) were actually created for this
-- project — `admins`, `is_admin()`, `has_write_access()`, and `admin_audit_log` already existed.
--
-- Practical consequences of reusing the shared admins table:
--   - Any admin bootstrapped for the ISP trackers (role + a row in `admins`) can also access
--     cwfqosp — it's the same table, not a separate one per site.
--   - `has_write_access(p_site)` on this project requires `role = 'global_admin' AND
--     break_glass_active = true`, OR `role = 'country_admin' AND p_site = any(scope)`. A
--     global_admin whose `break_glass_active` is false will see the cwfqosp app (is_admin() only
--     checks table membership) but Moderation deletes will silently fail at the RLS layer until
--     break_glass_active is flipped true for their row.
--   - cwfqosp/index.html queries `admins` by `.eq("user_id", ...)`, not `.eq("id", ...)`, and
--     writes to `admin_audit_log` using that table's real columns (`actor_user_id`, `site`), not
--     the `actor` column the original draft schema below assumed.
--
-- ============================================================================
-- SCENARIO A — this is what's actually live in zwispqosdb. Nothing to run; documented for
-- reference. If you ever point these apps at a different EXISTING zwispqos-family project, this
-- is the block to run there (it skips admins/functions/audit log, which that project already has).
-- ============================================================================

-- (already applied — included here only so this file matches what's live)

-- ============================================================================
-- SCENARIO B — reference only: if you ever point these apps at a brand-new, empty Supabase
-- project instead (fully independent of the zwispqos family), run the FULL schema below, which
-- creates its own id-keyed admins table and matching functions from scratch.
-- ============================================================================

-- ============================================================================
-- 1. Admins table + is_admin() — same model as the ISP-tracker family: privilege comes from
--    Supabase Auth + Row Level Security, never from hiding the anon key or the repo (the anon key
--    is meant to be public). A brand-new project starts with zero rows here — see cwfqosp/README.md
--    "Bootstrapping your own admin account" for how to add yourself.
-- ============================================================================

create table if not exists public.admins (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('viewer', 'country_admin', 'global_admin')),
  -- scope: which "site" values (currently just 'us') a country_admin may write to.
  -- Kept for parity with the ISP-tracker family's RBAC model even though this vertical only has
  -- one site today — a future 'ca'/'uk'/etc. sibling site would use this the same way they do.
  scope text[] not null default '{}',
  created_at timestamptz not null default now()
);

comment on table public.admins is 'Who may access cwfqosp. Bootstrap the first row manually via the Supabase dashboard (Table Editor) after your first login — see cwfqosp/README.md.';

alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from public.admins where id = auth.uid());
$$;

create or replace function public.has_write_access(p_site text)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.admins
    where id = auth.uid()
      and (role = 'global_admin' or (role = 'country_admin' and p_site = any(scope)))
  );
$$;

drop policy if exists "admins can read admin roster" on public.admins;
create policy "admins can read admin roster"
  on public.admins for select
  to authenticated
  using (is_admin());

-- ============================================================================
-- 2. wifi_qos_reports — star ratings + optional comment on a specific WiFi spot.
--    Equivalent role to the ISP-tracker family's qos_reports table, applied to a WiFi spot
--    instead of an ISP. osm_id is the spot's stable OpenStreetMap identifier (e.g. "node/123"),
--    since (unlike the ISP trackers) there's no hand-curated provider table to foreign-key against.
-- ============================================================================

create table if not exists public.wifi_qos_reports (
  id bigint generated always as identity primary key,
  site text not null default 'us',
  osm_id text not null,
  spot_name text not null,
  category text,
  lat double precision not null,
  lon double precision not null,
  search_location text,           -- the address/city/ZIP the reporter had searched, for context
  stars smallint not null check (stars between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index if not exists wifi_qos_reports_site_osm_idx on public.wifi_qos_reports (site, osm_id);
create index if not exists wifi_qos_reports_created_idx on public.wifi_qos_reports (created_at desc);

alter table public.wifi_qos_reports enable row level security;

drop policy if exists "public can submit ratings" on public.wifi_qos_reports;
create policy "public can submit ratings"
  on public.wifi_qos_reports for insert
  to anon, authenticated
  with check (site = 'us' and stars between 1 and 5);

drop policy if exists "public can read ratings" on public.wifi_qos_reports;
create policy "public can read ratings"
  on public.wifi_qos_reports for select
  to anon, authenticated
  using (true);

drop policy if exists "admin full access to ratings" on public.wifi_qos_reports;
create policy "admin full access to ratings"
  on public.wifi_qos_reports for all
  to authenticated
  using (has_write_access(site))
  with check (has_write_access(site));

-- ============================================================================
-- 3. wifi_status_reports — live status pill (live/partial/down/unconfirmed) on a spot.
--    Equivalent role to the ISP-tracker family's status_reports table.
-- ============================================================================

create table if not exists public.wifi_status_reports (
  id bigint generated always as identity primary key,
  site text not null default 'us',
  osm_id text not null,
  spot_name text not null,
  lat double precision not null,
  lon double precision not null,
  status text not null check (status in ('live', 'partial', 'down', 'unconfirmed')),
  created_at timestamptz not null default now()
);

create index if not exists wifi_status_reports_site_osm_idx on public.wifi_status_reports (site, osm_id);
create index if not exists wifi_status_reports_created_idx on public.wifi_status_reports (created_at desc);

alter table public.wifi_status_reports enable row level security;

drop policy if exists "public can submit status reports" on public.wifi_status_reports;
create policy "public can submit status reports"
  on public.wifi_status_reports for insert
  to anon, authenticated
  with check (site = 'us');

drop policy if exists "public can read status reports" on public.wifi_status_reports;
create policy "public can read status reports"
  on public.wifi_status_reports for select
  to anon, authenticated
  using (true);

drop policy if exists "admin full access to status reports" on public.wifi_status_reports;
create policy "admin full access to status reports"
  on public.wifi_status_reports for all
  to authenticated
  using (has_write_access(site))
  with check (has_write_access(site));

-- ============================================================================
-- 4. admin_audit_log — optional but cheap; matches the ISP-tracker family's break-glass/RBAC
--    audit trail. Not wired up to any UI in cwfqosp v0.1.0 yet (see CHANGELOG scope cuts) but the
--    table exists now so a later admin action (e.g. deleting a bad report) has somewhere to log to
--    without a second migration.
-- ============================================================================

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor uuid references auth.users(id),
  action text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_audit_log enable row level security;

drop policy if exists "admins can read audit log" on public.admin_audit_log;
create policy "admins can read audit log"
  on public.admin_audit_log for select
  to authenticated
  using (is_admin());

drop policy if exists "admins can write audit log" on public.admin_audit_log;
create policy "admins can write audit log"
  on public.admin_audit_log for insert
  to authenticated
  with check (is_admin());
