---
targets: ['3p']
---

# Partner Center — Store Listing & Certification Reference (3P)

Depth reference for the **Partner Center publishing** workflow
(`workflows/partner-center.md`). It owns the detailed **pre-submission
checklist**, the **store-listing field reference**, and the **certification
troubleshooting** table for third-party partners publishing a declarative agent
to the Microsoft commercial marketplace (AppSource / the Microsoft 365, Teams,
and Copilot store).

This reference stays at the **partner-facing process level**. The workflow can
use `wiqd publish pc` for verified Draft preparation and separately authorized
submission, or guide portal actions when direct commands are disabled/unavailable.
Partner Center owns certification and store publication. This is the **public 3P path only** — an org's own
admin-catalog publish (`wiqd plugin publish --env <env>`) and Microsoft-internal
first-party publishing are out of scope.

## Direct publishing boundaries

The direct path uses one verified `partner-center.json` for publisher binding and
listing inputs. Generic interactive authentication offers Skip before protected
storage; choosing setup still requires OS-protected credentials, verified tenant
and seller, and final binding consent. Complete enrollment in Partner Center;
sign-in is not program access, legal acceptance, or submission readiness.

Collect language, descriptions/short summary, categories, privacy and support
URLs, explicit terms mode, release notes, future availability, a listing logo
and one to five screenshots with captions. Custom terms require a terms URL;
standard Microsoft terms must not also specify a custom terms URL. These inputs
express the partner's choices; they do not accept an agreement on their behalf.
The app-package icons below and the separately uploaded listing logo are distinct.

Use the exact independently validated ZIP with explicit `--package` and release
notes for preflight and preparation. `--yes` authorizes Draft preparation only.
Submission requires a separate real-terminal typed confirmation or explicitly
authorized invocation-scoped unattended submission. Never invent
`--authorize-submit` consent. Pending/unknown outcomes stop later mutations;
status and portal recovery do not justify blind replay. `resume` is simulated.
An accepted submission or configure job never proves certification or Live
publication. Follow `workflows/partner-center.md` for the full direct sequence.

## Pre-submission checklist

Work through this before creating the offer. Most certification rejections trace
back to a missed item here.

| Area | Requirement | How to satisfy |
|------|-------------|----------------|
| Source | Saved diagnostics have no errors | `wiqd plugin validate --mode source --path "<project>" --env prod` |
| Package | Built from production and independently package-validated | `wiqd plugin package --env prod`, then `wiqd plugin validate --mode package --package-file "<final.zip>"` |
| Marketplace readiness | Policy findings are advisory warnings, not publishing blockers | `workflows/validation.md` using `--mode marketplace` on the same ZIP when listing/evidence inputs are available |
| Version | Unique, higher than any prior upload | Bump the manifest version before re-packaging |
| Color icon | 192×192 px PNG | Matches the icon in the package |
| Outline icon | 32×32 px transparent, monochrome PNG | Matches the icon in the package |
| Privacy Policy URL | Publicly reachable | Host a real privacy policy; no placeholder |
| Terms choice | Explicit Microsoft Standard Contract or custom EULA | Ask the publisher; never infer the choice or accept agreements |
| Terms of Use URL | Required only for custom EULA | Use the publisher's public HTTPS URL without embedded credentials; omit it for Standard Contract |
| Descriptions | Accurate, no unsupported claims | Describe what the agent does and what data it touches honestly |
| Screenshots | Show the agent in real use | 1+ representative screenshots |
| Support contact | Monitored channel | Email or support URL that reaches the partner |
| Publisher profile | Verified, complete | Legal name, display name, website in Partner Center |
| Permissions / scopes | Only what is used, each justified | Remove unused scopes; explain each in the listing |

## Store-listing field reference

Fill in the customer-facing listing completely — certification checks each field.

- **App name** — clear and accurate; avoid trademark or "Microsoft"-implying names
  the partner does not own.
- **Short description** — one-line value proposition shown in search results.
- **Long description** — what the agent does, who it is for, and — for
  Copilot/AI agents — what data it accesses and any limitations. AI capabilities
  are scrutinized, so be explicit and honest.
- **Screenshots** — required; show the agent in use. A demo video is optional but
  strengthens the listing.
- **Category and search terms** — pick the most relevant category so customers can
  find the agent.
- **Associated service purchase** — explicitly ask whether the plugin requires
  a separate service purchase or offers in-app purchases. Record the partner's
  confirmed answer; there is no assumed No for the public 3P path.
- **Industries (optional)** — choose at most two of Agriculture, Distribution,
  Education, Finance, Government, Healthcare, Manufacturing, Professional
  Services, Retail and Sustainability. Only select industry-specific needs the
  plugin serves, require partner confirmation of suggestions, and support each
  selection in the description. Confirm Apps applicability in the portal.
  Leave unset for general-purpose plugins; Clouds for Industry is only for
  managed partners and must not be inferred.
- **Icons** — color 192×192 and outline 32×32; must match the package exactly.
- **Privacy Policy URL** — mandatory and publicly reachable.
- **Terms choice** — ask Microsoft Standard Contract or custom EULA, with no
  default. Standard Contract (`standardMicrosoft`) needs no Terms of Use URL.
  Custom EULA (`custom`) requires the publisher's own public HTTPS Terms of Use
  URL without embedded credentials; never invent or host it. Present the
  [Partner Center guidance and published-offer implications](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/standard-contract)
  before the partner selects. Choice is not agreement acceptance or legal advice;
  the partner completes the portal settings and agreements.
- **Support contact and publisher website** — must resolve and be monitored.
- **Supported languages / markets** — the languages and markets where the app
  will be listed; drives where it goes live after certification.

## Certification: what reviewers check

After **Submit**, the agent goes through AppSource / Office Store certification:

1. **Automated validation** — package integrity, manifest schema conformance, icon
   sizes/formats, required URLs present.
2. **Manual review** — content and claims, security, privacy and consent, and —
   for Copilot/AI agents — responsible-AI and data-handling requirements.

Certification typically takes a few business days; AI-powered agents can take
longer due to the additional responsible-AI scrutiny.

## Troubleshooting rejections

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Package upload rejected | Duplicate version, or invalid manifest | Authorize source repair, source-check with the packaging path/environment, rebuild, then rerun package validation on that exact ZIP |
| "Manifest failed validation" | Schema errors in the manifest | Use `workflows/validation.md` for scoped repair and same-mode revalidation; do not patch the ZIP |
| Icon rejected | Wrong size/format | Color icon 192×192 PNG; outline icon 32×32 transparent PNG |
| Missing privacy / terms | Missing privacy URL, terms choice, or custom EULA URL | Supply the privacy URL, confirm Standard Contract or custom EULA, and supply a public HTTPS Terms of Use URL only for custom EULA |
| Consent / permissions flagged | Requested scopes not justified in listing | Describe why each permission is needed; remove unused scopes |
| AI / responsible-AI feedback | Data handling or claims not documented | Document what data the agent uses and its limitations honestly in the listing |
| Certification stuck / unclear | Manual review in progress | Wait for reviewer feedback; address every comment and resubmit |

When a submission is rejected, Partner Center returns specific reviewer feedback.
Address **every** item, re-validate, re-package if the manifest changed, and
resubmit. Each resubmission with a manifest change needs a **bumped version**.

## Shipping updates

To publish a new version after go-live:

1. Make the change and bump the **`version` field in the app manifest**
   (`appPackage/manifest.json`).
2. `wiqd plugin validate --mode source --path "<project>" --env prod` — resolve source errors.
3. `wiqd plugin package --env prod` — rebuild the `.zip`.
4. Require `wiqd plugin validate --mode package --package-file "<final.zip>"` to
   pass on the new ZIP. Marketplace policy findings remain advisory. In Partner
   Center, upload that same package to the existing offer, update the listing if
   needed, and **Submit** for re-certification.

## Related references

- `references/wiqd-core/package.md` — packaging behavior and `wiqd plugin package`.
- `references/wiqd-core/validate.md` — manifest validation and `wiqd plugin validate`.
- `workflows/validation.md` and `references/validate/listing-collection.md` — package/Marketplace
  readiness, listing review and authorized repair (`microsoft.validate`).
