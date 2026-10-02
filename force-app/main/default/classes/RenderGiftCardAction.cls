/**
 * Read-only CLT renderer for an already-issued Pronto gift certificate.
 *
 * Resolution Center owns the money-moving write. Customer Care can call this
 * action after a connected-agent handoff returns a gift number so the visible
 * chat session can render the same c__giftCardView card without issuing a
 * second credit.
 */
public with sharing class RenderGiftCardAction {
    public class Request {
        @InvocableVariable(label='Gift Number' description='Gift_Certificate__c auto-number to render.')
        public String giftNumber;

        @InvocableVariable(label='Verified Customer Id' description='Verified Contact Id used as a fallback scope.')
        public String verifiedCustomerId;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when a gift certificate was found.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable action status.')
        public String message;

        @InvocableVariable(label='Gift Number' description='Gift certificate number.')
        public String giftNumber;

        @InvocableVariable(label='Gift Card' description='Rich gift card to display to the user.')
        public IssueGiftCardAction.GiftCardView giftCard;
    }

    @InvocableMethod(
        label='Render Gift Card'
        description='Returns a displayable gift card voucher for an existing gift certificate.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        try {
            if (req == null || (String.isBlank(req.giftNumber) && String.isBlank(req.verifiedCustomerId))) {
                out.message = 'giftNumber or verifiedCustomerId is required.';
                return new List<Response>{ out };
            }

            Gift_Certificate__c gift = findGift(req);
            if (gift == null) {
                out.message = 'No matching active gift card was found.';
                return new List<Response>{ out };
            }

            out.giftCard = toView(gift);
            out.giftNumber = gift.Name;
            out.success = true;
            out.message = 'Rendered gift card "' + gift.Name + '".';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }
        return new List<Response>{ out };
    }

    private static Gift_Certificate__c findGift(Request req) {
        if (String.isNotBlank(req.giftNumber)) {
            List<Gift_Certificate__c> byNumber = [
                SELECT Id, Name, Value__c, Type__c, Status__c, Issue_Date__c, Expiration_Date__c,
                       Notes__c, Recipient__r.Name
                FROM Gift_Certificate__c
                WHERE Name = :req.giftNumber.trim()
                AND Status__c = 'Active'
                LIMIT 1
            ];
            if (!byNumber.isEmpty()) {
                return byNumber[0];
            }
        }

        Id contactId = Id.valueOf(req.verifiedCustomerId.trim());
        List<Gift_Certificate__c> recent = [
            SELECT Id, Name, Value__c, Type__c, Status__c, Issue_Date__c, Expiration_Date__c,
                   Notes__c, Recipient__r.Name
            FROM Gift_Certificate__c
            WHERE Recipient__c = :contactId
            AND Status__c = 'Active'
            AND Source_Channel__c = 'Agentforce'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return recent.isEmpty() ? null : recent[0];
    }

    private static IssueGiftCardAction.GiftCardView toView(Gift_Certificate__c gift) {
        IssueGiftCardAction.GiftCardView view = new IssueGiftCardAction.GiftCardView();
        view.giftNumber = gift.Name;
        view.amount = gift.Value__c;
        view.giftType = gift.Type__c;
        view.status = gift.Status__c;
        view.recipientName = gift.Recipient__r != null ? gift.Recipient__r.Name : 'Valued Customer';
        view.issueDate = gift.Issue_Date__c != null ? gift.Issue_Date__c.format() : null;
        view.expirationDate = gift.Expiration_Date__c != null ? gift.Expiration_Date__c.format() : null;
        view.message = String.isBlank(gift.Notes__c) ? 'A little something to make it right.' : gift.Notes__c;
        return view;
    }
}