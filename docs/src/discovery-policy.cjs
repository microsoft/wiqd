// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

const FRONTMATTER = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/;

function isHiddenDocument(markdown) {
  const frontmatter = markdown.match(FRONTMATTER)?.[1];
  return Boolean(frontmatter?.match(/^discovery:[ \t]*hidden[ \t]*\r?$/m));
}

function discoverableDocsLoader(loader) {
  return {
    ...loader,
    async load(context) {
      const store = new Proxy(context.store, {
        get(target, key) {
          if (key === 'set')
            return (entry) => {
              if (entry.data.discovery === 'hidden') {
                target.delete(entry.id);
                return false;
              }
              return target.set(entry);
            };
          const value = Reflect.get(target, key);
          return typeof value === 'function' ? value.bind(target) : value;
        },
      });
      await loader.load({ ...context, store });
      for (const [id, entry] of context.store.entries()) {
        if (entry.data.discovery === 'hidden') context.store.delete(id);
      }
    },
  };
}

module.exports = { isHiddenDocument, discoverableDocsLoader };
