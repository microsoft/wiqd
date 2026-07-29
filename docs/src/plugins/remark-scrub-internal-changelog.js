// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// Changelog scrubbing is a no-op in the mirror: the public changelog shipped
// here is already cleaned upstream by the release pipeline. This stub preserves
// the export astro.config imports so the config wiring stays byte-identical to
// its source, without carrying any 1P-marker scrubbing logic.
/** @returns {import('unified').Plugin} */
export function remarkScrubInternalChangelog() {
  return () => {};
}
