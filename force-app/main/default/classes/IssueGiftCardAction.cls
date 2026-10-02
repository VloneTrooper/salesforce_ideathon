/**
 * IssueGiftCardAction
 *
 * CLT-enabled agent action that issues a goodwill Gift_Certificate__c and returns a
 * rich, displayable GiftCardView. The GiftCardView inner class is the Apex data shape
 * referenced by the `giftCardView` custom Lightning type bundle, which renders the
 * giftCardRenderer LWC instead of the default text output.
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Issue_Gift_Card
 *   - Lightning type bundle        : giftCardView  (referenced as c__giftCardView)
 *   - Apex data shape              : c__IssueGiftCardAction$GiftCardView
 *   - Renderer LWC                 : c/giftCardRenderer
 */
public with sharing class IssueGiftCardAction {

    /**
     * Data shape for the gift card renderer. Fields are @AuraEnabled so the LWC can read
     * them off `@api value`, and the class is serializable so it survives the agent runtime.
     */
    @JsonAccess(serializable='always' deserializable='always')
    public class GiftCardView {
        @AuraEnabled @InvocableVariable public String giftNumber;
        @AuraEnabled @InvocableVariable public Decimal amount;
        @AuraEnabled @InvocableVariable public String giftType;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public String recipientName;
        @AuraEnabled @InvocableVariable public String issueDate;
        @AuraEnabled @InvocableVariable public String expirationDate;
        @AuraEnabled @InvocableVariable public String message;
    }

    public class Request {
        @InvocableVariable(
            label='Verified Customer Id'
            description='Contact Id for the verified customer who receives the gift certificate.'
            required=true
        )
        public String verifiedCustomerId;

        @InvocableVariable(
            label='Gift Value'
            description='Monetary value of the gift certificate.'
            required=true
        )
        public Decimal giftValue;

        @InvocableVariable(
            label='Gift Type'
            description='Gift_Certificate__c.Type__c picklist value (for example: Recovery, Promotion, Purchased). Defaults to Recovery.'
            required=false
        )
        public String giftType;

        @InvocableVariable(
            label='Notes'
            description='Optional context about why the gift certificate was issued.'
            required=false
        )
        public String notes;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when the gift certificate was created.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Gift Number' description='The created Gift_Certificate__c auto-number Name.')
        public String giftNumber;

        @InvocableVariable(label='Gift Card' description='Rich gift card to display to the user.')
        public GiftCardView giftCard;
    }

    @InvocableMethod(
        label='Issue Gift Card'
        description='Creates a goodwill gift certificate and returns a rich gift card voucher for display.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        try {
            if (req == null || String.isBlank(req.verifiedCustomerId)) {
                out.message = 'verifiedCustomerId is required.';
                return new List<Response>{ out };
            }
            if (req.giftValue == null || req.giftValue <= 0) {
                out.message = 'giftValue must be a positive amount.';
                return new List<Response>{ out };
            }

            Id custId = Id.valueOf(req.verifiedCustomerId.trim());
            String giftType = String.isBlank(req.giftType) ? 'Recovery' : req.giftType.trim();
            Datetime duplicateCutoff = System.now().addHours(-24);

            List<Gift_Certificate__c> existingGifts = [
                SELECT Id, Name, Value__c, Type__c, Status__c, Issue_Date__c, Expiration_Date__c,
                       Recipient__r.Name
                FROM Gift_Certificate__c
                WHERE Recipient__c = :custId
                AND Value__c = :req.giftValue
                AND Type__c = :giftType
                AND Status__c = 'Active'
                AND Source_Channel__c = 'Agentforce'
                AND CreatedDate >= :duplicateCutoff
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!existingGifts.isEmpty()) {
                populateResponse(out, existingGifts[0], req.notes, true);
                return new List<Response>{ out };
            }

            Date expiry = Date.today().addDays(90);

            Gift_Certificate__c gc = new Gift_Certificate__c();
            gc.Recipient__c = custId;
            gc.Value__c = req.giftValue;
            gc.Original_Value__c = req.giftValue;
            gc.Remaining_Value__c = req.giftValue;
            gc.Type__c = giftType;
            gc.Source_Channel__c = 'Agentforce';
            gc.Issue_Date__c = Date.today();
            gc.Issued_By__c = UserInfo.getUserId();
            gc.Expiration_Date__c = expiry;
            gc.Notes__c = req.notes;
            gc.Status__c = 'Active';
            insert gc;

            gc = [
                SELECT Id, Name, Value__c, Type__c, Status__c, Issue_Date__c, Expiration_Date__c,
                       Recipient__r.Name
                FROM Gift_Certificate__c
                WHERE Id = :gc.Id
                LIMIT 1
            ];

            populateResponse(out, gc, req.notes, false);
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }
        return new List<Response>{ out };
    }

    private static void populateResponse(
        Response out,
        Gift_Certificate__c gift,
        String notes,
        Boolean reusedExisting
    ) {
        GiftCardView view = new GiftCardView();
        view.giftNumber = gift.Name;
        view.amount = gift.Value__c;
        view.giftType = gift.Type__c;
        view.status = gift.Status__c;
        view.recipientName = gift.Recipient__r != null ? gift.Recipient__r.Name : 'Valued Customer';
        view.issueDate = gift.Issue_Date__c != null ? gift.Issue_Date__c.format() : null;
        view.expirationDate = gift.Expiration_Date__c != null ? gift.Expiration_Date__c.format() : null;
        view.message = String.isBlank(notes) ? 'A little something to make it right.' : notes;

        out.giftCard = view;
        out.giftNumber = gift.Name;
        out.success = true;
        String prefix = reusedExisting ? 'Reused recent' : 'Issued a';
        out.message = prefix + ' $' + gift.Value__c.setScale(2) + ' ' + gift.Type__c
            + ' gift card "' + gift.Name + '".';
    }
}