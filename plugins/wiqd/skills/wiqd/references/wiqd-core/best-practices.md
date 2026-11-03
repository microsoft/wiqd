# M365 Agent Developer Best Practices

Follow these best practices for successful M365 Copilot agent development.

## Security

- **Principle of Least Privilege:** Always scope capabilities to the minimum necessary resources
- **Credential Management:** Use secure credential storage for production environments
- **Input Validation:** Validate all user inputs and API responses
- **PII Handling:** Follow data protection regulations when handling personal information
- **Audit Logging:** Implement comprehensive audit trails for all agent actions
- **Secret Storage:** Never hardcode credentials; use Azure Key Vault or environment variables

## Performance

- **Scoped Queries:** Use scoped capabilities to reduce query time and improve response quality
- **Efficient API Design:** Design API plugins with pagination and filtering
- **Caching Strategy:** Implement appropriate caching for frequently accessed data
- **Response Time:** Keep operations under 30 seconds to avoid timeouts
- **Batch Operations:** Use batch APIs when processing multiple items

## Error Handling

- **Graceful Degradation:** Handle errors without breaking the conversation flow
- **Clear Error Messages:** Provide actionable error messages to users
- **Retry Logic:** Implement retry mechanisms for transient failures
- **Fallback Behavior:** Define fallback behavior when capabilities are unavailable
- **Error Logging:** Log errors with sufficient context for troubleshooting

## Testing

- **Test All Conversation Starters:** Verify each starter works as intended
- **Test Edge Cases:** Test with missing data, invalid inputs, and error conditions
- **Security Testing:** Verify scoping and permission controls
- **Cross-Environment Testing:** Test in dev, staging, and production environments
- **User Acceptance Testing:** Conduct UAT with actual users before production release

## Compliance

- **Data Residency:** Consider data residency requirements for multi-region deployments
- **Retention Policies:** Follow organizational data retention policies
- **Access Controls:** Implement role-based access controls (RBAC)
- **Compliance Frameworks:** Follow relevant frameworks (GDPR, HIPAA, SOC 2, etc.)
- **Documentation:** Maintain compliance documentation and audit trails

## Maintainability

- **Documentation:** Add `@doc` decorators to all operations, models, and properties
- **Naming Conventions:** Use PascalCase for models/enums, camelCase for properties/actions
- **Code Organization:** Separate concerns (capabilities, API plugins, models)
- **Version Control:** Use semantic versioning for shared agents
- **Change Management:** Document changes and maintain changelog

## Conversation Design

- **Specific Instructions:** Write directive instructions with clear role definition
- **Actionable Starters:** Create 3-5 specific, actionable conversation starters
- **Clear Boundaries:** Define what the agent can and cannot do
- **Appropriate Tone:** Match tone to audience and context
- **Confirmation Patterns:** Require confirmation for destructive or sensitive actions

**Reference:** [conversation-design.md](conversation-design.md)

## Deployment

- **Environment Strategy:** Use separate environments for dev, staging, and production
- **CI/CD Integration:** Automate testing and deployment using wiqd CLI
- **Version Management:** Bump versions before re-provisioning shared agents
- **Rollback Plan:** Have a rollback strategy for failed deployments
- **Monitoring:** Implement monitoring and alerting for production agents

**Reference:** [deployment.md](deployment.md)

## Agent Skills

- **Enable the Flag First:** Turn on WIQD's `agent-skills` feature flag before `wiqd agent add skill` and keep it enabled for `wiqd agent package` — core sets the SDK environment during those operations, and the flag gates packaging too
- **Scope Skills Narrowly:** Each `SKILL.md` should cover one focused, reusable procedure, not a catch-all
- **Name for Triggering:** Write `description` around the phrases a user would actually say, not a summary of the skill's purpose
- **Keep Name and Folder in Lockstep:** The frontmatter `name` and the containing folder name are one value — rename both together
- **Add `expose_skill_to_copilot`, Don't Hand-Author `agent_skills[]`:** `wiqd agent add skill` writes the DA `agent_skills[]` entry with `folder` only; add `expose_skill_to_copilot: true` to that entry when you want the DA skill exposed to Copilot directly. It does not write the root Cowork `agentSkills[]` registration; use `wiqd plugin add skill` for that independent surface
- **Validate source, then the final ZIP:** Before `wiqd agent package`, run `wiqd agent validate --mode source` with the same project/environment. After packaging, use `--mode package --package-file "<zip>"`; Marketplace readiness uses `--mode marketplace`, including package checks. Source does not check skill contents or prove ZIP acceptance. `wiqd plugin validate --mode deep` retains its separate plugin-project contract.

**Reference:** [agent-skills.md](agent-skills.md)
