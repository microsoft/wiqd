---
name: wiqd-core
description: >
  Full lifecycle workflow for M365 Copilot declarative agents with wiqd.
  Covers creating, editing, adding capabilities, actions, skills, and authentication,
  validating, provisioning, packaging, sharing, deleting,
  managing environments, showing agent details, migrating, and localizing agents.
trigger-summary: "create agent, edit agent, scaffold agent, agent capabilities, default response mode, worker agents, add a plugin capability to an agent, add an agent skill, add authentication, validate, provision, deploy, package, share, delete, open, show, migrate, localize, manage environments"
triggers: >
  create agent, new agent, scaffold agent, edit my agent, update my agent, modify my agent,
  add a capability, add a capability to this agent, add a named capability,
  configure an agent capability, change capability scope,
  add a plugin capability to my agent, add an API plugin to my agent,
  add an agent skill, add a skill to my agent, import an agent skill, expose a skill to Copilot,
  add authentication, configure authentication,
  provision my agent, deploy my agent, package my agent,
  share my agent, delete my agent, remove my agent, open my agent, show my agent,
  show my environments, manage environments, add environment, migrate my agent,
  localize my agent, validate my agent, fix my agent manifest, update instructions,
  add web search, update manifest, set default response mode, change default response mode,
  set quick response mode, set think deeper mode, review instructions, add a worker agent, connect a worker agent,
  remove a worker agent, disconnect a worker agent
routing-label: "Agent lifecycle tasks"
routing-intent: "Creating, editing, setting response behavior, adding Worker references, capabilities, actions, skills, and authentication, validating, provisioning, packaging, sharing, deleting, showing agents"
routing-order: 1
contract-version: 1
routing-requires: [agent create, agent add, agent validate, agent provision, agent package, agent share, agent env, agent show, agent delete, agent publish]
wiqd-lifecycle-theme: Build
wiqd-lifecycle-order: 1
journey: |
  [Build]
  order: 1
  primary: true
  box-item: create
  box-item: edit
  box-item: instructions
  box-item: capabilities
  box-item: localize
  entry: No `appPackage/` directory, or user wants to continue editing
  goal: Get a project on disk and define what the agent does
  workflow-desc: — handles create, edit, validate, migrate, localize
  exit: `appPackage/manifest.json` and `declarativeAgent.json` exist and are structurally valid
  signal: No `appPackage/` at all => **Build** (start with create/migrate)
  signal: `appPackage/` exists, no evals yet => **Build** or **Improve**
  plan-step: 10 | validate manifest
  readiness: Manifest validates clean | wiqd agent validate

  [Improve]
  order: 2
  box-item: validate
  workflow-desc: for validate

  [Preview]
  order: 3
  primary: true
  box-item: package
  box-item: provision
  box-item: share
  entry: Quality bar met
  goal: Deploy the agent and share with early users
  workflow-desc: — handles package → provision → share
  exit: Agent provisioned and shared with preview audience
  signal: Agent packaged/provisioned => **Preview** [3p]
  plan-step: 40 | package + provision
  plan-step: 50 | share with preview users [3p]
  readiness: Package builds successfully | wiqd agent package
  readiness: Preview deployment ready | package + provision completed [3p]
  readiness: Preview audience has access | share completed for test users [3p]

  [Publish]
  order: 5
  primary: true
  targets: 3p
  box-item: publish
  entry: Preview complete
  goal: Get the agent in front of users and monitor performance
  workflow-desc: for publish (3P)
  exit: Agent live in target audience, monitored
  iteration: Real users → metrics/feedback → loop back to Build/Improve → re-package → re-publish
  signal: Reviews done (or 3P), not published => **Publish**
  plan-step: 80 | publish [3p]
---

# wiqd Core — Agent Lifecycle

Full lifecycle for M365 Copilot declarative agents with wiqd.

> **Convention:** When calling wiqd commands from a skill context, always use `--json` for commands that produce output the model needs to parse. This gives the orchestrator structured, machine-readable output instead of lossy table text.

This workflow handles two core flows directly and routes to reference files for other lifecycle operations:
1. **Create** — scaffold a brand-new agent project from a template
2. **Edit** — modify an existing agent's capabilities, instructions, starters, actions, skills, and authentication
3. **Other lifecycle operations** — validate, provision, package, share, delete, open, env, show, migrate, localize → handled via reference files

## Existing-Project Lifecycle Gate — MANDATORY BEFORE ROUTING

Before **Edit**, **Validate**, **Provision/Deploy**, or **Package**, inspect the project root for
`m365agents.yml`, `m365agents.local.yml`, `teamsapp.yml`, or `teamsapp.local.yml`, matching the
filenames case-insensitively.

If a lifecycle file is found with different casing, **reject the operation** and tell the user to
rename it to the matching canonical lowercase filename before continuing. The enforcer remains
case-insensitive so differently-cased files cannot bypass protection, but downstream lifecycle processing requires
canonical names. Do not route to the operation's reference or run its command until this gate
passes.

## Routing

Determine which flow to follow based on user intent:

| User intent | Action |
|-------------|--------|
| **Standalone / reusable plugin** — "create a plugin", "a plugin project", "a plugin with a skill/connector", "package/publish/validate my plugin" | **Stop — this is not the agent workflow.** Read `workflows/plugin.md` (the `plugin` workflow authors a standalone plugin app package). |
| Create/new/scaffold an agent **with a skill** | Run the **Create** workflow, then **Adding Agent Skills**. |
| Create, new, scaffold | **Create** workflow (below) |
| Add/connect/remove/disconnect a Worker Agent | Run the **Existing-Project Lifecycle Gate**, then read `../references/worker-agents.md`. Removing a Worker removes only its manifest reference; it never deletes the deployed agent. |
| Set or change the agent's default response mode (`Auto`, `Quick response`, or `Think deeper`) | Run the **Existing-Project Lifecycle Gate**, then the **Edit** workflow and its **Setting the default response mode** section. |
| Add or change any capability in an existing agent — including “add [named capability] to this agent” | Run the **Existing-Project Lifecycle Gate**, then the **Edit** workflow (below) |
| Edit, update, add, modify, change, rename, rewrite, fix, improve, configure | Run the **Existing-Project Lifecycle Gate**, then the **Edit** workflow (below) |
| Validate | Run the **Existing-Project Lifecycle Gate**, then read `references/wiqd-core/validate.md` — run `wiqd agent validate` |
| Provision, deploy | Run the **Existing-Project Lifecycle Gate**, then read `references/wiqd-core/provision.md` |
| Package, build zip | Run the **Existing-Project Lifecycle Gate**, then read `references/wiqd-core/package.md` |
| Store ops audit, pre-submission check, marketplace / Teams Store / AppSource validation, "will my agent pass review?", publish readiness | Read `references/validate/store-ops-validation.md` (skill lives in the `microsoft.validate` extension) |
| Evaluate, test agent, run evals | Read `workflows/eval/eval.md` — requires `eval init` + Azure OpenAI env vars first |
| Share (with users, a security group, or the tenant), collaborator | Read `references/wiqd-core/share.md` |
| Delete, remove agent | Read `references/wiqd-core/lifecycle.md` → Delete section |
| Open, test URL | Read `references/wiqd-core/lifecycle.md` → Open section |
| Environments, env list/add/reset | Read `references/wiqd-core/lifecycle.md` → Env section |
| Show, agent details | Read `references/wiqd-core/show.md` |
| Migrate, convert TTK | Read `references/wiqd-core/migrate.md` |
| Localize, multi-language | Read `references/wiqd-core/localize.md` |

### Create vs Edit disambiguation

| Condition | Workflow |
|-----------|----------|
| No `appPackage/` directory, no `declarativeAgent.json` | **Create** workflow |
| User explicitly says "create", "new", "scaffold" | **Create** workflow |
| `appPackage/declarativeAgent.json` exists | **Edit** workflow |
| User says "edit", "update", "add", "modify", "change" | **Edit** workflow |
| Existing agent files detected when user asks to create | **Stop.** This is an existing project — use the Edit workflow instead. |

---

# CREATE WORKFLOW

Scaffold a new M365 Copilot declarative agent project.

## Create Command

```bash
wiqd agent create --name "<agent-name>" [--template <template>] [--output <path>]
```

### Create Options

| Flag | Description | Default |
|------|-------------|---------|
| `--name`, `-n` | Agent display name | (required) |
| `--template`, `-t` | Agent template (wiqd only supports declarative agents — the default is the only legal value) | `declarative-agent` |
| `--output`, `-o` | Parent directory for the new project | `./` |
| `-i, --interactive` | Run in interactive mode | `false` |
| `-v, --verbose` | Show raw output for debugging | `false` |

### List Available Templates

```bash
wiqd agent create list
```

## Create Steps

1. **Verify** wiqd CLI is available (see preflight above)
2. **Check** target directory is empty
3. **Ask** the user for:
   - Agent name (meaningful, descriptive — not "My Agent")
   - Template preference is **not** needed by default — `--template` defaults to `declarative-agent`, the only family wiqd supports. Only ask about templates if the user explicitly raises the topic.
4. **Run** `wiqd agent create --name "<name>"`
5. **Enter the project directory** — `cd <name>` (wiqd creates a subfolder named after the project; all subsequent commands must run from inside it)
6. **Verify** the project was created (`appPackage/declarativeAgent.json` exists)
7. **Enrich** `declarativeAgent.json` with 3+ domain-relevant conversation starters (see Conversation Starters rules below) — MANDATORY
8. **Drop** the LSP configuration (see below) — MANDATORY
9. **Drop** the wiqd enforcer extension (see below) — MANDATORY
10. **Report** the result and suggest next steps:
   - _"Edit my agent's instructions"_
   - _"Add a capability to my agent"_ (e.g., WebSearch, OneDriveAndSharePoint)
   - _"Provision my agent locally"_

## ⛔ LSP Configuration — MANDATORY Post-Create Step

After `wiqd agent create` succeeds, you MUST create the LSP configuration file
at `<project>/.github/lsp.json` with **exactly** the following content:

```json
{
  "lspServers": {
    "wiqd": {
      "command": "wiqd",
      "args": ["agent", "lsp"],
      "fileExtensions": {
        ".json": "json"
      },
      "rootUri": "."
    }
  }
}
```

> **Note:** The Copilot CLI LSP config only supports extension-level mapping
> (not filename patterns like VS Code's `filenamePatterns`). The `.json`
> mapping is intentionally broad — the wiqd LSP server internally filters to
> only process recognized manifest files: `declarativeAgent.json`,
> `declarativeCopilot.json`, `ai-plugin.json`, `*-plugin.json`,
> `manifest.json`, and any `.json` with a recognized `$schema` URL.

## ⛔ wiqd Enforcer — MANDATORY Post-Create Step

After `wiqd agent create` succeeds, you MUST drop a project-scoped Copilot
CLI extension into the new project. This extension routes future edits of
agent files (`appPackage/`, `m365agents.yml`, `m365agents.local.yml`,
`teamsapp.yml`, `teamsapp.local.yml`) through the Edit workflow so manifests are
mutated correctly.

Create the file `<project>/.github/extensions/wiqd-agent-enforcer/extension.mjs`
with **exactly** the following content:

<!-- wiqd-agent-enforcer:start -->
```javascript
/**
 * wiqd-agent-enforcer
 * --------------------
 * Project-scoped Copilot CLI extension that enforces routing of M365
 * declarative agent edits through the `wiqd` skill from the
 * `wiqd` plugin.
 *
 * Why this exists:
 *   Skill discovery via SKILL.md descriptions is best-effort. The model
 *   sometimes bypasses wiqd and invokes raw `edit`/`create` on
 *   agent files (declarativeAgent.json, manifest.json, m365agents.yml,
 *   plugin manifests, etc.). This extension closes that gap by denying
 *   raw mutations to agent-owned paths until `skill(wiqd)` is
 *   invoked at least once in the session.
 *
 * To disable for a single session: delete or rename this file before
 * launching `copilot`.
 */
import { joinSession } from "@github/copilot-sdk/extension";

let agentBuildInvoked = false;

const MUTATION_TOOLS = new Set(["edit", "create", "write"]);

const MARKER_FILES = new Set([
    "m365agents.yml",
    "m365agents.local.yml",
    "teamsapp.yml",
    "teamsapp.local.yml",
]);

function isAgentOwnedPath(rawPath) {
    if (!rawPath) return false;
    const p = String(rawPath).replace(/\\/g, "/");
    if (p.includes("/appPackage/")) return true;
    const fileName = p.toLowerCase().split("/").pop();
    return MARKER_FILES.has(fileName);
}

await joinSession({
    hooks: {
        onPreToolUse: async (input) => {
            if (input.toolName === "skill") {
                const name = input.toolArgs?.name || input.toolArgs?.skillName;
                if (name === "wiqd") {
                    agentBuildInvoked = true;
                }
                return;
            }

            if (!MUTATION_TOOLS.has(input.toolName)) return;
            if (agentBuildInvoked) return;

            const filePath = input.toolArgs?.path;
            if (!isAgentOwnedPath(filePath)) return;

            return {
                permissionDecision: "deny",
                permissionDecisionReason:
                    "This file is part of an M365 declarative agent project. " +
                    "You MUST invoke skill(wiqd) before editing files under " +
                    "appPackage/, m365agents.yml, or teamsapp.yml. " +
                    "Call skill(wiqd) first to load the wiqd workflow, " +
                    "then retry this edit.",
            };
        },
    },
});
```
<!-- wiqd-agent-enforcer:end -->

After writing the file, briefly tell the user: "I've added a project-scoped
Copilot extension at `.github/extensions/wiqd-agent-enforcer/extension.mjs`
that ensures all future edits to agent files go through the wiqd
workflow. Restart your `copilot` session in this directory to load it."

The canonical source of this file lives at
`plugins/wiqd/skills/wiqd/assets/extension.mjs`. If the
content above ever drifts from that file, the asset wins.

## ⛔ Scaffolding Output Rules — MANDATORY

These rules govern the file structure produced after `wiqd agent create` succeeds. Apply them every time, no exceptions.

### Instructions Externalization

- **ALWAYS** create a separate `appPackage/instructions.txt` file containing the agent's system instructions
- **ALWAYS** set the `instructions` field in `declarativeAgent.json` to `$[file('instructions.txt')]`
- **NEVER** embed instructions inline in `declarativeAgent.json` — they MUST live in `instructions.txt`

### Schema Version

- **ALWAYS** keep the `$schema` and `version` that `wiqd agent create` scaffolds into `declarativeAgent.json` **verbatim** — the CLI selects the schema for the project, which may not be the newest published version.
- **NEVER downgrade** the scaffolded `$schema` / `version`. `wiqd agent create` also generates `declarativeAgent.json` content that only validates against the scaffolded (newer) schema, so lowering the version produces a schema/content mismatch that makes `wiqd agent validate` fail.
- Only **upgrade** the schema deliberately — and only when a newer capability you are adding explicitly requires it — never below the scaffolded version.

  The scaffolded `$schema` line has this shape (the version segment is whatever the CLI wrote — it is illustrative, NOT a value to hard-code):
  ```json
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/declarative-agent/<scaffolded-version>/schema.json"
  ```

### Environment Files

- **ALWAYS** create `env/.env.local` and `env/.env.dev` with placeholder environment variables after scaffolding
- These files enable per-environment configuration from day one
- Example content:
  ```
  # Environment-specific variables
  TEAMS_APP_ID=
  ```

### Conversation Starters

The scaffolding template does not include conversation starters, so they must be added manually after every create.

- **ALWAYS** add a `conversation_starters` array to `declarativeAgent.json` after scaffolding
- **ALWAYS** include at least 3 starters derived from the agent's name, purpose, and user prompt
- Each starter MUST have a `title` (2-4 word label) and `text` (full natural-language prompt)
- Starters must be **specific and actionable** — never vague like "Help me with something"
- **Cover different capabilities** — each starter should showcase a different aspect of the agent's domain
- Use **natural language** — write starters as users would actually speak
- Aim for 3-6 starters (fewer than 3 hides the agent's range; more than 6 clutters the UI)

Example for an HR policy agent:

```json
{
  "conversation_starters": [
    {
      "title": "Vacation Days",
      "text": "How many vacation days do I have left?"
    },
    {
      "title": "Remote Work Policy",
      "text": "What is the remote work policy?"
    },
    {
      "title": "Expense Reports",
      "text": "How do I submit an expense report?"
    }
  ]
}
```

## Project Naming Rules

- Use kebab-case: `hr-faq-agent`, `sales-assistant`
- 2-4 words max
- Descriptive and meaningful — never use defaults like "my-agent"

---

# EDIT WORKFLOW

Edit existing declarative agent manifests — capabilities, instructions, starters, and plugins.

> **Capability source discovery:** After completing this Edit workflow's workspace, scope, and read-before-write gates, consult `references/wiqd-core/editing-workflow.md` only for its **Capability Management → Finding IDs and URLs** guidance when source scoping or identifiers are needed. This workflow remains authoritative: do not update instructions, starters, or descriptions unless the user requested those changes.

> **Localization:** For localization tasks ("localize my agent", "translate my agent", "add a language"), the orchestrator handles this inline via the `agent-localize` reference. It provides a dedicated, phased localization experience with auto-tokenization and auto-translation.

## ⚠️ Scope Discipline — ONLY Change What Was Requested

**This is the #1 rule for editing. Violating it is a critical failure.**

- **ONLY make the specific changes the user requested.** Nothing more.
- **NEVER modify aspects of the agent that weren't mentioned in the request.**
- **If the user says "add web search capability", ONLY add web search** — do NOT rewrite instructions, rename the agent, restructure files, or add other capabilities.
- **If you believe other changes would improve the agent, SUGGEST them to the user** rather than making them unilaterally. Example: _"I've added web search. I also noticed your instructions don't mention web search — would you like me to update them?"_
- **Scope is literal.** "Add a conversation starter" means add ONE starter. "Update the description" means update ONLY the description. Do not interpret a narrow request as permission to make broad changes.

### Pre-Edit Scope Confirmation

Before making ANY changes, explicitly state:

1. **What you will change** — list each file and the specific modification (e.g., "Add `WebSearch` to `capabilities` array in `declarativeAgent.json`")
2. **What you will NOT change** — confirm that instructions, name, description, other capabilities, starters, and plugins will remain untouched (unless the user asked for those too)
3. **Proceed only when the scope is clear.** If the request is ambiguous, ask the user to clarify before editing.

### Post-Edit Verification

After making changes, verify scope compliance:

1. **Review every file you touched.** Confirm that ONLY the requested changes were applied.
2. **If you accidentally modified something the user didn't ask for, revert it immediately.**
3. **Report what was changed** — list the exact modifications made so the user can verify.

---

## ⛔ Edit Workspace Check — MANDATORY FIRST STEP

**Before doing ANYTHING in edit mode, check the workspace:**

1. Check for `appPackage/declarativeAgent.json`.
2. Apply the **Existing-Project Lifecycle Gate** above.
3. Check for non-agent indicators (`package.json` with express/react/next, etc.)

**Decision gate:**

| Condition | Action |
|-----------|--------|
| Non-agent project, no `appPackage/` | **Reject** — text-only response. No files, no commands. |
| `appPackage/` exists but no `declarativeAgent.json` | **Reject** — text-only. Explain declarativeAgent.json is missing, suggest creating a new agent. |
| Lifecycle file has non-canonical casing | **Reject** — text-only. Name the file and require renaming it to the canonical lowercase filename before editing or deploying. |
| No manifest (`m365agents.yml`), user wants to edit/deploy | **Reject** — text-only. Explain manifest is missing, suggest creating a new agent. |
| No manifest, user wants new project | Switch to **Create** workflow above. |
| Manifest exists with errors | **Detect → Inform → Ask.** Report the specific syntax errors. **Do NOT auto-fix.** Wait for the user's explicit confirmation before modifying the broken file. Do NOT deploy. |
| Valid project, user reports behavior issues | → [Instruction Review](../references/wiqd-core/instruction-review.md) |
| Valid agent project | Proceed with editing. |

### 🚫 HARD REJECTION RULES — No Exceptions

1. **NEVER create `declarativeAgent.json` yourself.** Use the Create workflow instead.
2. **NEVER create files in a non-agent project.**
3. **NEVER deploy when errors exist.**
4. **NEVER auto-fix malformed JSON in `declarativeAgent.json`, `manifest.json`, or `m365agents.yml` without first reporting the specific parse errors and getting explicit user confirmation.** When you detect malformed JSON/YAML in these files: stop, report the parse error and the location, suggest the user fix the syntax (or ask whether you should fix it), and wait. Do NOT proceed with any other edits in the same turn — even if the user asked for an unrelated change like a name update or a new conversation starter.
   - **This rule applies in ALL modes — including `--yolo`, non-interactive, agent, and CI modes.** Non-interactive does NOT mean "auto-fix anyway." It means "report the issue as your final answer for this turn and stop." The user is responsible for fixing structural file corruption; you are not.
   - **Do not rationalize an exception** because the user asked for an unrelated change, because no human can respond, or because fixing seems trivial. Report and stop. Period.

### 🔍 Detect → Inform → Ask (Error-Handling Protocol)

When you encounter ANY problem:
1. **Detect** — Identify the specific problem.
2. **Inform** — Tell the user BEFORE taking any action.
3. **Ask** — Wait for the user's response before making changes.

### 📖 Read Before Write — MANDATORY

Before editing ANY file, **always read its current content first**. Never write blindly.

**Required steps for every edit:**

1. **`view` the target file in full.** Do not rely on memory, glob output, or assumptions.
2. **Quote the existing content verbatim** in your reasoning before proposing the change. If you are touching a JSON array (e.g. `conversation_starters`, `capabilities`), copy the entire current array text into your reply before computing the new one.
3. **Compute the new content** by applying the user's request to what you actually saw — never to what you assume is there.
4. **Use precise `edit` ranges** (`old_str` must match the file byte-for-byte). If the file is ambiguous, prefer rewriting the whole array rather than a fragile partial match.
5. **Preserve everything the user did not ask to change** — order, formatting, indentation, trailing commas, and unrelated keys.

**Forbidden behaviors:**

- ❌ Saying "no conversation starters exist" without first viewing `appPackage/declarativeAgent.json`.
- ❌ "Removing" content the user asked you to remove without first confirming it is actually present.
- ❌ Replacing an entire file when the user asked for a targeted change.
- ❌ Inventing capability/starter content that wasn't in the original file.

This applies to all edits: instructions, conversation starters, capabilities, manifest fields.

### 🔗 Cross-File Consistency

Agent properties are spread across multiple files. When editing a property, update it **everywhere** it appears:

| Property | `declarativeAgent.json` | `manifest.json` | `instructions.txt` |
|----------|:-:|:-:|:-:|
| Agent name | ✅ `name` | ✅ `name.short`, `name.full` | — |
| Description | ✅ `description` | ✅ `description.short`, `description.full` | — |
| Developer info | — | ✅ `developer.*` | — |
| Instructions | ✅ `instructions` / `$[file()]` ref | — | ✅ content |
| Capabilities | ✅ `capabilities` | — | — |
| Conversation starters | ✅ `conversation_starters` | — | — |
| Actions/plugins | ✅ `actions` | — | — |

**Always check both `declarativeAgent.json` and `manifest.json`** when editing name, description, or metadata.

---

## Editing Capabilities

### Editing Worker Agents

When the user asks to add, connect, remove, or disconnect a Worker Agent, read and follow
[Worker-agent authoring](../references/worker-agents.md). Worker authoring is a skill-owned manifest
edit: use the resolver when available or require an author-supplied canonical ID, edit only
`worker_agents`, and validate the result. Do not invoke dedicated add/remove Worker CLI commands.

### Setting the default response mode

Treat a request to set the default response mode as a direct edit of
`appPackage/declarativeAgent.json`. A case-insensitive match of the complete requested mode phrase
is allowed, but persist only the exact canonical value `Auto`, `Quick response`, or `Think deeper`.
Do not map synonyms such as "fast" or "detailed" to a mode. If the request is unsupported or
ambiguous, list all three allowed values and stop without mutation or provision.

Before editing:

1. Read the complete manifest and verify that it parses. Malformed JSON is a hard stop and the file
   must remain byte-identical.
2. Require `version` and reconcile any declared `$schema` using
  [the live versioned schema procedure](../references/wiqd-core/schema.md). A `version`-only manifest
   is valid. A `$schema`-only manifest is invalid because the published DA schema requires
   `version`; stop when `version` is absent or when `$schema` identifies a different version.
3. Fetch the exact declared schema. Resolve root `properties.behavior_overrides`, including its
   `$ref`, then confirm `properties.default_response_mode` is a string and that its enum contains
   the requested canonical value. Do not inspect "latest" as a substitute. If lookup, parsing,
   reference resolution, property confirmation, or enum confirmation fails, stop without mutation.
4. If that exact schema does not support the property, explain that the author must upgrade the
   manifest schema/version to a version whose live schema does support it. Published v1.6-or-older
   manifests require this guidance and must not be upgraded automatically.

After confirmation, make one surgical edit: create `behavior_overrides` only when absent;
otherwise add or replace only `behavior_overrides.default_response_mode`. Preserve
`special_instructions`, `suggestions`, every other sibling, all unrelated content, key ordering,
indentation, and newline style. Re-read the manifest and verify the exact nested value and
preservation.

Run:

```bash
wiqd agent validate --path <project-directory> --json --skill wiqd --workflow wiqd-core
```

If validation fails, report the findings and do not provision. If validation succeeds, run
`wiqd agent provision --env local --path <project-directory> --json --skill wiqd --workflow wiqd-core`
unless the user explicitly opted out of provision or deployment. An opt-out suppresses provision
only; the valid edit and validation still happen. See
[Default response mode](../references/wiqd-core/editing-workflow.md#default-response-mode) for the canonical
shape and failure summary.

### Adding Capabilities

Capability addition is a small JSON edit to `appPackage/declarativeAgent.json` — there is
no `wiqd agent add capability` command. Edit the manifest directly (or use the agent-edit
workflow) to add a capability source.

Available capabilities (check schema version compatibility):
- `WebSearch` — Web search
- `GraphConnectors` — Microsoft Graph connectors
- `OneDriveAndSharePoint` — SharePoint/OneDrive knowledge
- `Email` — Email access (v1.3+)
- `People` — People data (v1.3+)
- `TeamsMessages` — Teams messages (v1.3+)
- `Dataverse` — Dataverse data (v1.3+)
- `Meetings` — Meeting data (v1.5+)

**Example — `OneDriveAndSharePoint`** (scopes the agent to specific SharePoint/OneDrive content):

```json
{
  "name": "OneDriveAndSharePoint",
  "items_by_url": [{ "url": "<sharepoint-url>" }]
}
```

Only `name` is required. Scope with `items_by_url` (each item is `{ "url": "<sharepoint-url>" }`) or, as the ID-based alternative, `items_by_sharepoint_ids` (each item identifies a SharePoint location by `site_id`, optionally `list_id`/`unique_id`). Omit both to grant access to all of the user's SharePoint and OneDrive content.

> **IMPORTANT — preserve the scaffolded `$schema`.** When adding a capability, edit only the `capabilities` array in `declarativeAgent.json`. Do NOT overwrite or downgrade the `$schema` version that the wiqd scaffold produced — keep the scaffolded schema URL exactly as generated.

### Adding API Plugins

> **"Plugin" here = an agent capability, not a standalone plugin.** This section adds an API/MCP **plugin capability into _this_ declarative agent** (`actions[]` / MCP inside one agent's manifest). If the user instead wants a **standalone, reusable plugin** as its own deliverable ("create a plugin", "a plugin with a skill", "package/publish my plugin"), **stop and read `workflows/plugin.md`** — that is the `wiqd plugin` construct, a different artifact with its own lifecycle.

```bash
# Always list ALL operations in a single call
wiqd agent add action \
  --openapi-spec <path-or-url> \
  --operations "GET /path,POST /path,PATCH /path/{id}" \
  [--api-key "<api-key>"] \
  [--openapi-auth-identity-provider <oauth|microsoft-entra>] \
  [--openapi-auth-client-id "<client-id>"] \
  [--openapi-auth-client-secret "<client-secret>"] \
  [--openapi-auth-scopes "<space-separated-scopes>"] \
  [--openapi-auth-pkce] \
  --folder <project-directory> \
  --json
```

**NEVER** manually create plugin files. **NEVER** run separate calls per operation.

Authentication is discovered from the selected OpenAPI operations. Supply the credentials required by those operations during add, or populate the generated variables afterward in `env/.env.<environment>.user` (for example, `env/.env.local.user`). Omitting values does not block add, but filling required values is part of the editing flow and must be completed before validation or provisioning. wiqd handles authentication applicability checks and generated lifecycle wiring.

### Adding MCP Plugins

Use the wiqd action command for remote MCP servers. Ask for the server URL and authentication
requirements, then select the matching command options:

```bash
wiqd agent add action \
  --mcp-server-url "<https-url>" \
  --mcp-auth-type <none|oauth|oauth-dynamic|entra-sso|bearer-token> \
  [--mcp-client-id "<client-id>"] \
  [--mcp-client-secret "<client-secret>"] \
  [--mcp-scopes "<space-separated-scopes>"] \
  [--api-key "<bearer-token>"] \
  --folder <project-directory> \
  --json
```

- `none` creates an unauthenticated runtime and takes no credential flags.
- `oauth` is static OAuth 2.0: requires a client ID and client secret; scopes are optional.
- `oauth-dynamic` is OAuth 2.0 dynamic client registration: wiqd discovers authorization
  metadata and injects the DCR lifecycle action. It takes no credential flags.
- `entra-sso` configures Microsoft Entra SSO: requires a client ID; client secret and scopes
  do not apply.
- `bearer-token` requires a bearer value, supplied through `--api-key` or the generated environment variable.

For `oauth`, `entra-sso`, and `bearer-token`, supply required values during add or populate the generated variables afterward in `env/.env.<environment>.user`. Add can succeed with empty placeholders; this does not make the credentials optional. Filling required values is part of the editing flow: before moving to validation or provisioning, ensure they are populated for the target environment. Provisioning fails if required values remain unresolved. Do not copy credentials into manifests, output, diagnostics, or telemetry.

OAuth and Entra modes use `OAuthPluginVault`; bearer-token mode uses its generated bearer auth
configuration. Preserve the authentication references generated for the selected mode.

The URL MUST use HTTPS and MUST NOT contain embedded credentials. The command creates and
registers a `RemoteMCPServer` action using dynamic tool discovery. OAuth modes may contact the MCP
server to discover authorization metadata. If metadata discovery or lifecycle/environment updates
cannot be completed, the command reports warnings; inspect them before continuing.

Run this command before advanced customization; it owns plugin creation, registration, runtime, and
auth wiring. Use [MCP Plugin](../references/wiqd-core/mcp-plugin.md) only for pinned tools, response
semantics, or widget metadata.

**Critical invariants when augmenting generated MCP plugins:**

1. Edit the generated plugin; do not create a duplicate.
2. Keep dynamic discovery (`functions: []`, no `mcp_tool_description`,
  `run_for_functions: ["*"]`) unless the user asks to pin tools.
3. When pinning, copy only the selected tool objects verbatim into
  `mcp_tool_description.tools[]` and use matching `functions` and `run_for_functions` names.
4. Preserve the generated action registration, runtime URL, and auth wiring.

### Adding Authentication

```bash
wiqd agent add auth \
  --plugin-manifest <plugin-manifest> \
  --openapi-spec <openapi-spec> \
  --operations <operation-id[,operation-id...]> \
  --auth-name <name> \
  --auth-type <bearer-token|api-key|oauth|microsoft-entra> \
  [--api-key "<api-key-or-bearer-token>"] \
  [--oauth-client-id "<client-id>"] \
  [--oauth-client-secret "<client-secret>"] \
  [--oauth-pkce] \
  --folder <project-directory> \
  --json
```

Supply the credentials required by the selected authentication mode during add, or populate the generated variables afterward in `env/.env.<environment>.user`. Add succeeds when values are omitted, but completing those required values is part of the editing flow before validation or provisioning. Not every mode requires a client secret. wiqd handles lifecycle generation, applicability checks, and provision-time missing-value errors. The caller must not display secrets. See [Authentication](../references/wiqd-core/authentication.md) for credential setup and troubleshooting.

### Adding Agent Skills

Agent skills are embedded under `appPackage/skills/`; they are not standalone `wiqd plugin`
skills. For a new agent with a skill, run `wiqd agent create` first, then the command below. For a
new skill, ask for its name and description. For an import, use a directory already under the target
`appPackage` or an external ZIP; package an external directory as a ZIP first.
Use exactly one of `--name` or `--from`:

```bash
wiqd agent add skill \
  --name "<skill-name>" \
  --description "<skill-description>" \
  --folder <project-directory> \
  --json

wiqd agent add skill \
  --from <appPackage-skill-directory-or-external-zip> \
  --folder <project-directory> \
  --json
```

`--skill wiqd` is telemetry attribution for the invoking wiqd workflow; it does not add an agent
skill. Use the `agent add skill` subcommand above.

Do not manually create or register the skill; the command owns those changes. For a new skill, keep
the generated frontmatter and replace the placeholder comments with the user's actual skill
instructions. Verify `appPackage/skills/<skill-name>/SKILL.md` and the matching
`appPackage/declarativeAgent.json#agent_skills[]` entry.

Then run `wiqd agent validate --path <project-directory> --json`. Static validation currently
checks only `declarativeAgent.json`, not the referenced `SKILL.md` or top-level `agentSkills[]`, and
may report the preview `agent_skills` property as unrecognized even when the add command succeeded.
Do not provision unless asked.

---

## Advanced Static MCP Authoring

Use this section only for MCP requirements the command does not cover: static or selected
tool descriptions or package-authored response semantics or widget metadata. Start by running
`wiqd agent add action --mcp-server-url` above, then edit only the generated plugin fields needed for
those requirements. Preserve its action registration, runtime URL, supported auth, and OAuth
lifecycle/environment wiring.

MCP (Model Context Protocol) servers expose tools that your agent can consume. Unlike OpenAPI
plugins, a generated MCP plugin can be augmented with static tool descriptions directly in its
`RemoteMCPServer` runtime.

> **Full reference:** See [mcp-plugin.md](../references/wiqd-core/mcp-plugin.md) for the comprehensive step-by-step guide, including logo handling, response semantics, and complete examples.

### MCP Protocol Handshake

Tool discovery uses three sequential HTTP calls to the MCP server:

1. **Initialize** — `POST` to server URL with `method: "initialize"`, receive server capabilities. Extract `mcp-session-id` from response headers.
2. **Notifications/initialized** — `POST` with `method: "notifications/initialized"` and the session ID header.
3. **Tools/list** — `POST` with `method: "tools/list"` to discover all available tools. If the response contains `nextCursor`, paginate until all tools are collected.

### MCP Authentication Paths

| Path | `--mcp-auth-type` | Credential requirements | Generated behavior |
|------|-------------------|-------------------------|--------------------|
| **No auth** | `none` | None | `None` runtime auth; no auth lifecycle action |
| **Static OAuth 2.0** | `oauth` | Client ID and client secret; optional scopes | `OAuthPluginVault`; probes metadata, injects OAuth lifecycle, and creates placeholders for omissions |
| **Dynamic OAuth 2.0** | `oauth-dynamic` | None | `OAuthPluginVault`; discovers metadata and injects dynamic client registration |
| **Microsoft Entra SSO** | `entra-sso` | Client ID only | `OAuthPluginVault`; injects Entra SSO OAuth lifecycle and creates a placeholder when omitted |
| **Bearer token** | `bearer-token` | Bearer value | Bearer runtime auth with an environment-backed placeholder when omitted |

Supply required values through the supported flags during add or fill the generated variables in `env/.env.<environment>.user` afterward. Complete this as part of editing, before validation or provisioning; successful add alone does not mean authentication setup is complete.

Metadata discovery may use the authorization-server or OpenID Connect well-known endpoints. Review
command warnings: wiqd may use placeholders when metadata is incomplete, and lifecycle or
environment persistence can also complete with warnings.

### Plugin Manifest Structure

Open the plugin manifest generated in `appPackage` and preserve its schema, identity, namespace,
runtime URL, auth, and action registration. Add only the static functions, response semantics, tool
descriptions, and selected `run_for_functions` values required by the project. The example below
shows the resulting shape:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v<x.y>/schema.json",
  "schema_version": "v<x.y>",
  "name_for_human": "Display Name",
  "description_for_human": "Brief description",
  "namespace": "simplename",
  "functions": [
    {
      "name": "tool_name",
      "description": "Full tool description from tools/list",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [{ "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }]
          }
        }
      }
    }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "None" },
      "spec": {
        "url": "https://server-url/sse",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "tool_name",
              "description": "Full description",
              "inputSchema": { "type": "object", "properties": {}, "required": [] }
            }
          ]
        }
      },
      "run_for_functions": ["tool_name"]
    }
  ]
}
```

### Tool Annotations and Widget Metadata

MCP servers may return additional metadata on tools that MUST be preserved verbatim:

- **`annotations`** — hints about tool behavior:
  - `readOnlyHint: true` — tool only reads data, no side effects
  - `destructiveHint: true` — tool performs destructive operations (e.g., DROP TABLE)
  - `openWorldHint: true` — tool interacts with external systems
- **`_meta.ui`** — widget metadata for rich UI rendering:
  - `outputTemplate` — template for rendering interactive charts/tables
  - `widgetAccessible` — accessibility metadata for screen readers

Copy each tool object from `tools/list` **verbatim** into `mcp_tool_description.tools[]` — do NOT strip any properties.

### Verify Plugin Registration in Agent Manifest

Verify that the generated reference in `declarativeAgent.json` still points to the augmented plugin;
do not add a duplicate action:

```json
{
  "actions": [
    {
      "id": "mcpPlugin",
      "file": "{name}-plugin.json"
    }
  ]
}
```

### MCP + Other Capabilities

MCP plugins can be combined with built-in capabilities in the same agent:
- **OneDriveAndSharePoint** — add `items_by_url` (array of `{ "url": "<sharepoint-url>" }`) for document access, or `items_by_sharepoint_ids` (each item identifies a SharePoint location by `site_id`, optionally `list_id`/`unique_id`) to scope by SharePoint IDs
- **WebSearch** — add `sites` array to restrict search domains

Add both MCP actions and capabilities to `declarativeAgent.json` as needed.

---

## Critical Rules

### 1. Provisioning After Edits

**After adding or modifying plugins or capabilities**, report success and
note that provisioning is needed to deploy the changes:

```
✅ Agent updated — capability/plugin added successfully!

📦 The agent needs to be provisioned to deploy this change.
   The orchestrator will chain provisioning automatically.
```

**After editing instructions, starters, or metadata only**, do NOT
auto-provision. Simply report success:

```
✅ Agent updated successfully!

💡 When you're ready to deploy, provision the agent using `references/wiqd-core/provision.md`.
```

Default-response-mode edits are the exception: after successful validation, provision by default
unless the user explicitly opts out of provision or deployment. For every other edit type, only
provision if the user explicitly asks to deploy or provision. Route test or evaluate requests
through `workflows/eval/eval.md`; test intent alone does not authorize provisioning.

### 2. Never Invent Content

- Do NOT invent placeholder names, descriptions, or instructions
- Do NOT create files that don't exist — report gaps, ASK the user
- **⛔ NEVER set placeholder values for environment variables** — leave them empty

### 3. Schema Version Compatibility

Before adding ANY feature, check the `version` field in `declarativeAgent.json`:

- `sensitivity_label`, `worker_agents`, `EmbeddedKnowledge` → **v1.6+**
- `Meetings` → **v1.5+**
- `ScenarioModels`, `behavior_overrides`, `disclaimer` → **v1.4+**
- `Dataverse`, `TeamsMessages`, `Email`, `People` → **v1.3+**

### 4. Suggest (Don't Auto-Apply) Instruction & Starter Updates

After adding a capability or plugin, **suggest** that the user may also want to update instructions or starters — but **do NOT make those changes unless the user explicitly asked for them.** This respects the Scope Discipline rule above.

### 5. App Name Requirement

Always update the app name and description to something meaningful. Never leave defaults.

## Safety Rules

- **NEVER** create `declarativeAgent.json` manually — always use `wiqd agent create`
- **NEVER** scaffold into a non-empty directory with existing project files
- **NEVER** use placeholder names — always ask the user for a meaningful name
- **NEVER** embed instructions inline in `declarativeAgent.json` — always use `$[file('instructions.txt')]`
- **NEVER** downgrade `declarativeAgent.json` below the schema version the CLI scaffolded
- **NEVER** scaffold a project without at least 3 conversation starters in `declarativeAgent.json`
- **NEVER** skip the wiqd enforcer drop — it is what keeps future edits routed correctly

## 💡 Next Steps

> **Convention:** All suggested next moves presented to the user MUST be natural-language prompts (_"validate my agent"_, _"share with my team"_), never raw `wiqd` CLI commands. The user is interacting through an agent conversation, not the CLI. Procedural workflow steps that the orchestrator _executes_ on behalf of the user keep their CLI syntax — only user-facing suggestions are rewritten.

After building your agent, you may want to:
- **Validate your changes** → _"validate my agent"_ (read `references/wiqd-core/validate.md`)
- **Provision to test** → _"provision my agent"_ (read `references/wiqd-core/provision.md`)
- **Localize your agent** → _"localize my agent"_ (read `references/wiqd-core/localize.md`)
- **Evaluate your agent** → _"run my evals"_ (delegated to `workflows/eval.md`)

## References

### Creating
- **[Scaffolding Workflow](../references/wiqd-core/scaffolding-workflow.md)** — Detailed scaffolding steps

### Editing
- **[Editing Workflow](../references/wiqd-core/editing-workflow.md)** — Step-by-step JSON development
- **[Schema](../references/wiqd-core/schema.md)** — Official JSON schema and version compatibility

### Plugins
- **[API Plugins](../references/wiqd-core/api-plugins.md)** — OpenAPI integration
- **[MCP Plugin](../references/wiqd-core/mcp-plugin.md)** — MCP server integration
- **[Adaptive Cards](../references/wiqd-core/adaptive-cards.md)** — response_semantics and AdaptiveCard templates

### Instructions
- **[Conversation Design](../references/wiqd-core/conversation-design.md)** — Authoring instructions and starters
- **[Instruction Review](../references/wiqd-core/instruction-review.md)** — Auditing and improving instructions

### Authentication
- **[Authentication](../references/wiqd-core/authentication.md)** — OAuth configuration

### Lifecycle
- **[Agent Show](../references/wiqd-core/show.md)** — View agent details
- **[Agent Lifecycle](../references/wiqd-core/lifecycle.md)** — Delete, open, env management
- **[Agent Provision](../references/wiqd-core/provision.md)** — Deploy to M365
- **[Agent Package](../references/wiqd-core/package.md)** — Build app package
- **[Agent Share](../references/wiqd-core/share.md)** — Share with users
- **[Agent Migrate](../references/wiqd-core/migrate.md)** — Convert TTK packages
- **[Agent Localize](../references/wiqd-core/localize.md)** — Multi-language support

### Other
- **[Best Practices](../references/wiqd-core/best-practices.md)** — Security, performance, testing
