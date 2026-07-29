---
title: ATK · Agentic workflows
description: The Copilot orchestrator workflow and reference files the ATK extension contributes
---

# ATK · Agentic workflows

The ATK extension ships a complete **agentic playbook** for the declarative-agent lifecycle. When you ask Copilot to work with agents, the wiqd Copilot orchestrator loads the workflow below and, as needed, the matching reference files. This is the agent-facing surface — you don't have to read these to use wiqd at the terminal, but they define every scenario the orchestrator knows how to drive end-to-end.

## Workflow

| File | Scenarios |
|------|-----------|
| `workflows/atk.md` | Full lifecycle — create, edit, scaffold, validate, provision, deploy, package, share, delete, open, show, migrate, localize, edit capabilities, add plugin, manage environments. |
| `workflows/partner-center.md` | **3P only** — guide external partners/ISVs through publishing a declarative agent to the Microsoft commercial marketplace (AppSource / Microsoft 365, Teams, and Copilot store) via Partner Center: validate, package, enroll, create offer, upload, complete the listing, submit for certification, go live, and troubleshoot rejections. |

## Reference files

Loaded on demand when the workflow needs deep context on a specific topic.

| File | Topic |
|------|-------|
| `1p-schema.md` | First-party manifest schema reference. |
| `adaptive-cards.md` | Authoring Adaptive Cards for plugin responses. |
| `api-plugins.md` | API plugin authoring (OpenAPI-backed actions). |
| `authentication.md` | Plugin authentication patterns (anonymous, API key, OAuth). |
| `best-practices.md` | General authoring best practices. |
| `conversation-design.md` | Designing conversation flow, prompts, and turns. |
| `debug.md` | Debugging a deployed or local agent. |
| `deployment.md` | Provisioning and deployment topology. |
| `editing-workflow.md` | Editing an existing agent safely. |
| `examples.md` | Worked examples for common patterns. |
| `instruction-review.md` | Reviewing and refining agent instructions. |
| `lifecycle.md` | End-to-end lifecycle stages and gates. |
| `localization.md` | Localization theory and file layout. |
| `localize.md` | The `wiqd agent localize` workflow. |
| `mcp-plugin.md` | MCP plugin authoring. |
| `migrate.md` | Migrating older agents to current schema. |
| `package.md` | Packaging the agent for distribution. |
| `partner-center.md` | **3P only** — Partner Center publishing depth: pre-submission checklist, store-listing field reference, certification criteria, and rejection troubleshooting. |
| `provision.md` | Provisioning into an environment. |
| `scaffolding-workflow.md` | Creating a new agent from a template. |
| `schema.md` | Manifest schema deep-dive. |
| `share.md` | Sharing and collaborator management. |
| `show.md` | Inspecting agent details. |
| `validate.md` | Static and deep validation. |
| `workspace-gates.md` | Pre-action gates the workflow enforces. |
