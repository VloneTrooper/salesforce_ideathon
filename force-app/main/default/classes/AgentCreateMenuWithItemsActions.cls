/**
 * AgentCreateMenuWithItemsActions
 *
 * Creates a new Menu__c record and inserts one or more Menu_Item__c records
 * in a single transaction. Requires accountId for security validation.
 *
 * Items are passed as a JSON array string. Each object in the array should have:
 *   name (required), description, price, calories, available, imageUrl, category
 *
 * When a "category" is provided on an item, the action looks up an existing
 * Menu_Category__c by name. If none exists, it creates one automatically.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentCreateMenuWithItemsActions {

    public class MenuItemInput {
        public String name;
        public String description;
        public Decimal price;
        public Decimal calories;
        public Boolean available;
        public String imageUrl;
        public String category;
    }

    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to create the menu for.'
            required=true
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Menu Name'
            description='The name for the new menu (Menu__c.Name). Required.'
            required=true
        )
        public String menuName;

        @InvocableVariable(
            label='Menu Display Name'
            description='Customer-facing display name (Menu__c.Menu_Display_Name__c). Defaults to menuName if not provided.'
            required=false
        )
        public String menuDisplayName;

        @InvocableVariable(
            label='Active'
            description='Whether the menu should be active immediately. Defaults to true.'
            required=false
        )
        public Boolean active;

        @InvocableVariable(
            label='Items JSON'
            description='JSON array of menu items. Each object: { "name": "Item Name", "description": "...", "price": 12.99, "calories": 450, "available": true, "imageUrl": "...", "category": "Appetizers" }. Only name is required per item. If category is provided, the action will match or create a Menu_Category__c record automatically.'
            required=false
        )
        public String itemsJson;
    }

    public class CreatedItemSummary {
        @InvocableVariable(label='Menu Item Id' description='The created Menu_Item__c record Id.')
        public Id id;

        @InvocableVariable(label='Name' description='The menu item name.')
        public String name;

        @InvocableVariable(label='Price' description='The item price.')
        public Decimal price;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the menu and items were created successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Menu'
            description='The created Menu__c record. Display this as a clickable record link.'
        )
        public Menu__c menu;

        @InvocableVariable(
            label='Item Count'
            description='Number of menu items created.'
        )
        public Integer itemCount;

        @InvocableVariable(
            label='Created Items'
            description='Summary list of created menu items.'
        )
        public List<CreatedItemSummary> createdItems;

        @InvocableVariable(
            label='Created Items JSON'
            description='JSON-serialized version of createdItems for clients that prefer JSON parsing.'
        )
        public String createdItemsJson;
    }

    @InvocableMethod(
        label='Create Menu With Items'
        description='Creates a new menu on a storefront and inserts multiple menu items in one transaction. Items are passed as a JSON array string. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;
        out.message = null;
        out.createdItems = new List<CreatedItemSummary>();
        out.itemCount = 0;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                out.createdItemsJson = '[]';
                return new List<Response>{ out };
            }
            if (req.storefrontId == null) {
                out.message = 'storefrontId is required.';
                out.createdItemsJson = '[]';
                return new List<Response>{ out };
            }
            if (String.isBlank(req.menuName)) {
                out.message = 'menuName is required.';
                out.createdItemsJson = '[]';
                return new List<Response>{ out };
            }

            List<Storefront__c> storefronts = [
                SELECT Id, Account__c
                FROM Storefront__c
                WHERE Id = :req.storefrontId
                LIMIT 1
            ];

            if (storefronts.isEmpty()) {
                out.message = 'No storefront found with the provided Id.';
                out.createdItemsJson = '[]';
                return new List<Response>{ out };
            }

            if (storefronts[0].Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                out.createdItemsJson = '[]';
                return new List<Response>{ out };
            }

            Menu__c menu = new Menu__c();
            menu.Menu_Display_Name__c = String.isNotBlank(req.menuDisplayName) ? req.menuDisplayName : req.menuName;
            menu.Active__c = req.active != null ? req.active : true;
            menu.Storefront__c = req.storefrontId;

            insert menu;

            List<MenuItemInput> itemInputs = parseItems(req.itemsJson);

            if (!itemInputs.isEmpty()) {
                Map<String, Id> categoryMap = resolveCategories(itemInputs);

                List<Menu_Item__c> itemRecords = new List<Menu_Item__c>();
                for (MenuItemInput mi : itemInputs) {
                    if (String.isBlank(mi.name)) continue;

                    Menu_Item__c item = new Menu_Item__c();
                    item.Name = mi.name;
                    item.Description__c = mi.description;
                    item.Price__c = mi.price;
                    item.Calories__c = mi.calories;
                    item.Available__c = mi.available != null ? mi.available : true;
                    item.Image_URL__c = mi.imageUrl;
                    item.Menu__c = menu.Id;
                    if (String.isNotBlank(mi.category)) {
                        item.Menu_Category__c = categoryMap.get(mi.category.trim().toLowerCase());
                    }
                    itemRecords.add(item);
                }

                if (!itemRecords.isEmpty()) {
                    insert itemRecords;

                    for (Menu_Item__c rec : itemRecords) {
                        CreatedItemSummary s = new CreatedItemSummary();
                        s.id = rec.Id;
                        s.name = rec.Name;
                        s.price = rec.Price__c;
                        out.createdItems.add(s);
                    }
                }
            }

            menu = [SELECT Id, Name, Menu_Display_Name__c FROM Menu__c WHERE Id = :menu.Id LIMIT 1];

            out.menu = menu;
            out.itemCount = out.createdItems.size();
            out.success = true;
            out.message = 'Created menu "' + menu.Menu_Display_Name__c + '" with ' + out.itemCount + ' item(s).';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.createdItemsJson = JSON.serialize(out.createdItems);
        return new List<Response>{ out };
    }

    /**
     * Collects unique category names from the item inputs, looks up existing
     * Menu_Category__c records by name, and creates any that don't yet exist.
     * Returns a map of lowercase-category-name → Menu_Category__c Id.
     */
    private static Map<String, Id> resolveCategories(List<MenuItemInput> items) {
        Set<String> categoryNames = new Set<String>();
        for (MenuItemInput mi : items) {
            if (String.isNotBlank(mi.category)) {
                categoryNames.add(mi.category.trim());
            }
        }
        if (categoryNames.isEmpty()) return new Map<String, Id>();

        Map<String, Id> resolved = new Map<String, Id>();
        for (Menu_Category__c existing : [
            SELECT Id, Name FROM Menu_Category__c WHERE Name IN :categoryNames
        ]) {
            resolved.put(existing.Name.toLowerCase(), existing.Id);
        }

        List<Menu_Category__c> toCreate = new List<Menu_Category__c>();
        for (String catName : categoryNames) {
            if (!resolved.containsKey(catName.toLowerCase())) {
                toCreate.add(new Menu_Category__c(Name = catName));
            }
        }
        if (!toCreate.isEmpty()) {
            insert toCreate;
            for (Menu_Category__c created : toCreate) {
                resolved.put(created.Name.toLowerCase(), created.Id);
            }
        }

        return resolved;
    }

    private static List<MenuItemInput> parseItems(String itemsJsonStr) {
        if (String.isBlank(itemsJsonStr)) return new List<MenuItemInput>();
        try {
            List<MenuItemInput> parsed = (List<MenuItemInput>) System.JSON.deserialize(
                itemsJsonStr, List<MenuItemInput>.class
            );
            return parsed != null ? parsed : new List<MenuItemInput>();
        } catch (Exception e) {
            return new List<MenuItemInput>();
        }
    }
}