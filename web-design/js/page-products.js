/* Products page wiring. Loaded with `defer` after the shared libraries. */
renderShell('products');
const activeTag = new URLSearchParams(location.search).get('tag') || '';

/* Reflect the active category in the heading + document title so a filtered
   view reads as "Products — Cards". The current chip is marked below with
   is-active + aria-current. */
if (activeTag) {
  const h1 = document.querySelector('#main .section-head h1');
  if (h1) h1.textContent = `Products — ${activeTag}`;
  document.title = `${activeTag} — Products — Knightsbridge Newsagency, Castle Hill`;
}

document.getElementById('tag-filter').innerHTML =
  `<li><a class="tag-chip ${!activeTag ? 'is-active' : ''}" href="products.html" ${!activeTag ? 'aria-current="true"' : ''}>Everything</a></li>` +
  store.distinctTags().map(t =>
    `<li><a class="tag-chip ${activeTag === t ? 'is-active' : ''}" href="products.html?tag=${encodeURIComponent(t)}" ${activeTag === t ? 'aria-current="true"' : ''}>${esc(t)}</a></li>`).join('');

function render() {
  const all = store.activeProducts();
  const list = activeTag ? all.filter(p => p.tag === activeTag) : all;
  document.getElementById('empty-msg').hidden = list.length > 0;
  document.getElementById('product-grid').innerHTML = list.map(productCardHTML).join('');
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
