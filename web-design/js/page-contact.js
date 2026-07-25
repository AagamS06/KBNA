/* Contact page wiring. Loaded with `defer` after the shared libraries.
   The form validates inline and accessibly (aria-invalid + per-field error
   text + focus to the first problem) instead of a blocking alert(). */
renderShell('contact');

document.getElementById('visit-address').innerHTML =
  `${BUSINESS.name}<br>${BUSINESS.street}<br>${BUSINESS.suburb}<br>
   <a href="${BUSINESS_LINKS.phone}">${BUSINESS.phone}</a>`;

document.getElementById('hours-list').innerHTML =
  BUSINESS.hours.map(([days, time]) => `<li>${esc(days)} — ${esc(time)}</li>`).join('');

document.getElementById('online-links').innerHTML = [
  ['Open in Google Maps', BUSINESS_LINKS.maps],
  [`Read our ${REVIEW_SUMMARY.count} Google reviews`, BUSINESS_LINKS.reviews],
  ['Write us a Google review', BUSINESS_LINKS.writeReview],
  ['Our page on the Knightsbridge Shopping Centre site', BUSINESS_LINKS.centre],
  ['Our Yelp listing', BUSINESS_LINKS.yelp],
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

// Clear a field's error as soon as the visitor starts fixing it.
form.addEventListener('input', (e) => {
  if (e.target.id) setError(e.target.id, '');
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
  if (!email.value.trim()) fail(email, 'Please add an email so we can reply.');
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim())) fail(email, 'That email address looks incomplete.');
  if (!message.value.trim()) fail(message, 'Please write a short message.');

  if (firstBad) { firstBad.focus(); return; }

  const body = `From: ${name.value.trim()} <${email.value.trim()}>\nPhone: ${phone.value.trim() || 'not provided'}\n\n${message.value.trim()}`;
  location.href = `mailto:${store.owner().email}?subject=${encodeURIComponent('Website enquiry from ' + name.value.trim())}&body=${encodeURIComponent(body)}`;
});
