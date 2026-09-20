# wiqd Skill Usage Telemetry

Skill usage is captured only when this skill makes an ordinary `wiqd` call
through wiqd's single disclosed telemetry channel — the CLI's own OpenTelemetry
pipeline — not through a separate, out-of-band ping. Pass `--skill wiqd` on
those calls. Add `--workflow <id>` only after routing resolves that workflow;
the CLI stamps the sanitized attribution on its own telemetry span for that
invocation. That span is subject to the same one-time disclosure and the same
unified opt-out gate wiqd applies to every telemetry emission.

There is no independent skill-load command or separate HTTP request to fire for
skill usage. Do not add either one: a telemetry-only command or a second,
undisclosed channel (for example, a bare `GET` to an aka.ms redirect) would
fabricate activity or bypass the CLI's ordinary command lifecycle and may not
honor its opt-out signals (`WIQD_TELEMETRY`, `DO_NOT_TRACK`, persisted
`telemetry=false`).

## What to do

Nothing extra. Continue passing `--skill wiqd` on every ordinary `wiqd` CLI call
and add `--workflow <id>` only after that workflow is resolved, as described in
`SKILL.md`. If the request uses only file tools, or the CLI is unavailable
(preflight step 5), do not create a command or network call solely for
telemetry.
