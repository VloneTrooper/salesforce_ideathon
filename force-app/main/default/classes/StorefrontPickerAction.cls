/**
 * StorefrontPickerAction
 *
 * CLT-enabled selector for disambiguating storefronts. When a merchant name matches more
 * than one location, the storefrontSelector editor LWC shows swipeable cards so the user
 * taps the right storefront instead of typing an Id. The chosen storefront is returned to
 * the agent for downstream actions.
 *
 * The StorefrontSelection inner class is the Apex data shape behind the
 * `storefrontSelection` custom Lightning type bundle. The editor LWC loads candidate
 * storefronts from StorefrontPickerController.getStorefronts().
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Select_Storefront
 *   - Lightning type bundle        : storefrontSelection  (referenced as c__storefrontSelection)
 *   - Apex data shape              : c__StorefrontPickerAction$StorefrontSelection
 *   - Editor LWC                   : c/storefrontSelector
 */
public with sharing class StorefrontPickerAction {

    @JsonAccess(serializable='always' deserializable='always')
    public class StorefrontSelection {
        @AuraEnabled @InvocableVariable public String storefrontId;
        @AuraEnabled @InvocableVariable public String name;
        @AuraEnabled @InvocableVariable public String cuisine;
        @AuraEnabled @InvocableVariable public String address;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public Decimal rating;
        @AuraEnabled @InvocableVariable public String imageUrl;
    }

    public class Request {
        @InvocableVariable(
            label='Selected Storefront'
            description='The storefront the user selected from the Storefront Selector cards.'
            required=true
        )
        public StorefrontSelection selectedStorefront;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when a storefront was selected.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Storefront Id' description='The selected Storefront Id, for downstream actions.')
        public String storefrontId;

        @InvocableVariable(label='Storefront Name' description='The selected storefront name.')
        public String storefrontName;
    }

    @InvocableMethod(
        label='Select Storefront'
        description='Lets the user pick the right storefront from a set of cards and returns the selected storefront.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        if (req == null || req.selectedStorefront == null || String.isBlank(req.selectedStorefront.storefrontId)) {
            out.message = 'No storefront was selected.';
            return new List<Response>{ out };
        }

        out.storefrontId = req.selectedStorefront.storefrontId;
        out.storefrontName = req.selectedStorefront.name;
        out.success = true;
        out.message = 'Selected storefront ' + req.selectedStorefront.name + '.';
        return new List<Response>{ out };
    }
}