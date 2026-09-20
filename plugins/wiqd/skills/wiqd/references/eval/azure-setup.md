# Azure OpenAI Credential Setup

Reference for configuring the Azure judge routes used by the eval skill: local Azure OpenAI for GPT-4.x, or Microsoft Foundry cloud evaluation for GPT-5.x/o-series.

---

## When Azure OpenAI Is Required

**Most runs don't need this file.** wiqd's default judge backend is `github-copilot` (`--judge-backend github-copilot`), which authenticates via `gh auth login` (or `GITHUB_TOKEN`) and needs no Azure setup at all.

The Eval CLI (`runevals` from `@microsoft/m365-copilot-eval`) can use GitHub Copilot, local Azure OpenAI, or Microsoft Foundry cloud evaluation for its four built-in LLM evaluators (Relevance, Coherence, Groundedness, Similarity). Azure setup is needed for these routes:

- **GPT-4.x with `--judge-backend azure`** — uses local Azure OpenAI evaluators.
- **Custom `.prompty` evaluators** (e.g. a project's own `AssertionJudge`) — their Python wrapper always receives an Azure OpenAI model configuration; this is independent of `--judge-backend` and has no GitHub Copilot equivalent.
- **GPT-5.x or o-series judge models** via Microsoft Foundry cloud evaluation under `--judge-backend azure` — set `AZURE_AI_PROJECT_ENDPOINT` and `AZURE_AI_MODEL_NAME`. This path uses Entra and does not require an Azure OpenAI endpoint, API version, or API key.

See [judge-backends.md](judge-backends.md) for the complete evaluator compatibility matrix — every built-in evaluator except custom `.prompty` ones works fine under `--judge-backend github-copilot`.

Without the variables and authentication required by the selected Azure route, the run fails before scoring. Custom `.prompty` evaluators require the local Azure OpenAI configuration even when Foundry variables are present.

---

## Configuration by model family

Store credentials in the user override paired with the selected base environment: `.env.local.user` for `.env.local`, or `.env.dev.user` for `.env.dev`. The Eval CLI searches both the project root and `env/`.

| Model route                | Required judge variables                                                                                           | Authentication                                                         |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| GPT-4.x local Azure OpenAI | `AZURE_AI_OPENAI_ENDPOINT`, `AZURE_AI_API_VERSION`, `AZURE_AI_MODEL_NAME`; leave `AZURE_AI_PROJECT_ENDPOINT` unset | `AZURE_AI_API_KEY`, or `DefaultAzureCredential` when the key is absent |
| GPT-5.x/o-series Foundry   | `AZURE_AI_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_NAME`                                                                 | Entra `DefaultAzureCredential`; `AZURE_AI_API_KEY` is unused           |

`TENANT_ID` is required separately for the M365 agent connection. Set `AZURE_TENANT_ID` only when the Azure credential must use a different tenant.

---

## Finding Your Credentials

### Endpoint and API Key

For the local GPT-4.x route:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your **Azure OpenAI** resource
3. In the left menu, select **Keys and Endpoint**
4. Copy **Endpoint** → use as `AZURE_AI_OPENAI_ENDPOINT`
5. For key authentication, copy **KEY 1** or **KEY 2** → use as `AZURE_AI_API_KEY`. Omit it to use `DefaultAzureCredential`.

### Foundry Project Endpoint and Model

For the GPT-5.x/o-series route:

1. Open the project in [Microsoft Foundry](https://ai.azure.com/).
2. Copy the project endpoint from the project overview → use as `AZURE_AI_PROJECT_ENDPOINT`.
3. Deploy or select a chat-capable GPT-5.x/o-series model and copy its deployment name → use as `AZURE_AI_MODEL_NAME`.
4. Grant the evaluating identity the **Azure AI Developer** role on the project.
5. Use an existing Entra sign-in or workload identity; no API key is used.

### Tenant ID

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID**
3. Select **Overview**
4. Copy **Tenant ID** from the overview pane → use as `TENANT_ID`

---

## Interactive Setup Workflow

When the `m365-agent-evaluator` skill offers interactive credential setup, it will:

1. Ask whether the user wants the local GPT-4.x route or the GPT-5.x/o-series Foundry route.
2. Collect only the variables listed for that route above.
3. Confirm `TENANT_ID` is available for the M365 agent connection.
4. For local Azure, explain that a non-empty `AZURE_AI_API_KEY` selects key authentication; an absent key selects `DefaultAzureCredential`.
5. For Foundry, verify Entra sign-in and the Azure AI Developer role; never request an API key.
6. Write each approved value to the selected `.env.<environment>.user` file one at a time.
7. Confirm success without displaying secret values.

- If blank input is provided for any credential, the skill will reject it and re-prompt once. If the second attempt is also blank, setup is aborted and the user is asked to re-run when ready.

If a value already exists in the selected `.user` file, the skill will ask for explicit confirmation before overwriting it. Existing values are not silently replaced.

---

## Manual Setup

To configure a local GPT-4.x judge manually:

```
AZURE_AI_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
TENANT_ID=your-tenant-id-here
AZURE_AI_API_VERSION=2024-12-01-preview
AZURE_AI_MODEL_NAME=gpt-4o
AZURE_AI_API_KEY=your-optional-key-here
```

To configure a GPT-5.x/o-series judge through Foundry:

```
TENANT_ID=your-m365-tenant-id
AZURE_AI_PROJECT_ENDPOINT=https://your-account.services.ai.azure.com/api/projects/your-project
AZURE_AI_MODEL_NAME=gpt-5-mini
```

The Foundry path uses Entra authentication. Do not add `AZURE_AI_API_KEY` for it. Add `AZURE_TENANT_ID` only when the Foundry project is in a different tenant than the active credential.

---

## Keeping Secrets Out of Git

The `.user` credential files MUST be git-ignored. After writing credentials, verify your `.gitignore` includes:

```
.env.local.user
.env.dev.user
env/.env.*.user
```

**If a `.user` credential file is already tracked by git:**

1. Stop tracking it with `git rm --cached <credential-file>`
2. Add it to `.gitignore`
3. Commit the removal
4. **Rotate the key immediately** — treat any committed key as compromised regardless of how briefly it was in history

Never print or log credential values. Avoid `echo $AZURE_AI_API_KEY` or any debug dump of environment variables containing secrets.

---

## CI/CD Configuration

In pipelines, credentials must never be stored in committed files. Inject them as environment variables from your platform's secret store:

| Platform        | Secret Storage                   | How to Inject                                                        |
| --------------- | -------------------------------- | -------------------------------------------------------------------- |
| GitHub Actions  | Repository Secrets               | `env: AZURE_AI_API_KEY: ${{ secrets.AZURE_AI_API_KEY }}`             |
| Azure DevOps    | Variable Groups (mark as secret) | Link variable group to pipeline; variables are available as env vars |
| Azure Key Vault | Key Vault secrets                | Reference via Azure DevOps Key Vault task or GitHub OIDC             |

The Eval CLI reads the variables for the selected route from the environment; no `.env.local` file is required in CI when they are injected directly.

---

## No-Overwrite Protection

If the selected `.user` file already contains a value for any variable required by the selected route, the skill will:

1. Display the existing value (masked for API keys)
2. Ask explicitly: "This value already exists. Overwrite? (y/N)"
3. Only replace the value if the user confirms with `y`

Declining the prompt leaves the existing value unchanged.

---

## Common Errors

| Symptom                                                               | Cause                                                           | Resolution                                                                             |
| --------------------------------------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `runevals` reports connection error                                   | `AZURE_AI_OPENAI_ENDPOINT` is missing or malformed              | Verify endpoint is set and matches the format `https://<resource>.openai.azure.com/`   |
| Local `runevals` reports authentication error                         | API key is invalid, or `DefaultAzureCredential` is unavailable  | Verify the selected auth mode and Azure identity                                       |
| Foundry setup reports authentication/permission error                 | Entra session missing or identity lacks Azure AI Developer role | Sign in interactively and grant the required project role                              |
| GPT-5.x local evaluator returns `unsupported_parameter`               | GPT-5.x Responses API rejects local evaluator `response_format` | Configure `AZURE_AI_PROJECT_ENDPOINT` and run with `--judge-backend azure`             |
| Agent context unavailable, evals fail                                 | `TENANT_ID` is missing                                          | Add your Microsoft 365 tenant ID to the selected base or `.user` environment file      |
| `Error: Missing required environment variables: AZURE_AI_API_VERSION` | `AZURE_AI_API_VERSION` is not set                               | Add `AZURE_AI_API_VERSION` (e.g. `2024-12-01-preview`) to the selected `.user` file    |
| `Error: Missing required environment variables: AZURE_AI_MODEL_NAME`  | `AZURE_AI_MODEL_NAME` is not set                                | Add `AZURE_AI_MODEL_NAME` (e.g. `gpt-4o`) to the selected `.user` file                 |
| LLM-as-judge calls fail with region error                             | Model deployment is in a different region than the endpoint     | Ensure the model deployment and the Azure OpenAI resource are in the same Azure region |

---

## Env Vars Forwarded to runevals

When the skill executes `runevals`, it forwards the variables required by the selected route:

```
# Common M365 agent context
TENANT_ID

# GPT-4.x local Azure route
AZURE_AI_OPENAI_ENDPOINT
AZURE_AI_API_VERSION
AZURE_AI_MODEL_NAME
AZURE_AI_API_KEY (optional)

# GPT-5.x/o-series Foundry route
AZURE_AI_PROJECT_ENDPOINT
AZURE_AI_MODEL_NAME
AZURE_TENANT_ID (optional)
```

Do not require or forward unused secrets merely because another route uses them.
