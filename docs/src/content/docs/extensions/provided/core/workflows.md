---
title: wiqd Core · Agentic workflows
description: Workflows and references contributed by the wiqd Core extension
---

# wiqd Core · Agentic workflows

## Workflow files

| File | Purpose |
| --- | --- |
| `workflows/wiqd-core.md` | Full native lifecycle: create, edit, validate, provision, package, share, publish, delete, environments, migration, and localization. |
| `workflows/plugin.md` | Standalone reusable plugin authoring and lifecycle. |
| `workflows/partner-center.md` | 3P Partner Center publishing guidance. |

## Reference files

The extension contributes reference material under `packages/wiqd-ext-core/references/`, including authoring, schema, provisioning, packaging, sharing, validation, localization, API plugin, MCP plugin, authentication, and workspace-gate guidance.

Deep validation is delegated statically to `microsoft.wiqd.core`; there is no backend selector or ATK rollback path.

## Editing the default response mode

Ask wiqd to set the agent's default response mode to `Auto`, `Quick response`, or
`Think deeper`. The workflow preserves unrelated manifest content and never
silently upgrades the manifest version.

Before editing, it fetches the manifest version's canonical Microsoft schema and
reads the complete resolved `default_response_mode` property. The lookup must
show both `type: string` and the allowed `enum`; finding the enum alone is not
enough. Missing or incompatible schema evidence stops the edit.

After the edit, the workflow validates the project. An explicit request not to
deploy or provision suppresses provision, but does not skip validation.
