/* About page wiring. Loaded with `defer` after the shared libraries.
   The page is static content; this only renders the shared header/footer
   and wires up the reveal-on-scroll for the `data-reveal` sections. Without
   initReveal() those sections stay at opacity 0 — which used to render as
   a big whitespace gap between the "Drop in" band and the footer on mobile. */
renderShell('about');
if (typeof initReveal === 'function') initReveal();
