# Changelog

## [0.9.0] — 2026-07-29

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Check for prerequisite CLIs and offer a consent-gated install
- Notify you when a newer release is available, show what changed after an update, and browse version ranges with `wiqd changelog --from/--to`

### Fixes

- Seed extensions on first run, and repair them from the doctor, when a post-install step is blocked
- Install the evaluation and Work IQ extensions as first-class dependencies
- Scope the doctor's antivirus exclusion advice to the project instead of a whole drive
- Distinguish active from installed extensions in `wiqd ext list`, with clearer version reporting
- Report upstream and precondition failures with actionable diagnostics
- Describe the `wiqd agent add` command group properly in help output

## [0.8.0-rc.1] — 2026-07-22

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Scaffold declarative agent projects from built-in templates
- Add OpenAPI actions, skills, and authentication to an agent from the CLI
- Validate agent manifests offline and check publish readiness before you ship
- Provision an agent to a named environment and get its Copilot deep link
- Package, share, inspect, publish, and delete agents across their full lifecycle
- Initialize and run scored agent evaluations with concurrency and threshold controls
- Ask, list, and monitor deployed agents from the terminal with structured output
- Launch a local browser DevUI to build, debug, and evaluate agents on your machine
- Drive the full build, improve, preview, and publish lifecycle from one guided Copilot skill
- Create and edit agents safely with project checks and read-before-write safeguards
- Generate and analyze evaluation suites with approval gates that protect the quality bar
- Guide partners from a validated package through listing, certification, and go-live
- Sign in, sign out, and inspect authentication across active extensions
- Check for and install updates by version or channel, with dry-run support
- Read installed release notes by version in text, JSON, or Markdown
- Activate extensions and install Copilot, Claude, and editor integrations
- Submit and browse product feedback from the CLI, with optional context
- Emit versioned JSON success and error envelopes for scriptable use
- Generate shell tab completion for Bash, Zsh, PowerShell, and Fish
- Ship schemas and guides for extension manifests, OpenAPI, MCP, and OAuth
