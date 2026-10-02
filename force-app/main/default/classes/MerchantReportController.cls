/**
 * Backs the merchantReportForm LWC on the Merchant Support site (/merchants).
 * Guests (restaurants and couriers) submit email + storefront + message; this creates the same
 * Merchant Report Case as Email-to-Case and the Web-to-Case form:
 *   Origin = Merchant Report, Reported_Storefront__c = chosen storefront, SuppliedEmail = sender.
 * The Merchant_Report_Case_Enrichment flow then sets Storefront, Type, Reason and the Merchant Ops Queue owner.
 * Runs without sharing because site guests cannot read Storefronts or create Cases themselves.
 */
public without sharing class MerchantReportController {

    @AuraEnabled(cacheable=true)
    public static List<String> getStorefronts() {
        List<String> names = new List<String>();
        for (Storefront__c s : [SELECT Name FROM Storefront__c ORDER BY Name LIMIT 500]) {
            names.add(s.Name);
        }
        return names;
    }

    @AuraEnabled
    public static String submitReport(String email, String storefront, String message) {
        if (String.isBlank(email) || !email.trim().contains('@') || email.trim().contains(' ') || !email.trim().substringAfter('@').contains('.')) {
            throw new AuraHandledException('Enter a valid email address.');
        }
        if (String.isBlank(storefront) || [SELECT COUNT() FROM Storefront__c WHERE Name = :storefront] == 0) {
            throw new AuraHandledException('Choose your storefront.');
        }
        if (String.isBlank(message)) {
            throw new AuraHandledException('Tell us what is happening.');
        }
        email = email.trim();
        message = message.trim();

        Case c = new Case(
            Origin = 'Merchant Report',
            SuppliedEmail = email,
            Subject = message.split('\n')[0].left(80),
            Description = message + '\n\nStorefront: ' + storefront + '\nSubmitted via the Pronto merchant site.',
            Reported_Storefront__c = storefront
        );
        // The sender is matched to a Contact by SuppliedEmail in the Merchant_Report_Case_Enrichment flow (system mode),
        // so site guests never need access to Contacts.
        Database.DMLOptions options = new Database.DMLOptions();
        options.assignmentRuleHeader.useDefaultRule = true;      // Merchant Report -> Merchant Ops Queue
        options.EmailHeader.triggerAutoResponseEmail = true;     // merchant confirmation email
        c.setOptions(options);
        insert c;
        // Site guests cannot read the Case back (guest sharing), so the merchant gets the case number in the
        // confirmation email sent by the Pronto Merchant Reports auto-response rule.
        return 'sent';
    }
}
