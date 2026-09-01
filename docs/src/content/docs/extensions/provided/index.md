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
| [Agents Toolkit (ATK)](/extensions/provided/atk/) | The full agent lifecycle: scaffold, edit, validate, package, provision, publish, share, delete | `wiqd agent` |
| [Eval](/extensions/provided/eval/) | Quality evaluations of deployed agents (LLM-as-judge scoring) | `wiqd agent eval` |
| [Validate](/extensions/provided/validate/) | Offline MVL static validation and the VS Code LSP server | `wiqd agent validate`, `wiqd agent lsp` |
| [Work IQ](/extensions/provided/workiq/) | Monitor, ask, and list deployed agents in your tenant | `wiqd agent monitor`, `ask`, `list` |
| [Work IQ DevUI](/extensions/provided/devui/) | Launch the local Work IQ DevUI web experience for interactively testing/debugging agents | `wiqd devui` |

## How each extension is documented

Every extension has its own collapsible subsection in the sidebar with **four pages**:

1. **Overview** — one-paragraph elevator pitch, a realistic end-to-end workflow walkthrough, and pointers into the codebase.
2. **CLI commands** — every leaf command this extension adds, with links to the full CLI reference page for each.
3. **Agentic workflows** — the multi-step workflow files and reference files this extension contributes to the wiqd Copilot orchestrator. Some extensions (Support, Validate) contribute none; those pages say so honestly and explain why.
4. **Agent plugins** — the user-facing scenarios this extension unlocks in Copilot Chat, with trigger phrases and routing guidance.

This structure makes it easy to answer three different questions: *"what can I script with this?"* (CLI commands), *"what will Copilot do for me?"* (Agentic workflows + Copilot skills), and *"where does the code live?"* (Overview → "Where to look in the codebase").
