/* Knightsbridge Newsagency — static browser build.
   All data lives in localStorage. No server, no database, no build step. */

const DEFAULT_TAGS = ['Magazine', 'Paper', 'Toys', 'Cards', 'Stationery', 'Gifts', 'Lottery'];

/* Bump when SEED_PRODUCTS changes shape so the demo catalogue refreshes. */
const SEED_VERSION = 2;

/* A "Check in store" card carries checkInStore:true. There are far too many
   greeting-card designs to track stock online, so these products hide their
   price/stock and never enter the basket — the card renders a "Check in store"
   prompt instead. price/stock fields are kept (set to 0) so the product shape
   stays uniform for the owner app and any code that reads them. */
const CHECK_IN_STORE_DEFAULTS = { price_cents: 0, stock: 0, low_stock_threshold: 0, checkInStore: true };

const SEED_PRODUCTS = [
  /* ---- Paper ----
     `days` = Sydney weekdays this edition is on sale (0=Sun … 6=Sat). The shop
     shows only today's papers (see store.visibleProducts); e.g. Saturday shows
     the Saturday Telegraph, Saturday Herald, AFR Weekend and Weekend Australian.
     A paper with no `days` would show every day. */
  { name: 'The Daily Telegraph', description: "Today's edition, in early every weekday morning.", price_cents: 300, stock: 40, low_stock_threshold: 10, tag: 'Paper', days: [1, 2, 3, 4, 5] },
  { name: 'The Saturday Telegraph', description: 'Saturday edition with the weekend lift-outs.', price_cents: 450, stock: 35, low_stock_threshold: 8, tag: 'Paper', days: [6] },
  { name: 'The Sunday Telegraph', description: 'Sunday edition — news, sport and the magazine.', price_cents: 450, stock: 35, low_stock_threshold: 8, tag: 'Paper', days: [0] },
  { name: 'The Sydney Morning Herald', description: 'Weekday edition of the Herald.', price_cents: 480, stock: 30, low_stock_threshold: 8, tag: 'Paper', days: [1, 2, 3, 4, 5] },
  { name: 'The Saturday Herald', description: 'Saturday SMH with all the lift-outs.', price_cents: 580, stock: 28, low_stock_threshold: 8, tag: 'Paper', days: [6] },
  { name: 'The Sun-Herald', description: 'Sunday edition of the Herald.', price_cents: 480, stock: 28, low_stock_threshold: 8, tag: 'Paper', days: [0] },
  { name: 'The Australian', description: 'National daily broadsheet — weekday edition.', price_cents: 450, stock: 28, low_stock_threshold: 8, tag: 'Paper', days: [1, 2, 3, 4, 5] },
  { name: 'The Weekend Australian', description: 'Weekend edition with the Magazine and Review — Saturday and Sunday.', price_cents: 550, stock: 22, low_stock_threshold: 6, tag: 'Paper', days: [6, 0] },
  { name: 'Australian Financial Review', description: 'Weekday business and markets daily.', price_cents: 550, stock: 20, low_stock_threshold: 6, tag: 'Paper', days: [1, 2, 3, 4, 5] },
  { name: 'AFR Weekend', description: 'The weekend Financial Review — business, life and leisure. Saturday and Sunday.', price_cents: 600, stock: 18, low_stock_threshold: 5, tag: 'Paper', days: [6, 0] },
  { name: 'Hills Shire Times', description: 'Your local Castle Hill and Hills District weekly (Wednesdays).', price_cents: 220, stock: 35, low_stock_threshold: 10, tag: 'Paper', days: [3] },
  /* ---- Magazine ---- */
  { name: "Woman's Day Magazine", description: 'Latest weekly issue.', price_cents: 620, stock: 15, low_stock_threshold: 4, tag: 'Magazine' },
  { name: 'National Geographic', description: 'Current monthly issue.', price_cents: 1450, stock: 8, low_stock_threshold: 3, tag: 'Magazine' },
  { name: "That's Life Puzzler", description: 'Crosswords and puzzles — a customer favourite.', price_cents: 550, stock: 20, low_stock_threshold: 5, tag: 'Magazine' },
  { name: 'The Big Book of Crosswords', description: 'Chunky puzzle magazine — weeks of crosswords and quizzes.', price_cents: 895, stock: 18, low_stock_threshold: 5, tag: 'Magazine' },
  { name: 'Better Homes and Gardens', description: 'Monthly issue — home, garden, food and DIY.', price_cents: 890, stock: 12, low_stock_threshold: 4, tag: 'Magazine' },
  { name: 'TV Week', description: 'Weekly guide, gossip and puzzles.', price_cents: 480, stock: 24, low_stock_threshold: 6, tag: 'Magazine' },
  { name: 'Australian Geographic', description: 'Bi-monthly — landscapes, wildlife and adventure.', price_cents: 1595, stock: 7, low_stock_threshold: 3, tag: 'Magazine' },
  /* ---- Toys ---- */
  { name: 'Matchbox Diecast Car', description: 'Assorted models — great little gift.', price_cents: 500, stock: 18, low_stock_threshold: 5, tag: 'Toys' },
  { name: 'Plush Teddy Bear', description: 'Soft cuddly bear — a last-minute gift sorted.', price_cents: 1995, stock: 9, low_stock_threshold: 3, tag: 'Toys' },
  { name: 'Wooden Jigsaw Puzzle (100 pieces)', description: 'Chunky pieces — good for little hands.', price_cents: 1250, stock: 11, low_stock_threshold: 3, tag: 'Toys' },
  { name: 'Deck of Playing Cards', description: 'Standard 52-card deck for games night.', price_cents: 450, stock: 26, low_stock_threshold: 6, tag: 'Toys' },
  { name: 'Bumper Colouring & Activity Book', description: 'Puzzles, mazes and pictures to colour in.', price_cents: 695, stock: 16, low_stock_threshold: 4, tag: 'Toys' },
  /* ---- Stationery ---- */
  { name: 'Crayola Coloured Pencils (12 pack)', description: 'Full colour set for school or home.', price_cents: 649, stock: 14, low_stock_threshold: 4, tag: 'Stationery' },
  { name: 'A4 Spiral Notebook 120pg', description: 'Ruled pages, sturdy cover.', price_cents: 425, stock: 22, low_stock_threshold: 6, tag: 'Stationery' },
  { name: 'Parker Jotter Ballpoint Pen', description: 'Stainless steel barrel — a proper everyday pen.', price_cents: 2495, stock: 10, low_stock_threshold: 3, tag: 'Stationery' },
  { name: 'HB Pencils (10 pack)', description: 'Everyday graphite pencils for school or office.', price_cents: 380, stock: 30, low_stock_threshold: 8, tag: 'Stationery' },
  { name: 'Sticky Notes (assorted colours)', description: 'Handy 76mm pads — five colours.', price_cents: 425, stock: 20, low_stock_threshold: 5, tag: 'Stationery' },
  { name: 'Highlighter Set (4 pack)', description: 'Chisel-tip markers in four bright colours.', price_cents: 550, stock: 18, low_stock_threshold: 5, tag: 'Stationery' },
  /* ---- Gifts ---- */
  { name: 'Gift Wrap Roll — Assorted', description: '3 metres of quality wrap.', price_cents: 495, stock: 16, low_stock_threshold: 5, tag: 'Gifts' },
  { name: 'Scented Candle — Vanilla', description: 'Popular local gift line.', price_cents: 1295, stock: 6, low_stock_threshold: 3, tag: 'Gifts' },
  { name: 'Gift Bag — Medium (Assorted)', description: 'Sturdy paper gift bag with rope handles.', price_cents: 350, stock: 30, low_stock_threshold: 8, tag: 'Gifts' },
  { name: 'Photo Frame 6x4', description: 'Simple standing frame for a favourite snap.', price_cents: 1195, stock: 10, low_stock_threshold: 3, tag: 'Gifts' },
  { name: 'Reed Diffuser — Linen', description: 'Long-lasting home fragrance in a glass bottle.', price_cents: 1650, stock: 8, low_stock_threshold: 3, tag: 'Gifts' },
  { name: 'Keyring — Assorted', description: 'Little novelty keyrings — pick one at the counter.', price_cents: 650, stock: 24, low_stock_threshold: 6, tag: 'Gifts' },
  /* ---- Lottery ----
     Lottery tickets and Instant Scratch-Its are NOT sold online — reselling
     them online breaches the operator's rules. The Lottery category is kept,
     but the Products page shows an in-store / official-app message there
     instead of any product (see js/page-products.js). No Lottery products
     are seeded. */
  /* ---- Cards (Check in store — too many designs to track stock) ---- */
  { name: 'Birthday Card', description: 'A big wall of birthday designs — from kids to milestone ages.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Love Card', description: 'For your someone special, Valentine\'s or just because.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Sympathy Card', description: 'Thoughtful, understated designs for a difficult time.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Thank You Card', description: 'Say thanks properly — singles and value packs.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'New Baby Card', description: 'Welcome the new arrival — for a boy, a girl or a surprise.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Congratulations Card', description: 'New job, new home, graduation or a big win.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Anniversary Card', description: 'From first year to golden — plenty to choose from.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS },
  { name: 'Blank Card — Any Occasion', description: 'Blank inside so you can write your own message.', tag: 'Cards', ...CHECK_IN_STORE_DEFAULTS }
];

/* The shop's contact address, used by the enquiry form. There is deliberately
   no password here any more: the owner portal has moved to the mobile app, so
   the public site never needs a credential and must not ship one. */
const SHOP_CONTACT = { email: 'owner@knightsbridgenews.com.au' };

const store = {
  _read(k, fallback) {
    try { return JSON.parse(localStorage.getItem(k)) ?? fallback; }
    catch { return fallback; }
  },
  _write(k, v) { localStorage.setItem(k, JSON.stringify(v)); },

  init() {
    // Re-seed when the catalogue shape changes (day-tagged papers, lottery
    // removed from sale). Bumping SEED_VERSION refreshes the demo catalogue.
    if (this._read('kn.seedVersion', 0) !== SEED_VERSION) {
      const seeded = SEED_PRODUCTS.map((p, i) => ({ id: i + 1, active: true, held: false, ...p }));
      this._write('kn.products', seeded);
      this._write('kn.nextId', seeded.length + 1);
      this._write('kn.seedVersion', SEED_VERSION);
      this._write('kn.cart', {});
    } else {
      // Same shape, but the seed's fixed catalogue facts (cover price, on-sale
      // `days`, description) may have been retuned in SEED_PRODUCTS — e.g. a
      // newspaper price rise, or the weekend AFR/Australian now selling on
      // Sunday too. Propagate just those fields to returning users so the change
      // reaches them without a SEED_VERSION bump (which would wipe their cart).
      this._syncSeedCatalogue();
    }
    if (!localStorage.getItem('kn.owner')) this._write('kn.owner', SHOP_CONTACT);
    if (!localStorage.getItem('kn.cart')) this._write('kn.cart', {});
    if (!localStorage.getItem('kn.orders')) this._write('kn.orders', []);
  },

  /* Reconcile persisted products' seed-controlled fields with SEED_PRODUCTS
     (matched by name): cover price, on-sale `days` and description. These are
     fixed catalogue facts the shopfront never edits — stock lives in the
     owner's app — so overwriting just them is always safe and leaves stock,
     cart and everything else untouched. */
  _syncSeedCatalogue() {
    const SYNC_FIELDS = ['price_cents', 'days', 'description'];
    const seedByName = new Map(SEED_PRODUCTS.map(p => [p.name, p]));
    const list = this.products();
    let changed = false;
    for (const p of list) {
      const seed = seedByName.get(p.name);
      if (!seed) continue;
      for (const f of SYNC_FIELDS) {
        if (f in seed && JSON.stringify(p[f]) !== JSON.stringify(seed[f])) {
          p[f] = Array.isArray(seed[f]) ? seed[f].slice() : seed[f];
          changed = true;
        }
      }
    }
    if (changed) this.saveProducts(list);
  },

  products() { return this._read('kn.products', []); },
  activeProducts() { return this.products().filter(p => p.active); },
  productById(id) { return this.products().find(p => p.id === Number(id)); },
  saveProducts(list) { this._write('kn.products', list); },

  /* Today's Sydney weekday (0=Sun … 6=Sat), so day-specific papers show only
     on their day. */
  todayWeekday() {
    const s = new Intl.DateTimeFormat('en-US', { timeZone: 'Australia/Sydney', weekday: 'short' }).format(new Date());
    return { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }[s];
  },
  showsToday(p) { return !Array.isArray(p.days) || p.days.includes(this.todayWeekday()); },
  /* Products a customer should see right now — active, and (for papers) on sale
     today. Use this for shopfront rendering; activeProducts stays unfiltered. */
  visibleProducts() { return this.activeProducts().filter(p => this.showsToday(p)); },

  addProduct(p) {
    const list = this.products();
    const nextId = this._read('kn.nextId', list.length + 1);
    list.push({ id: nextId, active: true, held: false, ...p });
    this._write('kn.nextId', nextId + 1);
    this.saveProducts(list);
  },
  updateProduct(id, patch) {
    const list = this.products().map(p => p.id === Number(id) ? { ...p, ...patch } : p);
    this.saveProducts(list);
  },
  removeProduct(id) { this.updateProduct(id, { active: false }); },

  distinctTags() {
    return [...new Set(this.activeProducts().map(p => p.tag))].sort();
  },

  cart() { return this._read('kn.cart', {}); },
  cartLines() {
    const cart = this.cart();
    return Object.entries(cart).map(([id, qty]) => {
      const p = this.productById(id);
      // checkInStore items can't be reserved online, so they never appear as
      // a cart line even if an id somehow lingered in storage.
      if (!p || !p.active || p.held || p.checkInStore) return null;
      return { ...p, qty: Math.min(qty, p.stock) };
    }).filter(l => l && l.qty > 0);
  },
  cartCount() {
    return this.cartLines().reduce((n, l) => n + l.qty, 0);
  },
  addToCart(id) {
    const p = this.productById(id);
    // Refuse checkInStore items: they aren't stock-tracked and can't be
    // reserved or paid for online — the shopper comes in to browse them.
    if (!p || !p.active || p.held || p.checkInStore || p.stock <= 0) return;
    const cart = this.cart();
    cart[id] = Math.min((cart[id] || 0) + 1, p.stock);
    this._write('kn.cart', cart);
  },
  setCartQty(id, qty) {
    const cart = this.cart();
    if (qty <= 0) delete cart[id];
    else {
      const p = this.productById(id);
      if (p && !p.checkInStore) cart[id] = Math.min(qty, p.stock);
    }
    this._write('kn.cart', cart);
  },
  clearCart() { this._write('kn.cart', {}); },

  /** Simulate a paid order: decrement stock, auto-hold low items, record order,
   *  return {order, lowStockItems} for the receipt/alert. */
  fulfilOrder(method) {
    const lines = this.cartLines();
    if (!lines.length) return null;
    const products = this.products();
    const lowStock = [];
    lines.forEach(l => {
      const p = products.find(x => x.id === l.id);
      if (!p) return;
      p.stock = Math.max(0, p.stock - l.qty);
      if (p.stock <= p.low_stock_threshold && !p.held) {
        p.held = true;
        lowStock.push({ ...p });
      }
    });
    this.saveProducts(products);
    const total = lines.reduce((s, l) => s + l.price_cents * l.qty, 0);
    const order = {
      id: Date.now(),
      created_at: new Date().toISOString(),
      items: lines.map(l => ({ id: l.id, name: l.name, qty: l.qty, price_cents: l.price_cents })),
      total_cents: total,
      payment_method: method
    };
    const orders = this._read('kn.orders', []);
    orders.unshift(order);
    this._write('kn.orders', orders.slice(0, 50));
    this.clearCart();
    return { order, lowStock };
  },
  orders() { return this._read('kn.orders', []); },

  /* Where the enquiry form sends mail. Sign-in, stock editing and order
     management all live in the owner's mobile app now, so none of that
     logic — and no password — exists in this bundle. */
  owner() { return this._read('kn.owner', SHOP_CONTACT); },

  resetAll() {
    ['kn.products', 'kn.nextId', 'kn.owner', 'kn.cart', 'kn.orders', 'kn.galleryPhotos']
      .forEach(k => localStorage.removeItem(k));
    this.init();
  }
};

const money = c => `$${(c / 100).toFixed(2)}`;
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* Product card markup, shared by the shop page.
   Photo, in order of preference:
     1. an address the owner typed in (a supplier's own product shot)
     2. one found automatically by the Openverse lookup (see js/images.js),
        which carries a credit line the licence requires us to show
     3. artwork generated from the item's tag + name (see js/art.js), so a
        brand new item always has a thumbnail even with no photo at all
   A photo that fails to load falls back to 3 — see the error handler in
   js/images.js. */
function productCardHTML(p) {
  const unavailable = p.held || p.stock === 0;
  const low = !unavailable && p.stock <= p.low_stock_threshold + 2;
  /* width/height reserve the box before the photo loads (no layout shift); the
     .product-thumb CSS aspect-ratio still governs the rendered size. */
  const art = p.image_url
    ? `<img src="${esc(p.image_url)}" alt="" width="400" height="170" loading="lazy" data-art-fallback="${esc(p.tag)}">`
    : tagThumb(p.tag, p.name);
  const credit = p.image_url && p.image_credit ? imageCreditHTML(p.image_credit) : '';
  /* The image and the name link through to the deep-linkable detail page. The
     Add / Check-in-store control stays a real button/link OUTSIDE these links,
     so we never nest an interactive control inside an anchor. */
  const detailHref = `product.html?id=${encodeURIComponent(p.id)}`;

  /* "Check in store" items (e.g. greeting cards) have too many designs to
     track stock online, so they never show a price or an Add button and can
     never enter the basket. Instead the card shows an informative control
     that points the shopper to the store / contact page. */
  const body = p.checkInStore
    ? `
        <p class="product-instore-note">Come in and browse the range — too many designs to list online.</p>
        <a class="btn btn-instore btn-block" href="contact.html">
          Check in store<span class="visually-hidden"> for ${esc(p.name)}</span>
        </a>`
    : `
        <p class="product-price"><span class="visually-hidden">Price: </span>${money(p.price_cents)}</p>
        ${unavailable
          ? `<p class="product-held">Temporarily unavailable — restocking soon</p>`
          : `${low ? `<p class="product-low">Only ${p.stock} left</p>` : ''}
             <button class="btn btn-primary btn-block" data-add="${p.id}">Add <span class="visually-hidden">${esc(p.name)} </span>to basket</button>`}`;

  return `
    <li class="product-card">
      <div class="product-thumb">
        <a class="product-thumb-link" href="${detailHref}" tabindex="-1" aria-hidden="true">${art}</a>
        <span class="product-tag">${esc(p.tag)}</span>
      </div>
      <div class="product-body">
        <h2 class="product-name"><a href="${detailHref}">${esc(p.name)}</a></h2>
        ${p.description ? `<p class="product-desc">${esc(p.description)}</p>` : ''}
        ${body}
        ${credit}
      </div>
    </li>`;
}

/* Shared masthead + footer so every page renders the same shell. */
function renderShell(currentPage) {
  const cartCount = store.cartCount();
  const nav = [
    { href: 'index.html', label: 'Home', key: 'home' },
    { href: 'products.html', label: 'Products', key: 'products' },
    { href: 'services.html', label: 'Services', key: 'services' },
    { href: 'about.html', label: 'About us', key: 'about' },
    { href: 'contact.html', label: 'Contact us', key: 'contact' }
  ];

  document.getElementById('site-header').innerHTML = `
    <a class="skip-link" href="#main">Skip to main content</a>
    <p class="top-banner">Open 7 days · Mon–Fri 8am–6pm, Sat–Sun 8am–4pm · <a href="${BUSINESS_LINKS.phone}">${BUSINESS.phone}</a> · Reserve online, pay &amp; collect in store</p>
    <div class="nav-bar">
      <div class="nav-brand">
        <a class="brand-link" href="index.html" aria-label="${esc(BUSINESS.name)} — home">
          <img class="brand-wordmark" src="assets/icons/newsagency-wordmark.png" alt="${esc(BUSINESS.name)}">
        </a>
        <span class="brand-sub">Castle Hill NSW · Open 7 days</span>
      </div>
      <button class="nav-toggle" type="button" aria-controls="primary-nav" aria-expanded="false" aria-label="Menu">
        <span class="nav-toggle-bar" aria-hidden="true"></span>
        <span class="nav-toggle-bar" aria-hidden="true"></span>
        <span class="nav-toggle-bar" aria-hidden="true"></span>
      </button>
      <nav class="nav-menu" id="primary-nav" aria-label="Main menu">
        <ul>${nav.map(n => `<li><a href="${n.href}" ${n.key === currentPage ? 'aria-current="page"' : ''}>${esc(n.label)}</a></li>`).join('')}</ul>
      </nav>
      <div class="nav-tools">
        <form class="nav-search" role="search" id="nav-search">
          <label class="visually-hidden" for="nav-search-input">Search this page</label>
          <input id="nav-search-input" type="search" placeholder="Search…" autocomplete="off"
                 aria-label="Search this page">
          <button type="submit" class="nav-search-btn" aria-label="Search">
            <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false">
              <circle cx="11" cy="11" r="7" fill="none" stroke="currentColor" stroke-width="2"/>
              <line x1="16.5" y1="16.5" x2="21" y2="21" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
        </form>
        <a class="nav-basket" href="cart.html" ${currentPage === 'cart' ? 'aria-current="page"' : ''}
           aria-label="Cart, ${cartCount} item${cartCount === 1 ? '' : 's'}">
          <svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true" focusable="false">
            <!-- Modern shopping cart: hooked handle top-left, trapezoidal basket,
                 two wheels at the base. Stroked so it reads clearly at any size. -->
            <path d="M3 4h2.2a1 1 0 0 1 1 .8l.55 2.7"
                  fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
            <path d="M6.75 7.5h13.4a.6.6 0 0 1 .58.75l-1.6 6.4a1.6 1.6 0 0 1-1.55 1.2H9.2a1.6 1.6 0 0 1-1.57-1.28L6.15 6.5"
                  fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
            <circle cx="9.5" cy="20" r="1.6" fill="currentColor"/>
            <circle cx="17.5" cy="20" r="1.6" fill="currentColor"/>
          </svg>
          <span class="cart-count" aria-hidden="true">${cartCount}</span>
        </a>
      </div>
    </div>
    <p class="nav-search-status visually-hidden" id="nav-search-status" role="status" aria-live="polite"></p>`;

  // Hamburger toggle — collapsed by default on mobile, ignored on desktop where CSS shows the menu inline.
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.getElementById('primary-nav');
  if (toggle && menu) {
    toggle.addEventListener('click', () => {
      const open = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!open));
      menu.classList.toggle('is-open', !open);
    });
  }

  if (typeof initNavSearch === 'function') initNavSearch(currentPage);

  document.getElementById('site-footer').innerHTML = `
    <div class="footer-grid">
      <section aria-labelledby="f-visit">
        <h2 id="f-visit">Visit us</h2>
        <p>${BUSINESS.street}<br>${BUSINESS.suburb}</p>
        <ul class="footer-links">
          <li><a href="${BUSINESS_LINKS.phone}">${BUSINESS.phone}</a></li>
          <li><a href="${BUSINESS_LINKS.maps}" target="_blank" rel="noopener">Get directions (Google Maps)</a></li>
        </ul>
      </section>
      <section aria-labelledby="f-shop">
        <h2 id="f-shop">Products</h2>
        <ul class="footer-links">
          <li><a href="products.html">All products</a></li>
          <li><a href="services.html">Services</a></li>
          <li><a href="about.html">About us</a></li>
          <li><a href="cart.html">Your basket</a></li>
          <li><a href="contact.html">Contact us</a></li>
        </ul>
      </section>
      <section aria-labelledby="f-web">
        <h2 id="f-web">Find us online</h2>
        <ul class="footer-links">
          <li><a href="${BUSINESS_LINKS.reviews}" target="_blank" rel="noopener">Our Google reviews</a></li>
          <li><a href="${BUSINESS_LINKS.writeReview}" target="_blank" rel="noopener">Write us a review</a></li>
          <li><a href="${BUSINESS_LINKS.lott}" target="_blank" rel="noopener">Check your Lotto numbers</a></li>
        </ul>
      </section>
      <section aria-labelledby="f-hours">
        <h2 id="f-hours">Opening hours</h2>
        <ul class="footer-links">
          ${BUSINESS.hours.map(([days, time]) => `<li>${esc(days)} — ${esc(time)}</li>`).join('')}
        </ul>
      </section>
    </div>
    <p class="footer-fineprint">© ${new Date().getFullYear()} ${BUSINESS.name} · Rated ${REVIEW_SUMMARY.rating} stars by our local customers · <a class="staff-link" href="admin/login.html" rel="nofollow">Staff</a></p>`;
}

store.init();

/* Progressive enhancement: register the service worker so the shell works
   offline after the first visit. Guarded so it never throws where it can't
   run — service workers need a secure context (https or localhost) and are
   simply unavailable from file://, where the site still works without it. */
if ('serviceWorker' in navigator &&
    (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => { /* offline caching just won't be available */ });
  });
}
