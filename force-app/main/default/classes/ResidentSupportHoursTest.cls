@isTest
private class ResidentSupportHoursTest {
    @isTest
    static void returnsWhetherTheSupportRecordIsOpen() {
        List<ResidentSupportHours.Result> results = ResidentSupportHours.check(
            new List<ResidentSupportHours.Request>{ new ResidentSupportHours.Request() }
        );

        System.assertEquals(1, results.size(), 'One result for one request.');
        System.assertNotEquals(null, results[0].within_hours, 'The business hours record answers open or closed.');
    }
}
