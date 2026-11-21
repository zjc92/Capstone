/**
 * Demo stand-in for the SmartRent API. Public on purpose: SmartRent_API calls it
 * through the Pacific Haven site. It reads and writes no records and returns fixed
 * success bodies so the unlock and key fob order paths can be shown end to end.
 */
@RestResource(urlMapping='/smartrent/v1/*')
global with sharing class SmartRentMock {

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String key = req.headers.get('Idempotency-Key');
        String suffix = String.isBlank(key) ? 'DEMO' : key.left(8).toUpperCase();
        res.addHeader('Content-Type', 'application/json');
        if (req.requestURI.endsWith('/unlock')) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'requestId' => 'MOCK-REQ-' + suffix,
                'status' => 'unlocked'
            }));
        } else if (req.requestURI.endsWith('/keyfob-orders')) {
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'orderId' => 'MOCK-ORD-' + suffix,
                'status' => 'ordered',
                'estimatedDelivery' => '3 business days'
            }));
        } else {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf('{"error":"not found"}');
        }
    }
}
