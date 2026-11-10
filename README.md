# Agentforce Capstone

Salesforce DX project for an Agentforce capstone. It starts from Salesforce's Agentforce DX **agent** template, including a sample **Local Info Agent** you can preview, change, and replace with your capstone agent.

The sample agent shows weather, local events, and facility hours using:

- Invocable Apex, a prompt template, and a Flow
- Mutable variables
- `available when` action gating
- Deterministic `if/else` branching in reasoning

## Project layout

| Path | Purpose |
|---|---|
| `force-app/main/default/aiAuthoringBundles/` | Agent Script bundles (`.agent` + `.bundle-meta.xml`) |
| `force-app/main/default/classes/` | Invocable Apex used by agent actions |
| `force-app/main/default/flows/` | Autolaunched Flows used by agent actions |
| `force-app/main/default/genAiPromptTemplates/` | Prompt templates used by agent actions |
| `docs/AgentSpec.md` | Design spec for the capstone agent |

## Prerequisites

- A Salesforce Developer Edition org: [developer.salesforce.com/signup](https://developer.salesforce.com/signup)
- Salesforce CLI (`sf`)
- Cursor or VS Code with Salesforce extensions

Authorize an org:

```bash
sf org login web --alias agentforce-capstone --set-default --json
```

## Preview the sample agent

1. Open `force-app/main/default/aiAuthoringBundles/Local_Info_Agent/Local_Info_Agent.agent`.
2. Preview in simulated mode (Agentforce DX: **AFDX: Preview This Agent**), or use `sf agent`.
3. Ask something like `What's the weather like?`

Deploy Apex, Flow, and prompt templates before switching to live actions.

## Scratch org (optional)

`config/project-scratch-def.json` enables Agentforce features. After a Dev Hub is authorized:

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias AgentScratchOrg --set-default --target-dev-hub DevHub --json
```

## Next steps

1. Fill in `docs/AgentSpec.md` with the capstone agent's purpose, users, and actions.
2. Keep Local Info Agent as a reference, or replace it with your own authoring bundle.
3. Connect a target org when you are ready to validate, deploy, and preview.

## Docs

- [Agentforce DX Developer Guide](https://developer.salesforce.com/docs/einstein/genai/guide/agent-dx.html)
- [Agent Script](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
