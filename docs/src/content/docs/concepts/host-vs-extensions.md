---
title: Host vs extensions
description: How Work IQ Dev Tools are structured and where commands come from
---

# Host vs extensions

When you type `wiqd agent create` or `wiqd agent provision`, two different layers are at work. Understanding the split helps you predict where a command lives, what tool you need installed, and where to look when something goes wrong.

## The host

The **host** is the `wiqd` binary you install. It owns:

- The command-line surface — parsing flags, picking subcommands, printing help.
- Global concerns — authentication, configuration, telemetry, output formatting (`--json`), the spinner, the banner.
- A small set of *core* commands that work without any extensions: `version`, `config`, `auth`, `update`, `doctor`, `docs`, `feedback`, `install`, `uninstall`, `ext`.
- One agent-specific core command: `wiqd agent validate` (static mode) and its sibling `wiqd agent lsp`. These ship with the host because manifest validation must work offline.

The host is intentionally generic. It has no built-in knowledge of ATK, Work IQ, or the eval suite.

For an extension that declares a managed downstream CLI, the host derives the package,
compatibility range, and owner/consumer relationship from its manifest; the extension's
`package.json` and lockfile own the exact pin. It keeps immutable generations under
`~/.wiqd/extensions/`; this state deliberately
survives uninstalling the host. `wiqd doctor` installs or repairs every active direct
managed owner before running extension checks. Its JSON output uses the standard
`checks[]` rows; standalone global copies appear as warnings and are never removed
automatically. When a managed copy is healthy, the warning includes an explicit
`npm uninstall -g <package>` command that you should run only after confirming no
external workflow or explicit override depends on that package. `wiqd ext list` and
`wiqd ext show` inspect managed state without changing it. `wiqd ext remove` only
deactivates an extension.

## Extensions

Every other command — `wiqd agent create`, `wiqd agent provision`, `wiqd agent monitor`, `wiqd agent eval` — is contributed by an **extension**. An extension is a package that ships:

- A manifest describing the commands it adds, the options each one accepts, how to render the result, and what to validate after the upstream tool runs.
- Optionally, transform scripts that shape data flowing between you and the upstream tool.
- Doctor health checks that `wiqd doctor` aggregates.
- Optionally, Copilot skills and a VS Code companion.

Work IQ Dev Tools ship with seven extensions out of the box (see [Provided Extensions](/extensions/provided/)). You don't install them separately — they come with `wiqd`. Both the ATK and in-process core backends are installed and registered; `plugin-core-engine` selects one, so the unselected backend is hidden rather than absent.

## How a command flows

Take `wiqd agent provision --env local`:

1. The host parses the flags and looks up `agent.provision` in its command tree.
2. It finds that the command belongs to the Agents Toolkit extension.
3. It resolves the upstream `atk` binary (env var override, then bundled, then `PATH`).
4. It runs preflight checks declared by the extension.
5. It spawns `atk` with the right arguments, plus its non-interactive flag so Work IQ Dev Tools own the prompt experience.
6. After `atk` exits, the host validates the filesystem postconditions the extension declared.
7. It renders a clean success/failure message — or maps the upstream error to something human-readable.

The same shape applies to every extension command. **Exit code plus filesystem postconditions are the source of truth** — Work IQ Dev Tools never try to guess success from upstream stdout text.

## What this means for you

- If a command is failing, run `wiqd doctor`. For managed tools such as Work IQ and Eval, use `wiqd exec <cli> --version` rather than a PATH copy; use `atk --version` only when the ATK rollback backend is selected.
- If you want to know exactly what Work IQ Dev Tools are doing, run with `--verbose` — the raw upstream output goes to stderr.
- If you need to script around Work IQ Dev Tools, use `--json` — it's stable across extensions and the host wraps everything in the same envelope.
- If a command you expect isn't there, run `wiqd ext list` to confirm the right extension is loaded.

## Go deeper

- [Provided Extensions](/extensions/provided/) — what each bundled extension does
- [Exit codes & output](/concepts/exit-codes-output/) — the contract scripts can rely on
- [`wiqd ext list`](/cli/reference/#wiqd-ext-list), [`wiqd ext show`](/cli/reference/#wiqd-ext-show) — inspect what's loaded
- [`wiqd doctor`](/cli/reference/#wiqd-doctor) — health check every upstream tool
