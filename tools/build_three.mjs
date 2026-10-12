import { mkdir, cp, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(root, 'site/three');
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await cp(resolve(root, 'web/three/index.html'), resolve(out, 'index.html'));
await cp(resolve(root, 'web/three/app.js'), resolve(out, 'app.js'));
const bundle = await build({entryPoints:[resolve(root,'tools/three_global_entry.js')],bundle:true,format:'esm',minify:true,write:false});
await writeFile(resolve(out, 'three.module.js'), bundle.outputFiles[0].contents);
await cp(resolve(root, 'data/levels/levels.json'), resolve(out, 'levels.json'));
await writeFile(resolve(out, 'README.txt'), 'Busão Lotado — runtime Three.js browser-first\n');
console.log(`three build ready: ${out}`);
