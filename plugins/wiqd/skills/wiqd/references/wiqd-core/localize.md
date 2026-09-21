# Agent Localize

**Telemetry:** `--skill wiqd`

Automate the full localization workflow — scan, tokenize, translate, wire, validate, deploy.

## Core Rule: Two Workflows

**BEFORE doing anything, detect which workflow applies:**

| Signal                                                                     | Workflow                                                                                                   |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| No `localizationInfo` in `manifest.json` AND no `[[TOKEN]]` in DA manifest | **A — Full Localization** (scan → tokenize → translate → wire → validate → deploy)                         |
| `localizationInfo` exists AND manifests use `[[TOKEN]]`                    | **B — Add Language** (read existing → translate → add language file → update manifest → validate → deploy) |

**⛔ Check `manifest.json` for `localizationInfo` AND `declarativeAgent.json` for `[[` tokens BEFORE proceeding.**

---

## Workflow A: Full Localization (No Existing Localization)

### Phase 1: Scan

Read all manifest files and build an inventory of localizable strings.

**Files to scan:**

- `appPackage/declarativeAgent.json` — fields: `name`, `description`, `conversation_starters[].title`, `conversation_starters[].text`, `disclaimer.text`
- `appPackage/plugin.json` (if exists) — fields: `name_for_human`, `description_for_human`, `description_for_model`, `conversation_starters[].title`, `conversation_starters[].text`
- `appPackage/manifest.json` — fields: `name.short`, `name.full`, `description.short`, `description.full`

**⛔ NEVER include `instructions` in the localizable list.** Instructions are consumed by the LLM in a single language.

**Show the user** a summary of all found strings with their current values.

### Phase 2: Plan — Generate Tokens and Ask for Languages

Generate descriptive UPPER_SNAKE_CASE tokens for each localizable field:

| Source      | Field                            | Token Pattern                 |
| ----------- | -------------------------------- | ----------------------------- |
| DA manifest | `name`                           | `AGENT_NAME`                  |
| DA manifest | `description`                    | `AGENT_DESCRIPTION`           |
| DA manifest | `conversation_starters[N].title` | `AGENT_STARTER_{SLUG}_TITLE`  |
| DA manifest | `conversation_starters[N].text`  | `AGENT_STARTER_{SLUG}_TEXT`   |
| DA manifest | `disclaimer.text`                | `AGENT_DISCLAIMER`            |
| Plugin      | `name_for_human`                 | `PLUGIN_NAME`                 |
| Plugin      | `description_for_human`          | `PLUGIN_DESCRIPTION`          |
| Plugin      | `description_for_model`          | `PLUGIN_MODEL_DESCRIPTION`    |
| Plugin      | `conversation_starters[N].title` | `PLUGIN_STARTER_{SLUG}_TITLE` |
| Plugin      | `conversation_starters[N].text`  | `PLUGIN_STARTER_{SLUG}_TEXT`  |

**Slug generation** from conversation starter title:

- Lowercase, replace spaces with underscores, remove special chars
- Keep first 2-3 meaningful words: "Q1 pipeline review" → `pipeline`, "Password reset" → `password`
- Token key must match: `^[a-zA-Z_][a-zA-Z0-9_]*$`

**Show the tokenization plan to the user** — table of field → current value → proposed token.

**Ask for target languages:**

```
🌍 What languages should this agent support?
Default: English (en)
Please list additional languages (e.g., French, Spanish, Japanese).
```

### Phase 3: Tokenize

After user confirms plan and languages:

1. **Externalize instructions** if inline:
   - Extract `instructions` value → write to `appPackage/instructions.txt`
   - Replace with `"instructions": "$[file('instructions.txt')]"`
2. **Replace** all localizable string values with `[[TOKEN]]` in `declarativeAgent.json`
3. **Replace** all localizable string values with `[[TOKEN]]` in `plugin.json` (if exists)
4. **Show diff** of changes

**⛔ POST-TOKENIZATION CHECKPOINT:**

- [ ] `name` uses `[[AGENT_NAME]]`
- [ ] `description` uses `[[AGENT_DESCRIPTION]]`
- [ ] Every `conversation_starters[].title` uses a `[[token]]`
- [ ] Every `conversation_starters[].text` uses a `[[token]]`
- [ ] `instructions` is NOT tokenized
- [ ] Plugin fields (if any) use `[[token]]` syntax

### Phase 4: Translate

**Default language file (`en.json`):**
Use the original English values extracted in Phase 1.

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json",
  "name.short": "<original short name from manifest>",
  "name.full": "<original full name from manifest>",
  "description.short": "<original short description from manifest>",
  "description.full": "<original full description from manifest>",
  "localizationKeys": {
    "[[AGENT_NAME]]": "<original DA name>",
    "[[AGENT_DESCRIPTION]]": "<original DA description>",
    ...all tokens with original English values
  }
}
```

**Additional language files:**
Translate ALL strings using your multilingual capabilities.

**Translation rules:**

- Be context-aware — use domain-appropriate terminology
- Respect character limits: `name.short` ≤ 30, `name.full` ≤ 100, `description.short` ≤ 80, `description.full` ≤ 4000, `plugin name_for_human` ≤ 20
- `localizationKeys` keys MUST use `[[TOKEN]]` format (e.g., `"[[AGENT_NAME]]"`, NOT `"AGENT_NAME"`)
- Translations should read naturally, not word-for-word
- Keep terminology consistent within a language
- If user provided translations for specific fields, use those exactly

**Show translations to user for review** before writing files.

**If user provides their own translations** for some strings, use those and translate only the remaining ones.

### Phase 5: Wire

Add `localizationInfo` to `manifest.json`:

```json
{
  "localizationInfo": {
    "defaultLanguageTag": "en",
    "defaultLanguageFile": "en.json",
    "additionalLanguages": [
      { "languageTag": "fr", "file": "fr.json" },
      { "languageTag": "es", "file": "es.json" }
    ]
  }
}
```

### Phase 6: Validate

Cross-check everything:

1. **Token consistency** — every `[[TOKEN]]` in manifests has a matching `[[TOKEN]]` key in every language file's `localizationKeys`
2. **Key parity** — all language files have the exact same set of `localizationKeys` keys
3. **Required fields** — every language file has `name.short`, `description.short`, `description.full` (required per schema); `name.full` is recommended but optional
4. **Character limits** — no translated string exceeds its field's max length
5. **Schema** — all language files reference `$schema` URL `https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json`
6. **Key format** — all `localizationKeys` keys use `[[TOKEN]]` format matching pattern `^\[\[[a-zA-Z_][a-zA-Z0-9_]*\]\]$`
7. **Instructions** — verify `instructions` is NOT tokenized

**Show validation results to user.**

### Phase 7: Deploy

```bash
wiqd agent provision --skill wiqd --env local
```

Read `M365_TITLE_ID` from `env/.env.local` and present the test link: `https://m365.cloud.microsoft/chat?titleId={M365_TITLE_ID}`

**⛔ Never skip deployment after localization changes.**

---

## Workflow B: Add Language (Existing Localization)

When the agent is already localized:

### Step B1: Read Existing Setup

1. Read `manifest.json` → note `localizationInfo` (default language, existing additional languages)
2. Read default language file (e.g., `en.json`) → note ALL `localizationKeys` keys
3. Confirm `declarativeAgent.json` uses `[[token]]` syntax

### Step B2: Ask for New Language(s)

Show existing languages, ask which to add.

### Step B3: Translate

Translate all strings (using existing default language values as source) into the new language(s).

**⛔ CRITICAL:** New language file MUST have the EXACT SAME `localizationKeys` keys as the default file.

Show translations to user for review.

### Step B4: Wire

Add new language entry to `additionalLanguages` in `manifest.json`.

**⛔ Do NOT modify existing language files or the default language file.**

### Step B5: Validate + Deploy

Same as Workflow A Phases 6-7.

---

## Anti-Patterns — NEVER Do These

| ❌ Anti-Pattern                                                | Why It Fails                                                       | ✅ Correct Approach                                |
| -------------------------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------- |
| Replacing strings directly with translated text in DA manifest | Only one language works at a time                                  | Use `[[token]]` syntax + language files            |
| Tokenizing the `instructions` field                            | Instructions consumed by LLM in single language                    | Use `$[file('instructions.txt')]` — never tokenize |
| Creating language files without tokenizing manifests first     | `localizationKeys` have no effect without `[[token]]` in manifests | Always tokenize BEFORE creating language files     |
| Inventing translations without showing the user                | Translations may be inaccurate                                     | Always show translations for user review           |
| Creating a language file with different keys than the default  | Missing keys cause runtime resolution failures                     | Copy key names from default file exactly           |
| Skipping the default language file                             | Default language file required when `localizationInfo` is present  | Always create the default language file first      |

---

## Localizable Fields Quick Reference

**Declarative Agent:**

| Field                            | Token                            | Max Length | Required |
| -------------------------------- | -------------------------------- | ---------- | -------- |
| `name`                           | `[[AGENT_NAME]]`                 | 100        | ✔️       |
| `description`                    | `[[AGENT_DESCRIPTION]]`          | 1,000      | ✔️       |
| `conversation_starters[N].title` | `[[AGENT_STARTER_{SLUG}_TITLE]]` | —          |          |
| `conversation_starters[N].text`  | `[[AGENT_STARTER_{SLUG}_TEXT]]`  | —          |          |
| `disclaimer.text`                | `[[AGENT_DISCLAIMER]]`           | —          |          |

**API Plugin:**

| Field                   | Token                          | Max Length | Required |
| ----------------------- | ------------------------------ | ---------- | -------- |
| `name_for_human`        | `[[PLUGIN_NAME]]`              | 20         | ✔️       |
| `description_for_human` | `[[PLUGIN_DESCRIPTION]]`       | 100        | ✔️       |
| `description_for_model` | `[[PLUGIN_MODEL_DESCRIPTION]]` | 2,048      |          |

**App Manifest (language file keys, NOT tokens):**

| Key                 | Max Length | Required    |
| ------------------- | ---------- | ----------- |
| `name.short`        | 30         | ✔️          |
| `name.full`         | 100        | Recommended |
| `description.short` | 80         | ✔️          |
| `description.full`  | 4,000      | ✔️          |

---

## Completion

After successful localization, summarize:

- Files created (language files)
- Files modified (DA manifest, plugin manifest, app manifest)
- Languages supported
- Test link

If the user wants to add more languages later, they can invoke this skill again — it will detect Workflow B.

## Error Handling

| Error                                            | Action                                                            |
| ------------------------------------------------ | ----------------------------------------------------------------- |
| No `declarativeAgent.json`                       | Create an agent first                                             |
| No `manifest.json`                               | Create an agent first                                             |
| Token collision (two starters produce same slug) | Append numeric suffix                                             |
| Character limit exceeded in translation          | Warn user, suggest shorter alternative                            |
| Invalid language tag                             | Suggest valid BCP-47 tag                                          |
| Existing language file for requested language    | Ask user: update or skip?                                         |
| Provision fails                                  | Show error, suggest _"provision my agent with verbose output"_    |

---

## ⛔ FINAL GATE — Before Responding to the User

**STOP.** Before writing your response, verify ALL of the following:

- [ ] `declarativeAgent.json` uses `[[token]]` syntax for ALL localizable fields
- [ ] `instructions` is NOT tokenized
- [ ] Default language file exists with `name.short`, `description.short`, `description.full` (required), `name.full` (recommended), and ALL `localizationKeys` using `[[TOKEN]]` format as keys
- [ ] Every additional language file has the EXACT SAME `localizationKeys` keys
- [ ] `manifest.json` has `localizationInfo` with `defaultLanguageTag`, `defaultLanguageFile`, and `additionalLanguages`
- [ ] Translations were shown to user for review
- [ ] Deployed with `wiqd agent provision --skill wiqd --env local`
- [ ] Presented the test link

**If any box is unchecked, you are NOT done.**

---

## Localization Workflow

### Quick Reference — Complete Localization Checklist

**For adding localization to an agent (Workflow A):**

1. ⛔ Tokenize `declarativeAgent.json` → replace `name`, `description`, all `conversation_starters[].title` and `.text` with `[[token]]` syntax
2. ⛔ Create language files → `en.json` (default) + one per additional language, each with `name.short`, `description.short`, `description.full` (required), `name.full` (recommended), and `localizationKeys` mapping EVERY token using `[[TOKEN]]` format as keys
3. ⛔ Update `manifest.json` → add `localizationInfo` with `defaultLanguageTag`, `defaultLanguageFile`, `additionalLanguages`
4. ⛔ Deploy → `wiqd agent provision --env local`

**For adding a language to an already-localized agent (Workflow B):**

1. Read existing default language file to get the list of `localizationKeys`
2. Create new `{lang}.json` with the SAME set of keys, translated values
3. Add new entry to `additionalLanguages` in `manifest.json`
4. ⛔ Deploy

---

This document provides step-by-step instructions for localizing an M365 Copilot declarative agent into multiple languages.

Localization spans two layers: the **app manifest** (`manifest.json`) and the **declarative agent manifest** (`declarativeAgent.json`). Both use the same set of language files, but reference strings differently.

> **Important:** If an agent supports more than one language, you must provide a separate language file for **every** supported language, including the default language. Single-language agents do not require language files.

---

### ⛔ STOP — READ THIS FIRST

#### Two Localization Scenarios

| Scenario                                                                                                                 | What to do                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Agent has NO localization yet** (no `localizationInfo` in `manifest.json`, no `[[tokens]]` in `declarativeAgent.json`) | Follow **Workflow A: Add Localization to an Agent** — you must tokenize, externalize instructions, create ALL language files, and update `manifest.json` |
| **Agent is ALREADY localized** (`localizationInfo` exists, manifests use `[[tokens]]`)                                   | Follow **Workflow B: Add a Language to an Already-Localized Agent** — you only create a new language file and update `localizationInfo`                  |

**⛔ MANDATORY:** You MUST check which scenario applies BEFORE making any changes. Read `manifest.json` to see if `localizationInfo` exists, and read `declarativeAgent.json` to see if it already uses `[[token]]` syntax.

#### ⛔ Anti-Patterns — NEVER Do These

| ❌ Anti-Pattern                                                                      | Why It Fails                                                                                                                                     | ✅ Correct Approach                                                                                                |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Replacing strings directly with translated text in `declarativeAgent.json`           | Hardcoded translations don't support multi-language switching. Only one language works at a time.                                                | Use `[[token]]` syntax and create language files with `localizationKeys`.                                          |
| Leaving instructions inline in `declarativeAgent.json` when localizing               | Instructions must be separated from localizable content. Inline instructions block proper tokenization.                                          | Create `appPackage/instructions.txt` and set `"instructions": "$[file('instructions.txt')]"`.                      |
| Creating language files without tokenizing `declarativeAgent.json` first             | Language file `localizationKeys` are only resolved when the manifest uses `[[token]]` syntax. Without tokens, the language files have no effect. | Always tokenize the manifest BEFORE creating language files.                                                       |
| Using `[[token]]` for the instructions field                                         | Instructions are NOT localizable. The LLM consumes them in a single language.                                                                    | Use `$[file('instructions.txt')]` for instructions. Never tokenize them.                                           |
| Setting `defaultLanguageTag` to a non-English language without an `en.json` fallback | The default language must have the default language file. English should typically be the default.                                               | Set `defaultLanguageTag: "en"` and `defaultLanguageFile: "en.json"`. Add other languages as `additionalLanguages`. |

#### How Localization Works

| Layer                          | Key style                                             | Example                                    |
| ------------------------------ | ----------------------------------------------------- | ------------------------------------------ |
| App manifest (`manifest.json`) | JSONPath expressions                                  | `name.short`, `description.full`           |
| Agent / plugin manifests       | Double-bracket tokens resolved via `localizationKeys` | `[[AGENT_NAME]]`, `[[PLUGIN_DESCRIPTION]]` |

Both types of localized strings live in the **same** language file per locale.

---

### Workflow A: Add Localization to an Agent

Use this workflow when localizing an agent for the **first time** — the agent currently has hardcoded strings and no `localizationInfo`.

#### Step A1: Tokenize Agent Manifests — MANDATORY

Replace ALL user-facing strings in `declarativeAgent.json` (and `plugin.json`, if applicable) with tokenized keys wrapped in double brackets (`[[key_name]]`).

**You MUST tokenize ALL of these fields:**

| Field                                 | Token example                                                |
| ------------------------------------- | ------------------------------------------------------------ |
| `name`                                | `[[AGENT_NAME]]`                                             |
| `description`                         | `[[AGENT_DESCRIPTION]]`                                      |
| Every `conversation_starters[].title` | `[[STARTER_TRAVEL_TITLE]]`, `[[STARTER_REMOTE_TITLE]]`, etc. |
| Every `conversation_starters[].text`  | `[[STARTER_TRAVEL_TEXT]]`, `[[STARTER_REMOTE_TEXT]]`, etc.   |
| `disclaimer.text` (if present)        | `[[DISCLAIMER_TEXT]]`                                        |

**Token key rules:**

- Must match the pattern: `^[a-zA-Z_][a-zA-Z0-9_]*$`
- Use descriptive, UPPER_SNAKE_CASE names (e.g., `STARTER_VPN_TITLE` not `key1`)
- Keep names consistent across agent and plugin manifests

**Example — tokenized `declarativeAgent.json`:**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v<x.y>/schema.json",
  "version": "v<x.y>",
  "name": "[[AGENT_NAME]]",
  "description": "[[AGENT_DESCRIPTION]]",
  "instructions": "$[file('instructions.txt')]",
  "conversation_starters": [
    {
      "title": "[[STARTER_VPN_TITLE]]",
      "text": "[[STARTER_VPN_TEXT]]"
    },
    {
      "title": "[[STARTER_SIGNIN_TITLE]]",
      "text": "[[STARTER_SIGNIN_TEXT]]"
    }
  ],
  "disclaimer": {
    "text": "[[DISCLAIMER_TEXT]]"
  }
}
```

**If API plugin exists — tokenize `plugin.json` too:**

```json
{
  "schema_version": "v<x.y>",
  "name_for_human": "[[PLUGIN_NAME]]",
  "description_for_human": "[[PLUGIN_DESCRIPTION]]",
  "description_for_model": "[[PLUGIN_MODEL_DESCRIPTION]]"
}
```

**⛔ NEVER skip tokenization.** Writing localization files without first tokenizing the manifests makes localization non-functional. The manifests MUST use `[[token]]` syntax for the language files to take effect.

**✅ POST-TOKENIZATION CHECKPOINT — Verify before proceeding to Step A2:**

- [ ] `name` field uses `[[AGENT_NAME]]` or similar token
- [ ] `description` field uses `[[AGENT_DESCRIPTION]]` or similar token
- [ ] Every `conversation_starters[].title` uses a `[[token]]`
- [ ] Every `conversation_starters[].text` uses a `[[token]]`
- [ ] `instructions` field is NOT tokenized (it should remain as `$[file('instructions.txt')]` or inline text — never `[[token]]`)

**If any box is unchecked, STOP and fix it before continuing.**

#### Step A2: Create Language Files — MANDATORY

Create one JSON file per language in `appPackage/`, named `{languageTag}.json` (e.g., `en.json`, `fr.json`, `ja.json`).

**Every language file MUST contain:**

1. **`$schema`** — The localization schema reference: `https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json`
2. **App manifest strings** — `name.short`, `description.short`, `description.full` (required per schema); `name.full` (recommended but optional)
3. **`localizationKeys` object** — One entry per `[[token]]` used in `declarativeAgent.json` and `plugin.json`, using the token name WITH `[[brackets]]` as the key (e.g., `"[[AGENT_NAME]]"`, NOT `"AGENT_NAME"`)

**Default language file (`en.json`) — use the ORIGINAL English values from the agent:**

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json",
  "name.short": "IT Help Desk",
  "name.full": "IT Help Desk Agent",
  "description.short": "Resolve common IT issues",
  "description.full": "Helps employees resolve common IT issues using internal knowledge bases and ticketing systems.",
  "localizationKeys": {
    "[[AGENT_NAME]]": "IT Help Desk Agent",
    "[[AGENT_DESCRIPTION]]": "Helps employees resolve common IT issues using internal knowledge bases and ticketing systems.",
    "[[STARTER_VPN_TITLE]]": "VPN issues",
    "[[STARTER_VPN_TEXT]]": "I can't connect to the corporate VPN. What should I try?",
    "[[STARTER_SIGNIN_TITLE]]": "Sign-in help",
    "[[STARTER_SIGNIN_TEXT]]": "How do I regain access to my account?",
    "[[DISCLAIMER_TEXT]]": "This agent provides general IT guidance. For urgent issues, contact the helpdesk directly."
  }
}
```

**Additional language file (`fr.json`) — use translations provided by the user:**

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json",
  "name.short": "Support informatique",
  "name.full": "Agent de support informatique",
  "description.short": "Résoudre les problèmes informatiques courants",
  "description.full": "Aide les employés à résoudre les problèmes informatiques courants à l'aide des bases de connaissances internes.",
  "localizationKeys": {
    "[[AGENT_NAME]]": "Agent de support informatique",
    "[[AGENT_DESCRIPTION]]": "Aide les employés à résoudre les problèmes informatiques courants à l'aide des bases de connaissances internes.",
    "[[STARTER_VPN_TITLE]]": "Problèmes de VPN",
    "[[STARTER_VPN_TEXT]]": "Je n'arrive pas à me connecter au VPN de l'entreprise. Que dois-je essayer ?",
    "[[STARTER_SIGNIN_TITLE]]": "Aide à la connexion",
    "[[STARTER_SIGNIN_TEXT]]": "Comment puis-je retrouver l'accès à mon compte ?",
    "[[DISCLAIMER_TEXT]]": "Cet agent fournit des conseils informatiques généraux. Pour les problèmes urgents, contactez le service d'assistance directement."
  }
}
```

**⛔ CRITICAL:** The `localizationKeys` in EVERY language file must have the EXACT SAME set of keys (in `[[TOKEN]]` format). If `en.json` has `[[AGENT_NAME]]`, `[[AGENT_DESCRIPTION]]`, `[[STARTER_VPN_TITLE]]`, etc., then `fr.json` must also have ALL of those same keys. Missing keys cause runtime resolution failures.

**If the user did not provide translations for some strings** (e.g., conversation starters), you MUST ask the user for them. Do NOT invent translations.

#### Step A3: Add `localizationInfo` to `manifest.json` — MANDATORY

Add the `localizationInfo` section to `manifest.json`:

```json
{
  "localizationInfo": {
    "defaultLanguageTag": "en",
    "defaultLanguageFile": "en.json",
    "additionalLanguages": [
      {
        "languageTag": "fr",
        "file": "fr.json"
      },
      {
        "languageTag": "es",
        "file": "es.json"
      }
    ]
  }
}
```

**Rules:**

- `defaultLanguageTag` and `defaultLanguageFile` are always required
- Each additional language needs an entry in `additionalLanguages`
- Language files live in `appPackage/` alongside the manifests
- Use language-only tags (e.g., `en` rather than `en-us`) for top-level translations; add region-specific overrides only when needed

#### Step A4: Deploy — MANDATORY

After completing ALL localization changes, deploy the agent:

```bash
wiqd agent provision --env local
```

Then read `M365_TITLE_ID` from `env/.env.local` and present the test link. **⛔ Never skip deployment after localization changes.**

---

### Workflow B: Add a Language to an Already-Localized Agent

Use this workflow when the agent is ALREADY localized (manifests use `[[tokens]]`, `localizationInfo` exists, language files exist) and the user wants to add another language.

**⛔ Do NOT re-tokenize manifests or recreate existing language files.** Only create the NEW language file and update `localizationInfo`.

#### Step B1: Read Existing Localization Setup

1. Read `manifest.json` — note the `localizationInfo` section (default language, existing additional languages)
2. Read the default language file (e.g., `en.json`) — note ALL keys in `localizationKeys` (these are the keys the new file must also have)
3. Read `declarativeAgent.json` — confirm it uses `[[token]]` syntax (if not, switch to Workflow A)

#### Step B2: Create the New Language File

Create `appPackage/{languageTag}.json` with:

1. `$schema` — same as existing language files
2. `name.short`, `name.full`, `description.short`, `description.full` — translated values from the user
3. `localizationKeys` — one entry per key from the default language file, with translated values from the user

**⛔ CRITICAL:** The new file MUST have the EXACT SAME set of `localizationKeys` as the default language file. Copy the key names from the existing default language file and fill in translated values.

#### Step B3: Update `localizationInfo` in `manifest.json`

Add the new language to the `additionalLanguages` array:

```json
{
  "languageTag": "pt-BR",
  "file": "pt-BR.json"
}
```

**⛔ Do NOT modify existing language files or the `defaultLanguageFile` entry.** Only add to `additionalLanguages`.

#### Step B4: Deploy — MANDATORY

Deploy the agent:

```bash
wiqd agent provision --env local
```

Then present the test link. **⛔ Never skip deployment.**

---

### Localizable Fields Reference

**Declarative agent manifest:**

| Field                           | Description                                 | Max length  | Required |
| ------------------------------- | ------------------------------------------- | ----------- | -------- |
| `name`                          | Display name of the agent                   | 100 chars   | ✔️       |
| `description`                   | Description shown to users                  | 1,000 chars | ✔️       |
| `conversation_starters[].title` | Short title for a conversation starter      | —           |          |
| `conversation_starters[].text`  | Full prompt text for a conversation starter | —           |          |
| `disclaimer.text`               | Disclaimer shown at conversation start      | —           |          |

**API plugin manifest:**

| Field                           | Description                            | Max length  | Required |
| ------------------------------- | -------------------------------------- | ----------- | -------- |
| `name_for_human`                | Short, human-readable plugin name      | 20 chars    | ✔️       |
| `description_for_human`         | Human-readable description             | 100 chars   | ✔️       |
| `description_for_model`         | Description provided to the model      | 2,048 chars |          |
| `conversation_starters[].title` | Title for plugin conversation starters | —           |          |
| `conversation_starters[].text`  | Text for plugin conversation starters  | —           |          |

#### Required App Manifest Keys in Every Language File

| Key                 | Description           | Max length  | Required    |
| ------------------- | --------------------- | ----------- | ----------- |
| `name.short`        | Short app name        | 30 chars    | ✔️          |
| `name.full`         | Full app name         | 100 chars   | Recommended |
| `description.short` | Short app description | 80 chars    | ✔️          |
| `description.full`  | Full app description  | 4,000 chars | ✔️          |

---

### Language Resolution Order

The Microsoft 365 host resolves strings in the following order:

1. Start with the **default language** strings
2. Overwrite with the user's **language-only** file (e.g., `en`)
3. Overwrite with the user's **language + region** file (e.g., `en-gb`), if available

For example, if the default language is `fr`, and you provide `en` and `en-gb` files, a user with locale `en-gb` sees: `fr` → overwritten by `en` → overwritten by `en-gb`.

> **Tip:** Provide top-level, language-only translations (e.g., `en` rather than `en-us`). Add region-specific overrides only for the few strings that need them.

---

### Project Structure

A localized app package includes the language files alongside the manifests:

```text
my-agent/
├── appPackage/
│   ├── manifest.json
│   ├── declarativeAgent.json
│   ├── instructions.txt            # externalized instructions (NOT tokenized)
│   ├── plugin.json                 # optional
│   ├── en.json                     # default language file
│   ├── fr.json                     # French language file
│   ├── es.json                     # Spanish language file
│   ├── color.png
│   └── outline.png
├── env/
│   └── .env.dev
└── m365agents.yml
```

---

### Critical Rules

1. **Every `[[token]]` must have a matching `[[TOKEN]]` key in `localizationKeys`** in every language file. Keys use `[[TOKEN]]` format (e.g., `"[[AGENT_NAME]]"`). Missing keys cause runtime failures.
2. **Keep token names descriptive** — use `STARTER_VPN_TITLE` not `key1`.
3. **Do NOT localize instructions** — externalize to `instructions.txt` via `$[file('instructions.txt')]`. Never use `[[tokens]]` for instructions.
4. **Schema URL** — `$schema` in language files must be `https://developer.microsoft.com/en-us/json-schemas/teams/v1.25/MicrosoftTeams.Localization.schema.json`.
5. **Always deploy after localization changes.**
6. **Do NOT invent translations** — ask the user for translated strings. Never machine-translate without confirmation.
7. **Tokenization is MANDATORY** — language files have no effect without `[[token]]` syntax in the manifests.
8. **`localizationKeys` key format** — keys MUST match pattern `^\[\[[a-zA-Z_][a-zA-Z0-9_]*\]\]$` per the v1.25 schema.

---

### ⛔ FINAL GATE — Before Responding to the User

**STOP.** Before writing your response, verify ALL of the following:

- [ ] `declarativeAgent.json` uses `[[token]]` syntax for ALL localizable fields (name, description, every conversation starter title/text, disclaimer)
- [ ] `instructions` field is NOT tokenized (never use `[[token]]` for instructions)
- [ ] A default language file exists (e.g., `en.json`) with `name.short`, `description.short`, `description.full` (required), `name.full` (recommended), and ALL `localizationKeys` using `[[TOKEN]]` format as keys
- [ ] Every additional language file has the EXACT SAME set of `localizationKeys` keys (in `[[TOKEN]]` format) as the default
- [ ] `manifest.json` has `localizationInfo` with `defaultLanguageTag`, `defaultLanguageFile`, and `additionalLanguages`
- [ ] I deployed with `wiqd agent provision --env local`
- [ ] I presented the test link

**If you cannot check ALL boxes, you are NOT done.** Go back and complete the missing steps.

---

### Error Handling

| Error                                                        | Action                                                                                                                   |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Token in manifest has no matching `localizationKeys` entry   | **Stop.** List the missing keys and the language files that need them. Ask the user to provide the translations.         |
| Language file referenced in `localizationInfo` doesn't exist | **Stop.** List the missing files. Ask the user to provide them or remove the language from `additionalLanguages`.        |
| `localizationInfo.defaultLanguageFile` is missing            | **Stop.** Inform the user that a default language file is required when `localizationInfo` is present.                   |
| Agent has only one language                                  | Inform the user that language files are not required for single-language agents. Ask if they want to add more languages. |

---

### Learn More

- [Localize your agent](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/localize-agents) — Official Microsoft localization guide for agents
- [Localize your app (Microsoft Teams)](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/build-and-test/apps-localization) — General Teams app localization reference
- [Localization schema reference](https://learn.microsoft.com/en-us/microsoftteams/platform/resources/schema/localization-schema) — JSON schema for localization files
