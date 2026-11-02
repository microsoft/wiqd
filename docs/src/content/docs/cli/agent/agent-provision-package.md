---
title: Provision a package for development
description: Personally sideload a final DA ZIP, or prepare an MCP connector as a DA execution host.
---

`wiqd agent provision package` works directly with a final ZIP. It does not
require a source project or store publication. Installation is **personal** in
your currently signed-in Microsoft 365 tenant; it never shares the agent or
changes tenant permissions.

## Prepare without installing

```powershell
wiqd agent provision package --package-file .\agent.zip `
  --output .\.validation\package-1 --dry-run --json
```

Choose a new private output directory. This step makes no authentication or
network calls and leaves the input untouched. It retains `source.zip`, the
actual `deployment.zip`, and `preparation.json` containing their hashes and
declared identities. JSON returns these paths and `preparationSha256`.
`phase: prepared` does **not** mean the target is installed or available.

For a single-DA package, deployment bytes and app identity are unchanged;
sideloading may update an existing personal installation of that app.
For a standalone MCP connector, WIQD creates a separately identified DA host.
The original connector ZIP remains available as the validation subject.
Generated identities stay the same when you reuse this preparation directory.

Conversion preserves the MCP endpoint, supplied tool-description bytes and
supported auth references. Static tool names come from the supplied description;
without one, the action uses dynamic discovery. It adds no alternative grounding.
Explicit `None`, `OAuthPluginVault` and `ApiKeyPluginVault` auth can be represented,
but real service access and any existing consent are still required.
DCR/ConnectionVault mappings, multiple/mixed connectors, OpenAPI and Graph
connectors are not converted. WIQD never replaces declared authentication.

If a standalone connector omits `authorization` entirely (for example emem),
first confirm that it supports **anonymous access**, or supply a suitable existing
development target instead. Omitted auth has no assumed schema default. After
that confirmation, explicitly select anonymous auth for the generated wrapper:

```powershell
wiqd agent provision package --package-file .\emem.zip `
  --output .\.validation\emem-1 --connector-auth-type None --dry-run --json
```

`None` is the only supported value. It applies only when `authorization` is
absent, not null/incomplete or already declared (even explicit `None`).
The original ZIP is unchanged; only the separate wrapper gains explicit runtime
`None`. `preparation.json` and JSON results record `connectorAuthType: "None"`
as caller-selected provenance, and `preparationSha256` binds it. Retain the same
`--connector-auth-type None` on installation and later reuse; adding or dropping
it rejects reuse before authentication or upload.

This selection does not authorize an upload, live scenario, consent or tool call.
The validation workflow's separately approved `--connector-scenario public-example`
selects one fixed read-only public-example request, not anonymous auth or automatic
provisioning eligibility. Extra app execution surfaces such as skills, tabs and
compose extensions require a suitable existing target, not automatic conversion.

Malformed or unsafe ZIP entries and missing references fail before upload.
The compressed limit is 10 MiB, with bounded entry count and uncompressed data.
Inspect and validate the prepared deployment package before installing it.
Service-backed validation has its own authentication/upload requirements.

## Install the inspected package

Check `wiqd auth status --json` and explicitly sign in if needed. After confirming
the intended Microsoft 365 account, tenant and personal installation, use the
same input and output directory:

```powershell
wiqd agent provision package --package-file .\agent.zip `
  --output .\.validation\package-1 `
  --preparation-sha256 "<returned-preparationSha256>" `
  --expected-tenant "<confirmed-tenant-id>" `
  --expected-account "<confirmed-account>" --json
```

The assertions reject changed preparation or identity **before sideload-service requests**;
they do not switch accounts. Source-project `--path` and `--env`
options are not accepted by this child command. Use ordinary
`wiqd agent provision` for a configured source-project environment.
For the omitted-auth example above, also retain `--connector-auth-type None` and
use its exact emem input/output paths and returned preparation hash.

On success, `phase` is `provisioned`. Copy the returned **`agentId`** for the
requested functional validation. It uses the service-returned title and the
package's declared DA ID; an app GUID, title-only value or guessed suffix is
not a substitute. `deployment.json` retains the result. For connector validation,
use the original connector ZIP and its `connector-package-to-agent` mapping,
not the generated wrapper as a replacement validation subject.

Provision success is a caller-asserted package/target mapping, not proof of
runtime availability, deployed service bytes or passing policy checks.
Reusing a successful preparation with the same identity and unchanged artifacts
returns its saved target without another upload; it does not probe readiness.

## Failure and cancellation

There is one upload attempt and a 300-second deadline. Cancellation propagates
to requests and polling. Auth errors, tenant denial and uncertain responses
never trigger automatic re-upload, consent grants, publication or rollback.

Keep `attempt.json`, any returned status ID and all preparation artifacts when
an operation fails. A later invocation refuses to upload again if that attempt
has no durable success record. Reconcile the existing operation before making
another installation; a new directory is not a safe retry workaround.
No remote cleanup is automatic.

Exit codes are `0` for success, `1` for input/service failures, `2` for unavailable
identity/infrastructure and `130` for cancellation or deadline. `--mock` does
not fabricate a deployment receipt; use `--dry-run` for real local preparation.
