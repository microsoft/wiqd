---
title: Validate · Agentic workflows
description: Agent validation and authorized repair in coding-agent sessions.
---

Ask your coding assistant to validate saved source, check a final ZIP, or assess
Marketplace readiness. It selects the requested scope, reports findings, and
asks before making repairs unless you already authorized them.

For Marketplace checks, review the listing information and separately authorize
any eligible live testing. After validation, choose **Fix and revalidate** or
**Not now**. Repairs rerun the original validation mode, with at most two authorized
repair rounds. Package-content changes require a new ZIP; listing/evidence-only
changes retain the original ZIP.

Use source checks before packaging or provisioning with the same project and
environment. Source checks need no build. Validation and repair do not authorize
deployment or publication; account setup, enrollment and approval remain separate.

Source is offline one-shot diagnostics, not an LSP session and not final-package acceptance.
Package checks TDP; Marketplace checks TDP plus StoreOps on the same captured ZIP. Results use
`validation.result` from success `data` or completed non-pass `error.data`; policy-only
`report.result` is not the overall verdict. Source checks return diagnostics without
a ZIP or HTML report.

Compatible CLI/plugin upgrades and a fresh host session are required. CLI updates alone do not
refresh guidance; update the coding-assistant plugin through its marketplace.
See [Validate command guide](/cli/plugin-validate/).
