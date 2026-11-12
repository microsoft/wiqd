---
title: wiqd Core · Agentic workflows
description: Workflows and references contributed by the wiqd Core extension
---

# wiqd Core · Agentic workflows

## Workflow files

| File | Purpose |
| --- | --- |
| `workflows/wiqd-core.md` | Native lifecycle: create, edit with source prechecks, provision, package, share, publish, delete, environments, migration, and localization. |
| `workflows/plugin.md` | Standalone reusable plugin authoring and lifecycle. |
| `workflows/partner-center.md` | 3P direct Partner Center preparation/submission with explicit consent, or portal fallback when unavailable. |

See [Publish to Partner Center](/getting-started/publish-partner-center/) for
publisher setup, exact-package validation, listing inputs and separate submission
authorization. Submission acceptance is not certification or Live publication.

## Reference files

The extension contributes reference material under `packages/wiqd-ext-core/references/`, including authoring, schema, provisioning, packaging, sharing, validation, localization, API plugin, MCP plugin, authentication, and workspace-gate guidance.

Explicit validation and identified-finding repair belong to the `validation` workflow
from `microsoft.validate`. Core lifecycle prechecks explicitly use `--mode source` with the same
project/environment; they do not build a ZIP merely to check source. Package validation uses
Core's typed TDP API; Marketplace includes TDP and StoreOps on one ZIP. There is no experiment
selector or ATK fallback, and these workflow gates do not force new backend validation.

## Editing the default response mode

Ask wiqd to set the agent's default response mode to `Auto`, `Quick response`, or
`Think deeper`. The workflow preserves unrelated manifest content and never
silently upgrades the manifest version.

Before editing, it fetches the manifest version's canonical Microsoft schema and
reads the complete resolved `default_response_mode` property. The lookup must
show both `type: string` and the allowed `enum`; finding the enum alone is not
enough. Missing or incompatible schema evidence stops the edit.

After the edit, the workflow source-checks the saved project with the provisioning path/environment.
An explicit request not to
deploy or provision suppresses provision, but does not skip validation.
