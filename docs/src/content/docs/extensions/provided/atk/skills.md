---
title: ATK · Agent plugins
description: The natural-language scenarios the ATK extension powers in Copilot Chat
---

# ATK · Agent plugins

When you talk to Copilot Chat with the wiqd plugin loaded, the ATK extension's workflow shows up as the **"ATK tasks"** routing entry. Saying any of the trigger phrases below lifts the right ATK command into the conversation, with Work IQ Dev Tools shelling out behind the scenes.

## Scenarios unlocked

The ATK workflow covers the **Build** stage of the agent journey, from "empty folder" to "shareable, published agent":

- **Scaffold** — create a new agent from a template.
- **Edit** — modify instructions, capabilities, actions, plugins, or auth configuration on an existing agent.
- **Validate** — fast static checks and deep semantic checks before deploying.
- **Provision** — push the agent into an environment (local, staging, prod).
- **Package** — build the deployable `.zip` you share with a teammate or distribute.
- **Share / collaborate** — give a teammate access, manage co-owners.
- **Publish** — promote the agent to the org-wide catalog.
- **Delete / open / show** — inspect and tear down cloud resources.
- **Migrate / localize** — keep older agents on the current schema and translate to other locales.

## Trigger phrases

Saying any of these in Copilot Chat routes the orchestrator into the ATK workflow:

> create agent · new agent · scaffold agent · edit my agent · update my agent · modify my agent · add a capability · add a plugin · provision my agent · deploy my agent · package my agent · share my agent · delete my agent · remove my agent · open my agent · show my agent · show my environments · manage environments · add environment · migrate my agent · localize my agent · validate my agent · fix my agent manifest · update instructions · add web search · update manifest · review instructions

## Where ATK sits in the journey

ATK is **stage 1 of 4** in the wiqd agent journey — the **Build** stage. Once a project exists on disk and a manifest is structurally valid, the orchestrator hands off to the [Eval extension](/extensions/provided/eval/skills/) for the **Improve** stage and to the [Work IQ extension](/extensions/provided/workiq/skills/) for the **Preview** stage.
