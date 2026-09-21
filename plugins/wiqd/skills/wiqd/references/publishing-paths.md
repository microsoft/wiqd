# Publishing Path

How to take a declarative agent from idea to production.

## Lifecycle Phases

| Phase | What Happens | wiqd Tooling |
|-------|-------------|-------------|
| **Build** | Create agent, add capabilities, instructions, plugins | atk workflow ("create agent", "add a capability") |
| **Validate** | Run manifest validation, fix errors | atk workflow ("validate my agent") |
| **Improve** | Run evals, iterate on quality | eval workflow ("run my evals", "evaluate my agent") |
| **Package** | Build the app package (.zip) | atk workflow ("package my agent") |
| **Provision** | Create Entra app + Teams app, sideload for testing | atk workflow ("provision my agent") |
| **Preview** | Share with early users for testing | atk workflow ("share my agent") |
| **Publish** | Submit to Partner Center and publish to store | atk workflow ("publish my agent") |

## Key Details

- **Partner Center owns certification and store listing.** wiqd helps build through publish — Partner Center handles the rest.
- **atk provision handles sideloading.** Use "provision my agent" to deploy to a test environment for previewing.
- **Apps go live globally after certification.** Once certified, the agent is available in the store.

## What's Possible

| | |
|---|---|
| **Audience** | External customers, ISV partners, or your organization |
| **Published via** | Partner Center → Teams/M365 store |
| **Certification** | Partner Center certification process |
| **wiqd scope** | Full lifecycle: build through publish. Partner Center owns certification and store listing. |

## Prerequisites Before Publishing

1. Agent provisioned and tested ("provision my agent", "share my agent")
2. Partner Center developer account
3. App manifest validates clean ("validate my agent")
4. Icons meet size/format requirements (color icon 192×192, outline icon 32×32)
5. Privacy policy URL and Terms of Use URL
