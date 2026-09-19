# cwfqosp — USA Free WiFi Tracker (privileged backend)

The privileged half of the `cwfqosd`/`cwfqosp` pair — same model as this project's ISP-quality
trackers: **`cwfqosd` = public demo, shared access; `cwfqosp` = backend connected to a privileged
tier for analytics, moderation, and exports.** Unlike `cwfqosd`, this app has no local-demo-mode
fallback — its entire point is seeing everyone's reports, which local-only storage can't provide —
so it does nothing useful until a Supabase project is actually connected.

## Setup — status: done, live as of 2026-09-19

Both apps are already wired up and connected. Nothing below needs to be re-run for the current
deployment — this section is kept as a record of what happened and as a reference if you ever set
this up again against a different project.

1. **Project used: the existing shared `zwispqosdb` Supabase project**, the same one the
   `*ispqos*` ISP-tracker family uses (Ed chose to reuse it rather than create a dedicated one,
   since the table names don't collide). `SUPABASE_CONFIG` in both `index.html` files already
   points at it.
2. **Migration applied.** Only `wifi_qos_reports` and `wifi_status_reports` were created (with
   RLS: public insert + read, admin full access via the existing `has_write_access(site)`).
   `admins`, `is_admin()`, `has_write_access()`, and `admin_audit_log` were **not** recreated —
   they already existed in this project from the ISP-tracker family. See the big comment block at
   the top of `schema.sql` for the full story, including a schema mismatch that was caught and
   fixed (this project's `admins` table is keyed on `user_id`, not `id`, and has extra break-glass
   columns) — `cwfqosp/index.html` was updated to match the real column names.
3. **Admin access: already working, no bootstrap step needed.** Ed's Supabase Auth account
   (`edmundondo@gmail.com`) already has a `global_admin` row in this shared `admins` table with
   `break_glass_active = true` from earlier ISP-tracker work — so signing in to `cwfqosp/index.html`
   with that same account gives full admin access immediately, including Moderation deletes (which
   require `break_glass_active = true`, not just `role = 'global_admin'`, per this project's
   `has_write_access()` definition).
4. **Commit and push.** Already done — if using GitHub Pages, it redeploys automatically on the
   next push.

### If you ever point these apps at a different project instead

- **Reusing another existing zwispqos-family project**: run only the `wifi_qos_reports` /
  `wifi_status_reports` block from `schema.sql` (Scenario A) — skip `admins`/functions/audit log,
  they'll already be there, and adjust `index.html`'s admin queries to match that project's real
  `admins` schema (check with the same `information_schema.columns` query used when this was set
  up, don't assume `user_id` vs `id`).
- **Starting from a brand-new, fully independent Supabase project**: run the full Scenario B block
  in `schema.sql`, which creates its own `id`-keyed `admins` table and functions from scratch —
  then follow the original bootstrap steps (create account, insert an `admins` row manually via
  Table Editor with `role = 'global_admin'`).

## What's here (v0.1.0)

- **Overview**: total ratings, average stars, total status reports, "down" report count, and the
  15 most-reported spots with their average rating and latest status.
- **Moderation**: a flat, chronological table of every rating and status report, each with a
  Delete button (writes an `admin_audit_log` row on every delete).
- **Export**: ratings CSV, status-reports CSV, and a print/Save-as-PDF summary — all reserved for
  this privileged tier, never the public demo, per the family convention.
- Password-based Supabase Auth, `admins` table + `is_admin()`/`has_write_access()` RLS functions,
  same architecture as `zwispqosp`'s RBAC model (`viewer`/`country_admin`/`global_admin` roles,
  `scope` for country-scoped write access — currently moot with only one site, `'us'`, but there
  from day one in case a sibling site is ever added the same way the ISP-QoS family grew from one
  country to six).

## Scope cuts vs. the ISP-tracker family's admin app (documented, not silent gaps)

- **No breadcrumb Drill-down Explorer.** The ISP trackers drill City → Area → ISP because their
  data has that fixed hierarchy from a hand-curated `PROVIDER_DIRECTORY`. This vertical's spots come
  from live OpenStreetMap queries with no fixed city/area list to hang a breadcrumb on — Moderation
  and Overview are flat tables instead, same as how the ISP admin app already keeps its own
  no-fixed-geography tables flat on purpose.
- **No inline per-spot benchmark report** (the ISP trackers' "free teaser, paid full report" funnel
  piece) — not built for this vertical yet.
- **No RBAC/break-glass UI** beyond the `role`/`scope` columns and `has_write_access()` existing in
  the schema — no break-glass toggle, no audit-log viewer UI (the table exists and is written to on
  every delete; reading it back is a Table Editor query for now, not an in-app tab).
- **No language chips / i18n.**
- **EPUB export** — the ISP admin app has one (via JSZip); not built here. CSV + print-to-PDF cover
  the same "get the data out" need at much lower complexity for a v1.
- **Google/passkey sign-in** — password-only for now, same bootstrap-first constraint as the ISP
  admin app (Google/passkey can only be *linked* to an account that already has a session).

## Files

- `index.html` — the admin app.
- `schema.sql` — the Postgres/Supabase migration (see "Run the migration" above).
- `README.md` — this file.
- `CHANGELOG.md`

## Related

See `cwfqosd` (the public demo for this pair) and the `bpqos`/`ispqos` skills for the reusable
architecture this was built from.
