public without sharing class ResidentSupportHours {
    private static final String HOURS_NAME = 'Pacific_Haven_Resident_Support';

    public class Request {
        @InvocableVariable(required=false label='Unused')
        public String unused;
    }

    public class Result {
        @InvocableVariable(label='Within Hours')
        public Boolean within_hours;
    }

    @InvocableMethod(
        label='Resident Support Hours Are Open'
        description='True when the Pacific Haven Resident Support business hours record is open now.'
    )
    public static List<Result> check(List<Request> requests) {
        BusinessHours hours = [
            SELECT Id
            FROM BusinessHours
            WHERE Name = :HOURS_NAME AND IsActive = TRUE
            LIMIT 1
        ];
        Result result = new Result();
        result.within_hours = BusinessHours.isWithin(hours.Id, System.now());
        return new List<Result>{ result };
    }
}
