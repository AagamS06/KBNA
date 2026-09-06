# App security

How the owner app protects the shop's data, and what to do at release. Scope
is proportionate: one or two trusted users, a single shop, no customer PII
beyond a reservation name/phone.

## Data at rest

- **No plaintext password ships in the build.** The old web demo hard-coded
  `changeMe1234`; that is gone. Sign-in is checked against Supabase Auth when a
  backend is configured; the local-only demo compares against a value the owner
  sets on the device.
- **Session tokens** (once Supabase Auth is wired) are held by
  `supabase_flutter`, which stores them in the platform secure store — iOS
  Keychain / Android EncryptedSharedPreferences. Do **not** move them into
  plain `SharedPreferences` or the sqflite DB.
- The local sqflite database holds stock and reservations, not secrets. If the
  device is shared, enable OS device-lock; optionally add `sqlcipher` later.

## Data in transit

- All Supabase traffic is HTTPS/TLS. The client rejects plain HTTP.
- The app ships only the Supabase **anon** key. That key is safe to expose
  **because** Row Level Security (see `supabase/schema.sql`) denies anon every
  table and exposes only the read-only `public_products` view. The **service
  role** key must never appear in the app or the website — it bypasses RLS and
  belongs only in server-side Edge Functions / GitHub Actions.

## Backend authorisation

- RLS is the whole authorisation model. `supabase/schema.sql` now also revokes
  table grants from `anon`/`public` as defence in depth, pins the public view
  to definer rights, and fixes the functions' `search_path`.
- Public sign-ups are disabled; the two owner accounts are provisioned by hand.
- Orders can't be created from the browser (a customer could set total to 0) —
  creation goes through a server Edge Function; the app only reads/advances
  status.

## Input & integrity

- Every DB write is parameterised (sqflite / PostgREST) — no string-built SQL.
- Stock is an append-only ledger with client-generated `idempotency_key`
  (unique), so a retried sync can't double-apply a movement.
- Photos picked on-device are re-encoded, which strips EXIF/GPS before the
  image ever leaves the phone (`lib/data/image_pipeline.dart`).

## Release build hardening

Run release builds obfuscated, and keep the debug symbols to de-obfuscate
crash reports:

```bash
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

- **Never commit the `--dart-define` values.** Inject them from GitHub Actions
  secrets / a local untracked `--dart-define-from-file` JSON that is in
  `.gitignore`.
- **Android**: R8/ProGuard shrinking is on by default for `--release`. After
  `flutter create .`, add a network-security-config that disables cleartext
  traffic (`android:usesCleartextTraffic="false"`).
- **Back up** the `build/symbols` directory per release — without it a
  production crash stack is unreadable.
- Do **not** declare `CAMERA` or `READ_MEDIA_*` in the Android manifest; the
  app uses the system photo picker, which needs no permission (keeps the app
  off Google's restricted-permissions review — see `PHOTOS.md`).

## Reporting a vulnerability

See the repository-root `SECURITY.md` for the disclosure contact.
