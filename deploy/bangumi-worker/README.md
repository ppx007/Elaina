# Bangumi Worker Mirror

This Cloudflare Worker is the recommended self-hosted Bangumi mirror for
Elaina. It proxies Bangumi API traffic and Bangumi image traffic without
embedding a public third-party mirror in the app.

## Routes

- `/api/*` proxies to `https://api.bgm.tv/*`.
- `/image?url=<encoded original image url>` proxies Bangumi images.

The image route only accepts `lain.bgm.tv` URLs and only supports `GET` and
`HEAD`, so the Worker does not become an open proxy.

## Deploy

1. Create a Cloudflare Worker.
2. Copy `worker.js` into the Worker editor or deploy it with Wrangler.
3. Bind the Worker to a domain, for example:
   `https://bangumi.example.com`.
4. Configure Elaina:
   - API mirror URL: `https://bangumi.example.com/api`
   - Image mirror URL: `https://bangumi.example.com/image`
   - Enable `使用 Bangumi 镜像` in Settings.

OAuth/token acquisition remains on the official Bangumi page. Do not proxy
token pages through this Worker unless a later change explicitly adds that
flow.
