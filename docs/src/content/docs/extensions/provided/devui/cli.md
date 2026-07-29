---
title: DevUI · CLI commands
description: Every wiqd command contributed by the Work IQ DevUI extension
---

# DevUI · CLI commands

Every command below lives under `wiqd devui`. They are gated behind the `devui` preview flag (`wiqd config flags set devui true`) and start or reuse a local server that authenticates via the `workiq` CLI.

## Commands

| Command | What it does |
|---------|--------------|
| [`wiqd devui start`](/cli/reference/#wiqd-devui-start) | Start (or reuse) the local Work IQ DevUI and open it in the browser. |
| [`wiqd devui ask`](/cli/reference/#wiqd-devui-ask) | Ask an agent and watch the turn run live in the local Work IQ DevUI (deep-linked + auto-sent). |
| [`wiqd devui config`](/cli/reference/#wiqd-devui-config) | Configure DevUI to mint access tokens with your own Entra app registration (skip the `workiq` CLI). Running `start` afterwards forces an initial sign-in. |
