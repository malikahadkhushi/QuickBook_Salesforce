@isTest
public class MyWebServiceMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        // Create a mock HTTP response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"status":"success","message":"Account synced successfully"}');
        res.setStatusCode(200);
        return res;
    }
}
