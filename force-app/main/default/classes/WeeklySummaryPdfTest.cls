@isTest
private class WeeklySummaryPdfTest {

    private static WeeklySummaryPdf.Request sample() {
        WeeklySummaryPdf.Request r = new WeeklySummaryPdf.Request();
        r.buildingCount = 21;
        r.apartmentCount = 500;
        r.occupiedCount = 250;
        r.vacantCount = 250;
        r.occupancyRate = 50.0;
        r.paymentsDueCount = 1;
        r.latePaymentCount = 0;
        r.lateRentTotal = 0;
        r.casesOpenedCount = 0;
        r.casesOpenCount = 1;
        r.casesClosedCount = 2;
        return r;
    }

    @isTest
    static void createsAPdfFileForTheRunningUser() {
        List<WeeklySummaryPdf.Result> out = WeeklySummaryPdf.create(new List<WeeklySummaryPdf.Request>{ sample() });
        System.assertEquals(1, out.size());
        System.assert(out[0].fileUrl.contains('/sfc/servlet.shepherd/document/download/'), out[0].fileUrl);
        System.assert(out[0].fileName.endsWith('.pdf'));
        List<ContentVersion> files = [SELECT Id, OwnerId, FileExtension FROM ContentVersion WHERE PathOnClient = :out[0].fileName];
        System.assertEquals(1, files.size());
        System.assertEquals('pdf', files[0].FileExtension);
        System.assertEquals(UserInfo.getUserId(), files[0].OwnerId);
    }

    @isTest
    static void badManagerIdReturnsNoLinkInsteadOfFailing() {
        WeeklySummaryPdf.Request r = sample();
        r.managerUserId = '001000000000000AAA';
        List<WeeklySummaryPdf.Result> out = WeeklySummaryPdf.create(new List<WeeklySummaryPdf.Request>{ r });
        System.assertEquals('', out[0].fileUrl);
    }
}
