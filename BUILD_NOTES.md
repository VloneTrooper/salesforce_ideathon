# Pronto Ideathon — Build Notes

Running log of the build. Newest status at the top of each phase. If you are a Claude session
picking this up: read `CLAUDE.md`, then this file, then continue from **Next up**.

## Status board

| Phase | Status | Human step pending |
|---|---|---|
| 0 Data model | ✅ Deployed | — |
| 1 Merchant & Courier channel | 🟡 Built + flow tested | Verify routing address in Prontosupport2@gmail.com; set up Gmail forwarding; send test email (see Phase 1) |
| 2 Agent failure handling | ⏳ Not started | Valen activates new agent version; confirm bell + email |
| Ex. 3 Verification + refunds | ⏳ Not started | (part of agent activation) |
| 3 Report & dashboard | ⏳ Not started | Approve insight sentence; export .xlsx + PDF |
| 4 Photo evidence | ⏳ Not started | TBD |
| 5 Bonus merchant-aware agent | ⏳ Not started | Rehearse demo |

**Next up:** Exercise 3 + Phase 2 (agent verification, order issues, failure logging).

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

Gotcha: the admin profile has no field-level access to most `Storefront__c` / `Refund__c` custom
fields (SOQL as Valen says "No such column"). The fields exist; the agent's Apex runs in system
mode so the agent is unaffected. Only matters if you build reports on those objects' fields.

---

## Phase 1 — Merchant & Courier channel 🟡 built, awaiting human verification

**How it works:** merchant/courier emails Prontosupport2@gmail.com → Gmail forwards to the
Salesforce Email-to-Case address → Case created with Origin = `Merchant Report`, owner =
`Merchant Ops Queue`. Email-to-Case matches the sender's email to a Contact, which sets Contact +
Account automatically. Flow `Merchant_Report_Case_Enrichment` (before-save, Case create, Origin =
Merchant Report) then copies Contact.Storefront → Case.Storefront, sets Type = `Merchant Operations`,
and Reason by subject keyword.

| Built | Detail |
|---|---|
| Email-to-Case + On-Demand | Enabled via `settings/Case.settings-meta.xml` |
| Routing address "Merchant & Courier Ops" | prontosupport2@gmail.com → Origin Merchant Report, owner Merchant_Ops_Queue, priority Medium |
| **Salesforce forwarding address** | `prontosupport2@p-26570hgw9ax5bi67rtqxw83i97kfo5clk3qh1xxi0n9o7xy4ma.fj-fq9t5eak.usa1044.case.salesforce.com` |
| Store manager contact | **Ethan Skinner**, "Store Manager, Urban Table Downtown", ethanskinner216@gmail.com, Account Urban Eats Collective, Storefront Urban Table Downtown (`003fj00001nEeCAAA0`) |
| Flow | `Merchant_Report_Case_Enrichment` — keyword rules: "out of"/"86" → Out of Stock; "late"/"delay" → Prep Delay; else Handoff Issue (case-insensitive, subject only) |
| Omni-Channel | `Available` presence status now includes `Case_Channel` (plus messaging) |

**Tested (Apex, rolled back):** "Out of fries tonight" from Ethan → Merchant Operations / Out of Stock /
Urban Table Downtown / Urban Eats Collective ✅; "Kitchen running LATE" → Prep Delay ✅; unknown sender →
Handoff Issue, no storefront ✅.

**Human steps (Valen / Ethan):**
1. In Prontosupport2@gmail.com, open the Salesforce "verify routing address" email and click the link.
2. Gmail → Settings → Forwarding and POP/IMAP → Add a forwarding address → paste the Salesforce
   forwarding address above. Gmail sends a confirmation code **to Salesforce**, so it becomes a Case
   in Merchant Ops Queue — open that Case, copy the code from its description into Gmail, then
   choose "Forward a copy of incoming mail to…" and save. (Delete that Case afterwards.)
3. From ethanskinner216@gmail.com, email Prontosupport2@gmail.com with subject "Out of fries tonight".
4. Check: Case appears in Merchant Ops Queue with Contact Ethan Skinner, Account Urban Eats
   Collective, Storefront Urban Table Downtown, Type Merchant Operations, Reason Out of Stock.
5. Omni-Channel: in the Service Console, open the Omni-Channel utility, go Available — the Case
   should be offered. If Omni says no presence configuration, assign Valen to
   "Messaging Presence Configuration" (Setup → Presence Configurations).

Pitch line: customer chat reacts to problems; this channel hears about them first, from the people
who cause or see them, with no new app for merchants.
