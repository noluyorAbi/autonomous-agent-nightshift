// Bundles the Ink TUI (src + all npm deps) into one self-contained ESM file
// with a node shebang. `npm install -g` ships this prebuilt file; no build or
// node_modules install is needed at the user's end.
import { build } from 'esbuild';
import { chmodSync } from 'node:fs';

const outfile = 'dist/cli.js';

await build({
  entryPoints: ['src/cli.tsx'],
  outfile,
  bundle: true,
  platform: 'node',
  format: 'esm',
  // ink 7 requires Node >= 22; bin/nightshift gates the UI on Node >= 22 and
  // falls back to the bash UI below that. The root package.json allows >= 18
  // because the bash CLI itself needs no Node.
  target: 'node22',
  jsx: 'automatic',
  // ink only `await import('./devtools.js')` under DEV=true (guarded by
  // import.meta.resolve), so react-devtools-core never loads in normal runtime.
  // Stub it to a no-op: keeps the bundle a single self-contained file (an
  // `external` would hoist to a top-level import and crash on startup) and
  // avoids pulling the whole React devtools backend into the bundle.
  plugins: [
    {
      name: 'stub-react-devtools',
      setup(b) {
        b.onResolve({ filter: /^react-devtools-core$/ }, () => ({
          path: 'react-devtools-core',
          namespace: 'stub-devtools',
        }));
        b.onLoad({ filter: /.*/, namespace: 'stub-devtools' }, () => ({
          contents: 'export default { connectToDevTools() {} };',
          loader: 'js',
        }));
      },
    },
  ],
  // Yoga (ink's layout engine) ships ESM with import.meta; keep it intact.
  banner: {
    js: [
      // Shebang comes from src/cli.tsx (esbuild preserves it on line 1).
      // Shim CJS globals some bundled deps expect under ESM.
      "import { createRequire as __nsCreateRequire } from 'node:module';",
      "import { fileURLToPath as __nsFileURLToPath } from 'node:url';",
      "import { dirname as __nsDirname } from 'node:path';",
      'const require = __nsCreateRequire(import.meta.url);',
      'const __filename = __nsFileURLToPath(import.meta.url);',
      'const __dirname = __nsDirname(__filename);',
    ].join('\n'),
  },
  logLevel: 'info',
});

chmodSync(outfile, 0o755);
console.log(`built ${outfile}`);
