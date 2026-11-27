---
name: feedback
description: >
  Submit product feedback (bugs, feature requests, improvements) about wiqd itself as GitHub
  issues, and list feedback the user has already filed. Classifies intent, captures sentiment,
  confirms before submitting, and reports the created issue number and URL.
trigger-summary: "submit feedback, report a bug, request a feature, suggest an improvement, list my feedback"
triggers: >
  submit feedback, send feedback, report a bug, file a bug, this is broken, request a feature,
  feature request, suggest an improvement, I wish wiqd could, give feedback about wiqd,
  list my feedback, show my feedback, what feedback have I filed
routing-label: "Feedback"
routing-intent: "Submitting or listing wiqd product feedback (bugs, feature requests, improvements)"
routing-order: 6
contract-version: 1
routing-requires: [feedback submit, feedback list]
---

# Feedback

Submit product feedback (bugs, feature requests, improvements) about **wiqd** as GitHub issues,
and list feedback you have already filed.

## When to Use

- User wants to report a bug, request a feature, or suggest an improvement to wiqd
- User says "submit feedback", "this is broken", "I wish wiqd could…"
- User asks to see the feedback they have already filed

This workflow is about feedback on **wiqd itself** — not about the user's own agent or code.

## Workflow

1. Classify the intent to one of six types:
   - **`bug`** — something broken or crashing
   - **`feature`** — a wish / new capability
   - **`improvement`** — enhance an existing capability
   - **`question`** — clarification / how-to (not a code issue)
   - **`docs`** — documentation gap or error
   - **`performance`** — slow / resource-heavy behavior
   - _(Security issues route through `SECURITY.md`, not `wiqd feedback`.)_
2. Determine sentiment: frustration → `negative`, praise → `positive`, neutral → omit
3. Summarize: extract a clear, actionable title (≤ 256 chars)
4. Compose the description: write `--description` from the user's ACTUAL, COMPLETE feedback —
   their problem statement, repro steps, and request, in their own words. **The title is only a
   one-line summary; the description is the substance of the issue.** A title alone is NOT
   sufficient — never submit with an empty or placeholder description. NEVER pass a bare
   placeholder like `**Problem**` (with nothing else after it) as the description; if the user's
   message doesn't contain enough detail to write a real description, ask a follow-up question
   before submitting.
5. Preview with `wiqd feedback submit --dry-run --json` using the composed fields.
   Show the user the resolved destination, disclosure warning, title, and full
   description/body, including any environment context. If `requiresHostSelection`
   is true, ask the user to select an explicit host/repository and preview again.
   Get explicit approval for that destination and complete report before submitting.
   Never assume a private destination or substitute the public repository.
6. Submit the same approved fields with `--yes` for non-interactive JSON execution:

```bash
wiqd feedback submit --type <type> --title "<title>" --description "<desc>" [--sentiment <positive|negative>] --yes --json --skill wiqd
```

   Example — a bug report with a real multi-line description (the title stays a short summary;
   the description carries the user's actual words):

```bash
wiqd feedback submit --type bug \
  --title "plugin provision fails on macOS when the project path has a space" \
  --description "**Problem**
wiqd plugin provision fails whenever the project directory path contains a
space; the command aborts before any resources are created.

**Steps to reproduce**
1. Create a project under \"~/My Projects/agent-demo\"
2. Run \`wiqd plugin provision --env dev\`

**Expected**
Provisioning completes successfully, the same as it does for paths without
spaces.

**Actual**
ATK exits immediately with \"error: unrecognized argument\" and no resources
are created." \
  --sentiment negative --yes --json --skill wiqd
```

7. Check the response before reporting success: if `data.descriptionEmpty` is `true`, the issue was
   filed with no user feedback body (the description was empty or a bare placeholder). Do NOT
   report success — go back to step 4, compose a real description from the user's words (asking a
   follow-up question if needed), and edit the issue body to add it. `wiqd feedback submit` also
   writes a `⚠ No user feedback in --description` warning to stderr on this path, in both human and
   `--json` mode.
8. Report the issue number and URL

After an uncertain submission result, retry the identical approved command so
the local journal can reconcile it. Do not change the report, delete state, or
call `gh issue create` separately: that can duplicate an already-created issue.
An unresolved recovery is not success and does not authorize another create.

## List the user's feedback

```bash
wiqd feedback list [--top <n>] [--status open|closed|all] --json --skill wiqd
```

The list output includes a **Triage** column (AI-applied `category:*/severity:*`) and an **Impl** column (linked implementation issue #) once the automated triage + dispatch workflows have processed the submission.

## Options

| Flag            | Description                                                                          |
| --------------- | ------------------------------------------------------------------------------------ |
| `--type`        | `bug`, `feature`, `improvement`, `question`, `docs`, `performance` (default: `improvement`) |
| `--title`       | Short summary ≤ 256 chars (required)                                                 |
| `--description` | Detailed description, Markdown supported                                             |
| `--sentiment`   | `positive` or `negative` — omit if neutral                                           |
| `--no-context`  | Skip auto-attached environment context                                               |
| `--dry-run`     | Preview payload without creating an issue                                            |
| `--yes`         | Submit the reviewed destination and report without a terminal prompt; required for live JSON/headless use |
| `--json`        | Emit machine-readable JSON output (default: human-readable table)                    |

**Exit codes:** 0 = success, 1 = validation/auth error, 2 = `gh` CLI missing or unsupported, 130 = cancelled.

## GitHub CLI (`gh`) prerequisite

Both `feedback submit` and `feedback list` shell out to the GitHub CLI (`gh`). The command
checks that `gh` is installed, on a supported version, and authenticated before doing any work.
If `gh` is missing or too old, wiqd attempts a best-effort, non-interactive install for the
current platform (winget/choco on Windows, Homebrew on macOS/Linux). Auto-install can be
disabled with `WIQD_GH_AUTO_INSTALL=false`. If `gh` still isn't available, the command exits
with code 2 and prints install guidance.

**If `gh` is unavailable:** preserve the formatted report and explain the blocker.
Do not silently redirect to a public issue page or bypass the configured
destination. For a user-requested manual submission, first establish the exact
destination and obtain approval of its disclosure boundary and complete report.
