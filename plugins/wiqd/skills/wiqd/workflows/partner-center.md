---
name: partner-center
description: >
  Guide third-party (3P) partners and ISVs through publishing a declarative
  agent to the Microsoft commercial marketplace via Partner Center. Covers
  prerequisites, building the submittable package with wiqd, enrolling and
  setting up a Partner Center account, creating the Microsoft 365 and Copilot
  offer, uploading the package, completing the store listing, submitting for
  certification, going live, and troubleshooting rejections.
trigger-summary: 'publish to partner center, submit to appsource, list in the store, certify my agent, get my agent in the marketplace, why did certification fail'
triggers: >
  how do I publish my agent, publish to Partner Center, submit to Partner Center,
  submit my agent for review, publish to AppSource, submit to AppSource,
  submit my agent to the store, list my agent in the store, get my agent into
  the Microsoft 365 store, get my agent into the Teams store, get my agent into
  the Copilot store, ship my agent to the marketplace, certify my agent,
  certification failed, why did my agent get rejected, store listing,
  how do partners publish, ISV publishing
targets: ['3p']
routing-label: 'Partner Center publishing (3P)'
routing-intent: 'Publishing a declarative agent to the Microsoft commercial marketplace via Partner Center'
routing-order: 8
contract-version: 1
routing-requires: [agent validate, agent package]
wiqd-lifecycle-theme: Publish
wiqd-lifecycle-order: 2
journey: |
  [Publish]
  order: 5
  targets: 3p
  box-item: partner-center
  entry: Agent packaged and previewed; ready for the public marketplace
  goal: Get the agent certified and listed in the Microsoft commercial marketplace
  workflow-desc: for public 3P publishing via Partner Center
  exit: Agent certified and live in the Microsoft 365, Teams, and Copilot store
  iteration: Store feedback / reviews → loop back to Build/Improve → re-package → re-submit with a bumped version
  signal: Partner (3P), package ready, not yet in the store => **Publish** via Partner Center
  plan-step: 80 | package + submit to Partner Center [3p]
---

# Partner Center Publishing (3P)

Guides **third-party partners and ISVs** through publishing a declarative agent to
the **Microsoft commercial marketplace** (AppSource / the Microsoft 365, Teams,
and Copilot store) using **Partner Center**.

wiqd owns the lifecycle **up to and including building the submittable package**.
**Partner Center owns certification and the store listing** — wiqd does not submit
on the partner's behalf. The goal of this workflow is to get a validated package,
then drive it through the Partner Center submission and certification flow.

> **Convention:** When calling wiqd commands from a skill context, always use
> `--json` for commands that produce output the model needs to parse.

> **Scope:** This is the public 3P path. Publishing to an org's own admin catalog
> is a different flow (`wiqd agent publish --env <env>`), and Microsoft-internal
> first-party publishing (ring-based rollout to M365 tenants) is out of scope.

## Routing

| User intent | Action |
|-------------|--------|
| "How do I publish / submit / ship my agent to the store", "publish to AppSource", "get into the marketplace" | Follow the **Publishing journey** below |
| Detailed store-listing checklist, icon/URL requirements, per-field guidance | Read `references/wiqd-core/partner-center.md` → Store listing checklist |
| "Certification failed", "my agent was rejected", troubleshooting a submission | Read `references/wiqd-core/partner-center.md` → Troubleshooting rejections |
| Build the submittable `.zip` | Read `references/wiqd-core/package.md` — run `wiqd agent package` |
| Fix identified validation findings before submitting | Hand off to `workflows/validation.md` for authorized same-mode repair; return to this publishing journey afterward. |
| Pre-submission readiness check ("will my agent pass review?") | Hand off to `workflows/validation.md` for Marketplace validation, including package checks on the same final ZIP. |

## The publishing journey at a glance

```
Build & validate → Package → Package validation + policy advice → Enroll in Partner Center → Create offer
   → Upload package → Complete listing → Submit → Certification → Go live
```

| Phase | Partner does | Tool / surface |
|-------|--------------|----------------|
| Build & validate | Finalize the agent, fix saved-source errors | `wiqd agent validate --mode source` with the packaging path/environment |
| Package | Build the distributable `.zip` | `wiqd agent package` |
| Package validation | Require the final `.zip` to pass package validation | `wiqd agent validate --mode package --package-file "<final.zip>"` |
| Marketplace readiness | Show policy findings as non-blocking warnings | `workflows/validation.md` when listing/evidence inputs are available |
| Enroll | Get a verified Partner Center account | Partner Center |
| Create offer | Start a Microsoft 365 and Copilot offer | Partner Center |
| Upload | Upload the app package `.zip` | Partner Center |
| Listing | Descriptions, screenshots, categories, URLs | Partner Center |
| Submit | Submit for review | Partner Center |
| Certification | Automated + manual validation | Microsoft |
| Go live | App is listed in the store | Store |

## Step 0 — Prerequisites

Before touching Partner Center, confirm the partner has:

1. **A working, tested agent.** Provision and preview it first ("provision my
   agent", "share my agent") so it behaves correctly before external users can
   install it.
2. **Clean saved source.** Run `wiqd agent validate --mode source` with the same
   project/environment as packaging and resolve errors. This checks source, not final ZIP acceptance.
3. **Icons that meet store requirements:** color icon **192×192 px** PNG, outline
   icon **32×32 px** transparent monochrome PNG.
4. **A publicly reachable Privacy Policy URL and Terms of Use URL** — both are
   mandatory for the store listing.
5. **A Partner Center account** (Step 3) — enrollment and verification take time,
   so start early.
6. **Company / publisher details** — display name, support contact, and website.

> **Tip:** Fixing icon sizes, missing privacy URLs, and manifest validation
> errors *before* submission avoids the most common certification rejections.
> See `references/wiqd-core/partner-center.md` for the full pre-flight checklist.

## Step 1 — Build the submittable package

Use wiqd to produce the distributable `.zip` — this is the artifact uploaded to
Partner Center. Require source validation to pass before building.

```bash
# Check saved source for the same project and environment before building
wiqd agent validate --mode source --path "<project>" --env prod

# Build the package (use the production environment)
wiqd agent package --path "<project>" --env prod --output "<final.zip>"
```

The build produces an app package `.zip` under the project's `appPackage/`
directory containing the manifest, icons, and declarative agent / plugin
definitions. **This is the file the partner submits.** If `wiqd agent package`
reports errors, resolve them first — re-run `wiqd agent validate --mode source` with the same path/environment for
manifest-level problems and use `--verbose` for the full upstream output. For
packaging details, read `references/wiqd-core/package.md`.

## Step 2 — Validate the package and show Marketplace advice

Before guiding any Partner Center upload or submission, run:

```bash
wiqd agent validate --mode package --package-file "<final.zip>" --json
```

Require `validation.result == "PASSED"` from this independent package run on the
exact final ZIP. Missing, malformed, mismatched, `FAILED` or `ERROR` package
results stop upload/submission guidance. Read successful results from `data` and
completed non-pass results from `error.data`.

Marketplace policy checks are advisory for publishing. When listing/evidence
inputs are available, follow `workflows/validation.md` in Marketplace mode on
the same ZIP. Otherwise warn that policy readiness is unverified and continue
after the package gate passes; do not make listing/evidence collection a new
publishing prerequisite. Surface policy findings, skipped checks, missing/malformed
reports and `FAILED`/`ERROR` policy outcomes as warnings, not publication blockers.
Do not require policy repair, a passing Marketplace result or a waiver. Preserve
actual results and report links; this is not official certification or publication
authorization.

Marketplace mode also runs package/TDP checks. Do not treat its combined result
as policy-only or let an actual package failure/incomplete check be hidden by
this advisory rule. Do not change the ZIP between validation and upload. If
source/ZIP changes, rerun applicable source/package validation before resuming.
Marketplace policy checks are not a prerequisite for tenant LOB or org-catalog
publishing, sideloading, or ordinary audience/ring sharing.

## Step 3 — Enroll in and set up Partner Center

1. Go to the **Partner Center dashboard**: <https://partner.microsoft.com/dashboard>
2. **Enroll the organization** in the Microsoft commercial marketplace program if
   not already. Enrollment requires organizational verification and can take
   several business days — do it early.
3. Set up the **publisher profile**: legal business name, publisher display name
   (shown to customers), and support contact.
4. Confirm the account has the **Microsoft 365 and Copilot** (Office Store)
   program enabled — this is the program that lists Teams apps, Microsoft 365
   apps, and Copilot agents.

## Step 4 — Create the offer

1. In Partner Center, open **Marketplace offers** and create a **new Microsoft 365
   and Copilot offer** (Teams app / Office Store offer).
2. Give the offer an internal **offer ID** and **alias** — for the partner's own
   tracking; not shown to customers.
3. Choose the **listing type / plan** appropriate to the agent (for a declarative
   agent shipped as a Teams/M365 app, this is a standard store listing).

## Step 5 — Upload the package

1. In the offer's **Package / Technical configuration** section, **upload the
   `.zip`** built in Step 1.
2. Partner Center reads the manifest to pre-populate offer metadata (app name,
   version, capabilities). Verify these look correct.
3. To push a new version later, **bump the `version` field in the app manifest**
   (`appPackage/manifest.json`) and re-run `wiqd agent package` before uploading
   again — Partner Center rejects a re-upload with the same version.

## Step 6 — Complete the store listing

Fill in the customer-facing listing. Certification checks these, so be thorough:
app name and descriptions, screenshots, category / search terms, icons (matching
the package), the mandatory Privacy Policy and Terms of Use URLs, support contact,
publisher website, and supported languages / markets. For the complete
field-by-field checklist and asset requirements, read
`references/wiqd-core/partner-center.md`.

## Step 7 — Submit for certification

1. Review every section — Partner Center flags incomplete sections before it lets
   the partner submit.
2. Click **Submit** (or **Publish**) to send the offer for review.
3. The agent goes through **AppSource / Office Store certification**:
   - **Automated validation** checks the package, manifest schema, and icons.
   - **Manual review** checks content, security, privacy, consent, and — for
     Copilot/AI agents — responsible-AI and data-handling requirements.

Certification typically takes a few business days but can take longer for
AI-powered agents given the additional scrutiny.

## Step 8 — Go live

- Once certified, the offer moves to **Publish** and the agent becomes available
  in the **Microsoft 365, Teams, and Copilot store** for the selected markets.
- Apps go live **globally after certification** (subject to market selection) —
  there is no ring-based rollout on the 3P path.
- To ship an update, repeat Steps 1, 2, and 5–7 with a **bumped manifest version**
   so the newly built package passes package validation before upload and
   certification; Marketplace policy findings remain advisory.

## Troubleshooting

When a submission is rejected, Partner Center returns specific reviewer feedback.
Address **every** item through authorized repair, source-check and re-package if the
source changed, then rerun package validation on the new ZIP before resubmitting.
Marketplace policy findings remain advisory. For a symptom → cause → fix
table covering the common rejections (duplicate version, icon format, missing
privacy/terms URLs, consent/permission flags, responsible-AI feedback), read
`references/wiqd-core/partner-center.md` → Troubleshooting rejections.

## Related commands

- `wiqd agent validate --mode source` — same-path/environment pre-build workflow gate.
- `wiqd agent validate --mode package --package-file "<final.zip>"` — required final ZIP package gate.
- `wiqd agent validate --mode marketplace --package-file "<final.zip>"` — package plus policy readiness through the canonical workflow; policy findings are advisory for publishing.
- `wiqd agent package` — builds the `.zip` uploaded to Partner Center.
- `wiqd agent provision` / `wiqd agent share` — provision and preview with early
  users before publishing publicly.
- `wiqd agent publish --env <env>` — different path: publish to an org's own admin
  catalog (tenant-internal), **not** the public store.
