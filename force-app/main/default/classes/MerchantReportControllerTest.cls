@IsTest
private class MerchantReportControllerTest {
    @IsTest
    static void createsMerchantReportCase() {
        insert new Storefront__c(Name = 'Test Kitchen');
        Account a = new Account(Name = 'Test Merchant');
        insert a;
        insert new Contact(LastName = 'Manager', Email = 'mgr@test.example', AccountId = a.Id);

        System.assert(MerchantReportController.getStorefronts().contains('Test Kitchen'));
        System.assertEquals('sent', MerchantReportController.submitReport('mgr@test.example', 'Test Kitchen', 'Out of fries tonight'));

        Case c = [SELECT Origin, ContactId, AccountId, Reported_Storefront__c, Subject FROM Case WHERE Subject = 'Out of fries tonight' LIMIT 1];
        System.assertEquals('Merchant Report', c.Origin);
        System.assertEquals(a.Id, c.AccountId);
        System.assertEquals('Test Kitchen', c.Reported_Storefront__c);
        System.assertEquals('Out of fries tonight', c.Subject);
    }

    @IsTest
    static void rejectsBadInput() {
        try {
            MerchantReportController.submitReport('not-an-email', 'x', 'y');
            System.assert(false, 'expected an error');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
