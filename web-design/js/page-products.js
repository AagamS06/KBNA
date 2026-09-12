/* Products page wiring. Loaded with `defer` after the shared libraries. */
renderShell('products');
const activeTag = new URLSearchParams(location.search).get('tag') || '';
const isLotteryView = activeTag === 'Lottery';

/* Reflect the active category in the heading + document title. */
if (activeTag) {
  const h1 = document.querySelector('#main .section-head h1');
  if (h1) h1.textContent = `Products — ${activeTag}`;
  document.title = `${activeTag} — Products — Knightsbridge Newsagency, Castle Hill`;
}

/* Category chips. Lottery is always offered even though nothing is seeded for
   it (see the in-store notice below). */
const tags = [...new Set([...store.distinctTags(), 'Lottery'])];
document.getElementById('tag-filter').innerHTML =
  `<li><a class="tag-chip ${!activeTag ? 'is-active' : ''}" href="products.html" ${!activeTag ? 'aria-current="true"' : ''}>Everything</a></li>` +
  tags.map(t =>
    `<li><a class="tag-chip ${activeTag === t ? 'is-active' : ''}" href="products.html?tag=${encodeURIComponent(t)}" ${activeTag === t ? 'aria-current="true"' : ''}>${esc(t)}</a></li>`).join('');

/* Sort toolbar — alphabetical by default, with a dropdown to change it.
   Injected here (no inline JS/handlers) so the CSP stays strict. */
const grid = document.getElementById('product-grid');
const SORTS = {
  az: { label: 'Name (A–Z)', fn: (a, b) => a.name.localeCompare(b.name) },
  za: { label: 'Name (Z–A)', fn: (a, b) => b.name.localeCompare(a.name) },
  'price-asc': { label: 'Price (low to high)', fn: (a, b) => a.price_cents - b.price_cents || a.name.localeCompare(b.name) },
  'price-desc': { label: 'Price (high to low)', fn: (a, b) => b.price_cents - a.price_cents || a.name.localeCompare(b.name) },
  tag: { label: 'Category', fn: (a, b) => a.tag.localeCompare(b.tag) || a.name.localeCompare(b.name) },
};
let currentSort = 'az';

if (!isLotteryView) {
  const toolbar = document.createElement('div');
  toolbar.className = 'products-toolbar';
  toolbar.innerHTML =
    `<label for="sort-select">Sort by</label>
     <select id="sort-select">
       ${Object.entries(SORTS).map(([k, v]) => `<option value="${k}">${esc(v.label)}</option>`).join('')}
     </select>`;
  grid.insertAdjacentElement('beforebegin', toolbar);
  const sel = toolbar.querySelector('#sort-select');
  sel.value = currentSort;
  sel.addEventListener('change', () => { currentSort = sel.value; render(); });
}

function render() {
  const empty = document.getElementById('empty-msg');

  // Lottery can't be sold online — show the in-store / official-app notice.
  if (isLotteryView) {
    empty.hidden = true;
    grid.classList.remove('product-grid');
    grid.innerHTML = `
      <div class="notice lottery-notice">
        <h2>Lottery &amp; Instant Scratch-Its</h2>
        <p>We can't sell lottery tickets or Instant Scratch-Its online — the
           operator's rules don't allow it. But we'd love to help in store:</p>
        <ul>
          <li><strong>Pop in</strong> and grab your tickets or a scratchie at the counter.</li>
          <li><strong>Playing online?</strong> Choose <strong>Knightsbridge Newsagency</strong>
              as your store when you buy through the official Lott app or
              <a href="${BUSINESS_LINKS.lott}" target="_blank" rel="noopener">thelott.com</a>
              — it supports us at no extra cost to you.</li>
        </ul>
        <p><a class="btn btn-primary btn-arrow" href="${BUSINESS_LINKS.lott}" target="_blank" rel="noopener">Visit thelott.com</a></p>
      </div>`;
    return;
  }

  grid.classList.add('product-grid');
  const all = store.visibleProducts();                 // papers filtered to today
  const list = (activeTag ? all.filter(p => p.tag === activeTag) : all)
    .slice()
    .sort(SORTS[currentSort].fn);
  empty.hidden = list.length > 0;
  grid.innerHTML = list.map(productCardHTML).join('');
}

document.addEventListener('click', e => {
  const id = e.target.closest('[data-add]')?.dataset.add;
  if (!id) return;
  store.addToCart(id);
  const msg = document.getElementById('added-msg');
  msg.textContent = 'Added to basket.';
  msg.hidden = false;
  renderShell('products');
  render();
});

render();

/* Papers hydrate asynchronously from data/papers.json — re-render when
   they arrive so first-load visitors see them the moment the fetch lands. */
window.addEventListener('kn:products-updated', render);
