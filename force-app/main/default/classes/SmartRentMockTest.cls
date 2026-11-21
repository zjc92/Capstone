@IsTest
private class SmartRentMockTest {
    private static RestResponse call(String path) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/smartrent/v1/' + path;
        req.httpMethod = 'POST';
        req.addHeader('Idempotency-Key', 'abcd1234xyz');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        SmartRentMock.handlePost();
        return RestContext.response;
    }
    @IsTest static void unlockReturns200() {
        System.assertEquals(200, call('devices/D1/unlock').statusCode);
    }
    @IsTest static void orderReturns201() {
        System.assertEquals(201, call('keyfob-orders').statusCode);
    }
    @IsTest static void otherReturns404() {
        System.assertEquals(404, call('other').statusCode);
    }
}
