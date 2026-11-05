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
For a supported single MCP connector, WIQD creates a separately identified minimal DA host.
The original connector ZIP remains available as the validation subject.
Generated identities stay the same when you reuse this preparation directory.

The connector may be accompanied by `agentSkills`, `staticTabs`, `configurableTabs`
or `composeExtensions` arrays, but not packaged agents. The test host contains only
required app metadata/icons, one DA, its MCP action and any referenced tool-description
file. Bundled skills, tabs, message extensions, unrelated files and unrelated domains
are omitted from the **separate host**, never from your original ZIP.
Testing the connector does not test those excluded surfaces or establish complete
functional coverage.
Associated bot, app sign-in, permission and default-group metadata is also omitted;
it never replaces the MCP connector's own authentication or adds DA permission grants.

New connector preparations record `minimalTestHost: true`. Existing unmarked
preparations retain their original deployment bytes and identities on reuse;
WIQD does not silently trim or regenerate them. Do not abandon an uncertain
deployment by choosing another output directory.

Conversion preserves the MCP endpoint, supplied tool-description bytes and
supported auth references. Static tool names come from the supplied description;
without one, the action uses dynamic discovery. It adds no alternative grounding.
Explicit `None`, `OAuthPluginVault` and `ApiKeyPluginVault` auth can be represented,
but real service access and any existing consent are still required.
DCR/ConnectionVault mappings, multiple/mixed connectors, OpenAPI and Graph
connectors are not converted by ZIP sideload. An omitted-auth OAuth-DCR connector
can use the separate source-host path below. WIQD never replaces declared authentication.

For an authenticated connector such as Pinegap, preserve its concrete
`OAuthPluginVault` reference without supplying `--connector-auth-type None`.
No new OAuth registration or client secret is needed for the local conversion.
The existing registration must nevertheless allow the new wrapper app and your
account/tenant; this ZIP command does not inspect or recreate it. A vault
reference alone does not identify static OAuth versus DCR.

If a supported connector omits `authorization` entirely (for example emem),
first confirm that it supports **anonymous access**, explicitly select the DCR
source path below when required, or supply a suitable existing development target.
Omitted auth has no assumed schema default. After
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
provisioning eligibility. Supported additional-surface packages can use the native
minimal-host preparation above; their live tests require that explicit connector-only
scenario. Unknown manifest settings, malformed surface arrays and packaged agents
are not automatically converted.

Malformed or unsafe ZIP entries and missing references fail before upload.
The compressed limit is 10 MiB, with bounded entry count and uncompressed data.
Inspect and validate the prepared deployment package before installing it.
Service-backed validation has its own authentication/upload requirements.

## Prepare an OAuth-DCR connector source host

For an omitted-auth connector known to require dynamic client registration,
such as Success.co, use the existing create command with explicit DCR selection:

```powershell
wiqd agent create --name keep-success-co-validation `
  --output .\.validation --connector-package .\success-co.zip `
  --mcp-auth-type oauth-dynamic --json
```

This is offline preparation, not registration or installation. It creates a new
minimal source project, preserving the original ZIP as `source.zip` and its
SHA-256/provenance in `connector-host.json` and JSON `data.connectorPackage`.
Only the selected MCP endpoint, supplied tool-description bytes, required icons
and minimal DA/action are carried forward. The generated app and OAuth reference
use fresh environment placeholders. The app manifest references
`appPackage/declarativeAgent.json`, the normal source-precheck entry point.
Packaged lifecycle files are never executed
or copied. Declared authorization, endpoint/credential overrides and existing
output directories are rejected; omitted auth is not evidence that DCR is supported.

New DCR source hosts use runtime tool discovery: their action has `functions: []`,
`run_for_functions: ["*"]`, and no runtime `mcp_tool_description`. The supplied
tool snapshot remains byte-identical in the source project, but is not a runtime
pin. Returned and retained provenance records `toolDiscovery: dynamic`. This
exercises the live server tool surface, not proof that it matches the submitted
snapshot. Existing hosts and finalized-ZIP conversion remain unchanged; changing
an existing deployment requires explicit authorization, not automatic regeneration.
Discovery does not relax the approved read-only collection scope or prove that
a previous service error is fixed.

Inspect the generated lifecycle and provenance before continuing. Separately
approve **app creation, OAuth DCR registration, validation-service uploads and
personal installation** in the verified M365 account/tenant. Then run the normal
source preflight and provision once:

```powershell
wiqd agent validate --mode source --path .\.validation\keep-success-co-validation `
  --env local --json
wiqd agent provision --path .\.validation\keep-success-co-validation --env local --json
```

Provisioning runs `dcr/register` for the unchanged MCP resource URL and personal-only
publication; it is not Marketplace or tenant publication. Follow the normal EULA
and sign-in gates. Verify the source is unchanged before provision. On success,
bind the returned `m365TitleId` to the actual built manifest's declared DA ID
(`validationAgent` for this generator), and verify its resolved OAuth reference
matches `MCP_DA_AUTH_ID_VALIDATION`. Keep that target mapping and original ZIP/hash.
Complete publisher sign-in and connector Allow yourself in Microsoft 365 Copilot
before live validation. Never use `--connector-auth-type None` to bypass OAuth.

Partial source provision may leave an app or OAuth registration behind.
Retain the project and outputs; do not automatically rerun provisioning, generate
a replacement project or apply ZIP `--reconcile` recovery to it. This source path
does not create ZIP preparation/attempt receipts. Validate the original connector
ZIP with connector-to-agent evidence binding, not the generated host as a replacement
audit subject; unrelated package functionality remains untested.

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

For live connector validation, open the returned `deepLink` in **Microsoft 365
Copilot**, review connector access and complete any provider sign-in/consent
yourself using the same M365 account/tenant as the collector. In the WIQD
validation skill, confirm readiness before evidence collection starts.
Browser sign-in does not replace missing application-level OAuth configuration
or a static API key. An unavailable/incompatible registration is an external
setup prerequisite, not permission to downgrade auth or reinstall.
For setup, ask Copilot to use only the intended connector for the approved
read-only public scenario, reporting unavailable access instead of using other
tools or answering from memory. This setup prompt is not collected validation
evidence; confirm readiness in the validation skill before its single capture.

## Failure and cancellation

There is one upload attempt and a 300-second deadline. Cancellation propagates
to requests and polling. Auth errors, tenant denial and uncertain responses
never trigger automatic re-upload, consent grants, publication or rollback.

Keep `attempt.json`, any returned status ID and all preparation artifacts when
an operation fails. A later invocation refuses to upload again if that attempt
has no durable success record. If **`status.json` was retained**, explicitly check
the existing attempt without uploading again:

```powershell
wiqd agent provision package --package-file .\agent.zip `
  --output .\.validation\package-1 --reconcile `
  --preparation-sha256 "<returned-preparationSha256>" `
  --expected-tenant "<original-tenant-id>" `
  --expected-account "<original-account>" --json
```

Use the original ZIP, unchanged preparation directory and original identity.
Preserve any original omitted-auth selection; never add `None` for an
authenticated connector. `--reconcile` cannot be combined with `--dry-run`.
It verifies retained package/identity bindings, then makes only environment/status
GET requests. It never uploads, installs again or changes accounts. Pending
status can be polled within its 300-second deadline. Verified success writes
`deployment.json` and returns the normal `agentId` and `deepLink`, with
`reused: true`; human-readable successful output also displays the Copilot link.
Continue through the manual Allow/provider-authentication handoff above, not
straight to evidence collection.

In the **validation skill**, installation approval includes up to **three
additional read-only reconciliation invocations**, waiting **10, 20 and 30 seconds
before the first, second and third respectively**, if status retrieval encounters
a transport/read or invalid-JSON/object/missing-body failure after the status
ID was saved. Copilot runs these in the same session without asking you to check
again. It stops at the first verified success and continues the original
validation, retaining the manual connector Allow/authentication handoff.
Recovery of an earlier attempt without that approval requires one approval for
the bounded series. Running the CLI directly does not start this skill loop.

Recovery requires `PACKAGE_SIDELOAD_UNAVAILABLE` or
`PACKAGE_SIDELOAD_INVALID_RESPONSE` with a sanitized **status**-phase diagnostic
and valid retained attempt/status records. A malformed response during
environment discovery or upload does not qualify. A malformed status body is
not treated as pending or successful; only a later verified response can complete
the existing attempt.

Authentication/HTTP denial, oversized responses, failed validation,
changed or missing state, persistence failure, cancellation and deadline stop
immediately. If all three recovery invocations fail, the skill reports the count,
last diagnostic and retained directory, then stops; an unresolved installation
remains **unknown**, not necessarily failed.

Missing/invalid retained status records, mismatched artifacts/identity and failed
validation remain blockers. Each CLI invocation still stops on a service error;
only the skill orchestrates eligible recovery. Sanitized errors identify environment, upload
or status phase and distinguish HTTP denial, transport/read failure, invalid
JSON and the 64-KiB response limit without printing service bodies or credentials.
An interrupted response does not prove installation failed. If no status ID was
retained, automated reconciliation is unavailable; report the uncertain outcome
for manual investigation. A new directory is not a safe retry workaround, and
no remote cleanup is automatic.

Exit codes are `0` for success, `1` for input/service failures, `2` for unavailable
identity/infrastructure and `130` for cancellation or deadline. `--mock` does
not fabricate a deployment receipt; use `--dry-run` for real local preparation.
