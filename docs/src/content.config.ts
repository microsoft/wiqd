// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { z } from 'astro/zod';
import { createRequire } from 'node:module';

const { discoverableDocsLoader } = createRequire(import.meta.url)('./discovery-policy.cjs');

export const collections = {
  docs: defineCollection({
    loader: discoverableDocsLoader(docsLoader()),
    // 1P/3P docs separation is directory-based: pages under the `internal/`
    // partition are internal-only and excluded from the public build by
    // scripts/build.mjs (which moves the partition out of the collection
    // before `astro build`). The discovery marker only controls navigation
    // and indexing; it does not define the internal/public boundary.
    schema: docsSchema({ extend: z.object({ discovery: z.literal('hidden').optional() }) }),
  }),
};
