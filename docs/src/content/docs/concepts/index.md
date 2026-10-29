---
title: Concepts
description: Mental models for working with Work IQ Dev Tools
---

# Concepts

This section gives you the mental models you need to use Work IQ Dev Tools effectively. The goal isn't to document every flag — that lives in the [CLI Reference](/cli/reference/). It's to give you the *why* behind the commands so you can predict how Work IQ Dev Tools will behave in a new situation.

Read these in roughly this order:

1. [Plugins](/concepts/plugins/) — the app package you build and ship, composed of skills, connectors, and optional declarative agents
2. [Build a Plugin](/getting-started/build-a-plugin/) — WIQD's end-to-end build, improve, preview, and publish flow
3. [Declarative agents](/concepts/declarative-agents/) — the conversational component a plugin can include
4. [Agent component lifecycle](/concepts/agent-lifecycle/) — agent-specific authoring, evaluation, and existing `wiqd agent` projects
5. [Host vs extensions](/concepts/host-vs-extensions/) — how Work IQ Dev Tools are structured under the hood
6. [Environments](/concepts/environments/) — how `local`, `dev`, `staging`, and `prod` work
7. [Validation & MVL](/concepts/validation-mvl/) — static + deep checks before you ship
8. [Exit codes & output](/concepts/exit-codes-output/) — how to script Work IQ Dev Tools safely
9. [VS Code extension](/concepts/vscode-extension/) — live diagnostics in your editor

If you're brand-new, start with [Getting Started](/getting-started/) instead — that walks you through installation and your first plugin before circling back here for depth.
