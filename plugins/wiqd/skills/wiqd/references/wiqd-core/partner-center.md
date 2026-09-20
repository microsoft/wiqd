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

This reference stays at the **partner-facing process level**. wiqd owns the
lifecycle up to and including `wiqd agent package`; Partner Center owns
certification and the listing. This is the **public 3P path only** — an org's own
admin-catalog publish (`wiqd agent publish --env <env>`) and Microsoft-internal
first-party publishing are out of scope.

## Pre-submission checklist

Work through this before creating the offer. Most certification rejections trace
back to a missed item here.

| Area | Requirement | How to satisfy |
|------|-------------|----------------|
| Manifest | Validates with zero errors | `wiqd agent validate` — fix every error |
| Package | Built from the production env | `wiqd agent package --env prod` |
| Version | Unique, higher than any prior upload | Bump the manifest version before re-packaging |
| Color icon | 192×192 px PNG | Matches the icon in the package |
| Outline icon | 32×32 px transparent, monochrome PNG | Matches the icon in the package |
| Privacy Policy URL | Publicly reachable | Host a real privacy policy; no placeholder |
| Terms of Use URL | Publicly reachable | Host real terms; no placeholder |
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
- **Icons** — color 192×192 and outline 32×32; must match the package exactly.
- **Privacy Policy URL** and **Terms of Use URL** — mandatory and publicly
  reachable.
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
| Package upload rejected | Duplicate version, or invalid manifest | Bump the manifest version, re-run `wiqd agent validate` then `wiqd agent package` |
| "Manifest failed validation" | Schema errors in the manifest | Run `wiqd agent validate`, fix every error, re-package |
| Icon rejected | Wrong size/format | Color icon 192×192 PNG; outline icon 32×32 transparent PNG |
| Missing privacy / terms | No public Privacy Policy or Terms of Use URL | Add publicly reachable Privacy Policy and Terms of Use URLs to the listing |
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
2. `wiqd agent validate` — resolve every error.
3. `wiqd agent package --env prod` — rebuild the `.zip`.
4. In Partner Center, upload the new package to the existing offer, update the
   listing if needed, and **Submit** for re-certification.

## Related references

- `references/wiqd-core/package.md` — packaging behavior and `wiqd agent package`.
- `references/wiqd-core/validate.md` — manifest validation and `wiqd agent validate`.
- `references/validate/store-ops-validation.md` — pre-submission store-ops
  readiness check (skill lives in the `microsoft.validate` extension).
