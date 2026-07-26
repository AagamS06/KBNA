/* Knightsbridge Newsagency — customer reviews + outbound links.

   Everything the shop links out to on the real web lives in BUSINESS_LINKS
   below, so there is exactly one place to edit when a detail changes. */

/* ------------------------------------------------------------------
   OWNER: paste your Google Place ID here to turn the "Write a review"
   button into a one-tap deep link that opens the review box directly.

   Find it at  https://developers.google.com/maps/documentation/places/web-service/place-id
   (search your business, copy the "ChIJ..." string).

   Left blank, the button still works — it opens your Google listing,
   where the customer taps "Write a review". One extra tap, no setup.
   ------------------------------------------------------------------ */
const GOOGLE_PLACE_ID = '';

const BUSINESS = {
  name: 'Knightsbridge Newsagency',
  street: 'Shop 5, 159 Ridgecrop Drive',
  suburb: 'Castle Hill NSW 2154',
  phone: '02 9634 1591',
  phoneHref: 'tel:+61296341591',
  /* Confirmed by the shop. The online directories disagree with each other
     and with this, so change it here and nowhere else — the footer and the
     contact page both read from this one list. */
  hours: [
    ['Monday to Friday', '8am – 6pm'],
    ['Saturday and Sunday', '8am – 4pm']
  ]
};

const MAPS_QUERY = encodeURIComponent(
  `${BUSINESS.name}, ${BUSINESS.street}, ${BUSINESS.suburb}`
);

const BUSINESS_LINKS = {
  /* Google Maps URL API — documented, stable, and needs no API key. */
  maps: `https://www.google.com/maps/search/?api=1&query=${MAPS_QUERY}`,
  reviews: `https://www.google.com/maps/search/?api=1&query=${MAPS_QUERY}`,
  writeReview: GOOGLE_PLACE_ID
    ? `https://search.google.com/local/writereview?placeid=${GOOGLE_PLACE_ID}`
    : `https://www.google.com/maps/search/?api=1&query=${MAPS_QUERY}`,
  centre: 'https://www.knightsbridgeshoppingcentre.com.au/knightsbridge-newsagency/',
  yelp: 'https://www.yelp.com/biz/knightsbridge-newsagency-castle-hill',
  lott: 'https://www.thelott.com/',
  phone: BUSINESS.phoneHref
};

/* Overall Google rating, shown above the slideshow.
   OWNER: update these two numbers whenever you like — they're just text. */
const REVIEW_SUMMARY = { rating: 4.2, count: 147, source: 'Google' };

/* ------------------------------------------------------------------
   The reviews shown in the slideshow.

   OWNER: these are real comments left on the shop's Google listing.
   To swap in your current favourites, open your Google Business Profile,
   copy the wording exactly, and edit the list below. Keep `stars` honest —
   it should match the rating the customer actually left.
   ------------------------------------------------------------------ */
const REVIEWS = [
  {
    quote: "Quick to come out from behind the counter and find me what I was looking for. Only a little newsagents but all the best stuff.",
    author: 'Rosslyn',
    stars: 5,
    source: 'Google review'
  },
  {
    quote: "The owner of the shop is a lovely and funny guy. Me and my husband received great service and a good amount of crossword and puzzle games to pick from.",
    author: 'Manon',
    stars: 5,
    source: 'Google review'
  },
  {
    quote: "A wonderful little newsagency. Nice range of gifts, lots of magazines, lottery tickets, cards. Friendly staff.",
    author: 'Helen',
    stars: 5,
    source: 'Google review'
  },
  {
    quote: "Great friendly service.",
    author: 'Google reviewer',
    stars: 5,
    source: 'Google review'
  }
];

/* Star glyphs. Decorative for sighted readers; the caller pairs them with
   a visually-hidden sentence so screen readers hear "5 out of 5 stars"
   rather than four identical star characters. */
function starsHTML(rating, extraClass = '') {
  const filled = Math.round(rating);
  const stars = '★'.repeat(filled) + `<span class="stars-dim">${'☆'.repeat(5 - filled)}</span>`;
  return `<span class="stars ${extraClass}" aria-hidden="true">${stars}</span>`;
}

/* Small monochrome verified tick. Deliberately NOT Google's multicolour "G":
   the mark and wording stay neutral so we don't reproduce a trademark. */
const VERIFIED_TICK =
  `<svg class="review-verified" viewBox="0 0 20 20" width="15" height="15" aria-hidden="true" focusable="false">
     <circle cx="10" cy="10" r="10" fill="currentColor"></circle>
     <path d="M5.8 10.4l2.6 2.6 5.8-5.9" fill="none" stroke="#0E0E0E" stroke-width="2.1"
           stroke-linecap="round" stroke-linejoin="round"></path>
   </svg>`;

/** One review card for the testimonials grid. `esc()` guards every string. */
function reviewCardHTML(r, i) {
  const name = String(r.author || 'Google reviewer').trim() || 'Google reviewer';
  const initial = esc((name.match(/[A-Za-z0-9]/)?.[0] || 'G').toUpperCase());
  const when = esc(r.source || 'Google review');
  const quote = String(r.quote || '');

  // Truncate long quotes at a word boundary and offer a Read more toggle.
  const LIMIT = 120;
  let body;
  if (quote.length > LIMIT) {
    let cut = quote.slice(0, LIMIT);
    const sp = cut.lastIndexOf(' ');
    if (sp > 70) cut = cut.slice(0, sp);
    body =
      `<span class="rt-short">${esc(cut)}… </span>` +
      `<span class="rt-full" hidden>${esc(quote)} </span>` +
      `<button type="button" class="review-more" data-rmore aria-expanded="false">Read more</button>`;
  } else {
    body = esc(quote);
  }

  return `
    <figure class="review-card" role="group" aria-roledescription="review"
            aria-label="Review ${i + 1} by ${esc(name)}">
      <div class="review-head">
        <span class="review-avatar" aria-hidden="true">${initial}</span>
        <span class="review-who">
          <span class="review-name">${esc(name)}<span class="review-verified-wrap" title="Verified review">${VERIFIED_TICK}<span class="visually-hidden"> — verified review</span></span></span>
          <span class="review-time">${when}</span>
        </span>
      </div>
      <p class="review-stars">
        ${starsHTML(r.stars)}
        <span class="visually-hidden">Rated ${r.stars} out of 5 stars.</span>
      </p>
      <p class="review-text">${body}</p>
      <span class="review-via">via ${esc(REVIEW_SUMMARY.source)}</span>
    </figure>`;
}

/** Testimonials section: dark band, a rating panel on the left and a paged
 *  grid of our real Google reviews on the right.
 *
 *  Auto-rotate keeps the same contract as before — a visible pause control,
 *  silent while auto-rotating, paused on hover / keyboard focus, and switched
 *  off entirely for prefers-reduced-motion. The prev/next arrows page through
 *  the reviews (two cards per page on desktop, one on mobile). */
function initReviewsSection(mountId, reviews, { interval = 6500 } = {}) {
  const root = document.getElementById(mountId);
  if (!root || !reviews.length) return;

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const wide = window.matchMedia('(min-width: 48rem)');
  const { rating, source } = REVIEW_SUMMARY;

  let page = 0;
  let timer = null;
  let playing = !reduceMotion;
  let userPaused = false;

  root.innerHTML = `
    <div class="testi-header">
      <div class="testi-intro">
        <span class="eyebrow">Testimonials</span>
        <h2 id="reviews-h" class="testi-title">What our<br><span class="testi-accent">customers say</span></h2>
      </div>
      <div class="testi-nav">
        <button class="testi-arrow" type="button" data-rnav="prev" aria-label="Previous reviews">
          <span aria-hidden="true">‹</span>
        </button>
        <button class="testi-arrow" type="button" data-rnav="next" aria-label="Next reviews">
          <span aria-hidden="true">›</span>
        </button>
        <button class="testi-arrow testi-play" type="button" data-rnav="toggle"
                aria-label="${playing ? 'Pause automatic review rotation' : 'Start automatic review rotation'}">
          <span aria-hidden="true">${playing ? '❚❚' : '▶'}</span>
        </button>
      </div>
    </div>
    <div class="testi-body">
      <aside class="testi-summary">
        <span class="rating-score">${esc(rating)}</span>
        ${starsHTML(rating, 'stars-lg')}
        <span class="visually-hidden">Rated ${esc(rating)} out of 5 stars.</span>
        <p class="rating-caption">Rated by locals on ${esc(source)}</p>
        <a class="btn btn-primary" href="${BUSINESS_LINKS.reviews}" target="_blank" rel="noopener">Review on ${esc(source)}</a>
      </aside>
      <div class="testi-cards" role="group" aria-label="Customer reviews" aria-live="off">
        ${reviews.map(reviewCardHTML).join('')}
      </div>
    </div>`;

  const cardsWrap = root.querySelector('.testi-cards');
  const cardEls = [...root.querySelectorAll('.review-card')];
  const toggleBtn = root.querySelector('[data-rnav="toggle"]');

  const perView = () => (wide.matches ? 2 : 1);
  const pageCount = () => Math.max(1, Math.ceil(reviews.length / perView()));

  function render(fromUser = false) {
    const pv = perView();
    const pages = pageCount();
    page = ((page % pages) + pages) % pages;
    const start = page * pv;
    cardEls.forEach((el, i) => {
      const shown = i >= start && i < start + pv;
      el.classList.toggle('is-shown', shown);
      el.hidden = !shown;               // drop hidden cards from tab order + a11y tree
    });
    cardsWrap.setAttribute('aria-live', fromUser ? 'polite' : 'off');
  }

  function goTo(next, fromUser = false) { page = next; render(fromUser); }

  function start() {
    if (reduceMotion || userPaused) return;
    stop();
    timer = setInterval(() => goTo(page + 1), interval);
    playing = true;
    syncToggle();
  }
  function stop() { if (timer) clearInterval(timer); timer = null; }
  function pause(byUser = false) {
    stop();
    if (byUser) { userPaused = true; playing = false; syncToggle(); }
  }
  function syncToggle() {
    toggleBtn.setAttribute('aria-label', playing ? 'Pause automatic review rotation' : 'Start automatic review rotation');
    toggleBtn.querySelector('span').textContent = playing ? '❚❚' : '▶';
  }

  root.addEventListener('click', (e) => {
    const more = e.target.closest('[data-rmore]');
    if (more) {
      const card = more.closest('.review-card');
      const expanded = more.getAttribute('aria-expanded') === 'true';
      card.querySelector('.rt-short').hidden = !expanded;
      card.querySelector('.rt-full').hidden = expanded;
      more.setAttribute('aria-expanded', String(!expanded));
      more.textContent = expanded ? 'Read more' : 'Show less';
      return;
    }
    const nav = e.target.closest('[data-rnav]')?.dataset.rnav;
    if (nav === 'prev') { goTo(page - 1, true); if (playing) start(); }
    if (nav === 'next') { goTo(page + 1, true); if (playing) start(); }
    if (nav === 'toggle') {
      if (playing) pause(true);
      else { userPaused = false; start(); }
    }
  });

  // Left / right arrow keys page through when focus is inside the section.
  root.addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
    if (e.target.closest('.review-more')) return;   // let buttons behave normally
    e.preventDefault();
    goTo(page + (e.key === 'ArrowRight' ? 1 : -1), true);
    if (playing) start();
  });

  // Re-flow when crossing the 1-card / 2-card breakpoint.
  const onBreakpoint = () => render();
  if (wide.addEventListener) wide.addEventListener('change', onBreakpoint);
  else if (wide.addListener) wide.addListener(onBreakpoint);

  // Preserve the original pause-on-hover / pause-on-focus behaviour.
  root.addEventListener('mouseenter', () => stop());
  root.addEventListener('mouseleave', () => { if (playing && !userPaused) start(); });
  root.addEventListener('focusin', () => stop());
  root.addEventListener('focusout', (e) => {
    if (!root.contains(e.relatedTarget) && playing && !userPaused) start();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop(); else if (playing && !userPaused) start();
  });

  render();
  if (reduceMotion) { playing = false; syncToggle(); } else { start(); }
}
