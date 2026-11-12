---
title: wiqd publish pc
description: Reference for direct declarative-agent publishing to Partner Center, including update selectors, consent, authentication limits, and errors.
---

# wiqd publish pc

Prepares and submits supported declarative-agent packages for Partner Center certification. The public launch branch targets `@microsoft/wiqd` 0.25.0 with Marketplace bundled and enabled by default; confirm the installed artifact with `wiqd --version`, `wiqd ext list`, and command help. Explicit removal/disablement is respected. For enrollment, exact-ZIP validation, and sign-in, see [Publish to Partner Center](/getting-started/publish-to-partner-center/).

## Synopsis

```bash
wiqd publish pc (--interactive | --authorize-submit) [publishing inputs] [--package-env <name>]
wiqd publish pc access
wiqd publish pc init [--product-id product/<GUID>]
wiqd publish pc preflight [publishing inputs] [--package-env <name>]
wiqd publish pc prepare [publishing inputs] [--package-env <name>] --yes
wiqd publish pc submit --product-id product/<GUID> --yes (--interactive | --authorize-submit)
wiqd publish pc update (--dry-run | --yes) [--fields <paths>] [--update-package | --package <zip>] [--logo] [--screenshots --screenshot-mode <add|replace>]
wiqd publish pc status [--product-id product/<GUID> | --job-id <id>] [--watch]
```

## Subcommands

| Subcommand | What it does | Changes Partner Center? |
| --- | --- | --- |
| `pc` (bare) | Runs `preflight`, `prepare`, and `submit` in order. Stops at the first failure. | Yes |
| `access` | Prints links to the Partner Center setup you need. | No |
| `init` | Adds missing sections to `partner-center.json`. | No |
| `preflight` | Checks your config, files, and any linked offer. | No |
| `prepare` | Creates the offer, fills in the Draft, and uploads files. | Yes |
| `submit` | Sends the prepared Draft to certification. | Yes |
| `update` | Previews or applies changes to an offer that already has files or a submission. Doesn't submit. | Yes, with `--yes` |
| `status` | Reports where your submission is. | No |

## Options

### Common options

| Flag | Default | Description |
| --- | --- | --- |
| `--path <dir>` | `.` | Your plugin project folder. |
| `--listing <file>` | `partner-center.json` | Must resolve to the selected project's canonical `partner-center.json`, not a separate validation `listing.json` or arbitrary config path. |
| `--json` | Off | Print JSON instead of readable output. |
| `--mock` | Off | Return sample results without reading your project or calling Partner Center. |

### Publishing inputs

Bare `pc`, `preflight`, and `prepare` take these. Each overrides the matching value in `partner-center.json` for that run.

| Flag | Description |
| --- | --- |
| `--package <file.zip>` | Upload this package instead of a fresh build. Needs `--release-notes`. |
| `--release-notes <text>` | Notes for certification reviewers, 1 to 2,500 characters. Not shown to customers. |
| `--availability-date <timestamp>` | ISO date and time with seconds and a timezone, like `2026-11-01T17:00:00Z`. At least 24 hours out. |
| `--package-env <name>` | The environment to build a fresh package for. Defaults to `local`. Ignored with `--package`. |

### Confirmation flags

| Flag | Used by | Description |
| --- | --- | --- |
| `--yes` | `prepare`, `submit`, `update` | OKs Draft changes and uploads. Doesn't authorize submission on its own. |
| `--interactive` | bare `pc`, `submit` | Prompts you to type `submit`. Needs a real terminal. |
| `--authorize-submit` | bare `pc`, `submit` | Authorizes this one run without a prompt, for pipelines. |
| `--dry-run` | `update` | Previews changes without applying them. |

Use exactly one of `--interactive` or `--authorize-submit`.

### Update options

`update` gets its Product from the selected project's `partner-center.json`,
not `--product-id`. Link an unbound project with `init --product-id` first.
Use `--dry-run` to inspect, or explicit selectors with `--yes` to apply.
Do not combine `--dry-run` and `--yes`.

| Flag | Description |
| --- | --- |
| `--fields <paths>` | Comma-separated supported configuration paths. Apply only those listing/legal/availability fields, preserving other remote values. |
| `--update-package` | Bump the local manifest version and build/upload a fresh package. |
| `--package <zip>` | Use an existing ZIP whose embedded version exceeds the local/recorded successful baseline. Does not rewrite the ZIP or bump the source manifest. |
| `--package-env <name>` | Lifecycle environment for a fresh build; defaults to `local`. |
| `--listing-only` | Records intent; does not skip the package/version change or select fields. |
| `--logo` | Replace the listing logo with the configured project file. |
| `--screenshots` | Upload configured screenshots. Resulting listing must contain 1 to 5 screenshots with captions. |
| `--screenshot-mode add\|replace` | Explicitly preserve/add to or replace the screenshot set. Requires `--screenshots`. |
| `--interactive` | Ask add versus replace at a real terminal if screenshot mode is omitted. Never authorizes submission. |
| `--submit` | Unsupported. Finish submission of an updated Draft in Partner Center. |

Supported `--fields` values are `listing.title`, `listing.description`,
`listing.searchResultSummary`, `listing.categories`, `listing.industries`,
`listing.requiresAssociatedServicePurchase`, `listing.legal.privacyPolicyUrl`,
`listing.legal.supportDocumentUrl`, `listing.legal.termsConditions`,
`listing.legal.termsOfUseUrl`, `listing.certification.notesToReviewer`, and
`availabilityDate`. Identity, language, hide key, and generated digests are not
generic editable fields.

```bash
wiqd publish pc update --fields listing.description --dry-run --json
wiqd publish pc update --fields listing.description --yes --json
wiqd publish pc update --screenshots --screenshot-mode add --dry-run --json
wiqd publish pc update --screenshots --screenshot-mode add --yes --json
```

Every applied non-no-op update carries a higher-version package, even a
listing/media-only change. Without `--package`, it bumps and packages local
source; the preview is not byte-level validation of that future ZIP.
`--yes` alone selects no changes. In-flight certification refuses updates.
After `applied: true`, inspect and submit the Draft in Partner Center;
earlier CLI preparation authorization is invalidated. See the
[existing/rejected-offer walkthrough](/getting-started/publish-to-partner-center/#update-an-existing-or-rejected-offer).

### Automation authentication

Marketplace requires its own existing protected OS session under the runner's
OS identity. `--authorize-submit` grants invocation-scoped consent, not credentials.
Core `CI_ENABLED`/`M365_*` credentials do not authenticate Marketplace.
This build has no supported clean-runner or app-only bootstrap. See
[Marketplace authentication in automation](/getting-started/publish-to-partner-center/#marketplace-authentication-in-automation).

## Configuration file

Everything wiqd sends to Partner Center, except the package, comes from `partner-center.json` in your project folder.

1. `wiqd auth login --interactive --tenant <seller-tenant-guid>` creates it with your seller `binding`.
2. `wiqd publish pc init` adds the missing fields, with placeholders.
3. You replace the placeholders.
4. `prepare` writes back `productId`, `package`, and `packageDigest`.

| Field | Required | What to put |
| --- | --- | --- |
| `listing.title` | No | Defaults to `name.short` in `appPackage/manifest.json`. |
| `listing.description` | Yes | What your plugin does. |
| `listing.searchResultSummary` | Yes | Up to 100 characters. |
| `listing.categories` | Yes | At least one category. |
| `listing.requiresAssociatedServicePurchase` | Yes | `true` or `false`: does your plugin need a separate service purchase, or have in-app purchases? |
| `listing.languageId` | Yes | Listing language. No default. |
| `listing.legal.privacyPolicyUrl` | Yes | Your privacy policy URL. |
| `listing.legal.supportDocumentUrl` | Yes | Your `https://` support page. |
| `listing.legal.termsConditions` | Yes | `standardMicrosoft` or `custom`. Choosing one doesn't accept any agreement. |
| `listing.legal.termsOfUseUrl` | For `custom` | Your `https://` terms of use. |
| `assets.logo` | Yes | Logo path inside the project folder. |
| `assets.screenshots` | Yes | 1 to 5 entries, each with a `path` and a `caption`. |
| `releaseNotes` | Yes | 1 to 2,500 characters for the package release; also required with an explicit `--package` override. Not a replacement for Notes for certification. |
| `listing.certification.notesToReviewer` | For reviewer handoff | Instructions and context for certification reviewers. Check portal readiness before submission. |
| `listing.certification.validationReport` | No | Select an existing package-bound StoreOps `report.json` and its sibling HTML. Review contents before authorizing disclosure; stale/mismatched reports are refused. Attachment verification does not prove reviewer access. |
| `availabilityDate` | Yes | At least 24 hours out when you prepare. |
| `hideKey` | Yes, at submit | Secret preview key that `init` generates. Never paste it into chat, logs, or issues. |

## Output

With `--json`, successful commands wrap their payload in `data` under the shared
success envelope. Publishing payloads include `mode`, `action`, `evidence`,
`published`, and `result`; errors use the shared error envelope and a nonzero
exit code. Save the `productId` from `prepare` and the `jobId` from `submit`.

| `evidence` | What it means |
| --- | --- |
| `not-applicable` | Nothing remote to check yet. |
| `draft-verified` | wiqd read the Draft from Partner Center. |
| `processing` | A Partner Center job is still running. |
| `job-accepted` | The job finished. Certification hasn't happened yet. |
| `submission-active` | Submission in progress, or done but not seen Live yet. |
| `live-verified` | Live. The only value with `published: true`. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Done. |
| `1` | Something needs fixing before you rerun: a flag, config value, file, or confirmation. |
| `2` | Environment, sign-in, or service problem, or wiqd couldn't confirm the outcome. Check `pc status` before retrying. |
| `3` | The wiqd EULA hasn't been accepted. |
| `130` | Cancelled. IDs Partner Center already accepted are kept. |

## Common errors

| Code | What happened | What to do |
| --- | --- | --- |
| `PC_LISTING_MISSING` | No `partner-center.json`. | Run `wiqd auth login --interactive`, then `pc init`. |
| `PC_MISSING_REQUIRED_FIELD` | Required fields are empty. | Fill in the fields the message lists. |
| `PC_LISTING_INVALID` | A value has the wrong format. | Fix the field named in the message. |
| `PC_CONSENT_REQUIRED` | `prepare` or `submit` ran without `--yes`. | Add `--yes`, or `--dry-run` for `update`. |
| `PC_SUBMIT_AUTHORIZATION_REQUIRED` | No submission mode, or no real terminal. | Use `--interactive` at a terminal, or `--authorize-submit`. |
| `PC_SUBMIT_AUTHORIZATION_DECLINED` | You didn't type `submit`. | Rerun when ready. Nothing was sent. |
| `PC_DRAFT_NOT_FOUND` | No prepared Draft. | Run `pc prepare --yes` first. |
| `PC_ALIAS_UNRESOLVED` | `name.short` is missing in `appPackage/manifest.json`. | Set it and rerun. |
| `PC_PUBLISH_UPLOAD_REFUSED` | A file is empty, too big, outside the project, or a symlink. | Fix the path. |
| `PC_CONFIG_CHANGED` | Files changed mid-run. Nothing was submitted. | Rerun without editing. |
| `PC_UPDATE_REQUIRED` | The offer already has files or a submission. | Use `pc update --dry-run`. |
| `PC_UPDATE_PRODUCT_REQUIRED` | No Product is recorded for update. | Link the intended existing offer with `pc init --product-id product/<GUID>`. |
| `PC_NOT_IMPLEMENTED` | Unsupported update intent, such as `--submit` or `--yes` without selectors. | Select supported fields/package/media; review and submit the updated Draft in the portal. |
| `PC_SCREENSHOT_MODE_REQUIRED` | No explicit add/replace choice. | Ask the publisher, then pass `--screenshot-mode add` or `replace`. |
| `PC_SUBMISSION_IN_PROGRESS` | The offer is in certification. | Wait, and check `pc status`. |
| `PC_VERIFICATION_PENDING` | `--watch` timed out. Not a rejection. | Check again later. |
| `PC_OUTCOME_UNKNOWN` | wiqd couldn't confirm a change. | Check `pc status` or Partner Center before retrying. |
| `PC_RESERVATION_LOST` | wiqd lost its local lock. | Use a non-synced folder, check `pc status`, then rerun. |
| `PC_AUTH_*` | Sign-in problem. | Rerun `wiqd auth login --interactive --tenant <seller-tenant-guid>`. |

## Limitations

- **One `prepare` per offer.** Use `update` for later changes.
- **One seller per sign-in.** If sign-in picks the wrong seller, sign in with another account.
- **`resume` is simulated, not live recovery.** If a run stops partway, check `pc status` and Partner Center.
- **Updates do not submit.** Apply explicit selectors, review the Draft, then submit in Partner Center.
- **No clean-runner Marketplace authentication.** Core pipeline credentials do not establish this extension's session.
