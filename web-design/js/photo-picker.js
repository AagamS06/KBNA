/* Knightsbridge Newsagency — picking photos off a phone.

   ---------------------------------------------------------------
   WHAT "CONNECT TO ICLOUD / GOOGLE PHOTOS" ACTUALLY MEANS ON THE WEB
   ---------------------------------------------------------------
   Neither service can be browsed from a web page, and it is worth
   being precise about why, because the workaround below is better
   than it sounds.

   iCloud Photos has no public API of any kind for third parties.
   Apple exposes the photo library only to native iOS apps, through
   PhotoKit. There is no web endpoint to connect to — not one that
   needs a key, not one behind OAuth. It does not exist.

   Google Photos used to offer a Library API that could read a user's
   whole library. Google withdrew that access for third-party apps in
   2025; what remains is a Picker flow where the user hand-picks items,
   and it needs OAuth credentials and a server to exchange the token.
   Neither is possible in a static page with no backend.

   What DOES work, on every phone, with no API, no key, no account and
   no permission prompt, is the file input below. Tapping it opens the
   operating system's own photo picker:

     iOS      — the system picker, which lists the user's iCloud
                Photos library. An iCloud-optimised photo is fetched
                down from iCloud automatically before it is handed
                over, so "connected to iCloud" is simply true.
     Android  — the system picker, with Google Photos as a source
                alongside local storage and Drive.

   So the owner taps "Choose a photo", sees their iCloud or Google
   Photos library, picks one, and it lands here. That is the outcome
   that was wanted; it just arrives through the OS rather than through
   an API integration. Full library access — searching, browsing by
   album, syncing automatically — needs the native app, where PhotoKit
   and the Android photo picker are available.
   --------------------------------------------------------------- */

/* Phone photos are 3-12MB. Anything stored here has to fit in
   localStorage alongside the stock list, so pictures are scaled down
   and re-encoded before they are kept. */
const PHOTO_MAX_EDGE = 1200;     // px on the longest side
const PHOTO_QUALITY  = 0.75;     // JPEG quality
const PHOTO_MAX_BYTES = 600_000; // refuse anything still huge after scaling

/** Open the phone's photo library (or camera) and hand back the chosen file.
 *  Resolves with null if the person backs out. */
function choosePhotoFile({ camera = false } = {}) {
  return new Promise(resolve => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    // `capture` opens the camera directly; without it the OS shows the
    // full library, which is where iCloud and Google Photos live.
    if (camera) input.capture = 'environment';
    input.style.cssText = 'position:fixed;left:-9999px';
    document.body.appendChild(input);
    input.addEventListener('change', () => {
      const file = input.files && input.files[0];
      input.remove();
      resolve(file || null);
    }, { once: true });
    // Safari fires no event when the picker is dismissed, so the promise
    // simply never settles in that case — harmless, the element is gone.
    input.click();
  });
}

/** Scale a chosen photo down and re-encode it as JPEG.
 *
 *  Re-encoding through a canvas throws away every EXIF tag, which is the
 *  point: phone photos carry GPS coordinates, and a shop owner uploading
 *  a picture taken at home should not be publishing their home address.
 *  Orientation is read before the metadata is dropped so portrait photos
 *  don't come out sideways. */
async function shrinkPhoto(file, { maxEdge = PHOTO_MAX_EDGE, quality = PHOTO_QUALITY } = {}) {
  if (!file || !file.type.startsWith('image/')) {
    throw new Error('That file is not an image.');
  }
  let bitmap;
  try {
    // imageOrientation applies the EXIF rotation while decoding.
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  } catch {
    // Chrome on Android can't decode HEIC. iPhones normally convert on
    // share, but not always — say something a shopkeeper can act on.
    throw new Error(
      'That photo is in a format this browser can\'t read (usually HEIC). ' +
      'On iPhone: Settings → Camera → Formats → "Most Compatible", then retake it.'
    );
  }
  const scale = Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height));
  const w = Math.round(bitmap.width * scale);
  const h = Math.round(bitmap.height * scale);

  const canvas = document.createElement('canvas');
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(bitmap, 0, 0, w, h);
  bitmap.close?.();

  const dataUrl = canvas.toDataURL('image/jpeg', quality);
  const bytes = Math.round((dataUrl.length - dataUrl.indexOf(',') - 1) * 0.75);
  if (bytes > PHOTO_MAX_BYTES) {
    // One more pass at lower quality rather than failing outright.
    const smaller = canvas.toDataURL('image/jpeg', 0.6);
    return { dataUrl: smaller, width: w, height: h,
             bytes: Math.round((smaller.length - smaller.indexOf(',') - 1) * 0.75) };
  }
  return { dataUrl, width: w, height: h, bytes };
}

/** Pick a photo and get it back ready to store. Returns null if cancelled. */
async function pickAndPreparePhoto(opts) {
  const file = await choosePhotoFile(opts);
  if (!file) return null;
  return shrinkPhoto(file, opts);
}

/* ------------------------------------------------------------------
   Gallery photos chosen on this device.

   Kept apart from the Openverse cache so that replacing a stand-in with
   a real photo of the shop is permanent, and clearing the cache never
   throws the owner's own pictures away.
   ------------------------------------------------------------------ */
const OWN_PHOTOS_KEY = 'kn.ownGalleryPhotos';

function readOwnPhotos() {
  try { return JSON.parse(localStorage.getItem(OWN_PHOTOS_KEY)) || {}; }
  catch { return {}; }
}

function saveOwnPhoto(tag, dataUrl) {
  const all = readOwnPhotos();
  all[tag] = dataUrl;
  try {
    localStorage.setItem(OWN_PHOTOS_KEY, JSON.stringify(all));
    return { ok: true };
  } catch {
    return { ok: false, error:
      'This browser is out of storage room for photos. Remove one before adding another.' };
  }
}

function removeOwnPhoto(tag) {
  const all = readOwnPhotos();
  delete all[tag];
  try { localStorage.setItem(OWN_PHOTOS_KEY, JSON.stringify(all)); } catch { /* nothing to do */ }
}

/* ------------------------------------------------------------------
   Photo-swap controls on the gallery.

   Managing the shop is the app's job now, so these are not part of the
   public page: they appear only when the address ends in ?photos, which
   is how the owner opens the gallery to change a picture from a phone
   without needing a login the site no longer has.

       index.html?photos
   ------------------------------------------------------------------ */
function galleryPickingEnabled() {
  return new URLSearchParams(location.search).has('photos');
}

function decorateGalleryForPicking(mount, items, repaint) {
  if (!galleryPickingEnabled()) return;

  mount.querySelectorAll('.gallery-item').forEach(li => {
    const tag = li.dataset.galleryTag;
    const has = !!readOwnPhotos()[tag];
    const bar = document.createElement('p');
    bar.className = 'gallery-actions';
    bar.innerHTML = `
      <button class="btn btn-small btn-secondary" data-pick="${esc(tag)}">
        ${has ? 'Replace photo' : 'Choose a photo'}
      </button>
      ${has ? `<button class="btn btn-small btn-danger" data-unpick="${esc(tag)}">Remove</button>` : ''}
      <span class="gallery-status" role="status"></span>`;
    li.querySelector('figure').appendChild(bar);
  });

  if (mount.dataset.pickerWired) return;
  mount.dataset.pickerWired = '1';

  mount.addEventListener('click', async (e) => {
    const pick = e.target.closest('[data-pick]')?.dataset.pick;
    const unpick = e.target.closest('[data-unpick]')?.dataset.unpick;

    if (unpick) { removeOwnPhoto(unpick); repaint(); return; }
    if (!pick) return;

    const status = e.target.closest('figure').querySelector('.gallery-status');
    try {
      status.textContent = 'Opening your photos…';
      const photo = await pickAndPreparePhoto();
      if (!photo) { status.textContent = ''; return; }
      status.textContent = 'Saving…';
      const saved = saveOwnPhoto(pick, photo.dataUrl);
      if (!saved.ok) { status.textContent = saved.error; return; }
      repaint();
    } catch (err) {
      status.textContent = err.message;
    }
  });
}
