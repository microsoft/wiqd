---
title: Validation & MVL
description: Shared plugin and agent source/package/Marketplace validation and editor diagnostics.
---

# Validation & MVL

Validation checks a defined surface, not every aspect of a plugin. Choose the
command and scope for the project you are working on.

## Plugin validation

```bash
wiqd plugin validate --mode source --env dev
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin validate --mode package --env dev --package-file "<zip>"
```

Plugin validation uses the same runtime, modes, output and exit contract as agent
validation below. Explicitly select offline source before provisioning or packaging;
the default is package and uploads an existing ZIP. Provision before packaging so
the selected environment and app identity exist.

Plugin source additionally requires readable JSON objects in `wiqd.plugin.json`
and `appPackage/manifest.json`. It checks the canonical **declarative-agent component**
when present, not full descriptor/schema/composition validity, skills or root connectors.
No component means empty coverage; a declared component with missing canonical source
fails. Neither an empty scope nor a source pass establishes whole-plugin validity.
Package and Marketplace accept ZIP-only input without these source guards.

## Shared source, package and Marketplace validation

Both commands use three explicit scopes; for an agent project:

```bash
wiqd agent validate --mode source --path ./my-agent --env local
wiqd agent validate --mode package --package-file ./final.zip
wiqd agent validate --mode marketplace --package-file ./final.zip --listing-file ./listing.json
```

Source runs offline one-shot checks through the same `DiagnosticsService` used
by the editor LSP. It initially checks saved `appPackage/declarativeAgent.json`
and returns checked files and diagnostic codes, severities and locations.
It needs no ZIP, build, sign-in or report directory and does not start an LSP
server. This is not project-wide or final-package acceptance. Environment context
is limited to the selected `--env` (`local` by default).

Package is the default when `--mode` is omitted. It uploads a read-only copy of
an existing captured ZIP to TDP through Core. Marketplace includes that package
validation and StoreOps policy checks on the same snapshot. Neither mode builds
automatically. Select an explicit ZIP, or have exactly one nonrecursive ZIP in
`appPackage/build`; missing or ambiguous inputs fail rather than choosing the newest.
Unavailable authentication or evidence is incomplete, not an implicit pass.

Use the same project/environment for source and authorized package/provision
operations. These coding-agent prechecks are workflow gates, not newly forced
backend gates. Source has no ZIP identity and cannot prove that a later provision
uploads a previously validated package. Validation never authorizes publication.

For either command, exit `0` means passed; `1` means findings, incomplete work,
input or report-write failure; `2` means invalid source project or missing
runtime/configuration; `130` means cancelled. Read success `data` or completed
non-pass `error.data` and use `validation.result` for the overall verdict.
Warnings do not block. Package/Marketplace reports preserve captured inputs;
source has no HTML report.

Old modes `static`, `deep`, `manifest` and comma-combined selections are
rejected with migration guidance for both commands, not silently mapped to uploads.

## Real-time validation in VS Code

The [VS Code extension](/concepts/vscode-extension/) starts `wiqd agent lsp`
for live open-buffer diagnostics, hovers and available quick fixes. Unsaved
buffers and editor-only advisory checks can differ from saved-source results;
neither promises identical editor and final-ZIP findings.

## Go deeper

- [Agent validation guide](/cli/agent/agent-validate/) - options, JSON, authorized repair and compatible CLI/plugin upgrades with fresh sessions
- [Plugin validation](/cli/reference/#wiqd-plugin-validate) - shared modes and plugin source requirements
- [Exit codes & output](/concepts/exit-codes-output/) - shared command contract
- [Validate extension](/extensions/provided/validate/) - runtime and LSP integration
- [Build a Plugin](/getting-started/build-a-plugin/) - plugin delivery
