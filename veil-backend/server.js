import http from 'node:http';
import crypto from 'node:crypto';

const PORT = Number(process.env.PORT || 8787);
const WEB_ORIGIN = process.env.WEB_ORIGIN || 'http://localhost:3000';
const WEB_REDIRECT_URL = process.env.WEB_REDIRECT_URL || WEB_ORIGIN;
const X_CLIENT_ID = process.env.X_CLIENT_ID || '';
const X_CLIENT_SECRET = process.env.X_CLIENT_SECRET || '';
const X_REDIRECT_URI = process.env.X_REDIRECT_URI || `http://localhost:${PORT}/auth/x/callback`;
const isProduction = process.env.NODE_ENV === 'production';

const pending = new Map();
const sessions = new Map();
const COOKIE = isProduction ? '; Secure' : '';

function random(size = 32) { return crypto.randomBytes(size).toString('base64url'); }
function base64url(buffer) { return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, ''); }
function parseCookies(req) { return Object.fromEntries((req.headers.cookie || '').split(';').map(v => v.trim().split('=').map(decodeURIComponent)).filter(([k, v]) => k && v)); }
function sendJson(res, status, body) { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...corsHeaders() }); res.end(JSON.stringify(body)); }
function corsHeaders() { return { 'Access-Control-Allow-Origin': WEB_ORIGIN, 'Access-Control-Allow-Credentials': 'true', 'Vary': 'Origin' }; }
function redirect(res, location, cookies = []) { res.writeHead(302, { Location: location, 'Cache-Control': 'no-store', 'Set-Cookie': cookies, ...corsHeaders() }); res.end(); }
function safeReturn(path = '') { return path.startsWith('/') && !path.startsWith('//') ? path : '/'; }
function frontend(suffix = '') { return new URL(suffix, WEB_REDIRECT_URL).toString(); }

function startOAuth(req, res) {
  if (!X_CLIENT_ID || !X_CLIENT_SECRET) return sendJson(res, 503, { error: 'X OAuth is not configured on the server.' });
  const state = random(24);
  const verifier = random(48);
  const challenge = base64url(crypto.createHash('sha256').update(verifier).digest());
  pending.set(state, { verifier, createdAt: Date.now() });
  const params = new URLSearchParams({ response_type: 'code', client_id: X_CLIENT_ID, redirect_uri: X_REDIRECT_URI, scope: 'tweet.read users.read offline.access', state, code_challenge: challenge, code_challenge_method: 'S256' });
  redirect(res, `https://x.com/i/oauth2/authorize?${params}`, [`veil_oauth_state=${encodeURIComponent(state)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=600${COOKIE}`]);
}

async function exchangeCode(code, verifier) {
  const credentials = Buffer.from(`${X_CLIENT_ID}:${X_CLIENT_SECRET}`).toString('base64');
  const response = await fetch('https://api.x.com/2/oauth2/token', { method: 'POST', headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ code, grant_type: 'authorization_code', redirect_uri: X_REDIRECT_URI, code_verifier: verifier }) });
  if (!response.ok) throw new Error(`X token exchange failed (${response.status})`);
  return response.json();
}

async function refreshAccessToken(session) {
  if (!session.refresh_token) return session;
  const credentials = Buffer.from(`${X_CLIENT_ID}:${X_CLIENT_SECRET}`).toString('base64');
  const response = await fetch('https://api.x.com/2/oauth2/token', { method: 'POST', headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ refresh_token: session.refresh_token, grant_type: 'refresh_token' }) });
  if (!response.ok) throw new Error(`X token refresh failed (${response.status})`);
  const token = await response.json();
  Object.assign(session, token, { expiresAt: Date.now() + Number(token.expires_in || 7200) * 1000 });
  return session;
}

async function xRequest(path, token) {
  const response = await fetch(`https://api.x.com${path}`, { headers: { Authorization: `Bearer ${token}` } });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.detail || `X API request failed (${response.status})`);
  return body;
}

async function oauthCallback(req, res, url) {
  const state = url.searchParams.get('state');
  const code = url.searchParams.get('code');
  const cookieState = parseCookies(req).veil_oauth_state;
  const flow = state && pending.get(state);
  pending.delete(state);
  if (!state || !code || !flow || state !== cookieState || Date.now() - flow.createdAt > 10 * 60 * 1000) return sendJson(res, 400, { error: 'OAuth state expired or did not match.' });
  try {
    const token = await exchangeCode(code, flow.verifier);
    const me = await xRequest('/2/users/me?user.fields=username,name,profile_image_url', token.access_token);
    const sessionId = random(32);
    sessions.set(sessionId, { ...token, user: me.data, expiresAt: Date.now() + Number(token.expires_in || 7200) * 1000 });
    redirect(res, frontend('?x=connected'), [`veil_session=${encodeURIComponent(sessionId)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000${COOKIE}`, `veil_oauth_state=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0${COOKIE}`]);
  } catch (error) {
    redirect(res, frontend('?x=error'));
  }
}

async function homeTimeline(req, res) {
  const sessionId = parseCookies(req).veil_session;
  const session = sessions.get(sessionId);
  if (!session) return sendJson(res, 401, { error: 'X is not connected.' });
  try {
    if (session.expiresAt && session.expiresAt < Date.now() + 30_000) await refreshAccessToken(session);
    const me = session.user || await xRequest('/2/users/me', session.access_token);
    const userId = me.data?.id || session.user?.id;
    const query = '?max_results=25&exclude=retweets,replies&tweet.fields=created_at,attachments,possibly_sensitive&expansions=attachments.media_keys,author_id&user.fields=username,name,profile_image_url&media.fields=preview_image_url,type,url,variants';
    const timeline = await xRequest(`/2/users/${encodeURIComponent(userId)}/timelines/reverse_chronological${query}`, session.access_token);
    sendJson(res, 200, { ...timeline, user: me.data });
  } catch (error) {
    sendJson(res, 502, { error: error.message });
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  if (req.method === 'OPTIONS') { res.writeHead(204, { ...corsHeaders(), 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' }); return res.end(); }
  if (req.method === 'GET' && url.pathname === '/health') return sendJson(res, 200, { ok: true });
  if (req.method === 'GET' && url.pathname === '/auth/x/start') return startOAuth(req, res);
  if (req.method === 'GET' && url.pathname === '/auth/x/callback') return oauthCallback(req, res, url);
  if (req.method === 'GET' && url.pathname === '/api/x/home') return homeTimeline(req, res);
  sendJson(res, 404, { error: 'Not found.' });
});

server.listen(PORT, () => console.log(`Veil OAuth backend listening on port ${PORT}`));
