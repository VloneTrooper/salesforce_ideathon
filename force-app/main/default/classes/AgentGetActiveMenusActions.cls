/**
 * AgentGetActiveMenusActions
 *
 * Retrieves all active menus for a given storefront.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentGetActiveMenusActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to retrieve menus for.'
            required=true
        )
        public Id storefrontId;
    }

    public class MenuSummary {
        @InvocableVariable(label='Menu Id' description='The Menu__c record Id.')
        public Id menuId;

        @InvocableVariable(label='Menu Name' description='The customer-facing menu name to display to the user.')
        public String menuName;

        @InvocableVariable(label='Description' description='Menu description.')
        public String description;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the query executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Menus'
            description='A list of active menus for the storefront.'
        )
        public List<MenuSummary> menus;

        @InvocableVariable(
            label='Menus JSON'
            description='JSON-serialized version of menus for clients that prefer JSON parsing.'
        )
        public String menusJson;

        @InvocableVariable(
            label='Menu Count'
            description='Number of active menus found.'
        )
        public Integer menuCount;
    }

    @InvocableMethod(
        label='Get Active Menus'
        description='Retrieves all active menus for a given storefront. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.menus = new List<MenuSummary>();
        out.success = false;
        out.message = null;
        out.menuCount = 0;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }
            if (req.storefrontId == null) {
                out.message = 'storefrontId is required.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            // Validate storefront belongs to the provided account
            List<Storefront__c> storefronts = [
                SELECT Id, Account__c
                FROM Storefront__c
                WHERE Id = :req.storefrontId
                LIMIT 1
            ];

            if (storefronts.isEmpty()) {
                out.message = 'No storefront found with the provided Id.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            if (storefronts[0].Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            List<Menu__c> menus = [
                SELECT Id, Name, Menu_Display_Name__c, Description__c, Active__c
                FROM Menu__c
                WHERE Storefront__c = :req.storefrontId
                AND Active__c = true
                ORDER BY Name ASC
                LIMIT 100
            ];

            List<String> menuLines = new List<String>();
            for (Menu__c m : menus) {
                MenuSummary s = new MenuSummary();
                s.menuId = m.Id;
                s.menuName = String.isNotBlank(m.Menu_Display_Name__c)
                    ? m.Menu_Display_Name__c
                    : m.Name;
                s.description = m.Description__c;
                out.menus.add(s);

                String line = '- ' + s.menuName;
                if (String.isNotBlank(s.description)) {
                    line += ': ' + s.description;
                }
                menuLines.add(line);
            }

            out.menuCount = out.menus.size();
            out.success = true;
            out.message = 'Found ' + out.menuCount + ' active menu(s) for this storefront:\n'
                + String.join(menuLines, '\n');
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.menusJson = JSON.serialize(out.menus);
        return new List<Response>{ out };
    }
}