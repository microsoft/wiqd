# Remote agent card

Use `wiqd agent show --id <deployed-id>` or `--name <deployed-name>` for a
deployed agent. ID takes precedence when both are supplied. Local project
inspection is `wiqd plugin show`; `agent show` never requires or reads a local
project.

The command calls Work IQ's real `agents get-card` operation. It does not derive
a card from `agent list`. For a generated project, use the built app manifest's
resolved `name.short` as the lookup name, not the declarative-agent name or the
project directory name. Scaffolding can shorten the app name before adding an
environment suffix; do not reconstruct it yourself.

The pinned Work IQ 1.0.0 returns sectioned console output, not JSON. WIQD accepts
only that verified shape or the previously supported Markdown card. Missing or
duplicate required fields, conflicting IDs, unexpected content and other
formats fail explicitly. The console heading can be the complete deployed ID
instead of a display name. WIQD preserves that ID when its Identifiers bullet
agrees (including the formatter's observed omission of the prefix underscore).
Console output does not render description or skills; these are an empty string
and array with a warning, not inferred from a local project or a list summary.
Canonical `T_`, `P_` and `U_` header IDs retain their underscore. Only the
Identifiers bullet's observed missing underscore is normalized; different
prefixes, GUIDs or component IDs are rejected, not repaired.

A name-selected card is only a candidate, not proof that it belongs to a
particular installation. Prefer an explicitly supplied runtime ID with `--id`.
If the opened installation shows a different runtime ID, stop target calls and
verify that exact ID before confirming the target association again. Do not
construct a runtime ID from the installation title or reuse evidence from the
other candidate.

Work IQ 1.0.0 does not render its underlying A2A endpoint or
state-transition-history capability. WIQD reports those values as `null` with a
warning rather than fabricating them.

The pinned CLI can return “agent not found” with exit zero. WIQD maps that exact
failure response to `AGENT_NOT_FOUND`, not a card-parser error. A failed lookup
does not establish that provisioning failed: retain the existing deployment and
check the built app name, account and tenant without recreating it.
