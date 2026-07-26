/* Accessible auto-rotating hero carousel.
   Follows the WAI-ARIA carousel pattern:
   - role=region + aria-roledescription=carousel
   - a visible pause/play control (WCAG 2.2.2 — moving content must be pausable)
   - auto-rotation runs continuously; it is NOT paused by hover or focus, only
     by the explicit Pause button (WCAG 2.2.2 is still met by that control)
   - the tab-hidden pause (visibilitychange) is kept — it's invisible anyway
   - prefers-reduced-motion disables auto-rotation and slide transitions entirely
   - a manual arrow/dot change restarts the interval (unless the user paused)
   - arrow keys move between slide dots */

function initHeroCarousel(mountId, slides, { interval = 6000 } = {}) {
  const root = document.getElementById(mountId);
  if (!root || !slides.length) return;

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let index = 0;
  let timer = null;
  let playing = !reduceMotion;
  let userPaused = false;

  root.setAttribute('role', 'region');
  root.setAttribute('aria-roledescription', 'carousel');
  root.setAttribute('aria-label', 'Featured departments');

  root.innerHTML = `
    <div class="carousel-viewport" id="${mountId}-slides" aria-live="off">
      ${slides.map((s, i) => `
        <div class="carousel-slide ${i === 0 ? 'is-active' : ''}"
             role="group" aria-roledescription="slide"
             aria-label="${i + 1} of ${slides.length}: ${s.heading}"
             ${i === 0 ? '' : 'aria-hidden="true"'} data-slide="${i}">
          <div class="slide-art">${s.svg()}</div>
          <div class="slide-copy">
            <p class="slide-eyebrow">${s.eyebrow}</p>
            <h2 class="slide-heading">${s.heading}</h2>
            <p class="slide-body">${s.body}</p>
            <a class="btn btn-primary btn-arrow" href="${s.cta.href}" ${i === 0 ? '' : 'tabindex="-1"'}>${s.cta.label}</a>
          </div>
        </div>`).join('')}
    </div>
    <div class="carousel-controls">
      <button class="carousel-btn" type="button" data-nav="prev" aria-label="Previous slide">
        <span aria-hidden="true">‹</span>
      </button>
      <div class="carousel-dots" role="tablist" aria-label="Choose slide">
        ${slides.map((s, i) => `
          <button class="carousel-dot ${i === 0 ? 'is-active' : ''}" type="button" role="tab"
                  data-dot="${i}" aria-selected="${i === 0}"
                  aria-label="Slide ${i + 1}: ${s.heading}"></button>`).join('')}
      </div>
      <button class="carousel-btn" type="button" data-nav="next" aria-label="Next slide">
        <span aria-hidden="true">›</span>
      </button>
      <button class="carousel-btn carousel-play" type="button" data-nav="toggle"
              aria-label="${playing ? 'Pause automatic slide rotation' : 'Start automatic slide rotation'}">
        <span aria-hidden="true">${playing ? '❚❚' : '▶'}</span>
      </button>
    </div>`;

  const slideEls = [...root.querySelectorAll('.carousel-slide')];
  const dotEls = [...root.querySelectorAll('.carousel-dot')];
  const viewport = root.querySelector('.carousel-viewport');
  const toggleBtn = root.querySelector('[data-nav="toggle"]');

  function goTo(next, fromUser = false) {
    index = (next + slides.length) % slides.length;
    slideEls.forEach((el, i) => {
      const active = i === index;
      el.classList.toggle('is-active', active);
      if (active) el.removeAttribute('aria-hidden'); else el.setAttribute('aria-hidden', 'true');
      const link = el.querySelector('a');
      if (link) link.tabIndex = active ? 0 : -1;
    });
    dotEls.forEach((d, i) => {
      d.classList.toggle('is-active', i === index);
      d.setAttribute('aria-selected', String(i === index));
    });
    // Announce only when the person drove the change; silent while auto-rotating
    // so a screen reader isn't interrupted every few seconds.
    viewport.setAttribute('aria-live', fromUser ? 'polite' : 'off');
  }

  function start() {
    if (reduceMotion || userPaused) return;
    stop();
    timer = setInterval(() => goTo(index + 1), interval);
    playing = true;
    syncToggle();
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  function pause(byUser = false) {
    stop();
    if (byUser) { userPaused = true; playing = false; syncToggle(); }
  }

  function syncToggle() {
    toggleBtn.setAttribute('aria-label', playing ? 'Pause automatic slide rotation' : 'Start automatic slide rotation');
    toggleBtn.querySelector('span').textContent = playing ? '❚❚' : '▶';
  }

  root.addEventListener('click', (e) => {
    const nav = e.target.closest('[data-nav]')?.dataset.nav;
    const dot = e.target.closest('[data-dot]')?.dataset.dot;
    if (dot != null) { goTo(Number(dot), true); if (playing) start(); }
    if (nav === 'prev') { goTo(index - 1, true); if (playing) start(); }
    if (nav === 'next') { goTo(index + 1, true); if (playing) start(); }
    if (nav === 'toggle') {
      if (playing) { pause(true); }
      else { userPaused = false; start(); }
    }
  });

  // Arrow keys within the dot group
  root.querySelector('.carousel-dots').addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
    e.preventDefault();
    const next = (index + (e.key === 'ArrowRight' ? 1 : -1) + slides.length) % slides.length;
    goTo(next, true);
    dotEls[next].focus();
  });

  // Auto-rotation is deliberately NOT paused by hover or focus — it keeps
  // running so the carousel is always in motion unless the visitor presses
  // Pause. The pause button satisfies WCAG 2.2.2. The only implicit pause we
  // keep is for a hidden tab, which no one is looking at anyway.
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop(); else if (playing && !userPaused) start();
  });

  if (reduceMotion) { playing = false; syncToggle(); } else { start(); }
}

/* Reveal-on-scroll, skipped entirely when reduced motion is requested. */
function initReveal() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    document.querySelectorAll('[data-reveal]').forEach(el => el.classList.add('is-revealed'));
    return;
  }
  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) { entry.target.classList.add('is-revealed'); io.unobserve(entry.target); }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
  document.querySelectorAll('[data-reveal]').forEach(el => io.observe(el));
}
