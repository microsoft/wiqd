// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DOCS_ROOT = resolve(__dirname, '..');
const MIRROR_INDEX_GENERATOR = join(__dirname, 'generate-docs-index.cjs');
const SOURCE_INDEX_GENERATOR = resolve(DOCS_ROOT, '..', 'scripts', 'generate-docs-index.js');
const DEFAULT_OUTPUT_PATH = join(DOCS_ROOT, 'public', 'docs-index.json');

export function createSearchIndexArgs(
  internal,
  outputPath = DEFAULT_OUTPUT_PATH,
  mirrorIndexGenerator = MIRROR_INDEX_GENERATOR,
  sourceIndexGenerator = SOURCE_INDEX_GENERATOR,
) {
  const indexGenerator = existsSync(mirrorIndexGenerator)
    ? mirrorIndexGenerator
    : sourceIndexGenerator;
  const args = [indexGenerator];
  if (!internal) args.push('--exclude-sections', 'internal');
  args.push('--output', outputPath);
  return args;
}

export function generateDocsSearchIndex(
  internal,
  outputPath = DEFAULT_OUTPUT_PATH,
  stdio = 'inherit',
) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(process.execPath, createSearchIndexArgs(internal, outputPath), {
      cwd: DOCS_ROOT,
      stdio,
    });
    child.on('error', rejectPromise);
    child.on('exit', (code, signal) => {
      if (signal) {
        rejectPromise(new Error(`docs index generation terminated by signal ${signal}`));
        return;
      }
      resolvePromise(code ?? 0);
    });
  });
}
