# Pronto Ideathon — instructions for Claude

This is a Salesforce DX project for the Pronto Ideathon (submission due 11am Oct 2, 2026).
The team is Valen Cole (support lead, org admin) and Ethan Skinner.

**Read `BUILD_NOTES.md` first.** It is the running log of what has been built, what is
deployed, what still needs a human, and how to demo each piece. Keep it updated as you work.
The plan being followed is `references/Pronto Ideathon — Build Plan & Implementation Order.md`.

## Working rules
- Org alias `hackathon-org` (default). Deploy with `sf project deploy start -d <path>`;
  check results with `--json`.
- The Pronto Service Agent is defined in Agent Script:
  `force-app/main/default/aiAuthoringBundles/Pronto_Service_Agent/Pronto_Service_Agent.agent`.
  Validate with `sf agent validate authoring-bundle -n Pronto_Service_Agent`, publish with
  `sf agent publish authoring-bundle -n Pronto_Service_Agent`. Publishing creates a new
  version; **Valen activates it** in Agentforce Builder — do not activate.
- Do not edit the agent in Agentforce Builder and locally at the same time; retrieve first.
- Commit to git (remote: github.com/VloneTrooper/salesforce_ideathon) before each deploy
  that changes the org, so changes can be rolled back.
- Never commit `.sf/` or `.sfdx/` (org auth).
