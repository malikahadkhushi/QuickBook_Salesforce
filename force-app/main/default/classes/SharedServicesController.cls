public with sharing class SharedServicesController {

    // get Meta data of Quick Books Online
    private static final Map<String, String> metadata = QuickBooksAuthController.getQuickBookMetadata();  

    // Static variables for access token and realm ID
    private static final String accessToken = metadata.get('accessToken');
    private static final String realmId = metadata.get('Realm_ID');

    // Inuit Base Url for API calls
    private static final String BASE_URL = 'https://sandbox-quickbooks.api.intuit.com/v3/company/';

    // class constructor
    public SharedServicesController() {

    }

    /**
     * This function will set request headers and body
     * Parameters {postUrl,Method of Request,Content Type and body of the request}
     */
    public static HttpResponse SendRequestHandler(String postUrl,String method, String content_type,String body){
        try {

            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL+realmId+postUrl);
            req.setMethod(method);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', content_type);
            req.setHeader('Accept', 'application/json');
    
            if(body != null){
             req.setBody(body);
            }
            Http http = new Http();
            HttpResponse res = http.send(req);
            return res;
            
        } catch (Exception e) {
            throw new AuraHandledException('Request Failed: '+e);
        }
    }

    public static Map<String, Object> FormatResponseHandler (Boolean status,String message,HttpResponse res,Exception e){
        Map<String, Object> response = new Map<String, Object>();

        response.put('success', status);
        response.put('message', message);
        response.put('statusCode', e!=null ? 500 : res.getStatusCode());
        
        if(res != null){
        response.put('data', JSON.deserializeUntyped(res.getBody()));
        }else{
            response.put('error',e.getMessage());
        }

        return response;
    }

}