/* Basket page wiring. Loaded with `defer` after the shared libraries. */
renderShell('cart');

function render() {
  const lines = store.cartLines();
  const total = lines.reduce((s, l) => s + l.price_cents * l.qty, 0);
  const body = document.getElementById('cart-body');

  if (!lines.length) {
    body.innerHTML = `
      <p>Your basket is empty.</p>
      <p><a class="btn btn-primary btn-arrow" href="shop.html">Browse the shop</a></p>`;
    return;
  }

  body.innerHTML = `
    <table class="cart-table">
      <caption class="visually-hidden">Items in your basket</caption>
      <thead><tr><th>Item</th><th>Price</th><th>Quantity</th><th>Subtotal</th></tr></thead>
      <tbody>
        ${lines.map(l => `
          <tr>
            <th scope="row">${esc(l.name)}</th>
            <td>${money(l.price_cents)}</td>
            <td>
              <div class="qty-form">
                <label class="visually-hidden" for="q-${l.id}">Quantity of ${esc(l.name)}</label>
                <input id="q-${l.id}" type="number" min="0" max="${l.stock}" value="${l.qty}" data-qty="${l.id}">
              </div>
            </td>
            <td>${money(l.price_cents * l.qty)}</td>
          </tr>`).join('')}
      </tbody>
      <tfoot><tr><th scope="row" colspan="3">Total (AUD)</th><td class="cart-total">${money(total)}</td></tr></tfoot>
    </table>

    <section class="pay-options" aria-labelledby="pay-h">
      <h2 id="pay-h">Choose how to pay</h2>
      <p class="notice">Live card / PayPal processing needs a server — this browser demo simulates the payment so you can see the whole flow (stock decrement, low-stock hold, order recorded in the owner portal).</p>
      <div class="pay-grid">
        <div class="pay-card">
          <h3>Card payment (Stripe)</h3>
          <p>In production this would open Stripe Checkout.</p>
          <button class="btn btn-primary btn-block" id="pay-stripe">Simulate card payment</button>
        </div>
        <div class="pay-card">
          <h3>PayPal</h3>
          <p>In production this would show PayPal Smart Buttons.</p>
          <button class="btn btn-primary btn-block" id="pay-paypal">Simulate PayPal payment</button>
        </div>
      </div>
    </section>`;
}

function pay(method) {
  const result = store.fulfilOrder(method);
  if (!result) return;
  const heldNames = result.lowStock.map(p => p.name);
  sessionStorage.setItem('kn.lastReceipt', JSON.stringify({ ...result.order, heldNames }));
  location.href = 'success.html';
}

document.addEventListener('input', e => {
  const id = e.target.dataset?.qty;
  if (!id) return;
  store.setCartQty(id, parseInt(e.target.value, 10) || 0);
  renderShell('cart');
  render();
});
document.addEventListener('click', e => {
  if (e.target.id === 'pay-stripe') pay('stripe');
  if (e.target.id === 'pay-paypal') pay('paypal');
});

render();
