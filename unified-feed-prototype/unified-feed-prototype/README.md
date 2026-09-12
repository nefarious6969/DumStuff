# Veil unified-feed prototype

This is a clickable product prototype for the proposed iOS app. It demonstrates a media-first feed combining autoplaying muted video and photo cards from YouTube, Instagram, X, and Facebook, with a live protection state, per-card reveal, source selection, saved items, and following views.

Use the cover-style selector to try soft blur, pixel mosaic, black bar, or a custom text/image cover. The sensitive cards are sample states; the prototype does not attempt to classify real nudity. A native implementation would run an on-device Core ML classifier over incoming frames and cover detected breasts, genitalia, or buttocks before display.

The cards are sample data. The next native implementation would use separate `WKWebView` sessions for each supported service, a Core ML image classifier running on-device, and a blur layer in each protected view. Native iOS apps cannot read or alter the rendering of unrelated installed apps, so this prototype intentionally models the safer protected-browser approach.

Open `index.html` in a browser to try it.
# Veil X + Reddit prototype

This is a mobile-first browser prototype for the X + Reddit version of Veil. It includes large photo/video cards, muted autoplay, source filters, saved/following views, and local cover controls. The gear button opens a separate Settings page with Protection and Censored objects tabs, per-category switches for breasts, female genitalia, and female buttocks, and a detection-confidence control.

The Reddit source now loads image and video posts from a public subreddit listing. Use **Add subreddit** to change it; no Reddit credential is placed in the page. X remains behind the companion `veil-backend` OAuth service, which keeps the X client secret and user tokens server-side.

The folder is also PWA-ready. Serve it over HTTPS (or from `localhost` during development), open it in Safari on the iPhone, and use **Share → Add to Home Screen**. The service worker only caches the app shell; it does not collect credentials or upload media.

The X cards remain demo data until the OAuth backend is deployed. Paste its HTTPS URL into **Settings → Protection → X connection**, then use **Connect X securely**. See `../veil-backend/README.md` for the secure deployment setup.
