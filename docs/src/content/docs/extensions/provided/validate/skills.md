---
title: Validate · Agent plugins
description: Source, package and Marketplace validation and authorized repair.
---

With the WIQD coding-assistant plugin installed, ask to validate source, a package,
or Marketplace readiness, then authorize repairs if needed. Account setup and
publication are separate steps.

| Request | Scope |
| --- | --- |
| “Validate my agent”, “check source”, “check my manifest” | Offline saved-source checks. |
| “Validate this package”, “check this ZIP” | Final-package/TDP validation. |
| “Marketplace validation”, “validate for Partner Center” | Package and Marketplace policy checks on the same ZIP. |
| “Fix these validation findings”, “validate and fix” | Scoped repair when authorized, followed by same-mode revalidation. |

Source repair reruns source without a ZIP or HTML report. Package-content repair
creates an explicit new ZIP from the actual source project or bounded ZIP-only
replacements. Listing/evidence-only repair keeps the ZIP unchanged and requires
neither a source project nor a build. Both revalidate the original mode; Marketplace
refreshes evidence before checking the repaired package.
Validation alone does not authorize edits. Actionable findings offer **Fix and revalidate**
or **Not now**, unless repair was already requested or a report-only/no-questions scope applies.

Use offline `--mode source` checks while editing and before packaging or provisioning.
Validation does not replace account setup, enrollment or publishing approval. Update the CLI
and host plugin to compatible releases and start a fresh host session: updating the CLI alone
does not refresh the coding-assistant plugin.

See the [command guide](/cli/plugin-validate/) and [workflow reference](/extensions/provided/validate/workflows/).
Editor diagnostics still use the separate [LSP integration](/concepts/vscode-extension/).
