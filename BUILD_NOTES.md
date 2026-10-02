# Pronto Ideathon — Build Notes

Running log of the build. Newest status at the top of each phase. If you are a Claude session
picking this up: read `CLAUDE.md`, then this file, then continue from **Next up**.

## Status board

| Phase | Status | Human step pending |
|---|---|---|
| 0 Data model | ✅ Deployed | — |
| 1 Merchant & Courier channel | ⏳ Not started | Verify routing address in Prontosupport2@gmail.com; set up Gmail forwarding; send test email |
| 2 Agent failure handling | ⏳ Not started | Valen activates new agent version; confirm bell + email |
| Ex. 3 Verification + refunds | ⏳ Not started | (part of agent activation) |
| 3 Report & dashboard | ⏳ Not started | Approve insight sentence; export .xlsx + PDF |
| 4 Photo evidence | ⏳ Not started | TBD |
| 5 Bonus merchant-aware agent | ⏳ Not started | Rehearse demo |

**Next up:** Phase 1 (Email-to-Case + routing flow).

## Key facts
- Org: `hackathon-org` (Developer Edition, org id 00Dfj00000fQ9T5EAK).
- Support lead: **Valen Cole** (username `v413nc@gmail.com`).
- Team inbox for merchants/couriers: **Prontosupport2@gmail.com**.
- Merchant account: **Urban Eats Collective** (`001fj00001pGnvjAAC`); demo storefront **Urban Table Downtown**.
- Agent runs as `agentforce_service_agent.wzhzea842vrr@example.com` (EinsteinServiceAgent User).
- Pronto Case conventions found in the org: **Type** = broad category (`Customer Order Issue`,
  `Merchant Operations`, …); **Reason** = specific issue (`Missing items`, `Order running late`,
  `Wrong items delivered`, …). So the new issue values went on **Reason**, and merchant reports
  use Type = `Merchant Operations`.
- Ethan Skinner's user has a Force.com Free license, which cannot see Cases — that is why Valen is
  the support lead.

---

## Phase 0 — Data model ✅

Deployed 2026-10-01 ~9:30pm.

| What | API name | Notes |
|---|---|---|
| Case Origin values | `Merchant Report`, `Agent` | Added to StandardValueSet CaseOrigin. `Agentforce` already existed (unused by data). |
| Case Reason values | `Out of Stock`, `Prep Delay`, `Handoff Issue` | Next to `Missing items`, `Order running late`, `Wrong items delivered`. |
| Case → Storefront lookup | `Case.Storefront__c` | Did not exist; older 9 Cases are blank. |
| Contact → Storefront lookup | `Contact.Storefront__c` | Ties a store manager to a storefront (Phase 1). |
| Failure Type picklist | `Case.Failure_Type__c` | `Escalation Failed`, `Clarification Loop`, `Action Error`. |
| Omni-Channel service channel for Case | `Case_Channel` | Lets Case queues route via Omni-Channel. |
| Queues (Case, Omni routing = `Customer_Service_Agent_Routing_Configuration`) | `Merchant_Ops_Queue`, `Agent_Escalations_Queue` | Valen is a member of both. |
| Custom notification type | `Agent_Failure_Alert` | Desktop + mobile. |
| Permission set | `Pronto_Ideathon_Access` | FLS on the 3 new fields. Assigned to Valen and the agent user. |

Existing data at start: 9 Cases total, none linked to a storefront → Phase 3 needs seeded sample data.
