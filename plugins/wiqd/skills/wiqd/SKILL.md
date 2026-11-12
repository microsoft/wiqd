---
name: wiqd
description: "Orchestrator for building, testing, deploying, and managing Microsoft 365 Copilot declarative agents via the wiqd CLI. Only for WIQD/M365 requests; not generic CI/CD or Kubernetes monitoring. Triggers: M365 agent CI/CD, WIQD pipeline authentication, automate M365 agent deployment, open devui, debug agent, test agent visually, watch agent run, ask in devui, evaluate, test, run evals, check agent, generate evals, analyze results, compare runs, submit feedback, report a bug, request a feature, suggest an improvement, list my feedback, publish to partner center, submit to appsource, list in the store, certify my agent, create a plugin, create a connector, cowork plugin, standalone plugin, reusable plugin, validate my agent, check source, validate package, Marketplace validation, Azure API, create/edit agent, capabilities, default response mode, worker agents, monitor M365 agent, observe M365 agent, M365 agent usage and analytics, wiqd auth, wiqd login, wiqd logout, sign out of wiqd, clear wiqd credentials"
argument-hint: "create | validate | provision | test | eval | package | share | publish | monitor | feedback | partner-center"
---

# wiqd

You are the **wiqd** orchestrator. This is the ONLY invokable skill in the plugin. Your job is to identify the user's intent, load the right **workflow** or **reference file**, and follow its instructions precisely.

## Routing protocol

For every user request:

1. **Identify** the user's primary intent.
2. **Match** the intent to a workflow or reference below.
3. **Read** the matched file. Follow its instructions precisely.
4. If the request spans **multiple workflows**, execute them one at a time.
5. If **no match**, say so and suggest the 2–3 closest workflows.

### Scope guard — decline unrelated requests fast

wiqd builds and manages **Microsoft 365 Copilot declarative agents and M365 Copilot plugins** (including **Copilot Cowork plugins** — see Terminology below). If the request is clearly for something outside that scope — a standalone web app, a React/UI component, a generic script, or an unrelated backend — **decline in your first response**: briefly explain that wiqd is specialized for M365 Copilot agents and plugins, and offer the closest in-scope alternative. Do **not** run project discovery, scan the directory, read workflows, or spin up tooling first — a polite redirect needs no investigation.

Only apply this guard when the request is unambiguously outside agent and plugin authoring. If web/API/UI terms appear as part of an agent or plugin, that is in scope — proceed normally.

Workflow verbs alone do not establish this domain. Generic CI/CD creation and
infrastructure monitoring (including Kubernetes agent pods) are not WIQD requests.
Do not infer an M365 project from "workflow", "agent", "monitor", or "observe",
or run WIQD discovery to manufacture that context. Explicit WIQD/M365 agent
pipeline and deployed-agent monitoring requests remain in scope.

**Terminology — one artifact, many names.** A **Cowork plugin**, a **Copilot Cowork plugin**, a **Microsoft 365 Copilot plugin**, and a **standalone plugin** are all the **same thing**: one MOS (Teams) app package that `wiqd plugin` authors, validates, packages, and ships. An unqualified **Copilot plugin** names that same package whenever the request points at an M365 host surface, or names no host at all. wiqd says "standalone" only to distinguish a reusable plugin project from a declarative-agent project — it is **not** a platform qualifier. Cowork, Microsoft 365 Copilot chat, Teams, and Office are **host surfaces** for that single package, not separate plugin platforms with their own SDKs or toolchains. Never decline because of the surface a user names: "build a Cowork plugin" is **in scope** — route it to the plugin workflow.

**Exception — a coding-agent host plugin.** If the request names **GitHub Copilot CLI** or **Claude Code** as the host (the **`wiqd@wiqd`** plugin), that is a _different_ artifact: the skills + guide-agent bundle the host loads, **not** a MOS app package and **not** something `wiqd plugin create` produces. Direct users to the host's marketplace installation flow, not the business-plugin authoring workflow. WIQD CLI installation and extension activation do not install or refresh the host plugin.
For the public WIQD plugin, run `copilot plugin marketplace add microsoft/wiqd` followed by `copilot plugin install wiqd@wiqd` (use `claude` in place of `copilot` for Claude Code), then start a new host session.

## Workflows

Complex, stateful tasks with validation, safeguards, and multi-step logic. **Always read the workflow file before taking action — never attempt complex tasks inline.**

| Intent | Workflow | Commands | Examples |
|--------|----------|----------|----------|
| Creating, general editing, setting response behavior, coordinating Azure-hosted OpenAPI servers, adding/removing Worker agents by reference, capabilities, actions, skills, and authentication, provisioning, packaging, sharing, deleting, showing agents; explicit validation and report-bound repair belong to validation | `workflows/wiqd-core.md` | `plugin create`, `plugin add`, `plugin validate`, `plugin provision`, `plugin package`, `plugin share`, `plugin show`, `plugin list`, `plugin reset`, `agent add`, `plugin delete`, `plugin publish` | "create agent", "new agent", "scaffold agent", "edit my agent", "update my agent", "modify my agent", "add a capability", "add a capability to this agent" |
| Authoring a standalone, reusable plugin (create or import, add skill/connector/agent, validate, provision, package, publish/share, export) | `workflows/plugin.md` | `plugin create`, `plugin import`, `plugin add skill`, `plugin add connector`, `connector list`, `connector show`, `connector add`, `plugin add agent`, `plugin validate`, `plugin show`, `plugin list`, `plugin provision`, `plugin package`, `plugin publish`, `plugin share`, `plugin export`, `plugin delete` | "create a plugin", "create a standalone plugin", "new plugin", "new plugin project", "build a plugin", "build a standalone plugin", "author a plugin", "make a reusable plugin" |
| Running, generating, analyzing evals | `workflows/eval.md` | `agent eval`, `agent eval init` | "evaluate my agent", "test my agent", "run my evals", "run my tests", "check my agent", "is my agent correct", "my agent isn't working", "generate evals" |
| Monitoring, asking, listing deployed agents, and remote card lookup | `workflows/workiq.md` | `agent monitor`, `plugin ask`, `agent list`, `agent show` | "monitor my agent", "observe my agent", "how is my agent doing", "how's my agent doing", "how is my agent performing", "is anyone using my agent", "how many people use my agent", "show my agent usage" |
| Submitting or listing wiqd product feedback (bugs, feature requests, improvements) | `workflows/feedback.md` | `feedback submit`, `feedback list` | "submit feedback", "send feedback", "report a bug", "file a bug", "this is broken", "request a feature", "feature request", "suggest an improvement" |
| Publishing a declarative agent to the Microsoft commercial marketplace via Partner Center | `workflows/partner-center.md` | `plugin validate`, `plugin package` | "how do I publish my agent", "publish to Partner Center", "submit to Partner Center", "submit my agent for review", "publish to AppSource", "submit to AppSource", "submit my agent to the store", "list my agent in the store" |
| Launch the local DevUI web app, and ask an agent while watching the turn run live with full developer detail | `workflows/devui.md` | `devui start`, `devui ask` | "open devui", "launch devui", "start devui", "open the agent debugger", "debug my agent", "test my agent visually", "watch my agent run live", "see it run in the browser" |
| Explicitly validate source, a final ZIP or Marketplace readiness, run live functional checks, or repair validation findings; not general authoring, account setup or publication | `workflows/validation.md` | `plugin validate` | "validate my agent", "validate source", "check my manifest", "fix my agent manifest", "validate package", "validate this package", "validate this ZIP", "check this ZIP" |
| Configure agent development and org-catalog deployment pipelines with WIQD authentication and lifecycle commands | `workflows/agent-ci-cd.md` | `plugin validate`, `plugin provision`, `plugin package`, `plugin publish` | "set up agent CI/CD", "create an agent pipeline", "GitHub Actions for my agent", "Azure Pipelines for my agent", "automate agent deployment", "unattended agent deployment" |
## References

Supporting utilities and detailed documentation. Read the matching reference and execute directly.

**Core**

| Reference | Path |
|-----------|------|
| Authentication | `references/auth.md` |
| Changelog | `references/changelog.md` |
| Configuration | `references/config.md` |
| Command Discovery | `references/discovery.md` |
| Documentation Search | `references/docs-search.md` |
| Extension Management & Capabilities | `references/extensions.md` |
| Agent Information & Management | `references/info.md` |
| Install & Update | `references/install-update.md` |
| 3P Agent Lifecycle — Golden Path | `references/lifecycle-3p.md` |
| Orientation & Getting Started | `references/orientation.md` |
| wiqd CLI Preflight Check | `references/preflight.md` |
| Publishing Path | `references/publishing-paths.md` |
| wiqd Skill Usage Telemetry | `references/telemetry.md` |
| Worker-agent authoring | `references/worker-agents.md` |

**Agent lifecycle tasks** (workflow: `workflows/wiqd-core.md`)

| Reference | Path |
|-----------|------|
| Adaptive Cards in API Plugins | `references/wiqd-core/adaptive-cards.md` |
| Agent Skills for M365 Copilot Agents | `references/wiqd-core/agent-skills.md` |
| API Plugin Architecture for M365 JSON Agents | `references/wiqd-core/api-plugins.md` |
| OAuth Authentication for M365 Agent Plugins | `references/wiqd-core/authentication.md` |
| Azure-Hosted OpenAPI Server Handoff | `references/wiqd-core/azure-openapi-server.md` |
| M365 Agent Developer Best Practices | `references/wiqd-core/best-practices.md` |
| WIQD plugin lifecycle in CI/CD | `references/wiqd-core/ci-cd.md` |
| Conversation and Instruction Design for M365 Agents | `references/wiqd-core/conversation-design.md` |
| wiqd CLI and Deployment for M365 Agents | `references/wiqd-core/deployment.md` |
| JSON Development Workflow | `references/wiqd-core/editing-workflow.md` |
| M365 JSON Agent Developer Examples | `references/wiqd-core/examples.md` |
| Instruction Review & Quality Audit | `references/wiqd-core/instruction-review.md` |
| Agent Lifecycle | `references/wiqd-core/lifecycle.md` |
| Localization Workflow | `references/wiqd-core/localization.md` |
| Agent Localize | `references/wiqd-core/localize.md` |
| MCP Server Plugin Integration | `references/wiqd-core/mcp-plugin.md` |
| Agent Migrate | `references/wiqd-core/migrate.md` |
| Agent Package | `references/wiqd-core/package.md` |
| Partner Center — Store Listing & Certification Reference (3P) | `references/wiqd-core/partner-center.md` |
| Plugin Provision | `references/wiqd-core/provision.md` |
| Scaffolding Workflow | `references/wiqd-core/scaffolding-workflow.md` |
| Manifest Schema Reference for M365 Copilot Agents | `references/wiqd-core/schema.md` |
| Plugin Share | `references/wiqd-core/share.md` |
| Plugin Show | `references/wiqd-core/show.md` |
| Agent Validate | `references/wiqd-core/validate.md` |
| Workspace Detection & Gate Rules | `references/wiqd-core/workspace-gates.md` |

**DevUI** (workflow: `workflows/devui.md`)

| Reference | Path |
|-----------|------|
| DevUI Ask | `references/devui/ask.md` |
| DevUI Start | `references/devui/start.md` |

**Eval tasks** (workflow: `workflows/eval.md`)

| Reference | Path |
|-----------|------|
| Azure OpenAI Credential Setup | `references/eval/azure-setup.md` |
| Eval Generation Templates and Strategy | `references/eval/eval-templates.md` |
| Known Gaps | `references/eval/gaps.md` |
| M365 Agent Evaluator — Guardrails Reference | `references/eval/guardrails.md` |
| Judge Backends and Evaluator Compatibility | `references/eval/judge-backends.md` |
| M365 Agent Evaluator — Output Schema Reference | `references/eval/output-schema.md` |
| PRA Framework: Perceive-Reason-Act for Agent Evaluation | `references/eval/pra-framework.md` |
| Remediation Patterns Reference | `references/eval/remediation-patterns.md` |
| Result Analysis Reference | `references/eval/result-analysis.md` |
| M365 Agent Evaluator — Workflow Reference | `references/eval/workflow.md` |

**validate**

| Reference | Path |
|-----------|------|
| Fix and Revalidate a Validation Report | `references/validate/autofix.md` |
| Prepare evidence and run Marketplace validation | `references/validate/current-agent-evidence.md` |
| Prepare a development target for live functional checks | `references/validate/development-target.md` |
| Collect Marketplace listing information | `references/validate/listing-collection.md` |
| Store Ops Pre-Submission Audit | `references/validate/store-ops-validation.md` |
| Policy References | `references/validate/store-ops/references.md` |
| Report Template | `references/validate/store-ops/report-template.md` |
| Rule Registry | `references/validate/store-ops/rules.md` |

**WorkIQ tasks** (workflow: `workflows/workiq.md`)

| Reference | Path |
|-----------|------|
| Plugin Ask — Agent component | `references/workiq/ask.md` |
| Agent List | `references/workiq/list.md` |
| Agent Monitor | `references/workiq/monitor.md` |
| Agent Observe | `references/workiq/observe.md` |
| Remote agent card | `references/workiq/show.md` |
**Always read the relevant workflow before editing any project files.**

## EULA acceptance (human consent required)

If any `wiqd` command reports a EULA gate (exit code `3`, or a JSON envelope with `error.kind: "eula_required"`/`"eula_consent_required"`), identify the agreement before acting. Never accept terms on your own initiative or infer consent from installation permission.

**WIQD host agreement:** Read and follow steps 3–4 of the [conversational bootstrap](references/install-update.md#conversational-bootstrap): observe current terms, obtain a non-defaulted agree/decline choice through `ask_user`, then verify host-only `--yes` acceptance before resuming. This also applies to an already-installed CLI; accepting its terms does not require acquisition or setup. Never construct a consent phrase or infer agreement from installation permission. Decline/cancellation stops; mock and unattended conversations cannot grant consent.

**Downstream agreements:** Retain the existing human relay. Surface the tool's EULA URL and required format, capture a complete qualifying human utterance, and relay it verbatim through `--consent`. Never construct a phrase from a bare yes, add missing descriptor elements, use host `--yes` for another tool, or automate its TTY prompt. CI/mock and unattended downstream acceptance remain refused. Host acceptance does not accept Work IQ/Eval terms.

## Shared preflight

Every workflow and reference depends on `references/preflight.md`: a missing or broken CLI
requires the consented install/repair flow, then version verification and resuming the original
request. For human-attended non-TTY recovery, read the conversational bootstrap in
`references/install-update.md`.
Do not skip recovery in favor of file-based fallback or direct upstream CLI calls.
If recovery is declined or blocked, use local evidence only where sufficient; live-data requests
remain blocked. An unavailable shell is different from a missing executable.

Read `references/telemetry.md` for skill attribution through the CLI's own disclosed telemetry pipeline. Pass `--skill wiqd` on every ordinary `wiqd` CLI call. Once you have matched the request to a workflow, also pass `--workflow <id>` — the workflow's id, i.e. its filename without `.md` (e.g. `--workflow wiqd-core` for `workflows/wiqd-core.md`) — on subsequent `wiqd` calls so the resolved routing is observable. Never run a command or make a network request solely for telemetry; CLI-free and file-only flows remain telemetry-free.

Existing projects created by the retired `wiqd agent create` do not need to be
recreated. Project-scoped `wiqd plugin` commands recognize Microsoft 365 Agents
projects structurally from contained `m365agents.yml` and
`appPackage/manifest.json`, derive identity and capabilities from the root app
manifest, and never write identity/cache metadata. A historical
`wiqd.plugin.json` is ignored and can be deleted manually after checking that no
external tooling depends on it. Surface structural or component-reference
failures exactly as the CLI reports them.

## Journey map

```
        Build               Improve              Preview              Publish      
  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
  │ create         │   │ eval           │   │ package        │   │ partner-center │
  │ edit           │ → │ validate       │ → │ provision      │ → │ publish        │
  │ instructions   │   │                │   │ share          │   │ monitor        │
  │ capabilities   │   │                │   │                │   │                │
  │ localize       │   │                │   │                │   │                │
  └────────────────┘   └────────────────┘   └────────────────┘   └────────────────┘
```

### Phase 1 — Build

- **Entry:** No `appPackage/` directory, or user wants to continue editing
- **Goal:** Get a project on disk and define what the agent does
- **Workflow:** read `workflows/wiqd-core.md` — handles create, edit with source prechecks, migrate, localize
- **Exit:** `appPackage/manifest.json` and `declarativeAgent.json` exist and are structurally valid

### Phase 2 — Improve

- **Entry:** Manifest is structurally valid
- **Goal:** Confirm the agent works as intended; iterate until quality bar is met
- **Workflow:** read `workflows/eval.md` for generate/run/analyze evals, read `workflows/validation.md` for source, package and Marketplace validation and authorized repair
- **Exit:** Evals pass at acceptable rate

### Phase 3 — Preview

- **Entry:** Quality bar met
- **Goal:** Deploy the agent and share with early users
- **Workflow:** read `workflows/wiqd-core.md` — handles package → provision → share
- **Exit:** Agent provisioned and shared with preview audience

### Phase 4 — Publish

- **Entry:** Preview complete
- **Goal:** Get the agent in front of users and monitor performance
- **Workflow:** read `workflows/partner-center.md` for public 3P publishing via Partner Center, read `workflows/wiqd-core.md` for publish (3P), read `workflows/workiq.md` for monitor
- **Exit:** Agent live in target audience, monitored
- **Iteration:** Real users → metrics/feedback → loop back to Build/Improve → re-package → re-publish
## Operating loop

Every turn:

1. **Discover** the project once per session (cache). Scan the working directory for project files and determine current state. If shell tools fail, fall back to `view`/`glob`/`grep`.

2. **Locate the user on the journey:**

| Signal | Phase |
   |---|---|
   | No `appPackage/` at all | **Build** (start with create/migrate) |
   | `appPackage/` exists, no evals yet | **Build** or **Improve** |
   | Evals exist, agent not packaged/provisioned | **Improve** |
   | Agent packaged/provisioned | **Preview** |
   | Partner (3P), package ready, not yet in the store | **Publish** via Partner Center |
   | Reviews done (or 3P), not published | **Publish** |
3. **Decide the next step.** Name the workflow, say _why_, then read it before choosing the journey marker.

4. **Orient** — show one journey marker and a one-line "you are here".
   On every new request or mode switch, including plan-only requests, emit a fresh
   marker before the plan or next question. Do not rely on an earlier turn's marker
   or treat its temporary override as the caller's navigation for the new request.
   Use the selected workflow's navigation override only when its request/mode guard matches.
   An applicable override replaces the default marker below; never show both.
   Without an applicable override, retain the caller's navigation or use this default:
   <!-- BEGIN JOURNEY_MARKER (auto-generated from workflow journey metadata — do not edit by hand) -->
   `📍 ▶ Build → Improve → Preview → Publish`
5. **After the workflow returns**, restore the caller's navigation, summarize outcome,
   re-locate user, and offer 1–3 logical next steps. Do not carry a temporary navigation
   override into another mode or a new request. Navigation never authorizes stage execution.

## Multi-phase plans

When the user asks for something spanning multiple phases, seed a `todo` plan:

```
1. validate manifest                   (wiqd-core)
2. generate evals                      (eval)
3. run evals + iterate                 (eval, loop)
4. package + provision                 (wiqd-core)
5. share with preview users            (wiqd-core)
6. package + submit to Partner Center  (partner-center)
7. publish                             (wiqd-core)
8. monitor                             (workiq)
```
## Readiness checklist

When a user asks "am I ready to publish?":

```
📋 Publish Readiness Checklist
  ☐ Saved source validates clean  → wiqd plugin validate --mode source
  ☐ Evals pass quality bar        → evals/runs/ has recent passing run
  ☐ Package builds successfully   → wiqd plugin package
  ☐ Preview deployment ready      → package + provision completed
  ☐ Preview audience has access   → share completed for test users
```
Check each item programmatically. Report ✅ or ❌ with what's needed. Drive the first ❌ item.

## Anti-patterns

- ❌ Don't bypass workflow files — they have validation and safeguards you need.
- ❌ Don't edit project files without reading the relevant workflow first.
- ❌ Don't help weaken eval suites — fix the agent, not the bar.
- ❌ Don't dump the journey map every turn — show `📍` marker + one-line summary.
- ❌ Don't ask permission for the obvious next step — move.
- ❌ Don't improvise project changes — all file mutations go through workflows.
