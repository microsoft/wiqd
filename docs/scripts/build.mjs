// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// Wrapper around `astro build` that respects the wiqd docs internal/3P
// partition. Reads WIQD_DOCS_INTERNAL (or accepts an --internal CLI flag).
//
// - Public mode (default): physically moves the `internal/` partition OUT of
//   the content collection so the public build (`dist/`) contains zero 1P
//   pages, then restores it in a finally block.
// - Internal mode (`WIQD_DOCS_INTERNAL=1` or `--internal`): the `internal/`
//   partition is included verbatim. Output goes to `dist-internal/` so the
//   two artifacts can coexist on the same CI runner without overwriting.
// - `--out-dir <dir>` / `--base <path>` let a caller build a THIRD, distinct
//   artifact (still public-partitioned) under a non-default deployment base
//   (e.g. the `/wiqd/` project-page base the public mirror actually ships
//   under) without colliding with the default `dist/` public build. This is
//   a wiqd-specific override flag, deliberately named differently from
//   Astro's own `--outDir` so the two never collide when forwarded through
//   `args.extra`.
//
// The wrapper exits with the same exit code as `astro build`. In public mode,
// withGateFiltering installs SIGINT/SIGTERM handlers so the partition is
// restored on a build error AND on Ctrl+C; a crashed run self-heals on the
// next build via recoverStaleStash.

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import process from 'node:process';
import {
  assertPublicOutputIsIsolated,
  clearAstroBuildCaches,
  withGateFiltering,
} from './internal-partition-gate.mjs';
import { generateDocsSearchIndex } from './generate-search-index.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DOCS_ROOT = resolve(__dirname, '..');
const CONTENT_ROOT = join(DOCS_ROOT, 'src', 'content', 'docs');

function parseArgs(argv) {
  const args = { internal: false, outDir: null, base: null, extra: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--internal') args.internal = true;
    else if (a === '--out-dir') args.outDir = argv[++i];
    else if (a === '--base') args.base = argv[++i];
    else args.extra.push(a);
  }
  return args;
}

function isInternalMode(args) {
  return args.internal || process.env.WIQD_DOCS_INTERNAL === '1';
}

function runAstroBuild(outDir, extraArgs) {
  return new Promise((resolvePromise, rejectPromise) => {
    const args = ['build', '--outDir', outDir, ...extraArgs];
    // `npx astro build` doesn't work on Windows when astro isn't on PATH;
    // shelling out via npm exec ensures the local astro binary is found.
    const child = spawn('npx', ['--no-install', 'astro', ...args], {
      cwd: DOCS_ROOT,
      stdio: 'inherit',
      shell: process.platform === 'win32',
      env: process.env,
    });
    child.on('error', rejectPromise);
    child.on('exit', (code, signal) => {
      if (signal) {
        rejectPromise(new Error(`astro build terminated by signal ${signal}`));
        return;
      }
      resolvePromise(code ?? 0);
    });
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const internal = isInternalMode(args);
  const outDir = args.outDir ?? (internal ? 'dist-internal' : 'dist');

  // Make the mode authoritative for the spawned astro process (and its remark
  // plugins) even when selected via the --internal flag rather than the env var.
  if (internal) process.env.WIQD_DOCS_INTERNAL = '1';
  // `docs/src/site-config.mjs` reads WIQD_DOCS_BASE directly, so setting it
  // here (rather than threading a --base flag through to astro itself) is
  // the one true way to retarget the deployment base for this build.
  if (args.base) process.env.WIQD_DOCS_BASE = args.base;

  // A later public build must not retain hidden internal collection data from
  // either of Astro's generated-state locations.
  await clearAstroBuildCaches(DOCS_ROOT);

  console.log(
    `[docs-build] mode=${internal ? 'internal' : 'public'} outDir=${outDir} base=${process.env.WIQD_DOCS_BASE || '/'}`,
  );

  const exitCode = await withGateFiltering(CONTENT_ROOT, internal, async ({ internalPages }) => {
    if (internalPages > 0) {
      const verb = internal ? 'included' : 'hidden';
      console.log(`[docs-build] ${verb} ${internalPages} page(s) under internal/ partition`);
    }

    // Regenerate inside every build so an internal build can never leave its
    // full search index behind for a later public artifact to copy.
    const indexExitCode = await generateDocsSearchIndex(internal);
    if (indexExitCode !== 0) return indexExitCode;

    const buildExitCode = await runAstroBuild(outDir, args.extra);
    if (buildExitCode !== 0) return buildExitCode;

    if (!internal) await assertPublicOutputIsIsolated(DOCS_ROOT, outDir);

    return 0;
  });

  process.exit(exitCode);
}

main().catch((err) => {
  console.error('[docs-build] failed:', err);
  process.exit(1);
});
