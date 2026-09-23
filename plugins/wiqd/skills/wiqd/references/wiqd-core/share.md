# Agent Share

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Share a provisioned agent with specific people, a security group, or the entire tenant.

## Guided target selection (inspection-first)

When the user asks to share, resolve the target from what they already said before asking anything:

- They named or supplied **email addresses** (`--email`, or "share with alice@…") → direct user share, below. Do not ask again.
- They asked to share with a **team / group / distribution list** → security-group share, below. Collect the group's mail address if it wasn't given.
- They asked to share with **everyone / the whole org / the tenant** → tenant share (use with caution; confirm first).
- Nothing is explicit → ask **one** question. This target-agnostic question offers three targets: _"Share with specific email address(es), a security group, or your whole tenant?"_ — then collect only the missing input. On a **first-party** install a separate overlay **extends this same question with a fourth, discoverable menu item** (a supported common audience); that fourth option is owned entirely by the overlay (see the note below).

> First-party agents have an **additional** common-audience target contributed by a separate first-party overlay when installed. This core reference stays **target-agnostic**: it covers only the email/group/tenant targets exposed by `wiqd agent share`, and deliberately does **not** name the specific common audiences or the package sidecar that back them. When the active install includes the overlay, that overlay **extends this one question with a fourth, discoverable menu item** on 1P installs (it is not a hidden path requiring magic words) and owns the common-audience branch end-to-end — including its execution dependency. On a pure third-party install the menu stays at the three targets above.

### Composition handoff — where the fourth target comes from

This reference is the **routing owner** for share intent, including the generic
"share my agent" request. The fourth menu item is not defined here; it is
composed in from the first-party overlay. Resolve it like this:

1. **Before presenting the guided question, check whether the `1P agent authoring`
   workflow is in the active routing set** (it ships only from the first-party
   `microsoft.1p-agents` extension).
2. **If it is present** — read its _Common-audience sharing_ section and present a
   **single four-item menu**: the three targets above plus the overlay's target.
   The overlay owns that branch end-to-end; do not re-derive it here. This applies
   to a plain "share my agent" request too, not only to a request that already
   names the overlay's audience — a generic share intent MUST still surface all
   four options on a 1P install.
3. **If it is absent** (pure third-party install) — present exactly the three
   targets above. Never mention or promise a fourth target that no active
   extension contributes.

When `plugin-core-engine == fxcore`, this reference is the active owner for the
three standard share targets. The optional first-party overlay may extend the
guided menu, but all standard branches continue through the core-backed
`wiqd agent share` commands below.

## Commands

### Share with specific users (recommended starting point)
```bash
# Share with specific users — they get immediate access
wiqd agent share --json --skill wiqd --scope users --email "user1@org.com,user2@org.com" --env <env>
```

### Share with a security group

The core-backed `--email` input accepts individual users or mail-enabled groups.
There is no separate `--scope group` value. Share with a group by passing the
group's **mail address** through `--email` under `--scope users`:

```bash
# Share with a mail-enabled security group / distribution list
wiqd agent share --json --skill wiqd --scope users --email "eng-copilot@org.com" --env <env>
```

- Do **not** invent a `--scope group` flag or any group-specific option.
- wiqd does not resolve a group's address from a display name; collect the group's mail address from the user (do not invent it).
- A non-mail-enabled security group has no address to pass; if the user's group isn't mail-enabled, say so rather than guessing.

### Share with entire tenant
```bash
# Share with everyone in the tenant — use with caution
wiqd agent share --json --skill wiqd --scope tenant --env <env>
```

### Remove shared access
```bash
wiqd agent share remove --json --skill wiqd --users "user@org.com" --env <env>
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--scope` | Share scope: `users` (individual people or a group address) or `tenant` | `users` |
| `--email` | Comma-separated addresses — individual users and/or a group's mail address (required for `users` scope) | — |
| `--env` | Environment to share | `local` |
| `--path` | Agent project directory | `./` |

`share remove` is a different subcommand with a different option set — it accepts only `--users`, `--owners`, `--env`, `--path`. It does **not** accept `--email` or `--scope`; revoke by listing the addresses in `--users` (or `--owners`), and revoke a tenant-wide share by removing the users that share granted.

## Collaborator Management

### Listing who has access (read-only — do this first for "list / show access" requests)

When the user asks to **list collaborators** or **see who can administer the
agent**, this is a read-only lookup. Run the command directly and report — do
NOT enumerate project files, re-provision, or take any mutating action:

```bash
wiqd agent share collaborator list --json --skill wiqd --env <env>
```

The command reports collaborators that can administer the agent. There is no
separate `wiqd agent share list` command for enumerating the end-user audience;
do not invent one. If no environment is provisioned yet, say so instead of
provisioning.

### Managing collaborators

```bash
wiqd agent share collaborator add --json --skill wiqd --email "dev@org.com"
wiqd agent share collaborator list --json --skill wiqd --env <env>
```

The CLI currently exposes collaborator add/list, not a
`share collaborator remove` subcommand. To revoke explicit owner access, use
`wiqd agent share remove --owners ...`; do not invent a collaborator-remove
command.

## Audience Management

```bash
wiqd agent share --json --skill wiqd --scope users --email "new@org.com"       # Add users
wiqd agent share remove --json --skill wiqd --users "user@org.com" --env <env>  # Revoke user access
wiqd agent share remove --json --skill wiqd --owners "dev@org.com" --env <env> # Revoke owner access
```

## Error Recovery

- **404 error during share**: Do not provision automatically. Explain that recovery
  requires an additional cloud mutation and ask for confirmation. If confirmed,
  route through `references/wiqd-core/provision.md` for the same environment and
  path so validation runs before provisioning. Retry share only after provisioning
  succeeds.

## Critical Rules

- Agent must be provisioned (`TEAMS_APP_ID` in env file). If not → run provision workflow first.
- `M365_TITLE_ID` must exist in env file. If missing → run provision workflow first.
- Do NOT share with tenant without explicit user confirmation — this gives access to everyone.
- Collect email addresses for `users` scope — do not invent emails.
- Share with a group by passing the group's mail address to `--email`; do NOT invent a `--scope group` flag or the group's address.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
