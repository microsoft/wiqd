---
title: policy publish
description: Publish a separate Work IQ policy for an existing MOS title
---

# policy publish

```powershell
wiqd policy publish --title-id <title-id> --file ./policy.json --caller-id <runtime-app-id> --json
```

The core extension delegates publication to the native SDK. All three options
are required. The title is an existing MOS title, and Caller ID is the runtime
application ID used by Work IQ. Neither value is inferred from the publisher,
registration identity or the other identifier. Relative file paths resolve from
the invocation directory. No project, app manifest, package or YAML is required.

This command belongs to the root `policy` namespace, not `agent`. The previous
`wiqd agent policy publish` path is not an alias. JSON envelopes identify the
command as `policy-publish`.

## SDK Availability

The bundled SDK exposes public direct action execution, and normal calls delegate
to its policy action. Older SDKs without that API return `ACTION_API_UNAVAILABLE`
(exit `2`) without reading policy, acquiring tokens or publishing. Local SDK
integration does not establish live-service qualification. WIQD selects the
SDK-exported policy action rather than fixing its namespace. Input/schema
validation and file capture remain SDK-owned.

Use explicit `--mock` to simulate the whole command without loading the runtime,
reading the file or contacting services:

```powershell
wiqd policy publish --title-id <title-id> --file ./policy.json --caller-id <runtime-app-id> --mock --json
```

The result reports `published: false`, `simulationScope: "command"` and unavailable
schema validation. It is not a service receipt.

## Publication Outcomes

With a qualified SDK, sign in through `wiqd auth login` first. The action reuses
the existing core M365 identity and authentication behavior with
destination-specific token audiences. The SDK's direct-action authentication
interaction policy still needs upstream confirmation before live release.

Publication success follows the SDK's successful `published`/`unchanged`
result for the selected target. JSON preserves `target` (`mos`, `workiq` or
`both`) when the SDK supplies it. An unselected destination may be `not-started`;
this does not turn a successful selected target into failure. WIQD does not
override the SDK's target or default. Enforcement remains `not-verified`.
Human output names publication success or an already-current policy explicitly,
shows the reported target and service confirmation, and labels an explicitly
unselected destination as `Not requested`. Without a reported target,
`not-started` remains `Not started`, not an inferred skip. Operation ID and
service ETag/revision rows appear only when supplied by the SDK. JSON keeps the
native states unchanged. Whole-command mock is labelled as simulation with no
remote update, never as publication success.

Partial, unknown, conflict and native simulated
outcomes return nonzero with a stable error code and a safe message describing
both destination states and the SDK's next-action guidance. Structured failure
reports are not exposed in this increment. Native `simulated` may include a real
MOS write; never blindly retry an unknown write or assume rollback. Handler
cancellation retains exit `130` without a JSON envelope or public receipt.

## Project Lifecycles

`wiqd plugin provision` remains the separate project-based entry point with its
existing project/app-manifest requirements. The project owner maintains YAML
action order, environment-backed agent identity/registration metadata, the
verified title, explicit policy path and runtime Caller ID under the supported
SDK contract. Registration ID is not a MOS title. WIQD neither inserts actions
nor falls back between standalone and provision after a failure.

Provision integration and registration-to-title support require their own native
SDK qualification; this standalone preparation does not establish them. Removing
a local policy or action never deletes remote state. Policy publication adds no
package upload, identity creation, approval or enforcement guarantee.