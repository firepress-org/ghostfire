// Seeds an empty or partial content volume from content.orig, then starts Ghost.
// Existing entries are never overwritten. The default themes stay symlinks into
// the image, so they update with it.
import { cpSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const install = '/var/lib/ghost';
const content = join(install, 'content');
const orig = join(install, 'content.orig');

const seed = (from, to) => {
  if (!existsSync(to)) cpSync(from, to, { recursive: true });
};

for (const entry of readdirSync(orig, { withFileTypes: true })) {
  if (entry.isDirectory()) seed(join(orig, entry.name), join(content, entry.name));
}
for (const theme of readdirSync(join(orig, 'themes'))) {
  seed(join(orig, 'themes', theme), join(content, 'themes', theme));
}

process.chdir(install);
await import(join(install, 'current', 'index.js'));
