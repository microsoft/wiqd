# Orientation & Getting Started

**Telemetry:** `--skill wiqd` on every `wiqd` command.

When the user asks "how do I get started?", "what's the lifecycle?", "what can wiqd do?", or expresses orientation intent:

1. Show the journey map and locate the user on it (use the journey map from the orchestrator's "Journey map" section).
2. Identify their starting point: map the scenario to a journey **phase** and the **intent** to act on. Then dispatch that intent through the orchestrator's **Workflows** routing table — it maps intents to whatever workflows the installed extensions contribute. Don't name or assume a specific workflow file or capability here; if no workflow matches the intent, say so and suggest the closest ones.

| Scenario                                        | Phase   | Intent to route                            |
| ----------------------------------------------- | ------- | ------------------------------------------ |
| "I want to build a new agent from scratch"      | Build   | create / scaffold a new agent project      |
| "I already have a .zip or app package"          | Build   | migrate an existing package into a project |
| "I have an agent project, want to keep editing" | Build   | edit the agent                             |
| "I want to improve and test my agent"           | Improve | validate, then generate / run evals        |
| "I want to preview with a small audience"       | Preview | package → provision → share                |

| "I'm ready to publish" | Publish | publish |
| "I want to add translations" | Build | localize |

3. **Install wiqd:** follow [Install & Update](install-update.md) for the target-specific CLI-only installer.
4. **Discover all commands:** `wiqd --help` or `wiqd agent --help`
5. **Explore extensions:** For extension inventory, activation, or capabilities, read `references/extensions.md`. Use `wiqd ext list` for an overview and `wiqd ext show <id>` for per-extension capabilities.

Key documentation:

- [Build Declarative Agents](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/build-declarative-agents)
- [Declarative Agent Manifest](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/declarative-agent-manifest)
- [M365 Agents Toolkit (ATK)](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/agents-toolkit-overview)
