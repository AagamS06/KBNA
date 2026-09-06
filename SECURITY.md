# Security policy

## Reporting a vulnerability

If you find a security issue in the Knightsbridge Newsagency website (or the
owner admin area under `web-design/admin/`), please report it privately —
do **not** open a public GitHub issue.

- **Email:** owner@knightsbridgenews.com.au
- Include steps to reproduce and, if you can, the impact.
- We aim to acknowledge within a few business days.

Please give us reasonable time to fix an issue before disclosing it publicly.
We won't pursue action against good-faith research that avoids privacy
violations, data destruction, and service disruption.

## Where the security controls live

| Area | Documented in |
|---|---|
| Website (CSP, headers, HTTPS, `security.txt`) | [`web-design/HOSTING-SECURITY.md`](web-design/HOSTING-SECURITY.md) |
| Backend authorisation (Row Level Security) | [`_archive/app/supabase/schema.sql`](_archive/app/supabase/schema.sql) — schema is being reused for the web admin area |
| Retired Flutter app (reference only) | [`_archive/app/SECURITY.md`](_archive/app/SECURITY.md) |

## Handled by design

- No password or secret ships in the website or app source. The site is
  read-only; the app carries only the Supabase **anon** key, which RLS makes
  safe to expose.
- The service-role key and any `--dart-define` secrets are injected from CI
  secrets and are never committed.
- On-device photos are re-encoded to strip EXIF/GPS before upload.

## Supported

This is an actively maintained project for a single business. Only the current
`main` line receives security fixes.
