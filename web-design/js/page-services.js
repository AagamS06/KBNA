/* Services page wiring. Loaded with `defer` after the shared libraries.
   The page is static content; this only renders the shared header/footer
   and wires up initReveal() so `data-reveal` sections don't stay at opacity 0. */
renderShell('services');
if (typeof initReveal === 'function') initReveal();
