# Photos — platform configuration

The real photo integration is implemented (`lib/data/photo_service.dart`,
`lib/data/image_pipeline.dart`). It follows `../app-design/03-photo-integration.md`:
system pickers (prompt-free on both platforms), EXIF/GPS stripped, downscaled and
re-encoded to JPEG, and Openverse for "Find one for me".

`flutter create .` regenerates the `ios/` and `android/` folders **without** the
keys below, so paste them in **after** running it. Do this once.

The design keeps the app almost permission-free: the only OS prompt in the whole
product is the iOS camera one (§1.3). **Do not add photo-library or
`READ_MEDIA_*` permissions** — the system pickers need none, and adding them
invites App Store / Play rejection (§1.2, §7.2).

---

## iOS — `ios/Runner/Info.plist`

Add inside the top-level `<dict>`:

```xml
<!-- Shown by the OS the first (and only) time the owner taps "Take a photo".
     Keep it specific — generic strings are a common App Store rejection (§7.1). -->
<key>NSCameraUsageDescription</key>
<string>Knightsbridge uses the camera so you can photograph stock items to show on the shop website.</string>
```

That is the complete list. Deliberately **absent** (all per §1.1 / §7.1):

| Key | Why it is NOT here |
|---|---|
| `NSPhotoLibraryUsageDescription` | `PHPickerViewController` (what `image_picker`'s gallery source uses) needs no library access and shows no prompt. |
| `NSPhotoLibraryAddUsageDescription` | We never write photos back into the user's library. |
| `NSLocationWhenInUseUsageDescription` | We strip location; we never read it. |
| `NSMicrophoneUsageDescription` | Images only. |

> If v1 ships **without** the in-app camera (owner shoots in the iOS Camera app,
> then picks the photo), even `NSCameraUsageDescription` is unnecessary and the
> app asks for nothing at all. Since this build offers "Take a photo", include it.

### Privacy manifest — `ios/Runner/PrivacyInfo.xcprivacy`

Required for App Store submission since 1 May 2024 (§7.1). Photos are uploaded
and published, so they are "collected". Minimum:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypePhotosorVideos</string>
      <key>NSPrivacyCollectedDataTypeLinked</key><false/>
      <key>NSPrivacyCollectedDataTypeTracking</key><false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
    </dict>
  </array>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- We read file modification times when writing the stored JPEG. -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>C617.1</string></array>
    </dict>
  </array>
</dict>
</plist>
```

Third-party plugins ship their own manifests; `flutter build ipa` merges them.

---

## Android — `android/app/src/main/AndroidManifest.xml`

`image_picker`'s gallery source uses the Android Photo Picker, which needs **no
permission**. The camera source uses `ACTION_IMAGE_CAPTURE`, which needs no
permission **as long as `CAMERA` is not declared**. So the manifest adds only a
soft camera feature flag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">

    <!-- Install on tablets with no camera; capture is still optional. -->
    <uses-feature android:name="android.hardware.camera" android:required="false" />

    <application ...>
        <!-- Pre-install the Photo Picker backport on Android 4.4–10 rather
             than fetching it on first use (§1.2). Optional but nicer. -->
        <service android:name="com.google.android.gms.metadata.ModuleDependencies"
                 android:enabled="false" android:exported="false"
                 tools:ignore="MissingClass">
            <intent-filter>
                <action android:name="com.google.android.gms.metadata.MODULE_DEPENDENCIES" />
            </intent-filter>
            <meta-data android:name="photopicker_activity:0:required" android:value="" />
        </service>
    </application>
</manifest>
```

**Do NOT add, and check the *merged* manifest does not add** (a library can pull
one in via manifest merge — §1.2, §7.2):

- `android.permission.CAMERA`  → forces a runtime prompt for `ACTION_IMAGE_CAPTURE`.
- `android.permission.READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_VISUAL_USER_SELECTED`
  → restricted by Play's Photo & Video Permissions policy; a one-photo-per-item
  stock app will be rejected.

Verify after building:

```bash
# from android/
./gradlew :app:processReleaseManifest
# then inspect app/build/intermediates/merged_manifests/release/AndroidManifest.xml
```

There should be **no** `CAMERA` and **no** `READ_MEDIA_*` line.

---

## Permission-priming copy (§7.3)

Show your own screen **before** the OS prompt, only right after the owner taps
something that needs it. Never prime on launch. (The screens themselves are the
app author's to place; this is the approved copy.)

**iOS camera — the one priming screen in the app:**

> **Take a photo of this item**
> Knightsbridge uses your camera only when you tap "Take photo". Photos are
> attached to the stock item you're editing.
> Nothing is taken automatically, and nothing is uploaded until you tap Save.
> [ Not now ] [ Open camera ]

**Photo library — no prompt exists, so no priming screen.** Just the button:

> **Choose a photo** — Pick from your photos, including anything in iCloud.

**Before a photo goes on the public website — show once, remember the ack:**

> **This photo will appear on the shop's public website.**
> We automatically remove the location tag from every photo, so your address is
> never published.
> Please avoid photos that show customers' faces, staff rosters, or anything on
> the counter with a name or address on it.
> [ Cancel ] [ Publish photo ]

---

## How each source is stored

| Source | Result | `Product.imageUrl` |
|---|---|---|
| Take a photo / Choose a photo | pipeline: 1200 px, JPEG, EXIF+GPS stripped | **local file path** in the app documents dir |
| Paste a web address | validated clipboard URL | the https URL, verbatim |
| Find one for me | Openverse (commercial licence) | the remote https URL; `imageCredit` = JSON credit block |

Device photos are stored as a **file path**, not a data URI: the app is offline
/ local-first with no server, and a base64 blob in every product row would bloat
the "load all products" query. `widgets/photo_block.dart` renders a file path
with `FileImage` and an http(s) URL with `NetworkImage`.

## Pre-launch checklist (§ checklist)

- [ ] `exiftool` on a stored photo shows **no `GPS*` tags**.
- [ ] A portrait and an upside-down photo both render upright.
- [ ] A HEIC iPhone photo completes on an Android device (API 28+).
- [ ] Merged Android manifest has **no** `CAMERA` / `READ_MEDIA_*`.
- [ ] `NSCameraUsageDescription` present; no photo-library usage string.
