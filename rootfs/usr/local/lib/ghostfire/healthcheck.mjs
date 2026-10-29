// HEALTHCHECK for an image without curl: exits 0 only when the admin site API
// answers 200. Ghost takes url, admin.url, and server.port from the environment
// first, then from config.<NODE_ENV>.json; this does the same.
import { readFileSync } from 'node:fs';
import { get } from 'node:http';

const readConfig = () => {
  const file = `/var/lib/ghost/config.${process.env.NODE_ENV ?? 'development'}.json`;
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch {
    return {};
  }
};

const config = readConfig();
const site = new URL(process.env.url ?? config.url ?? 'http://localhost:2368');
// With a separate admin.url, Ghost serves the admin API only on that host,
// still under the path of the site url.
const admin = new URL(process.env.admin__url ?? config.admin?.url ?? site);
const port = Number(process.env.server__port ?? config.server?.port ?? 2368);
const path = `${site.pathname.replace(/\/?$/, '/')}ghost/api/admin/site/`;
const target = `${admin.host}${path}`;

const fail = (reason) => {
  console.log(`${target} ${reason}`);
  process.exit(1);
};

// node:http, because fetch cannot set Host. Ghost redirects plain http to
// https when the url is https, unless a proxy reports the original scheme, as
// the reverse proxy in front of it does.
const request = get(
  {
    host: '127.0.0.1',
    port,
    path,
    headers: { Host: admin.host, 'X-Forwarded-Proto': admin.protocol.slice(0, -1) },
    timeout: 5000,
  },
  (response) => {
    response.resume();
    if (response.statusCode !== 200) fail(response.statusCode);
    console.log(`${target} 200`);
    process.exit(0);
  },
);
request.on('timeout', () => request.destroy(new Error('no answer after 5 s')));
request.on('error', (error) => fail(error.message));
