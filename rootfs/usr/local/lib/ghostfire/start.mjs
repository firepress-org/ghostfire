// Seeds an empty or partial content volume from content.orig, then starts Ghost.
// Existing entries are never overwritten. The default themes stay symlinks to
// /var/lib/ghost/current, so they update with the image. Without
// verbatimSymlinks, cpSync would point them at the versioned directory, which
// the next Ghost version does not have.
import { cpSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const install = '/var/lib/ghost';
const content = join(install, 'content');
const orig = join(install, 'content.orig');

const seed = (from, to) => {
  if (!existsSync(to)) cpSync(from, to, { recursive: true, verbatimSymlinks: true });
};

for (const entry of readdirSync(orig, { withFileTypes: true })) {
  if (entry.isDirectory()) seed(join(orig, entry.name), join(content, entry.name));
}
for (const theme of readdirSync(join(orig, 'themes'))) {
  seed(join(orig, 'themes', theme), join(content, 'themes', theme));
}

process.chdir(install);
await import(join(install, 'current', 'index.js'));
