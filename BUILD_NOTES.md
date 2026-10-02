# Pronto Ideathon — Build Notes

Running log of the build. Newest status at the top of each phase. If you are a Claude session
picking this up: read `CLAUDE.md`, then this file, then continue from **Next up**.

## Status board

| Phase | Status | Human step pending |
|---|---|---|
| 0 Data model | ✅ Deployed | — |
| 1 Merchant & Courier channel | 🟡 Email channel built; ✅ **web form** built + tested | Email: verify routing address + Gmail forwarding. Form: open it in a browser once and submit |
| 2 Agent failure handling | 🟡 **v4 published (inactive)**, v3 active | Valen activates **v4** (fixes live issues from step 5/6 tests) |
| Ex. 3 Verification + refunds | 🟡 Built, tested in live preview (in v2) | Activate v2 |
| 3 Report & dashboard | 🟡 Built (4 reports + dashboard), sample data seeded | Check filters in the UI; approve insight sentence; export .xlsx + PDF |
| 4 Photo evidence | ❌ Dropped — org lacks the file-attachment permission (verified by Valen). Agent v3 no longer mentions photos. Put it on the "next steps" slide | — |
| 5 Bonus merchant-aware agent | 🟡 Built early, tested in live preview (in v2) | Rehearse email → chat sequence |

**Next up:** Ship. Demo brief (features, 10-min timeline, morning checklist, insight, Q&A, fallbacks): https://claude.ai/artifact/9brcErEtaZjYJt5uaagqtL . Test data from Oct 1–2 night deleted; open-work chart now groups by Origin. Optional add-ons listed in the brief.

## Key facts
- Org: `hackathon-org` (Developer Edition, org id 00Dfj00000fQ9T5EAK).
- Support lead: **Valen Cole** (username `v413nc@gmail.com`). Alerts land in Gmail spam — mark Not spam.
- Team users (all System Administrator + Service Cloud User + `Pronto_Ideathon_Access` + members of both queues):
  Valen Cole, **Ethan Skinner** (upgraded from Force.com Free on Oct 1), **Pronto Merchant Ops** (username
  `prontosupport2@pronto-ideathon.demo`, email Prontosupport2@gmail.com — the inbox owner; password-setup email sent there).
  Script: `scripts/apex/setup_team_users.apex`. All three also have `Agent_Presence_Status_Access` (Omni "Available").
  Pronto Merchant Ops default app = Service Console; Omni-Channel widget added to the Service Console utility bar.
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

---

## Phase 3 — Report & dashboard 🟡 built, awaiting human checks

**Dashboard:** Pronto Service Health —
https://orgfarm-db2402fd58-dev-ed.develop.lightning.force.com/lightning/r/Dashboard/01Zfj000008LgUHEA0/view
(folder "Pronto Ideathon Dashboards", runs as Valen). Reports are in folder "Pronto Ideathon".

| Component | Report | Shows |
|---|---|---|
| Order issues by storefront (stacked bar) | `Order_Issues_by_Storefront_and_Source` (matrix: rows Storefront, columns Origin; filter Reason = order-issue values) | Merchant-vs-customer reporting gap |
| Issue type mix (donut) | `Order_Issue_Type_Mix` (grouped by Reason) | Missing / late / wrong / cold / out of stock / prep delay / handoff |
| Agent failures by type (column) | `Agent_Failures_by_Type` (Origin = Agent, grouped by Failure Type) | Clarification Loop vs Action Error vs Escalation Failed |
| Open work by queue (bar) | `Open_Cases_by_Queue` (open, owner contains "Queue") | Merchant Ops Queue vs Agent Escalations Queue |

**Dashboard filters:** Origin (Pronto App / Web / Merchant Report / Agent), Storefront (8 storefronts in the
sample data), Created Date (Today / Last 7 days / This month). Every component is wired to all three filters.
Expected quirks: Storefront filter empties the agent-failure chart (agent failures rarely have a storefront);
Created Date makes little difference because all sample cases were created on Oct 1.

**Sample data:** `scripts/apex/seed_sample_cases.apex` — 58 storefront cases + 11 agent-failure cases, every one
tagged `[Sample data]` at the start of Description. Merchant reports were seeded **Closed** so they don't
trigger the live bonus demo; agent failures were inserted as Web then switched to Agent so they didn't fire
11 alert notifications. **The pattern (Urban Table Downtown under-reports) was designed into the seed data —
say so in Q&A: "seeded sample data, shaped to show what the dashboard surfaces."**
Delete all with: `delete [SELECT Id FROM Case WHERE Description LIKE '[Sample data]%'];`

**Numbers as of build (report API):**
- Order issues by storefront: Urban Table Downtown 11 customer-reported (6 missing items) vs **1** merchant
  report; Fusion Bites Oak Lawn 6 customer vs **5** merchant; Munch Central Trinity Groves 4 vs 5;
  The Savory Spot Bishop Arts 6 vs 0.
- Agent failures: Clarification Loop 6, Action Error 4 (incl. test Case 00001041), Escalation Failed 2.
- Open by queue: Agent Escalations 4, Merchant Ops 2.

**Draft insight (needs Valen's approval; numbers will shift once the live demo email + test cases change):**
> "Urban Table Downtown has the most customer-reported order issues (11, six of them missing items) but sent
> only one merchant report, while Fusion Bites Oak Lawn self-reported 5 of its 11 — so Merchant Ops should
> call Urban Table Downtown first and get them emailing stock-outs before customers notice (Goals 1 and 2)."

**Human steps:** open dashboard → try each filter → approve/edit insight → Report: Export → Formatted Report
(.xlsx) on "Order Issues by Storefront and Source" → Dashboard: print to PDF / full screenshot.

---

## Phase 4 — Photo evidence in chat ❌ dropped (no org permission) — next-steps slide; agent v3 asks for a description instead

- ✅ Agent v2 invites the customer to attach a photo with the paperclip when there's no merchant report, and is
  told never to claim it can see photos.
- ❌ Could not enable attachments via metadata: `isAttachmentUploadEnabled` is rejected on both
  `MessagingChannel` and `EmbeddedServiceConfig.embeddedServiceMessagingChannel` (API 67). Original files restored.
- **Human steps:** Setup → Messaging Settings → Pronto Service Agent channel, and Setup → Embedded Service
  Deployments → Pronto_Service_Agent: look for a file attachment / file upload option, turn it on, **Publish**
  the deployment, reload the Experience site
  (https://orgfarm-db2402fd58-dev-ed.develop.my.site.com/ESWProntoServiceAgent1790904441555), send a photo,
  then check the Messaging Session record / transcript and whether it shows on the Case.
- Verify whether the paperclip appears while the AI agent is chatting or only after a human handoff.
  If it only works after handoff, demo it on the rep side or move it to a "next steps" slide (plan fallback).

---

## Demo runbook (for the presentation and for a Claude walkthrough)

Story: **"One bad night at Urban Table Downtown."** Run it twice before presenting.

**Before you present (≈15 min before):**
1. Agent v2 is **Active** (Agentforce Builder).
2. Open `merchant-report-form/index.html`, choose **Urban Table Downtown**, message **"Out of fries tonight"**, send
   (or email Prontosupport2@gmail.com from a merchant contact address).
   Confirm a new Case in **Merchant Ops Queue** with Storefront = Urban Table Downtown, Reason = Out of Stock.
   (The bonus only fires if this case is **open** and **< 24h old**.) Screenshot it as a backup.
3. Valen logged in, bell icon visible, Omni-Channel set to Available.

**Live sequence:**
| Min | Do | Say |
|---|---|---|
| 3–5 | Show the Case from the email (Account, Contact, Storefront, Reason auto-filled, owner Merchant Ops Queue) | "The restaurant told us first — by email, no new app." |
| 5–6 | Chat on the site or Builder Preview: "my fries were missing" → `alex.morgan@example.com`, `Morgan` → order `10301` → "yes" | Agent: "Urban Table Downtown already reported being out of fries tonight" → $14.20 refund, REF number. "Both channels work as one system." |
| 6–7:30 | New preview: "hmm" → "I don't know, something is off" | Agent gives a case number; Valen's bell lights up; email arrives. "Failures become cases, not dead ends." |
| 7:30–9 | Dashboard → filter Storefront = Urban Table Downtown → read the insight | Tie to Goals 1–3. |

**Q&A facts:** verification = email + last name must both match a Contact; refund amount = order total ÷ items ×
affected items, customer must confirm; failure types and priorities per plan; keyword classification is
subject-only and case-insensitive; the agent does not read photos; sample data is seeded and tagged.

**If something breaks:** agent v1 is still there (re-activate it); flows can be deactivated in Setup → Flows;
everything is in git (github.com/VloneTrooper/salesforce_ideathon), one commit per phase.

### Cleanup before submission
- Delete the Gmail-forwarding confirmation Case (from forwarding-noreply@google.com) in Merchant Ops Queue.
- Keep the `[Sample data]` cases — the dashboard needs them.

---

## Open issue log

- **"Check Merchant Reports" flow error emails (8:28pm Oct 1)**: from flow version 1, before the switch to system
  mode — the agent user cannot read `Storefront__c`. Fixed in version 2 (system mode); later live tests passed.
  Ignore those emails.
- **Support-lead alert: ✅ confirmed.** Bell shows in Lightning when logged in as Valen Cole; emails arrive but land in
  **Gmail spam** (Salesforce sends them as a gmail.com / example.com address, which fails Gmail's sender checks).
  Mark them "Not spam" before the demo. Test Cases 00001041 / 00001116 deleted.

---

## Phase 1b — Merchant Report web form ✅ built + tested (added Oct 1, ~11:30pm)

Simpler demo path than email: **`merchant-report-form/index.html`** — open it by double-clicking (no server).
Merchant enters **their own email**, picks a **storefront**, types **what's happening** (quick-start chips for
out of stock / running late / courier). No merchant account or login needed.

How it works: the page POSTs to Salesforce **Web-to-Case** (`webto.salesforce.com`, org 00Dfj00000fQ9T5) with
Origin = `Merchant Report`, Subject = first line of the message, Description = full message, and
`Case.Reported_Storefront__c` (field id `00Nfj00005G2v9h`) = the chosen storefront.
- **Case assignment rule** "Standard" got a new first entry: Origin = Merchant Report → **Merchant Ops Queue**
  (Web-to-Case assigns the owner after flows run, so the flow alone couldn't route it).
- **Flow `Merchant_Report_Case_Enrichment`** now also: matches Reported Storefront by name and uses it (beats the
  Contact's storefront), and sets owner = Merchant Ops Queue (covers email too).
- If the email matches a Contact, Web-to-Case links Contact + Account; unknown emails still work (stored in
  `SuppliedEmail`, storefront still set from the dropdown).

Tested via the same POST with curl: known sender (Ethan) + "running late" + Fusion Bites Oak Lawn → Prep Delay,
Fusion Bites Oak Lawn, Contact Ethan Skinner, Account Urban Eats Collective ✅; unknown sender + "out of buns" +
Harvest Grill → Out of Stock, Harvest Grill, Merchant Ops Queue ✅. Test cases deleted.
Not yet clicked through in a real browser (the page uses `fetch(..., {mode: "no-cors"})`, so it can't read
Salesforce's reply and won't show a case number — it shows "Report sent").

**Demo:** pick **Urban Table Downtown**, type **"Out of fries tonight"**, send → Case appears in Merchant Ops Queue
within a few seconds → then run the customer chat (bonus fires because an open Merchant Report exists < 24h).

---

## Oct 2 (~12:30am) — live-test fixes, public sites, Pronto Ops app

**Live test results (Valen, references/step#5…, step#6…):** step 5 worked but after verification the live agent said
"I am processing your report…" instead of asking for the order number; step 6 never triggered the clarification-loop case
(router answered "hmm" itself). Step 7 report export + dashboard screenshot are in `references/`.

**Agent v4** (published, inactive — activate it): order_issue is now 3 explicit stages driven by variables —
STAGE 1 verify (`VerifiedCustomerId` empty), STAGE 2 ask for order number (`order_checked` False; set from
`Get_Order_Status` success), STAGE 3 resolve. Router told it must never answer or clarify itself and must always route vague
messages to ambiguous_question. Preview replay of both transcripts: ✅ "Thanks, Alex! You're verified. What's your order
number?" → refund; ✅ second vague message logs Clarification Loop case + offers a person.

**Human handoff:** "connect me to a person" escalates to `Customer_Service_Messaging_Queue` (messaging channel). It only
connects if a queue member is **Available** in Omni at that moment (Valen / Ethan / Pronto Merchant Ops in Pronto Ops or
Service Console). Nobody available → customer waits.

**Sites:** Customer Support (/customers) and Merchant Support (/merchants) switched from Preview to **Live** (welcome emails
turned off first) and **published** (`sf community publish`). Public access was already enabled. The `ESW…` URL is only the
chat's backing site — it is blank by design. **The customer chat lives on /customers.**
- /customers home: new link "Restaurant or courier partner? Report a problem tonight →" to /merchants.
- /merchants home: new link "Pronto customer? Get help with an order →" to /customers, and the **Merchant Report Form**
  component (LWC `merchantReportForm` + Apex `MerchantReportController`, without sharing; guest profile "Merchant Support
  Profile" granted class access). Same pipeline as the other channels: Origin Merchant Report, Reported Storefront, contact
  matched by email, default assignment rule → Merchant Ops Queue, auto-response email. Shows the case number on success.
  Tests: `MerchantReportControllerTest` 2/2 pass; end-to-end Apex call → Case 00001121 Handoff Issue / Munch Central /
  Merchant Ops Queue.
- The Merchant Support Agent (merchant chatbot) and its ESW site are untouched (that ESW site is still Preview).

**Merchant auto-reply rebranded:** template `Merchant_Report_Received` ("Pronto received your report: … (Ref 000…)") +
active Case auto-response rule "Pronto Merchant Reports" (Origin = Merchant Report), sender name **Pronto Merchant Ops**,
sender address v413nc@gmail.com (Salesforce forbids using the Email-to-Case routing address). Web-to-Case default response
template switched to the same template.

**Pronto Ops console app** (App Launcher → Pronto Ops; default app for the Pronto Merchant Ops user): Home = embedded
Pronto Service Health dashboard; tabs Cases, Storefronts, Refunds (new tab), Contacts, Accounts, Reports, Dashboards;
utility bar Omni-Channel + History. New Case list views **Merchant Reports** and **Agent Failures** (queue list views
"Merchant Ops Queue" / "Agent Escalations Queue" already existed). `profiles/Admin` and `profiles/Merchant Support Profile`
in the repo are **partial** profiles (only the app/tab/class settings) — deploying them adds those settings only.

**Cleanup:** delete Case 00001121 (TEST site form) after Valen sees the rebranded email.

### Oct 2 (~1:15am) — fixes from Valen's step C/E retest
- **Merchant form "Couldn't load storefronts":** guest users in this org are blocked even inside `without sharing` Apex unless
  they have object access *and* records are shared to them. Fixes: `Merchant Support Profile` (guest) got Read on
  Storefront__c / Contact, Create+Read on Case, FLS on Case.Origin, SuppliedEmail, Reported_Storefront__c; new guest sharing
  rule `Merchant_Site_Guests_Read_Storefronts` (Read, all storefronts). Contact matching moved out of Apex into the
  enrichment flow (Case.SuppliedEmail → exactly one Contact → ContactId/AccountId), so guests never read Contacts. The guest
  can't read the Case back, so the form now says "Report sent — reference number is in the confirmation email".
  Verified with a runAs(site guest user) probe test (deleted afterwards): 21 storefronts, submit → Merchant Operations /
  Out of Stock / Urban Table Downtown / Ethan Skinner / Urban Eats Collective / Merchant Ops Queue.
- **Escalation never reached a human:** MS-00000006 escalated correctly and waited in Customer_Service_Messaging_Queue,
  but Valen was at Omni capacity (default presence config = 5 units; two open Case works × 2 units; a chat needs 2).
  Valen, Ethan, Pronto Merchant Ops now use **Messaging_Presence_Configuration (capacity 20)**. Go Offline → Available to pick
  it up. Close Cases you're done with so they stop holding capacity.
- **No alert email for live failures:** cases from live chat are created by the agent user (noreply@example.com), which
  Gmail drops. `Agent_Failure_Alert_Notification` email now uses senderType **DefaultWorkflowUser**. Tested (Case 00001123).
- Cleanup later: Cases 00001121, 00001123 (tests).

### Oct 2 (~1:45am) — email deliverability, closing cases, chat reply
- **Emails:** Salesforce shows them Sent, but Gmail filters/drops them because they claim to be from a @gmail.com
  address (v413nc) while coming from Salesforce servers. No Salesforce-owned sender is possible here (the Email-to-Case
  service address is 118 chars; Salesforce email fields max 80). Mitigations: case number now leads every subject
  ("Case 000xxxx: Agent failure, …" / "Ref 000xxxx: Pronto received your report (…)") so Gmail doesn't thread new alerts into old
  spam conversations; Gmail filters (see below). **The bell notification is the reliable alert — demo that.**
- **Merchant site confirmations:** Salesforce skips auto-response rules for site guests, so new flow
  `Merchant_Site_Report_Confirmation` (after-save, Merchant Report created by a Guest with SuppliedEmail) emails the same
  confirmation (sender = default workflow user).
- **Closing cases:** Support setting `closeCaseThroughStatusChange` turned on → "Closed" now appears in Case Status.
- **Replying to an accepted chat:** the Messaging Session page needs the **Enhanced Conversation** component. Its metadata
  name isn't documented (6 guesses rejected), so it must be added in Lightning App Builder (see Valen's steps). After it's
  saved, retrieve it with `sf project retrieve start -m FlexiPage` to keep it in git.
- **Gmail filter (Valen and Ethan):** Gmail → search box → "Show search options" → From: `v413nc@gmail.com`, Has the words:
  `"Agent failure" OR "Pronto received your report"` → Create filter → ✅ Never send it to Spam → Create filter.

### Oct 2 (~2:15am) — bell only; chat reply works
- **Emails removed by decision (Valen): the bell is the alert.** `Agent_Failure_Alert_Notification` now only sends the bell
  notification (title "Case 000xxxx: Agent failure, <type> (<priority>)", click opens the Case). Auto-response rule
  "Pronto Merchant Reports" deactivated; `Merchant_Site_Report_Confirmation` flow set to Draft. Only the local HTML form
  (Web-to-Case) still triggers Salesforce's default Web-to-Case receipt.
- **Chat reply works:** Valen added the Enhanced Conversation component in Lightning App Builder; page retrieved into git as
  `flexipages/Messaging_Session_Record_Page` (org default for Messaging Session).
- **Closing:** merchant reports and agent-failure records are Cases → Status = Closed. Live chats are Messaging Sessions →
  end them with **End Chat** in the conversation window (no Status to set); the escalation case stays open until closed.
- Clarification Loop alerts: only 2 cases exist (00001122, 00001125), one per deliberate step-E test — not over-firing.
