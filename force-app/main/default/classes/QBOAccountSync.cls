public with sharing class QBOAccountSync {
    
    @AuraEnabled
    public static  List<Map<String, Object>> syncAccountsBidirectional(List<Map<String,Object>> data) {
        System.debug('data-->'+data);
        try {
            List<Map<String, Object>> syncResults = new List<Map<String, Object>>();
    
        // Query accounts updated in the last hour in Salesforce
        DateTime oneHourAgo = DateTime.now().addHours(-1);
    
        List<Account> updatedAccounts = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, LastModifiedDate
            FROM Account
            WHERE LastModifiedDate >= :oneHourAgo
        ];

        System.debug('update Accounts'+updatedAccounts);
       List< Map<String, Object>> qboUpdatedAccounts = data;

        // Create a map of Salesforce accounts for easy lookup by name or another unique field
        Map<String, Account> sfAccountMap = new Map<String, Account>();
        for (Account acc : updatedAccounts) {
            sfAccountMap.put(acc.Name, acc);
        }

        // // Sync QBO accounts with Salesforce
        for (Map<String,Object> obj : qboUpdatedAccounts) {

            Map<String, Object> qboAccount = obj;
            String qboAccountName = (String)qboAccount.get('Name');
            DateTime LastUpdatedTime = null;

            // Parse QBO LastModifiedDate if present
            if (qboAccount.containsKey('MetaData')) {
                System.debug('===>');
                Map<Object, Object> rawMetaData = (Map<Object, Object>)qboAccount.get('MetaData');

                Map<String, Object> metaData = new Map<String, Object>();
                for (Object key : rawMetaData.keySet()) {
                    metaData.put((String)key, rawMetaData.get(key));
                }
    
                if (metaData.containsKey('LastUpdatedTime')) {
                    String rawDateTime = (String)metaData.get('LastUpdatedTime');
                    // Remove the time zone offset
                    String formattedDateTime = rawDateTime.split('\\-\\d{2}:\\d{2}')[0]; // Splits at the offset

                    // Parse the date
                    LastUpdatedTime = DateTime.valueOf(formattedDateTime.replace('T', ' '));                }
            }
            System.debug('LastUpdatedData---->'+LastUpdatedTime);
    
            if (sfAccountMap.containsKey(qboAccountName)) {
                Account sfAccount = sfAccountMap.get(qboAccountName);
    
                if (LastUpdatedTime > sfAccount.LastModifiedDate ) {
                    System.debug('====> if');
                    // Update QBO with Salesforce data
                    Map<String, Object> result = SyncSalesforceAccountInQBO(sfAccount);
                    syncResults.add(result);
                } else {

                    System.debug('update else');
                    // Update Salesforce with QBO data
                    UpdateSalesforceAccountWithQBO(sfAccount, qboAccount);
                    syncResults.add(new Map<String, Object>{
                        'success' => true,
                        'message' => 'Salesforce account updated with QBO data',
                        'statusCode' => 200,
                        'accountId' => sfAccount.Id
                    });
                }
    
                // Remove the account from the map to avoid re-processing
                sfAccountMap.remove(qboAccountName);
            } else {
                System.debug('created else');
                // If QBO account does not exist in Salesforce, create it
                CreateSalesforceAccountWithQBO(qboAccount);
                syncResults.add(new Map<String, Object>{
                    'success' => true,
                    'message' => 'New Salesforce account created from QBO data',
                    'statusCode' => 200

                });
            }
        }
    
        System.debug('stAccountMap--->'+sfAccountMap);
        // // Sync remaining Salesforce accounts to QBO
        if (!sfAccountMap.isEmpty()) {
            System.debug('sfAccountMap.isEmpty()'+sfAccountMap.isEmpty());
            for (Account sfAccount : sfAccountMap.values()) {
                Map<String, Object> result = SyncSalesforceAccountInQBO(sfAccount);
                syncResults.add(result);
            }
        }

        System.debug('syncResults'+syncResults);
        return syncResults;
        } catch (Exception e) {
            List<Map<String, Object>> errorList = new List<Map<String, Object>>();
            Map<String, Object> error = new Map<String, Object>(SharedServicesController.FormatResponseHandler(false, 'Accounts Sync Failed', null, e));
            errorList.add(error);
            return errorList;
            // throw new AuraHandledException('Error'+error);
        } 
    }
    
    
    //     /**
    //      * Sync QBO Accounts in Salesforce
    //      */
        public static void CreateSalesforceAccountWithQBO(Map<String, Object> qboAccount) {
            Account newAccount = new Account(
                Name = (String)qboAccount.get('Name'),
                No_of_Items__c = 5
            );
            insert newAccount;
        }
        
    //     /**
    //      * Update Salesforce Account with QBO accounts data
    //      */
        public static void UpdateSalesforceAccountWithQBO(Account sfAccount, Map<String, Object> qboAccount) {
        sfAccount.Name = (String)qboAccount.get('Name');
        sfAccount.No_of_Items__c = 10;
        update sfAccount;
    }
    

    public static Map<String, Object> SyncSalesforceAccountInQBO(Account acc) {
        System.debug('accounts===>'+acc);
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            // Prepare account data
            Map<String, Object> accountData = new Map<String, Object> {
                'Name' => acc.Name,
                'AccountType' => 'Accounts Receivable' 
            };
            
            System.debug('Account Data--'+accountData);
            
            // Serialize the account data to JSON
            String body = JSON.serialize(accountData);
            
            // Call the external service
            HttpResponse res = SharedServicesController.SendRequestHandler('/account', 'POST', 'application/json', body);
            System.debug('HTTP Response: ' + res);
            
            // Check the response status code
            if (res.getStatusCode() == 200) {
                response.putAll(SharedServicesController.FormatResponseHandler(true, 'Account synced successfully', res, null));
            } else {
                // Log the failure details
                String errorMessage = 'Failed to sync account. Status Code: ' + res.getStatusCode() + ', Response Body: ' + res.getBody();
                System.debug('Error: ' + errorMessage);
                response.putAll(SharedServicesController.FormatResponseHandler(false, errorMessage, res, null));
            }
        } catch (Exception e) {
            // Log detailed error information
            String errorMessage = 'Error syncing account: ' + e.getMessage() + ', StackTrace: ' + e.getStackTraceString();
            System.debug('Exception: ' + errorMessage);
            
            // Return the formatted error response
            response.putAll(SharedServicesController.FormatResponseHandler(false, 'Error syncing account', null, e));
        }
        
        System.debug('----response--->' + response);
        return response;
    }

    
    @AuraEnabled
    public static Map<String,Object> GetQBOUpdatedAccounts() {
        try {

            // Get the current time in UTC (no need to adjust for PKT here)
            DateTime oneHourAgoUTC = DateTime.now().addHours(4);  // Now it's already in UTC
            
            // Format the time in UTC with 'Z' suffix
            String formattedTime = oneHourAgoUTC.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

            String query = 'select * from Account Where Metadata.LastUpdatedTime >= \'' + formattedTime + '\'';
            String encodedQuery = EncodingUtil.urlEncode(query, 'UTF-8');
            String postUrl = '/query?query=' + encodedQuery;

            HttpResponse res = SharedServicesController.SendRequestHandler(postUrl, 'GET', 'text/plain', null);
            if (res.getStatusCode() == 200) {
                // Parse the response body into a list of maps
                Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                if (responseBody.containsKey('QueryResponse')) {
                    // Extract the 'QueryResponse' map
                    Map<String, Object> queryResponse = (Map<String, Object>)responseBody.get('QueryResponse');                
                    return queryResponse;
                } else {
                    // QueryResponse not found, return an empty list
                    return new Map<String, Object>(); 
                }
            } else if(res.getStatusCode() == 401){
                Map<String, Object> errorResponse = (Map<String, Object>)SharedServicesController.FormatResponseHandler(false, 'Token Expire', res, null);
                return errorResponse;
            }else{
                return new Map<String, Object>(); 

            }
        } catch (Exception e) {
            System.debug('getting QBO account'+e.getMessage());
            throw new AuraHandledException('Error in getting QBO accounts');
            }
    }


}
