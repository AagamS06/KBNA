/* Knightsbridge Newsagency — product photos and the shop gallery.

   ---------------------------------------------------------------
   WHY THIS DOESN'T SEARCH GOOGLE IMAGES
   ---------------------------------------------------------------
   Two reasons, and the second is the one that matters.

   1. There is no image-search API a static page can call. Google's
      Custom Search JSON API needs a secret key, which in a build like
      this would sit in plain view in the page source for anyone to
      copy, and it stops at 100 lookups a day. Scraping the results
      page instead is blocked by the browser and breaks whenever
      Google changes its markup.

   2. Google Images is an index, not a library of images you may use.
      Almost everything it returns is under someone else's copyright —
      publisher cover art, press photography, brand product shots.
      Attaching those to items for sale on a shop's own website is
      publishing them commercially without a licence, which is what
      takedown notices and infringement claims are made of. The shop
      would be the one carrying that risk, not the search engine.

   So the lookup below uses Openverse instead — the Creative Commons
   search index (Flickr, museums, Wikimedia and others), filtered to
   images explicitly licensed for COMMERCIAL reuse. It behaves the way
   you asked for: type a product name, leave the photo blank, and a
   relevant photo is found and attached on its own. The difference is
   that the shop is allowed to use what comes back, and the credit the
   licence requires is captured and shown automatically.

   If you would rather use official product shots, the right route is
   the supplier's own media/trade pack — those come with permission
   attached. Drop the address straight into the "Photo web address"
   box and it wins over anything found here.
   --------------------------------------------------------------- */

const OPENVERSE_ENDPOINT = 'https://api.openverse.org/v1/images/';

/* Words in a stock name that hurt more than help as search terms —
   pack sizes, edition notes, and the like. */
const NOISE = /\(.*?\)|\b(\d+\s*(pack|pk|pg|pages|ml|g|cm|mm))\b|\b(weekday|weekend|assorted|classic|range|current|latest|issue|edition)\b/gi;

/** Turn "Crayola Coloured Pencils (12 pack)" into "Crayola Coloured Pencils". */
function imageQueryFor(name, tag) {
  const cleaned = String(name || '').replace(NOISE, ' ').replace(/\s+/g, ' ').trim();
  return cleaned.length >= 3 ? cleaned : String(tag || '').trim();
}

/** One Openverse call. Returns the first usable hit, or null. */
async function searchOpenverse(query, { signal } = {}) {
  const url = OPENVERSE_ENDPOINT
    + '?q=' + encodeURIComponent(query)
    + '&page_size=1'
    + '&license_type=commercial'   // only images we're allowed to use commercially
    + '&mature=false'
    + '&aspect_ratio=wide';        // product cards are 400x170
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error('Image search returned ' + res.status);
  const data = await res.json();
  const hit = (data.results || [])[0];
  if (!hit) return null;
  return {
    url: hit.url,
    title: hit.title || query,
    creator: hit.creator || 'Unknown',
    creator_url: hit.creator_url || '',
    license: (hit.license || '').toUpperCase(),
    license_version: hit.license_version || '',
    license_url: hit.license_url || '',
    landing: hit.foreign_landing_url || '',
    source: hit.source || 'openverse'
  };
}

/** Find a photo for a stock item. Tries the item name, then falls back to
 *  the category tag, then gives up quietly so the generated artwork is used.
 *  Never throws — a failed lookup must not block the owner saving an item. */
async function findProductImage(name, tag, { timeout = 8000 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const tries = [imageQueryFor(name, tag), String(tag || '')].filter(
      (q, i, a) => q && q.length >= 3 && a.indexOf(q) === i
    );
    for (const q of tries) {
      const hit = await searchOpenverse(q, { signal: controller.signal });
      if (hit) return hit;
    }
    return null;
  } catch {
    return null;                    // offline, blocked, or timed out
  } finally {
    clearTimeout(timer);
  }
}

/** The credit line a Creative Commons licence requires. */
function imageCreditHTML(credit) {
  if (!credit || !credit.creator) return '';
  const who = credit.creator_url
    ? `<a href="${esc(credit.creator_url)}" target="_blank" rel="noopener">${esc(credit.creator)}</a>`
    : esc(credit.creator);
  const lic = [credit.license, credit.license_version].filter(Boolean).join(' ');
  const licLink = credit.license_url
    ? `<a href="${esc(credit.license_url)}" target="_blank" rel="noopener">CC ${esc(lic)}</a>`
    : (lic ? `CC ${esc(lic)}` : '');
  return `<p class="image-credit">Photo by ${who}${licLink ? ' · ' + licLink : ''}</p>`;
}

/* ------------------------------------------------------------------
   THE GALLERY SECTION

   OWNER: replace `src` with photos of your own shop and these become
   real pictures — a phone photo of the magazine wall, the card racks,
   the counter at opening. Leave `src` empty and the tile falls back to
   the generated artwork for that category, so the section never looks
   broken while you're still collecting photos.

   Put your photos in an `images/` folder next to this file and use a
   plain relative address, e.g.  src: 'images/magazine-wall.jpg'
   ------------------------------------------------------------------ */
/* These stand-ins were resolved from Openverse ONCE, during development,
   and the results written in here by hand.

   They are deliberately not looked up at runtime. A visitor's browser must
   never call an image API just to draw the home page: it costs six network
   round trips before the section renders, it leaks every visitor to a third
   party, and Openverse's 20/minute limit is per IP address — so a school or
   an office behind one shared address would start seeing empty tiles.

   Each entry carries the credit its Creative Commons licence requires.
   Replace `src` with your own shop photos and the credit disappears with
   it, because then the photo is yours. */
const GALLERY = [
  { tag: 'Magazine', feature: true,
    caption: 'The magazine wall — puzzlers, glossies, motoring and craft',
    src: 'https://upload.wikimedia.org/wikipedia/commons/a/a9/Used_Car_Expert_magazine_in_WH_Smith.jpg',
    credit: { creator: 'UsedCarExpert.co.uk', creator_url: '', license: 'BY-SA', license_version: '3.0',
              license_url: 'https://creativecommons.org/licenses/by-sa/3.0/' } },
  { tag: 'Paper',
    caption: 'Papers in early, every morning of the week',
    src: 'https://live.staticflickr.com/7443/9559519298_693de78034_b.jpg',
    credit: { creator: 'shauser', creator_url: 'https://www.flickr.com/photos/73993978@N00',
              license: 'BY', license_version: '2.0',
              license_url: 'https://creativecommons.org/licenses/by/2.0/' } },
  { tag: 'Cards',
    caption: 'Cards for birthdays, sympathy, new baby and just because',
    src: 'https://live.staticflickr.com/215/504992369_bf909ba210_m.jpg',
    credit: { creator: 'nomi49', creator_url: 'https://www.flickr.com/photos/63846686@N00',
              license: 'BY', license_version: '2.0',
              license_url: 'https://creativecommons.org/licenses/by/2.0/' } },
  { tag: 'Gifts',
    caption: 'Gift lines, wrap and candles by the counter',
    src: 'https://live.staticflickr.com/2791/4393262126_09be5e0c41_b.jpg',
    credit: { creator: 'andymangold', creator_url: 'https://www.flickr.com/photos/30116130@N03',
              license: 'BY', license_version: '2.0',
              license_url: 'https://creativecommons.org/licenses/by/2.0/' } },
  { tag: 'Toys',
    caption: 'Little treats and toys for the kids',
    src: 'https://live.staticflickr.com/6162/6155651060_fe787c1b17_b.jpg',
    credit: { creator: 'PINTOY®', creator_url: 'https://www.flickr.com/photos/67321821@N06',
              license: 'BY-SA', license_version: '2.0',
              license_url: 'https://creativecommons.org/licenses/by-sa/2.0/' } },
  { tag: 'Lottery',
    caption: 'Lotto, scratchies and a lucky counter',
    src: 'https://live.staticflickr.com/3100/3159183511_5070d61610_b.jpg',
    credit: { creator: 'Montage Communications', creator_url: 'https://www.flickr.com/photos/92118646@N00',
              license: 'BY-SA', license_version: '2.0',
              license_url: 'https://creativecommons.org/licenses/by-sa/2.0/' } }
];

/** Markup for one gallery tile. Uses a real photo when one is set,
 *  and the generated category artwork when it isn't. */
function galleryTileHTML(item, credit) {
  const media = item.src
    ? `<img src="${esc(item.src)}" alt="${esc(item.caption)}" width="800" height="600" loading="lazy"
            data-art-fallback="${esc(item.tag)}">`
    : tagThumb(item.tag, item.caption);
  return `
    <li class="gallery-item${item.feature ? ' is-feature' : ''}" data-gallery-tag="${esc(item.tag)}">
      <figure>
        <div class="gallery-media">${media}</div>
        <figcaption>${esc(item.caption)}${credit ? imageCreditHTML(credit) : ''}</figcaption>
      </figure>
    </li>`;
}

/** Renders the gallery straight away using the generated artwork, then
 *  quietly upgrades any tile without its own photo to a real licensed one.
 *  Nothing here blocks the page: offline, the drawn artwork simply stays. */
/** Renders the gallery. Entirely local — no network calls, no waiting.
 *  A photo the owner picked off their phone wins; otherwise the stand-in
 *  above is used; if that fails to load, the drawn artwork takes over. */
function renderGallery(mountId, items = GALLERY) {
  const el = document.getElementById(mountId);
  if (!el) return;

  /* Photos the owner picked off their own phone beat everything else, and
     need no credit line because the shop took them. */
  const own = typeof readOwnPhotos === 'function' ? readOwnPhotos() : {};

  const paint = () => {
    el.innerHTML = items.map(item =>
      own[item.tag]
        ? galleryTileHTML({ ...item, src: own[item.tag] }, null)
        : galleryTileHTML(item, item.credit || null)
    ).join('');
    if (typeof decorateGalleryForPicking === 'function') decorateGalleryForPicking(el, items, paint);
  };
  paint();
}

/* If a remote photo fails to load — the shop is offline, the address is
   wrong, or the host has gone away — quietly swap in the generated
   artwork for that category so no card is left with a broken image.
   `error` doesn't bubble, so this listens on the capture phase. */
document.addEventListener('error', (e) => {
  const img = e.target;
  if (!(img instanceof HTMLImageElement)) return;
  const tag = img.dataset.artFallback;
  if (tag == null) return;
  const holder = img.parentElement;
  if (holder) holder.innerHTML = tagThumb(tag, img.alt || '');
}, true);
