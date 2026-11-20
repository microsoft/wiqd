---
title: wiqd plugin publish
description: Submit a source project or existing final ZIP to the tenant organization app catalog.
---

# `wiqd plugin publish`

Submit a plugin to the tenant organization app catalog for **administrator approval**.
This does not grant immediate tenant access, share the plugin, personally sideload
it, or publish to Partner Center/the public store.

## Publish a project

```powershell
wiqd plugin publish --path .\my-plugin --env dev --json
```

The project must have `m365agents.yml`, a contained app manifest, and a provisioned
environment with a valid `TEAMS_APP_ID`. The selected YAML `publish:` lifecycle
runs unchanged and may rebuild the package. Omitting `--env` selects `local`.
An optional contained `--manifest <path>` must match the YAML packaging input.

Project readiness without submission remains available:

```powershell
wiqd plugin publish --path .\my-plugin --env dev --dry-run --no-runtime --no-network --json
```

The existing `--browser`, `--prompts`, and `--artifacts` options apply to project
dry-run. Declarative-agent phases explicitly skip skill/connector-only plugins.

## Publish an existing final ZIP

```powershell
wiqd plugin publish --package-file .\release\plugin.zip --json
```

No source project, lifecycle YAML, provisioning or environment is needed.
WIQD captures the selected ZIP and submits those bytes unchanged through the SDK:
it does not rebuild, modify, extract a source project, or silently fall back.
Do not combine `--package-file` with `--path`, `--manifest`, or an explicit
`--env` (including `local`).

The ZIP must be a regular file, not a symlink, no larger than 10 MiB, with root
`manifest.json` of at most 1 MiB containing a literal GUID `id`. The bounded reader rejects unsafe,
duplicate, encrypted or corrupt entries and limits expanded content to 50 MiB /
512 entries. SDK validation and tenant publishing permissions still apply.
The current working directory must be writable: WIQD holds a private snapshot
there until the SDK settles, then removes it.

Both modes use your Microsoft 365 identity (`wiqd auth login`). When an existing
catalog app requires replacement confirmation, ZIP publication returns
`PUBLISH_CONFIRMATION_REQUIRED`, without auto-consenting. Review/update the package
in the tenant admin portal instead.
ZIP catalog submission is unsupported in GCCH and DoD and fails explicitly.

ZIP `--dry-run` and `--mock` are unsupported and fail explicitly without submission.
For separately authorized package validation:

```powershell
wiqd plugin validate --mode package --package-file .\release\plugin.zip --json
```

Validation may upload to the validation service and is **not publication consent**.
For personal development sideloading, use `wiqd plugin provision package`, not
catalog publication.

## Results and failures

Project success retains `target`, `env`, `projectPath`, and `nextSteps`.
ZIP success instead returns `target: "org-catalog"`, canonical `packageFile`,
captured `packageSha256`, manifest `appId`, and environment-neutral `nextSteps`.
It never fabricates a project/environment or returns the staging path.
Human and JSON output both state submission, not administrator approval.

Invalid/conflicting input, validation, authentication and permission errors stop
publication with a nonzero exit. Signed-out state exits `2`; backend rejection
exits `1`. Cancellation or the 300-second deadline exits `130` without a success
envelope. In-flight remote effects can be uncertain: inspect the catalog before
any manually approved retry. Cancellation does not promise rollback.

See [plugin package](/cli/plugin-package/) for producing release ZIPs.
