Knightsbridge Newsagency — Demo Build
=====================================

HOW TO RUN
----------
Unzip, then double-click index.html. Opens in Chrome.
No install, no Node, no server, no build step.


WHAT'S NEW IN THIS VERSION
--------------------------
- The owner portal has been REMOVED from the website — see the section
  below, because it has consequences you need to know about.
- Gallery photos can now be picked from your phone, iCloud or Google
  Photos.
- Opening hours corrected to weekdays 8am-6pm, weekends 8am-4pm, and
  moved into one place (BUSINESS.hours in js/reviews.js) so the footer
  and the contact page can never disagree.
- Footer links given proper 44px tap targets — they were 21px tall and
  a genuine nuisance to hit on a phone.
- New "Have a look around" gallery section on the home page.
- Stock items can now carry a photo, and one is found automatically
  when you don't supply your own. See PHOTOS below — it does NOT
  search Google, and the reason matters.
- Rebuilt the layout in a modern agency style, taking structure from
  digitalzoop.com.au but keeping the shop's own red/black/white:
  * Full-bleed bands alternating white, light grey and black, instead
    of one narrow column down the middle
  * A small red letter-spaced label ("BROWSE", "TESTIMONIALS") above
    every section heading
  * Bigger, tighter headings in Plus Jakarta Sans
  * Flat cards with hairline borders — the drop shadows are gone
  * Pill buttons with a circular arrow badge, used only on the one
    call to action that leads a section
  * A "Step 01 / 02 / 03" ordering explainer and a stat band
  The reference site is dark end to end. This one is light with dark
  feature bands, because the audience is 25-55 and prices, product
  names and forms are easier to read on white.
- Recoloured to the logo: signal red #E1251B, black and white, and
  nothing else. The generated artwork was redrawn in the same three
  colours, so the whole site now matches the sign above the shop.
- Reviews are now a slideshow, not a static row:
  * One review at a time, rotating every 7 seconds
  * Star ratings shown as ★ symbols, with the rating also read aloud
  * Overall score (4.2 from 147 Google reviews) above the slideshow
  * Pause/play, prev/next, dots — same keyboard and reduced-motion
    behaviour as the hero carousel
  * "Write a review on Google" button underneath
- Real outbound links: Google Maps directions, the Google reviews
  listing, the Knightsbridge Shopping Centre page, the Yelp listing,
  the Lott, and a tap-to-call phone number. All in the footer on every
  page, plus a "Find us online" list and opening hours on Contact.
- Auto-rotating hero carousel: 4 illustrated slides (papers, magazines,
  cards & gifts, lotto & toys) that cycle every 6.5 seconds.
- Every product card has its own generated artwork, keyed to its
  category tag. Items the owner adds later get artwork automatically —
  no uploads needed. An image web address, if supplied, overrides it.


PHOTOS — AND WHY NOT GOOGLE IMAGES
----------------------------------
Add a stock item, leave "Photo web address" blank, and a photo is
found and attached for you when you save. It searches Openverse (the
Creative Commons index — Flickr, museums, Wikimedia), filtered to
images licensed for COMMERCIAL use, and the credit the licence
requires is captured and printed under the product automatically.

It deliberately does not search Google Images, for two reasons:

  1. No static page can. Google's search API needs a secret key,
     which here would sit in plain view in the page source, and it
     stops at 100 lookups a day.

  2. The one that actually matters: Google Images is an index, not a
     library of images you may use. Nearly everything in it belongs
     to someone — publishers, press agencies, brands. Putting those
     on items for sale on your own website is commercial publishing
     without a licence, and the shop carries that risk, not Google.

For real product shots, ask your suppliers for their trade/media
pack — those come with permission attached. Paste the address into
the photo box and it overrides everything else.

Notes:
- Openverse allows 20 lookups a minute and 200 a day per address, so
  the six gallery photos are cached in the browser for 30 days rather
  than fetched on every visit. Product lookups happen once, when you
  add the item.
- Offline, or if a lookup fails, nothing breaks: the item still saves
  and falls back to its generated category artwork. A photo that
  later stops loading falls back the same way.

PUTTING YOUR OWN PHOTOS IN THE GALLERY
--------------------------------------
The stand-in photos are there so the section isn't empty. Real photos
of your shop will do far more. Make an `images/` folder next to
index.html, drop your photos in, then edit the GALLERY list near the
bottom of js/images.js:

    { src: 'images/magazine-wall.jpg', tag: 'Magazine',
      caption: 'The magazine wall', feature: true },

Any tile with a `src` skips the search entirely — no network call, no
credit line needed, because the photo is yours.


EDITING THE REVIEWS AND LINKS
-----------------------------
Everything lives at the top of js/reviews.js:

  BUSINESS        name, address, phone
  BUSINESS_LINKS  every outbound web address, in one place
  REVIEW_SUMMARY  the overall score and review count
  REVIEWS         the quotes in the slideshow

Two things worth doing before this goes live:

1. Paste your Google Place ID into GOOGLE_PLACE_ID (js/reviews.js,
   line 17). That turns "Write a review" into a one-tap deep link
   straight to the review box. Left blank it still works — it opens
   your Google listing and the customer taps "Write a review" there.

2. Check the REVIEWS list against your Google Business Profile and
   swap in whichever comments you'd rather lead with. Keep the `stars`
   number matching what the customer actually left.

All artwork is drawn in code as SVG. Nothing is downloaded, nothing is
copyrighted, and it all works with the internet switched off. The
outbound links and the photo lookup are the only parts that need a
connection, and both fail softly — the drawn artwork takes over.

Accessibility is unchanged and still WCAG 2.0 AA: skip link, landmarks,
labelled forms, 4.5:1 text contrast everywhere, visible focus rings,
48px touch targets, and full keyboard control of both carousels.
Red is never used as body text on black — a lighter tint of the same
red is used there so it still clears 4.5:1. Borders that outline a
control (buttons, inputs, chips, carousel dots) are darker than a
plain hairline so they clear the separate 3:1 rule for non-text.


THE OWNER PORTAL HAS MOVED OUT OF THE WEBSITE
---------------------------------------------
owner.html is gone from the site. Sign-in, stock editing and order
history now belong to the owner's mobile app; the website is the
shop front only. Every link to it has been removed, and the demo
password no longer ships in the JavaScript, which is the bigger win —
a public site should never have carried one.

READ THIS BEFORE RELYING ON IT: the app is at the design stage, not
built. Until it exists and has a backend behind it, there is NO way
to add or edit stock. The website reads the sample catalogue and
nothing can change it. If you need to manage stock in the meantime,
the old portal is preserved, unchanged, at:

    ../_archive/owner.html

Move it back beside index.html and it works exactly as before. It was
archived rather than deleted because this project has no git history,
so a delete would have been permanent.

Designs for the replacement app are in ../app-design/.


PHOTOS FROM YOUR PHONE, ICLOUD AND GOOGLE PHOTOS
------------------------------------------------
Open the home page with ?photos on the end:

    index.html?photos

Each gallery tile gains a "Choose a photo" button. That opens your
phone's own photo picker — which on iPhone lists your iCloud Photos
library, and on Android lists Google Photos. Pick one and it replaces
the stand-in immediately.

Neither iCloud nor Google Photos can be connected to directly from a
web page. Apple provides no third-party API for iCloud Photos at all.
Google withdrew full library access from third-party apps in 2025.
Going through the phone's own picker sidesteps both: no key, no
account, no permission prompt, and the same photos.

Your photos are scaled to 1200px and re-encoded before being stored,
which cuts a 4MB phone photo to well under 100KB and — importantly —
strips the EXIF data, including the GPS coordinates of wherever the
photo was taken.

Photos you choose are yours, so no credit line is shown. They also
survive the Openverse cache being cleared.


WHAT WORKS
----------
- Shop, category filter, cart, quantity updates
- Gallery photos from your phone, iCloud or Google Photos (?photos)
- Automatic product photos from Openverse, with credits
- Simulated Stripe + PayPal checkout: decrements stock, auto-holds
  low items, shows the alert that would email the owner in production


WHAT DOESN'T (browser-only limits)
----------------------------------
- Managing stock — that moved to the app, which isn't built yet
- Real payments — Stripe/PayPal need secret keys, which need a server
- Contact form opens your email app via mailto: instead of Resend
- Data lives in localStorage in THIS browser only, so a photo added on
  your phone does not appear on anyone else's device. Fixing that needs
  the backend described in ../app-design/01-architecture.md.


TO GO LIVE
----------
The website needs a small backend so the app and the site share one
catalogue. See ../app-design/01-architecture.md for the recommended
option and what it costs.
