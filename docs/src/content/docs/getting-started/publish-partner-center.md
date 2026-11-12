---
title: Partner Center publishing overview
description: Prepare and submit a verified declarative-agent package with separate submission consent.
---

# Publish to Partner Center

For enrollment details, conversational prompts, runnable update/rejection steps,
and runner authentication limits, use the
[publishing walkthrough](/getting-started/publish-to-partner-center/).
This page is a compact overview of the same public direct-publishing flow.

`wiqd publish pc` prepares a Partner Center Draft and, with separate authorization,
submits it for review. The Marketplace extension is included and enabled by
default in the public CLI. Partner Center still owns enrollment, certification
and store publication. A successful API job or accepted submission is not
certification or a Live listing.

If Marketplace has been removed or `partner-center-publishing` is disabled,
direct commands are absent. Use Partner Center's portal instead, or deliberately
restore the extension/flag yourself. WIQD does not silently reverse that choice.
Check installed command help for the exact available surface.

## Set up your publisher

Complete Partner Center enrollment, organization verification, publisher profile
and access to the Microsoft 365 and Copilot program first. From the intended
agent project, sign in in a real terminal:

```bash
wiqd auth login --interactive
```

With no `partner-center.json`, **Skip Marketplace setup** is initially selected.
Skip does not acquire secure storage or create a lock and lets other providers
continue. Directory discovery or another directory starts setup. If you know the
seller tenant, use `--tenant <seller-tenant-guid>` to bypass only that initial
menu. Sign in with your home work account, targeting the seller tenant; a guest
object does not have a separate password.

Windows prefers WAM when available; other supported systems use external Edge.
No embedded browser or borrowed credentials are used. Protected OS storage
through `keytar` is required once setup is selected. Missing/denied storage
fails explicitly, with no plaintext fallback.

Verify the returned **Seller Id**, not Partner ID, then confirm the exact binding
destination. The service exposes one current seller, not a seller picker. An
existing binding is validated and preserved; a mismatched `--tenant` does not
overwrite it. `wiqd auth status --json` reports current provider evidence, not
enrollment or submission readiness. Logout clears only Marketplace-owned local
credentials. See [Authentication](/getting-started/authentication/).

## Build and validate the exact package

Use the same project and lifecycle environment for saved-source validation and
packaging:

```bash
wiqd plugin validate --mode source --path "<project>" --env "<environment>"
wiqd plugin package --path "<project>" --env "<environment>" --output "<final.zip>"
wiqd plugin validate --mode package --package-file "<final.zip>" --json
```

Require the independent package result to be `PASSED`. If source or ZIP bytes
change, rebuild/revalidate before uploading. Marketplace policy checks are
advisory and never replace package validation or official certification.

## Complete the listing and prepare a Draft

Initialize the authenticated project's shared configuration:

```bash
wiqd publish pc init --path "<project>" --json
```

Complete `partner-center.json` with your actual listing choices: language, title,
description, short summary, categories, privacy and support URLs, explicit terms
mode, release notes, availability at least 24 hours ahead, a listing logo and
one to five screenshots with captions. Paths must be regular files inside the
selected project, with no symlink traversal. The uploaded listing logo is separate
from the app-package icons.

Choose `listing.legal.termsConditions` explicitly: `standardMicrosoft` or `custom`.
Custom terms require `termsOfUseUrl`; standard Microsoft terms reject a custom
terms URL. Configuration expresses your choices, not acceptance of an agreement.
Initialization generates/preserves the private preview key; do not log or share it.

Pass the **exact validated ZIP**, not a stale configuration path:

```bash
wiqd publish pc preflight --path "<project>" --package "<final.zip>" --release-notes "<approved notes>" --json
wiqd publish pc prepare --path "<project>" --package "<final.zip>" --release-notes "<approved notes>" --yes --json
```

`--yes` authorizes Draft preparation only. It does not authorize submission.
Omitting `--package` builds fresh bytes for `--package-env` (default `local`);
those bytes are not automatically the ZIP you previously validated. The public
flow does not inject private deployment sidecars or expose private targeting
options.

The optional `listing.certification.validationReport` selects an existing
package-bound StoreOps `report.json` and its original sibling HTML. Inspect both
first: selecting them authorizes disclosure of their existing content, including
paths and policy diagnostics, to certification reviewers. A stale/mismatched
report fails before mutation. Attachment verification does not prove reviewer
access, portal visibility, downstream archive acceptance or retention.

## Authorize submission separately

After preparation completes with a verified Draft, submit in a real terminal:

```bash
wiqd publish pc submit --path "<project>" --product-id "product/<GUID>" --yes --interactive
```

Review the exact publisher, Product, package and terms, then type the requested
confirmation. For explicitly authorized unattended submission, replace
`--interactive` with `--authorize-submit`. Use exactly one mode; neither can be
inferred from `--yes`, successful validation, login or saved configuration.
Automation needs an already-established protected session; aggregate login is
terminal-only. Core `CI_ENABLED`/`M365_*` pipeline credentials do not authenticate
Marketplace, and this build has no supported clean-runner bootstrap. See
[Marketplace authentication in automation](/getting-started/publish-to-partner-center/#marketplace-authentication-in-automation).
Both modes revalidate the same inputs, publisher and prepared
Draft, refusing drift rather than submitting stale content.

Bare `wiqd publish pc` composes preflight, preparation and submission and requires
one of those authorization modes. It is not a prepare-only command.

## Observe and recover safely

```bash
wiqd publish pc status --path "<project>" --product-id "product/<GUID>" --json
```

Accepted submission, processing, certification rejection and independently
verified Live publication are distinct outcomes. Pending/unknown work returns
actionable evidence; preserve Product/job IDs and project-local receipts.
Do not blindly repeat create/uploads/submission or delete receipts to retry.
Use status or recover the Draft in Partner Center. `resume` remains simulated,
not live recovery. Certification and publication timing are external, not a
WIQD guarantee. A higher-version update requires a newly validated package.

For an existing or rejected offer, preview/apply explicit `update` selectors,
then inspect and resubmit the Draft in Partner Center. `update --submit` is
unsupported and previous CLI preparation authorization is invalidated. Follow
the [update walkthrough](/getting-started/publish-to-partner-center/#update-an-existing-or-rejected-offer)
rather than rerunning fresh-offer preparation or submission.

Public rollout approval does not itself establish clean-machine, cross-platform,
guest-directory, secure-refresh, certification or reviewer-access acceptance.
Those require their own verified service evidence.
