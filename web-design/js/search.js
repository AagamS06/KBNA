/* Knightsbridge Newsagency — nav search.

   Local, no backend. It searches THIS page, relative to where the visitor is:
   - On the Products page it live-filters the product grid.
   - On every other page it does a find-in-page: highlights matches in the main
     content and jumps to the first one.
   All user text is handled as text (never innerHTML of raw input). */

function initNavSearch() {
  const form = document.getElementById('nav-search');
  const input = document.getElementById('nav-search-input');
  const status = document.getElementById('nav-search-status');
  if (!form || !input) return;

  const grid = document.getElementById('product-grid');

  if (grid) {
    const run = () => filterProductGrid(grid, input.value, status);
    input.addEventListener('input', run);
    form.addEventListener('submit', (e) => { e.preventDefault(); run(); });
  } else {
    form.addEventListener('submit', (e) => { e.preventDefault(); findInPage(input.value, status); });
    // Clearing the box removes highlights.
    input.addEventListener('input', () => { if (!input.value.trim()) clearHighlights(); });
  }
}

/* ---- Products page: filter the grid ---- */
function filterProductGrid(grid, query, status) {
  const q = query.trim().toLowerCase();
  const cards = [...grid.querySelectorAll('.product-card')];
  let shown = 0;
  cards.forEach((card) => {
    const match = !q || card.textContent.toLowerCase().includes(q);
    card.hidden = !match;
    if (match) shown++;
  });
  let empty = document.getElementById('search-empty');
  if (q && shown === 0) {
    if (!empty) {
      empty = document.createElement('p');
      empty.id = 'search-empty';
      empty.className = 'notice';
      grid.insertAdjacentElement('afterend', empty);
    }
    empty.textContent = `No products match “${query.trim()}”. Try a shorter word, or ask us in store.`;
    empty.hidden = false;
  } else if (empty) {
    empty.hidden = true;
  }
  if (status) status.textContent = q ? `${shown} product${shown === 1 ? '' : 's'} found.` : '';
}

/* ---- Other pages: find-in-page ---- */
const SEARCH_SKIP = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'SVG', 'BUTTON']);

function clearHighlights() {
  document.querySelectorAll('mark.search-hit').forEach((m) => {
    const parent = m.parentNode;
    parent.replaceChild(document.createTextNode(m.textContent), m);
    parent.normalize();
  });
}

function findInPage(query, status) {
  clearHighlights();
  const q = query.trim();
  const main = document.getElementById('main');
  if (!q || !main) { if (status) status.textContent = ''; return; }

  const needle = q.toLowerCase();
  const walker = document.createTreeWalker(main, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      if (!node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
      if (SEARCH_SKIP.has(node.parentNode.nodeName)) return NodeFilter.FILTER_REJECT;
      if (node.parentNode.closest && node.parentNode.closest('.visually-hidden')) return NodeFilter.FILTER_REJECT;
      return node.nodeValue.toLowerCase().includes(needle)
        ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    },
  });

  const hits = [];
  let node;
  while ((node = walker.nextNode())) hits.push(node);

  let count = 0;
  let first = null;
  hits.forEach((textNode) => {
    const value = textNode.nodeValue;
    const frag = document.createDocumentFragment();
    let i = 0;
    let idx;
    const lower = value.toLowerCase();
    while ((idx = lower.indexOf(needle, i)) !== -1) {
      if (idx > i) frag.appendChild(document.createTextNode(value.slice(i, idx)));
      const mark = document.createElement('mark');
      mark.className = 'search-hit';
      mark.textContent = value.slice(idx, idx + needle.length);
      frag.appendChild(mark);
      if (!first) first = mark;
      count++;
      i = idx + needle.length;
    }
    if (i < value.length) frag.appendChild(document.createTextNode(value.slice(i)));
    textNode.parentNode.replaceChild(frag, textNode);
  });

  if (first) first.scrollIntoView({ block: 'center', behavior: 'smooth' });
  if (status) {
    status.textContent = count
      ? `${count} match${count === 1 ? '' : 'es'} for “${q}”. Showing the first.`
      : `No matches for “${q}” on this page.`;
  }
}
