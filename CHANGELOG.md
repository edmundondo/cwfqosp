# Changelog

All notable changes to `cwfqosp` are documented here, in the
[Keep a Changelog](https://keepachangelog.com/) style already used across the `*ispqos*` family.

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
