// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

/**
 * Remark plugin that strips `.md` extensions from relative internal links at
 * build time. This lets authors write `[text](./page.md)` in source (so VS
 * Code Ctrl+Click navigation and GitHub's markdown preview both work) while
 * the published Starlight site receives clean URLs like `/page/`.
 *
 * Remote URLs (http://, https://, mailto:) and anchor-only links (#heading)
 * are intentionally left untouched.
 */

/** URLs that must not be rewritten (remote schemes or bare anchors). */
const REMOTE_OR_ANCHOR = /^(https?:|mailto:|\/\/|#)/;

/** @returns {import('unified').Plugin} */
export function remarkStripMdExtensions() {
  return (tree) => {
    stripLinks(tree);
  };
}

/**
 * Recursively walk the MDAST and strip `.md` from qualifying link `url`s.
 * We avoid an external `unist-util-visit` dep by doing a simple recursive walk.
 * @param {import('mdast').Node} node
 */
function stripLinks(node) {
  if (node.type === 'link') {
    const url = /** @type {import('mdast').Link} */ (node).url;
    // Skip remote URLs and anchor-only links
    if (url && !REMOTE_OR_ANCHOR.test(url)) {
      // Strip `.md` extension only when followed by a fragment (#), query (?),
      // or end-of-string. Using a lookahead keeps the rest of the URL intact.
      /** @type {import('mdast').Link} */ (node).url = url.replace(/\.md(?=[?#]|$)/, '');
    }
  }
  if ('children' in node && Array.isArray(node.children)) {
    for (const child of node.children) {
      stripLinks(child);
    }
  }
}
