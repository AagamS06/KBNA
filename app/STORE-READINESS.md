# Store readiness — shipping the owner app to the App Store & Google Play

This is the exact, ordered checklist to take the Knightsbridge Newsagency owner
app from this repo to a live listing on both stores. It is written so a
non-technical owner can follow along and hand the technical steps to a developer.

Read alongside `DEPLOYMENT.md` (flavours, build commands, signing secrets) and
`../app-design/01-architecture.md` §7 (store-review posture).

---

## 0. Honest status — what is done vs what only a human can do

**Done and in this repo (no further code needed to run or build):**

- The app compiles and runs today. `flutter run` with no arguments launches the
  full offline, local-only app exactly as designed — no backend required.
- Release tooling is pre-configured in `pubspec.yaml`: app-icon and splash
  generators (`flutter_launcher_icons`, `flutter_native_splash`), version/build
  number (`1.0.0+14`), and the Supabase-behind-`--dart-define` seam.
- CI (`.github/workflows/flutter-ci.yml`) runs format + analyze + tests on
  every push.

**Only a human can do these (they need real identities, money, or Apple/Google
review — they cannot be scripted in this repo):**

- Enrol in the **Apple Developer Program** (US$99/year) and **Google Play
  Console** (US$25 one-time). Enrolment includes identity verification and can
  take days.
- Generate and safely store the **Android upload keystore** and the **iOS
  distribution certificate + provisioning profile**.
- Create the **app icon / splash artwork** (the config points at PNG paths that
  do not exist yet).
- Stand up a **real Supabase project** and a **real domain** if/when the online
  sync + website go live (the app runs fully without them).
- Fill in **store listings, screenshots, privacy answers**, and pass **store
  review**.

The bottom line: **the app is submittable** — nothing in the code blocks a build
or a submission — but account creation, signing, artwork, and review are human
steps that must happen outside this repo.

---

## 1. Human prerequisites (do these first — they have lead time)

| Prerequisite | Cost | Notes |
|---|---|---|
| Apple Developer Program | **US$99/year** | Required to build/sign/submit to the App Store and TestFlight. Identity check can take 24–48h+. |
| Google Play Console account | **US$25 one-time** | Required to publish on Google Play. Identity + (for individuals) address verification. |
| A **Mac with Xcode** | — | Mandatory to build/upload the iOS app. No Mac → use a macOS CI runner or a Mac cloud service. Android builds run on any OS. |
| (Optional) Supabase project | Free tier fine at this scale | Only needed for online sync/website. Gives you `SUPABASE_URL` + anon key. The app runs without it. |
| (Optional) A real domain | ~US$10–20/year | Only for the public website / links. Not needed for the app to run. |

The app **runs and is submittable without** the Supabase project or domain — it
simply ships as the offline local-only build until those exist.

---

## 2. One-time: generate the native platform folders

The `android/`, `ios/`, `macos/`, etc. folders are intentionally **not** in the
repo (they are machine-generated). From inside `app/`:

```bash
flutter create .
flutter pub get
```

`flutter create .` fills in the native folders **without touching `lib/` or
`pubspec.yaml`**. Do this once per fresh checkout (and re-run after a Flutter
upgrade if the templates change).

Verify it still runs locally, offline:

```bash
flutter run          # should launch the full app with sample stock, no backend
```

---

## 3. Set the app identifiers (bundle ID / application ID)

Pick **one** reverse-DNS identifier and use it on both stores, e.g.
`com.knightsbridgenews.owner`. Set it when generating the folders, or change it
afterwards:

```bash
# Easiest: pass it at create time
flutter create --org com.knightsbridgenews --project-name knightsbridge_owner .
```

- **iOS:** `ios/Runner.xcodeproj` → target → *Bundle Identifier*
  (`com.knightsbridgenews.owner`).
- **Android:** `android/app/build.gradle` → `applicationId`
  (`com.knightsbridgenews.owner`).

The identifier is **permanent** once an app is published — choose carefully.

---

## 4. App icon & splash screen

The generators are already configured at the bottom of `pubspec.yaml`. You only
need to supply the artwork, then run them.

1. Create the PNGs (brand palette: red `#E1251B`, ink `#111111`, white; **no
   transparency, no rounded corners** on the master — the OS rounds it):
   - `assets/icon/app_icon.png` — 1024×1024 master
   - `assets/icon/app_icon_foreground.png` — Android adaptive foreground
   - `assets/splash/splash_logo.png` and `assets/splash/splash_logo_dark.png`
2. Generate:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Re-run whenever the art changes. (These are config-only tools — they never run
during `flutter run`/`build`, so the app compiles even before the art exists.)

---

## 5. iOS permission strings (`ios/Runner/Info.plist`)

The app uses the **system photo picker** for "Choose from your photos", which is
**prompt-free** and needs **no** photo-library usage string. But it also offers
**"Take a photo"** (in-app camera via `image_picker`), which on iOS requires one
string or the app **hard-crashes on first camera use**:

```xml
<key>NSCameraUsageDescription</key>
<string>Take a photo of a product to show it on your website.</string>
```

Do **not** add `NSPhotoLibraryUsageDescription` or
`NSPhotoLibraryAddUsageDescription` — the picker does not need them and adding
them implies access you do not use.

Notifications (low-stock / new-order alerts) are requested at runtime by the app;
no Info.plist string is required.

> If you decide **not** to ship the in-app camera in v1 (owner takes the photo in
> the Camera app, then picks it), the app shows **no OS permission prompt at all**
> and you can omit `NSCameraUsageDescription`. That is the lowest-friction v1.

---

## 6. Android manifest — what NOT to declare

The system photo picker and the system camera app mean you should declare **none**
of these. Declaring any of them (even via a library's manifest merge) forces a
runtime permission prompt and pulls you into Google Play's restricted-permission
review:

- ❌ `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_VISUAL_USER_SELECTED`
- ❌ `android.permission.CAMERA`

After `flutter create .`, check the **merged** manifest and confirm none of the
above appear:

```bash
# build once, then inspect the merged manifest
flutter build apk --debug
# open: build/app/outputs/logs/manifest-merger-*.txt  (or the merged AndroidManifest)
```

Android 13+ notification permission (`POST_NOTIFICATIONS`) is handled by
`flutter_local_notifications` and requested at runtime — that one is expected and
fine.

---

## 7. Version & build numbers

`pubspec.yaml` → `version: <name>+<build>` (currently `1.0.0+14`).

- **`<name>`** (e.g. `1.0.0`) — the version customers see. Bump per release.
- **`<build>`** (e.g. `15`) — **must increase on every single store upload**;
  both stores reject a re-used build number. Bump it every submission, even for
  the same version name.
- Override without editing the file: `--build-name=1.0.0 --build-number=15`.
- Keep the `"v1.0 (14)"` string in `lib/screens/settings_screen.dart` in step
  (or wire it to `package_info_plus` later).

---

## 8. Signing (secrets live outside the repo — never commit them)

### Android — upload keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Save `android/key.properties` (gitignored) pointing at it (see `DEPLOYMENT.md`
  §5 for the exact contents).
- **Back up the keystore + passwords** in the shop's password manager. Losing it
  means you can never update the Play listing again without Google's key-reset
  process. Enrol in **Play App Signing** so Google holds the release key and you
  only manage the upload key.

### iOS — distribution certificate + provisioning profile

- In the Apple Developer portal, create an **App ID** matching the bundle ID, an
  **iOS Distribution certificate**, and an **App Store provisioning profile**.
- Xcode's *Automatically manage signing* handles this for a first submission if
  you sign in with the Apple Developer account.

For CI signing, store all of the above as **GitHub Actions secrets** — the exact
secret names are listed in `DEPLOYMENT.md` §5.

---

## 9. Build the release artifacts

Local-only build (no backend — genuinely offline binary):

```bash
flutter build appbundle --release    # Android → .aab for Play
flutter build ipa --release          # iOS → .ipa (needs a Mac + Xcode)
```

Build against a Supabase backend (adds online sync; still offline-first):

```bash
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

(Same `--dart-define` flags for `flutter build ipa`.) Outputs:
`build/app/outputs/bundle/release/app-release.aab` and `build/ios/ipa/*.ipa`.

---

## 10. Privacy declarations (both stores ask before you can publish)

The app's data touchpoints, and how to answer:

| What the app does | Store answer |
|---|---|
| **Take a photo / attach a product photo.** Photos are downscaled and **EXIF/GPS-stripped on-device**, then stored locally and (if a backend is configured) uploaded to your own Supabase as the product image. | Declare **Photos** used for **App Functionality**, **not used for tracking**, not shared with third parties. |
| **Owner sign-in (email + password).** | Declare **Contact Info / Account** (email) used for **App Functionality / Authentication**. |
| **Notifications** (low-stock, new order). | Not "data collection". Just note notification usage in the listing description. |
| **No analytics/ads/tracking SDKs.** | Answer **No** to tracking across every category. |

### App Store — App Privacy "nutrition label"

In App Store Connect → your app → **App Privacy**, add:

- **Photos or Videos** → *App Functionality* → *Not linked to identity* (or
  linked, if you tie product photos to the shop account) → *Not used for
  tracking*.
- **Email Address** (owner sign-in) → *App Functionality* → *Not used for
  tracking*.
- Everything under *Tracking*: **No**.

### Google Play — Data safety form

In Play Console → **App content → Data safety**:

- **Photos and videos** → collected → *App functionality* → not shared → you may
  mark data **encrypted in transit** (Supabase is HTTPS) and that the user can
  request deletion.
- **Email address** → collected for *Account management / App functionality*.
- **No** to "Is this data used for tracking?" everywhere.

> **The compliance win:** because the merged Android manifest declares **no**
> `READ_MEDIA_*` and **no** `CAMERA` permission, the **Photo & Video Permissions
> declaration form is not required at all** — there is nothing for a reviewer to
> reject. Keep it that way (see §6).

---

## 11. Submit

### Google Play

1. Create the app in Play Console, set the store listing (title, short/full
   description, screenshots, feature graphic, content rating questionnaire).
2. Upload the `.aab` to an **Internal testing** track first; install and smoke-
   test on a real device.
3. Complete **Data safety** (§10) and the content-rating questionnaire.
4. Promote to **Production** and submit for review.

### App Store

1. Create the app record in App Store Connect (bundle ID from §3).
2. Upload the build via Xcode → *Organizer* → *Distribute App*, or Transporter,
   or `flutter build ipa` + Transporter.
3. Test via **TestFlight** on a real device.
4. Fill in **App Privacy** (§10), screenshots, description, and a **working demo
   account** for the reviewer (seed email `owner@knightsbridgenews.com.au` /
   password `changeMe1234` for the local build, or a real Supabase test login).
5. Submit for review. Expect a possible **Guideline 4.2 ("minimum
   functionality")** query for a business tool — lead with the offline stock
   editing, low-stock notifications, and the photo capture as the native value,
   and point the reviewer at the demo account.

---

## 12. Final pre-submit checklist

- [ ] `flutter create .` run; `flutter run` launches offline with sample stock.
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] Bundle ID / applicationId set and identical on both stores.
- [ ] Icon + splash PNGs added and generators run.
- [ ] iOS: `NSCameraUsageDescription` present (if shipping the in-app camera).
- [ ] Android merged manifest has **no** `CAMERA` / `READ_MEDIA_*`.
- [ ] Build number bumped (must exceed the last uploaded build).
- [ ] Android keystore created **and backed up**; Play App Signing enrolled.
- [ ] iOS distribution cert + provisioning profile in place.
- [ ] App Privacy (Apple) + Data safety (Google) completed per §10.
- [ ] Reviewer demo account works.
- [ ] `.aab` / `.ipa` uploaded to a testing track and smoke-tested on a real
      device before promoting to production.
