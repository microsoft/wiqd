---
title: Validate · Agentic workflows
description: Agent validation and authorized repair in coding-agent sessions.
---

The `microsoft.validate` extension contributes **validation** to the wiqd skill for both stable
plugin targets. Its references are composed under `references/validate`.

| File | Responsibility |
| --- | --- |
| `workflows/validation.md` | Select source/package/Marketplace, report results and collect repair authorization. |
| `references/validate/autofix.md` | Scoped source edits and same-mode revalidation, bounded to two repair rounds. |
| `references/validate/current-agent-evidence.md` | Request-bound evidence in the current host, replayed with AI off. |
| `references/validate/listing-collection.md` | Reuse or collect listing data and obtain one complete HTML confirmation. |

Generic agent validation routes here uniquely. Core still owns create/edit/package/provision and
uses explicit same-project/environment source checks before those lifecycle steps; they do not
build a ZIP just to validate source. Account setup and publication remain with the audience's
owning workflows, including their enrollment and approval boundaries. Repair does not authorize
either deployment or publication.

Source is offline one-shot diagnostics, not an LSP session and not final-package acceptance.
Package checks TDP; Marketplace checks TDP plus StoreOps on the same captured ZIP. Results use
`validation.result` from success `data` or completed non-pass `error.data`; policy-only
`report.result` is not the overall verdict. No source ZIP or report path is fabricated.

Compatible CLI/plugin upgrades and a fresh host session are required. CLI updates alone do not
refresh guidance; plugin delivery uses the native marketplace lifecycle, not extension activation.
See [Agent validation](/cli/agent/agent-validate/).
