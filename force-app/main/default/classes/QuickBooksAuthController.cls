@RestResource(urlMapping='/IntuitOAuthRedirect')
global with sharing class QuickBooksAuthController {

    @HttpGet
    global static void handleRedirect() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String authCode = req.params.get('code');
        String state = req.params.get('state');

        if (authCode != null) {
            // Save the authorization code for later use
            // Redirect to a success page or handle further processing
            res.addHeader('Location', '/success-page');
            res.statusCode = 302;
        } else {
            // Handle error or missing code
            res.addHeader('Location', '/error-page');
            res.statusCode = 302;
        }
    }

    @AuraEnabled
    public static Map<String, String> getAccessToken(String code, String realmId) {
        try {
            // Fetch metadata to get Client ID, Client Secret, and Authorization Code
            Map<String, String> credentials = getQuickBookMetadata();
            Map<String, String> response = new Map<String, String>();

            String clientId = credentials.get('clientId');
            String clientSecret = credentials.get('clientSecret');
            String redirectUri = credentials.get('redirectUri');
            String authorizationCode = code;

            if (String.isEmpty(clientId) || String.isEmpty(clientSecret)) {
                throw new AuraHandledException('Client ID or Client Secret is missing in metadata.');
            }

            // If authorization code is available and not expired, exchange it for tokens
            response = get_access_token(clientId, clientSecret, authorizationCode, redirectUri);
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Exception: ' + e.getMessage());
        }
    }

    // Exchange Authorization Code for Access and Refresh Tokens
    private static Map<String, String> get_access_token(String clientId, String clientSecret, String authorizationCode, String redirectUri) {
        Map<String, String> response = new Map<String, String>();
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';

            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(clientId + ':' + clientSecret)));

            // Set query parameters in the request body
            String requestBody = 'grant_type=authorization_code'
                + '&code=' + authorizationCode
                + '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8');

            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Parse response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                response.put('accessToken', (String) responseMap.get('access_token'));
                response.put('refreshToken', (String) responseMap.get('refresh_token'));
                return response;
            } else {
                response.put('error', res.getStatus() + ' - ' + res.getBody());
                return response;
            }
        } catch (Exception e) {
            response.put('error', 'Error exchanging authorization code: ' + e.getMessage());
            return response;
        }
    }

    // Use Refresh Token to Get a New Access Token
    @AuraEnabled
    public static Map<String, String> refreshAccessToken() {
        Map<String, String> credentials = getQuickBookMetadata();
        Map<String, String> response = new Map<String, String>();
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';

            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(credentials.get('clientId') + ':' + credentials.get('clientSecret'))));

            // Set query parameters in the request body for refreshing the token
            String requestBody = 'grant_type=refresh_token'
                + '&refresh_token=' + credentials.get('refreshToken')
                + '&redirect_uri=' + EncodingUtil.urlEncode(credentials.get('redirectUri'), 'UTF-8');

            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Parse response to get new access token
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                response.put('accessToken', (String) responseMap.get('access_token'));
                response.put('refreshToken', (String) responseMap.get('refresh_token'));
                updateQuickBookMetadata(credentials.get('authorizationCode'), credentials.get('Realm_ID'), response.get('accessToken'), response.get('refreshToken'));
                return response;
            } else {
                response.put('error', res.getStatus() + ' - ' + res.getBody());
                return response;
            }
        } catch (Exception e) {
            response.put('error', 'Error refreshing access token: ' + e.getMessage());
            return response;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getQuickBookMetadata() {

        Map<String, String> credentials = new Map<String, String>();
        credentials.put('redirectUri', 'https://focusteck2-dev-ed--c.develop.vf.force.com/apex/Quick_Book_Integration');
        
        List<QuickBook__mdt> metadataRecords = [
            SELECT DeveloperName, value__c
            FROM QuickBook__mdt
            WHERE DeveloperName IN ('Client_ID','Client_Secret','accessToken','refreshToken','Authorization_Code','Realm_ID')
        ];
        for(QuickBook__mdt record : metadataRecords) {
            if(record.DeveloperName == 'Client_ID') {
                credentials.put('clientId', record.value__c);
            } else if(record.DeveloperName == 'Client_Secret') {
                credentials.put('clientSecret', record.value__c);
            } else if(record.DeveloperName == 'accessToken') {
                credentials.put('accessToken', record.value__c);
            } else if(record.DeveloperName == 'refreshToken') {
                credentials.put('refreshToken', record.value__c);
            } else if(record.DeveloperName == 'Authorization_Code') {
                credentials.put('authorizationCode', record.value__c);
            } else if(record.DeveloperName == 'Realm_ID') {
                credentials.put('Realm_ID', record.value__c);
            }
        }
        return credentials;
    }

    @AuraEnabled
    public static void updateQuickBookMetadata(String code, String realmId, String accessToken, String refreshToken) {
        List<QuickBook__mdt> metadataToUpdate = [
            SELECT Id, DeveloperName, value__c 
            FROM QuickBook__mdt 
            WHERE DeveloperName IN ('Authorization_Code', 'Realm_ID', 'accessToken', 'refreshToken')
        ];
        
        Map<String, String> updateValues = new Map<String, String>{
            'Authorization_Code' => code,
            'realmId' => realmId,
            'accessToken' => accessToken,
            'refreshToken' => refreshToken
        };
        
        List<Metadata.CustomMetadata> metadataRecords = new List<Metadata.CustomMetadata>();
        
        for(QuickBook__mdt record : metadataToUpdate) {
            if(updateValues.containsKey(record.DeveloperName)) {
                Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                customMetadata.fullName = 'QuickBook.' + record.DeveloperName;
                customMetadata.label = record.DeveloperName;
                
                Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                customField.field = 'value__c';
                customField.value = updateValues.get(record.DeveloperName);
                
                customMetadata.values.add(customField);
                metadataRecords.add(customMetadata);
            }
        }
        
        if(!metadataRecords.isEmpty()) {
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            for(Metadata.CustomMetadata cmd : metadataRecords) {
                mdContainer.addMetadata(cmd);
            }
            
            // Enqueue the deployment
            Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
    }
}