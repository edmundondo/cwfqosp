# Changelog

All notable changes to `cwfqosp` are documented here, in the
[Keep a Changelog](https://keepachangelog.com/) style already used across the `*ispqos*` family.

## [0.2.0] - 2026-09-19

### Changed
- Connected to the shared `zwispqosdb` Supabase project (`SUPABASE_CONFIG` wired up). Reused the
  project's existing `admins` / `is_admin()` / `has_write_access()` / `admin_audit_log` instead of
  creating a second, conflicting set — only `wifi_qos_reports` and `wifi_status_reports` were newly
  created.
- Fixed `index.html` to query `admins` by `user_id` (not `id`) and write `admin_audit_log` using
  its real columns (`actor_user_id`, `site`), matching this project's actual schema — caught when
  the original `id`-keyed migration failed against the existing table.
- `schema.sql` rewritten to document both the reused-shared-project path (what's actually live) and
  the from-scratch path (for a brand-new, independent project).

### Known limitation carried over
- `has_write_access()` on this shared project requires `break_glass_active = true` for
  `global_admin`, not just the role — an admin bootstrapped elsewhere without break-glass active
  will see the app but Moderation deletes will fail at the RLS layer. Ed's own account already has
  `break_glass_active = true`.

## [0.1.0] - 2026-09-19

### Added
- Initial build: privileged admin app for `cwfqosd`, gated by Supabase Auth + Row Level Security
  (`admins` table, `is_admin()`/`has_write_access()`, `viewer`/`country_admin`/`global_admin` roles).
- Overview tab: total ratings, average stars, total status reports, "down" report count, top 15
  most-reported spots.
- Moderation tab: flat chronological table of all reports with per-row delete (audit-logged to
  `admin_audit_log`).
- Export tab: ratings CSV, status-reports CSV, print/Save-as-PDF summary — reserved for this
  privileged tier only, per the family convention.
- `schema.sql`: `admins`, `wifi_qos_reports`, `wifi_status_reports`, `admin_audit_log`, all RLS-
  enabled, additive and safe to run against a new or the existing shared Supabase project.
- `SITE_ID = "us"`, grep-verified against this repo (per the family's hard-won `SITE_ID`-mislabeling
  lesson).

### Scope cuts (documented explicitly — see README for the full list and why)
- No breadcrumb Drill-down Explorer (flat tables instead — no fixed city/area hierarchy exists for
  this vertical's live-queried data).
- No inline per-spot benchmark/teaser report.
- No RBAC break-glass UI or in-app audit-log viewer (table exists, written to; no UI yet).
- No language chips / i18n.
- No EPUB export (CSV + print-to-PDF only).
- Password-only sign-in (no Google/passkey linking yet).

### Known limitation
- This schema was reviewed statically but could not be executed against a live Postgres instance in
  the session that built it (no root access to install `postgresql`, no network path to a portable
  Postgres binary). Run it in Supabase's own SQL Editor first and treat any error it reports as
  authoritative.
