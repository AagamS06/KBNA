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

/** Markup for the rating summary block above the slideshow. */
function ratingSummaryHTML() {
  const { rating, count, source } = REVIEW_SUMMARY;
  return `
    <p class="rating-summary">
      <span class="rating-score">${rating}</span>
      ${starsHTML(rating, 'stars-lg')}
      <span class="visually-hidden">Rated ${rating} out of 5 stars.</span>
      <span class="rating-meta">
        from ${count} ${esc(source)} reviews ·
        <a href="${BUSINESS_LINKS.reviews}" target="_blank" rel="noopener">Read them all on ${esc(source)}</a>
      </span>
    </p>`;
}

/** Accessible one-at-a-time review slideshow.
 *  Same contract as the hero carousel: visible pause control, pauses on
 *  hover and keyboard focus, silent while auto-rotating, and switched off
 *  entirely when the visitor asks for reduced motion. */
function initReviewSlider(mountId, reviews, { interval = 7000 } = {}) {
  const root = document.getElementById(mountId);
  if (!root || !reviews.length) return;

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let index = 0;
  let timer = null;
  let playing = !reduceMotion;
  let userPaused = false;

  root.setAttribute('role', 'region');
  root.setAttribute('aria-roledescription', 'carousel');
  root.setAttribute('aria-label', 'Customer reviews');

  root.innerHTML = `
    <div class="review-track" aria-live="off">
      ${reviews.map((r, i) => `
        <div class="review-slide ${i === 0 ? 'is-active' : ''}"
             role="group" aria-roledescription="slide"
             aria-label="Review ${i + 1} of ${reviews.length}"
             ${i === 0 ? '' : 'aria-hidden="true"'}>
          <figure class="review-card">
            <p class="review-rating">
              ${starsHTML(r.stars)}
              <span class="visually-hidden">Rated ${r.stars} out of 5 stars.</span>
            </p>
            <blockquote><p>${esc(r.quote)}</p></blockquote>
            <figcaption>
              <footer>
                <span class="review-author">${esc(r.author)}</span>
                <span>${esc(r.source)}</span>
              </footer>
            </figcaption>
          </figure>
        </div>`).join('')}
    </div>
    <div class="review-controls">
      <button class="review-btn" type="button" data-rnav="prev" aria-label="Previous review">
        <span aria-hidden="true">‹</span>
      </button>
      <div class="review-dots" role="tablist" aria-label="Choose review">
        ${reviews.map((r, i) => `
          <button class="review-dot ${i === 0 ? 'is-active' : ''}" type="button" role="tab"
                  data-rdot="${i}" aria-selected="${i === 0}"
                  aria-label="Review ${i + 1} by ${esc(r.author)}"></button>`).join('')}
      </div>
      <button class="review-btn" type="button" data-rnav="next" aria-label="Next review">
        <span aria-hidden="true">›</span>
      </button>
      <button class="review-btn review-play" type="button" data-rnav="toggle"
              aria-label="${playing ? 'Pause automatic review rotation' : 'Start automatic review rotation'}">
        <span aria-hidden="true">${playing ? '❚❚' : '▶'}</span>
      </button>
    </div>`;

  const slideEls = [...root.querySelectorAll('.review-slide')];
  const dotEls = [...root.querySelectorAll('.review-dot')];
  const track = root.querySelector('.review-track');
  const toggleBtn = root.querySelector('[data-rnav="toggle"]');

  function goTo(next, fromUser = false) {
    index = (next + reviews.length) % reviews.length;
    slideEls.forEach((el, i) => {
      const active = i === index;
      el.classList.toggle('is-active', active);
      if (active) el.removeAttribute('aria-hidden'); else el.setAttribute('aria-hidden', 'true');
    });
    dotEls.forEach((d, i) => {
      d.classList.toggle('is-active', i === index);
      d.setAttribute('aria-selected', String(i === index));
    });
    track.setAttribute('aria-live', fromUser ? 'polite' : 'off');
  }

  function start() {
    if (reduceMotion || userPaused) return;
    stop();
    timer = setInterval(() => goTo(index + 1), interval);
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
    const nav = e.target.closest('[data-rnav]')?.dataset.rnav;
    const dot = e.target.closest('[data-rdot]')?.dataset.rdot;
    if (dot != null) { goTo(Number(dot), true); if (playing) start(); }
    if (nav === 'prev') { goTo(index - 1, true); if (playing) start(); }
    if (nav === 'next') { goTo(index + 1, true); if (playing) start(); }
    if (nav === 'toggle') {
      if (playing) pause(true);
      else { userPaused = false; start(); }
    }
  });

  root.querySelector('.review-dots').addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
    e.preventDefault();
    const next = (index + (e.key === 'ArrowRight' ? 1 : -1) + reviews.length) % reviews.length;
    goTo(next, true);
    dotEls[next].focus();
  });

  root.addEventListener('mouseenter', () => stop());
  root.addEventListener('mouseleave', () => { if (playing && !userPaused) start(); });
  root.addEventListener('focusin', () => stop());
  root.addEventListener('focusout', (e) => {
    if (!root.contains(e.relatedTarget) && playing && !userPaused) start();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop(); else if (playing && !userPaused) start();
  });

  if (reduceMotion) { playing = false; syncToggle(); } else { start(); }
}
