/**
 * Remote unlock for a verified resident. Called by the Remote Unlock Door flow.
 *
 * This class never inserts a Case. The flow inserts the Door Access Case only
 * when unlocked is true, so a failed or refused call leaves no success record.
 *
 * Without sharing: the agent user cannot see every Contact and Apartment__c
 * row. The checks below are the access control, not record sharing.
 */
public without sharing class UnlockDoor {

    public class Request {
        @InvocableVariable(required=true label='Customer Id')
        public String customerId;

        @InvocableVariable(required=true label='Apartment Id')
        public String apartmentId;

        @InvocableVariable(required=true label='Authentication Key')
        public String authenticationKey;
    }

    public class Result {
        @InvocableVariable(label='Unlocked')
        public Boolean unlocked;

        @InvocableVariable(label='Account Id')
        public String accountId;

        @InvocableVariable(label='Request Id')
        public String requestId;

        @InvocableVariable(label='Result Message')
        public String resultMessage;
    }

    @InvocableMethod(
        label='Unlock Door'
        description='Unlocks the bound apartment for a verified tenant. Calls SmartRent only after the tenant, apartment, and device checks pass. Does not insert a Case.'
    )
    public static List<Result> unlock(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            results.add(unlockOne(request));
        }
        return results;
    }

    private static Result unlockOne(Request request) {
        Result result = refused('The door was not unlocked.');

        Id contactId = contactFor(request.customerId);
        if (contactId == null || String.isBlank(request.apartmentId) || String.isBlank(request.authenticationKey)) {
            return result;
        }

        List<Apartment__c> apartments = [
            SELECT Id, Account__c, Occupied__c, External_Id__c, SmartRent_Device_Id__c
            FROM Apartment__c
            WHERE Id = :request.apartmentId
            LIMIT 1
        ];
        if (apartments.isEmpty()) {
            return result;
        }
        Apartment__c apartment = apartments[0];

        Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
        if (apartment.Account__c == null || contact.AccountId != apartment.Account__c) {
            return result;
        }
        if (apartment.Occupied__c != true) {
            return result;
        }
        if (String.isBlank(apartment.SmartRent_Device_Id__c)) {
            return result;
        }

        result.accountId = apartment.Account__c;

        HttpResponse response;
        try {
            response = send(apartment, request.authenticationKey);
        } catch (CalloutException e) {
            result.resultMessage = 'The door was not unlocked. SmartRent did not respond.';
            return result;
        }

        if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            Map<String, Object> body = parse(response.getBody());
            result.unlocked = true;
            result.requestId = body.containsKey('requestId') ? String.valueOf(body.get('requestId')) : null;
            result.resultMessage = 'The door was unlocked.';
            return result;
        }

        // 409 means SmartRent already handled this key. Do not unlock again and do not
        // count it as a new success. Flagged for review in the design note.
        result.resultMessage = 'The door was not unlocked.';
        return result;
    }

    private static Result refused(String message) {
        Result result = new Result();
        result.unlocked = false;
        result.resultMessage = message;
        return result;
    }

    /** Accepts a Contact Id or a User Id. Returns null when neither resolves. */
    private static Id contactFor(String customerId) {
        if (String.isBlank(customerId)) {
            return null;
        }
        Id recordId;
        try {
            recordId = Id.valueOf(customerId);
        } catch (StringException e) {
            return null;
        }
        if (recordId.getSObjectType() == Contact.SObjectType) {
            return recordId;
        }
        if (recordId.getSObjectType() == User.SObjectType) {
            List<User> users = [SELECT ContactId FROM User WHERE Id = :recordId LIMIT 1];
            return users.isEmpty() ? null : users[0].ContactId;
        }
        return null;
    }

    private static HttpResponse send(Apartment__c apartment, String authenticationKey) {
        Map<String, String> payload = new Map<String, String>{
            'apartmentExternalId' => apartment.External_Id__c,
            'requestedBy' => 'verified-contact',
            'reason' => 'resident_remote_unlock'
        };

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:SmartRent_API/smartrent/v1/devices/'
            + EncodingUtil.urlEncode(apartment.SmartRent_Device_Id__c, 'UTF-8')
            + '/unlock'
        );
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Idempotency-Key', authenticationKey);
        request.setBody(JSON.serialize(payload));
        request.setTimeout(10000);

        return new Http().send(request);
    }

    private static Map<String, Object> parse(String body) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            return parsed;
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }
}
