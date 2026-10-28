// HEALTHCHECK for an image without curl: exits 0 only when the admin site API
// answers 200 under the path of the site url. Ghost takes the url from the
// environment first, then from config.<NODE_ENV>.json; this does the same.
import { readFileSync } from 'node:fs';

const configUrl = () => {
  const file = `/var/lib/ghost/config.${process.env.NODE_ENV ?? 'development'}.json`;
  try {
    return JSON.parse(readFileSync(file, 'utf8')).url;
  } catch {
    return undefined;
  }
};

const url = new URL(process.env.url ?? configUrl() ?? 'http://localhost:2368');
const path = url.pathname.replace(/\/?$/, '/');
const target = `http://127.0.0.1:2368${path}ghost/api/admin/site/`;

try {
  // Ghost redirects plain http to https when the url is https, unless a proxy
  // reports the original scheme, as the reverse proxy in front of it does.
  const response = await fetch(target, {
    headers: { 'X-Forwarded-Proto': url.protocol.slice(0, -1) },
    redirect: 'manual',
    signal: AbortSignal.timeout(5000),
  });
  console.log(`${target} ${response.status}`);
  process.exit(response.status === 200 ? 0 : 1);
} catch (error) {
  console.log(`${target} ${error.message}`);
  process.exit(1);
}
