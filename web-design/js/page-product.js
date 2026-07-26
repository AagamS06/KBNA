/* Product detail page. Loaded with `defer` after the shared libraries, so every
   global it uses (renderShell, store, tagThumb, money, esc, imageCreditHTML) is
   ready. Reads ?id=<productId> and renders that single product, or a friendly
   "not found" state for a missing / unknown / inactive id. */
renderShell('products');   // highlight "Products" in the nav

const CANON_BASE = 'https://www.knightsbridgenews.com.au/product.html';

const rawId = new URLSearchParams(location.search).get('id');
const product = store.productById(rawId);
const found = product && product.active;

const mount = document.getElementById('product-detail');
const backLink = document.getElementById('detail-back');

/* One product's full detail. Reuses the exact price / stock / check-in-store
   logic and markup from productCardHTML so the two views never drift. */
function productDetailHTML(p) {
  const unavailable = p.held || p.stock === 0;
  const low = !unavailable && p.stock <= p.low_stock_threshold + 2;

  /* width/height reserve the image box before it loads (no layout shift); the
     .detail-media CSS aspect-ratio governs the rendered size. The generated
     artwork (tagThumb) already carries its own viewBox, so it needs no attrs. */
  const art = p.image_url
    ? `<img src="${esc(p.image_url)}" alt="${esc(p.name)}" width="1200" height="800" data-art-fallback="${esc(p.tag)}">`
    : tagThumb(p.tag, p.name);
  const credit = p.image_url && p.image_credit ? imageCreditHTML(p.image_credit) : '';

  /* "Check in store" items (e.g. greeting cards) never show a price or an Add
     button and can never enter the basket — same guard as the grid card. */
  const action = p.checkInStore
    ? `
        <p class="product-instore-note">Come in and browse the range — too many designs to list online.</p>
        <a class="btn btn-instore" href="contact.html">
          Check in store<span class="visually-hidden"> for ${esc(p.name)}</span>
        </a>`
    : `
        <p class="product-price"><span class="visually-hidden">Price: </span>${money(p.price_cents)}</p>
        ${unavailable
          ? `<p class="product-held">Temporarily unavailable — restocking soon</p>`
          : `${low
                ? `<p class="product-low">Only ${p.stock} left</p>`
                : `<p class="product-stock">In stock — ${p.stock} available</p>`}
             <button class="btn btn-primary" data-add="${p.id}">Add <span class="visually-hidden">${esc(p.name)} </span>to basket</button>`}`;

  return `
    <article class="product-detail">
      <div class="detail-media">${art}</div>
      <div class="detail-body">
        <span class="detail-tag">${esc(p.tag)}</span>
        <h1 class="detail-name">${esc(p.name)}</h1>
        ${p.description ? `<p class="detail-desc">${esc(p.description)}</p>` : ''}
        ${action}
        ${credit}
      </div>
    </article>`;
}

function notFoundHTML() {
  return `
    <section class="message-page">
      <span class="eyebrow">Not found</span>
      <h1>We couldn't find that product</h1>
      <p>It may have sold out, or the link is out of date. Browse everything we stock instead.</p>
      <p style="margin-top:2rem"><a class="btn btn-primary btn-arrow" href="products.html">Browse the products</a></p>
    </section>`;
}

/* ---- <head> helpers: keep the tab title, description and canonical honest ---- */
function setMetaName(name, content) {
  let el = document.querySelector(`meta[name="${name}"]`);
  if (!el) { el = document.createElement('meta'); el.setAttribute('name', name); document.head.appendChild(el); }
  el.setAttribute('content', content);
}
function setMetaProp(prop, content) {
  const el = document.querySelector(`meta[property="${prop}"]`);
  if (el) el.setAttribute('content', content);
}
function metaDescFor(p) {
  const extra = p.description ? ' ' + p.description : '';
  return p.checkInStore
    ? `${p.name} at Knightsbridge Newsagency, Castle Hill NSW.${extra} Check in store.`
    : `${p.name} — ${money(p.price_cents)} at Knightsbridge Newsagency, Castle Hill NSW.${extra} Reserve online, collect in store.`;
}
function applyHead(p) {
  const url = `${CANON_BASE}?id=${encodeURIComponent(p.id)}`;
  const title = `${p.name} — Knightsbridge Newsagency, Castle Hill`;
  const desc = metaDescFor(p);

  document.title = title;
  setMetaName('description', desc);

  let link = document.querySelector('link[rel="canonical"]');
  if (!link) { link = document.createElement('link'); link.rel = 'canonical'; document.head.appendChild(link); }
  link.href = url;

  setMetaProp('og:title', title);
  setMetaProp('og:description', desc);
  setMetaProp('og:url', url);
  setMetaName('twitter:title', title);
  setMetaName('twitter:description', desc);
}

/* Product / Offer structured data. A <script type="application/ld+json"> block
   is data, not executable script, so it's allowed under our strict CSP (the
   home page already ships one). Fails soft — it's an SEO nicety only. */
function injectProductSchema(p) {
  try {
    const url = `${CANON_BASE}?id=${encodeURIComponent(p.id)}`;
    const availability = p.checkInStore
      ? 'https://schema.org/InStoreOnly'
      : (p.held || p.stock === 0 ? 'https://schema.org/OutOfStock' : 'https://schema.org/InStock');

    const offer = {
      '@type': 'Offer',
      availability,
      priceCurrency: 'AUD',
      url,
      seller: { '@type': 'Store', name: 'Knightsbridge Newsagency' }
    };
    // checkInStore items aren't stock-tracked and carry no online price.
    if (!p.checkInStore) offer.price = (p.price_cents / 100).toFixed(2);

    const data = {
      '@context': 'https://schema.org',
      '@type': 'Product',
      name: p.name,
      category: p.tag,
      offers: offer
    };
    if (p.description) data.description = p.description;
    if (p.image_url) data.image = p.image_url;

    const s = document.createElement('script');
    s.type = 'application/ld+json';
    s.textContent = JSON.stringify(data);
    document.head.appendChild(s);
  } catch { /* SEO only — never block the page */ }
}

/* ---- Render ---- */
if (found) {
  mount.innerHTML = productDetailHTML(product);
  applyHead(product);
  injectProductSchema(product);
} else {
  if (backLink) backLink.hidden = true;
  mount.innerHTML = notFoundHTML();
  document.title = 'Product not found — Knightsbridge Newsagency';
  setMetaName('description', "That product couldn't be found. Browse everything Knightsbridge Newsagency stocks in Castle Hill NSW.");
  setMetaName('robots', 'noindex, follow');
}

/* Add to basket — same behaviour as the grid, plus a re-render so the stock /
   "Only N left" line and the basket count stay in step. */
document.addEventListener('click', e => {
  const id = e.target.closest('[data-add]')?.dataset.add;
  if (!id) return;
  store.addToCart(id);
  const msg = document.getElementById('added-msg');
  if (msg) { msg.textContent = 'Added to basket.'; msg.hidden = false; }
  renderShell('products');                 // refresh the basket count in the header
  const p = store.productById(id);
  if (p) mount.innerHTML = productDetailHTML(p);
});
