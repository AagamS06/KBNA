/* Contact page wiring. Loaded with `defer` after the shared libraries.
   The form validates inline and accessibly (aria-invalid + per-field error
   text + focus to the first problem) instead of a blocking alert().

   Submission: the form is POSTed to a form-forwarding endpoint that emails
   the owner. Two options that both work with a static site:
     - Formspree:   https://formspree.io/f/XXXXXXXX   (recommended)
     - Web3Forms:   https://api.web3forms.com/submit  (uses an access_key)
   Set FORM_ENDPOINT once you've created the account and copied the URL.
   Until then, the form falls back to the previous mailto: behaviour so it
   still works locally without breaking. */
const FORM_ENDPOINT = ''; // e.g. 'https://formspree.io/f/xxxxxxx'
renderShell('contact');

document.getElementById('visit-address').innerHTML =
  `${BUSINESS.name}<br>${BUSINESS.street}<br>${BUSINESS.suburb}<br>
   <a href="${BUSINESS_LINKS.phone}">${BUSINESS.phone}</a>`;

document.getElementById('hours-list').innerHTML =
  BUSINESS.hours.map(([days, time]) => `<li>${esc(days)} — ${esc(time)}</li>`).join('');

document.getElementById('online-links').innerHTML = [
  ['Open in Google Maps', BUSINESS_LINKS.maps],
  ['Read our Google reviews here', BUSINESS_LINKS.reviews],
  ['Write us a Google review', BUSINESS_LINKS.writeReview],
  ['Check your Lotto numbers at the Lott', BUSINESS_LINKS.lott]
].map(([label, href]) =>
  `<li><a href="${href}" target="_blank" rel="noopener">${esc(label)}</a></li>`
).join('');

const form = document.getElementById('contact-form');

function setError(id, message) {
  const input = document.getElementById(id);
  const err = document.getElementById('err-' + id.split('-')[1]);
  if (message) {
    input.setAttribute('aria-invalid', 'true');
    if (err) { err.textContent = message; err.hidden = false; }
  } else {
    input.removeAttribute('aria-invalid');
    if (err) { err.textContent = ''; err.hidden = true; }
  }
}

const reachErr = document.getElementById('err-reach');
function setReachError(message) {
  const email = document.getElementById('c-email');
  const phone = document.getElementById('c-phone');
  if (message) {
    email.setAttribute('aria-invalid', 'true');
    phone.setAttribute('aria-invalid', 'true');
    reachErr.textContent = message; reachErr.hidden = false;
  } else {
    email.removeAttribute('aria-invalid');
    phone.removeAttribute('aria-invalid');
    reachErr.textContent = ''; reachErr.hidden = true;
  }
}

// Clear errors as soon as the visitor starts fixing them.
form.addEventListener('input', (e) => {
  if (e.target.id === 'c-email' || e.target.id === 'c-phone') setReachError('');
  else if (e.target.id) setError(e.target.id, '');
});

form.addEventListener('submit', e => {
  e.preventDefault();
  const name = document.getElementById('c-name');
  const email = document.getElementById('c-email');
  const phone = document.getElementById('c-phone');
  const message = document.getElementById('c-message');

  let firstBad = null;
  const fail = (el, msg) => { setError(el.id, msg); if (!firstBad) firstBad = el; };

  if (!name.value.trim()) fail(name, 'Please tell us your name.');

  // Email OR mobile — at least one; validate email format only if given.
  const hasEmail = !!email.value.trim();
  const hasPhone = !!phone.value.trim();
  if (!hasEmail && !hasPhone) {
    setReachError('Please give us an email or a mobile number so we can reply.');
    if (!firstBad) firstBad = email;
  } else if (hasEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim())) {
    setReachError('That email address looks incomplete.');
    if (!firstBad) firstBad = email;
  }

  if (!message.value.trim()) fail(message, 'Please write a short message.');

  if (firstBad) { firstBad.focus(); return; }

  const payload = {
    name: name.value.trim(),
    email: email.value.trim(),
    phone: phone.value.trim(),
    message: message.value.trim(),
    _subject: 'Website enquiry from ' + name.value.trim()
  };

  // Fallback to mailto if no endpoint is configured yet — keeps the form
  // usable during local dev / before the owner sets up the form service.
  if (!FORM_ENDPOINT) {
    const contact = [
      payload.email && `<${payload.email}>`,
      payload.phone && `phone ${payload.phone}`
    ].filter(Boolean).join(', ');
    const body = `From: ${payload.name} ${contact}\n\n${payload.message}`;
    location.href = `mailto:${store.owner().email}?subject=${encodeURIComponent(payload._subject)}&body=${encodeURIComponent(body)}`;
    return;
  }

  const submitBtn = form.querySelector('button[type="submit"]');
  if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = 'Sending…'; }

  fetch(FORM_ENDPOINT, {
    method: 'POST',
    headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  }).then(res => {
    if (!res.ok) throw new Error('send failed');
    form.innerHTML = `<p class="form-success" role="status">
      Thanks — we've got your message and will get back to you shortly.</p>`;
  }).catch(() => {
    if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = 'Send message'; }
    setReachError('Something went wrong sending that. Please call us on ' + BUSINESS.phone + '.');
  });
});
