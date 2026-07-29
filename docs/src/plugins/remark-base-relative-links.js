// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

/**
 * Remark plugin that prefixes the configured Astro `base` onto root-relative
 * links and images in markdown/MDX content at build time.
 *
 * Starlight base-prefixes its own navigation (sidebar, breadcrumbs) but does
 * NOT touch root-relative URLs an author writes inside content
 * (`[text](/getting-started/)`), nor image sources. When the site is served
 * under a non-root base (e.g. the public mirror at `/wiqd/`), those links would
 * resolve to the domain root and 404. Prefixing them here keeps a single
 * source of content links working under any deployment base.
 *
 * When `base` is `/` (the internal/default deployment) the transform is a
 * no-op, so the internal build output is byte-identical to before.
 *
 * Component props (`<LinkCard href="/...">`) and hero frontmatter (`link: /...`)
 * are NOT markdown nodes and are intentionally NOT handled here — those few
 * call sites (only the splash homepage) use base-root-relative URLs instead.
 *
 * Remote URLs (http://, https://, mailto:, //host) and anchor-only links
 * (#heading) are left untouched.
 */

/** URLs that must not be rewritten (remote schemes, protocol-relative, anchors). */
const REMOTE_OR_ANCHOR = /^(https?:|mailto:|tel:|\/\/|#)/;

/**
 * @param {{ base?: string }} [options]
 * @returns {import('unified').Plugin}
 */
export function remarkBaseRelativeLinks(options = {}) {
  // Normalize to exactly one trailing slash; an undefined/empty base means root.
  const base = `/${(options.base || '/').replace(/^\/+|\/+$/g, '')}/`.replace(/\/{2,}/g, '/');
  return (tree) => {
    if (base === '/') return;
    prefix(tree, base);
  };
}

/**
 * Recursively walk the MDAST and prefix `base` onto root-relative `url`s of
 * link, image, and definition nodes. We avoid an external `unist-util-visit`
 * dep by doing a simple recursive walk (matching remark-strip-md-extensions).
 * @param {import('mdast').Node} node
 * @param {string} base
 */
function prefix(node, base) {
  if (node.type === 'link' || node.type === 'image' || node.type === 'definition') {
    const url = /** @type {{ url?: string }} */ (node).url;
    if (url && url.startsWith('/') && !REMOTE_OR_ANCHOR.test(url)) {
      /** @type {{ url: string }} */ (node).url = base + url.slice(1);
    }
  }
  if ('children' in node && Array.isArray(node.children)) {
    for (const child of node.children) {
      prefix(child, base);
    }
  }
}
