// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    // 1P/3P docs separation is directory-based: pages under the `internal/`
    // partition are internal-only and excluded from the public build by
    // scripts/build.mjs (which moves the partition out of the collection
    // before `astro build`). There is no per-page frontmatter flag.
    schema: docsSchema(),
  }),
};
