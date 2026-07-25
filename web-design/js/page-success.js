/* Order-complete page wiring. Loaded with `defer` after the shared libraries. */
renderShell('home');
const raw = sessionStorage.getItem('kn.lastReceipt');
if (raw) {
  const r = JSON.parse(raw);
  document.getElementById('receipt').innerHTML = `
    <section class="receipt">
      <h2>Order receipt</h2>
      <p><strong>Paid via:</strong> ${esc(r.payment_method)}</p>
      <ul>${r.items.map(i => `<li>${esc(i.name)} × ${i.qty} — ${money(i.price_cents * i.qty)}</li>`).join('')}</ul>
      <p><strong>Total: ${money(r.total_cents)} AUD</strong></p>
      ${r.heldNames?.length ? `<p class="notice notice-warning"><strong>Low-stock alert triggered</strong> for: ${r.heldNames.map(esc).join(', ')}. In production an email would be sent to the owner and these items are now hidden from customers until restocked.</p>` : ''}
    </section>`;
}
