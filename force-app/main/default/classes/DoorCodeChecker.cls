/**
 * Checks the code a resident typed against the signed key from DoorCodeService.
 * Returns only is_verified. Called by the Check Door Code flow.
 */
public without sharing class DoorCodeChecker {

    public class Request {
        @InvocableVariable(required=true label='Customer Code')
        public String customerCode;

        @InvocableVariable(required=true label='Customer Id')
        public String customerId;

        @InvocableVariable(required=true label='Apartment Id')
        public String apartmentId;

        @InvocableVariable(required=true label='Authentication Key')
        public String authenticationKey;
    }

    public class Result {
        @InvocableVariable(label='Is Verified')
        public Boolean isVerified;
    }

    @InvocableMethod(
        label='Check Door Code'
        description='True only when the code matches the signed key for this contact and apartment and the key has not expired.'
    )
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Result result = new Result();
            result.isVerified = DoorCodeService.verify(
                request.customerCode, request.customerId, request.apartmentId, request.authenticationKey
            );
            results.add(result);
        }
        return results;
    }
}
