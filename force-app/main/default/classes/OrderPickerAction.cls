/**
 * OrderPickerAction
 *
 * CLT-enabled "no typing" selector. Instead of asking the customer to type an order
 * number, the recentOrderPicker editor LWC shows the customer's last few orders as
 * selectable cards. The chosen order is returned to the agent so it can drive downstream
 * actions (order status, incident intake, refund).
 *
 * The OrderSelection inner class is the Apex data shape behind the `orderSelection`
 * custom Lightning type bundle. The editor LWC loads candidate orders from
 * OrderPickerController.getRecentOrders().
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Pick_Recent_Order
 *   - Lightning type bundle        : orderSelection  (referenced as c__orderSelection)
 *   - Apex data shape              : c__OrderPickerAction$OrderSelection
 *   - Editor LWC                   : c/recentOrderPicker
 */
public with sharing class OrderPickerAction {

    @JsonAccess(serializable='always' deserializable='always')
    public class OrderSelection {
        @AuraEnabled @InvocableVariable public String orderNumber;
        @AuraEnabled @InvocableVariable public String storefrontName;
        @AuraEnabled @InvocableVariable public Decimal total;
        @AuraEnabled @InvocableVariable public String placedDate;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public String itemSummary;
    }

    public class Request {
        @InvocableVariable(
            label='Selected Order'
            description='The order the customer selected from the Recent Order Picker.'
            required=true
        )
        public OrderSelection selectedOrder;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when an order was selected.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Order Number' description='The selected order number, for downstream actions.')
        public String orderNumber;

        @InvocableVariable(label='Selected Order' description='The full selected order details.')
        public OrderSelection selectedOrder;
    }

    @InvocableMethod(
        label='Pick Recent Order'
        description='Lets the customer pick one of their recent orders from a card list and returns the selected order.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        if (req == null || req.selectedOrder == null || String.isBlank(req.selectedOrder.orderNumber)) {
            out.message = 'No order was selected.';
            return new List<Response>{ out };
        }

        out.selectedOrder = req.selectedOrder;
        out.orderNumber = req.selectedOrder.orderNumber;
        out.success = true;
        out.message = 'Selected order ' + req.selectedOrder.orderNumber
            + (String.isBlank(req.selectedOrder.storefrontName) ? '' : ' from ' + req.selectedOrder.storefrontName) + '.';
        return new List<Response>{ out };
    }
}