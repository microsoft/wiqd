---
title: Provided Extensions
description: The extensions bundled with Work IQ Dev Tools
---

# Provided Extensions

When you install Work IQ Dev Tools, several extensions install with it. You don't enable them — they're already loaded. Every command outside of the small host core (see [Host vs extensions](/concepts/host-vs-extensions/)) comes from one of these.

Run `wiqd ext list` at any time to see what's loaded in your environment.

## The bundled extensions

| Extension | What it gives you | Commands contributed under |
|-----------|-------------------|----------------------------|
| [wiqd Core](/extensions/provided/core/) | Plugin composition and lifecycle, plus agent-component authoring and existing agent projects | `wiqd plugin`, `wiqd agent` |
| [Eval](/extensions/provided/eval/) | Quality evaluations of deployed agents (LLM-as-judge scoring) | `wiqd agent eval` |
| [Validate](/extensions/provided/validate/) | Source, package and Marketplace validation, listing/repair helpers, plus editor diagnostics | `wiqd plugin validate`, plugin listing/repair helpers |
| [Work IQ](/extensions/provided/workiq/) | Monitor, ask, and list deployed agents in your tenant | `wiqd agent monitor`, `ask`, `list` |
| [Work IQ DevUI](/extensions/provided/devui/) | Launch the local Work IQ DevUI web experience for interactively testing/debugging agents | `wiqd devui` |
| [Marketplace](/getting-started/publish-to-partner-center/) | Publisher sign-in and direct declarative-agent offer preparation, submission, updates and status | `wiqd publish pc`, Marketplace provider under `wiqd auth` |

Marketplace is bundled and enabled by default in the public launch build.
Explicit extension removal or a disabled `partner-center-publishing` flag is
preserved. Installing it does not grant publisher access or submission authority.

## How each extension is documented

Most extensions have a collapsible subsection in the sidebar with **four pages**.
Marketplace instead has a [publishing guide](/getting-started/publish-to-partner-center/)
and [command reference](/cli/publish-pc/):

1. **Overview** — what the extension does and when to use it.
2. **CLI commands** — every leaf command this extension adds, with links to the full CLI reference page for each.
3. **Agentic workflows** — the steps your coding assistant guides you through, including validation and authorized repair.
4. **Agent plugins** — the user-facing scenarios this extension unlocks in Copilot Chat, with trigger phrases and routing guidance.

Use the CLI pages for scripting and the workflow and agent-plugin pages for
guided use with your coding assistant.
