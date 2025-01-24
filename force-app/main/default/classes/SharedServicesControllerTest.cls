@isTest
public class SharedServicesControllerTest {

    @isTest
    static void testSendRequestHandler_Success() {
        // Mock the HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"status":"success","data":{"id":"123"}}');
        mockResponse.setStatusCode(200);

        // Set up the mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockImpl(mockResponse));

        // Call the method
        Test.startTest();
        HttpResponse response = SharedServicesController.SendRequestHandler('/testEndpoint', 'GET', 'application/json', null);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(200, response.getStatusCode(), 'Status code should be 200');
        System.assert(response.getBody().contains('"status":"success"'), 'Response body should contain success status');
    }

    @isTest
    static void testSendRequestHandler_Exception() {
        // Mock an exception during HTTP callout
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockImpl(null, true));

        // Call the method and verify exception
        try {
            Test.startTest();
            SharedServicesController.SendRequestHandler('/testEndpoint', 'GET', 'application/json', null);
            Test.stopTest();
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Request Failed'), 'Exception message should indicate request failure');
        }
    }

    @isTest
    static void testFormatResponseHandler_Success() {
        // Mock the HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('Content-Type', 'application/json');
        mockResponse.setBody('{"status":"success","data":{"id":"123"}}');
        mockResponse.setStatusCode(200);

        // Call the method
        Map<String, Object> formattedResponse = SharedServicesController.FormatResponseHandler(
            true,
            'Request successful',
            mockResponse,
            null
        );

        // Assertions
        System.assertEquals(true, formattedResponse.get('success'), 'Success flag should be true');
        System.assertEquals('Request successful', formattedResponse.get('message'), 'Message should match');
        System.assertEquals(200, formattedResponse.get('statusCode'), 'Status code should match');
        System.assertNotEquals(null, formattedResponse.get('data'), 'Data should not be null');
    }

    @isTest
    static void testFormatResponseHandler_Exception() {
        // Simulate an exception with no message
        Exception mockException = null;
    
        // Call the method
        Map<String, Object> formattedResponse = SharedServicesController.FormatResponseHandler(
            false,
            'Request failed',
            null,
            mockException
        );
    
        // Assertions
        System.assertEquals(false, formattedResponse.get('success'), 'Success flag should be false');
        System.assertEquals('Request failed', formattedResponse.get('message'), 'Message should match');
        System.assertEquals(500, formattedResponse.get('statusCode'), 'Status code should be 500');
        System.assertNotEquals(null, formattedResponse.get('error'), 'Error message should not be null');
    }
    
    
    // Mock class for HTTP callouts
    private class HttpCalloutMockImpl implements HttpCalloutMock {
        private HttpResponse mockResponse;
        private Boolean throwError;

        public HttpCalloutMockImpl(HttpResponse response, Boolean throwError) {
            this.mockResponse = response;
            this.throwError = throwError;
        }

        public HttpCalloutMockImpl(HttpResponse response) {
            this(response, false);
        }

        public HTTPResponse respond(HTTPRequest req) {
            if (throwError) {
                throw new CalloutException('Mock callout exception');
            }
            return mockResponse;
        }
    }
}
