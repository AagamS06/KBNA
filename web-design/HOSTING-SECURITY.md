# Website security — how it's set up and what to check before launch

The site ships with a defence-in-depth set of controls. Most work on any
host; a few need one line of host config. This file says which is which.

## What's already in the files

- **Content-Security-Policy** — a `<meta http-equiv>` CSP in every page. This
  is the one control that works everywhere, including plain static hosts that
  can't set headers (GitHub Pages). It restricts the page to loading scripts
  and styles only from this site, fonts from Google Fonts, and images from
  this site / `data:` / any HTTPS source. Inline scripts are blocked entirely.
- **Referrer-Policy** — `strict-origin-when-cross-origin`, via meta.
- **`_headers`** — the full header set for **Netlify / Cloudflare Pages**.
- **`.htaccess`** — the same set for **Apache** hosts (cPanel, shared hosting),
  plus a force-HTTPS redirect.
- **`.well-known/security.txt`** — RFC 9116 contact for security reports.
- **No secrets in the code.** The old owner password was removed when the
  portal moved to the app. The site is read-only; there is nothing to steal.

## Headers a `<meta>` tag cannot set — need a real host

These are in `_headers` / `.htaccess` but are **ignored on GitHub Pages**,
which cannot send custom headers:

| Header | Protects against | Set where |
|---|---|---|
| `Strict-Transport-Security` | protocol-downgrade / SSL-strip | `_headers`, `.htaccess` |
| `X-Frame-Options` / `frame-ancestors` | clickjacking (framing the site) | `_headers`, `.htaccess` |
| `Permissions-Policy` | rogue use of camera/mic/geolocation | `_headers`, `.htaccess` |
| `X-Content-Type-Options: nosniff` | MIME sniffing | `_headers`, `.htaccess` |

**If you host on GitHub Pages**, put the site behind **Cloudflare** (free) and
add these headers there (a Cloudflare "Transform Rule" or `_headers` on
Cloudflare Pages). The `<meta>` CSP still gives you the biggest single win in
the meantime.

## Before launch

1. **Swap the domain.** The CSP itself isn't domain-specific, but the
   placeholder `www.knightsbridgenews.com.au` appears in the canonical/OG/
   sitemap tags and in `security.txt`'s `Canonical:` line — update those to
   the real domain.
2. **Confirm HTTPS + auto-redirect.** All modern hosts do this; the `.htaccess`
   forces it on Apache.
3. **Update `security.txt`** `Expires:` before it lapses (currently 2027-12-31)
   and confirm the contact email.
4. **Test the headers** at https://securityheaders.com and the CSP at
   https://csp-evaluator.withgoogle.com after deploying.
5. **Optional, strongest step:** self-host the two Google fonts (drop the
   `.woff2` files in `assets/fonts/` and add `@font-face`), then tighten the
   CSP to drop `fonts.googleapis.com` / `fonts.gstatic.com` and remove
   `'unsafe-inline'` from `style-src`. That removes the last third-party origin.
