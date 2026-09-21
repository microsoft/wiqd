# Agent List

**Telemetry:** `--skill wiqd` on every `wiqd` command.

List deployed agents from the Work IQ platform.

## Command

```bash
wiqd agent list [--name <filter>] [--id <filter>] [--top <n>] [--json] --skill wiqd
```

## Options

| Flag     | Description                                                       | Default |
| -------- | ----------------------------------------------------------------- | ------- |
| `--name` | Filter by agent name (substring match)                            | —       |
| `--id`   | Filter by agent ID                                                | —       |
| `--top`  | Maximum number of results                                         | `10`    |
| `--json` | Emit machine-readable JSON output (default: human-readable table) | `false` |

- `--name` and `--id` combine with AND logic — both perform substring matching
- Does NOT require an ATK project folder — works from any directory
- **After listing agents, always mention the available filtering options** (`--name`, `--id`, `--top`) so users know they can narrow results

## How `--json` works (important)

`--json` here is **wiqd's own output flag** — it toggles wiqd's _table-vs-JSON_ output. It is NOT forwarded upstream. The upstream `workiq agents list` command has **no `--json` option** (only `workiq ask` does). Instead, wiqd **parses workiq's human-readable text listing natively** and turns it into a structured `{ id, name, publisher }` contract that feeds **both** the human table **and** wiqd's `--json` envelope. So `wiqd agent list --json` works regardless of what shape workiq prints — there is no upstream `--json` to be "too old" for.

This is why you must run `wiqd agent list`, not `workiq agents list`: only wiqd produces structured JSON.

## Error Recovery

| Error           | Action                                     |
| --------------- | ------------------------------------------ |
| Auth error      | Tell user: _"log me in"_                   |
| No agents found | Confirm filters, suggest broadening search |

**🚫 Never bypass wiqd.** Do NOT work around `wiqd agent list` by calling `workiq agents list` directly — it emits unstructured text with no `--json`, so you lose the parsed `id`/`name`/`publisher` contract, filtering (`--name`/`--id`/`--top`), and wiqd's error mapping. wiqd is the only path that yields structured output.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
