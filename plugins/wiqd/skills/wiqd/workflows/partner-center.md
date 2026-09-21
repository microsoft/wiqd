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
| Fix manifest errors before submitting | Read `references/wiqd-core/validate.md` — run `wiqd agent validate` |
| Pre-submission store-ops readiness check ("will my agent pass review?") | Read `references/validate/store-ops-validation.md` (skill lives in the `microsoft.validate` extension) |

## The publishing journey at a glance

```
Build & validate → Package → Store Ops audit → Enroll in Partner Center → Create offer
   → Upload package → Complete listing → Submit → Certification → Go live
```

| Phase | Partner does | Tool / surface |
|-------|--------------|----------------|
| Build & validate | Finalize the agent, fix manifest errors | `wiqd agent validate` |
| Package | Build the distributable `.zip` | `wiqd agent package` |
| Store Ops audit | Gate the final `.zip` on Store policy Must-fix findings | `references/validate/store-ops-validation.md` |
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
2. **A clean manifest.** Run `wiqd agent validate` and resolve every error — a
   manifest that fails validation locally will fail certification.
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
Partner Center.

```bash
# Validate first — certification will reject an invalid manifest
wiqd agent validate

# Build the package (use the production environment)
wiqd agent package --env prod
```

The build produces an app package `.zip` under the project's `appPackage/`
directory containing the manifest, icons, and declarative agent / plugin
definitions. **This is the file the partner submits.** If `wiqd agent package`
reports errors, resolve them first — re-run `wiqd agent validate` for
manifest-level problems and use `--verbose` for the full upstream output. For
packaging details, read `references/wiqd-core/package.md`.

## Step 2 — Run the Store Ops submission gate

Before guiding any Partner Center upload or submission, read `references/validate/store-ops-validation.md` and run its **Partner Center workflow gate** against the final `.zip` produced in Step 1. Require the complete JSON report contract.

- Require every registry rule to be accounted for and every skip to include severity and applicability. If the report is missing or malformed, `data.result.mustFailCount > 0`, `data.result.blockingSkippedCount > 0`, or `data.result.label == "fail"`, show the findings and blocked checks and stop. Do not proceed to package upload or submission guidance.
- Continue only when `data.result.label == "pass"`, `data.result.mustFailCount == 0`, and `data.result.blockingSkippedCount == 0`. Show Good-to-fix findings, non-blocking skips, and manual approvals before continuing.

This gate applies only to Partner Center / public Marketplace submission. It is not a prerequisite for tenant LOB or org-catalog publishing, sideloading, or ordinary audience/ring sharing.

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
   so the newly built package passes the Store Ops gate before upload and
   certification.

## Troubleshooting

When a submission is rejected, Partner Center returns specific reviewer feedback.
Address **every** item, re-validate (`wiqd agent validate`), re-package if the
manifest changed (`wiqd agent package`), and resubmit. For a symptom → cause → fix
table covering the common rejections (duplicate version, icon format, missing
privacy/terms URLs, consent/permission flags, responsible-AI feedback), read
`references/wiqd-core/partner-center.md` → Troubleshooting rejections.

## Related commands

- `wiqd agent validate` — must pass before packaging or submitting.
- `wiqd agent package` — builds the `.zip` uploaded to Partner Center.
- `wiqd agent provision` / `wiqd agent share` — provision and preview with early
  users before publishing publicly.
- `wiqd agent publish --env <env>` — different path: publish to an org's own admin
  catalog (tenant-internal), **not** the public store.
