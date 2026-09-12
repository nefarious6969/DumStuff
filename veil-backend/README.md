# Veil X OAuth backend

This small Node 20 service owns the X OAuth exchange. The browser only visits `/auth/x/start` and calls `/api/x/home`; it never receives `X_CLIENT_SECRET`.

## Configure

1. Create an X Developer App and enable OAuth 2.0 Authorization Code with PKCE.
2. Register the exact callback URL in `X_REDIRECT_URI`. Set `WEB_ORIGIN` to the PWA origin only, and `WEB_REDIRECT_URL` to its full page URL if the PWA is hosted below a path such as GitHub Pages.
3. Copy `.env.example` to `.env` and fill in the values. Keep `.env` out of Git.
4. Run `npm start` on an HTTPS host. GitHub Pages can host the PWA, but it cannot run this backend.
5. Paste the deployed backend origin into **Settings → Protection → X connection** in the PWA before using **Connect X securely**.

The starter keeps tokens in memory so a restart logs the user out. A production deployment should use an encrypted server-side session store and rotate secrets. The OAuth state and PKCE verifier are single-use and expire after ten minutes.
