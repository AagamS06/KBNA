/* Home page wiring. Loaded with `defer` after the shared libraries, so every
   global it uses (renderShell, HERO_SLIDES, store, REVIEWS, …) is ready. */
renderShell('home');

/* Load last night's draw (facts only) BEFORE building the carousel, so the
   lotto slide can show the real winning numbers + which draw. Fails soft: with
   no verified data the slide keeps its decorative balls. */
(async () => {
  try {
    const res = await fetch('data/lottery.json', { cache: 'no-store' });
    if (res.ok) setHeroLotto(await res.json());
  } catch { /* offline / no file — decorative fallback */ }
  initHeroCarousel('hero', HERO_SLIDES, { interval: 6500 });
})();

/* Home hero seam: fills from data/lottery.json if present, stays hidden if not. */
if (typeof initLotteryPanel === 'function') {
  initLotteryPanel('lottery-panel', 'data/lottery.json');
}

renderGallery('gallery');

initReviewsAuto('reviews-section', { interval: 6500 });

// Every figure here is a real, checkable one — the Google rating and
// review count from reviews.js, and the opening hours from the shop.
document.getElementById('stat-grid').innerHTML = [
  [REVIEW_SUMMARY.rating, `average ${REVIEW_SUMMARY.source} rating`],
  [REVIEW_SUMMARY.count, `${REVIEW_SUMMARY.source} reviews and counting`],
  ['7', 'days a week, from 8am']
].map(([figure, label]) => `
  <li class="stat">
    <span class="stat-figure">${esc(figure)}</span>
    <span class="stat-label">${esc(label)}</span>
  </li>`).join('');

document.getElementById('tag-list').innerHTML =
  store.distinctTags().map(t => `<li><a class="tag-chip" href="products.html?tag=${encodeURIComponent(t)}">${esc(t)}</a></li>`).join('')
  + `<li><a class="tag-chip" href="products.html">Everything</a></li>`;

function renderPopular() {
  const picks = store.activeProducts().filter(p => !p.held && p.stock > 0).slice(0, 4);
  document.getElementById('popular-grid').innerHTML = picks.map(productCardHTML).join('');
}
renderPopular();

document.addEventListener('click', e => {
  const id = e.target.closest('[data-add]')?.dataset.add;
  if (!id) return;
  store.addToCart(id);
  renderShell('home');
  renderPopular();
});

initReveal();
