---
title: Work IQ · CLI commands
description: Every command contributed by Work IQ Dev Tools' Work IQ extension
---

# Work IQ · CLI commands

The Work IQ extension contributes four commands, all under `wiqd agent`. Every one of them requires `wiqd config set experimental true` and `wiqd auth login`.

| Command | What it does |
|---------|--------------|
| [`wiqd agent monitor`](/cli/reference/#wiqd-agent-monitor) | Ask the Insights Agent about a provisioned agent's performance and usage. |
| [`wiqd agent ask`](/cli/reference/#wiqd-agent-ask) | Send a message directly to a declarative agent by ID or name. |
| [`wiqd agent list`](/cli/reference/#wiqd-agent-list) | List declarative agents deployed in the tenant. |
| [`wiqd agent show --name/--id`](/cli/reference/#wiqd-agent-show) | Remote-mode lookup of a deployed agent. The **local mode** of `wiqd agent show` (no `--id`/`--name`) belongs to the [ATK extension](/extensions/provided/atk/). |
