# Policy References

The publicly-documented Microsoft sources the [`rules.md`](rules.md) registry is derived from. Every rule in the registry cites one of these entries. Update the `Last validated` date when you re-verify the URL and the heading text.

> **Why not just cite section numbers?** Microsoft renumbers policy sections periodically — `§1140.x` today may be `§1141.y` next quarter. The stable anchors are the URL, the page title, and the heading text. We include the numbered reference for convenience but the heading text is authoritative.

---

## Teams Store Validation Guidelines

- **URL:** https://learn.microsoft.com/microsoftteams/platform/concepts/deploy-and-publish/appsource/prepare/teams-store-validation-guidelines
- **Owner:** Microsoft Teams platform team
- **Scope:** App package structure, manifest content, naming, icons, descriptions, valid domains, privacy/terms requirements.
- **Headings used by `rules.md`:**
  - "App package structure" → `P1`–`P9`
  - "Name your app" → `B1`, `B2`, `B3`, `B4`, `B8`
  - "Write the description" → `B5`, `B6`, `B7`, `B12`, `B13`, `M11`, `M12`, `M13`
  - "App icons" → `I1`–`I8`
  - "Valid Domains" → `D1`–`D9`
  - "Privacy policy and terms of use" → `M6`, `M7`, `U1`–`U4`
  - "App package size" → `P8`
- **Last validated:** 2026-06-18

---

<a id="commercial-marketplace-1140"></a>

## Commercial Marketplace Certification Policies

- **URL:** https://learn.microsoft.com/legal/marketplace/certification-policies
- **Owner:** Microsoft Commercial Marketplace
- **Scope:** Publisher requirements (§100), apps & agents for M365/Copilot (§1140), declarative agents (§1140.9 — Agents for M365 Copilot, Copilot Chat, Agent 365), branding, intellectual property, content claims.
- **Headings used by `rules.md`:**
  - "100 General" → `C1`–`C4`
  - "100.14 Functionality / app must be testable" → `S5`
  - "1140.2 Listing requirements" → `M5`–`M14`, `B5`–`B9`
  - "1140.4 Technical requirements" → `P3`–`P5`, `P8`, `G1`–`G3` (tabs, bots, mobile experience)
  - "1140.4.1 App listing content" → `B10`–`B13`, `M17`, `F1`–`F8`
  - "1140.4.1.3 Product name references" → `B10`, `B11`
  - "1140.4.1.4/5 Screenshots and video" → `F1`, `F4`, `F6`
  - "1140.4.1.19 Hyperlinks in description" → `F7`
  - "1140.4.1.23 Publisher documentation URL" → `M17`
  - "1140.4.1.24 AI disclosure" → `R7`
  - "1140.4.1.27 Mobile and M365 screenshots" → `F3`, `F5`
  - "1140.6.2 Publisher attestation" → `F2`
  - "1140.8 Manifest schema" → `M1`, `M2`
  - "1140.8.1.4 Supported clients" → `F8`
  - "1140.9 Agents for Microsoft 365 Copilot, Copilot Chat, and Agent 365" → `A1`–`A13`, `X1`–`X8`, `R1`–`R7`, `K1`–`K8`, `N1`–`N5`
  - "1140.9.1.1 App name in Copilot UI" → `N4`
  - "1140.9.2.8/10 Confirmation body" → `A13`
  - "1140.9.2.11 Plugin name matches manifest" → `N3`
  - "1140.9.2.13/15/17/18/21 Name consistency" → `N1`, `N2`
  - "1140.9.2.14 First reference to Copilot agents" → `B10`
  - "1140.1.4.1 Version increment on resubmission" → `M18`
- **Common deep-links to known stable headings (verify before relying on):**
  - https://learn.microsoft.com/legal/marketplace/certification-policies#100-general
  - https://learn.microsoft.com/legal/marketplace/certification-policies#11402-listing-requirements
  - https://learn.microsoft.com/legal/marketplace/certification-policies#11409-agents-for-microsoft-365-copilot-copilot-chat-and-agent-365
- **Last validated:** 2026-06-18

---

<a id="copilot-review-validation"></a>

## Copilot / Declarative Agent Review Validation Guidelines

- **URL:** https://learn.microsoft.com/microsoftteams/platform/concepts/deploy-and-publish/appsource/prepare/review-copilot-validation-guidelines
- **Owner:** Microsoft Teams / Copilot extensibility team
- **Scope:** Declarative agent–specific validation rules, prompt-injection patterns, conversation starter rules, actions + plugins, worker agents. (Custom-engine agents are out of scope for this skill.)
- **Headings used by `rules.md`:**
  - "Declarative agent requirements" → `A1`–`A13`, `G2`, `G3`
  - "Prompt injection patterns" → `X1`–`X8`
  - "Conversation starters" → `A7`–`A9`
  - "Actions and plugins" → `K1`–`K8`
  - "Worker agents" → `W1`–`W3`
- **Last validated:** 2026-06-18

---

## Declarative Agent Manifest Schema

- **URLs (latest stable + active versions):**
  - 1.5: https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest-1.5
  - 1.6: https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest-1.6
  - 1.7: https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest-1.7
  - 1.8: https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest-1.8
  - Schema index: https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest
- **Owner:** Microsoft 365 Copilot extensibility documentation team
- **Scope:** The DA JSON schema — field names, length constraints, allowed values, capability shapes, `worker_agents`, `localizationInfo`, `webApplicationInfo`.
- **Schema URL allowlist for rule `M1` / `A1`:** consider a `$schema` URL **publicly released** if it matches:
  - `^https://developer\.microsoft\.com/json-schemas/teams/v1\.\d+/MicrosoftTeams\.schema\.json$` (Teams app manifest)
  - `^https://developer\.microsoft\.com/json-schemas/copilot/declarative-agent/v1\.[0-9]+/schema\.json$` (DA JSON manifest)
  - Reject any URL containing `preview`, `dev`, `draft`, or a non-numeric version (e.g., `v0.dev`).
- **Last validated:** 2026-08-05

---

## Microsoft Teams App Manifest Schema

- **URL:** https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema
- **Owner:** Microsoft Teams platform team
- **Scope:** The umbrella Teams app manifest — `id`, `name`, `description`, `icons`, `validDomains`, `webApplicationInfo`, `localizationInfo`, `copilotAgents`, `bots`, `composeExtensions`, `customEngineAgents`.
- **Headings used by `rules.md`:**
  - "`webApplicationInfo`" → `S1`–`S5`
  - "`localizationInfo`" → `L1`–`L5`
  - "`validDomains`" → `D1`–`D9`, `G1` (bundled-tab `configurationUrl` host coverage)
  - "`bots` / `configurableTabs` / `devicePermissions`" → `G1`–`G3` (bundled-surface co-presence with `copilotAgents`)
- **Last validated:** 2026-05-27

---

## Microsoft Responsible AI Standard (v2)

- **URL:** https://blogs.microsoft.com/wp-content/uploads/prod/sites/5/2022/06/Microsoft-Responsible-AI-Standard-v2-General-Requirements-3.pdf
- **Owner:** Microsoft Office of Responsible AI
- **Scope:** Banned and restricted use cases — facial recognition for US police, real-time biometrics, emotion inference disclosure, claims of bias-free / fair systems, medical/legal/financial advice without disclosure.
- **Headings used by `rules.md`:**
  - "Restricted Uses" → `R3`, `R4`
  - "Transparency" → `R5`, `R6`
- **Last validated:** 2026-05-27

> Microsoft RAI policy is referenced from §100 (General) of the Commercial Marketplace certification policies. Failures in `R3` are treated as Must-fix because the RAI Standard explicitly bans the use case for marketplace publication.

---

## Banned Domain / Endpoint Lists (informational)

Maintained inline in [`rules.md`](rules.md) for rules `D1`, `D2`, `D3`. These lists are derived from the Teams Store Validation Guidelines "Valid Domains" section, the Teams app manifest schema definition of `validDomains`, and Microsoft Bot Framework public documentation.

Common references when verifying a domain:

- https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema#validdomains
- https://learn.microsoft.com/azure/bot-service/bot-service-resources-bot-framework-faq

---

## Maintenance Checklist

When refreshing the references:

1. Open each URL above and confirm the page is reachable.
2. Confirm the heading text used by `rules.md` still exists on the page.
3. If the heading text has changed, update both this file and the citation column in the report (the citation deep-links to the heading).
4. Update `Last validated` on each section.
5. Update `last_validated` in the SKILL.md front-matter.
6. Update the `Changelog` table at the bottom of `rules.md` if rules are added, retired, or re-graded.
