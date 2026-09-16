---
title: MCP-backed commands
description: Give an extension's wiqd commands an MCP server as their backend — wiqd becomes the MCP client and a tools/call is the command's execution
---

# MCP-backed commands

Most extension commands wrap an **upstream binary** (`upstream` + `argMap`) or
run a **transform** (`.mjs`). This page covers a third backend: an
[**MCP**](https://modelcontextprotocol.io) server. An extension declares the MCP
servers it can reach (`mcpBackends`) and binds a command to a specific server +
tool (`mcpCall`). When the command runs, **wiqd is the MCP client**: it connects,
performs the `initialize` handshake, calls the named tool with arguments
interpolated from your options, and feeds the result into the command's normal
`transform` / `render` pipeline — exactly as if the tool result were the
upstream binary's stdout.

The result: installing an MCP extension grows wiqd's CLI with new subcommands
whose backend is an MCP service, the same way installing ATK grows
`wiqd agent …`.

> **Not the same as MCP _composition_.** A separate feature composes each
> extension's MCP servers into the plugin's `.mcp.json` so **Copilot CLI /
> Claude Code** load them — there the AI host is the client and the tools
> surface in chat. This page is the inverse: the tools surface as `wiqd`
> commands you type in a terminal. The two are independent and can coexist.

## Two building blocks

### 1. `mcpBackends` — the server registry

A top-level `mcpBackends` object maps a backend id to a connection definition.
Two transports are supported: `stdio` (spawn a local server process) and `http`
(streamable HTTP to a remote server).

```jsonc
{
  "mcpBackends": {
    // Local server spawned as a child process
    "orders": {
      "transport": "stdio",
      "command": "orders-mcp-server",
      "pathEnvVar": "ORDERS_MCP_PATH",
      "args": ["--stdio"],
      "env": { "ORDERS_TOKEN": "${config.ordersToken}" },
    },
    // Remote server over HTTP, interactive OAuth
    "catalog": {
      "transport": "http",
      "url": "https://catalog.example.com/mcp",
      "auth": { "type": "oauth", "scopes": ["catalog.read"] },
    },
  },
}
```

- `stdio` resolves `command` through wiqd's binary resolver (env-var override →
  bundled package → PATH) and passes `args` + interpolated `env` to the child.
- `http` connects to `url`; `headers` and `auth` values are `${...}`-interpolated
  (see [Authentication](#authentication)). `stdio` servers are local children and
  take secrets via `env`, so `auth` applies only to `http`.

### 2. `mcpCall` — bind a command to a tool

A command declares `mcpCall` **instead of** relying on `upstream`. It names the
`backend`, the `tool`, and an `args` object interpolated from the command scope.

```jsonc
{
  "commands": {
    "additionalNamespaces": {
      "orders": {
        "lookup": {
          "description": "Look up an order by id via the Orders MCP server.",
          "options": [
            { "name": "--id", "required": true, "description": "Order id" },
            { "name": "--expand", "type": "bool", "description": "Include line items" },
          ],
          "mcpCall": {
            "backend": "orders",
            "tool": "get_order",
            "args": {
              "orderId": "${id}",
              "includeLineItems": "${expand}",
            },
            "timeoutSeconds": 60,
          },
          "render": {
            "title": "Order ${id}",
            "kind": "result",
            /* fields map upstream.structured / response … */
          },
        },
      },
    },
  },
}
```

This is deliberately the same shape and ergonomics as any other command — only
the backend block differs.

## Argument interpolation

`mcpCall.args` values are resolved with the same `${...}` engine used everywhere
else (options, `computed`, `preTransform`). Values that resolve to
`undefined` / `null` / `""` are **omitted** from the arguments object, so an
unset optional flag simply isn't sent.

## Result mapping

- The text `content` parts of a successful `tools/call` are concatenated and
  exposed as the command's `upstream.stdout` — so `transform` / `render` /
  `--json` work unchanged.
- If the tool returns `structuredContent`, it is exposed to the render scope
  (e.g. `${upstream.structured}`) so you can render structured fields.
- A result with `isError: true` maps to a non-zero exit (see
  [Exit codes](#exit-codes)).

## Output

Table (default) is drawn by the command's `render` block:

```
Order 12345
  Status      Shipped
  Total       $148.20
  Items       3
```

`--json` emits the standard envelope; the `data` payload defaults to
`{ response, structured? }` unless the command's render overrides it:

```json
{
  "status": "success",
  "command": "orders lookup",
  "data": { "response": "…tool text…", "structured": { "status": "Shipped" } }
}
```

## Exit codes

| Code  | Meaning                                                                                                                     |
| ----- | --------------------------------------------------------------------------------------------------------------------------- |
| `0`   | Tool call succeeded                                                                                                         |
| `1`   | Tool returned `isError: true`, or a tool/protocol error after a connected, authenticated session                           |
| `2`   | Config / connection / auth error: unknown backend, malformed transport, unresolved stdio command, unreachable server, handshake failure, timeout, or any failure to establish an authenticated connection |
| `130` | Cancelled (Ctrl+C) — the transport is closed and the stdio child is reaped                                                  |

See [Exit codes & output](../concepts/exit-codes-output.md).

## Authentication

Auth is declared per `http` backend under `mcpBackends.<id>.auth`. wiqd maps
each `auth.type` onto the matching mechanism:

| `auth.type`          | Mechanism                                | User present? | Use                                                  |
| -------------------- | ---------------------------------------- | ------------- | ---------------------------------------------------- |
| `none` (default)     | —                                        | —             | Open / unauthenticated server                        |
| `bearer`             | static `Authorization` header            | no            | Static token / API key via interpolated config/env   |
| `oauth`              | authorization-code + PKCE + DCR          | **yes**       | Browser sign-in brokered only by `wiqd auth login`   |
| `client_credentials` | OAuth client-credentials grant           | no            | Machine / CI with `clientId` + `clientSecret`        |
| `private_key_jwt`    | signed JWT client assertion (RFC 7523)   | no            | Machine / CI with a private key                      |

> Enterprise `cross_app_access` (SEP-990) is not part of the v1 manifest surface.
> It can be added later when there is a real backend to validate against.

### Interactive OAuth is brokered by `wiqd auth`

An interactive browser prompt must never ambush a scripted
`wiqd orders lookup --json`. So the browser round-trip runs **only** inside
`wiqd auth login`, never inside a tool-call command:

- **`wiqd auth login --interactive`** performs the one-time browser sign-in for
  each `oauth` backend and stores the resulting credentials securely.
- **`wiqd auth status`** reports whether each backend's credentials are active or
  refreshable.
- **`wiqd auth logout`** deletes the stored MCP credentials.

Tokens, refresh tokens, client secrets, and dynamic client registrations are
persisted only through wiqd's secure credential store (`keytar`). There is no
plaintext JSON token cache and no fallback to files; if secure storage is
unavailable, OAuth backends fail closed with repair guidance.

A tool-call command that needs `oauth`, finds no valid cached/refreshable
credential, or is running headless (`--json`, no TTY, CI, or `--mock`) **fails
fast** with exit `2` and a message pointing you to run `wiqd auth login` first —
it never blocks on a browser.

For the machine modes (`bearer`, `client_credentials`, `private_key_jwt`) no
browser is ever opened; credentials come from interpolated config/env, so they
work in CI as-is.

### Third-party service compatibility

OAuth 2.0 is recommended for user-present sign-in, but it is not required for
every MCP service:

| Service authentication | Extension configuration | Supported? |
| --- | --- | ---: |
| None/public | omit `auth` or use `none` | yes |
| Bearer token | `auth.type: bearer` | yes |
| API key in a static header | interpolated `headers` | yes |
| Standard interactive OAuth | `auth.type: oauth` | yes |
| OAuth machine identity | `client_credentials` or `private_key_jwt` | yes |
| SAML-only, cookies, mTLS, Kerberos/NTLM, request signing, custom token exchange | extension runtime handler or vendor gateway | not by the generic runner |

For example, a vendor API key can be supplied without adding a new auth mode:

```jsonc
{
  "transport": "http",
  "url": "https://mcp.vendor.example/mcp",
  "headers": {
    "X-API-Key": "${env.VENDOR_MCP_API_KEY}",
  },
}
```

Never place the real key in the manifest. Static headers do not implement
challenge/response, cookie acquisition, signing, or token exchange.

For automatic OAuth interoperability, the service must expose Streamable HTTP,
Protected Resource Metadata, Authorization Server Metadata, Authorization Code
with PKCE, a stable issuer, RFC 8707 resource/audience handling, and either a
pre-registered client id or Dynamic Client Registration. A refresh token is
recommended; without one, the user signs in again after the access token
expires.

If a vendor uses a non-standard protocol, prefer a standards-compatible gateway.
Otherwise, implement the flow in the extension's trusted runtime handler. A new
generic WIQD auth provider should be introduced only through a separate spec and
security review.

## Mock mode

Under `--mock` (or `WIQD_MOCK=true`), an `mcpCall` command does **not** open a
real connection — it resolves through the extension's declarative `mock`
responses, the same as a binary-backed command. This keeps CI and evals offline
and deterministic.

## Cancellation & process safety

On Ctrl+C (or an abort), wiqd closes the MCP transport in a `finally`. For
`stdio` backends the SDK reaps the spawned server through its own child handle
(close stdin → SIGTERM → SIGKILL) — wiqd never kills processes by image name.

## Examples

```bash
# Call an MCP tool as a first-class command
wiqd orders lookup --id 12345

# Machine-readable output for scripting
wiqd orders lookup --id 12345 --json | jq '.data.structured.status'

# Pre-authorize an OAuth backend once (opens a browser in an interactive shell)
wiqd auth login --interactive

# Offline / deterministic
wiqd orders lookup --id 12345 --mock

# Connection/handshake diagnostics to stderr
wiqd orders lookup --id 12345 --verbose
```
