---
title: wiqd marketplace setup
description: Install the public WIQD plugin or retain a verified public Copilot installation through native host marketplaces.
---

# `wiqd marketplace setup`

Install only the public `wiqd@wiqd` plugin from the
[`microsoft/wiqd`](https://github.com/microsoft/wiqd) marketplace in coding-agent hosts you
already installed, or retain a supported, independently verified public Copilot installation
without changing its identity. The command uses each host's native marketplace and plugin
commands, then re-reads native inventory to verify the result.

**This does not configure your complete WIQD environment.** A verified public-plugin
installation does not configure authentication, other tools, or other plugins, and does not
prove end-to-end runtime readiness.

```bash
wiqd marketplace setup [--host <host-id>] [options]
```

The command supports Copilot CLI (`copilot`) and Claude Code (`claude`). It does not install
either host, compose plugin content from local WIQD extensions, migrate an older local deployment,
or run automatically during WIQD installation or update.

The existing core extension contributes the command; it requires WIQD 0.23.0 or later and an
active, compatible core extension. There is no host-native fallback. Marketplace setup does not
initialize Microsoft 365 authentication, a tenant/project, or the lifecycle engine.
The normal WIQD EULA must already be accepted by a human. Missing or stale acceptance exits `3`
before runtime loading, the scope notice, or native work; help and hermetic `--mock` retain their
existing exemptions and never record consent.

## Options

| Option                       | Default          | Description                                                                 |
| ---------------------------- | ---------------- | --------------------------------------------------------------------------- |
| `--host <copilot\|claude>`   | —                | Override the default all-host selection and set up exactly one host         |
| `--marketplace <owner/repo>` | `microsoft/wiqd` | Marketplace identity; no other value is accepted                            |
| `--dry-run`                  | off              | Inspect native marketplace and plugin state without running add or install  |
| `--json`                     | off              | Emit one machine-readable envelope with the complete per-host report        |
| `--verbose`                  | off              | Write bounded native-operation status and exit information to stderr        |

Without `--host`, WIQD checks every registered supported host in stable registry order and skips
host binaries that are not installed. An explicitly empty or unknown `--host` value exits `2`
before host detection; it never selects all hosts. The command is fully non-interactive and closes stdin for
every native subprocess. The pre-release `--detected` design was removed before shipping and has
no compatibility alias.

For JSON compatibility, the default registry-wide report retains
`data.mode: "detected"`; an explicit `--host` invocation reports
`data.mode: "host"`. The envelope command identifier is
`command: "marketplace-setup"` with `schemaVersion: "2.1"` and `reportVersion: 2`.
Successful reports are in `data`; partial failure/cancellation reports are in `error.data`.
Pre-invocation failures, including the EULA gate, contain no report.
The mode value is report terminology, not a CLI flag.

After valid options and host selection, the command writes this exact notice once to stderr,
before any native probe or mutation, including for `--json`, `--dry-run`, and redirected streams:

```text
Public WIQD plugin only: new installs use wiqd@wiqd from microsoft/wiqd.
Verified existing public Copilot installations may be kept unchanged.
This command does not configure your complete WIQD environment.
Manual inspection and migration: https://aka.ms/wiqd/docs?id=getting-started/installation#migrating-from-a-cli-composed-plugin
```

This notice is informational, not a confirmation prompt or a success claim.
The public artifact, notice, and results are the same for all callers, including users with
additional WIQD extensions. Those extensions do not change the installation target or make
this command complete their environment setup.

## Examples

```bash
# Set up every already-installed supported host
wiqd marketplace setup

# Target Claude Code only
wiqd marketplace setup --host claude

# Preview native operations without changing either host
wiqd marketplace setup --dry-run --json
```

To display JSON results without losing a failure report or the original WIQD exit status,
including under Bash `set -e` and `pipefail`:

```bash
(
  setup_status=0
  setup_json=$(wiqd marketplace setup --json) || setup_status=$?
  display_status=0
  printf '%s\n' "$setup_json" |
    jq '{
      status,
      exitCode: (.exitCode // 0),
      error: (if .status == "error" then
        {code: .error.code, message: .error.message}
        else null end),
      results: ((.data // .error.data // {}).results // [] |
        map({hostId, outcome}))
    }' || display_status=$?
  if [ "$setup_status" -ne 0 ]; then
    exit "$setup_status"
  fi
  exit "$display_status"
)
```

Only `planned` dry-run results include a nonempty `plannedActions` list. Each entry contains
`action` (`marketplace-add` or `plugin-install`), `binary`, and the exact `args` array, in native
execution order. A fresh host plans add then install; an existing matching marketplace plans
install only. The table displays those same actions. Other outcomes omit `plannedActions`,
and all dry-run receipts describe unchanged, unattempted state.

## Safety and idempotency

Before changing a host, WIQD independently checks:

1. the `wiqd` marketplace registration and its normalized repository source; and
2. all installed WIQD candidates (`wiqd` and `wiqd@<marketplace>`), including enablement
   and source provenance.

Only a proven missing deployment can authorize installation. An unrelated/local marketplace,
disabled plugin, unknown provenance, malformed inventory, or standalone deployment fails closed.
WIQD never removes, rebinds, enables, refreshes, or rolls back host plugin state.
Conflicting registrations and unreadable marketplace inventory include a link to the
[manual migration procedure](/getting-started/installation/#migrating-from-a-cli-composed-plugin).

Exactly one enabled, source-verified `wiqd@wiqd` deployment with the matching canonical
registration produces an idempotent `skipped` result. Copilot can also retain exactly one
enabled, native-installed `wiqd@awesome-copilot` whose uniquely matching current
`awesome-copilot` registration resolves to `github/awesome-copilot`, including a default
registration. That alternative reports `installed-verified-alternative`, `skipped`, and
`changed: false`, even when the canonical registration is absent. It never authorizes
installing that alternative or adding another marketplace.

Missing/conflicting alternative registration, unknown provenance/enablement, non-installed
evidence, or the same alternative on Claude fails closed. Verified disabled deployments fail
without re-enabling them. Multiple WIQD candidates also fail unverified, even if one is the
canonical target. A conflicting `wiqd` registration takes `SOURCE_CONFLICT` precedence.
A marketplace merely listing WIQD is not an installed deployment; an affirmative empty
plugin inventory still permits canonical acquisition.

Re-running the command after a verified setup reports `skipped` with `changed: false`. A partial
failure retains receipts for any step already verified, so automation can distinguish a completed
marketplace registration from an unverified plugin install.

After installation, WIQD reads both native inventories again. A removed,
changed, ambiguous, or unreadable marketplace registration prevents success,
even if the install command exited zero. Receipts retain a completed add and
its confirmed change while reporting the latest registration observation.

Receipts export only the declared public repository sources, `microsoft/wiqd` and
`github/awesome-copilot`, or `null`. Public plugin identities are `wiqd@wiqd` and,
on Copilot only, `wiqd@awesome-copilot`, or `null`.
Null can mean unknown, unobserved, or intentionally withheld source details.
Private or undeclared source details are withheld without erasing observed presence,
enablement, or confirmed changes. A null plugin identity does not prove absence: a known
undeclared deployment is still reported as installed but unverified. Explicit local or
unresolved installed provenance is never overwritten by a matching marketplace registration.
Even with `--verbose`,
WIQD reports only bounded native-operation metadata; arbitrary native stdout/stderr is
withheld rather than filtered because it can contain private deployment details.

Every native command receives the resolved `COPILOT_HOME` or `CLAUDE_CONFIG_DIR` scope. When that
profile directory already exists, WIQD also uses it as the native working directory. On a
first-run host, WIQD uses the existing current directory instead and does not create the profile
during preflight; the host CLI still receives the intended profile environment.

The shared WIQD signal bridge handles both `SIGINT` and `SIGTERM`. Either signal exits 130
while preserving completed receipts. Each native operation has its own 60-second default
deadline. A child deadline reaps its owned tree before returning an ordinary host failure
(exit `1`); it does not abort the caller or prevent a healthy later host from proceeding.
Caller cancellation during cleanup instead takes precedence and stops later hosts.
Native stdout and stderr capture are each limited to 1 MiB. Exceeding either
limit fails the operation and cleans up its owned process tree; truncated output
is never accepted as inventory evidence.
If the operating system prevents termination or cleanup verification, the host
reports `NATIVE_CLEANUP_FAILED` and WIQD starts no further probes, mutations, or
hosts. The partial report retains completed hosts and verified steps; unfinished
mutation state is unknown, not a successful installation. Cancellation still
takes exit `130` precedence; the affected host remains `cancelled` with code
`NATIVE_CLEANUP_FAILED` so the incomplete cleanup is still visible. WIQD retains ownership and retries cleanup while
its spawned child remains live, blocking
new native launches in the same process until cleanup is verified. The report
can appear before the CLI process exits; the process may remain alive while
cleanup is unresolved. Neither CLI launcher forces shutdown through that retained
ownership. Inspect the reported receipts and resolve the owned
process before retrying; failure output is not proof that it was terminated.
After the spawned child exits, WIQD only verifies cleanup instead of signalling
a potentially reused process identifier; remaining descendants may need manual recovery.
Absent hosts are not counted as detected. Final human output includes
`Public WIQD plugin only; other environment setup is not checked.` and distinguishes:

| Outcome | Summary meaning |
| --- | --- |
| Verified new installation | Public WIQD plugin installed |
| All verified hosts already installed | Public WIQD plugin already installed |
| Dry-run with planned work | Public WIQD plugin installation planned; no changes made |
| All hosts absent | No supported hosts detected; no public WIQD plugin installed |
| Partial failure | Public WIQD plugin installation incomplete; inspect per-host results |
| Cancellation | Public WIQD plugin installation cancelled; inspect completed host results |

Standard WIQD startup/load and command-lifecycle telemetry applies with its existing
disclosures and opt-outs. This command adds no host/profile events, native output, argument
arrays, inventory, or resolved paths to telemetry. Bounded `--verbose` diagnostics stay local
on stderr.

## Exit codes

| Code  | Meaning                                                                                 |
| ----- | --------------------------------------------------------------------------------------- |
| `0`   | Every selected host has the public plugin verified installed, was absent in default all-host mode, or was planned in dry-run |
| `1`   | At least one detected host was unsupported or failed a probe, safety check, operation, or postcondition |
| `2`   | Invalid marketplace, unknown host, or an explicitly selected host binary was not found |
| `3`   | The normal root WIQD EULA gate refused missing or stale human acceptance; no report or native work |
| `130` | Cancellation; completed host and step receipts are preserved                            |

## Related documentation

- [Installation](/getting-started/installation/) — install WIQD and supported host CLIs.
- [Host vs extensions](/concepts/host-vs-extensions/) — understand the WIQD host and extension
  boundary.
- [Exit codes and output](/concepts/exit-codes-output/) — shared JSON envelope and automation
  guidance.
