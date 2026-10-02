# Pronto Ideathon — Build Notes

Running log of the build. Newest status at the top of each phase. If you are a Claude session
picking this up: read `CLAUDE.md`, then this file, then continue from **Next up**.

## Status board

| Phase | Status | Human step pending |
|---|---|---|
| 0 Data model | ✅ Deployed | — |
| 1 Merchant & Courier channel | 🟡 Built + flow tested | Verify routing address in Prontosupport2@gmail.com; set up Gmail forwarding; send test email (see Phase 1) |
| 2 Agent failure handling | 🟡 Built, tested in live preview, published as **v2 (inactive)** | Valen activates v2; confirm bell + email for Case 00001041 |
| Ex. 3 Verification + refunds | 🟡 Built, tested in live preview (in v2) | Activate v2 |
| 3 Report & dashboard | ⏳ Not started | Approve insight sentence; export .xlsx + PDF |
| 4 Photo evidence | ⏳ Not started | TBD |
| 5 Bonus merchant-aware agent | 🟡 Built early, tested in live preview (in v2) | Rehearse email → chat sequence |

**Next up:** Phase 4 (photo attachments) investigation, then Phase 3 (seed data, reports, dashboard).

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

---

## Exercise 3 + Phase 2 + Phase 5 — Pronto Service Agent v2 🟡 published, awaiting activation

All agent changes are in one Agent Script file:
`force-app/main/default/aiAuthoringBundles/Pronto_Service_Agent/Pronto_Service_Agent.agent`.
Published 2026-10-01 ~10:35pm as **BotVersion v2 (Inactive)**. v1 is still the active version.
**Valen activates v2** in Agentforce Builder (Pronto Service Agent → version dropdown → v2 → Activate).

### What changed in the agent
| Piece | How |
|---|---|
| **New subagent `order_issue`** (Exercise 3) | Router sends missing / wrong / late / cold items, refunds and order status here. |
| Verification | `Verify_Customer` → flow `Verify_Pronto_Customer` (email AND last name must match a Contact). Sets `VerifiedCustomerId` + `VerifiedFirstName`. Order lookup, merchant check and refund are **hidden** (`available when`) until verified. |
| Order lookup | `Get_Order_Status` → Apex `OrderStatusCardAction` (sample orders; added **10301 = Urban Table Downtown, 2x Smash Burger, 2x Large Fries, 2x Lemonade, $42.60**). |
| Refund | `Issue_Refund` → Apex `IssueRefundReceiptAction` (creates `Refund__c`, status Approved). Agent proposes amount = total ÷ items × affected items and waits for explicit yes. Wallet-pass callout fails harmlessly (no credential) — refund still succeeds. |
| **Bonus: merchant-aware** (Phase 5) | Before resolving, agent calls `Check_Merchant_Reports` → flow of same name (open Merchant Report case for that storefront in the last 24h). If found, it tells the customer the restaurant already flagged it and skips asking for proof. |
| Photo prompt (Phase 4 text) | If no merchant report, agent invites the customer to attach a photo with the paperclip; told never to claim it can see photos. |
| **Failure: Clarification Loop** | `clarify_count` (number) +1 in `before_reasoning` of `ambiguous_question`. At 2, `Log_Agent_Failure` becomes available with failureType fixed to "Clarification Loop"; output case number saved to `failure_case_number`; logged once per conversation (`clarify_failure_logged`). |
| **Failure: Escalation Failed** | `escalation` subagent: if `@utils.escalate` fails, call Log_Agent_Failure (High). Note: Preview can't really escalate, so this can't be demoed in Preview — demo the Clarification Loop instead. |
| **Failure: Action Error** | System + subagent instructions: any action returning success False / error → Log_Agent_Failure (High for refunds, else Medium). LLM-driven, not deterministic. |

### Flows (all deployed + Active)
| Flow | Type | Purpose |
|---|---|---|
| `Verify_Pronto_Customer` | Autolaunched, system mode | Email + last name → contactId, firstName, verified |
| `Log_Agent_Failure` | Autolaunched, system mode | Inputs failureType, summary, priority, contactId, storefrontName → Case (Origin Agent, Failure Type, Subject "Agent failure: {type}", owner Agent Escalations Queue). Outputs caseNumber, success. Ignores junk contact ids. |
| `Agent_Failure_Alert_Notification` | Record-triggered after-save, Case create, Origin = Agent | Bell notification `Agent_Failure_Alert` to the support lead (title = failure type + priority, body = case number + summary, click opens the Case) + email to the same person. Support lead = constant `supportLeadUsername` = `v413nc@gmail.com`. |
| `Check_Merchant_Reports` | Autolaunched, system mode | storefrontName → hasReport, reportSubject, reportReason, caseNumber, matchedStorefront |

The 3 agent-called flows run in **system mode** because the agent's service user could not run
them in user mode ("An error occurred when executing a flow interview"). The permission set
`Pronto_Ideathon_Access` also grants the agent user access to those flows and the 3 Apex classes.

### Tested (live-action preview of the local script, before publishing)
- Fries story: "my fries were missing" → asks email + last name → verified → order 10301 →
  "Urban Table Downtown already reported being out of fries tonight" → proposes $14.20 → "yes" →
  refund REF-000x issued. ✅
- Clarification loop: "hmm" → clarifying question; "I don't know, something is off" → logs
  Clarification Loop case, gives case number, offers live agent. ✅
- Flows tested directly in Apex: wrong last name rejected; bad contact id handled; Fusion Bites has no report. ✅
- Test records were deleted afterwards, except **Case 00001041** (Action Error, TEST) kept so Valen
  can confirm the bell + email arrived. Delete it after.

### How to re-run the preview from the CLI (any Claude session)
```bash
S=$(sf agent preview start --authoring-bundle Pronto_Service_Agent --use-live-actions --json | jq -r .result.sessionId)
sf agent preview send --authoring-bundle Pronto_Service_Agent --session-id $S -u "my fries were missing"
sf agent preview end --authoring-bundle Pronto_Service_Agent --session-id $S
```
Traces land in `.sfdx/agents/Pronto_Service_Agent/sessions/<id>/traces/` (shows every action input/output and errors).

### Human steps
1. **Activate v2** (Valen).
2. Confirm the bell icon + email for Case 00001041 reached Valen.
3. In Agentforce Builder Preview: send two vague messages ("hmm", "something is off") → case number
   in chat → bell lights up. Reset preview between tests.
4. Demo prep: the bonus only fires if a Merchant Report case for Urban Table Downtown was created
   in the last 24h — send the "Out of fries tonight" email shortly before presenting.
