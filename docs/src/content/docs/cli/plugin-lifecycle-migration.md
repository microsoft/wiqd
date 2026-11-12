---
title: Plugin-owned lifecycle migration
description: Migrate retired agent project commands to the canonical plugin lifecycle.
---

The Microsoft 365 project lifecycle is now owned by `wiqd plugin`. This is an
intentional breaking change. Retired command spellings remain hidden from help
and completion, and they still fail rather than running old or replacement
behavior. The difference is diagnostic: a legacy invocation now reports that it
is deprecated and gives the exact migration steps instead of returning only
`unknown command`. Existing projects must contain a valid contained
`m365agents.yml` and `appPackage/manifest.json`. Structurally complete projects
created by the retired `wiqd agent create` are immediately compatible.

The diagnostic does not authenticate, inspect or change a project, contact a
service, or run the replacement. It accepts the old invocation's arguments and
options only so guidance is not hidden behind another parser or required-option
error. A nonzero result is expected; update scripts to the canonical command.

## Existing legacy agent projects

Do not recreate a complete legacy project. WIQD recognizes the existing
lifecycle and root app manifest read-only, derives the project name from
normalized `name.short`, and derives capabilities from the root component
collections. Each command then validates only the referenced component closure
it needs. Missing or unsafe structural files fail with exit `2`; malformed
manifest/name/component data fails with exit `1` before authentication, cloud
work, or project mutation.

A historical `wiqd.plugin.json` from an earlier development build is ignored.
After confirming no external tooling depends on it, you may delete it manually;
WIQD neither migrates nor repairs it.

The compatibility gate applies to project-scoped add, show/list, environment,
validation, lifecycle/share/collaborator/delete, and export operations.
Template discovery, remote `agent show`, explicit ZIP-only commands,
`plugin import`, and title-ID-only delete remain non-project operations.

## Create and compose

Creation is explicitly two steps:

```bash
wiqd plugin create --name my-plugin
cd my-plugin
wiqd plugin add agent --name "My Agent"
```

`plugin add agent` always adds the basic declarative-agent starter and
accepts `--name`, `--folder`, and optional `--template` (alias `-t`), plus global
options. The template defaults to `declarative-agent`, the only supported value;
`wiqd plugin list templates` lists it. Add MCP or
OpenAPI actions separately against the final project:

```bash
wiqd agent add action --mcp-server-url https://example.com/mcp --mcp-auth-type none
```

The default `declarative-agent` starter is generated directly from WIQD-owned
templates, without loading fx-core or initializing Microsoft 365 authentication.
It adds `appPackage/declarativeAgent.json` and an editable `appPackage/instruction.txt`
for the agent's persona, scope and rules. Existing plugin identity, lifecycle,
environments, skills and connectors are preserved. `plugin create` still uses
the fx-core blank-app template; it is separate from this component-generation step.

For OAuth, dynamic OAuth, Entra SSO or bearer-token actions, select the appropriate
mode and credential options on `agent add action`; that command writes the
action, lifecycle and environment wiring together. The former MCP/auth and
`--connector-package` options on `plugin add agent` are rejected. Connector ZIP
source-host creation has been removed; it has no equivalent ZIP-import option
on `agent add action`. Existing hosts and separate `plugin provision package`
operations are unaffected. Root plugin skills/connectors remain separate from
the embedded agent's actions and `agent_skills`.

## Command replacements

The commands below are exact. In particular, environment and validation
helpers moved to verb-first plugin routes; `plugin env ...` and
`plugin validate <helper>` are not the final spellings.

| Legacy invocation | Use instead |
| --- | --- |
| `wiqd agent create` | Run `wiqd plugin create`, then `wiqd plugin add agent [--template declarative-agent]` for the fixed basic starter. The optional template selector accepts only `declarative-agent`; blank or unsupported legacy templates have no replacement. Add supported actions or API-plugin authentication afterward with `wiqd agent add action` or `wiqd agent add auth`, as applicable. Connector-package source-host creation has no direct replacement. |
| `wiqd agent create list` | Use `wiqd plugin list templates` for informational discovery. `wiqd plugin add agent` accepts the optional selector `--template declarative-agent` only; other template selection is unsupported. |
| `wiqd plugin templates` / `wiqd plugin templates list` | `wiqd plugin list templates` |
| `wiqd agent env` / `wiqd plugin env` | Choose `wiqd plugin list environments`, `wiqd plugin add environment`, or `wiqd plugin reset environment`. |
| `wiqd agent env list` / `wiqd plugin env list` | `wiqd plugin list environments` |
| `wiqd agent env add` / `wiqd plugin env add` | `wiqd plugin add environment` |
| `wiqd agent env reset` / `wiqd plugin env reset` | `wiqd plugin reset environment` |
| local `wiqd agent show` using `--path`, `--env`, or no remote identifier | `wiqd plugin show` |
| `wiqd agent provision` | `wiqd plugin provision` |
| `wiqd agent provision package` | `wiqd plugin provision package` |
| `wiqd agent package` | `wiqd plugin package` |
| `wiqd agent publish` | `wiqd plugin publish` |
| `wiqd agent validate` | `wiqd plugin validate`; map old modes as shown below. |
| `wiqd agent validate add-market-listing` / `wiqd plugin validate add-market-listing` | `wiqd plugin add market-listing` |
| `wiqd agent validate get-market-listing` / `wiqd plugin validate get-market-listing` | `wiqd plugin get market-listing` |
| `wiqd agent validate preview-market-listing` / `wiqd plugin validate preview-market-listing` | `wiqd plugin preview market-listing` |
| `wiqd agent validate repair-package` / `wiqd plugin validate repair-package` | `wiqd plugin repair package` |
| hidden `wiqd agent validate-request` | Internal automation uses hidden `wiqd plugin request validation`; ordinary validation uses `wiqd plugin validate`. |
| hidden `wiqd agent validate deep` | No direct command-path replacement. Use `wiqd plugin validate --mode package --package-file <zip>` for final-ZIP/TDP validation, or `--mode source` for offline saved-source diagnostics. |
| `wiqd agent share` | `wiqd plugin share` |
| `wiqd agent share remove` / `wiqd plugin share remove` | `wiqd plugin remove access` |
| `wiqd agent share collaborator` / `wiqd plugin share collaborator` | Choose `wiqd plugin add collaborator` or `wiqd plugin list collaborators`. |
| `wiqd agent share collaborator add` / `wiqd plugin share collaborator add` | `wiqd plugin add collaborator` |
| `wiqd agent share collaborator list` / `wiqd plugin share collaborator list` | `wiqd plugin list collaborators` |
| `wiqd agent delete` | `wiqd plugin delete` |
| `wiqd agent uninstall` | `wiqd plugin uninstall` |
| `wiqd agent ask` | `wiqd plugin ask --component agent` |

### Validation mode migration

`wiqd plugin validate` accepts exactly one current mode per invocation:

| Retired input | Use instead |
| --- | --- |
| `--mode static` | `--mode source` |
| `--mode deep` | `--mode package --package-file <zip>` |
| `--mode manifest` | `--mode package --package-file <zip>` |
| comma-separated modes | No combined equivalent. Run one of `source`, `package`, or `marketplace` for each required scope. |

`agent add action|skill|auth`, remote `agent show --id|--name`, `agent list`,
`monitor`, `eval`, `info`, separately contributed Agent commands, and hidden
`agent lsp` remain. `agent ask` moves to `plugin ask --component agent`.

`plugin publish` submits to the organization catalog for administrator approval;
it does not itself approve the app, share usage, or publish through Partner
Center.
