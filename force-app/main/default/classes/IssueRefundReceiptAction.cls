/**
 * IssueRefundReceiptAction
 *
 * Apex wrapper around the refund write so it can power a custom Lightning type. Flows
 * cannot back a CLT directly, so this class creates an approved Refund__c (mirroring the
 * Apply_Remediation flow) and returns a typed RefundReceiptView that renders the
 * refundReceiptRenderer LWC.
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Issue_Refund_Receipt
 *   - Lightning type bundle        : refundReceiptView  (referenced as c__refundReceiptView)
 *   - Apex data shape              : c__IssueRefundReceiptAction$RefundReceiptView
 *   - Renderer LWC                 : c/refundReceiptRenderer
 */
public with sharing class IssueRefundReceiptAction {

    @JsonAccess(serializable='always' deserializable='always')
    public class RefundReceiptView {
        @AuraEnabled @InvocableVariable public String refundNumber;
        @AuraEnabled @InvocableVariable public Decimal amount;
        @AuraEnabled @InvocableVariable public String reason;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public String issueDate;
        @AuraEnabled @InvocableVariable public String caseNumber;
        @AuraEnabled @InvocableVariable public String storefrontName;
        // Hosted Apple Wallet .pkpass URL from the Pronto Pass Factory. Null when the
        // pass could not be minted; the renderer simply hides the wallet button then.
        @AuraEnabled @InvocableVariable public String walletUrl;
    }

    public class Request {
        @InvocableVariable(label='Refund Amount' description='Refund amount in dollars.' required=true)
        public Decimal refundAmount;

        @InvocableVariable(label='Refund Reason' description='Short explanation for the refund.' required=true)
        public String refundReason;

        @InvocableVariable(label='Case Id' description='Optional Case Id the refund applies to.' required=false)
        public String caseId;

        @InvocableVariable(label='Verified Contact Id' description='Optional verified Contact Id receiving the refund.' required=false)
        public String verifiedContactId;

        @InvocableVariable(label='Storefront Id' description='Optional Storefront Id linked to the refund.' required=false)
        public String storefrontId;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when the refund was created.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Refund Number' description='The created Refund__c auto-number.')
        public String refundNumber;

        @InvocableVariable(label='Receipt' description='Rich refund receipt to display to the user.')
        public RefundReceiptView receipt;
    }

    @InvocableMethod(
        label='Issue Refund Receipt'
        description='Creates an approved refund and returns a rich refund receipt for display.'
        callout=true
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        try {
            if (req == null || req.refundAmount == null || req.refundAmount <= 0) {
                out.message = 'refundAmount must be a positive amount.';
                return new List<Response>{ out };
            }
            if (String.isBlank(req.refundReason)) {
                out.message = 'refundReason is required.';
                return new List<Response>{ out };
            }

            // Mint the Apple Wallet pass BEFORE any DML (Apex callout-before-DML rule).
            // Best-effort: a null URL just means the card renders without a wallet button.
            String walletUrl = mintWalletPass(req);

            Refund__c r = new Refund__c();
            r.Amount__c = req.refundAmount;
            r.Reason__c = req.refundReason.trim();
            r.Status__c = 'Approved';
            r.Issue_Date__c = Date.today();
            if (String.isNotBlank(req.caseId)) {
                r.Case__c = Id.valueOf(req.caseId.trim());
            }
            if (String.isNotBlank(req.verifiedContactId)) {
                r.Contact__c = Id.valueOf(req.verifiedContactId.trim());
            }
            if (String.isNotBlank(req.storefrontId)) {
                r.Storefront__c = Id.valueOf(req.storefrontId.trim());
            }
            insert r;

            r = [
                SELECT Id, Name, Amount__c, Reason__c, Status__c, Issue_Date__c,
                       Case__r.CaseNumber, Storefront__r.Name
                FROM Refund__c
                WHERE Id = :r.Id
                LIMIT 1
            ];

            RefundReceiptView view = new RefundReceiptView();
            view.refundNumber = r.Name;
            view.amount = r.Amount__c;
            view.reason = r.Reason__c;
            view.status = r.Status__c;
            view.issueDate = r.Issue_Date__c != null ? r.Issue_Date__c.format() : null;
            view.caseNumber = r.Case__r != null ? r.Case__r.CaseNumber : null;
            view.storefrontName = r.Storefront__r != null ? r.Storefront__r.Name : null;
            view.walletUrl = walletUrl;

            out.receipt = view;
            out.refundNumber = r.Name;
            out.success = true;
            out.message = 'Issued a $' + r.Amount__c.setScale(2) + ' refund "' + r.Name + '".';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }
        return new List<Response>{ out };
    }

    /**
     * Builds the pass request and asks the Pronto Pass Factory for a hosted wallet URL.
     * Runs before the Refund__c insert so the callout precedes DML. Returns null on any
     * failure so the refund still completes.
     */
    private static String mintWalletPass(Request req) {
        String recipient = 'Valued Customer';
        if (String.isNotBlank(req.verifiedContactId)) {
            try {
                List<Contact> contacts = [
                    SELECT Name FROM Contact WHERE Id = :req.verifiedContactId.trim() LIMIT 1
                ];
                if (!contacts.isEmpty() && String.isNotBlank(contacts[0].Name)) {
                    recipient = contacts[0].Name;
                }
            } catch (Exception e) {
                // Fall back to the default recipient name.
            }
        }

        ProntoWalletPassService.PassRequest pass = new ProntoWalletPassService.PassRequest();
        pass.recipient = recipient;
        pass.amount = req.refundAmount;
        pass.message = req.refundReason;
        pass.type = 'REFUND';
        return ProntoWalletPassService.mintPassUrl(pass);
    }
}