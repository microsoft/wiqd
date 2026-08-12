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
| [`wiqd devui stop`](/cli/reference/#wiqd-devui-stop) | Stop a running DevUI server by its recorded PID, releasing its process tree and the install-directory lock. Exits `0` whether or not a server was running. |

## Process model

**On Windows, interactively**, the server runs in **its own visible console window** (titled "Work IQ DevUI") showing the startup banner and listen URL. Stop it by pressing **Ctrl+C** in that window or closing it (the server exits with code 130). The window is separate from your terminal, so you can keep typing commands elsewhere.

**When the run is not interactive** (stdout is piped, or CI is detected), when you pass `--no-window`, or on **macOS/Linux** always, the server runs **headlessly in the background** with no new window. Logs go to a temporary file (`<os-temp>/wiqd-devui-<port>.log`). Stop it with `wiqd devui stop`.

`--json` controls only the **output format** — it does not change the process model, so you can combine an interactive console window with a machine-readable envelope, or take the headless path while still reading the human summary.

In every case, `wiqd devui start` itself returns immediately (non-blocking) once the server is confirmed healthy, so you get your prompt back right away.

## Stopping DevUI

- **Windows (visible window)** — press **Ctrl+C in the server's console window**, or close the window.
- **Headless runs, macOS, Linux** — run `wiqd devui stop` from any terminal.
- **Either platform** — `wiqd devui stop --port 7317` always works.

The server writes a PID sidecar (`<os-temp>/wiqd-devui-<port>.pid`) as soon as it starts listening; `stop` reads that file to terminate the server process tree, confirms the process is actually gone, and only then clears the sidecar.

| Exit | `status`      | Meaning                                                                          |
| ---- | ------------- | -------------------------------------------------------------------------------- |
| `0`  | `stopped`     | The server was found and is confirmed terminated.                                |
| `0`  | `not-running` | Nothing was tracked on that port (or the record was stale) — an idempotent no-op. |
| `1`  | `failed`      | A server was found **alive** but survived the kill (e.g. it runs elevated or as another user). Its PID record is kept so you can still act on it. |

A failed health check is deliberately not treated as "already stopped": a server with a wedged event loop is still holding the lock, so `stop` terminates it rather than silently forgetting about it.

## Live traces

The **Traces** tab shows workiq's OpenTelemetry spans for each turn, captured by an in-process OTLP/gRPC receiver on port `4317` by default. If `4317` is already in use, DevUI automatically picks a free port instead of failing — there is no `--otlp-port` flag. If workiq isn't yet configured to export anywhere (`workiq config set otlpEndpoint=...`), the Traces tab shows a hint with the exact command to enable it.
