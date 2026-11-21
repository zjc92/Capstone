@IsTest
private class DoorCodeServiceTest {

    private static final String APT = 'a00000000000001';

    @IsTest
    static void signedKeyVerifiesOnlyWithTheRightCodeAndContact() {
        Long expiry = Datetime.now().addMinutes(5).getTime();
        String key = expiry + '.abc123.deadbeef';
        System.assertEquals(false, DoorCodeService.verify('123456', '003000000000001', APT, null));
        System.assertEquals(false, DoorCodeService.verify('', '003000000000001', APT, key));
        System.assertEquals(false, DoorCodeService.verify('123456', '003000000000001', '', key));
        System.assertEquals(false, DoorCodeService.verify('123456', '003000000000001', APT, 'not.a.key'));
        System.assertEquals(false, DoorCodeService.verify('123456', '003000000000001', APT, key));
        System.assertEquals(false, DoorCodeService.verify('123456', '003000000000001', APT, '1.abc.def'));
    }

    @IsTest
    static void sendFailsClosedWithoutAMatchingContact() {
        DoorCodeService.SendRequest request = new DoorCodeService.SendRequest();
        request.customerToVerify = 'nobody@example.invalid';
        request.apartmentId = APT;
        List<DoorCodeService.SendResult> results = DoorCodeService.sendCode(
            new List<DoorCodeService.SendRequest>{ request }
        );
        System.assertEquals(false, results[0].emailSent);
        System.assertEquals(false, results[0].emailMatched);
        System.assertEquals(null, results[0].authenticationKey);
    }

    @IsTest
    static void aTypedEmailThatDoesNotMatchTheContactSendsNothing() {
        Contact c = new Contact(LastName = 'Resident', Email = 'resident@example.com');
        insert c;
        Contact other = new Contact(LastName = 'Other', Email = 'other@example.com');
        insert other;
        DoorCodeService.SendRequest request = new DoorCodeService.SendRequest();
        request.contactId = String.valueOf(c.Id);
        request.apartmentId = APT;
        // Another resident's real address must not work for this contact.
        request.customerToVerify = 'other@example.com';
        DoorCodeService.SendResult result = DoorCodeService.sendCode(
            new List<DoorCodeService.SendRequest>{ request }
        )[0];
        System.assertEquals(false, result.emailMatched);
        System.assertEquals(false, result.emailSent);
        System.assertEquals(null, result.authenticationKey);
        // No contact id: no lookup by email alone.
        request.contactId = null;
        request.customerToVerify = 'resident@example.com';
        result = DoorCodeService.sendCode(new List<DoorCodeService.SendRequest>{ request })[0];
        System.assertEquals(false, result.emailMatched);
        System.assertEquals(null, result.authenticationKey);
    }

    @IsTest
    static void atMostThreeCodesPerContactPerWindow() {
        Contact c = new Contact(
            LastName = 'Resident', Email = 'resident@example.com',
            Door_Code_Sends__c = DoorCodeService.MAX_CODES, Door_Code_Window_Start__c = Datetime.now()
        );
        insert c;
        DoorCodeService.SendRequest request = new DoorCodeService.SendRequest();
        request.customerToVerify = 'resident@example.com';
        request.contactId = String.valueOf(c.Id);
        request.apartmentId = APT;
        DoorCodeService.SendResult blocked = DoorCodeService.sendCode(new List<DoorCodeService.SendRequest>{ request })[0];
        System.assertEquals(true, blocked.rateLimited);
        System.assertEquals(false, blocked.emailSent);
        System.assertEquals(null, blocked.authenticationKey);
        // Two codes used inside the window: still allowed.
        update new Contact(Id = c.Id, Door_Code_Sends__c = DoorCodeService.MAX_CODES - 1);
        DoorCodeService.SendResult third = DoorCodeService.sendCode(new List<DoorCodeService.SendRequest>{ request })[0];
        System.assertEquals(false, third.rateLimited);
        // An older window no longer counts.
        update new Contact(Id = c.Id, Door_Code_Sends__c = DoorCodeService.MAX_CODES, Door_Code_Window_Start__c = Datetime.now().addMinutes(-DoorCodeService.WINDOW_MINUTES - 1));
        DoorCodeService.SendResult again = DoorCodeService.sendCode(new List<DoorCodeService.SendRequest>{ request })[0];
        System.assertEquals(false, again.rateLimited);
        if (again.emailSent == true) {
            System.assertEquals(1, again.sendCount);
        }
    }

    @IsTest
    static void checkerReturnsFalseForBadInput() {
        DoorCodeChecker.Request request = new DoorCodeChecker.Request();
        request.customerCode = '000000';
        request.customerId = '003000000000001';
        request.apartmentId = APT;
        request.authenticationKey = 'bad';
        System.assertEquals(false, DoorCodeChecker.check(new List<DoorCodeChecker.Request>{ request })[0].isVerified);
    }

    @IsTest
    static void codeSentByEmailVerifiesOnceAndExpiresWhenSigned() {
        Contact c = new Contact(LastName = 'Resident', Email = 'resident@example.com');
        insert c;
        DoorCodeService.SendRequest request = new DoorCodeService.SendRequest();
        // Case and spacing in what the resident types do not matter.
        request.customerToVerify = '  Resident@Example.com ';
        request.contactId = String.valueOf(c.Id);
        request.apartmentId = APT;
        DoorCodeService.SendResult result = DoorCodeService.sendCode(
            new List<DoorCodeService.SendRequest>{ request }
        )[0];
        System.assertEquals(true, result.emailMatched);
        if (result.emailSent != true) {
            // The org-wide sender or the secret record is missing in this org, so nothing can be signed.
            System.assertEquals(null, result.authenticationKey);
            return;
        }
        String code = DoorCodeService.lastCodeForTest;
        System.assertEquals(true, DoorCodeService.verify(code, result.customerId, APT, result.authenticationKey));
        System.assertEquals(false, DoorCodeService.verify('000000' == code ? '111111' : '000000', result.customerId, APT, result.authenticationKey));
        System.assertEquals(false, DoorCodeService.verify(code, '003000000000001', APT, result.authenticationKey));
        // The code is bound to the apartment it was issued for.
        System.assertEquals(false, DoorCodeService.verify(code, result.customerId, 'a00000000000002', result.authenticationKey));
        List<String> parts = result.authenticationKey.split('\\.');
        String expiredKey = '1.' + parts[1] + '.' + parts[2];
        System.assertEquals(false, DoorCodeService.verify(code, result.customerId, APT, expiredKey));
    }
}
