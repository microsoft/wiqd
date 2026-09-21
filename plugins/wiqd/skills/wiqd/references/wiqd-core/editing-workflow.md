# JSON Development Workflow

This document provides step-by-step instructions for developing M365 Copilot agents using JSON manifest files.

## Prerequisites

- Project must be scaffolded first (use scaffolding workflow if needed)
- Project contains `m365agents.yml` at the root
- Project uses JSON manifest files (`.json`)

---

## ✅ APP NAME & DESCRIPTION REQUIREMENT ✅

When developing an agent, you MUST ALWAYS update the app name and description in `manifest.json` to something **meaningful and descriptive** that reflects the agent's purpose. Never leave default/placeholder names like "My Agent" or generic descriptions.

**NEVER use "(local)" suffix in app names.** Always remove any "(local)" suffix from the app name.

---

## 🚨 CRITICAL DEPLOYMENT RULE 🚨

When making ANY successful, validated edits to an agent — including instructions, conversation starters, capabilities, plugins, or any file in `appPackage/` — you MUST ALWAYS deploy using `wiqd agent provision --env local` before returning to the user unless the author explicitly opts out. Rejected edits and validation failures MUST NOT deploy.

**You must NEVER:**

- Skip deploy because "it's just instructions" — deploy after every change
- Tell the user to "run `wiqd agent provision` yourself" — YOU must run it
- Deploy when validation found errors — not even "to test" or "to demonstrate"
- Deploy "to show the user what happens" when there are errors — just report the errors
- Run `wiqd agent provision` "for educational purposes" to demonstrate failure — errors = STOP, not a teaching moment

**Only exception:** The user explicitly asks you NOT to deploy. Only the user can opt out, never you.

---

---

## 💬 CONVERSATION STARTERS REQUIREMENT 💬

Every agent needs meaningful conversation starters that help users understand what the agent can do. Review the agent's capabilities and add/update conversation starters that showcase the agent's primary functions. Never leave an agent without conversation starters.

---

## 📝 ALWAYS UPDATE INSTRUCTIONS & STARTERS AFTER CHANGES — MANDATORY 📝

**This is NOT optional.** Adding a capability without updating instructions is incomplete work.

When you add, remove, or modify ANY capability or plugin, you MUST complete ALL of these steps before deploying:

1. **Update `instructions`** — Add a section describing what the new capability/plugin enables. For removals, delete all references to the removed capability.
2. **Add conversation starters** — Add at least 1 new conversation starter per added capability or plugin. Each starter should demonstrate the new functionality.
3. **Remove stale starters** — Delete conversation starters that reference removed capabilities.
4. **Update description** in `manifest.json` if the agent's purpose has expanded.
5. **Review existing instructions** for stale references to removed capabilities.

**This applies to EVERY edit operation:** adding capabilities, removing capabilities, adding API plugins, adding MCP servers, modifying scoping, or any other manifest change.

---

## Instructions

### Step 1: Understand the Requirements

**Action:** Gather and analyze the agent requirements:

- Identify the agent's primary purpose and target users
- Determine required data sources (M365 services, external APIs)
- List necessary actions the agent must perform
- Identify security and compliance requirements

### Step 2: Design the Agent Architecture

**Action:** Create a comprehensive architectural design:

- Select deployment model (personal or shared)
- Choose appropriate M365 capabilities with scoping
- Design API plugin integrations if needed
- Plan authentication and authorization strategy
- Design conversation flow and instructions

### Step 3: Edit JSON Manifest Files

**⚠️ PRE-EDIT CHECK — Before making ANY edits, do ALL of these:**

1. **Check for malformed JSON**: Read `declarativeAgent.json` and verify it parses correctly. If it has syntax errors (missing commas, unclosed brackets, trailing commas, etc.):
   - **STOP** — do NOT proceed with your edit
   - **INFORM** the user: list every syntax issue with line numbers
   - **ASK** the user if you should fix the syntax errors first
   - Only after the user confirms, fix with surgical edits, then re-read the file
   - Then continue with the user's original request as a separate step

2. **Check the schema version**: Read the `"version"` field the manifest declares (`v<x.y>`, e.g. `"v1.6"`) in `declarativeAgent.json`. For EVERY feature you plan to add, verify it exists in that version using the dynamic lookup procedure in [schema.md](schema.md) — fetch the authoritative versioned JSON Schema (schema.md is a version-compatibility overview, not a property reference). If a requested feature requires a newer version → **STOP. Tell the user.** Offer to upgrade the version first.

3. **Run a proactive instruction review** (if the edit touches instructions or capabilities): Before modifying instructions or adding/removing capabilities, run [Instruction Review](instruction-review.md) **Phase 1 (Inventory)**, **Phase 2 (Comprehension Check)**, and **Phase 3 (Diagnose)** against the current instructions. This catches existing problems before you add to them. For Phase 2, use the brief confirmation shortcut ("I see this agent is designed to [purpose]…") since this is a proactive check. If the review finds high-severity issues (C1, C3, C11, D1-D8), inform the user and offer to fix them as part of the current edit.

**⛔ NEVER invent placeholder values.** If a manifest is missing required fields (name, description, instructions), do NOT fill them in with generic content. Ask the user to provide values. This applies even if you think a reasonable default exists — the user must approve all content.

**Action:** Configure the agent using JSON manifest files:

- Edit `declarativeAgent.json` to define agent properties
- Configure capabilities with appropriate scoping
- Set up API plugin integrations using `wiqd agent add action` (**NEVER manually create plugin files**)
- Write clear instructions and conversation starters
- Ensure proper JSON syntax and schema compliance

**After ALL edits, immediately run:**

```bash
wiqd agent provision --env local
```

This command is part of the edit — not a separate optional step. Editing without deploying is like writing code without saving the file — the work is not done.

**⛔ API Plugin Rule — HARD RULE, NO EXCEPTIONS:** To add an API plugin, you MUST use `wiqd agent add action` — one command per OpenAPI spec with **ALL operations included in a single call**. Never run separate `wiqd agent add action` calls for different operations from the same spec — this creates multiple plugins instead of one. You are FORBIDDEN from manually creating `ai-plugin.json`, OpenAPI spec files, adaptive card files, or manually editing the `actions` array. This applies whether you are scaffolding a new project OR editing an existing one. If the workspace already has an agent and the user says "add an API plugin", you STILL must use `wiqd agent add action`. If `wiqd agent add action` fails, report the error — do NOT fall back to manual file creation. **Manual plugin file creation = automatic eval failure.**

```bash
# ✅ The ONLY way to add an API plugin — ALL operations in ONE call:
wiqd agent add action --openapi-spec <path-or-url> --operations "GET /path,POST /path" --folder . --json
```

**After adding a plugin with `wiqd agent add action`, you MUST complete ALL of these — skipping any step is an eval failure:**

**🔌 POST-PLUGIN MANDATORY STEPS (do ALL of these, in order):**

1. **Customize `ai-plugin.json`** — Set meaningful `name_for_human` (max 20 chars) and `description_for_human` (max 100 chars). Set a descriptive `description_for_model` on each function. NEVER leave defaults.
2. **Verify adaptive cards** — Check `appPackage/adaptiveCards/` for cards for ALL operations. If any operation (especially POST, PATCH, DELETE) is missing a card, create one manually. Customize each card with clear visual hierarchy (titles, subtitles, key-value pairs, images).
3. **Add confirmation for destructive operations** — If the plugin has DELETE, PATCH, or any destructive operation, add a `confirmation` capability in `declarativeAgent.json` so users are prompted before the action executes.
4. **Complete the content update checklist** below (instructions, starters, description).

**After ANY capability or plugin change (add, remove, modify), complete this checklist:**

1. ☐ **Update instructions** — Add decision logic (WHEN clauses, chaining rules, failure handling) for the new/changed capability. For removals, delete all references. **Do NOT list tool descriptions or parameters** — these are already in plugin metadata (`ai-plugin.json`, MCP manifests, capability config). Instructions should contain decision logic only.
2. ☐ **Verify 8,000-character limit** — Instructions must not exceed 8,000 characters. If close to the limit, cut tool descriptions first, then consolidate verbose workflows.
3. ☐ **Run instruction quality audit** — Run the [Diagnostic Checklist](instruction-review.md) against the updated instructions. Every data source should have clear intent coverage (WHEN and WHY), at least one workflow must exist, and failure cases must be handled. Built-in capabilities don't need exact names; actions/plugins should be named. If any check fails, fix it before deploying.
4. ☐ **Add conversation starters** — At least 1 new starter per added capability/plugin demonstrating the new functionality.
5. ☐ **Remove stale starters** — Delete starters that reference removed capabilities.
6. ☐ **Update `manifest.json` description** if the agent's purpose has expanded.
7. ☐ **Review existing instructions** for stale references to removed capabilities.

**This checklist is NOT optional.** Adding a capability without updating instructions and starters is incomplete work.

**⚠️ Instruction quality matters as much as JSON correctness.** Output-focused instructions (tone, format, style only) are a known failure pattern — they cause agents to give generic answers and ignore configured capabilities. Listing tool descriptions and parameters in instructions wastes the 8,000-character budget — this metadata is already available to the orchestrator. See [Instruction Review](instruction-review.md) for the anti-pattern catalog and before/after rewrites.

**Reference:** [schema.md](schema.md) for version compatibility and the dynamic property-lookup procedure
**Reference:** [api-plugins.md](api-plugins.md) for adaptive card enhancement guidelines after adding a plugin

**⚠️ IMPORTANT:** After making any edits to JSON files, you MUST deploy the agent (Step 4) before returning to the user.

**⛔ MANDATORY POST-EDIT CHECKPOINT — YOU ARE NOT DONE YET:**
After editing ANY file in `appPackage/`, you MUST deploy before responding to the user. Skipping this is an eval failure:

- **Deploy** — Run `wiqd agent provision --env local`. If you edited files but did not run this command, your work is incomplete. The only exception is if the user explicitly asked you not to deploy.

If you are about to respond to the user and you have NOT deployed, **STOP and deploy now**.

### Step 4: Provision and Deploy

**⛔ PRE-DEPLOY CHECK:** Before running the command below, verify the JSON files are syntactically correct and have the required fields. If there are known errors → fix them first before deploying.

**Action:** Provision required Azure resources and register the agent:

```bash
wiqd agent provision --env local
```

**Result:** Returns a test URL like `https://m365.cloud.microsoft/chat?titleId=T_abc123xyz`

**Note:** JSON-based agents do not require a compilation step - changes are deployed directly.

**✅ After successful provision, ALWAYS present the review UX with the test link:**

Read `M365_TITLE_ID` from `env/.env.local` and output:

```
✅ Agent deployed successfully!

🚀 Test Your Agent in M365 Copilot:
🔗 https://m365.cloud.microsoft/chat?titleId={M365_TITLE_ID}
```

**⛔ Never respond without this link.** If you deployed, the test link MUST appear in your response. This is not optional.

Then wait for the user's response.

### Step 5: Test and Iterate

**Action:** Test the agent in Microsoft 365 Copilot:

- Use the provisioned test URL
- Test all conversation starters
- Verify capability access and scoping
- Test error handling and edge cases
- Validate security controls

### Step 6: Deploy to Environments

**Action:** Deploy to staging/production environments:

```bash
wiqd agent provision --env prod
```

**Reference:** [deployment.md](deployment.md) for environment management and CI/CD patterns

### Step 7: Package and Share

**Action:** Package and share the agent:

```bash
# Package the agent
wiqd agent provision --env dev

# Share to tenant (for shared agents)
wiqd agent share --scope tenant --env dev
```

---

## Critical Workflow Rules

### Always Deploy After Edits

**RULE:** When making any changes to an agent (JSON manifest files, instructions, capabilities, API plugins), you MUST complete the following workflow before returning to the user:

1. Provision/deploy the agent: `wiqd agent provision --env local`
2. Read `M365_TITLE_ID` from `env/.env.local`
3. Present the review UX with the test link:

   ```
   ✅ Agent deployed successfully!

   🚀 Test Your Agent in M365 Copilot:
   🔗 https://m365.cloud.microsoft/chat?titleId={M365_TITLE_ID}
   ```

**⛔ Never respond without this link after deploying.**

### Always Clean Up Unused Files

**RULE:** Every time you work on an agent project, check for and remove unused or obsolete files:

- `TODO.md` or planning files no longer needed
- Old backup files (`.bak`, `.old`, `.orig`)
- Unused JSON files not referenced anywhere
- Stale environment files (`.env.old`, `.env.backup`)
- Empty or placeholder files
- Outdated manifest versions
- Unused API plugin definitions

---

## Capability Management

Capabilities grant the agent access to data sources and tools. They are managed in the `capabilities` array of `declarativeAgent.json`.

Do not maintain a capability or property inventory in this workflow. Read the exact versioned JSON schema as required by the pre-edit check; its definitions, required fields, constraints, and descriptions are authoritative. The guidance below covers only decisions and value-retrieval steps the schema cannot perform for the user.

### Finding IDs and URLs

Inspect the exact schema version before editing. When source scoping is optional:

1. Ask whether to use all accessible content or specific sources, and wait for the answer. Never infer “all” from silence or a missing value.
2. For all accessible content, omit optional scoping properties; never emit an empty scoping array.
3. For specific sources, give the matching retrieval steps below when requesting each missing value. Wait for real values and validate them against the schema. For additive requests, preserve existing entries and append only missing sources. For replace, remove, or rescope requests, remove excluded sources and retain only the requested scope. If removing a source would leave the scope empty, stop and ask whether to remove the capability entirely or supply a replacement source; never omit the scoping property as a fallback.

Never invent values or placeholders. If the user already supplied a value, verify it and continue.

#### Shared Graph Explorer setup

Open `https://developer.microsoft.com/graph/graph-explorer`, sign in to the data-owning tenant, set the method and URL, grant listed permissions through **Modify permissions**, and run the query. Never request access tokens or credentials.

#### SharePoint or OneDrive IDs

Guide the user through the **Graph Explorer** tab of [Retrieving capabilities IDs for declarative agent manifest](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/declarative-agent-capabilities-ids?tabs=explorer). After consenting to `Sites.Read.All` and `Files.Read.All`, use `POST https://graph.microsoft.com/v1.0/search/query` with the following request body, replacing the sample URL with the exact file or folder URL:

```json
{
  "requests": [
    {
      "entityTypes": ["driveItem"],
      "query": {
        "queryString": "Path:\"https://contoso.sharepoint.com/sites/YourSite/Shared%20Documents/YourFolder\""
      },
      "fields": ["fileName", "listId", "webId", "siteId", "uniqueId"]
    }
  ]
}
```

Verify `resource.listItem.fields.fileName` identifies the intended result. From `resource.listItem.fields`, map `siteId` to manifest `site_id`, `webId` to `web_id`, `listId` to `list_id`, and `uniqueId` to `unique_id`. Never use `resource.parentReference.siteId`: it is a composite identifier containing the hostname, site collection ID, and web ID, not the GUID required by manifest `site_id`.

#### Outlook folder IDs

For a default folder, prefer its locale-independent [well-known name](https://learn.microsoft.com/en-us/graph/api/resources/mailfolder?view=graph-rest-1.0#well-known-folder-names), such as `inbox`, `drafts`, `sentitems`, `deleteditems`, `junkemail`, or `archive`. For a custom folder, follow [List mailFolders](https://learn.microsoft.com/en-us/graph/api/user-list-mailfolders?view=graph-rest-1.0) in Graph Explorer: consent to `Mail.ReadBasic`, then run `GET https://graph.microsoft.com/v1.0/me/mailFolders?$select=id,displayName,childFolderCount`. For an accessible shared mailbox, consent to `Mail.Read.Shared` and replace `me` with `users/{shared-mailbox}` in this and the nested-folder URL below. Match `displayName`, copy its `id`, and follow `@odata.nextLink` when present. This request returns only folders directly under the mailbox root; for a nested folder, repeat with `GET https://graph.microsoft.com/v1.0/me/mailFolders/{parent-folder-id}/childFolders?$select=id,displayName,childFolderCount`.

#### Meeting IDs

The manifest `id` is the event's `iCalUId`, not its Graph `id`. In Graph Explorer, consent to `Calendars.ReadBasic`, then run `GET https://graph.microsoft.com/v1.0/me/events?$filter=subject eq '<meeting-subject>'&$select=iCalUId,subject,start,type`. Match both `subject` and `start`, follow `@odata.nextLink`, and ask the user to choose when multiple events match. Copy `iCalUId` exactly; it is an opaque string and must not be decoded or assumed to be Base64.

This query returns single-instance events and recurring-series masters. For an entire recurring series, select the result whose `type` is `seriesMaster` and set `is_series` to `true`. For one occurrence, run `GET https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=<start-ISO-8601>&endDateTime=<end-ISO-8601>&$select=iCalUId,subject,start,type`, replace both placeholders with a narrow UTC time range around the occurrence, match its subject and start time, copy its `iCalUId`, and set `is_series` to `false`. Never substitute an arbitrary occurrence's `iCalUId` for the series master: Microsoft Graph assigns a different `iCalUId` to each occurrence.

#### Source lookup summary

| Source | Where to find the value | Manifest field |
| ------ | ----------------------- | -------------- |
| Copilot connector | Follow the **Graph Explorer** tab of [Retrieving capabilities IDs for declarative agent manifest](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/declarative-agent-capabilities-ids?tabs=explorer#microsoft-365-copilot-connectors). An administrator must consent to `ExternalConnection.Read.All` and run `GET https://graph.microsoft.com/v1.0/external/connections?$select=id,name`. Match `name`, then copy `id`; otherwise ask the tenant administrator for it. | `GraphConnectors.connections[].connection_id` |
| SharePoint or OneDrive | For a URL, open the exact site, library, folder, or file in the browser and copy its absolute URL; prefer the direct resource URL over a short sharing link. For GUIDs, follow the SharePoint or OneDrive ID procedure above and copy the mapped values from the matching result. | `OneDriveAndSharePoint.items_by_url[].url` or `OneDriveAndSharePoint.items_by_sharepoint_ids[]` |
| Teams | For a channel, select **More channel options (…) → Copy link**. For a chat or meeting chat, open it in Teams on the web and copy the full browser URL. Preserve the complete link, including query parameters. | `TeamsMessages.urls[].url` |
| Outlook email | For folders, follow the Outlook folder ID procedure above and accept one or more values. For `shared_mailbox`, ask for exactly one shared-mailbox SMTP address. For `group_mailboxes`, ask for one or more group-mailbox SMTP addresses, up to 25. | As applicable: `Email.folders[].folder_id`, `Email.shared_mailbox`, `Email.group_mailboxes[]` |
| Meeting | Follow the meeting ID procedure above. Copy the selected event's `iCalUId` or Outlook `UID`; set `is_series` to `true` only for the series master and otherwise use `false`. | `Meetings.items_by_id[].id` and `Meetings.items_by_id[].is_series` |
| Dataverse knowledge source | In Copilot Studio, create or open an agent, add the intended Dataverse knowledge source, publish it, download its package, unzip it, and open its `declarativeAgent.json`. Copy the complete matching `knowledge_sources` entry so `host_name`, generated `skill`, and logical `table_name` values stay together. Never guess the generated `skill` ID or use a table's display name. | `Dataverse.knowledge_sources[]` |
| Scenario model | In Copilot Studio, open the intended model, select **Model details**, and copy its **Identifier**. Use the identifier, not the model's display name. | `ScenarioModels.models[].id` |
| Embedded knowledge | The normal authoring path needs no ID: copy each supported file into the app package and use its path relative to `declarativeAgent.json`. Use at most 10 files, each no larger than 1 MB; supported types are `.doc`, `.docx`, `.ppt`, `.pptx`, `.xls`, `.xlsx`, `.txt`, and `.pdf`. If the target schema uses `embedded_resource_snapshot_id` instead, that value must come from the external file-container storage service that provisioned the snapshot; there is no general discovery API, so ask that service's owner and never invent it. Confirm platform availability before editing. | `EmbeddedKnowledge.files[].file` or `EmbeddedKnowledge.embedded_resource_snapshot_id` |
| Public website | Open the intended site or section and copy its canonical HTTPS URL. Remove query parameters and fragments; the URL can contain at most two path segments. | `WebSearch.sites[].url` |

### Adding a Capability

Add the capability object to the `capabilities` array in `declarativeAgent.json`:

```json
{
  "capabilities": [
    {
      "name": "WebSearch",
      "sites": [
        { "url": "https://osha.gov" },
        { "url": "https://epa.gov" }
      ]
    },
    {
      "name": "OneDriveAndSharePoint",
      "items_by_url": [
        { "url": "https://contoso.sharepoint.com/sites/Engineering/Shared%20Documents" }
      ]
    },
    {
      "name": "GraphConnectors",
      "connections": [
        { "connection_id": "my-connector-id" }
      ]
    },
    { "name": "GraphicArt" },
    { "name": "CodeInterpreter" },
    { "name": "EmailActions" },
    { "name": "MeetingActions" }
  ]
}
```

When adding Graph connector IDs, trim and ignore empty IDs, reuse the existing `GraphConnectors` capability, preserve its connections, and append only missing `connection_id` values. If every requested ID already exists, leave the file unchanged.

If you add `EmailActions` or `MeetingActions`, ensure the manifest `version` is at least `v1.8`, the minimum required for these capabilities; see [Example 9](examples.md#example-9-full-agent-with-all-features) for a complete example manifest.

### Removing a Capability

Remove the capability object from the `capabilities` array. Preserve all other capabilities. After removing, update instructions and conversation starters to remove references to the removed capability.

### Adding Multiple Capabilities at Once

Multiple capabilities can be added in a single edit. Add all capability objects to the `capabilities` array together:

```json
{
  "capabilities": [
    { "name": "WebSearch", "sites": [{ "url": "https://arxiv.org" }] },
    { "name": "GraphicArt" },
    { "name": "CodeInterpreter" }
  ]
}
```

### Post-Edit Verification

After adding or removing capabilities, verify the change was applied:

1. Re-read `declarativeAgent.json` and confirm `capabilities` array is correct
2. Check that no other properties were lost or corrupted
3. Follow the mandatory content update checklist (instructions, starters, description)
4. Deploy: `wiqd agent provision --env local`

---

## Grounding Control — `discourage_model_knowledge`

When a user wants the agent to **only answer from its configured data sources** and never fabricate answers from general knowledge, use the `behavior_overrides` manifest property. This is the platform-level anti-hallucination control — it goes beyond instruction-level guidance by injecting special instructions into the orchestrator prompt that discourage the model from using pre-trained knowledge. The agent will say "I don't have information about that" instead of making things up.

### When to use it

Set `discourage_model_knowledge: true` when the user expresses any of these intents:

- "Don't make things up" / "no hallucinations"
- "Only use my data" / "only answer from my documents"
- "Ground the agent" / "I want grounded responses"
- "Only respond from configured sources"
- "Don't use general knowledge" / "no model knowledge"
- The agent's domain requires strictly factual, source-backed answers (HR policy bot, legal FAQ, compliance agent, internal knowledge base)

### Canonical JSON shape

Add the `behavior_overrides` object to `declarativeAgent.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v<x.y>/schema.json",
  "name": "My Grounded Agent",
  "description": "...",
  "instructions": "$[file('instructions.txt')]",
  "behavior_overrides": {
    "special_instructions": {
      "discourage_model_knowledge": true
    }
  }
}
```

### Important constraints

- **Requires manifest schema v1.4+.** Check the `$schema` URL in `declarativeAgent.json` before adding. If the agent is on v1.0, v1.2, or v1.3, offer to upgrade the schema version first.
- **Pair with data-source capabilities.** `discourage_model_knowledge` is most useful when the agent has capabilities configured (`WebSearch`, `OneDriveAndSharePoint`, `GraphConnectors`, etc.). Without configured data sources, the agent will say "I don't know" to almost everything because it has no data to draw from.
- **Complements instruction-level guidance.** Good instructions ("only answer from provided documents") plus `discourage_model_knowledge: true` gives both behavioral and platform-level enforcement. Use both for maximum grounding.

---

## Default response mode

When the author asks to set the agent's default response mode, edit only
`behavior_overrides.default_response_mode` in `appPackage/declarativeAgent.json`.

The only canonical persisted values are:

- `Auto`
- `Quick response`
- `Think deeper`

Match those complete phrases case-insensitively when interpreting natural language, then write the
exact spelling, casing, and spacing above. Reject aliases or unsupported values and report all
three choices.

Before editing, parse the manifest and require its `version` field. If `$schema` is present,
require it to identify the same version; `$schema` may be absent, but `version` may not. Fetch that
exact version's raw schema, resolve the root `behavior_overrides` definition, and confirm
`properties.default_response_mode` is a string whose enum contains the selected canonical value.
Do not use the latest schema as evidence for an older target. A missing required version, a
conflicting `$schema`, malformed JSON, an unavailable or unresolvable schema, or an absent
property/enum all stop the workflow without changing the file. When the exact schema is too old to
contain the property, explain that the author must upgrade the manifest schema/version first;
never upgrade it silently.

Canonical shape:

```json
{
  "behavior_overrides": {
    "default_response_mode": "Think deeper"
  }
}
```

If `behavior_overrides` is absent, add that object at the smallest valid insertion point. If it
already exists, add or replace only `default_response_mode`. Preserve `special_instructions`,
`suggestions`, all other siblings, unrelated fields, ordering, indentation, and newline style.
Every fail-closed path leaves the original manifest byte-identical.

After the edit, re-read the manifest, verify the exact nested value and preservation, and run
`wiqd agent validate --path <project-directory> --json --skill wiqd --workflow wiqd-core`.
Provision only after validation succeeds. Run
`wiqd agent provision --env local --path <project-directory> --json --skill wiqd --workflow wiqd-core`
unless the author explicitly asked not to deploy or provision; that opt-out does not skip the edit
or validation.

---

## ⛔ FINAL GATE — Before Responding to the User

**STOP.** Before writing your response after a default-response-mode edit, apply the branch that
matches the workflow outcome and the author's request:

- **Edit rejected or validation failed**
  - [ ] I did not run provision, publish, or any other deployment command
  - [ ] I reported the actionable failure without claiming the edit completed

- **Edit validated with an explicit provision/deployment opt-out**
  - [ ] I ran validation and it succeeded
  - [ ] I did not run provision, publish, or any other deployment command
- **Edit validated with no explicit opt-out, but provisioning failed**
  - [ ] I reported the actionable provisioning failure without claiming deployment succeeded
  - [ ] I did not present an M365 test link
- **Edit validated with no explicit opt-out**
  - [ ] I ran `wiqd agent provision --env local` after successful validation and it succeeded
  - [ ] I read `M365_TITLE_ID` from `env/.env.local`
  - [ ] I presented the review UX with the `🚀 Test Your Agent in M365 Copilot:` link

**If you cannot check every box in the applicable branch, you are NOT done.** Go back and complete
the missing steps.

This checklist applies to **EVERY turn that attempts a default-response-mode edit** — not just the
last turn in a multi-turn conversation.
