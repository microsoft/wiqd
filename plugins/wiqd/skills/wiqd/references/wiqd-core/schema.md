# Manifest Schema Reference for M365 Copilot Agents

This document is a **version-compatibility overview** for M365 Copilot declarative agent (DA) and API plugin manifests — it is not a property reference. Capability and property definitions change as new manifest versions ship, so **never hardcode or guess them here**; always retrieve the current, authoritative definition from the web before using one.

## Version Compatibility Overview

### Declarative Agent (DA) Manifest

Versions span **v1.0 through the current published version** — discover the latest via the procedure in "Discovering the current published version" below; never assume a fixed ceiling. Note there is no v1.1 (that version number was never released). Every published minor version has a public JSON Schema at the URL pattern under "Authoritative Sources." The `draft` version is an **internal/1P-only** preview and may not have a published public schema yet; 3P authoring should target a published stable version. Newer versions generally add capabilities and properties that older versions don't support — check the `"version"` field in `declarativeAgent.json` before assuming a capability is available. Well-known capability names you'll encounter across these versions include (illustrative only, not version-pinned):

- `WebSearch`
- `OneDriveAndSharePoint`
- `GraphConnectors`
- `Email`
- `People`
- `TeamsMessages`

Do not assume any of the above — or any other capability — is available, or has a given property, for a specific version without confirming against the live schema. See "Authoritative Sources" below.

### API Plugin Manifest

Versions span **v2.0 through the current published version** — discover the latest via the procedure in "Discovering the current published version" below; never assume a fixed ceiling. **v2.0 is legacy** — it uses `"schema_version": "v2"` rather than a semantic version and has no versioned public schema URL. v2.1 and onward have versioned public JSON Schemas at the URL pattern under "Authoritative Sources." The `draft` version is an **internal/1P-only** preview and may not have a published public schema yet; 3P authoring should target a published stable version. As with the DA manifest, confirm runtime, function, and capability property availability against the live schema for your target version rather than assuming from the version number alone.

## Authoritative Sources

This file intentionally does not enumerate properties. Retrieve them dynamically from:

- **Public JSON Schemas** (canonical, versioned):
  - Declarative agent: `https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v<x.y>/schema.json` — substitute `v<x.y>` with the target version (see "Discovering the current published version" below).
  - API plugin: `https://developer.microsoft.com/json-schemas/copilot/plugin/v<x.y>/schema.json` — substitute `v<x.y>` with the target version (see "Discovering the current published version" below).
- **Official Microsoft Learn documentation** for declarative agent and API plugin manifest capabilities — web-search for the current Learn page. Learn content is updated independently of this file, so don't rely on a cached or remembered URL.

Not every version has a schema published at the URL pattern above — for example, legacy API plugin v2.0 (`schema_version: "v2"`), `draft`/preview versions, and the DC (declarative copilot) manifest currently have no public JSON Schema. For those, don't guess: web-search the official Microsoft Learn docs for that specific version, and if it still can't be confirmed, tell the user the property can't be verified rather than inventing one.

## Discovering the current published version

wiqd intentionally hardcodes no "latest" manifest version in this file or anywhere else in its references, so this file needs no edit when Microsoft ships a new manifest version (DA and plugin manifests each ship roughly every 2-3 months). The `v<x.y>` token used throughout this file and [examples.md](examples.md) is a **placeholder** for whatever the current published version is at the time you're reading this — never copy `v<x.y>` literally into a manifest, and never assume a version number you remember from a prior session is still current.

1. **For an EXISTING manifest, don't look up "the current version" at all** — read its required `"version"` field (DA) or `"schema_version"` field (API plugin) and use that. If `$schema` is also present, use it only as a corroborating declaration and require it to identify the same version (see "How to Look Up a Capability's Properties" below; never default an existing manifest to "latest").
2. **To find the CURRENT published version** — for a brand-new manifest, or to check whether a newer version is available for an upgrade — consult Microsoft's canonical latest-version pointer:
   - **Declarative agent:** the "latest declarative agent manifest" IMPORTANT callout on Microsoft Learn, or its source include `https://raw.githubusercontent.com/MicrosoftDocs/m365copilot-docs/main/docs/includes/latest-declarative-agent-manifest.md`.
   - **API plugin:** `https://raw.githubusercontent.com/MicrosoftDocs/m365copilot-docs/main/docs/includes/latest-plugin-manifest.md`.
   - **Fallback**, if those are unreachable: `web_search` for the Learn "declarative agent manifest" / "API plugin manifest" pages (`declarative-agent-manifest-<x.y>` / `plugin-manifest-<x.y>` under `microsoft-365-copilot/extensibility/`), or probe `.../v<x.y>/schema.json` for the highest `<x.y>` that returns HTTP 200.
3. If none of these sources are reachable, tell the user you could not confirm the current version rather than guessing one.

## How to Look Up a Capability's Properties

Before adding or editing any capability property in a manifest:

1. **Determine the exact target version from the manifest itself — never default to "latest."** Parse the manifest before inspecting declarations. A DA manifest MUST carry the `"version"` field required by its published schema; an API plugin MUST carry `"schema_version"`. Stop without mutation when that required declaration is absent. `$schema` is optional, but when present its version MUST agree with the required version field. A version-only manifest is valid; a `$schema`-only DA manifest is not.
2. **Derive and fetch the canonical raw JSON Schema first — it is the authoritative source.** Construct the exact Microsoft URL from the reconciled version and the pattern under "Authoritative Sources." If `$schema` is declared, require it to match that canonical origin, path, and version after ordinary URL normalization; never fetch a noncanonical URL merely because it embeds the expected version. Inspect `properties`, `required`, and every applicable `$ref` directly. Resolve local `$ref` chains to the exact nested definition and confirm property type plus enum/const constraints before editing. Do NOT rely on `web_search` result summaries for property names: they are synthesized and can surface properties that do not exist (the exact hallucination this file exists to prevent).
3. Use `web_search` / Microsoft Learn only as a **supplement** — for versions with no published public schema (legacy Plugin v2.0, `draft`/preview, the DC manifest), or when the raw schema leaves a property's shape ambiguous. Never let a search default you to the newest documented version; confirm the version explicitly.
4. Use only property names you've confirmed exist for the target version. **Never invent a property name** — for example, there is no `items_by_default` property. A hallucinated property fails manifest validation or is silently ignored.

If the schema cannot be fetched, parsed, or resolved to the requested property and constraints,
tell the user support could not be confirmed for the manifest's declared version. Leave the
manifest byte-identical instead of guessing.
