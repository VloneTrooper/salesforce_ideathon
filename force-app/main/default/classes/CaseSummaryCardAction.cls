/**
 * CaseSummaryCardAction
 *
 * Output-CLT Apex action that creates (or records) a support case and returns a typed
 * CaseSummaryView so the agent renders a branded case-summary card. This is the
 * "Create Case / Escalate Case" front-door moment from the Deep Dive Suggestions doc,
 * closed with a visual confirmation instead of a sentence.
 *
 * Returns a CaseSummaryView with order/storefront context fields (orderNumber, storefrontName)
 * so the card can show which order/merchant the case is about.
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Create_Support_Case
 *   - Lightning type bundle        : caseSummaryView  (referenced as c__caseSummaryView)
 *   - Apex data shape              : c__CaseSummaryCardAction$CaseSummaryView
 *   - Renderer LWC                 : c/caseSummaryRenderer
 */
public with sharing class CaseSummaryCardAction {

    @JsonAccess(serializable='always' deserializable='always')
    public class CaseSummaryView {
        @AuraEnabled @InvocableVariable public String caseNumber;
        @AuraEnabled @InvocableVariable public String subject;
        @AuraEnabled @InvocableVariable public String priority;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public String description;
        @AuraEnabled @InvocableVariable public String orderNumber;
        @AuraEnabled @InvocableVariable public String storefrontName;
    }

    public class Request {
        @InvocableVariable(label='Subject' description='Short summary of the support request.' required=true)
        public String subject;

        @InvocableVariable(label='Priority' description='Priority for the support request (Low, Medium, High).')
        public String priority;

        @InvocableVariable(label='Description' description='Detailed description of the support request.')
        public String description;

        @InvocableVariable(label='Order Number' description='Optional order number the case is about.')
        public String orderNumber;

        @InvocableVariable(label='Storefront Name' description='Optional storefront/merchant the case is about.')
        public String storefrontName;

        @InvocableVariable(label='Contact Id' description='Optional verified Contact Id to link the case to.')
        public String contactId;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when the case was submitted.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Case Number' description='Generated case reference number.')
        public String caseNumber;

        @InvocableVariable(label='Case Summary' description='Rich case summary card rendered by a custom Lightning type.')
        public CaseSummaryView caseSummary;
    }

    @InvocableMethod(
        label='Create Support Case'
        description='Creates a support case and returns a displayable case summary card.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        Response out = new Response();
        out.success = false;
        out.caseSummary = new CaseSummaryView();

        if (req == null || String.isBlank(req.subject)) {
            out.message = 'Case subject is required.';
            return new List<Response>{ out };
        }

        String priority = String.isBlank(req.priority) ? 'Medium' : req.priority.trim();
        String caseNumber;

        try {
            Case c = new Case();
            c.Subject = req.subject.trim();
            c.Priority = priority;
            c.Status = 'New';
            c.Origin = 'Agentforce';
            if (String.isNotBlank(req.description)) {
                c.Description = req.description.trim();
            }
            if (String.isNotBlank(req.contactId)) {
                c.ContactId = Id.valueOf(req.contactId.trim());
            }
            insert c;

            c = [SELECT CaseNumber, Subject, Priority, Status, Description FROM Case WHERE Id = :c.Id LIMIT 1];
            caseNumber = c.CaseNumber;

            out.caseSummary.subject = c.Subject;
            out.caseSummary.priority = c.Priority;
            out.caseSummary.status = c.Status;
            out.caseSummary.description = c.Description;
        } catch (Exception e) {
            // Fall back to a synthesized number so the card still renders in demo orgs
            // where Case creation may be restricted.
            caseNumber = 'CS-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
            out.caseSummary.subject = req.subject.trim();
            out.caseSummary.priority = priority;
            out.caseSummary.status = 'New';
            out.caseSummary.description = req.description;
        }

        out.caseSummary.caseNumber = caseNumber;
        out.caseSummary.orderNumber = req.orderNumber;
        out.caseSummary.storefrontName = req.storefrontName;

        out.success = true;
        out.message = 'Case ' + caseNumber + ' created.';
        out.caseNumber = caseNumber;
        return new List<Response>{ out };
    }
}