# 03 — Photo Integration

**Knightsbridge Newsagency stock app (iOS + Android) and public website**
Written July 2026. Every platform claim below was checked against vendor documentation; sources are listed inline and collected in the Appendix.

---

## 0. Executive summary — read this first

**What genuinely works**

| Want | Works? | How |
|---|---|---|
| Take a photo and attach it | Yes | System camera intent (Android) / camera picker (iOS) |
| Attach a photo already on the phone | Yes | System photo pickers. **Zero permission prompts on both platforms.** |
| Attach a photo that lives in iCloud Photos | Yes, **on iOS only** | The iOS photo library *is* iCloud Photos. The picker shows cloud-only items and downloads them on demand. |
| Attach a photo that lives in Google Photos | Yes, **on Android, via the system picker** | Google Photos is a cloud media provider for the Android photo picker; cloud items appear inline, no OAuth. |
| Do all of the above from the public website with no app at all | Yes, mostly | `<input type="file" accept="image/*">` reaches the same system pickers in iOS Safari and Android Chrome. |

**What does not work — plainly**

1. **There is no iCloud Photos API.** Not a REST API, not CloudKit, not a file provider. Third-party code cannot read a user's iCloud Photo Library except by running on an Apple device and going through the on-device Photos framework. An Android app, a web page, or a server can never reach iCloud Photos. ([Apple Developer Forums](https://developer.apple.com/forums/thread/74434))
2. **You cannot browse a user's whole Google Photos library inside your app.** Google removed the `photoslibrary.readonly`, `photoslibrary.sharing` and `photoslibrary` scopes on **31 March 2025**; calls relying on them now return `403 PERMISSION_DENIED`. The Library API is now limited to content your own app created. ([Google](https://developers.google.com/photos/support/updates))
3. **The replacement Picker API does not give you a UI you can embed.** It hands the user off to Google's own picker (browser tab or the Google Photos app) and then hands you back a short-lived URL. There is no native Android or iOS SDK. ([Google](https://developers.google.com/photos/picker/guides/get-started-picker))
4. **The static website cannot store an upload by itself.** A page with no server can open a picker and resize an image in the browser, but something has to accept the bytes. The minimum "server" is one Cloudflare Worker (free tier).

**Recommendation for this shop**

Build the owner tool as a **mobile web page (installable PWA) first**, backed by one Cloudflare Worker and a Cloudflare R2 bucket. It costs $0/month at this scale, requires no app store review, no OAuth verification, and no permission prompts. Ship native wrappers only if the owner asks for a home-screen app with offline stock editing — and if you do, use the system pickers and nothing else. **Do not integrate the Google Photos API.** See §3.6 and §8 for why.

---

## 1. On-device camera and photo library

### 1.1 iOS

#### Photo library — use `PHPickerViewController`, nothing else

`PHPickerViewController` (framework `PhotosUI`, iOS 14+) runs **out of process**. Your app never gets library access; the picker returns `NSItemProvider` objects only for the items the user tapped.

Consequences that matter here:

- **No authorisation call.** You do not call `PHPhotoLibrary.requestAuthorization`.
- **No `Info.plist` usage description.** `NSPhotoLibraryUsageDescription` is not required and adding it does not cause a prompt — but leaving it out documents the intent.
- **No system alert of any kind is shown to the user.** They tap "Add photo", the picker slides up, they pick, it dismisses. ([Apple docs](https://developer.apple.com/documentation/photosui/phpickerviewcontroller), [AppCoda](https://www.appcoda.com/phpicker/))

Minimum configuration:

```
PHPickerConfiguration()          // NOTE: the no-argument initialiser
  .filter = .images              // exclude videos, Live Photo stills come through as images
  .selectionLimit = 1            // 1 for a product photo; 0 = unlimited for gallery batches
  .preferredAssetRepresentationMode = .current   // see §5.3 on HEIC
```

**The one trap.** `PHPickerConfiguration(photoLibrary:)` — the initialiser that takes a `PHPhotoLibrary` — is what enables `preselectedAssetIdentifiers` and asset-identifier results. Using it *does* require library authorisation and *does* require `NSPhotoLibraryUsageDescription`, and it *does* prompt. This app has no need for preselection. **Use the no-argument initialiser.**

#### `UIImagePickerController` — status

Soft-deprecated for library access since iOS 14 (the header is annotated for removal). Do not use it for the photo library: it requires `NSPhotoLibraryUsageDescription` and triggers the full access prompt including the Limited Library flow.

It is still the supported, non-deprecated route for a simple **camera capture** (`sourceType = .camera`), and remains the least code for that job. `AVCaptureSession` is the alternative if you ever want a custom capture UI — you do not.

#### `Info.plist` keys — the complete list for this app

| Key | Needed? | Why |
|---|---|---|
| `NSCameraUsageDescription` | **Only if you ship an in-app camera.** Required; the app hard-crashes on first camera access without it. | Camera capture |
| `NSPhotoLibraryUsageDescription` | **No** | Only for `PHPhotoLibrary`/`PHAsset` direct access, which we are not doing |
| `NSPhotoLibraryAddUsageDescription` | **No** | Only if you write photos back into the user's library |
| `NSMicrophoneUsageDescription` | **No** | Images only |
| `NSLocationWhenInUseUsageDescription` | **No** | We are deliberately stripping location (§5.5) |

#### Limited Library access — skip it entirely

The `.limited` authorisation state, `PHPhotoLibrary.presentLimitedLibraryPicker(from:)`, and the `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` plist key exist to make broad-access apps less invasive. They are all downstream of asking for library access in the first place. Because we use `PHPickerViewController`, **none of this applies and none of it should be written.** If you find yourself handling `.limited`, you have taken a wrong turn.

#### Zero-prompt option

If the app ships **without** an in-app camera — the owner takes the photo in the iOS Camera app, then taps "Add photo" and picks it — then the app shows **no OS permission prompt at all, ever**. That is the recommended v1 for a non-technical owner. Add the in-app camera later only if the round trip annoys them.

### 1.2 Android

#### Photo library — use the Android Photo Picker

Use the AndroidX contract, not the raw intent:

```
ActivityResultContracts.PickVisualMedia          // single item
ActivityResultContracts.PickMultipleVisualMedia  // gallery batches
// filter: PickVisualMediaRequest(mediaType = ImageOnly)
```

Requires `androidx.activity` **1.7.0 or later**. Under the hood this is `MediaStore.ACTION_PICK_IMAGES` on API 33+, the Google Play services backport on older devices, and `ACTION_OPEN_DOCUMENT` as a last-resort fallback. ([Android docs](https://developer.android.com/training/data-storage/shared/photo-picker))

**It requires no permission at all — no manifest entry, no runtime request, no prompt.** The picker is a separate system UI; your app receives content URIs only for what was selected.

Availability and the backport:

- Native on Android 11+ (API 30) via Modular System Components / Google System Updates, and on Android 13+ (API 33) as a platform API.
- **Backported to Android 4.4 (API 19) through Android 10 (API 29)**, plus Android Go on 11–12, through Google Play services.
- Check with `ActivityResultContracts.PickVisualMedia.isPhotoPickerAvailable(context)`.
- To get the backport module pre-installed rather than fetched on first use, add to `AndroidManifest.xml`:

```xml
<service android:name="com.google.android.gms.metadata.ModuleDependencies"
         android:enabled="false" android:exported="false"
         tools:ignore="MissingClass">
  <intent-filter>
    <action android:name="com.google.android.gms.metadata.MODULE_DEPENDENCIES" />
  </intent-filter>
  <meta-data android:name="photopicker_activity:0:required" android:value="" />
</service>
```

URI lifetime: the grant lasts until device restart or until your process is stopped, and an app may hold at most 5,000 media grants. Neither matters here because we copy the bytes and re-encode immediately (§5); do **not** persist picker URIs into your database.

**Android 16+ polish (optional).** `EmbeddedPhotoPickerProvider` / the `EmbeddedPhotoPicker` Compose composable render the picker inside your own screen on a `SurfaceView`, with the same privacy properties and still no permission. Nice-to-have, Android 16 only, needs a fallback path anyway — treat as a later refinement. ([Android Developers Blog](https://developer.android.com/blog/posts/the-embedded-photo-picker))

#### `READ_MEDIA_IMAGES` — do not request it

Google Play's **Photo and Video Permissions** policy restricts `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`. Compliance deadline was **22 January 2025**, extendable to **28 May 2025**, after which non-compliant apps are subject to removal. ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/15800983))

To declare it you must submit a Play Console declaration arguing that broad access is *core functionality* and that the system picker is *technically insufficient*. Google's own guidance names gallery and photo-management apps as the qualifying category, and states explicitly that having built a custom picker is not a justification. ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/16935362))

**A stock-management app for a newsagency attaching one photo per product will be rejected.** The use case is the textbook example of "one-time or infrequent access", which the policy directs to the system picker. Requesting the permission buys nothing and risks suspension.

`READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial access) is not an escape hatch: it is declared alongside `READ_MEDIA_IMAGES`, still shows a runtime prompt, and still puts you inside the restricted-permission policy. ([Android docs](https://developer.android.com/about/versions/14/changes/partial-photo-video-access))

#### Camera

Launch the system camera with `MediaStore.ACTION_IMAGE_CAPTURE` plus a `FileProvider` output URI, or the AndroidX contract `ActivityResultContracts.TakePicture`.

**Do not declare `android.permission.CAMERA` in the manifest.** Without it, the system camera app handles capture and you need no runtime permission and no prompt. If you declare it — even accidentally, even via a library's manifest merge — Android forces you into the runtime permission flow for `ACTION_IMAGE_CAPTURE`. Check the merged manifest.

Also add so the app installs on tablets without cameras:

```xml
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### 1.3 Which approach avoids a permission prompt — the direct answer

| Platform | Photo library | Camera |
|---|---|---|
| **iOS** | `PHPickerViewController` → **no prompt** | Camera → **one unavoidable prompt** (`NSCameraUsageDescription`) |
| **Android** | Photo Picker (`PickVisualMedia`) → **no prompt** | `ACTION_IMAGE_CAPTURE` with `CAMERA` *not* in the manifest → **no prompt** |

So: **library access is prompt-free on both platforms**, and the only OS prompt in the entire product is the iOS camera one. Ship v1 with picker-only and the app asks for nothing.

---

## 2. iCloud Photos

### 2.1 Can a third party read a user's iCloud Photo Library?

**Not directly, and not from anywhere except an Apple device.**

- **There is no public iCloud Photos HTTP/REST API.** None has ever shipped. Apple offers no OAuth-style "connect your iCloud Photos" flow to third parties.
- **CloudKit does not help.** CloudKit Web Services and the server-to-server API operate on *your app's own containers*. The user's photo library lives in a private Apple system container that no third-party container can address. Apple's own developer relations answer to this exact question is that there is no way to access the photo library through CloudKit or a web API — a native app must go through the on-device Photos framework. ([Apple Developer Forums](https://developer.apple.com/forums/thread/74434))
- **iCloud Photos is not a file provider.** `UIDocumentPickerViewController` and the Files app can reach iCloud *Drive*, and any third-party File Provider extension (Google Drive, Dropbox, OneDrive). iCloud **Photos** is not exposed there.
- Commercial "iCloud API" services (e.g. Reincubate's ricloud) work by taking the user's Apple ID credentials and impersonating a device. **Do not use these.** They require handing over credentials, they break with every Apple security change, and they are a serious liability for a shop.

### 2.2 The mechanism that does work

On an iPhone with iCloud Photos enabled, **the Photos library and the iCloud Photos library are the same library**. Every asset appears in `PHPickerViewController` regardless of whether its full-resolution bytes are on the device. So:

> Picking from the iOS photo picker *is* picking from iCloud Photos. There is nothing extra to build.

The same applies through Safari's `<input type="file">` (§4.1) — that is the fallback for an owner who never installs the app.

### 2.3 Optimised storage — the low-res placeholder problem

With **Settings → Photos → Optimise iPhone Storage**, the local file for an older photo is a downscaled placeholder; the original is in iCloud. This is the default on most phones that have been in use for a while, so treat it as the normal case, not an edge case.

#### Detecting it and downloading — with `PHPickerViewController` (recommended path)

The picker's `NSItemProvider` handles the iCloud download for you, but *silently and slowly*. You do get a progress object — use it:

```swift
let provider = result.itemProvider
guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return }

// loadFileRepresentation returns a Progress; iCloud download is reported through it.
let progress = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
    // url is a temporary file, valid only inside this closure — copy it out immediately.
}

// Observe progress.fractionCompleted to drive a determinate progress bar.
let token = progress.observe(\.fractionCompleted) { p, _ in /* update UI on main queue */ }
```

Key behaviours:
- `progress.fractionCompleted` moves during the iCloud fetch, so a **determinate** bar is possible. When the asset is already local it completes almost instantly.
- Set a timeout (suggest **60 s** per image) and offer Retry. On a poor mobile connection a 12 MB original genuinely takes that long.
- **Low Data Mode** (per-Wi-Fi or cellular) can suppress or slow the download. Surface "Couldn't download from iCloud — check your connection or turn off Low Data Mode" rather than a generic failure.
- `progress.cancel()` on a Cancel button.

#### Detecting it and downloading — with `PHAsset` (only if you ever take library access)

Documented for completeness. This path requires `NSPhotoLibraryUsageDescription` and a permission prompt, so **it is not the recommended design**, but the flags are the ones people search for:

```swift
let options = PHImageRequestOptions()
options.isNetworkAccessAllowed = true      // DEFAULT IS false — nothing downloads without this
options.deliveryMode = .highQualityFormat
options.progressHandler = { fraction, error, stop, info in /* 0.0 ... 1.0 */ }
```

- `isNetworkAccessAllowed` defaults to **`false`**. This is the single most common bug: the request silently returns only a degraded local placeholder. ([Apple docs](https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed))
- In the result `info` dictionary:
  - `PHImageResultIsInCloudKey == true` → the asset is not local and requires a download.
  - `PHImageResultIsDegradedKey == true` → this callback delivered a placeholder; a better one is still coming. Do not upload a degraded result.
- The equivalent for full original bytes is `PHAssetResourceManager` with `PHAssetResourceRequestOptions.isNetworkAccessAllowed = true` and its own `progressHandler`.

### 2.4 Progress UI for a non-technical owner

Do not show percentages of bytes or the word "iCloud" in an error. Suggested states:

- 0–100 % bar with the label **"Getting your photo…"**
- After 8 s with no completion: **"This photo is stored in iCloud, so it's downloading. This can take a minute on mobile data."**
- On failure: **"Couldn't get that photo. Try again, or pick a different one."** with a Retry button.

### 2.5 If the owner uses Android

**There is no path from iCloud Photos to an Android device.** The only workaround is manual: sign in to icloud.com/photos in a browser, download the file, then attach it. Do not build anything for this; if it becomes a real need, the answer is "keep the shop photos on the iPhone" or "use Google Photos instead".

---

## 3. Google Photos

### 3.1 What was removed, and when

Announced September 2024, effective **31 March 2025**:

| Scope | Status |
|---|---|
| `https://www.googleapis.com/auth/photoslibrary` | **Removed** |
| `https://www.googleapis.com/auth/photoslibrary.readonly` | **Removed** |
| `https://www.googleapis.com/auth/photoslibrary.sharing` | **Removed** |

Calls relying only on these return **`403 PERMISSION_DENIED`** for all clients, existing ones included. The methods `albums.share`, `albums.unshare`, `sharedAlbums.get`, `sharedAlbums.join`, `sharedAlbums.leave` and `sharedAlbums.list` were withdrawn with them. ([Google — Updates to the Google Photos APIs](https://developers.google.com/photos/support/updates), [Google Developers Blog](https://developers.googleblog.com/en/google-photos-picker-api-launch-and-library-api-updates/))

### 3.2 What OAuth scopes remain

| Scope | What it allows |
|---|---|
| `.../auth/photospicker.mediaitems.readonly` | Picker API: create/get/delete sessions, list the media items the user picked |
| `.../auth/photoslibrary.appendonly` | Upload media and create albums (write-only) |
| `.../auth/photoslibrary.readonly.appcreateddata` | Read **only** items your own app uploaded |
| `.../auth/photoslibrary.edit.appcreateddata` | Edit albums/items your own app created |

Service accounts are **not supported** — user OAuth only. ([Google — Authorization scopes](https://developers.google.com/photos/overview/authorization))

### 3.3 What the Picker API can and cannot do

**Flow** ([Google — Get started](https://developers.google.com/photos/picker/guides/get-started-picker), [sessions](https://developers.google.com/photos/picker/guides/sessions), [media items](https://developers.google.com/photos/picker/guides/media-items)):

1. Obtain an OAuth 2.0 access token for `photospicker.mediaitems.readonly`.
2. `POST https://photospicker.googleapis.com/v1/sessions` → returns a session `id`, a `pickerUri`, and a `pollingConfig` (`pollInterval`, `timeoutIn`).
3. Send the user to `pickerUri`. This opens **Google's picker** — the Google Photos app if installed, otherwise a browser tab. For web callers, append `/autoclose` so the tab closes itself after selection.
4. Poll `GET /v1/sessions/{id}` at the interval the API tells you, until `mediaItemsSet == true`.
5. `GET /v1/mediaItems?sessionId={id}` for the picked items.
6. Fetch bytes from `mediaFile.baseUrl` with size parameters appended, e.g. `=w2048-h2048` (or add `-c` to crop). Width/height range is `[1, 16383]`.
7. `DELETE /v1/sessions/{id}`.

**Can:** let the user search, browse albums and select from their *entire* library — inside Google's UI.
**Cannot:**
- Render, list, search or thumbnail the library inside your app. You never see anything the user did not pick.
- Serve the result directly in an `<img src>`. **Requests to `baseUrl` must include an `Authorization: Bearer` header**, so you must fetch the bytes with code and re-host them.
- Rely on the URL later. **`baseUrl` is valid for 60 minutes**, and dies sooner if the user revokes access. Download and store immediately.
- Provide a native experience. **There is no Android or iOS SDK** — the integration is REST plus a hand-off to a browser/app and back.
- Access anything after the session is deleted.

Google also enforces undisclosed **session-creation rate limits** and asks you to delete sessions promptly.

### 3.4 Is a backend server required?

**Strictly, no — but practically, plan for one.**

- For an installed app (Android/iOS) or a browser app you use the **OAuth 2.0 flow for installed apps / PKCE**, which has no client secret, so no server is needed for the token exchange itself.
- A static web page can do the same with PKCE / Google Identity Services token client, again with no secret.
- **But** the bytes must be fetched with a bearer token and then stored somewhere, and this app needs *somewhere* regardless (§6). Once you have that Worker, doing the token exchange there is cleaner and keeps refresh tokens off the device.

### 3.5 The OAuth verification trap — this is the deal-breaker

`photospicker.mediaitems.readonly` is a sensitive scope; **apps must pass OAuth verification review** before general use. ([Google](https://developers.google.com/photos/overview/authorization))

For a two-user shop app the temptation is to leave the OAuth consent screen in **Testing** status (up to 100 test users). The consequence:

> **Refresh tokens issued by apps in Testing status expire after 7 days.**
> ([Google Cloud Help](https://support.google.com/cloud/answer/15549945), [Google OAuth 2.0 docs](https://developers.google.com/identity/protocols/oauth2))

The owner would be forced through a Google sign-in screen — complete with an "unverified app / Google hasn't verified this app → Advanced → Go to…" warning — **every week, forever**. For a non-technical user that is a support call every seven days. Escaping it means publishing the app and passing Google's verification review: a privacy policy on a verified domain, a demo video, a security questionnaire, and weeks of turnaround, for one user.

### 3.6 Verdict: skip the Google Photos API

**"Browse the user's whole Google Photos library in-app" is no longer possible.** It was possible until 31 March 2025 and is not coming back.

The correct answer for this shop is that **you do not need the API**:

- **On Android**, Google Photos acts as a **cloud media provider** for the Android system photo picker. With backup switched on, the owner's Google Photos cloud library — including photos not stored on the phone — appears *inside* the system picker, with albums and favourites. No OAuth, no scopes, no verification, no permission prompt. ([Android Developers Blog](https://android-developers.googleblog.com/2024/02/cloud-photos-now-available-in-android-photo-picker.html))
- **On iOS**, if a photo is in Google Photos but not in the iOS library, the owner opens Google Photos, taps Share → Save to device (or the iOS share sheet), and it is then in the picker. Two extra taps, once per photo.

Both routes deliver the same end state with none of the cost. Revisit only if the shop ever needs unattended, scheduled, server-side access to a Google Photos album — which the API can no longer provide anyway.

---

## 4. The web fallback

This matters more than it looks: it may be the whole product.

### 4.1 iOS Safari — `<input type="file" accept="image/*">`

Tapping the control shows an action sheet with:

1. **Photo Library** — the system photo picker. This is the **full iCloud Photos library**, cloud-only items included; Safari triggers the iCloud download itself (with no progress indication, so a big cloud-only photo just takes a while).
2. **Take Photo or Video** — the camera. **Safari asks for camera permission itself; your page never declares anything.**
3. **Choose File** — the Files app: On My iPhone, iCloud **Drive**, and any installed File Provider (Google Drive, Dropbox, OneDrive).

**Google Photos does not appear** in either the Photo Library picker or the Files browser on iOS — the Google Photos app ships no File Provider extension. iCloud Photos, on the other hand, is fully covered by option 1.

**HEIC behaviour — important.** When the photo is HEIC and `accept` does *not* list HEIC, Safari **transcodes to JPEG automatically** before handing the `File` to the page. However, from Safari 17, if `accept` contains **both** `image/*` and `image/heic`, Safari may hand over the untranslated HEIC instead. ([Apple Developer Forums](https://developer.apple.com/forums/thread/743049), [write-up](https://shkspr.mobi/blog/2020/12/coping-with-heic-in-the-browser/))

> **Rule: use `accept="image/*"` and never add `image/heic` or `image/heif` to it.** Still implement the HEIC fallback in §5.3 — Safari's conversion is helpful, not guaranteed, and other iOS browsers behave slightly differently.

### 4.2 Android Chrome — `<input type="file" accept="image/*">`

Chrome fires `ACTION_GET_CONTENT` with an image MIME filter. On Android 13+ the system routes that to the **Android Photo Picker**, so the owner gets the same picker the native app would get — **including Google Photos cloud items** when backup is on — plus a "Browse" escape hatch to the document picker.

**Known regression:** on Android 14 and 15, plain `accept="image/*"` lost the Camera tile in Chrome's chooser. Two workarounds:

- Add Chrome's non-standard hint: `accept="image/*,android/allowCamera"` (harmless elsewhere; ignored by other browsers), or
- Offer a **separate** camera button using `<input type="file" accept="image/*" capture="environment">`.
  ([addpipe write-up](https://blog.addpipe.com/html-file-input-accept-video-camera-option-is-missing-android-14-15/))

**Never put `capture` on the main input** — it *replaces* the library picker with the camera outright, which is the opposite of what is wanted.

### 4.3 Recommended markup

```html
<!-- Primary: library + iCloud Photos + Google Photos (Android) -->
<input id="photoPick" type="file" accept="image/*,android/allowCamera" multiple>

<!-- Optional explicit camera shortcut -->
<input id="photoShoot" type="file" accept="image/*" capture="environment">
```

Add `multiple` for the gallery uploader; drop it for a single product photo.

### 4.4 What the web fallback cannot do

- **It cannot store the file.** The current site (`knightsbridge-static/`) is plain HTML/JS with no server. Picking and resizing happen in the browser; the bytes then need a destination. Minimum viable destination: one Cloudflare Worker that mints a short-lived upload URL for R2 (§6).
- No background upload, no offline queue, no push. Fine for this use case.
- On iOS, an installed PWA's file input works the same as Safari's, so nothing is lost by going PWA.

### 4.5 Practical conclusion

For an owner who takes photos on an iPhone and wants them on the shop site, the web fallback delivers **essentially the full picking experience with zero platform API integration** — iCloud Photos included. It is the correct v1.

---

## 5. Image handling pipeline

Input reality: 3–12 MB, HEIC on iPhone (default "High Efficiency") or JPEG ("Most Compatible"); HEIC on newer Samsung/Pixel, JPEG elsewhere. Typically 4032×3024 (4:3) or 4032×2268 (16:9). EXIF carries orientation and, unless the owner turned it off, **GPS coordinates including their home address**.

### 5.1 Output targets

Current display sizes in the site: product card **≈400×170**, gallery tile **16:9**.

| Derivative | Long edge | Aspect | Format | Quality | Budget |
|---|---|---|---|---|---|
| `thumb` — product card 1× | 400 | 400×170 (crop, ~2.35:1) | WebP | 0.78 | ≤ 25 KB |
| `thumb@2x` — product card 2× | 800 | 800×340 | WebP | 0.78 | ≤ 60 KB |
| `tile` — gallery tile | 800 | 800×450 (16:9) | WebP | 0.80 | ≤ 90 KB |
| `tile@2x` / feature tile | 1600 | 1600×900 (16:9) | WebP | 0.78 | ≤ 250 KB |
| `master` | 1600 (long edge, uncropped) | native | WebP | 0.82 | ≤ 300 KB |

Keep the **master** so the crops can be regenerated if the design changes; never keep the camera original (12 MB × a few hundred products is real money and real upload time on a shop's connection).

**Cropping.** Centre-crop with `object-fit: cover` semantics: scale so the short side fills, crop the overflow equally. Do not letterbox. For gallery tiles, offer the owner a simple drag-to-reposition on the crop — one control, no zoom — or skip it in v1 and accept centre crop.

**Format.** WebP: supported by Safari 14+ / iOS 14+, Chrome, Firefox, Edge — safe universally in 2026, and 25–35 % smaller than JPEG at matched quality. Keep a JPEG q0.82 sibling only if analytics later show ancient clients; do not build it speculatively. AVIF compresses better but browser-side encoding is slow enough to be felt on a phone — not worth it here.

### 5.2 Pipeline order (do not reorder)

```
1. Sniff format               → is it HEIC/HEIF?
2. Decode                     → HEIC path (§5.3) or native decode
3. Apply EXIF orientation     → §5.4
4. Downscale to target        → two-step for large ratios, §5.6
5. Centre-crop to aspect
6. Re-encode to WebP          → this is what strips EXIF/GPS, §5.5
7. Verify size budget         → step quality down 0.05 and retry, max 3 attempts
8. Upload
```

Metadata stripping is a *consequence* of step 6, which is why step 6 must never be skipped — including for files that arrive already small enough.

### 5.3 HEIC / HEIF → JPEG or WebP

**No browser decodes HEIC natively, including Safari in 2026.** ([caniuse](https://caniuse.com/heif))

**Detection** — do not trust the filename or the MIME type (Safari renames files; Android often reports `application/octet-stream`). Sniff the ISO-BMFF box: bytes 4–8 are `ftyp`, and bytes 8–12 are one of `heic`, `heix`, `hevc`, `hevx`, `mif1`, `msf1`.

```js
async function isHeic(file) {
  const b = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  const s = String.fromCharCode(...b.subarray(4, 12));
  return s.startsWith('ftyp') &&
         /^(heic|heix|hevc|hevx|mif1|msf1)/.test(s.slice(4));
}
```

**Per platform:**

- **iOS native app** — free. Ask the `NSItemProvider` for `UTType.jpeg` (`loadDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier)`) and the system transcodes. Alternatively set `preferredAssetRepresentationMode = .compatible` on the picker configuration and iOS delivers JPEG. **Do not ship a HEIC decoder on iOS.**
- **Android native app** — `ImageDecoder` / `BitmapFactory` decode HEIF from API 28 (Android 9) upward. Below that, HEIC files are vanishingly rare; fall back to an error message.
- **Web** — lazy-load `heic2any` or `libheif-js` (libheif compiled to WebAssembly) **only when the sniff returns true**. The WASM bundle is 1–2 MB, so never load it eagerly. Decode is slow (1–3 s for a 12 MP image on a mid-range phone) — run it in a Web Worker and show a spinner. In practice iOS Safari will already have converted to JPEG (§4.1), so this path fires rarely; it is insurance, not the main road.

### 5.4 EXIF orientation

Photos taken in portrait or upside-down carry an EXIF `Orientation` tag of 1–8. Ignore it and product photos appear sideways.

**Web — the one-liner that gets it right:**

```js
const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
// 'from-image' is now the spec default, but state it explicitly —
// older engines defaulted to 'none'.
canvas.width = targetW; canvas.height = targetH;
ctx.drawImage(bitmap, sx, sy, sw, sh, 0, 0, targetW, targetH);
```

Because the bitmap is already rotated, the canvas output needs no orientation tag — orientation is *baked into the pixels*. That is the desired end state: no downstream consumer can get it wrong. ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap))

Note the historical trap: `ctx.drawImage(imgElement, …)` with an `<img>` source does **not** reliably apply EXIF orientation across engines. Use `createImageBitmap` on the `Blob`.

**Native** — `UIImage` exposes `imageOrientation`; re-encoding through `UIGraphicsImageRenderer` bakes it in. On Android, read `ExifInterface.TAG_ORIENTATION` and apply the matching `Matrix` rotation before re-encoding; `expo-image-manipulator` and `flutter_image_compress` both handle this for you.

### 5.5 Stripping EXIF GPS before upload

**Non-negotiable.** A photo of a stock item taken at home, published to the shop website, with `GPSLatitude`/`GPSLongitude` intact, publishes the owner's home address to anyone who downloads it.

**The method: re-encode through a canvas (web) or a bitmap (native).** A canvas holds pixels only. `canvas.toBlob()` writes a file with **no EXIF, no XMP, no IPTC, no GPS** — the metadata is not copied because there is nowhere for it to have been kept. This is more reliable than any tag-deletion library, because it cannot miss a container you did not know about.

```js
canvas.toBlob(blob => upload(blob), 'image/webp', 0.80);   // blob has no metadata
```

Consequences to be aware of:

- The **ICC colour profile is also dropped**. iPhone photos are Display P3; the canvas is sRGB by default. Wide-gamut colours will look slightly less saturated. For newsagency stock photos this is a fair trade and arguably desirable (consistent rendering everywhere). If it ever matters, request `canvas.getContext('2d', { colorSpace: 'display-p3' })` and encode accordingly — do not do this in v1.
- The capture timestamp is also gone. If you want "photographed on", capture it in your own database from `File.lastModified` at pick time.

**Native equivalents:** `expo-image-manipulator` strips EXIF on manipulation; `flutter_image_compress` has `keepExif: false` (the default); on iOS re-encoding a `UIImage` via `UIGraphicsImageRenderer` drops all metadata.

**Verify once, in a test:** upload a photo you know has GPS, download the stored object, and run `exiftool` over it. Assert the output contains no `GPS*` tags. Make it a checklist item before go-live, because this is the kind of thing that silently regresses.

### 5.6 Downscaling quality

Drawing a 4032 px image straight down to 400 px in one `drawImage` produces aliasing on fine detail — exactly the failure mode for a photo of a magazine cover with small text.

- Set `ctx.imageSmoothingQuality = 'high'`.
- For reductions greater than ~3×, downscale in **halving steps** (4032 → 2016 → 1008 → 504 → 400). Roughly doubles the work and visibly improves text legibility.
- Alternatively `createImageBitmap(file, { resizeWidth, resizeQuality: 'high' })` where supported — one call, engine-optimised.

### 5.7 Guard rails

- Reject files > 25 MB and images with either dimension > 12000 px (decode-bomb protection, and a phone will run out of memory anyway).
- Run decode/resize in a **Web Worker** with `OffscreenCanvas` so the UI does not freeze on a 12 MP image.
- Wrap the whole pipeline in try/catch; on any failure, keep the existing behaviour of the site — the generated `tagThumb` artwork already covers a missing photo (see `js/images.js`), so a failed photo is cosmetic, never blocking.
- Total budget check: a product page with 20 cards at 60 KB each is 1.2 MB. Acceptable with `loading="lazy"`.

---

## 6. Storage and delivery

### 6.1 Recommendation: Cloudflare R2 + one Worker + a custom subdomain

| Component | Role | Cost at this scale |
|---|---|---|
| **Cloudflare R2** bucket | Stores the derivatives | **$0** — free tier is 10 GB storage, 1 M Class A ops, 10 M Class B ops per month, **egress always free** |
| **Cloudflare Worker** | Issues short-lived presigned PUT URLs; nothing else | **$0** — free tier 100,000 requests/day |
| **Custom subdomain** (e.g. `images.knightsbridgenewsagency.com.au`) bound to the bucket | Public read | **$0** on an existing Cloudflare zone |

**Why R2 and not S3:** zero egress charges. Image delivery is almost entirely egress, and it is the line item that turns a small bill into a surprising one.

**Sizing sanity check:** 300 products × (25 + 60 + 300 KB) + 60 gallery photos × (90 + 250 KB) ≈ **135 MB**. That is 1.4 % of the free tier. Storage beyond it is $0.015/GB-month. Realistically this shop never pays Cloudflare anything.

**Two configuration points that bite people:**

1. **Do not serve from the `*.r2.dev` managed URL in production.** Cloudflare applies a variable rate limit (429s past a few hundred req/s) and throttles bandwidth, and explicitly documents it as not intended for production. Bind a custom domain — that also unlocks caching rules and analytics. ([Cloudflare docs](https://developers.cloudflare.com/r2/buckets/public-buckets/))
2. **Never put R2 credentials in the static site.** The Worker holds them; the browser only ever receives a presigned URL scoped to one object key with a short expiry (5 minutes) and a content-length cap.

### 6.2 Object layout

```
products/{sku}/{contentHash}-thumb.webp
products/{sku}/{contentHash}-thumb@2x.webp
products/{sku}/{contentHash}-master.webp
gallery/{slug}/{contentHash}-tile.webp
gallery/{slug}/{contentHash}-tile@2x.webp
manifest/gallery.json
manifest/stock.json
```

- **Content-hash the filename** (first 12 hex chars of a SHA-256 of the encoded bytes). Uploading a replacement writes a new key, so you never fight a CDN cache and never need a purge.
- Set `Cache-Control: public, max-age=31536000, immutable` on the images.
- Set `Cache-Control: public, max-age=60` on the manifests, so an edit shows on the website within a minute.

### 6.3 How the website loads them

The current gallery code (`knightsbridge-static/js/images.js`) already has exactly the right shape: a `GALLERY` array with an `src` field, a `data-art-fallback` attribute, and a capture-phase `error` listener that swaps in generated artwork when a photo fails. Keep all of that. Two changes:

1. Fetch `manifest/gallery.json` from the image domain at startup and let it supply `src`, `caption` and dimensions, falling back to the hard-coded `GALLERY` array when the fetch fails (offline, first run, DNS trouble). The owner then edits photos in the app, not in a JS file.
2. Emit `srcset` and explicit `width`/`height`:

```html
<img src="…/x-tile.webp"
     srcset="…/x-tile.webp 800w, …/x-tile@2x.webp 1600w"
     sizes="(max-width: 700px) 100vw, 33vw"
     width="800" height="450" loading="lazy" decoding="async"
     alt="…" data-art-fallback="Magazine">
```

`width`/`height` prevent layout shift; the existing fallback keeps the page from ever looking broken.

**Note on the existing Openverse behaviour.** Once the owner's own photos exist, the Openverse lookup in `images.js` should become the *last* fallback, not the first choice: owner photo → generated artwork → Openverse. Real shop photos need no attribution and no licence reasoning, which removes the site's most fragile dependency. Keep `imageCreditHTML` for whatever Openverse images remain.

### 6.4 Alternatives considered

| Option | Verdict |
|---|---|
| **Supabase Storage** (free: 1 GB storage, 5 GB egress) | Reasonable. Bundles auth and a JS client, so slightly less code if you also want a login. Tighter free tier; egress is metered. |
| **Cloudflare Images** ($5 per 100k stored, $1 per 100k delivered, 5,000 transformations/mo free) | Only worth it if you want server-side variants instead of client-side resizing. We resize on the client, so this is spend for nothing. |
| **Backblaze B2** (10 GB free) | Fine storage, but you would pair it with a CDN anyway. R2 is simpler. |
| **Images committed to the site repo / GitHub Pages** | Free, but the owner would need Git. Disqualified on the "non-technical owner" constraint. |
| **AWS S3 + CloudFront** | Works, more moving parts, and egress is billed. No advantage here. |

---

## 7. Privacy and store compliance

### 7.1 Apple — App Privacy ("nutrition label")

Photos are uploaded to a server and published on a public website, so they are **collected** in Apple's sense and must be declared.

| Field | Value |
|---|---|
| Data type | **User Content → Photos or Videos** |
| Collected | **Yes** |
| Used for tracking | **No** |
| Linked to the user's identity | **No** if the app has no accounts; **Yes** if you add a login |
| Purpose | **App Functionality** |

Also relevant:

- **Data type: Contact Info / Identifiers** — only if you add owner accounts. Avoid accounts in v1 (a shared secret link or a device-bound token is enough for one user) and this section stays empty.
- **`PrivacyInfo.xcprivacy` (privacy manifest)** — required for new and updated apps since **1 May 2024**. Declare `NSPrivacyCollectedDataTypes` with `NSPrivacyCollectedDataTypePhotosorVideos`, and declare any **required-reason APIs** you touch — most likely `NSPrivacyAccessedAPICategoryFileTimestamp` (reason `C617.1`) if you read file modification dates, and `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`). Third-party SDKs must ship their own manifests. ([Apple](https://developer.apple.com/app-store/app-privacy-details/))
- **Usage strings are reviewed.** Generic text ("This app needs camera access") is a common rejection. Be specific — see §7.3.
- Because we use `PHPickerViewController` there is **no photo-library usage string to justify at all**, which removes an entire review surface. Worth saying out loud in the review notes.

### 7.2 Google Play — Data safety

| Field | Value |
|---|---|
| Data type | **Photos and videos → Photos** |
| Collected | **Yes** (they are transmitted off the device) |
| Shared | **No** — Cloudflare is a service provider processing on your behalf, which Play treats as processing, not sharing |
| Purpose | **App functionality** |
| Required or optional | **Optional** (a product can be saved without a photo) |
| Encrypted in transit | **Yes** (HTTPS end to end) |
| User can request deletion | **Yes** — provide a Delete photo action in the app, and name it in the answer |

Google's rule: data that never leaves the device does not need to be declared as collected. Ours leaves the device, so it does. ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/10787469))

**The compliance win:** because the app declares **no** `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED` or `CAMERA` permission, **no Photo and Video Permissions declaration form is required at all**, and there is nothing for a reviewer to reject. This is the single strongest argument for the picker-only design.

**Also required by Play if you add accounts:** an in-app account deletion path plus a web-accessible deletion URL. Another reason not to add accounts.

### 7.3 Permission-priming copy

Show your own screen **before** the OS prompt, and only immediately after the owner has tapped something that obviously needs it. Never prime on app launch.

**iOS camera — priming screen (the only prompt in the app):**

> **Take a photo of this item**
> Knightsbridge uses your camera only when you tap "Take photo". Photos are attached to the stock item you're editing.
> Nothing is taken automatically, and nothing is uploaded until you tap Save.
> [ Not now ] [ Open camera ]

**`NSCameraUsageDescription` string (this is what the OS shows — be specific):**

> Knightsbridge uses the camera so you can photograph stock items to show on the shop website.

**Photo library — no prompt exists, so no priming screen.** Just a button:

> **Choose a photo** — Pick from your photos, including anything in iCloud.

**Before publishing to the public website — show this once, and remember the acknowledgement:**

> **This photo will appear on the shop's public website.**
> We automatically remove the location tag from every photo, so your address is never published.
> Please avoid photos that show customers' faces, staff rosters, or anything on the counter with a name or address on it.
> [ Cancel ] [ Publish photo ]

**While an iCloud photo downloads:**

> Getting your photo… (progress bar)
> *(after 8 seconds)* This one's stored in iCloud, so it's downloading. It can take a minute on mobile data.

### 7.4 Two non-technical notes worth recording

- **Faces of customers.** Publishing recognisable customers on the shop website without consent is a real risk, independent of any API. In Australia, a business with turnover under $3 million is generally exempt from the Privacy Act 1988, but the exemption is not a licence and does not cover defamation or plain bad feeling in a small suburb. The prompt above is the practical mitigation. (Not legal advice.)
- **Third-party product packaging** in a shop photo is fine — a photograph of your own shelves is your photograph. That is a materially better position than the Openverse/licensing route the site currently relies on, and is a good reason to push the owner to take real photos.

---

## 8. Recommended build order

1. **Web first.** Add a photo control to the owner's page in `knightsbridge-static/` using `<input type="file" accept="image/*,android/allowCamera">`, the §5 pipeline in a Web Worker, and a Cloudflare Worker + R2 for storage. This already covers camera, on-device photos, **iCloud Photos** (via iOS Safari) and **Google Photos** (via the Android system picker). No app store, no OAuth, no permissions. Days of work, $0/month.
2. **Make it installable.** Add a web app manifest and a service worker so the owner gets a home-screen icon. Costs almost nothing and removes the "where's my app" question.
3. **Only if genuinely needed**, wrap in a native shell: `PHPickerViewController` on iOS, `PickVisualMedia` on Android, `ACTION_IMAGE_CAPTURE` / camera picker for capture, and no photo permissions declared anywhere. The pipeline moves to `expo-image-manipulator` or equivalent; storage and delivery are unchanged.
4. **Never** integrate the Google Photos Picker API for this shop. Re-evaluate only if a requirement appears for unattended server-side access to a Google Photos album — and note the API cannot do that any more either.

### Pre-launch checklist

- [ ] `exiftool` on a downloaded stored object shows **no `GPS*` tags**
- [ ] A portrait photo and an upside-down photo both render the right way up
- [ ] A HEIC file from an iPhone completes the pipeline on Android Chrome (the WASM path)
- [ ] A cloud-only iCloud photo completes, with progress shown, on mobile data
- [ ] Merged Android manifest contains **no** `CAMERA` and **no** `READ_MEDIA_*` permission
- [ ] `r2.dev` does not appear in any production URL
- [ ] Deleting a photo in the app removes it from the website within 60 seconds
- [ ] The site still renders correctly with the image domain blocked (generated-artwork fallback)

---

## Appendix — sources

**Google Photos API changes**
- Updates to the Google Photos APIs — https://developers.google.com/photos/support/updates
- Picker API launch and Library API changes (announcement) — https://developers.googleblog.com/en/google-photos-picker-api-launch-and-library-api-updates/
- Authorization scopes — https://developers.google.com/photos/overview/authorization
- Picker API: get started — https://developers.google.com/photos/picker/guides/get-started-picker
- Picker API: sessions — https://developers.google.com/photos/picker/guides/sessions
- Picker API: media items (`baseUrl`, 60-minute expiry, Authorization header) — https://developers.google.com/photos/picker/guides/media-items
- OAuth 2.0 / refresh-token expiry for apps in Testing — https://developers.google.com/identity/protocols/oauth2
- Manage App Audience (100 test users, 7-day token expiry) — https://support.google.com/cloud/answer/15549945

**Android**
- Photo picker — https://developer.android.com/training/data-storage/shared/photo-picker
- Embedded photo picker (Android 16) — https://developer.android.com/training/data-storage/shared/photo-picker/embedded
- Embedded Photo Picker announcement — https://developer.android.com/blog/posts/the-embedded-photo-picker
- Cloud photos in the Android photo picker (Google Photos as cloud media provider) — https://android-developers.googleblog.com/2024/02/cloud-photos-now-available-in-android-photo-picker.html
- Cloud media provider guide — https://developer.android.com/guide/topics/providers/cloud-media-provider
- Partial photo and video access (Android 14) — https://developer.android.com/about/versions/14/changes/partial-photo-video-access
- Play: required actions for the Photo & Video Permissions policy (22 Jan / 28 May 2025) — https://support.google.com/googleplay/android-developer/answer/15800983
- Play: restricted permissions and minimum-scope alternatives — https://support.google.com/googleplay/android-developer/answer/16935362
- Play: Data safety section — https://support.google.com/googleplay/android-developer/answer/10787469
- Prioritise media privacy with the Android Photo Picker — https://android-developers.googleblog.com/2025/04/google-play-empowering-developers-to-build-user-trust-through-privacy.html

**Apple**
- `PHPickerViewController` — https://developer.apple.com/documentation/photosui/phpickerviewcontroller
- Selecting photos and videos in iOS — https://developer.apple.com/documentation/PhotoKit/selecting-photos-and-videos-in-ios
- `PHImageRequestOptions.isNetworkAccessAllowed` — https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed
- No iCloud Photo Library access via CloudKit or a web API — https://developer.apple.com/forums/thread/74434
- App privacy details on the App Store — https://developer.apple.com/app-store/app-privacy-details/
- Safari 17 HEIC `accept` behaviour — https://developer.apple.com/forums/thread/743049
- Handling iCloud assets (practical write-up) — https://www.swiftjectivec.com/icloud-photo-handling/

**Web platform**
- `createImageBitmap` / `imageOrientation` — https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap
- HEIF/HEIC browser support — https://caniuse.com/heif
- Coping with HEIC in the browser — https://shkspr.mobi/blog/2020/12/coping-with-heic-in-the-browser/
- Handling HEIC on the web (heic2any / libheif-js) — https://upsidelab.io/blog/handling-heic-on-the-web
- Android 14/15 missing camera option in Chrome file inputs — https://blog.addpipe.com/html-file-input-accept-video-camera-option-is-missing-android-14-15/
- Capturing an image from the user — https://web.dev/articles/media-capturing-images

**Storage**
- Cloudflare R2 public buckets and the `r2.dev` rate limit — https://developers.cloudflare.com/r2/buckets/public-buckets/
- Cloudflare R2 limits — https://developers.cloudflare.com/r2/platform/limits
