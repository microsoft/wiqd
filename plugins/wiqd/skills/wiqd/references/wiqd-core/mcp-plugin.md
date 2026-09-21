# MCP Server Plugin Integration

Use this guide to add pinned tools, response semantics, or widget metadata to a generated MCP action.

> **Dynamic discovery is the default.** The generated runtime omits `mcp_tool_description`, keeps
> `functions` empty, and uses `run_for_functions: ["*"]`. Add inline
> `mcp_tool_description.tools[]` only when pinning selected tools. Do not create a separate
> `{name}-mcp-tools.json` file.

> **Version placeholder.** In the manifests below, `v<x.y>` stands for the current published plugin manifest version — do not copy it literally. Read it from an existing manifest's `$schema`/`schema_version`, or discover the current version per [schema.md](schema.md) ("Discovering the current published version").

> **Start with the command.** Run `wiqd agent add action --mcp-server-url <https-url>` with the
> required auth mode. Edit its generated plugin only for the advanced cases covered here.

### Authentication mode selection

The command accepts exactly five MCP auth modes:

| Mode | Meaning | Credential requirements |
|------|---------|--------|
| `none` | Unauthenticated MCP server | No credential flags |
| `oauth` | Static OAuth 2.0 client | Client ID and Secret; optional scopes |
| `oauth-dynamic` | OAuth 2.0 dynamic client registration | No credential flags; metadata is discovered |
| `entra-sso` | Microsoft Entra SSO | Client ID only |
| `bearer-token` | Static bearer authentication | API Key value |

OAuth and Entra modes use `OAuthPluginVault`; bearer-token mode uses its generated bearer auth
configuration. Preserve the authentication references generated for the selected mode.
Do not infer the selected mode from the manifest auth type alone.

For modes with static credentials, supply the required values through the supported flags during `wiqd agent add action`, or populate the generated variables afterward in `env/.env.<environment>.user` (for example, `env/.env.local.user`). The command accepts omitted values and creates environment-backed placeholders; the credentials themselves remain required. Completing these values is part of editing, before validation or provisioning. Provisioning fails if required values remain unresolved.

## Prerequisites

- MCP server URL (must be accessible via HTTP/HTTPS)
- Node.js installed (for `mcp-remote` authentication helper)
- Logo images for the agent (color.png 192×192 and outline.png 32×32) — optional, see [Step 5: Logo Images](#step-5-logo-images-optional)

---

## Scaffold the Agent Project First

Before adding an MCP plugin, you **must** have a scaffolded agent project — _"create an agent"_ if you haven't already:

```bash
wiqd agent create \
  -n my-agent \
  -c declarative-agent \
  -i false
```

This creates `m365agents.yml` (and `m365agents.local.yml`) with the **5 required lifecycle steps**:

| Step | Lifecycle Action              | What it does                                                    |
| ---- | ----------------------------- | --------------------------------------------------------------- |
| 1    | `teamsApp/create`             | Registers the Teams app                                         |
| 2    | `teamsApp/zipAppPackage`      | Packages manifest + icons into a zip                            |
| 3    | `teamsApp/validateAppPackage` | Validates the package (icons, schema, etc.)                     |
| 4    | `teamsApp/update`             | Uploads the package to Teams                                    |
| 5    | `teamsApp/extendToM365`       | **Extends the app to M365 Copilot** — generates `M365_TITLE_ID` |

**What breaks without `extendToM365`:** If this step is missing, `wiqd agent provision` will register the Teams app and generate `TEAMS_APP_ID`, but the agent will **never appear in Copilot Chat** because no `M365_TITLE_ID` is generated. This is the most common reason for "provision succeeded but agent not found" failures.

> **If you already have a project** but are missing `teamsApp/extendToM365`, add it to the `provision` lifecycle in `m365agents.yml` after `teamsApp/update`. See [deployment.md](deployment.md) for the full provisioning reference.

---

## Step-by-Step Integration

### Step 1: Get MCP Server URL

Ask the user for the MCP server URL. Example: `https://learn.microsoft.com/api/mcp`

Derive the **server root** (scheme + host only): e.g., `https://learn.microsoft.com`

### Step 2: Add the MCP Action

Run the command with the selected authentication mode. Supply its required credentials now, or fill the generated environment variables afterward:

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

If credentials are omitted during add, fill the generated variables in `env/.env.<environment>.user` as part of editing, before validation or provisioning.
Review metadata-discovery, lifecycle/environment, and missing-placeholder warnings before
continuing.

### Step 3: Discover MCP Tools When Pinning

Skip this step unless you are pinning tools from an authenticated server. The add-action command
already configures deployment auth; this step only obtains a token for `tools/list`.

**Probe both well-known endpoints in parallel:**

```bash
curl -s <SERVER_ROOT>/.well-known/oauth-authorization-server
curl -s <SERVER_ROOT>/.well-known/openid-configuration
```

**Decision:**

- **OAuth metadata found** → authenticate in Step 3a before discovery.
- **No OAuth metadata** → preserve the intended auth mode and obtain the required configuration
  before authenticated tool discovery. Missing metadata does not establish unauthenticated access.

> **If the discovered authority is Entra** (`login.microsoftonline.com` — typical for `*.azure.com` / Microsoft-hosted MCP servers), do **not** attempt Dynamic Client Registration: Entra publishes no `registration_endpoint` and has no `/.well-known/oauth-authorization-server` at all. The user must hand-register an Entra app to supply a `clientId`, and may additionally hit an admin-consent wall that provision does not detect. Tell them up front — see [authentication.md → Entra does not support DCR](authentication.md#entra-does-not-support-dcr) and [Platform constraints](authentication.md#platform-constraints-read-before-estimating).

Skip this step for dynamic discovery. Perform the handshake only when the user asks to pin a selected
set of tools or when package-authored response semantics or widget metadata require static function
entries.

You MUST discover tools via the MCP protocol directly. Tool discovery uses HTTP POST requests to the MCP server URL.

#### 3a. Authenticate (OAuth servers only)

If the server requires OAuth (detected in Step 3), perform a one-time authentication:

Tell the user:

> "I need to authenticate with [name]'s MCP server. A browser window will open — please sign in."

Run the command **interactively** (NOT backgrounded — do NOT append `&` or redirect to files):

```bash
npx -p mcp-remote@latest mcp-remote-client <MCP_SERVER_URL> --port 3334
```

Wait for it to complete. The command will open a browser for OAuth sign-in and then exit once authentication succeeds.

> **WSL / headless environments:** `mcp-remote` starts a local HTTP server for the OAuth callback and tries to open a browser. In WSL, the browser opens on the Windows host but the `http://127.0.0.1:3334/...` callback URL may not route back to WSL. If the browser opens but authentication seems stuck:
>
> 1. After signing in, copy the full callback URL from the browser (it will show an error or blank page)
> 2. Run `curl '<callback-url>'` inside WSL to deliver the auth code to mcp-remote
> 3. Alternatively, run `export BROWSER=wslview` before the command so WSL's browser opener is used, which handles the redirect correctly

**⛔ IMPORTANT:** Do NOT look for tokens in `/tmp/` or log files. Tokens are ONLY stored at `~/.mcp-auth/`.

**Read the cached access token from `~/.mcp-auth`:**

```bash
ls ~/.mcp-auth/mcp-remote-*/
```

Find the token file (pattern: `{url-hash}_tokens.json`), read it, and extract `access_token`.

**⛔ Security:** Do NOT print the token value in your output. Extract it silently and use it only in subsequent HTTP calls. Do NOT write it to any file or create copies.

#### 3b. MCP Session Handshake

Run three sequential HTTP calls to discover tools.

**⛔ Security:** Suppress raw HTTP responses that may contain tokens. Only extract the fields you need (`mcp-session-id`, tool definitions). Do NOT display Authorization headers or token values to the user.

**Call 1 — Initialize:**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  [-H "Authorization: Bearer <access_token>"] \
  -D - \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"m365-agent-skill","version":"1.0.0"}}}'
```

Extract `mcp-session-id` from the response headers. Omit the `Authorization` header for unauthenticated servers.

**Call 2 — Initialized notification:**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: <session_id>" \
  [-H "Authorization: Bearer <access_token>"] \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
```

**Call 3 — List tools (with pagination):**

```bash
curl -s -X POST <MCP_SERVER_URL> \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: <session_id>" \
  [-H "Authorization: Bearer <access_token>"] \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

If the response contains `nextCursor`, repeat with `{"params":{"cursor":"<nextCursor>"}}` until no cursor remains. Collect all tools.

**Extracting tools from the response:**

Save the raw tools/list response to a file, then use this script to extract the tools array:

```bash
python3 << 'EXTRACT_TOOLS'
import json, sys

with open("/tmp/mcp-tools-response.json") as f:
    data = json.load(f)

tools = data.get("result", {}).get("tools", [])
with open("/tmp/mcp-tools.json", "w") as out:
    json.dump(tools, out, indent=2)

print(f"Extracted {len(tools)} tools")
for t in tools:
    print(f"  - {t['name']}: {t.get('description', '')[:80]}")
EXTRACT_TOOLS
```

> **⛔ Do NOT use inline Python inside command substitutions** (e.g., `$(python3 -c '...')`). The shell security policy blocks nested command substitutions. Always use heredoc scripts (`<< 'EOF'`) or standalone `.py` files instead.

**Expected output structure:**

```json
{
  "result": {
    "tools": [
      {
        "name": "tool_name",
        "description": "Tool description",
        "inputSchema": {
          "type": "object",
          "properties": { ... },
          "required": [...]
        },
        "annotations": {
          "readOnlyHint": true
        },
        "execution": {
          "taskSupport": "forbidden"
        },
        "_meta": {
          "ui": {
            "resourceUri": "ui://namespace/view-name.html"
          }
        }
      }
    ]
  }
}
```

#### 3c. Select the Tools to Pin

Pin only the tools the user requested. If the user asks to pin every available tool, include all tools
returned by `tools/list`.

Copy each selected tool object verbatim into `mcp_tool_description.tools[]`; do not filter its
properties.

Tell the user how many tools were discovered and which tools will be pinned.

### Step 4: Open the Generated Plugin Manifest

Open the plugin manifest generated by `wiqd agent add action`. Preserve its schema, identity,
namespace, runtime URL, auth, and agent registration. The abbreviated shape below identifies the
fields augmented by the remaining steps; do not replace the generated manifest with it:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v<x.y>/schema.json",
  "schema_version": "v<x.y>",
  "name_for_human": "{NAME-FOR-HUMAN}",
  "description_for_human": "{DESCRIPTION-FOR-HUMAN}",
  "namespace": "simplename",
  "functions": [],
  "runtimes": []
}
```

**Required fields:**
| Field | Description |
|-------|-------------|
| `name_for_human` | Display name shown to users (max 20 characters) |
| `description_for_human` | Brief description of the plugin (max 100 characters) |
| `namespace` | Unique identifier, lowercase alphanumeric only (no hyphens, no underscores) |

### Step 4a: Add Functions for Pinned Tools

For each tool selected in Step 3, add a function entry with `name`, `description`, and `capabilities`
only. Do **NOT** duplicate `parameters`/`inputSchema` in the function — all pinned tool schema data
lives exclusively in `mcp_tool_description.tools[]` (see Step 6).

```json
{
  "functions": [
    {
      "name": "microsoft_docs_search",
      "description": "Search official Microsoft/Azure documentation to find the most relevant content for a user's query."
    }
  ]
}
```

**🚨 CRITICAL: Preserve ALL tool properties when creating function entries:**

| MCP tools/list Output                                                                                      | Plugin Manifest (`functions[]`)                                                   |
| ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `name`                                                                                                     | `name` — copy EXACTLY, do not rename                                              |
| `description`                                                                                              | `description` — use the **full** description text, do NOT abbreviate or summarize |
| `inputSchema`                                                                                              | Do NOT add to `functions[]` — this goes in `mcp_tool_description.tools[]` only    |
| **Any other property** (`annotations`, `execution`, `_meta`, `outputSchema`, `title`, or any future field) | Do NOT add to `functions[]` — this goes in `mcp_tool_description.tools[]` only    |

Keep only `name` and `description` in `functions[]`; the complete tool object belongs in
`mcp_tool_description.tools[]`.

### Step 4b: Add Response Semantics

**ALWAYS** add `capabilities.response_semantics` to every function — even if no title or URL fields can be identified. Never omit it.

For each tool:

1. Check the tool's `outputSchema` field (optional in MCP — present on some servers). If present, read field names from it directly.
2. If `outputSchema` is absent (common), reason from the tool's `description` text to identify which fields are returned. Look for mentions of URL fields (`url`, `link`, `href`) and title fields (`title`, `name`, `label`).
3. If you can confidently identify BOTH a title-like field AND a navigable URL field → use the **rich pattern**.
4. Otherwise → use the **default pattern**.

**Rich pattern** (when title + URL field are identified):

```json
{
  "name": "tool_name",
  "description": "...",
  "capabilities": {
    "response_semantics": {
      "data_path": "$.items",
      "properties": {
        "title": "$.title",
        "url": "$.url"
      },
      "static_template": {
        "type": "AdaptiveCard",
        "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6",
        "body": [
          {
            "type": "TextBlock",
            "text": "[${title}](${url})",
            "wrap": true,
            "maxLines": 2
          }
        ]
      }
    }
  }
}
```

**Default pattern** (when title or URL cannot be confidently identified):

```json
{
  "name": "tool_name",
  "description": "...",
  "capabilities": {
    "response_semantics": {
      "data_path": "$",
      "properties": {},
      "static_template": {
        "type": "AdaptiveCard",
        "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6",
        "body": [
          {
            "type": "TextBlock",
            "text": "${if(title, title, description)}",
            "wrap": true
          }
        ]
      }
    }
  }
}
```

**Response semantics rules:**

- `$schema`: always `https://adaptivecards.io/schemas/adaptive-card.json` (not `http://`)
- `version`: always `"1.6"`
- Rich template body is always `"[${title}](${url})"` — the title IS the hyperlink
- Source name comes from `name_for_human` automatically — do NOT add it as a TextBlock
- `data_path` and field paths are connector-specific — derive them from the tool's actual response structure

### Step 5: Logo Images (Optional)

Logos are **not mandatory**. The default logos from `wiqd agent create` work fine. Ask the user casually:

> "Would you like to use a custom logo for [name], or is the default fine?"

If the user **does not** have a logo or says to skip → **move on**. Do NOT block the workflow for logos.

If the user **does** want a custom logo, they need two **PNG** files (no JPG, SVG, or other formats):

- **`color.png`** — 192×192 px, full colour
- **`outline.png`** — 32×32 px, white-on-transparent

**Resolving logo inputs — check in this order:**

1. **URL**: If the user provides a URL, download the image with `curl -L -o <tempfile> <url>`.
2. **Local file path**: If the user provides a path, use it directly.

**If the provided image is not PNG, convert it to PNG before processing.**

**Handling missing formats:**

- If the user provides only one image, ask: "I have your [color/outline] logo. For the [other format], would you like to provide it, or shall I generate it automatically?"
- If the user says to generate it, derive it from the provided image using jimp.
- If the user says the provided images already meet the size requirements, skip processing and use them directly.

**Processing with jimp** (only when resizing or conversion is needed):

```javascript
// Install: npm install jimp (in a temp directory)
// Import: const { Jimp } = require('jimp');

// color.png: resize to 192x192
// outline.png: resize to 32x32, convert all non-transparent pixels to white on transparent background
```

Output files: `appPackage/color.png` (192×192) and `appPackage/outline.png` (32×32 white-on-transparent).

Show the resulting icon(s) to the user for approval before proceeding. If the user rejects, ask them to provide their own images and do NOT proceed until approved.

### Step 6: Configure the Runtime for Pinned Tools

Preserve the generated `RemoteMCPServer` runtime and add the selected tools inline in
`mcp_tool_description.tools`. Replace `run_for_functions: ["*"]` with the pinned function names:

**For OAuth-authenticated servers** (see [Authentication](authentication.md)):

```json
{
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": {
        "type": "OAuthPluginVault",
        "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}"
      },
      "spec": {
        "url": "{MCP_SERVER_URL}",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "function_name_1",
              "description": "Full tool description from tools/list output",
              "inputSchema": {
                "type": "object",
                "properties": { "...": "..." },
                "required": ["..."]
              },
              "annotations": { "readOnlyHint": true },
              "execution": { "taskSupport": "forbidden" },
              "_meta": { "ui": { "resourceUri": "ui://namespace/view.html" } }
            }
          ]
        }
      },
      "run_for_functions": ["function_name_1", "function_name_2"]
    }
  ]
}
```

**For unauthenticated servers:**

```json
{
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": {
        "type": "None"
      },
      "spec": {
        "url": "{MCP_SERVER_URL}",
        "mcp_tool_description": {
          "tools": [ ... ]
        }
      },
      "run_for_functions": [ ... ]
    }
  ]
}
```

> **⚠️ IMPORTANT:**
>
> - Inline each selected tool object exactly as returned by `tools/list`; do not use a file reference.
> - Do NOT fabricate properties that the server did not return. Only include what tools/list actually gives you.
> - For authenticated servers, verify the authentication steps generated by `wiqd agent add action` in both `m365agents.yml` and `m365agents.local.yml`. Keep the steps for your selected auth mode; do not add a duplicate `oauth/register` step. See [Authentication](authentication.md) for credential setup and registration troubleshooting.

### Step 7: Verify Plugin Registration in Agent Manifest

The command already adds the plugin to `declarativeAgent.json`. Verify that the generated reference
still points to the plugin you augmented; do not add a duplicate action:

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

---

## Complete Workflow Checklist

```
□ Step 0: Scaffold agent project with `wiqd agent create` (if not already scaffolded)      ← MANDATORY
□ Step 1: Get MCP server URL from user
□ Step 2: Run `wiqd agent add action --mcp-server-url` with the selected auth mode           ← MANDATORY
□       → Supply required credentials during add or defer entry to the generated environment user file
□       → Review warnings from metadata discovery and lifecycle/environment updates
□ Step 3: If pinning was requested, discover tools via MCP protocol (initialize → tools/list)
□       → Copy only the selected tools, preserving every property verbatim
□ Step 4: For pinned tools, add matching functions + response_semantics
□ Step 5: Ask user about custom logo (optional — skip if user declines)
□ Step 6: For pinned tools, add inline tool descriptions and replace `run_for_functions: ["*"]`
□ Step 7: Verify the generated action registration in declarativeAgent.json
□       → Complete authentication setup: fill any required credential values deferred during add in env/.env.<environment>.user before validation or provisioning
□ Step 8: Run wiqd agent provision --env local
```

---

## Complete Example — Unauthenticated Server

For the Zava Insurance MCP server at `https://zava-insurance-mcp.azurewebsites.net/mcp`:

### `appPackage/zava-plugin.json`

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v<x.y>/schema.json",
  "schema_version": "v<x.y>",
  "name_for_human": "Zava Insurance",
  "description_for_human": "Manage insurance claims, inspections, contractors, and purchase orders",
  "namespace": "zavainsurance",
  "functions": [
    {
      "name": "show-claims-dashboard",
      "description": "Displays the Zava Insurance claims dashboard showing all claims with status overview, filters, and summary metrics. Supports filtering by status and/or policy holder name. When the user mentions a person's name, first name, last name, or partial name, always pass it as the policyHolderName parameter. The name filter is case-insensitive and supports partial matches.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "show-claim-detail",
      "description": "Displays detailed information about a specific insurance claim including related inspections, purchase orders, and contractor assignments. Use claim ID (e.g. '1', '2') or claim number (e.g. 'CN202504990').",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "show-contractors",
      "description": "Displays the list of contractors available for insurance repair work. Optionally filter by specialty or preferred status.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "update-claim-status",
      "description": "Updates the status of an insurance claim. Use claim ID (e.g. '1', '2').",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "update-inspection",
      "description": "Updates an inspection record — status, findings, recommended actions, property, or inspector assignment.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "update-purchase-order",
      "description": "Updates a purchase order status (e.g. approve, reject, complete).",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "get-claim-summary",
      "description": "Returns a text summary for a specific claim with key details. Use claim ID or claim number.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "create-inspection",
      "description": "Creates a new inspection record. Only claimNumber is required. ID is auto-generated, status defaults to 'open'. claimId is optional.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "list-inspectors",
      "description": "Lists all available inspectors with their specializations.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
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
        "url": "https://zava-insurance-mcp.azurewebsites.net/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "show-claims-dashboard",
              "description": "Displays the Zava Insurance claims dashboard showing all claims with status overview, filters, and summary metrics. Supports filtering by status and/or policy holder name. When the user mentions a person's name, first name, last name, or partial name, always pass it as the policyHolderName parameter. The name filter is case-insensitive and supports partial matches.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "status": {
                    "type": "string",
                    "description": "Filter claims by status keyword (e.g. 'Open', 'Approved', 'Pending', 'Denied', 'Closed')"
                  },
                  "policyHolderName": {
                    "type": "string",
                    "description": "Filter claims by policy holder name. Supports partial, case-insensitive matching."
                  }
                },
                "additionalProperties": false
              },
              "annotations": { "readOnlyHint": true },
              "execution": { "taskSupport": "forbidden" },
              "_meta": { "ui": { "resourceUri": "ui://zava/claims-dashboard.html" } }
            },
            {
              "name": "show-claim-detail",
              "description": "Displays detailed information about a specific insurance claim including related inspections, purchase orders, and contractor assignments. Use claim ID (e.g. '1', '2') or claim number (e.g. 'CN202504990').",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "claimId": {
                    "type": "string",
                    "description": "The claim ID or claim number to look up"
                  }
                },
                "required": ["claimId"],
                "additionalProperties": false
              },
              "annotations": { "readOnlyHint": true },
              "execution": { "taskSupport": "forbidden" },
              "_meta": { "ui": { "resourceUri": "ui://zava/claim-detail.html" } }
            },
            {
              "name": "show-contractors",
              "description": "Displays the list of contractors available for insurance repair work. Optionally filter by specialty or preferred status.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "specialty": {
                    "type": "string",
                    "description": "Filter by contractor specialty (e.g. 'Roofing', 'Water Damage', 'Fire')"
                  },
                  "preferredOnly": {
                    "type": "boolean",
                    "description": "Show only preferred contractors"
                  }
                },
                "additionalProperties": false
              },
              "annotations": { "readOnlyHint": true },
              "execution": { "taskSupport": "forbidden" },
              "_meta": { "ui": { "resourceUri": "ui://zava/contractors-list.html" } }
            },
            {
              "name": "update-claim-status",
              "description": "Updates the status of an insurance claim. Use claim ID (e.g. '1', '2').",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "claimId": { "type": "string", "description": "The claim ID" },
                  "status": {
                    "type": "string",
                    "description": "New status (e.g. 'Approved', 'Denied', 'Closed', 'Open - Under Investigation')"
                  },
                  "note": { "type": "string", "description": "Optional note to add to the claim" }
                },
                "required": ["claimId", "status"],
                "additionalProperties": false
              },
              "execution": { "taskSupport": "forbidden" }
            },
            {
              "name": "update-inspection",
              "description": "Updates an inspection record — status, findings, recommended actions, property, or inspector assignment.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "inspectionId": {
                    "type": "string",
                    "description": "The inspection ID (e.g. 'insp-001')"
                  },
                  "status": {
                    "type": "string",
                    "description": "New status (e.g. 'completed', 'scheduled', 'in-progress', 'cancelled')"
                  },
                  "findings": { "type": "string", "description": "Updated findings text" },
                  "recommendedActions": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Updated recommended actions"
                  },
                  "property": { "type": "string", "description": "Updated property address" },
                  "inspectorId": {
                    "type": "string",
                    "description": "Inspector ID to assign (e.g. 'inspector-003')"
                  }
                },
                "required": ["inspectionId"],
                "additionalProperties": false
              },
              "execution": { "taskSupport": "forbidden" }
            },
            {
              "name": "update-purchase-order",
              "description": "Updates a purchase order status (e.g. approve, reject, complete).",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "purchaseOrderId": {
                    "type": "string",
                    "description": "The purchase order ID (e.g. 'po-001')"
                  },
                  "status": {
                    "type": "string",
                    "description": "New status (e.g. 'approved', 'rejected', 'completed', 'in-progress')"
                  },
                  "note": { "type": "string", "description": "Optional note to add" }
                },
                "required": ["purchaseOrderId", "status"],
                "additionalProperties": false
              },
              "execution": { "taskSupport": "forbidden" }
            },
            {
              "name": "get-claim-summary",
              "description": "Returns a text summary for a specific claim with key details. Use claim ID or claim number.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "claimId": { "type": "string", "description": "Claim ID or claim number" }
                },
                "required": ["claimId"],
                "additionalProperties": false
              },
              "execution": { "taskSupport": "forbidden" }
            },
            {
              "name": "create-inspection",
              "description": "Creates a new inspection record. Only claimNumber is required. ID is auto-generated, status defaults to 'open'. claimId is optional.",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "claimNumber": {
                    "type": "string",
                    "description": "The claim number (e.g. 'CN202504990')"
                  },
                  "claimId": { "type": "string", "description": "Optional claim ID" },
                  "taskType": {
                    "type": "string",
                    "description": "Type of inspection: 'initial', 're-inspection', 'final'. Defaults to 'initial'"
                  },
                  "priority": {
                    "type": "string",
                    "description": "Priority: 'low', 'medium', 'high'. Defaults to 'medium'"
                  },
                  "status": { "type": "string", "description": "Status. Defaults to 'open'" },
                  "scheduledDate": {
                    "type": "string",
                    "description": "Scheduled date (ISO string)"
                  },
                  "inspectorId": { "type": "string", "description": "Inspector ID to assign" },
                  "property": { "type": "string", "description": "Property address" },
                  "instructions": { "type": "string", "description": "Inspection instructions" }
                },
                "required": ["claimNumber"],
                "additionalProperties": false
              },
              "execution": { "taskSupport": "forbidden" }
            },
            {
              "name": "list-inspectors",
              "description": "Lists all available inspectors with their specializations.",
              "inputSchema": { "type": "object", "properties": {} },
              "execution": { "taskSupport": "forbidden" }
            }
          ]
        }
      },
      "run_for_functions": [
        "show-claims-dashboard",
        "show-claim-detail",
        "show-contractors",
        "update-claim-status",
        "update-inspection",
        "update-purchase-order",
        "get-claim-summary",
        "create-inspection",
        "list-inspectors"
      ]
    }
  ]
}
```

> **Note how tools with UI widgets** (e.g., `show-claims-dashboard`, `show-claim-detail`, `show-contractors`) include `annotations`, `execution`, AND `_meta` with `resourceUri` — all copied verbatim from the tools/list response. Tools without UI (e.g., `update-claim-status`) still include `execution` when the server returned it, but omit `annotations` and `_meta` since the server didn't provide them.

Verify the generated registration in `declarativeAgent.json` still points to the augmented plugin.

---

## Complete Example — Authenticated Server

For an OAuth-protected MCP server at `https://mcp.example.com/mcp`, start with `wiqd agent add
action --mcp-server-url ... --mcp-auth-type oauth`. Preserve the lifecycle and environment wiring
generated by wiqd. See [Authentication](authentication.md) for mode selection, credentials, and recovery.

### `appPackage/example-plugin.json`

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v<x.y>/schema.json",
  "schema_version": "v<x.y>",
  "name_for_human": "Example Service",
  "description_for_human": "Search and browse Example Service content",
  "namespace": "example",
  "functions": [
    {
      "name": "search",
      "description": "Search Example Service for content matching a query.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$.items",
          "properties": { "title": "$.title", "url": "$.url" },
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "[${title}](${url})", "wrap": true, "maxLines": 2 }
            ]
          }
        }
      }
    }
  ],
  "runtimes": [
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "OAuthPluginVault", "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}" },
      "spec": {
        "url": "https://mcp.example.com/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "search",
              "description": "Search Example Service for content matching a query.",
              "inputSchema": {
                "type": "object",
                "properties": { "query": { "description": "Search query", "type": "string" } },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": ["search"]
    }
  ]
}
```

---

## Multiple MCP Servers

You can integrate multiple MCP servers by adding multiple runtimes, each with its own auth type. Each runtime has its own `mcp_tool_description.tools` and `run_for_functions`:

```json
{
  "functions": [
    {
      "name": "docs_search",
      "description": "Search Microsoft docs.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
          }
        }
      }
    },
    {
      "name": "search",
      "description": "Search authenticated service.",
      "capabilities": {
        "response_semantics": {
          "data_path": "$",
          "properties": {},
          "static_template": {
            "type": "AdaptiveCard",
            "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.6",
            "body": [
              { "type": "TextBlock", "text": "${if(title, title, description)}", "wrap": true }
            ]
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
        "url": "https://learn.microsoft.com/api/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "docs_search",
              "description": "Search Microsoft docs.",
              "inputSchema": {
                "type": "object",
                "properties": { "query": { "type": "string" } },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": ["docs_search"]
    },
    {
      "type": "RemoteMCPServer",
      "auth": { "type": "OAuthPluginVault", "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}" },
      "spec": {
        "url": "https://mcp.example.com/mcp",
        "mcp_tool_description": {
          "tools": [
            {
              "name": "search",
              "description": "Search authenticated service.",
              "inputSchema": {
                "type": "object",
                "properties": { "query": { "type": "string" } },
                "required": ["query"]
              }
            }
          ]
        }
      },
      "run_for_functions": ["search"]
    }
  ]
}
```

---

## Common Issues

| Issue                        | Solution                                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| Plugin fails to load         | Verify `{name}-plugin.json` exists and preserves the generated runtime                                 |
| Pinned tools not recognized  | Verify names match exactly across `functions[]`, `mcp_tool_description.tools[]`, and `run_for_functions` |
| Dynamic tools not recognized | Verify `functions` is empty, `mcp_tool_description` is omitted, and `run_for_functions` is `["*"]`      |
| OAuth token errors           | Re-authenticate with `mcp-remote` — cached tokens may have expired                                     |
| `<PREFIX>_MCP_AUTH_ID` empty | Review the generated lifecycle and fill unresolved credential placeholders in the target environment; do not duplicate `oauth/register` |
| Tool calls 404 after a clean provision | Verify the endpoint, registration, permissions, and app binding before choosing a repair — see [registration recovery](authentication.md#re-provisioning-rewriting-and-recovering-a-registration) |
| "Invalid redirect URI"       | Ensure redirect URI in DCR is `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`            |

---

## Best Practices

1. Keep dynamic discovery unless the user asks to pin tools.
2. Discover before pinning; never invent tool definitions.
3. Copy selected tool objects verbatim and inline; keep names synchronized across the manifest.
4. Add response semantics to every pinned function.
5. Custom logos are optional and must be PNG.
