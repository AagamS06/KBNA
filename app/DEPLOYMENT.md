# Deployment

How to build, flavour, sign and ship the Knightsbridge Newsagency owner app.
Read this alongside `../app-design/01-architecture.md` §1.5 (build tooling) and
§7 (store submission — start the Apple/Google enrolments in week 0; they are the
long pole).

> **First time in this repo?** The generated native folders (`android/`, `ios/`,
> …) are gitignored. Run `flutter create .` once inside `app/` to create them —
> it does not touch `lib/` or `pubspec.yaml`. Then `flutter pub get`.

---

## 1. Flavours (dev / prod via `--dart-define`)

There is **no `flavor` build variant to configure** — the app selects its
backend at runtime from compile-time env, read in `lib/config/backend_config.dart`.
This keeps secrets out of the repo entirely.

| Variable | Meaning |
|---|---|
| `SUPABASE_URL` | Your project URL, e.g. `https://abcd.supabase.co` |
| `SUPABASE_ANON_KEY` | The **publishable** anon key (safe to ship — RLS enforces access, §2.3) |
| `APP_FLAVOR` | Cosmetic label only: `dev` (default) or `prod` |

**Dev / local-only (no backend — runs exactly as the offline demo):**

```bash
flutter run
```

**Dev against a Supabase project:**

```bash
flutter run \
  --dart-define=APP_FLAVOR=dev \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

**Prod:** same flags with `APP_FLAVOR=prod` and the production project's URL/key.

> Because the values are compile-time constants, a build made **without** the
> Supabase flags is genuinely a local-only binary — the Supabase client is never
> initialised. That is the property that keeps `flutter run` working with no
> backend.

Tip: put the long flag lists in VS Code `launch.json` configurations (one per
flavour) so F5 "just works", and/or a `--dart-define-from-file=env/prod.json`
file that is **gitignored**.

---

## 2. App icon & splash (config already in `pubspec.yaml`)

Both are **config-only** generators — they run manually, never during
`flutter run`/`build`, so the app compiles even before you add the art.

1. Create the source art in the brand palette (`#E1251B` red, `#111111` ink,
   white — §1.4). No transparency / no rounded corners on the 1024px master
   (the OS rounds it, §7.2):
   - `assets/icon/app_icon.png` — 1024×1024 master
   - `assets/icon/app_icon_foreground.png` — Android adaptive foreground
   - `assets/splash/splash_logo.png` and `..._dark.png` — centred launch mark
2. Generate:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Re-run whenever the art changes. Configuration lives at the bottom of
`pubspec.yaml` under `flutter_launcher_icons:` and `flutter_native_splash:`.

---

## 3. Versioning

`pubspec.yaml` → `version: <name>+<build>` (currently `1.0.0+14`).

- **`<name>`** (e.g. `1.1.0`) is the user-facing version; bump per release.
- **`<build>`** (e.g. `15`) MUST increase for every store upload — both stores
  reject a re-used build number. Bump it on every submission even for the same
  version name.
- Override at build time without editing the file: `--build-name=1.1.0
  --build-number=15`.
- Keep the "v1.0 (14)" string in `settings_screen.dart` in step, or wire it to
  `package_info_plus` later so it reads the real value.

---

## 4. Release builds

Android (App Bundle for Play, APK for sideload testing):

```bash
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
# or: flutter build apk --release  … (for direct-install testing)
```

iOS (archive, then upload via Xcode/Transporter or `flutter build ipa`):

```bash
flutter build ipa --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

iOS release builds require a Mac with Xcode (or a macOS CI runner). See §7 of the
architecture doc for the store-review posture — expect a possible Guideline 4.2
push-back and lead with the offline/scanner/Face-ID native features and a working
demo account.

---

## 5. Signing — secrets go in GitHub, never in the repo

**Do not commit** a keystore, `key.properties`, `.p8`, `google-services.json`, or
any `--dart-define` value. Store them as **GitHub Actions secrets**
(Settings → Secrets and variables → Actions):

| Secret | Used for |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | `--dart-define` in release builds |
| `ANDROID_KEYSTORE_BASE64` | `base64 -d` back to `upload-keystore.jks` at build time |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` / `ANDROID_KEY_ALIAS` | Gradle signing config |
| `IOS_DIST_CERT_P12_BASE64` / `IOS_DIST_CERT_PASSWORD` | iOS distribution cert |
| `IOS_PROVISIONING_PROFILE_BASE64` | iOS provisioning profile |
| `APP_STORE_CONNECT_API_KEY` (`.p8`, key id, issuer id) | `eas submit` / Transporter upload |

**Back up the Android upload keystore** somewhere safe (the shop's password
manager) — losing it means you can never update the Play listing again without
Google's key-reset process (§1.5).

Locally, Android signing reads `android/key.properties` (gitignored):

```properties
storeFile=upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

---

## 6. CI (`.github/workflows/flutter-ci.yml`, at the repo root)

On every push and PR it runs, with `app/` as the working directory:

```
dart format --set-exit-if-changed .   # formatting gate
flutter analyze                        # static analysis
flutter test                           # unit tests (test/)
```

It does **not** run `flutter create .` — analysis and unit tests work against
`lib/` + `test/` and don't need the native folders. A commented-out `build-android`
job at the bottom of the workflow shows how to add a signed, tag-gated release
build using the secrets above; leave it commented until the signing secrets are
in place.

---

## 7. Supabase side

Apply `supabase/schema.sql` in the Supabase SQL editor (project region
**ap-southeast-2 / Sydney**). It creates the tables, the ledger + auto-hold
triggers, the `public_products` view the website reads, and the RLS policies for
a 1–2 user shop. Then **disable public sign-ups** and provision the two owner
accounts by hand (§3.2). Push notifications (FCM/APNs), the `create-reservation`
and `send-push` Edge Functions, and the nightly `pg_dump` backup are follow-on
work described in architecture §2.7 / §5 / §2.8.
