/**
 * AgentUpdateMenuActions
 *
 * Updates Menu__c record fields (display name, description, active status).
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdateMenuActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Menu Id'
            description='The Menu__c record Id to update.'
            required=true
        )
        public Id menuId;

        @InvocableVariable(
            label='Display Name'
            description='New display name for the menu (Menu__c.Menu_Display_Name__c). Leave blank to skip.'
            required=false
        )
        public String displayName;

        @InvocableVariable(
            label='Description'
            description='New description for the menu (Menu__c.Description__c). Leave blank to skip.'
            required=false
        )
        public String description;

        @InvocableVariable(
            label='Active'
            description='Set the menu active (true) or inactive (false). Leave null to skip.'
            required=false
        )
        public Boolean active;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the update executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Menu Id'
            description='Echo of the updated Menu__c Id.'
        )
        public Id menuId;

        @InvocableVariable(
            label='Menu Name'
            description='Display name of the updated menu.'
        )
        public String menuName;
    }

    @InvocableMethod(
        label='Update Menu'
        description='Updates menu fields such as display name, description, and active status. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;
        out.message = null;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                return new List<Response>{ out };
            }
            if (req.menuId == null) {
                out.message = 'menuId is required.';
                return new List<Response>{ out };
            }

            List<Menu__c> menus = [
                SELECT Id, Menu_Display_Name__c, Description__c, Active__c,
                       Storefront__r.Account__c
                FROM Menu__c
                WHERE Id = :req.menuId
                LIMIT 1
            ];

            if (menus.isEmpty()) {
                out.message = 'No menu found with the provided Id.';
                return new List<Response>{ out };
            }

            Menu__c menu = menus[0];

            if (menu.Storefront__r.Account__c != req.accountId) {
                out.message = 'Access denied. This menu does not belong to the specified account.';
                return new List<Response>{ out };
            }

            Boolean hasUpdates = false;

            if (req.displayName != null) {
                menu.Menu_Display_Name__c = req.displayName;
                hasUpdates = true;
            }
            if (req.description != null) {
                menu.Description__c = req.description;
                hasUpdates = true;
            }
            if (req.active != null) {
                menu.Active__c = req.active;
                hasUpdates = true;
            }

            if (!hasUpdates) {
                out.success = true;
                out.message = 'No fields provided to update.';
                out.menuId = menu.Id;
                out.menuName = menu.Menu_Display_Name__c;
                return new List<Response>{ out };
            }

            update menu;

            out.success = true;
            out.message = 'Menu updated successfully.';
            out.menuId = menu.Id;
            out.menuName = menu.Menu_Display_Name__c;
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}