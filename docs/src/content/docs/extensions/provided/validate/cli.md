---
title: Validate · CLI commands
description: Every command contributed by Work IQ Dev Tools' Validate extension
---

# Validate · CLI commands

Use these commands for validation, listing information and package repair:

| Command | What it does |
|---------|--------------|
| [`wiqd plugin validate`](/cli/plugin-validate/) | Source, package (default), or Marketplace including package checks. |
| `wiqd plugin add market-listing` / `wiqd plugin get market-listing` / `wiqd plugin preview market-listing` | Save/read listing data and generate the whole-listing HTML review; no validation or publication. |
| `wiqd plugin repair package` | Create a new ZIP from explicit replacements without changing the original; no validation or publication. |

`--mode source` checks saved source offline. It does not require a ZIP/sign-in
or write reports. Package uploads the selected ZIP to Teams Developer Portal (TDP);
Marketplace includes TDP and StoreOps checks on those same bytes.
No validation mode builds automatically. See the [command guide](/cli/plugin-validate/) for inputs,
same-mode repair and upgrade notes.

## Plugin validation JSON

Read success `data` or completed non-pass `error.data`, and use `validation.result`
for the verdict. Confirmed blockers yield `FAILED`; without blockers, incomplete
provider execution yields `ERROR`. Completed validation with no must-fix findings
is `PASSED`, even when individual Marketplace policies remain unverified or
warnings/suggestions remain. A pass is not complete policy coverage or certification.
Source includes checked files and located diagnostics but writes no reports.
Source checks require valid `m365agents.yml` and `appPackage/manifest.json` in the project;
no declarative-agent component means explicit empty coverage, not full plugin acceptance.
Package/Marketplace accept ZIP-only inputs and preserve JSON/HTML reports.
Mock results are marked `simulated`. Replace retired `agent validate` commands
with `plugin validate`. Old `static`, `deep`, `manifest` and comma-combined modes
are rejected with migration guidance.

## Editor checks

The [VS Code extension](/concepts/vscode-extension/) starts editor diagnostics
automatically. Use `wiqd plugin validate --mode source` for an offline CLI or CI
check of saved files.
