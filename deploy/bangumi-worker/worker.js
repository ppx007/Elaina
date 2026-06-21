const BANGUMI_API_ORIGIN = 'https://api.bgm.tv';
const API_ROUTE_PREFIX = '/api';
const IMAGE_ROUTE_PATH = '/image';
const IMAGE_URL_PARAMETER = 'url';
const IMAGE_CACHE_CONTROL =
  'public, max-age=604800, s-maxage=2592000, immutable';
const ALLOWED_IMAGE_HOSTS = new Set(['lain.bgm.tv']);
const IMAGE_METHODS = new Set(['GET', 'HEAD']);

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return withCors(new Response(null, { status: 204 }));
    }

    const requestUrl = new URL(request.url);
    if (isApiRoute(requestUrl.pathname)) {
      return proxyApi(request, requestUrl);
    }
    if (requestUrl.pathname === IMAGE_ROUTE_PATH) {
      return proxyImage(request, requestUrl);
    }

    return withCors(new Response('Not found', { status: 404 }));
  },
};

function isApiRoute(pathname) {
  return pathname === API_ROUTE_PREFIX ||
    pathname.startsWith(`${API_ROUTE_PREFIX}/`);
}

async function proxyApi(request, requestUrl) {
  const upstreamUrl = new URL(BANGUMI_API_ORIGIN);
  const upstreamPath = requestUrl.pathname.slice(API_ROUTE_PREFIX.length);
  upstreamUrl.pathname = upstreamPath === '' ? '/' : upstreamPath;
  upstreamUrl.search = requestUrl.search;

  const response = await fetch(new Request(upstreamUrl, request));
  return withCors(response);
}

async function proxyImage(request, requestUrl) {
  if (!IMAGE_METHODS.has(request.method)) {
    return withCors(new Response('Image proxy only supports GET and HEAD', {
      status: 405,
    }));
  }

  const rawImageUrl = requestUrl.searchParams.get(IMAGE_URL_PARAMETER);
  if (rawImageUrl === null || rawImageUrl.trim() === '') {
    return withCors(new Response('Missing image URL', { status: 400 }));
  }

  let imageUrl;
  try {
    imageUrl = new URL(rawImageUrl);
  } catch (_) {
    return withCors(new Response('Invalid image URL', { status: 400 }));
  }

  if (!isAllowedImageUrl(imageUrl)) {
    return withCors(new Response('Image host is not allowed', { status: 403 }));
  }

  const response = await fetch(new Request(imageUrl, request));
  const headers = new Headers(response.headers);
  headers.set('Cache-Control', IMAGE_CACHE_CONTROL);
  return withCors(new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  }));
}

function isAllowedImageUrl(imageUrl) {
  const schemeAllowed = imageUrl.protocol === 'https:' ||
    imageUrl.protocol === 'http:';
  return schemeAllowed && ALLOWED_IMAGE_HOSTS.has(imageUrl.hostname);
}

function withCors(response) {
  const headers = new Headers(response.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, User-Agent');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
