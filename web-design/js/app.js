/* Knightsbridge Newsagency — static browser build.
   All data lives in localStorage. No server, no database, no build step. */

const DEFAULT_TAGS = ['Magazine', 'Paper', 'Toys', 'Cards', 'Stationery', 'Gifts', 'Lottery'];

const SEED_PRODUCTS = [
  { name: 'The Daily Telegraph (Weekday)', description: "Today's edition, delivered fresh each morning.", price_cents: 260, stock: 40, low_stock_threshold: 10, tag: 'Paper' },
  { name: 'The Sydney Morning Herald (Weekend)', description: 'Saturday edition with all the lift-outs.', price_cents: 450, stock: 30, low_stock_threshold: 8, tag: 'Paper' },
  { name: "Woman's Day Magazine", description: 'Latest weekly issue.', price_cents: 620, stock: 15, low_stock_threshold: 4, tag: 'Magazine' },
  { name: 'National Geographic', description: 'Current monthly issue.', price_cents: 1450, stock: 8, low_stock_threshold: 3, tag: 'Magazine' },
  { name: "That's Life Puzzler", description: 'Crosswords and puzzles — a customer favourite.', price_cents: 550, stock: 20, low_stock_threshold: 5, tag: 'Magazine' },
  { name: 'Birthday Card — Classic Range', description: 'Assorted designs with envelope.', price_cents: 795, stock: 25, low_stock_threshold: 6, tag: 'Cards' },
  { name: 'Sympathy Card', description: 'Thoughtful designs with envelope.', price_cents: 750, stock: 12, low_stock_threshold: 4, tag: 'Cards' },
  { name: 'Matchbox Diecast Car', description: 'Assorted models — great little gift.', price_cents: 500, stock: 18, low_stock_threshold: 5, tag: 'Toys' },
  { name: 'Crayola Coloured Pencils (12 pack)', description: 'Full colour set for school or home.', price_cents: 649, stock: 14, low_stock_threshold: 4, tag: 'Stationery' },
  { name: 'A4 Spiral Notebook 120pg', description: 'Ruled pages, sturdy cover.', price_cents: 425, stock: 22, low_stock_threshold: 6, tag: 'Stationery' },
  { name: 'Gift Wrap Roll — Assorted', description: '3 metres of quality wrap.', price_cents: 495, stock: 16, low_stock_threshold: 5, tag: 'Gifts' },
  { name: 'Scented Candle — Vanilla', description: 'Popular local gift line.', price_cents: 1295, stock: 6, low_stock_threshold: 3, tag: 'Gifts' },
  { name: 'The Big Book of Crosswords', description: 'Chunky puzzle magazine — weeks of crosswords and quizzes.', price_cents: 895, stock: 18, low_stock_threshold: 5, tag: 'Magazine' },
  { name: 'Parker Jotter Ballpoint Pen', description: 'Stainless steel barrel — a proper everyday pen.', price_cents: 2495, stock: 10, low_stock_threshold: 3, tag: 'Stationery' },
  { name: 'Plush Teddy Bear', description: 'Soft cuddly bear — a last-minute gift sorted.', price_cents: 1995, stock: 9, low_stock_threshold: 3, tag: 'Toys' },
  { name: 'Gift Bag — Medium (Assorted)', description: 'Sturdy paper gift bag with rope handles.', price_cents: 350, stock: 30, low_stock_threshold: 8, tag: 'Gifts' },
  { name: 'Instant Scratch-Its Ticket', description: 'Grab a scratchie at the counter and have a go.', price_cents: 500, stock: 50, low_stock_threshold: 10, tag: 'Lottery' }
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
    if (!localStorage.getItem('kn.products')) {
      const seeded = SEED_PRODUCTS.map((p, i) => ({ id: i + 1, active: true, held: false, ...p }));
      this._write('kn.products', seeded);
      this._write('kn.nextId', seeded.length + 1);
    }
    if (!localStorage.getItem('kn.owner')) this._write('kn.owner', SHOP_CONTACT);
    if (!localStorage.getItem('kn.cart')) this._write('kn.cart', {});
    if (!localStorage.getItem('kn.orders')) this._write('kn.orders', []);
  },

  products() { return this._read('kn.products', []); },
  activeProducts() { return this.products().filter(p => p.active); },
  productById(id) { return this.products().find(p => p.id === Number(id)); },
  saveProducts(list) { this._write('kn.products', list); },

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
      if (!p || !p.active || p.held) return null;
      return { ...p, qty: Math.min(qty, p.stock) };
    }).filter(l => l && l.qty > 0);
  },
  cartCount() {
    return this.cartLines().reduce((n, l) => n + l.qty, 0);
  },
  addToCart(id) {
    const p = this.productById(id);
    if (!p || !p.active || p.held || p.stock <= 0) return;
    const cart = this.cart();
    cart[id] = Math.min((cart[id] || 0) + 1, p.stock);
    this._write('kn.cart', cart);
  },
  setCartQty(id, qty) {
    const cart = this.cart();
    if (qty <= 0) delete cart[id];
    else {
      const p = this.productById(id);
      if (p) cart[id] = Math.min(qty, p.stock);
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
  const art = p.image_url
    ? `<img src="${esc(p.image_url)}" alt="" loading="lazy" data-art-fallback="${esc(p.tag)}">`
    : tagThumb(p.tag, p.name);
  const credit = p.image_url && p.image_credit ? imageCreditHTML(p.image_credit) : '';
  return `
    <li class="product-card">
      <div class="product-thumb">
        ${art}
        <span class="product-tag">${esc(p.tag)}</span>
      </div>
      <div class="product-body">
        <h2 class="product-name">${esc(p.name)}</h2>
        ${p.description ? `<p class="product-desc">${esc(p.description)}</p>` : ''}
        <p class="product-price"><span class="visually-hidden">Price: </span>${money(p.price_cents)}</p>
        ${unavailable
          ? `<p class="product-held">Temporarily unavailable — restocking soon</p>`
          : `${low ? `<p class="product-low">Only ${p.stock} left</p>` : ''}
             <button class="btn btn-primary btn-block" data-add="${p.id}">Add <span class="visually-hidden">${esc(p.name)} </span>to basket</button>`}
        ${credit}
      </div>
    </li>`;
}

/* Shared masthead + footer so every page renders the same shell. */
function renderShell(currentPage) {
  const cartCount = store.cartCount();
  // No owner entry point here by design — stock is managed only in the
  // owner's mobile app. See _archive/owner.html for the retired portal.
  const nav = [
    { href: 'index.html', label: 'Home', key: 'home' },
    { href: 'products.html', label: 'Products', key: 'products' },
    { href: 'services.html', label: 'Services', key: 'services' },
    { href: 'about.html', label: 'About us', key: 'about' },
    { href: 'contact.html', label: 'Contact us', key: 'contact' },
    { href: 'cart.html', label: `Basket <span class="cart-count" aria-label="${cartCount} items in basket">${cartCount}</span>`, key: 'cart' }
  ];

  document.getElementById('site-header').innerHTML = `
    <a class="skip-link" href="#main">Skip to main content</a>
    <p class="masthead-eyebrow">Knightsbridge Shopping Village · 5/159 Ridgecrop Dr, Castle Hill NSW</p>
    <p class="masthead-name"><a href="index.html">Knightsbridge<span aria-hidden="true"> </span>Newsagency</a></p>
    <nav aria-label="Main menu" class="main-nav">
      <ul>${nav.map(n => `<li><a href="${n.href}" ${n.key === currentPage ? 'aria-current="page"' : ''}>${n.label}</a></li>`).join('')}</ul>
    </nav>`;

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
          <li><a href="${BUSINESS_LINKS.centre}" target="_blank" rel="noopener">Knightsbridge Shopping Centre</a></li>
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
    <p class="footer-fineprint">© ${new Date().getFullYear()} ${BUSINESS.name} · Rated ${REVIEW_SUMMARY.rating} stars by our local customers · Demo build — data stored in your browser only.</p>`;
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
