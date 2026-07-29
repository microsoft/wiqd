---
title: Agent lifecycle
description: The path from creating an agent to shipping it
---

# Agent lifecycle

Every declarative agent moves through the same set of phases. Work IQ Dev Tools give you one command per phase, and the phases compose into a predictable pipeline you can run locally or in CI.

## The phases

```text
create ─▶ edit ─▶ validate ─▶ provision ─▶ package ─▶ publish ─▶ monitor
                     ▲                                              │
                     └──────────────── iterate ─────────────────────┘
```

### 1. Create

Scaffold a new project from a template.

```bash
wiqd agent create --name my-agent
```

You get a directory with the `appPackage/` files described in [Declarative agents](/concepts/declarative-agents/), plus a `m365agents.yml` driver file for the lifecycle commands.

### 2. Edit

Open the project in your editor. Tweak the instructions, add knowledge sources, attach actions, or add conversation starters with the bundled VS Code extension. You can also script edits with `wiqd agent add action` and `wiqd agent add skill`.

### 3. Validate

Catch problems before deploying.

```bash
wiqd agent validate              # fast static checks
wiqd agent validate --mode deep  # full ATK validation
```

Static mode runs the Microsoft Validation Layer (MVL) engine offline — no network, no auth, sub-second. Deep mode adds the upstream ATK semantic checks. See [Validation & MVL](/concepts/validation-mvl/).

### 4. Provision

Deploy the agent to an [environment](/concepts/environments/). The first run creates the M365 app registration; subsequent runs update it.

```bash
wiqd agent provision --env local
```

### 5. Package

Build the distributable `.zip` for sideloading or upload.

```bash
wiqd agent package
```

### 6. Publish

Push the package to the org catalog so other users can install it.

```bash
wiqd agent publish --env prod
```

### 7. Monitor & iterate

Once the agent is live, query its usage and health, then loop back to step 2.

```bash
wiqd agent monitor               # ask the Insights Agent
wiqd agent ask -q "..."  # send a test prompt
wiqd agent eval                  # run quality evaluations
```

## Side branches

A few commands sit outside the linear pipeline but you'll use them often:

- **`wiqd agent show`** — glanceable summary of what's in a project (local) or a deployed agent (remote).
- **`wiqd agent env`** — manage environment definitions.
- **`wiqd agent share`** — give other users access during development.
- **`wiqd agent delete`** — tear down cloud resources.

## Go deeper

- [Environments](/concepts/environments/) — `local`, `dev`, `staging`, `prod`
- [`wiqd agent create`](/cli/reference/#wiqd-agent-create), [`provision`](/cli/reference/#wiqd-agent-provision), [`package`](/cli/reference/#wiqd-agent-package), [`publish`](/cli/reference/#wiqd-agent-publish)
- [Agents Toolkit extension](/extensions/provided/atk/) — implements most of these phases
- [Eval extension](/extensions/provided/eval/) — quality evaluations on deployed agents
