---
title: Validation & MVL
description: Validate plugins with offline declarative-agent checks and package-first deep validation.
---

# Validation & MVL

Validation is a fast feedback loop throughout WIQD's plugin lifecycle. Static
validation checks a plugin's **declarative-agent component** offline; deep
validation checks its **built app package** through the Microsoft 365 service.
Neither substitutes for trying skills, connectors, and agent behavior in the
target experience.

## Two modes

```bash
wiqd plugin validate --env dev              # static (default), declarative-agent surface
wiqd plugin validate --mode deep --env dev  # needs an already-built ZIP
```

Existing agent-focused projects continue to use `wiqd agent validate`.

### Static mode

Static mode runs the **Microsoft Validation Layer (MVL)** — the same engine the M365 platform uses to accept a manifest. It's offline, needs no auth, and finishes in sub-second on a normal project. It catches:

- Schema violations (missing required fields, wrong types, bad enum values).
- Cross-file references that don't resolve (e.g., a capability that points to a file that isn't there).
- Constraints the M365 platform enforces but a JSON schema alone can't (e.g., maximum number of conversation starters).

This is the mode you should run on every save, on every commit hook, and on every PR.

For plugins, static mode does not inspect the root app manifest, skill content,
or root connectors. A skill-only or connector-only plugin has no
declarative-agent surface to check, so a static pass does not establish
whole-plugin validity.

### Deep mode

Deep mode resolves an already-built app package and hands it to wiqd Core's
in-process validation handler for platform-aware package checks. It does not
build the package or run static validation first. For a new plugin, provision
before packaging so the selected environment and app identity exist:

```bash
wiqd plugin validate --env dev
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin validate --mode deep --env dev
```

Deep mode needs service access and does not require the ATK CLI. Inspect its
findings before sharing or submitting to your tenant catalog.

## Real-time validation in VS Code

The [VS Code extension](/concepts/vscode-extension/) starts a `wiqd agent lsp` server that streams the same MVL diagnostics into the editor as you type. No save-and-run loop — squigglies appear inline, with hover details and quick fixes where MVL can suggest them.

## Where validation fits in the lifecycle

```text
compose/edit ─▶ static validate ─▶ provision ─▶ package ─▶ deep validate ─▶ share/publish
```

Treat validation as a precondition for every other command in the pipeline. Work IQ Dev Tools don't *force* you to validate before provisioning, but if you don't, you'll find out the same problems the slow way — through an upstream error halfway through a deploy.

## Exit codes

```text
0    Command completed; for deep JSON output, inspect data.valid
1    Static validation errors (your manifest needs fixing)
2    Infrastructure error (missing project, package, or validation dependency)
130  Cancelled (Ctrl+C)
```

Deep validation findings are a designed domain outcome: the command can exit `0`
with `data.valid: false`. Automation must inspect that field rather than relying
only on the process exit code. See [Exit codes & output](/concepts/exit-codes-output/)
for the shared command contract.

## Go deeper

- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — plugin validation
- [`wiqd agent validate`](/cli/reference/#wiqd-agent-validate) — existing agent-project validation
- [`wiqd agent lsp`](/extensions/provided/validate/cli/) — the editor integration
- [Validate extension](/extensions/provided/validate/) — the MVL engine + LSP server
- [VS Code extension](/concepts/vscode-extension/) — installing the live editor experience
- [Build a Plugin](/getting-started/build-a-plugin/) — where validation sits in plugin delivery
