# cwfqosp — USA Free WiFi Tracker (privileged backend)

The privileged half of the `cwfqosd`/`cwfqosp` pair — same model as this project's ISP-quality
trackers: **`cwfqosd` = public demo, shared access; `cwfqosp` = backend connected to a privileged
tier for analytics, moderation, and exports.** Unlike `cwfqosd`, this app has no local-demo-mode
fallback — its entire point is seeing everyone's reports, which local-only storage can't provide —
so it does nothing useful until a Supabase project is actually connected.

## Setup

1. **Create a Supabase project.** Free tier at [supabase.com](https://supabase.com), no credit card
   required. You can reuse this project for both `cwfqosd` and `cwfqosp` (they need the same
   `SUPABASE_CONFIG`) — or, if you'd rather keep this vertical fully separate from the
   `*ispqos*` ISP-tracker family's Supabase project, create a brand-new one. Either works: this
   schema's table names (`wifi_*`) don't collide with that family's (`qos_reports`/`status_reports`/
   etc.), so it's also safe to run against that same shared project if you'd prefer one Supabase
   project for everything.
2. **Run the migration.** Open **SQL Editor → New query** in the Supabase dashboard, paste in the
   full contents of `schema.sql`, and run it. This creates `admins`, `wifi_qos_reports`,
   `wifi_status_reports`, and `admin_audit_log`, each with Row Level Security enabled — public can
   insert and read reports, only admins can moderate or delete.
   - **A note on how this was verified**: this SQL was reviewed statically (balanced
     parens/quotes/`$$` blocks, correct `INSERT`-policy-uses-`WITH CHECK`-only /
     `SELECT`-policy-uses-`USING`-only rules) but this session had no way to actually execute it
     against a real Postgres instance (no root access to install `postgresql` locally, and the
     sandbox's network allowlist blocks fetching a portable Postgres binary). Supabase's own SQL
     Editor will surface any real syntax error immediately and clearly if one slipped through — run
     it there first, and if it errors, that's the thing to fix, not evidence this README is wrong.
3. **Get your API credentials.** **Project Settings → API**, copy the **Project URL** and the
   **anon public** key (safe to ship client-side — RLS is what actually enforces permissions, same
   principle as the rest of this project's family).
4. **Wire up both apps.** Open this file's `index.html` and `cwfqosd/index.html`, find the
   `SUPABASE_CONFIG` object near the top of each `<script>` block, and paste in the same Project URL
   and anon key in both.
5. **Create your own login.** Open `cwfqosp/index.html` in a browser, use the "Create account" form
   (password sign-in — this bootstraps a normal Supabase Auth user, not an admin yet).
6. **Bootstrap your own admin account.** In the Supabase dashboard, **Table Editor → admins →
   Insert row**: `id` = your new user's UUID (find it under **Authentication → Users**), `role` =
   `global_admin`, `scope` = `{}` (unused for `global_admin`, only meaningful for `country_admin`).
   Reload `cwfqosp/index.html` and sign in — you should now see the full admin app.
7. **Commit and push.** If using GitHub Pages, it redeploys automatically.

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
