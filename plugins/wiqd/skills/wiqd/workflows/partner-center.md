---
name: partner-center
description: >
  Guide third-party partners through direct Partner Center publishing when
  available, with portal guidance when disabled or unavailable. Covers exact
  package validation, publisher setup, listing choices, verified Draft
  preparation, separate submission authorization, certification observation,
  and rejection troubleshooting.
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
routing-requires: [plugin validate, plugin package]
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

wiqd can prepare and submit a verified Draft through **`wiqd publish pc`** when
the installed Marketplace extension is available. **Partner Center owns
certification and store publication.** Submission needs separate, explicit
authority for the exact operation. When direct commands are disabled or removed,
use the portal journey below without silently activating an extension or flag.

> **Convention:** When calling wiqd commands from a skill context, always use
> `--json` for commands that produce output the model needs to parse. Pass
> `--skill wiqd --workflow partner-center` on every ordinary CLI call here.

> **Scope:** This is the public 3P path. Publishing to an org's own admin catalog
> is a different flow (`wiqd plugin publish --env <env>`), and Microsoft-internal
> first-party publishing (ring-based rollout to M365 tenants) is out of scope.

## Routing

| User intent | Action |
|-------------|--------|
| "How do I publish / submit / ship my agent to the store", "publish to AppSource", "get into the marketplace" | Check installed direct-command availability, then follow **Direct publishing** or the portal journey below |
| Detailed store-listing checklist, icon/URL requirements, per-field guidance | Read `references/wiqd-core/partner-center.md` → Store listing checklist |
| "Certification failed", "my agent was rejected", troubleshooting a submission | Read `references/wiqd-core/partner-center.md` → Troubleshooting rejections |
| Build the submittable `.zip` | Read `references/wiqd-core/package.md` — run `wiqd plugin package` |
| Fix identified validation findings before submitting | Hand off to `workflows/validation.md` for authorized same-mode repair; return to this publishing journey afterward. |
| Pre-submission readiness check ("will my agent pass review?") | Hand off to `workflows/validation.md` for Marketplace validation, including package checks on the same final ZIP. |

## The publishing journey at a glance

```
Build & validate → Package → Package validation + policy advice → Enroll in Partner Center → Create offer
   → Upload package → Complete listing → Submit → Certification → Go live
```

| Phase | Partner does | Tool / surface |
|-------|--------------|----------------|
| Build & validate | Finalize the agent, fix saved-source errors | `wiqd plugin validate --mode source` with the packaging path/environment |
| Package | Build the distributable `.zip` | `wiqd plugin package` |
| Package validation | Require the final `.zip` to pass package validation | `wiqd plugin validate --mode package --package-file "<final.zip>"` |
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
2. **Clean saved source.** Run `wiqd plugin validate --mode source` with the same
   project/environment as packaging and resolve errors. This checks source, not final ZIP acceptance.
3. **Icons that meet store requirements:** color icon **192×192 px** PNG, outline
   icon **32×32 px** transparent monochrome PNG.
4. **A publicly reachable Privacy Policy URL and an explicit terms choice** —
   Microsoft Standard Contract or a custom EULA. Only custom EULA requires a
   publisher-provided public HTTPS Terms of Use URL.
5. **A Partner Center account** (Step 3) — enrollment and verification take time,
   so start early.
6. **Company / publisher details** — display name, support contact, and website.

> **Tip:** Fixing icon sizes, missing privacy URLs, and manifest validation
> errors *before* submission avoids the most common certification rejections.
> See `references/wiqd-core/partner-center.md` for the full pre-flight checklist.

## Step 1 — Build the submittable package

For **connector certification preparation**, first follow the
`workflows/plugin.md` connector certification section: create via
`connector add --prepare-for-certification`, then separately compose the exact
returned full `shared_<apiId>_<tenantId>` connector ID. Package with
`wiqd plugin package --path "<project>" --env prod --prepare-for-certification --output "<fresh-final.zip>" --json --skill wiqd --workflow partner-center`.
Keep `outputPath` and `validationOutputPath` distinct. The validation ZIP retains
the exact returned ID; the primary ZIP removes only the terminal `_<tenantId>`
GUID suffix from ConnectionVault references. Neither reference gains `_validation`.
This is opt-in, not the default for all
marketplace submissions, and does not approve or submit either artifact. Both
paths must be new; follow the existing exact-ZIP validation and submission
authorization rules for whichever artifact is selected.

Use wiqd to produce the distributable `.zip` — this is the artifact uploaded to
Partner Center. Require source validation to pass before building.

```bash
# Check saved source for the same project and environment before building
wiqd plugin validate --mode source --path "<project>" --env prod --skill wiqd --workflow partner-center

# Build the package (use the production environment)
wiqd plugin package --path "<project>" --env prod --output "<final.zip>" --skill wiqd --workflow partner-center
```

The build produces an app package `.zip` under the project's `appPackage/`
directory containing the manifest, icons, and declarative agent / plugin
definitions. **This is the file the partner submits.** If `wiqd plugin package`
reports errors, resolve them first — re-run `wiqd plugin validate --mode source` with the same path/environment for
manifest-level problems and use `--verbose` for the full upstream output. For
packaging details, read `references/wiqd-core/package.md`.

## Step 2 — Validate the package and show Marketplace advice

Before guiding any Partner Center upload or submission, run:

```bash
wiqd plugin validate --mode package --package-file "<final.zip>" --json --skill wiqd --workflow partner-center
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

## Direct publishing

Before choosing this path, inspect the installed command help using ordinary
CLI discovery. If `publish pc` is absent because Marketplace is disabled,
removed, or unavailable, explain that limitation and continue with the portal
steps below. Do not enable it, install another provider, or infer availability
from successful authentication.

After Steps 0-2 have validated the exact final ZIP:

1. Confirm Partner Center enrollment, publisher profile and program access with
   the partner. Authentication is not enrollment, legal acceptance, or readiness.
2. Direct the human to run `wiqd auth login --interactive --skill wiqd --workflow partner-center` from the intended
   project in a real terminal, optionally with `--tenant <seller-tenant-guid>`.
   Generic missing-profile login initially offers Skip Marketplace setup before
   touching protected storage. Discovery/another directory starts setup; verify
   the returned Seller Id separately and confirm the exact binding destination.
   Sign in with the home work account, targeting the seller tenant, never a guest
   object as a separate password-bearing account. No embedded sign-in or
   borrowed credentials. Never run interactive login from a redirected agent tool.
3. Initialize the verified binding, then collect the partner's explicit listing
   choices in `partner-center.json`: language, title/description/short summary,
   categories, privacy/support URLs, standard Microsoft or custom terms, a custom
   terms URL only for custom terms, release notes, availability at least 24 hours
   ahead, a listing logo, one to five screenshot paths/captions, whether a separate
   service purchase or in-app purchases are required, and up to two
   publisher-confirmed industries. Do not invent legal choices, purchase answers,
   industries, placeholder URLs, screenshots, or publisher identifiers.
4. Pass the exact validated ZIP and explicit release notes to preflight and
   preparation. Ask for Draft-work authority before using standalone `--yes`.
   Preparation must complete with a verified Draft before any submission.

```bash
wiqd publish pc init --path "<project>" --json --skill wiqd --workflow partner-center
wiqd publish pc preflight --path "<project>" --package "<final.zip>" --release-notes "<approved notes>" --json --skill wiqd --workflow partner-center
wiqd publish pc prepare --path "<project>" --package "<final.zip>" --release-notes "<approved notes>" --yes --json --skill wiqd --workflow partner-center
```

5. Obtain **explicit submission authority** for the exact verified Product,
   publisher, package and terms. `--yes` confirms preparation only.
   `submit --yes --interactive` belongs in the human's real terminal and requires
   typed confirmation. Only when the user explicitly authorizes unattended
   submission for that exact operation may you relay `--authorize-submit`.
   Never derive that authority from preparing a Draft, login, validation,
   defaults, saved configuration, or a broad request for help. Bare `publish pc`
   composes preparation/submission and must not be used for a prepare-only request.
6. Read `wiqd publish pc status --product-id "<prepared product/GUID>" --json
   --skill wiqd --workflow partner-center`. Report accepted submission, active
   certification, rejection and independently verified Live state separately.
   A successful job is not certification or publication.

Stop on pending/unknown outcomes and preserve the Product/job identifiers and
local receipts. Do not repeat create/upload/submit blindly or delete receipts
to retry. `resume` is simulated, not live recovery. Use status or Partner Center
portal recovery and explain current limits. A changed package requires fresh
validation and preparation; neither authorization mode permits stale Drafts.
Read `references/wiqd-core/partner-center.md` for listing and rejection details.

## Portal alternative

Use Steps 3-8 when direct commands are disabled/unavailable or the partner
chooses the portal. The exact-package validation and advisory-policy boundaries
from Steps 1-2 still apply.

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

Ask the publisher: **Microsoft Standard Contract or your own custom EULA?**
Present both choices without a default or inferred recommendation, including for
an existing offer. If already configured, confirm the saved choice rather than
silently changing it. Link the
[Partner Center Standard Contract guidance](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/standard-contract)
so the publisher can review the implications, including restrictions after
publication. This is not legal advice or agreement acceptance.

For Standard Contract, select `standardMicrosoft` in the offer's terms settings
and do not ask for or supply a Terms of Use URL. For custom EULA, ask for the
publisher's own publicly reachable HTTPS URL and select `custom` with that URL.
Reject malformed URLs or embedded credentials; never invent, write or host an
EULA. These names describe the terms choices, not a command on the public 3P
CLI. The partner makes and confirms the portal selection; the assistant never
accepts agreements on their behalf.

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
   (`appPackage/manifest.json`) and re-run `wiqd plugin package` before uploading
   again — Partner Center rejects a re-upload with the same version.

## Step 6 — Complete the store listing

Fill in the customer-facing listing. Certification checks these, so be thorough:
app name and descriptions, screenshots, category / search terms, icons (matching
the package), the mandatory Privacy Policy URL and confirmed terms choice
(Terms of Use URL only for custom EULA), support contact,
publisher website, and supported languages / markets. For the complete
field-by-field checklist and asset requirements, read
`references/wiqd-core/partner-center.md`.

Ask the partner explicitly: **does the plugin require purchasing a separate
service, or offer in-app purchases?** Have them confirm the Associated service
purchase answer in Partner Center; never assume No for a third-party publisher.

Offer optional **Industries** only when the plugin serves industry-specific
needs. Use the supported labels in the field reference, allow at most two, and
require partner confirmation of suggestions. Confirm **Apps** applicability and
ensure the description supports each selected industry. Leave industries unset
for a general-purpose plugin. **Clouds for Industry is managed-partner-only**;
never select it without that eligibility. Apply the same confirmed choices to
the direct configuration and the portal listing.

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

- `wiqd plugin validate --mode source` — same-path/environment pre-build workflow gate.
- `wiqd plugin validate --mode package --package-file "<final.zip>"` — required final ZIP package gate.
- `wiqd plugin validate --mode marketplace --package-file "<final.zip>"` — package plus policy readiness through the canonical workflow; policy findings are advisory for publishing.
- `wiqd plugin package` — builds the `.zip` uploaded to Partner Center.
- `wiqd plugin provision` / `wiqd plugin share` — provision and preview with early
  users before publishing publicly.
- `wiqd plugin publish --env <env>` — different path: publish to an org's own admin
  catalog (tenant-internal), **not** the public store.
