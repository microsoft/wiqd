// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// Directory-partition docs gate: everything under `src/content/docs/internal/`
// is internal-only (1P) and MUST NOT appear in the public Starlight build.
//
// Why a filesystem swap (and not a Vite/Astro plugin)?
//   1. Astro/Starlight build the route tree, sitemap, and search index
//      directly from the `src/content/docs/` filesystem walk. The only
//      contract that produces byte-different public output is: the internal
//      pages MUST NOT EXIST when `astro build` runs.
//   2. Moving the whole `internal/` tree OUT of the content collection root
//      (rather than renaming individual files) is one atomic operation, and
//      it covers pages added under `internal/` later without re-listing them.
//   3. The wrapper (build.mjs) runs the swap inside try/finally, and for the
//      public build withGateFiltering also installs SIGINT/SIGTERM handlers —
//      a try/finally alone does NOT unwind on signal-driven termination, so a
//      bare Ctrl+C would otherwise leave the partition stashed (showing up as a
//      deleted internal/ tree until the next build's recoverStaleStash heals it).
//
// Convention replaces the previous `featureFlag:` frontmatter gate: a page is
// internal IFF it lives under the `internal/` partition. No per-page flag.

import { rename, stat, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const INTERNAL_DIR_NAME = 'internal';
// Stash lives at the docs package root (outside src/content) so the `docs`
// content collection can never walk it during a public build.
const STASH_DIR_NAME = '.internal-gated-off';

async function pathExists(p) {
  try {
    await stat(p);
    return true;
  } catch {
    return false;
  }
}

/**
 * Resolve the internal partition dir and its stash location for a given
 * content root (`<docs>/src/content/docs`). The stash sits at `<docs>/`.
 */
export function resolvePartitionPaths(contentRoot) {
  const internalDir = join(contentRoot, INTERNAL_DIR_NAME);
  // contentRoot = <docs>/src/content/docs → docsRoot = <docs>
  const docsRoot = dirname(dirname(dirname(contentRoot)));
  const stashDir = join(docsRoot, STASH_DIR_NAME);
  return { internalDir, stashDir };
}

/**
 * Move the internal partition out of the content root so `astro build`
 * never sees it. Returns the stash descriptor (or null when there is no
 * internal partition to hide).
 *
 * Fails loudly when both the live partition and a leftover stash exist —
 * that is an ambiguous half-restored state a previous crashed run left
 * behind, and silently picking one risks losing edits.
 */
export async function hideInternalPartition(contentRoot) {
  const { internalDir, stashDir } = resolvePartitionPaths(contentRoot);
  const hasInternal = await pathExists(internalDir);
  const hasStash = await pathExists(stashDir);

  if (hasInternal && hasStash) {
    throw new Error(
      `Both the internal partition (${internalDir}) and a leftover stash ` +
        `(${stashDir}) exist. A previous build likely crashed mid-restore. ` +
        `Inspect both and remove the stale one before rebuilding.`,
    );
  }

  if (!hasInternal && hasStash) {
    // A previous public build crashed after hide, before restore. The content
    // is safe in the stash and already absent from the build tree, which is
    // exactly the public-build precondition — reuse it.
    return { internalDir, stashDir };
  }

  if (!hasInternal) return null;

  await rename(internalDir, stashDir);
  return { internalDir, stashDir };
}

/**
 * Reverse of hideInternalPartition. Safe to call with a null descriptor or
 * when the stash is already gone (idempotent restore).
 */
export async function restoreInternalPartition(stash) {
  if (!stash) return;
  const { internalDir, stashDir } = stash;
  if (!(await pathExists(stashDir))) return;
  if (await pathExists(internalDir)) {
    // Restoring would clobber a freshly-recreated partition — refuse.
    throw new Error(
      `Cannot restore internal partition: ${internalDir} already exists ` +
        `while stash ${stashDir} is also present.`,
    );
  }
  await rename(stashDir, internalDir);
}

/**
 * Self-heal a stale stash left by a crashed public build, before a build
 * starts. If only the stash exists, move it back so the working tree is whole.
 */
export async function recoverStaleStash(contentRoot) {
  const { internalDir, stashDir } = resolvePartitionPaths(contentRoot);
  const hasInternal = await pathExists(internalDir);
  const hasStash = await pathExists(stashDir);
  if (hasStash && !hasInternal) {
    await rename(stashDir, internalDir);
    return true;
  }
  return false;
}

/**
 * Count the pages under the internal partition (for logging). Returns 0 when
 * the partition is absent.
 */
export async function countInternalPages(contentRoot) {
  const { internalDir } = resolvePartitionPaths(contentRoot);
  if (!(await pathExists(internalDir))) return 0;
  let count = 0;
  async function walk(dir) {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) await walk(full);
      else if (entry.name.endsWith('.md') || entry.name.endsWith('.mdx')) count++;
    }
  }
  await walk(internalDir);
  return count;
}

/**
 * High-level wrapper: hide (public) / keep (internal), run task, restore in
 * finally. `isInternal=true` includes the internal partition verbatim.
 */
export async function withGateFiltering(contentRoot, isInternal, task) {
  await recoverStaleStash(contentRoot);
  if (isInternal) {
    return await task({ internalPages: await countInternalPages(contentRoot) });
  }
  const internalPages = await countInternalPages(contentRoot);
  const stash = await hideInternalPartition(contentRoot);

  // try/finally does not unwind on signal-driven termination, so without these
  // handlers a Ctrl+C during the build would leave internal/ stashed (and thus
  // appear deleted in git status). Restore best-effort, then re-raise the signal
  // with the conventional 128+signo exit code.
  let restored = false;
  const restoreOnce = async () => {
    if (restored) return;
    restored = true;
    await restoreInternalPartition(stash);
  };
  const signals = ['SIGINT', 'SIGTERM'];
  const handlers = {};
  for (const sig of signals) {
    handlers[sig] = () => {
      restoreOnce()
        .catch(() => {})
        .finally(() => {
          const signo = sig === 'SIGINT' ? 2 : 15;
          process.exit(128 + signo);
        });
    };
    process.once(sig, handlers[sig]);
  }

  try {
    return await task({ internalPages });
  } finally {
    for (const sig of signals) process.removeListener(sig, handlers[sig]);
    await restoreOnce();
  }
}

export const _internals = {
  INTERNAL_DIR_NAME,
  STASH_DIR_NAME,
  pathExists,
};
