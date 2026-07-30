// Worker entry point for the site (Workers + Static Assets). It runs ahead of the asset
// store via assets.run_worker_first in wrangler.jsonc, and falls through to it via env.ASSETS.
//
// Only "/" auto-detects. "/en/" and "/" stay stable, linkable URLs for each language,
// and an explicit choice from the nav switcher (lang cookie) always beats the browser header.

const SUPPORTED = ['vi', 'en'];
const DEFAULT_LANG = 'vi'; // what "/" already serves
const PATHS = { vi: '/', en: '/en/' };

function parseAcceptLanguage(header) {
  if (!header) return [];
  return header
    .split(',')
    .map((part) => {
      const [tag, ...params] = part.trim().split(';');
      const qParam = params.map((p) => p.trim()).find((p) => p.startsWith('q='));
      const q = qParam ? Number.parseFloat(qParam.slice(2)) : 1;
      return { lang: tag.trim().toLowerCase().split('-')[0], q };
    })
    .filter((e) => e.lang && e.lang !== '*' && Number.isFinite(e.q) && e.q > 0)
    .sort((a, b) => b.q - a.q);
}

function preferredLanguage(header) {
  const ranked = parseAcceptLanguage(header);
  const match = ranked.find((e) => SUPPORTED.includes(e.lang));
  if (match) return match.lang;
  // Visitor asked for a language we don't publish (ja, fr, ...): English travels further
  // than Vietnamese. No header at all (most crawlers) means no opinion -> keep the default.
  return ranked.length ? 'en' : DEFAULT_LANG;
}

function readCookie(request, name) {
  const header = request.headers.get('Cookie');
  if (!header) return null;
  for (const part of header.split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('=')).trim().toLowerCase();
  }
  return null;
}

// "/" answers differently per visitor, so no shared cache may pin one answer to it.
function markAsNegotiated(headers) {
  headers.set('Vary', 'Accept-Language, Cookie');
  headers.set('Cache-Control', 'no-store');
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

// Deliberately permissive but structural: rejects the typos people actually make
// (missing @, missing dot, trailing comma) without trying to out-lawyer RFC 5322.
const EMAIL = /^[^\s@,;]+@[^\s@,;.]+(?:\.[^\s@,;.]+)+$/;

// Browser -> here -> Apps Script -> sheet. The Apps Script URL and its shared secret
// live in Pages env vars, so they never reach the page source.
async function handleSubscribe(request, env) {
  if (request.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'method_not_allowed' }, 405);
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
  }

  // Honeypot: a bot filled the hidden field. Answer 200 so it never learns it failed.
  if (typeof payload.website === 'string' && payload.website.trim() !== '') {
    return jsonResponse({ ok: true });
  }

  const email = String(payload.email ?? '').trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) {
    return jsonResponse({ ok: false, error: 'invalid_email' }, 422);
  }

  if (!env.SHEET_WEBHOOK_URL || !env.SHEET_WEBHOOK_SECRET) {
    return jsonResponse({ ok: false, error: 'not_configured' }, 503);
  }

  const lang = String(payload.lang ?? '').slice(0, 12);
  const body = new URLSearchParams({
    secret: env.SHEET_WEBHOOK_SECRET,
    email,
    lang,
    country: request.headers.get('CF-IPCountry') ?? '',
    referer: (request.headers.get('Referer') ?? '').slice(0, 300),
  });

  let upstream;
  try {
    upstream = await fetch(env.SHEET_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body,
      // Apps Script answers 302 to googleusercontent.com; the payload is behind it.
      redirect: 'follow',
    });
  } catch {
    return jsonResponse({ ok: false, error: 'upstream_unreachable' }, 502);
  }

  let result = {};
  try {
    result = await upstream.json();
  } catch {
    // Apps Script serves an HTML error page when the script itself throws.
    return jsonResponse({ ok: false, error: 'upstream_bad_response' }, 502);
  }

  if (!upstream.ok || !result.ok) {
    return jsonResponse({ ok: false, error: 'upstream_rejected' }, 502);
  }

  return jsonResponse({ ok: true, duplicate: result.duplicate === true });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Must precede the asset fallthrough: a POST would otherwise be handed to ASSETS.
    if (url.pathname === '/api/subscribe') return handleSubscribe(request, env);

    const isRoot = url.pathname === '/' || url.pathname === '/index.html';
    const isReadOnly = request.method === 'GET' || request.method === 'HEAD';

    if (!isRoot || !isReadOnly) return env.ASSETS.fetch(request);

    const saved = readCookie(request, 'lang');
    const lang = SUPPORTED.includes(saved)
      ? saved
      : preferredLanguage(request.headers.get('Accept-Language'));

    if (lang !== DEFAULT_LANG) {
      const target = new URL(url);
      target.pathname = PATHS[lang];
      const headers = new Headers({ Location: target.toString() });
      markAsNegotiated(headers);
      // 302, not 301: the right target depends on who is asking, so it must not be memorised.
      return new Response(null, { status: 302, headers });
    }

    const response = await env.ASSETS.fetch(request);
    const negotiated = new Response(response.body, response);
    markAsNegotiated(negotiated.headers);
    return negotiated;
  },
};
