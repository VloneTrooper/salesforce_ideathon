# Pronto Ideathon — Build Plan & Implementation Order

Oct 1, 2026 · @Valen

Everything is submitted by 11am on Oct 2, 2026; presentations run 1–3pm. Required prompts are built first, the two extras last.

## At a glance

&#91;embedded content: service flow · 2 intake paths, 1 dashboard\]

Agent failures and merchant reports each become Cases in their own queue, and both feed the dashboard. The dashed line is the bonus: the agent checks merchant reports before answering a customer. This is also your architecture slide.

## Build order

Required prompts come first, extras second, slides last. A and B are the two builders; split differently if you have more people. Times are tonight unless noted.

| # | Phase | Owner | Time box | Done when |
| --- | --- | --- | --- | --- |
| — | Submit one-pager and site URL .txt to Canvas | Anyone | Now | Both show as submitted |
| 0 | Data model and prerequisite checks | A | 8:45–9:15 | New picklist values and fields exist; Case is routable in Omni-Channel |
| 1 | Merchant & Courier channel | A | 9:15–11:00 | A test email becomes a Case in the Merchant Ops Queue, linked to the merchant account |
| 2 | Agent failure handling | B | 9:15–11:30 | A failure triggered in chat creates a Case and the support lead gets a notification |
| 3 | Report and dashboard | A | 11:00–12:30 | Dashboard with working filters and one written insight backed by the data |
| 4 | Photo evidence in chat | B | 11:30–12:15 | A photo sent in chat is visible to the support rep |
| 5 | Bonus: merchant-aware agent | A + B | 12:30–1:30 | Agent cites a merchant report in a live preview; skip if Phases 1–3 are not solid |
| 6 | Deliverables, slides, rehearsal | Everyone | Fri 8:00–10:45am | Everything submitted before 11am; demo run twice |

## Phase 0: Data model and prerequisites

Every later phase writes to these fields, so do this first. All paths start at Setup → Object Manager → Case → Fields & Relationships.

- [ ] **Check for a Storefront lookup on Case.** It decides whether reports and the bonus can group by storefront. If missing, create a Lookup to Storefront and note that older Cases will be blank.
- [ ] **Case Origin:** add values `Merchant Report` and `Agent`. Note the existing value used for chat Cases.
- [ ] **Case Type** (or Reason, whichever Pronto Cases use): add `Out of Stock`, `Prep Delay`, `Handoff Issue` next to the existing missing-item, late, and wrong-order values.
- [ ] **New picklist `Failure Type`** (`Failure_Type__c`): `Escalation Failed`, `Clarification Loop`, `Action Error`.
- [ ] **Omni-Channel for Cases:** Setup → Service Channels → New, Salesforce object = Case. Without this, Case queues cannot route.
- [ ] **Two new queues** (Setup → Queues), object Case, routing configuration = the existing `Customer Service Agent Routing Configuration`: `Merchant Ops Queue` and `Agent Escalations Queue`.
- [ ] **Pick the named support lead** (a real user in the org) and create a Custom Notification Type `Agent Failure Alert` (Setup → Custom Notifications, desktop and mobile on).
- [ ] **Look at the existing Pronto Cases** (a quick list view grouped by Type). Decide now whether you need sample data for Phase 3.

## Phase 1: Merchant & Courier channel

Restaurants and couriers email one ops address; each email becomes a Case tied to the right merchant and routed to Merchant Ops, not to customer service.

1. **Enable Email-to-Case.** Setup → Email-to-Case → enable Email-to-Case and On-Demand Service.
2. **Create the routing address.** Name `Merchant & Courier Ops`; Email Address = a team inbox you control; Case Owner = `Merchant Ops Queue`; Case Origin = `Merchant Report`. Save, then click the verification link Salesforce sends to that inbox.
3. **Note the long Email Services Address** Salesforce generates. For the demo, either forward the team inbox to it (Gmail forwarding) or email it directly.
4. **Create merchant contacts.** Under the Urban Eats Collective account, add a Contact such as "Store Manager, Urban Table Downtown" using a teammate's real email. Email-to-Case matches the sender to this Contact, which links the Case to the merchant account automatically.
5. **Link the storefront.** Add a Storefront lookup on Contact and fill it for each manager. A record-triggered flow on Case (create, Origin = Merchant Report) copies Contact → Storefront onto the Case.
6. **Set the issue type in the same flow.** Subject contains "out of" or "86" → `Out of Stock`; "late" or "delay" → `Prep Delay`; anything else → `Handoff Issue`.
7. **Test end to end.** Email "Out of fries tonight" from the manager's address. Confirm the Case shows the right Account, Contact, Storefront, Type, and owner, and that it routes from the queue through Omni-Channel.

**Pitch line:** customer chat reacts to problems; this channel hears about them first, from the people who cause or see them, with no new app for merchants.

## Phase 2: Agent failure handling

Three defined failures each create a Case, give the customer a case number, and notify the support lead. The clarification loop is the one to demo live, because it is the easiest to trigger on cue.

| Failure | Trigger | Priority |
| --- | --- | --- |
| Escalation Failed | Customer asks for a human and the handoff does not complete | High |
| Clarification Loop | Agent lands in Ambiguous Question twice in one conversation | Medium |
| Action Error | An action returns `success = False` (refund, store search) | High if a refund, else Medium |

1. **Build the flow `Log Agent Failure`** (autolaunched). Inputs: failure type, summary, contact ID (optional), priority. It creates a Case with Origin = `Agent`, Failure Type, Subject "Agent failure: {type}", owner = `Agent Escalations Queue`, and outputs the Case Number. Mark the input and output variables as available for input and output.
2. **Make it an agent action.** In Agentforce Builder, create an action with Reference Action Type = Flow pointing at `Log Agent Failure`. Add it under Actions Available For Reasoning in the Escalation, Ambiguous Question, and refund subagents.
3. **Escalation Failed.** Edit the Escalation subagent instructions: if the handoff fails, call Log Agent Failure with `Escalation Failed`, then give the customer the case number and say a person will follow up.
4. **Clarification Loop.** Add a mutable number variable (for example `clarify_count`, starting at 0). In Ambiguous Question, add 1 each time; at 2, call Log Agent Failure and offer a human. Copy the variable and condition syntax from Exercise 3's verification logic and the Agent Script Reference. If the syntax fights you, fall back to a plain instruction: "If this is the second unclear request, call Log Agent Failure."
5. **Action Error.** Add to each subagent that has actions: "If an action returns success False, call Log Agent Failure with Action Error and describe what you tried."
6. **Build the notification flow** (record-triggered, Case created, Origin = Agent). Send Custom Notification `Agent Failure Alert` to the support lead (title = failure type, body = case number and summary, target = the Case), plus a Send Email action to the same person.
7. **Test in Preview.** Send two vague messages in a row. Confirm the Case exists, the bell icon lights up for the lead, and the email arrives. Save, refresh the browser, and reset the preview between tests.

**Beyond the minimum:** defined criteria, priority by severity, the customer gets a case number instead of a dead end, and every failure feeds the dashboard.

## Phase 3: Report and dashboard

The dashboard is where the three goals meet: issues by storefront, merchant-reported against customer-reported, and agent failures by type.

1. **Get enough data.** If the existing Pronto Cases are thin, add sample Cases spread across storefronts, types, and origins. The Data Import Wizard does not import Cases; use an Anonymous Apex script in the Developer Console (Claude can write it once you share the field API names) or dataloader.io. Say openly in Q&A that this is seeded sample data.
2. **Build the report "Order Issues by Storefront and Source."** Report type Cases, matrix format: rows = Storefront, columns = Origin. Filter Type to the order-issue values. Add Type, Status, Owner, and Created Date as columns.
3. **Build a second report, "Agent Failures by Type"** (Origin = Agent, grouped by Failure Type).
4. **Build the dashboard "Pronto Service Health"** with four components:
   - Order issues by storefront, stacked by Origin. This shows the merchant-vs-customer gap.
   - Issue type mix.
   - Agent failures by type.
   - Open cases by queue.
5. **Add dashboard filters:** Origin, Storefront, and Created Date. Check that each filter actually changes every component.
6. **Write the insight** as one sentence of finding, then action, then goal. For example: "Storefront X has the most customer-reported missing items and zero merchant reports, so Merchant Ops should contact X first (Goals 1 and 2)." Use the real numbers from your data.
7. **Export.** Report: Export → Formatted Report (.xlsx). Dashboard: Lightning dashboards have no data export, so print the page to PDF or take a full screenshot.

## Phase 4: Photo evidence in chat

Customers attach a photo of the wrong or missing item in the chat window, so the rep can approve a refund without back-and-forth. Time box: 45 minutes. If it is not working by then, move it to a "next steps" slide.

1. **Find the attachment setting.** Check the Pronto Service Agent messaging channel (Setup → Messaging Settings) and the `Pronto_Service_Agent` Embedded Service Deployment for a file attachment or file upload option. Turn it on.
2. **Republish** the Embedded Service Deployment, then reload the Experience site.
3. **Prompt the customer.** In the order-issue or refund subagent instructions, add: "When a customer reports a missing or wrong item, invite them to attach a photo using the attachment icon."
4. **Test and find where the file lands.** Send a photo from the live site. Check the Messaging Session record and its transcript, and whether the file appears on the related Case.
5. **Verify the claim before you make it.** Find out whether the paperclip shows up while the AI agent is handling the chat, or only after a handoff to a human. Do not claim the AI reads the photo unless you have seen it do so. "The photo is on the record for the rep" is enough.

## Phase 5 (bonus): Merchant-aware agent

When a customer reports a missing item, the agent first checks whether the restaurant already reported the problem, and resolves it without asking for proof. This is the moment where both channels visibly work as one system. Start only if Phases 1–3 work.

1. **Check the prerequisite.** Merchant-report Cases must have the Storefront filled in (Phase 1, step 5).
2. **Build the flow `Check Merchant Reports`** (autolaunched).
   - Input: storefront name.
   - Get Records on Storefront where Name contains the input.
   - Get Records on Case where Storefront = that record, Origin = `Merchant Report`, not closed, created today.
   - Outputs: has report (true/false), report subject, case number.
3. **Make it an agent action** (Reference Action Type = Flow) and add it under Actions Available For Reasoning in the order-issue or refund subagent.
4. **Instruct the agent:** "When a customer reports a missing, wrong, or late item, first call Check Merchant Reports with the storefront name. If a report exists, tell the customer the restaurant already flagged the problem and move straight to resolution without asking for proof."
5. **Rehearse the demo sequence.** Merchant emails "Out of fries tonight" for Urban Table Downtown. Then a customer chats "my fries were missing from Urban Table Downtown." The agent should reference the merchant's report.

**Fallback if it is not working by 1:30am: merchant alert.** A record-triggered flow on Case create counts order-issue Cases for that storefront in the last 7 days. At 3 or more, it creates a "Merchant Review" task for Merchant Ops and sends a custom notification. Lower risk, and it still turns the dashboard insight into automatic action.

## Phase 6: Deliverables, demo, Q&A

Tell the demo as one story, "one bad night at Urban Table Downtown," so judges see a single system instead of three assignments.

**Submission checklist** (due 11am Friday)

- [ ] One-page business goals (due tonight)
- [ ] .txt file with the Experience site URL
- [ ] Report export (.xlsx)
- [ ] Dashboard export (PDF)
- [ ] Trailhead progress screenshot for each team member, with the profile visible top right
- [ ] Presentation slides (PDF or PPTX)

**10-minute running order**

| Min | Slide or demo | Shows |
| --- | --- | --- |
| 0–1 | The problem: a good vs. a bad service experience | Problem framing |
| 1–2 | Three goals | Goals the rest of the talk refers back to |
| 2–3 | How it fits together (the diagram) | Coherence with the baseline |
| 3–5 | Live: merchant emails "out of fries" → Case → Merchant Ops Queue | Prompt 2 |
| 5–6 | Live: customer chats about missing fries; the agent already knows | Bonus |
| 6–7:30 | Live: two vague messages → failure Case → the lead's bell lights up | Prompt 3 |
| 7:30–9 | Dashboard: apply a filter, read the insight, tie it to the goals | Prompt 1 |
| 9–10 | Design decisions, limits, next steps | Critical thinking |

**Q&A prep.** Each prompt has one owner who can explain it alone. Have answers ready for:

- Why email for merchants, and not a web form, Slack, or SMS?
- What are the limits? Sample data, keyword-based type classification, and the agent does not read photos.
- What would you build next? AI classification of merchant emails with Prompt Builder, and proactive customer credits.
- How did you use AI, and how did you check its output? Every flow and agent change was tested live in Preview and against the actual Case records.

## Risks and fallbacks

| Risk | Fallback |
| --- | --- |
| The kickoff slides list Workshop 1 Exercises 1–3 as required, not 1–2 | Check now; Exercise 3 adds the verification and refund pieces the failure handling and bonus build on |
| Email arrives slowly during the live demo | Send one test email just before presenting; keep a screenshot of the resulting Case |
| Builder changes do not take effect | Save, refresh the whole browser tab, reset the preview |
| Agent Script syntax for the counter variable fails | Use the instruction-only version of the clarification loop |
| Case has no Storefront lookup and the data is thin | Group reports by merchant Account instead; seed sample Cases |
| File attachments only work after a human handoff | Show it on the rep's side, or move it to the next-steps slide |
| Bonus not working by 1:30am | Ship the merchant alert flow instead |
| Something breaks at 12:55 Friday | Screenshots of every working step, in order, as a backup slide set |
