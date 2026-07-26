/* Knightsbridge Newsagency — floating help chat.

   This is a LOCAL, RULE-BASED helper. It is NOT an LLM and makes NO network
   calls: every answer comes from the keyword rules below, reading the same
   in-page data the rest of the site uses (BUSINESS + BUSINESS_LINKS from
   reviews.js, and the live `store` catalogue from app.js). That keeps it
   CSP-safe (script-src 'self') and fully offline / file:// friendly.

   Security: user-typed text is only ever inserted with textContent (never
   innerHTML), and anything echoed elsewhere is passed through esc(). Bot
   replies are built as real DOM nodes so links stay safe. */

(function () {
  'use strict';

  // Reuse the site's escaper if present, else a local equivalent.
  const escape = (typeof esc === 'function')
    ? esc
    : (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  const fmtMoney = (typeof money === 'function') ? money : (c) => `$${(c / 100).toFixed(2)}`;

  // Business facts, read from reviews.js when available with safe fallbacks.
  const BIZ = (typeof BUSINESS !== 'undefined') ? BUSINESS : {
    name: 'Knightsbridge Newsagency',
    street: 'Shop 5, 159 Ridgecrop Drive',
    suburb: 'Castle Hill NSW 2154',
    phone: '02 9634 1591',
    phoneHref: 'tel:+61296341591',
    hours: [['Monday to Friday', '8am – 6pm'], ['Saturday and Sunday', '8am – 4pm']]
  };
  const LINKS = (typeof BUSINESS_LINKS !== 'undefined') ? BUSINESS_LINKS : {
    maps: 'https://www.google.com/maps/search/?api=1&query=Knightsbridge+Newsagency+Castle+Hill',
    phone: BIZ.phoneHref
  };

  /* ---------------- Reply builders ----------------
     Each returns an array of "segments": strings, or {text, href, external}
     link objects. The renderer turns them into safe DOM nodes. */

  function link(text, href, external) { return { text, href, external: !!external }; }

  function hoursReply() {
    const lines = BIZ.hours.map(([d, t]) => `${d}: ${t}`).join('\n');
    return [`We're open:\n${lines}\n\nOpen seven days.`];
  }

  function locationReply() {
    return [
      `You'll find us at ${BIZ.street}, ${BIZ.suburb}, inside the Knightsbridge Shopping Village.\n\n`,
      link('Open in Google Maps', LINKS.maps, true)
    ];
  }

  function contactReply() {
    return [
      'Give us a call on ',
      link(BIZ.phone, LINKS.phone || BIZ.phoneHref),
      ', or send a message from our ',
      link('contact page', 'contact.html'),
      '.'
    ];
  }

  function servicesReply() {
    return [
      'Alongside papers, magazines, cards, gifts, toys, stationery and lottery, ' +
      'we also offer ParcelPoint parcel collection and drop-off, a dry-cleaning ' +
      'agency, and PO box hire.\n\n',
      link('See all our services', 'services.html')
    ];
  }

  // Live product lookup against the in-page catalogue.
  function productReply(q) {
    let products = [];
    try {
      if (typeof store !== 'undefined' && store.activeProducts) {
        products = store.activeProducts().filter((p) => p.active && !p.held && p.stock > 0);
      }
    } catch (_) { products = []; }

    if (!products.length) {
      return [
        "I can't read the range just now — have a browse of the ",
        link('products page', 'products.html'), '.'
      ];
    }

    const STOP = new Set(['the', 'you', 'your', 'our', 'and', 'are', 'for', 'can',
      'get', 'got', 'have', 'has', 'how', 'much', 'they', 'sell', 'stock', 'buy',
      'price', 'cost', 'carry', 'any', 'some', 'does', 'did', 'with', 'that',
      'this', 'looking', 'here', 'there', 'want', 'need', 'sale', 'shop']);
    const words = q.toLowerCase().split(/[^a-z0-9]+/)
      .filter((w) => w.length > 2 && !STOP.has(w));
    const scored = products
      .map((p) => {
        const hay = (p.name + ' ' + p.tag + ' ' + (p.description || '')).toLowerCase();
        let score = 0;
        words.forEach((w) => {
          // Match the word, or a simple singular/plural stem, so "magazines"
          // still finds "Magazine" and "cards" finds "Card".
          const stem = w.replace(/(ies|es|s)$/, '');
          if (hay.includes(w) || (stem.length > 2 && hay.includes(stem))) score += 1;
        });
        return { p, score };
      })
      .filter((x) => x.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 4)
      .map((x) => x.p);

    if (!scored.length) {
      return [
        "I couldn't spot that on the shelf. You can search the full range on our ",
        link('products page', 'products.html'),
        ' or call us to check.'
      ];
    }

    const listed = scored.map((p) => `• ${p.name} — ${fmtMoney(p.price_cents)}`).join('\n');
    const singleTag = scored.every((p) => p.tag === scored[0].tag) ? scored[0].tag : null;
    const href = singleTag
      ? `products.html?tag=${encodeURIComponent(singleTag)}`
      : 'products.html';
    return [
      `Here's what I found in store:\n${listed}\n\n`,
      link('Reserve online for collection', href)
    ];
  }

  function fallbackReply() {
    return [
      "Sorry, I'm not sure about that one — I can help with opening hours, where " +
      'to find us, our services, and whether we stock something. For anything ' +
      'else, the best ways are:\n\n',
      '• Get in touch your way — call ',
      link(BIZ.phone, LINKS.phone || BIZ.phoneHref),
      ' or use our ',
      link('contact page', 'contact.html'),
      '.\n• Pop in and ask us in store — we love a chat.\n• Or have a look yourself on our ',
      link('products page', 'products.html'),
      '.'
    ];
  }

  // Route a question to a reply. Order matters: most specific first.
  function answer(raw) {
    const q = raw.toLowerCase();
    const has = (...w) => w.some((x) => q.includes(x));

    if (has('hour', 'open', 'close', 'closing', 'opening', 'what time', 'when are you')) {
      return hoursReply();
    }
    if (has('where', 'location', 'address', 'direction', 'directions', 'find you',
            'parking', 'map', 'located', 'get to')) {
      return locationReply();
    }
    if (has('parcel', 'parcelpoint', 'dry clean', 'dry-clean', 'dry cleaning',
            'po box', 'pobox', 'post office box', 'service', 'services',
            'laminate', 'photocop', 'print', 'fax')) {
      return servicesReply();
    }
    if (has('phone', 'call', 'contact', 'email', 'reach you', 'number', 'talk to')) {
      return contactReply();
    }
    if (has('sell', 'stock', 'have you got', 'do you have', 'how much', 'price',
            'cost', 'buy', 'carry', 'looking for', 'magazine', 'paper', 'card',
            'gift', 'toy', 'stationery', 'lottery', 'lotto', 'pen', 'candle',
            'notebook', 'puzzle', 'crossword', 'scratch')) {
      return productReply(raw);
    }
    if (has('hi', 'hello', 'hey', 'help', 'g\'day', 'gday')) {
      return ['Hi! I can help with opening hours, directions, our services, and ' +
              'whether we stock something. What are you after?'];
    }
    return fallbackReply();
  }

  /* ---------------- UI ---------------- */

  const REDUCE = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let root, launcher, panel, log, input, liveRegion, isOpen = false;

  function el(tag, attrs, kids) {
    const node = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach((k) => {
      if (k === 'class') node.className = attrs[k];
      else node.setAttribute(k, attrs[k]);
    });
    (kids || []).forEach((c) => node.appendChild(
      typeof c === 'string' ? document.createTextNode(c) : c));
    return node;
  }

  // Render reply segments into a message bubble as safe DOM nodes.
  function bubble(role, segments) {
    const wrap = el('div', { class: `cbot-msg cbot-${role}` });
    const b = el('div', { class: 'cbot-bubble' });
    segments.forEach((seg) => {
      if (typeof seg === 'string') {
        // Preserve newlines without innerHTML.
        seg.split('\n').forEach((line, i) => {
          if (i) b.appendChild(el('br'));
          b.appendChild(document.createTextNode(line));
        });
      } else if (seg && seg.href) {
        const a = el('a', { href: seg.href });
        if (seg.external) { a.target = '_blank'; a.rel = 'noopener'; }
        a.textContent = seg.text;
        b.appendChild(a);
      }
    });
    wrap.appendChild(b);
    return wrap;
  }

  function addUser(text) {
    const wrap = el('div', { class: 'cbot-msg cbot-user' });
    const b = el('div', { class: 'cbot-bubble' });
    b.textContent = text;                 // never innerHTML of user input
    wrap.appendChild(b);
    log.appendChild(wrap);
    scrollDown();
  }

  function addBot(segments) {
    log.appendChild(bubble('bot', segments));
    scrollDown();
    // Announce the plain-text version for screen readers.
    const plain = segments.map((s) => (typeof s === 'string' ? s : s.text)).join(' ');
    liveRegion.textContent = '';
    // Reassign on next tick so repeated identical answers still announce.
    window.setTimeout(() => { liveRegion.textContent = plain; }, 50);
  }

  function scrollDown() { log.scrollTop = log.scrollHeight; }

  function send() {
    const text = input.value.trim();
    if (!text) return;
    addUser(text);
    input.value = '';
    const reply = answer(text);
    addBot(reply);
  }

  function openPanel() {
    if (isOpen) return;
    isOpen = true;
    panel.hidden = false;
    launcher.setAttribute('aria-expanded', 'true');
    launcher.setAttribute('aria-label', 'Close help chat');
    root.classList.add('is-open');
    window.setTimeout(() => input.focus(), REDUCE ? 0 : 120);
  }

  function closePanel() {
    if (!isOpen) return;
    isOpen = false;
    panel.hidden = true;
    launcher.setAttribute('aria-expanded', 'false');
    launcher.setAttribute('aria-label', 'Open help chat');
    root.classList.remove('is-open');
    launcher.focus();
  }

  function togglePanel() { isOpen ? closePanel() : openPanel(); }

  function build() {
    root = el('div', { class: 'cbot' + (REDUCE ? ' cbot-reduce' : '') });

    launcher = el('button', {
      type: 'button', class: 'cbot-launcher',
      'aria-haspopup': 'dialog', 'aria-expanded': 'false',
      'aria-controls': 'cbot-panel', 'aria-label': 'Open KBNA Assistant chat'
    });
    launcher.appendChild(el('span', { 'aria-hidden': 'true', class: 'cbot-launcher-icon' }, ['💬']));

    panel = el('div', {
      class: 'cbot-panel', id: 'cbot-panel', role: 'dialog',
      'aria-modal': 'false', 'aria-label': 'KBNA Assistant chat'
    });
    panel.hidden = true;

    const header = el('div', { class: 'cbot-header' }, [
      el('span', { class: 'cbot-title' }, ['KBNA Assistant']),
      (function () {
        const close = el('button', {
          type: 'button', class: 'cbot-close', 'aria-label': 'Close help chat'
        });
        close.appendChild(el('span', { 'aria-hidden': 'true' }, ['×']));
        close.addEventListener('click', closePanel);
        return close;
      })()
    ]);

    log = el('div', { class: 'cbot-log' });

    const form = el('form', { class: 'cbot-form' });
    input = el('input', {
      type: 'text', class: 'cbot-input', name: 'q',
      autocomplete: 'off', placeholder: 'Type your question…',
      'aria-label': 'Type your question'
    });
    const sendBtn = el('button', { type: 'submit', class: 'cbot-send' },
      [el('span', { 'aria-hidden': 'true' }, ['➤'])]);
    sendBtn.setAttribute('aria-label', 'Send message');
    form.appendChild(input);
    form.appendChild(sendBtn);
    form.addEventListener('submit', (e) => { e.preventDefault(); send(); });

    liveRegion = el('div', { class: 'visually-hidden', 'aria-live': 'polite', 'aria-atomic': 'true' });

    panel.appendChild(header);
    panel.appendChild(log);
    panel.appendChild(form);
    panel.appendChild(liveRegion);

    root.appendChild(panel);
    root.appendChild(launcher);
    document.body.appendChild(root);

    launcher.addEventListener('click', togglePanel);
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && isOpen) { e.preventDefault(); closePanel(); }
    });

    // Greeting, added once so it's read when the panel first opens.
    addBot(['G\'day! I\'m the KBNA Assistant. Ask me about opening hours, ' +
            'where we are, our services, or whether we stock something.']);
  }

  function mount() {
    if (document.querySelector('.cbot')) return;   // guard against double-mount
    build();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mount);
  } else {
    mount();
  }
})();
