---
title: Eval · CLI commands
description: Every command contributed by Work IQ Dev Tools' Eval extension
---

# Eval · CLI commands

The Eval extension contributes two commands under `wiqd agent eval`:

| Command                                                                          | What it does                                                  |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [`wiqd agent eval`](/cli/reference/#wiqd-agent-eval)                  | Run quality evaluations against a deployed declarative agent  |
| [`wiqd agent eval init`](/cli/reference/#wiqd-agent-eval-init)        | Scaffold a starter `evals/prompts.json` for the agent         |

`wiqd agent eval init` requires an ATK project — it scaffolds a starter prompts file from the agent manifest.

`wiqd agent eval` does **not** require `m365agents.yml` or a provisioned ATK project. It needs only (1) a prompts file and (2) a resolvable agent title ID — sourced from `env/.env.<env>` (`M365_TITLE_ID`) or from `--agent-id`.

## Running against an evals-only folder

You can run `wiqd agent eval` from a folder that holds only `evals/prompts.json` plus `env/.env.<env>` carrying `M365_TITLE_ID` — no `m365agents.yml` required. The title ID is read from the env file automatically, so no `--agent-id` is needed:

```bash
wiqd agent eval --path <folder> --env <env>
```

## Evaluating a deployed agent directly

Pass `--agent-id <id>` to run evals against an already-deployed agent from any folder that holds only a prompts file — no `m365agents.yml` or `env/.env.<env>` required:

```bash
wiqd agent eval --path <folder> --agent-id <id> -c prompts.json
```

When `--agent-id` is set, the title ID is sourced from the option rather than from `env/.env.<env>`.

### Options

| Flag             | Type     | Default              | Description                                                                                                        |
| ---------------- | -------- | -------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `--path`         | `string` | `.`                  | Path to project or prompts folder (defaults to CWD)                                                                |
| `--env`          | `string` | `local`              | Target environment (project mode only)                                                                             |
| `--config`, `-c` | `string` | `evals/prompts.json` | Path to eval prompts file                                                                                          |
| `--agent-id`     | `string` | _(none)_             | Title ID of a deployed agent to evaluate directly (e.g. `T_xxx`). When set, sources the title ID from this option instead of `env/.env.<env>`. |
| `--concurrency`  | `int`    | `5`                  | Concurrent scenario runs (1-5)                                                                                     |
| `--threshold`    | `float`  | _(none)_             | Minimum pass-rate (0-1) to succeed. Exit 1 if score falls below this.                                              |
