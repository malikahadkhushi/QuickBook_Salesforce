@isTest
public class QBOAccountSyncTest {

    @isTest
    static void testSyncAccountsBidirectional() {
        // Create test data
        Account acc = new Account(Name = 'Test Account134535ooo32', BillingStreet = '123 Test St',No_of_Items__c = 5);
        insert acc;

        // Simulate QBO data
        Map<String, Object> qboAccount = new Map<String, Object>{
            'Name' => 'Test Account12444343',
            'MetaData' => new Map<Object, Object>{
                'LastUpdatedTime' => '2025-01-16T23:31:25-08:00'
            }
        };
        List<Map<String, Object>> qboData = new List<Map<String, Object>>{qboAccount};
        Test.startTest();
        List<Map<String, Object>> results = QBOAccountSync.syncAccountsBidirectional(qboData);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(true, results[0].get('success'), 'Sync should be successful');
    }

    @isTest
    static void testSyncAccountsBidirectional_NewAccount() {
        // Simulate QBO data for an account that doesn't exist in Salesforce
        Map<String, Object> qboAccount = new Map<String, Object>{
            'Name' => 'New QBO Account',
            'MetaData' => new Map<Object, Object>{
                'LastUpdatedTime' => '2025-01-16T23:31:25-08:00'
            }
        };
        List<Map<String, Object>> qboData = new List<Map<String, Object>>{qboAccount};

        Test.startTest();
        List<Map<String, Object>> results = QBOAccountSync.syncAccountsBidirectional(qboData);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'There should be one result');
        System.assertEquals(true, results[0].get('success'), 'New account creation should be successful');
    }

    @isTest
    static void testSyncAccountsBidirectional_Exception() {
        Test.startTest();
        List<Map<String, Object>> results = QBOAccountSync.syncAccountsBidirectional(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'There should be one result');
        System.assertEquals(false, results[0].get('success'), 'Sync should fail due to null input');
    }

    @isTest
    static void testCreateSalesforceAccountWithQBO() {
        Map<String, Object> qboAccount = new Map<String, Object>{
            'Name' => 'New Salesforce Account'
        };

        Test.startTest();
        QBOAccountSync.CreateSalesforceAccountWithQBO(qboAccount);
        Test.stopTest();

        Account createdAccount = [SELECT Name FROM Account WHERE Name = 'New Salesforce Account' LIMIT 1];
        System.assertNotEquals(null, createdAccount, 'Account should be created');
    }

    @isTest
    static void testUpdateSalesforceAccountWithQBO() {
        Account acc = new Account(Name = 'Account to Update',No_of_Items__c = 5);
        insert acc;

        Map<String, Object> qboAccount = new Map<String, Object>{
            'Name' => 'Updated Account'
        };

        Test.startTest();
        QBOAccountSync.UpdateSalesforceAccountWithQBO(acc, qboAccount);
        Test.stopTest();

        Account updatedAccount = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Account', updatedAccount.Name, 'Account name should be updated');
    }

    // @isTest
    // static void testSyncSalesforceAccountInQBO() {
    //     Account acc = new Account(Name = 'Account for QBO Syncsfgdsdfwerdsff',No_of_Items__c = 5);
    //     insert acc;

    //     Test.startTest();
    //     Map<String, Object> result = QBOAccountSync.SyncSalesforceAccountInQBO(acc);
    //     Test.stopTest();

    //     System.assertNotEquals(null, result, 'Result should not be null');
    //     System.assertEquals(true, result.get('success'), 'Sync should be successful');
    // }

    @isTest
    static void testSyncSalesforceAccountInQBO() {
        // Prepare test data
        Account testAccount = new Account(Name = 'Test Account',No_of_Items__c=5);
        insert testAccount;

        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MyWebServiceMock());

        // Start the test context
        Test.startTest();

        // Call the method that makes the callout
        Map<String, Object> result = QBOAccountSync.SyncSalesforceAccountInQBO(testAccount);

        // Stop the test context
        Test.stopTest();

        // Verify the results
        System.assertEquals(true, result.get('success'));
        System.assertEquals('Account synced successfully', result.get('message'));
    }

    @isTest
    static void testGetQBOUpdatedAccounts() {
        Test.startTest();
        Map<String, Object> result = QBOAccountSync.GetQBOUpdatedAccounts();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }
}
