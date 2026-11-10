@isTest
private class UnlockDoorTest {

    private class MockSmartRent implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private Boolean throwError;

        MockSmartRent(Integer statusCode, String body, Boolean throwError) {
            this.statusCode = statusCode;
            this.body = body;
            this.throwError = throwError;
        }

        public HttpResponse respond(HttpRequest request) {
            if (throwError) {
                throw new CalloutException('simulated timeout');
            }
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(body);
            return response;
        }
    }

    @TestSetup
    static void makeData() {
        Account home = new Account(Name = 'Unlock Test Household');
        Account other = new Account(Name = 'Unlock Other Household');
        insert new List<Account>{ home, other };

        Contact resident = new Contact(LastName = 'Resident', AccountId = home.Id);
        Contact stranger = new Contact(LastName = 'Stranger', AccountId = other.Id);
        insert new List<Contact>{ resident, stranger };

        Apartment__c occupied = new Apartment__c(
            Name = 'Unlock Test Unit',
            Account__c = home.Id,
            Occupied__c = true,
            External_Id__c = 'APT-TEST-1',
            SmartRent_Device_Id__c = 'DEV-TEST-1'
        );
        Apartment__c noDevice = new Apartment__c(
            Name = 'Unlock No Device Unit',
            Account__c = home.Id,
            Occupied__c = true,
            External_Id__c = 'APT-TEST-2'
        );
        Apartment__c vacant = new Apartment__c(
            Name = 'Unlock Vacant Unit',
            Account__c = home.Id,
            Occupied__c = false,
            External_Id__c = 'APT-TEST-3',
            SmartRent_Device_Id__c = 'DEV-TEST-3'
        );
        insert new List<Apartment__c>{ occupied, noDevice, vacant };
    }

    private static Id contactNamed(String lastName) {
        return [SELECT Id FROM Contact WHERE LastName = :lastName LIMIT 1].Id;
    }

    private static Id apartmentNamed(String name) {
        return [SELECT Id FROM Apartment__c WHERE Name = :name LIMIT 1].Id;
    }

    private static UnlockDoor.Result run(String customerId, String apartmentId, String key) {
        UnlockDoor.Request request = new UnlockDoor.Request();
        request.customerId = customerId;
        request.apartmentId = apartmentId;
        request.authenticationKey = key;
        Test.startTest();
        UnlockDoor.Result result = UnlockDoor.unlock(new List<UnlockDoor.Request>{ request })[0];
        Test.stopTest();
        return result;
    }

    @isTest
    static void refusesWhenContactBelongsToAnotherAccount() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-1","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Stranger'), apartmentNamed('Unlock Test Unit'), 'key-a');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void refusesWhenApartmentIsVacant() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-1","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Vacant Unit'), 'key-b');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void refusesWhenDeviceIdIsBlank() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-1","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock No Device Unit'), 'key-c');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void refusesWhenCustomerIdIsNotAContactOrUser() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-1","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(apartmentNamed('Unlock Test Unit'), apartmentNamed('Unlock Test Unit'), 'key-d');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void refusesWhenAuthenticationKeyIsBlank() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-1","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Test Unit'), '');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void unlocksWhenSmartRentReturnsCreated() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(201, '{"requestId":"UNL-77812","status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Test Unit'), 'key-e');
        System.assertEquals(true, result.unlocked, result.resultMessage);
        System.assertEquals('UNL-77812', result.requestId);
    }

    @isTest
    static void doesNotUnlockWhenSmartRentTimesOut() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(0, '', true));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Test Unit'), 'key-f');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void doesNotUnlockWhenSmartRentReturnsServerError() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(500, '{"error":"down"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Test Unit'), 'key-g');
        System.assertEquals(false, result.unlocked);
    }

    @isTest
    static void doesNotUnlockAgainOnConflict() {
        Test.setMock(HttpCalloutMock.class, new MockSmartRent(409, '{"status":"UNLOCKED"}', false));
        UnlockDoor.Result result = run(contactNamed('Resident'), apartmentNamed('Unlock Test Unit'), 'key-h');
        System.assertEquals(false, result.unlocked);
    }
}
