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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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
