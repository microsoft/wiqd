---
title: Validate · Agent plugins
description: Source, package and Marketplace validation and authorized repair.
---

The Validate extension contributes the **validation** workflow to the existing wiqd skill in
stable public and internal plugins. It owns explicit validation and identified-finding repair,
not general authoring, account setup or publication.

| Request | Scope |
| --- | --- |
| “Validate my agent”, “check source”, “check my manifest” | Offline saved-source checks. |
| “Validate this package”, “check this ZIP” | Final-package/TDP validation. |
| “Marketplace validation”, “validate for Partner Center” | Package and Marketplace policy checks on the same ZIP. |
| “Fix these validation findings”, “validate and fix” | Scoped repair when authorized, followed by same-mode revalidation. |

Source repair reruns source without a ZIP or HTML report. Package/Marketplace repair rebuilds an
explicit new ZIP; Marketplace prepares fresh evidence in the current host session, never a nested
model. Validation alone does not authorize edits. Actionable findings offer **Fix and revalidate**
or **Not now**, unless repair was already requested or a report-only/no-questions scope applies.

Core keeps general authoring and lifecycle ownership and explicitly uses `--mode source` for
package/provision/edit prechecks. The audience's account and publishing workflows retain their
onboarding, enrollment, approval and publication responsibilities. Update the CLI
and host plugin to compatible releases and start a fresh host session: updating the CLI alone
does not refresh host skills. No validation feature flag is required.

See the [command guide](/cli/agent/agent-validate/) and [workflow reference](/extensions/provided/validate/workflows/).
Editor diagnostics still use the separate [LSP integration](/concepts/vscode-extension/).
