# Knightsbridge Newsagency — Owner App (Flutter)

The shop owner's counter tool. Manage stock, prices, holds and view online
orders. It replaces the removed website owner portal (`owner.html`).

Built to the specs in `../app-design/` (UX §02, architecture §01, photos §03).
**Local-first**: it runs and demos entirely on the phone with **no backend** —
stock lives in an on-device SQLite ledger, seeded with the 12 sample products
from the website.

---

## Run it in VS Code (for someone who has never used Flutter)

### 1. Install the toolchain (once)

1. Install **Flutter** (stable channel, 3.x): https://docs.flutter.dev/get-started/install
   Follow the guide for your OS; it installs Dart too.
2. In a terminal run `flutter doctor` and fix anything it flags with a ✗ that
   relates to the platform you want to run on (Android toolchain, or Xcode for
   iOS on a Mac).
3. Open **VS Code** and install two extensions from the Extensions panel
   (`Ctrl/Cmd+Shift+X`):
   - **Flutter** (publisher: Dart Code) — this also pulls in the **Dart** extension.

### 2. Generate the native project folders (once)

This repository contains the Dart source (`lib/`), `pubspec.yaml` and this
README, but not the generated `android/`, `ios/`, `web/` etc. folders (those are
machine-generated and not worth committing). Create them:

```bash
cd app
flutter create .
```

`flutter create .` fills in the platform folders **without touching** `lib/` or
`pubspec.yaml`. Run it once.

### 3. Get the dependencies

```bash
flutter pub get
```

(In VS Code, opening `pubspec.yaml` and saving also runs this automatically.)

### 4. Pick a device and run

- **Bottom-right of the VS Code status bar** shows the current device. Click it
  to open the device picker (`Ctrl/Cmd+Shift+P` → "Flutter: Select Device").
  Choose an Android emulator, an iOS Simulator (Mac only), a connected phone, or
  **Windows/macOS/Linux desktop** (the app runs on desktop too — see note below).
- Press **F5** (Run → Start Debugging), or in a terminal:

```bash
flutter run            # runs on the selected device
flutter run -d windows # or macos / linux / chrome / <device-id>
flutter devices        # list what's available
```

Hot reload: save a file, or press `r` in the `flutter run` terminal.

### 5. Sign in

The seeded demo credentials are:

- **Email:** `owner@knightsbridgenews.com.au` (pre-filled)
- **Password:** `changeMe1234`

To wipe and re-seed at any time: **Today → gear (Settings) → Start again with
sample stock** (type `ERASE` to confirm).

> **Desktop note.** For convenient demos, the app also runs on desktop via
> `sqflite_common_ffi`. On a real iPhone/Android it uses the native SQLite. No
> code change needed — the database layer picks the right implementation.

---

## What's implemented

Every capability of the old `owner.html`, plus the UX spec's additions.

| owner.html capability | Where it lives now |
|---|---|
| Sign in | `sign_in_screen.dart` (2.1) |
| Sign out | Settings → Sign out (2.7) |
| Add stock item | Stock `+` → `add_edit_item_screen.dart` (2.5) |
| Edit stock item | Item detail → Edit, or row swipe/long-press (2.5) |
| Remove item (`active:false`) | Row swipe/long-press, item `⋯`, edit footer → **recoverable** in Settings → Removed items (2.4/2.7) |
| Set price (`price_cents`) | Add/Edit price field, `$` prefix, accepts `6.5`/`6.50`/`$6.50`/`650c` |
| Set stock (`stock`) | Row `± stepper`, item-detail stepper, number-pad sheet, Add form (2.3) |
| Category (`tag`) + custom | Category picker with "Add a new category" (2.5.2) |
| Low-stock threshold | "Warn me when it drops to" stepper (2.5) |
| Hold (`held`) | Row swipe/long-press, item status card, "Show this to customers" switch, Today card — shown in plain English, never as "held" (2.2/2.3/2.4/2.5) |
| Low-stock panel | Today "Needs attention" card (2.2) |
| Order history | Orders tab, grouped Today/Yesterday/Earlier (2.6.1) |
| Order line detail | `order_detail_screen.dart` — **new**; also explains the auto-hold (2.6.2) |
| Change sign-in details | Settings → Sign-in details; now **requires the current password** (2.7) |
| Auto-hold on low stock after an order | Ledger recalc + auto-hold in `local_repository.dart`; now auto-releases on restock and is **explained** on the order (§2.8) |
| Reset demo data | Settings → Start again with sample stock, typed `ERASE` (2.7) |
| Photo (`image_url`/credit) | `PhotoBlock` + generated category artwork fallback; photo picking is a clean seam (see below) |

Additions from the UX spec that are built: removed-items archive, order detail,
`barcode` field on the product record, dark mode, "Bigger buttons" and "Buttons
on the left" accessibility settings, the bottom-anchored search, the number pad.

## Architecture

```
lib/
├── main.dart                     App root, theme wiring, auth gate
├── models/                       Immutable domain types
│   ├── product.dart              matches web-design/js/app.js shape + barcode
│   ├── stock_movement.dart       the append-only ledger entry
│   ├── order.dart                ShopOrder + OrderItem (read-only)
│   └── app_settings.dart         preferences + Credentials
├── data/
│   ├── repository.dart           ShopRepository — THE BACKEND SEAM (interface)
│   ├── local_repository.dart     sqflite impl: ledger recalc + auto-hold + seed
│   ├── database.dart             SQLite open + schema (mirrors §2.4)
│   ├── seed_data.dart            the 12 sample products + demo orders
│   └── photo_service.dart        PhotoService — THE PHOTO SEAM (+ stub)
├── state/                        Riverpod providers + controllers
│   ├── providers.dart
│   └── auth_controller.dart
├── theme/                        Design system in code
│   ├── colors.dart               KnColors ThemeExtension (light + dark tokens)
│   ├── typography.dart           Plus Jakarta Sans + Atkinson Hyperlegible scale
│   ├── spacing.dart              4pt scale, radii, touch targets
│   └── app_theme.dart            Material 3 light/dark ThemeData
├── screens/                      One file per screen
└── widgets/                      Reusable components (stock row, stepper, …)
```

### Stock as a ledger (the important bit)

`stock` is **derived**, never written directly. Every change appends a
`stock_movement` (`count` / `sale` / `delivery` / `waste` / `adjust`) and
`_recalc()` recomputes the cached stock from the most recent stocktake plus every
later movement — the CRDT-shaped model from architecture §2.4/§4.4. The auto-hold
rule (hide at/below the alert level, auto-release once restocked) is applied in
the same recalc, reproducing `fulfilOrder()` from the website.

### The two seams

- **Backend:** everything talks to `ShopRepository`. To add Supabase sync later,
  add a second implementation (or a decorator draining an outbox) and override
  `repositoryProvider`. No UI changes.
- **Photos:** the UI depends only on `PhotoService`. The real integration
  (`SystemPhotoService`) is now wired in — system pickers (prompt-free), the
  downscale/EXIF-strip pipeline, and Openverse for "Find one for me".
  `StubPhotoService` is kept for tests/demos. **Platform config the owner must
  paste in after `flutter create .` lives in [`PHOTOS.md`](PHOTOS.md).**

## State management

**Riverpod** (`flutter_riverpod`), used consistently. Hand-written
`AsyncNotifier`/`Notifier` providers (no `riverpod_generator`) so the project
builds with a plain `flutter pub get` — no code-gen step.

## Fonts

Uses `google_fonts`, which fetches Plus Jakarta Sans and Atkinson Hyperlegible on
first run and caches them. For a production release, **bundle the `.ttf` files**
(both are OFL-licensed) under `assets/fonts/`, declare them in `pubspec.yaml`
(the block is already stubbed in comments), and set
`GoogleFonts.config.allowRuntimeFetching = false` in `main.dart` to remove the
first-run network fetch entirely, as the design system requires.

## Accessibility

48dp minimum touch targets (56 with "Bigger buttons"), semantic labels on every
control, the stock row folded into one semantics node with custom actions
(equivalent to the swipe gestures), OS text scaling respected, and state never
carried by colour alone (every low/hold/error state also has a word and a glyph).
The dark-mode red rule is enforced: red text on dark uses `#FF6E63`, brand red
`#E1251B` appears on dark only as a non-text graphic.

## Notes / things not verifiable without a compiler

See the delivery summary. In short: this was written without a Flutter toolchain
available, so it has not been through `flutter analyze` / `flutter run`. The code
is written to compile on current stable Flutter 3.x / Dart 3 with sound null
safety; run `flutter analyze` after `flutter pub get` and address any environment-
specific warnings.

Photo integration specifics not verifiable without a compiler/device:

- **Downscale size.** `flutter_image_compress` treats `minWidth`/`minHeight` as
  lower bounds, so photos land at ~1200 px short edge (long edge scales with
  aspect), not a strict 1200 px long edge. Heavy downscale, within spec; confirm
  on-device if an exact long-edge cap matters. See `data/image_pipeline.dart`.
- **EXIF/GPS strip.** Relies on `keepExif: false` (the default). Run the spec's
  check once: upload a GPS-tagged photo, download it, `exiftool` → no `GPS*`.
- **HEIC.** Decoded natively on iOS and Android API 28+. Older Android throws the
  handled "Most Compatible" message.
- **Local rendering.** `widgets/photo_block.dart` was given a 1-line-per-callsite
  change (`_photoProvider`) so a stored file path renders via `FileImage`;
  `Image.network` cannot display local files. This uses `dart:io`, so the app is
  **mobile/desktop only** (it already is — `sqflite`). Not web-compatible.
- **URL source = clipboard.** "Paste a web address" reads the clipboard, since
  `PhotoService.pick` has no `BuildContext` to show a text field. If you prefer an
  in-app URL field, add it in the screen and pass the text through the seam.
- **Cancel snackbar.** `add_edit_item_screen.dart` still shows its "picker coming
  soon" snackbar whenever `pick()` returns null — which now also means "owner
  cancelled" or "lookup failed". Left as-is (screen UX is out of scope); reword
  when convenient.
