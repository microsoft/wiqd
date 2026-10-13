---
title: Azure-hosted OpenAPI servers for declarative agents
description: How wiqd coordinates an external server and connects its verified OpenAPI contract
---

# Azure-hosted OpenAPI servers for declarative agents

wiqd already connects a declarative agent to an existing OpenAPI server. When
the server does not exist yet, the wiqd skill coordinates official Azure skills
that independently create and deploy it, then passes only the verified endpoint
and OpenAPI contract into the same `wiqd agent add action` flow.

> **Availability:** This experimental journey is provided by
> `microsoft.wiqd.core`, wiqd's single lifecycle provider. Connecting a contract for an already-deployed server remains
> available through the normal Action flow when the request does not also ask
> wiqd to create or deploy that server.

This journey starts only when you explicitly ask for a new backend, server, or
API. Creating an agent without requesting an OpenAPI server uses the normal
Create workflow and does not prompt for server authentication or check Azure/Entra
skills.

```text
describe the OpenAPI server
  -> for Entra-backed Generic OAuth, Entra supplies the non-secret application identity before deployment needs it
  -> Azure skills select a host, create, validate, and deploy it
  -> wiqd connects its OpenAPI contract to the agent
  -> wiqd validates the agent
  -> when requested, provisioning creates or reuses the Microsoft 365 OAuth registration
```

This is one continuous journey. Describe the operations and, if you already
know it, choose anonymous, API-key, or Generic OAuth authentication. If you
do not specify authentication, Copilot asks which of those three shapes you
prefer before it changes the project or creates cloud resources. You do not
need to name the owning skills, copy prompts between them, run each wiqd
command yourself, or ask Copilot to continue after every phase.

The same request may create a new Declarative Agent and its OpenAPI server. wiqd
resolves authentication and checks the required Azure capability first. For
Generic OAuth, it also checks the Entra skill prerequisite. It then creates the
agent, coordinates the external server as a separate ownership lane, and
returns its contract to the Action flow without requiring a second request.

## Starting points

The journey supports both:

- **An existing Declarative Agent project:** wiqd validates the existing project
  boundary, selects a separate application workspace outside the agent project,
  coordinates only the requested external server there, and adds its Action. It
  preserves the current Microsoft 365 app and Title ID, environments,
  capabilities, Actions, and valid lifecycle or OAuth registrations. It does
  not recreate or re-scaffold the agent.
- **A new agent and OpenAPI server in one request:** wiqd completes the normal agent
  authentication and skill-prerequisite checks first, completes the normal
  agent creation flow, selects a separate application workspace outside the new
  agent project, and then continues through the same server journey.

Both paths use the same Azure delegation and, for Generic OAuth, Entra identity
delegation, followed by Action validation and requested end-to-end verification.

Copilot pauses only when it needs a product decision, an Azure or Entra target
cannot be inferred, a cloud or identity mutation needs approval, you must check
an exact OAuth configuration identifier in the Teams Developer Portal under the
verified account and tenant, you must perform an approved deletion of an old
Microsoft 365 OAuth configuration in that Portal, you must supply a required
credential through an approved secure environment flow, or you must complete
interactive sign-in or consent. The same journey keeps its state and continues
after the required approval or confirmation.

## Prerequisites

Install and enable the official Microsoft Azure skills before starting. The
current session must include a skill capable of owning application hosting,
deployment, and endpoint verification. Every Generic OAuth journey also
requires the official `entra-app-registration` skill, including when it reuses
an existing client, because readiness verifies the application, service
principal, credential contract, redirect URI, scopes, and owners. Anonymous
and API-key servers do not require the Entra skill.

Copilot checks these prerequisites before changing the project or creating
cloud resources. If one is missing, it identifies what to install. Start a new
Copilot session after installation so the session's skill registry includes the
new provider.

## What wiqd coordinates

wiqd gathers the API operations, behavior, authentication requirements, and
runtime constraints. After Azure deployment, it connects the returned OpenAPI
document with `wiqd agent add action` and validates the project. It owns the
Declarative Agent lifecycle, not the OpenAPI server application lifecycle.

## What Azure and Entra own

Official Azure skills own hosting-service selection, server implementation,
infrastructure, deployment, endpoint verification, and diagnostics. When
Entra-backed Generic OAuth is selected, the Microsoft Entra skill owns the
OAuth client and resource-application registration.

If a required skill is unavailable, the workflow stops and names it. It does
not fall back to generated infrastructure or sample code.

## Lifecycle boundary

Backend source, infrastructure, deployment artifacts, and hosting lifecycle are
application-owned and remain outside the Declarative Agent project. Only the
verified endpoint and OpenAPI contract cross into the Action flow.
wiqd runs the selected Azure workflow from that separate application workspace
after resolving canonical paths and confirming that neither workspace contains
the other. It stops before attaching the Action if the returned workspace
differs from the recorded workspace, returned artifacts escape that workspace,
or the owning skills created or modified backend artifacts in the agent
project.

`m365agents.yml` also stays focused on Microsoft 365 and Teams lifecycle
operations. Azure resource provisioning and server deployment do not belong
in that file.

## Supported server shapes

- **Anonymous:** the server requires no caller credential.
- **API key:** the server and existing wiqd Action flow use secure
  API-key handling.
- **Generic OAuth:** the existing Action flow uses Microsoft Entra
  authorization and token endpoints, delegated scopes, a client ID, and either
  a confidential client secret or PKCE. `entra-app-registration` creates,
  reuses, verifies, or repairs that client.

Generic OAuth providers other than Microsoft Entra are not supported by this
experimental journey. If you explicitly request Auth0, Okta, GitHub, a custom
authorization server, or another provider, Copilot reports that boundary and
stops before creating or changing the agent project, Azure resources, or
identity resources. It does not silently replace your provider with Entra or
another authentication shape.

Azure returns an HTTPS endpoint, OpenAPI document, operation selectors,
authentication shape, and deployment evidence. wiqd adds it with
`wiqd agent add action --openapi-spec`.

Every selected operation must use the authentication shape chosen for that
Action. Anonymous health, readiness, and OpenAPI diagnostics stay out of an
API-key or Generic OAuth Action instead of being combined with protected
operations under multiple authentication runtimes.

Secrets remain in the secure authentication and environment flows owned by the
respective tools. They are not copied into manifests or chat summaries.

The returned OpenAPI document must include a runtime `servers` URL for the
verified HTTPS endpoint. When a deployed server omits it, wiqd may use a local
corrected copy that adds only that endpoint before attaching the Action.

## Generic OAuth flow

Generic OAuth uses the existing `oauth` Action identity-provider contract. The
OpenAPI security scheme identifies the provider's authorization and token
endpoints and delegated scopes. The Action uses a confidential client with a
securely stored client secret, or a public client with PKCE. This proposal does
not use the native Microsoft Entra Action identity-provider contract.

For Generic OAuth, the Entra skill may create or reuse the single application
that acts as both the OAuth client and backend resource API, plus its Enterprise
Application/service principal, delegated scope, redirect URI, and client
credential when required. It assigns the current signed-in user as owner of
both Entra objects by default. If tenant policy requires a group or service
principal owner instead, that governed owner is included in the mutation
approval. Reusing or repairing an application preserves its existing owners.
Creating or rotating a confidential-client credential on a reused application
also preserves all unrelated passwords, certificates, and federated
credentials. wiqd requires a non-secret before/after credential inventory and a
preservation receipt from the Entra skill, and stops if that evidence is
missing. The previous credential remains until affected consumers verify the
replacement. A reset that removes other credentials requires separate approval
that names the affected consumers.

Before first provision, the Entra skill configures the Microsoft 365 Generic
OAuth callback, `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`,
on the client. This journey does not use the native Entra SSO
`oAuthConsentRedirect` callback. Provisioning then creates or reuses the
Microsoft 365 OAuth registration and records its configuration ID; the
registration step does not return the callback URI. Before asking you to sign
in, wiqd verifies the provider endpoints, client type and ID, configured
platform callback, scopes, client-secret or PKCE contract, OAuth registration
reference, issued-token version, backend issuer and audience validation,
application, service principal, and their explicit owners. When the provider
and backend use the Microsoft identity platform v2 contract, the Entra resource
application must set `api.requestedAccessTokenVersion` to `2`; an unset value
can produce a v1 access token that the v2 backend rejects with `401
invalid_token`.

Before provisioning, wiqd also completes the existing API-plugin checklist,
including authentication and required inputs, operation descriptions, complete
Adaptive Cards, and confirmations for state-changing operations. Required root
fields and nested collections must both survive rendering. Provisioning uses
the canonical environment-specific validation, shared-agent versioning, and
test-link flow. Live verification runs read-only operations by default;
state-changing operations require your explicit approval against a disposable
or test target. The final OAuth check uses a real delegated token through the
Declarative Agent; successful registration or consent alone is not the
end-to-end result.
The agent is not reported as ready while either the OAuth readiness gate or live
sign-in verification is pending.

## Automatic recovery

Known recoverable failures stay inside the journey. Azure skills repair
unhealthy deployments; wiqd supplies a constrained local OpenAPI correction or
fixes generated response bindings. Entra application, service-principal,
redirect, credential, exposed-scope, and ownership failures return to the Entra
skill. Deployed-server, OpenAPI provider metadata, issuer, audience, and backend
authorization failures return to the owning Azure skill. Action authentication,
Microsoft 365 OAuth configuration, configuration-identifier, and secure
environment failures are routed according to the registration state. If the
identifier is empty, canonical Action authentication setup completes the
missing inputs before provisioning creates the registration. If the canonical
provisioning flow cannot retrieve a populated identifier, its warning alone
does not prove that the registration is absent. After wiqd verifies the signed-in
account and tenant, you check that exact identifier in the Teams Developer
Portal. If the record is absent, wiqd clears the stale environment value and
provisions a new identifier without asking you to delete a record that is
already absent. If the Portal cannot be accessed or the result is uncertain,
wiqd changes nothing and provides account and tenant guidance. A valid
registration with unchanged stored inputs is preserved while wiqd repairs only
local Action or secure-environment state. A registration that still exists but
is inconsistent, or whose stored OAuth inputs must change, including a
client-secret rotation, uses **Option B — start over**. After you approve the
repair, you
delete the old configuration in the Teams Developer Portal because wiqd cannot
delete it; wiqd then clears the environment value and provisions a new
identifier. Every affected copy still using the old identifier must be
provisioned again. Reprovisioning alone does not rewrite an existing OAuth
registration. Other provisioning-state failures return directly to canonical
provisioning.
The orchestration preserves the non-secret OAuth configuration identifier only
while the registration remains valid and its stored inputs are unchanged;
canonical authentication recovery replaces an invalid identifier. It does not
prescribe a backend-specific lifecycle action. You approve any new cloud
mutation, but you do not have to transport error details or repair instructions
between skills.

For an end-to-end request, Copilot returns one final summary covering server
deployment, Action attachment, validation, provisioning, authentication, and
the live agent result.
