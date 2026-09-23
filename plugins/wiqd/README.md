# wiqd

Developer toolkit for building, validating, provisioning, and publishing Microsoft 365 Copilot plugins, including extensibility capabilities such as declarative agents, skills, and connectors, using the `wiqd` CLI.

## Installation

```bash
/plugin install wiqd@wiqd
```

## Usage

```
# Scaffold a new agent
"Create a new declarative agent for HR FAQ"

# Edit the manifest
"Add a SharePoint capability to my agent"

# Validate
"Validate my agent manifest"

# Provision to an environment
"Provision my agent to local"

# Share with users
"Share my agent with the team"

# Package for distribution
"Package my agent for publishing"

# Publish to production
"Publish my agent to the tenant"

# Run evaluations
"Run evals for my agent"

# Monitor telemetry
"Show usage analytics for my agent"

# Ask directly
"Send a test message to my agent"

# Localize
"Localize my agent to French and German"

# Migrate an existing agent
"Migrate my existing agent zip into a wiqd project"

# Debug in DevUI
"Generate a DevUI link for my agent"

# Submit feedback
"File a bug report for wiqd"

# Search docs
"How do I add a Graph connector?"

# Getting started
"Walk me through the agent lifecycle"
```

## Skills

### Orchestrator

| Skill                              | What It Does                                                                                  |
| ---------------------------------- | --------------------------------------------------------------------------------------------- |
| [**wiqd**](./skills/wiqd/SKILL.md) | Core orchestrator — routes tasks to extension workflows or handles inline via reference files |

### Extension-contributed workflows

Each extension contributes a workflow file that the orchestrator reads inline.

| Workflow    | Extension       | What It Does                                                                                                       |
| ----------- | --------------- | ------------------------------------------------------------------------------------------------------------------ |
| `atk.md`    | wiqd-ext-atk    | Full ATK lifecycle — create, edit, validate, provision, package, share, show, delete, open, env, migrate, localize |
| `eval.md`   | wiqd-ext-eval   | Generate, run, and analyze evaluation suites using the PRA framework                                               |
| `workiq.md` | wiqd-ext-workiq | Monitor agent behavior, ask agents, list deployed agents                                                           |


### Inline references (handled by orchestrator)

| Reference           | Commands Covered                             |
| ------------------- | -------------------------------------------- |
| `orientation.md`    | Getting started, lifecycle phases            |
| `install-update.md` | `wiqd install`, `wiqd update`, `wiqd doctor` |
| `feedback.md`       | `wiqd feedback submit`, `wiqd feedback list` |

| `docs-search.md` | Documentation search (docs site) |
| `changelog.md` | `wiqd changelog` |

## Agents

### `wiqd:wiqd`

Journey orchestrator for building and shipping M365 Copilot declarative agents. Drives the full lifecycle (Build → Improve → Preview → Publish) by discovering project state, deciding the next step, and invoking the wiqd skill with the right workflow on your behalf.

## CLI Reference

```
wiqd
  ├── version
  ├── config
  │   ├── set <key=value...>
  │   └── reset
  ├── auth
  │   ├── login [--interactive]
  │   ├── logout
  │   └── status
  ├── update [--version] [--check] [--channel] [--force] [--dry-run] [--skip-extension]
  ├── changelog [--version] [--from] [--to] [--json] [--markdown]
  ├── install [--status]
  │   ├── plugin
  │   └── extension [--insiders]
  ├── uninstall
  │   ├── plugin
  │   └── extension [--insiders]
  ├── doctor
  ├── feedback [--type] [--title] [--description] [--no-context] [--dry-run]
  │   └── list [-n|--top] [--status] [--json]
  ├── ext
  │   ├── list [--json]
  │   └── show <id> [--json]
  ├── agent
  │   ├── create [--template] [--name] [--output]
  │   │   └── list
  │   ├── add
  │   │   ├── action [--openapi-spec] [--operations]
  │   │   ├── skill [--name] [--description] [--from]
  │   │   └── auth [--plugin-manifest] [--auth-name] [--auth-type]
  │   ├── provision [--env]
  │   ├── package
  │   ├── share [--email] [--scope]
  │   │   ├── remove [--users] [--owners]
  │   │   └── collaborator
  │   │       ├── add [--email]
  │   │       └── list [--all]
  │   ├── env
  │   │   ├── list
  │   │   ├── add [--env]
  │   │   └── reset [--env]
  │   ├── validate
  │   ├── show [--path] [--env] [--name] [--id]
  │   ├── lsp
  │   ├── monitor [-q] [--env] [--path]
  │   ├── ask [-q] [--agent-id] [--agent-name]
  │   ├── list [--name] [--id] [--top]
  │   ├── open [--env] [--path] [--print]
  │   ├── delete [--env] [--path] [--yes] [--keep-env-file] [--interactive]
  │   ├── publish [--env] [--path] [--manifest] [--interactive]
  │   └── eval [--env] [--path] [--config] [--category] [--concurrency] [--repeats] [--threshold]
  │       └── init [--path] [--output]
```

