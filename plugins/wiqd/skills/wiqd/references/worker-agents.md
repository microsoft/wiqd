# Worker-agent authoring

Use this reference when the user asks to add, connect, remove, or disconnect a Worker Agent from an
existing declarative-agent project. Worker authoring is a manifest edit owned by this skill. Do not
look for or invoke dedicated `wiqd agent add worker` or `wiqd agent remove worker` commands.

## Preconditions

1. Follow the Edit workflow workspace, malformed-file, read-before-write, and scope-confirmation
   gates before changing anything.
2. Resolve the project directory selected by that gate and read its complete current
   `appPackage/declarativeAgent.json`.
3. Read the active backend's schema reference: `references/atk/schema.md` for `atk`, or
   `references/wiqd-core/schema.md` for `wiqd-core`. Follow its dynamic lookup procedure against the
   manifest's declared `$schema`; when `$schema` is absent, use the manifest's `version` as that
   procedure specifies. When both fields are present, extract the version from `$schema` and require
   it to exactly match `version`. If they conflict, stop before confirmation or mutation even when
   `wiqd agent validate` reports success. Verify that the resolved version supports `worker_agents`.
   If the schema or property cannot be confirmed, stop and tell the author. Do not silently upgrade
   or replace the schema.
4. If `worker_agents` exists but is not an array, stop and report the invalid shape without changing
   the manifest.
5. Preserve every unrelated property, value, and array entry.
6. Before resolving or confirming a Worker change, run:

   ```bash
   wiqd agent validate --path "<project-directory>" --json --skill wiqd --workflow <active-workflow-id>
   ```

   The Edit workflow's malformed-file gate forbids edits; it does not skip this Worker
   pre-validation command. Even when reading the manifest already reveals malformed JSON, run the
   command, then report the parse error and stop without changing any bytes.

   If validation fails, report the diagnostics and stop with the manifest bytes unchanged. Do not
   combine fixes for existing validation errors with the Worker edit.

## Resolve a published Worker

When `wiqd agent resolve worker-agent` is available, pass the id of the currently routed lifecycle
workflow (`atk` or `wiqd-core`) as `<active-workflow-id>`:

```bash
wiqd agent resolve worker-agent --name "<user-supplied-name>" --json --skill wiqd --workflow <active-workflow-id>
```

The resolver fails closed when no agent matches, multiple agents match, or Work IQ cannot return the
canonical Worker manifest ID. Do not reproduce its filtering or ID parsing in the skill. Treat
`data.workerAgentId` as opaque.

Resolution proves only that the current user can see the agent. It does not prove that the deployed
orchestrator or its audience can invoke the Worker.

Do not use exit code alone to decide that the resolver is available. An unknown nested command may
print parent help and exit successfully. Accept the resolver path only when `--json` returns a
success envelope for `agent-resolve-worker-agent` with a non-empty string `data.fullAgentId` and
`data.workerAgentId`. Treat help, non-JSON output, or a missing field as resolver unavailable.
A structured error envelope for `agent-resolve-worker-agent` means resolution failed, not that the
resolver is unavailable. Report its no-match, ambiguity, authentication, or upstream error and stop
name-based resolution. Only after explaining that failure may you explicitly ask for the canonical
Worker manifest ID.

### Before the resolver is available

Ask the author for the canonical Worker manifest ID and label it as author supplied. Do not derive
an ID from a friendly name, truncate a full composite agent ID, or use `wiqd agent list` as an
implicit resolver. If the author provides only a name or a composite ID, explain that friendly-name
resolution is not available yet and request the canonical `worker_agents[].id` value.

Apply the same confirmation gate before editing. For removal, the author may instead select an exact
`id` already present in the manifest. Never infer which existing ID corresponds to a friendly name.

## Detect no-op requests

After pre-validation succeeds and the canonical Worker ID is known, compare it exactly against the
current `worker_agents[].id` values before requesting confirmation. For add, if the exact ID already
exists, report it as already configured and stop. For remove, if the exact ID is absent, report it as
already absent and stop. Include the manifest path, Worker ID source, validation result, and
`bytes changed: no` in either report. Confirmation is required only when the proposed operation will
change the manifest.

## Confirm the exact change

Before editing, show all of the following and wait for the author's explicit response. Do not edit
the manifest in the same turn as this confirmation request:

```text
Action: <add|remove>
Manifest: <project-directory>/appPackage/declarativeAgent.json
Worker ID source: <resolver|author supplied>
Full agent ID: <data.fullAgentId> (resolver path only)
Worker manifest ID: <canonical-worker-id>
Proposed change: <add { "id": "<canonical-worker-id>" }|remove the exact matching id entry>
```

This confirmation authorizes only the local manifest edit. It does not authorize provisioning.

## Add

After confirmation, add exactly this shape to `worker_agents`:

```json
{ "id": "<confirmed-worker-id>" }
```

- If `worker_agents` is absent, add it as an array without changing unrelated properties.
- If an entry with the exact confirmed ID already exists, make no change and report it as already
  configured.
- Do not add a `file` entry. Local-file Worker authoring is not supported by the current provision
  target.
- Do not add names, full agent IDs, credentials, scopes, or WIQD-owned metadata to the entry.

## Remove

For removal by friendly name, resolve and confirm the published Worker when the resolver is
available. If `worker_agents` is absent or empty, report that there is no Worker reference to remove
and stop. Otherwise, when the resolver is unavailable, list every existing `worker_agents[].id`
exactly as stored and require the author to select one exact ID. Never infer which existing ID
corresponds to a friendly name. Apply the same confirmation gate after selection, then remove only
entries whose `id` exactly equals the confirmed Worker ID. If none exists, make no change and report
it as already absent. If removing the match leaves no entries, remove the top-level `worker_agents`
property instead of saving an empty array. This keeps v1.6 manifests valid and normalizes the same
state consistently for later supported schemas.

Removing a reference never deletes the deployed Worker.

## Verify

Immediately after a changed manifest is saved, run:

```bash
wiqd agent validate --path "<project-directory>" --json --skill wiqd --workflow <active-workflow-id>
```

If validation fails, report the diagnostics and do not provision. If validation succeeds, report the
result and stop unless the author's original request explicitly included deploy or provision. Only
in that explicit case continue through the active workflow's provision reference. A request to test
or evaluate routes through the eval workflow and does not authorize provisioning. Report whether
the Worker ID came from the resolver or the author, the exact manifest entry added or removed,
manifest path, validation result, and whether any bytes changed.
