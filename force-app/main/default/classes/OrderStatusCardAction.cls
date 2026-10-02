/**
 * OrderStatusCardAction
 *
 * Output-CLT Apex action that returns a typed OrderStatusView so the agent can render a
 * branded order-status card (instead of a plain-text status sentence). This is the reliable
 * "renderer" path for Service Agent + Enhanced Chat v2 (input/selector CLTs are not yet
 * dependable in that runtime; see the output-first CLT recommendations doc).
 *
 * NOTE ON DATA SOURCE: In Pronto, orders live in the external Heroku Orders API surfaced via
 * External Services / Named Credentials, not in a Salesforce Order object. To keep the card
 * working out of the box, lookupOrder() returns representative sample data keyed by order
 * number, plus a deterministic synthesized fallback for any other number so the demo never
 * dead-ends. Replace the body of lookupOrder() with a callout to the Pronto Orders API
 * (e.g., ProntoOrders.getOrderByNumber) to wire live data. The rest of the wiring is unchanged.
 *
 * Naming alignment (do not change without updating all layers):
 *   - GenAiFunction developerName : Get_Order_Status_Card
 *   - Lightning type bundle        : orderStatusView  (referenced as c__orderStatusView)
 *   - Apex data shape              : c__OrderStatusCardAction$OrderStatusView
 *   - Renderer LWC                 : c/orderStatusRenderer
 */
public with sharing class OrderStatusCardAction {

    @JsonAccess(serializable='always' deserializable='always')
    public class OrderStatusView {
        @AuraEnabled @InvocableVariable public String orderNumber;
        @AuraEnabled @InvocableVariable public String storefrontName;
        @AuraEnabled @InvocableVariable public String status;
        @AuraEnabled @InvocableVariable public String stage;
        @AuraEnabled @InvocableVariable public String placedDate;
        @AuraEnabled @InvocableVariable public String eta;
        @AuraEnabled @InvocableVariable public String itemSummary;
        @AuraEnabled @InvocableVariable public Integer itemCount;
        @AuraEnabled @InvocableVariable public Decimal total;
    }

    public class Request {
        @InvocableVariable(label='Order Number' description='The order number to look up.' required=true)
        public String orderNumber;

        @InvocableVariable(label='Contact Id' description='Optional verified Contact Id to scope the lookup.' required=false)
        public String contactId;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True when the order was found.')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-readable status message.')
        public String message;

        @InvocableVariable(label='Order Status' description='Rich order status card to display to the user.')
        public OrderStatusView orderStatus;
    }

    @InvocableMethod(
        label='Get Order Status Card'
        description='Looks up an order and returns a rich order status card for display.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        if (req == null || String.isBlank(req.orderNumber)) {
            out.message = 'orderNumber is required.';
            return new List<Response>{ out };
        }

        OrderStatusView view = lookupOrder(req.orderNumber.trim());
        out.orderStatus = view;
        out.success = true;
        out.message = 'Order ' + view.orderNumber + ' is ' + view.status + '.';
        return new List<Response>{ out };
    }

    /**
     * Replace this with a real callout to the Pronto Orders API. The contactId argument
     * (on Request) is the verified customer's Contact Id when available so you can scope
     * the lookup. Until then, this returns representative sample data.
     */
    private static OrderStatusView lookupOrder(String orderNumber) {
        Map<String, OrderStatusView> samples = new Map<String, OrderStatusView>();
        samples.put('10293', buildOrder('10293', 'Fusion Bites', 'Delivered late', 'delivered',
            Date.today(), 'Arrived 45 min late \u00b7 8:32 PM', '2x Bao Buns, 1x Pad Thai, 1x Thai Iced Tea', 4, 48.75));
        samples.put('10277', buildOrder('10277', 'Green Garden Cafe', 'Delivered', 'delivered',
            Date.today().addDays(-4), 'Delivered Sat 6:12 PM', '1x Buddha Bowl, 1x Kombucha', 2, 21.40));
        samples.put('10254', buildOrder('10254', 'Nonna\'s Kitchen', 'Preparing', 'preparing',
            Date.today(), 'Est. 8:20 PM today', '1x Lasagna, 1x Caprese, 2x Tiramisu', 4, 63.10));
        // Ideathon demo order: "one bad night at Urban Table Downtown" (fries missing).
        samples.put('10301', buildOrder('10301', 'Urban Table Downtown', 'Delivered', 'delivered',
            Date.today(), 'Delivered 7:48 PM', '2x Smash Burger, 2x Large Fries, 2x Lemonade', 6, 42.60));

        if (samples.containsKey(orderNumber)) {
            return samples.get(orderNumber);
        }

        return buildOrder(orderNumber, 'Pronto Kitchen', 'Out for delivery', 'out_for_delivery',
            Date.today(), 'Est. 30 min', '1x Chef\'s Special', 1, 18.50);
    }

    private static OrderStatusView buildOrder(
        String orderNum, String storefront, String status, String stage,
        Date placed, String eta, String items, Integer itemCount, Decimal total
    ) {
        OrderStatusView o = new OrderStatusView();
        o.orderNumber = orderNum;
        o.storefrontName = storefront;
        o.status = status;
        o.stage = stage;
        o.placedDate = placed != null ? placed.format() : null;
        o.eta = eta;
        o.itemSummary = items;
        o.itemCount = itemCount;
        o.total = total;
        return o;
    }
}