/**
 * One-time door verification code for a resident.
 *
 * Why this exists: the packaged Service verification flow cannot be used here.
 * It returns the code masked (xxxxxx) and its own email is not delivered under the
 * agent user in this org. This class sends its own email from the org-wide address.
 *
 * Nothing is stored. The authentication key carries an expiry and a signature over
 * contact id, apartment id, expiry, nonce and code. The code itself is only in the email.
 * The secret lives in the Door_Code_Secret__mdt record (git-ignored; this org does not allow protected types).
 *
 * Without sharing: the agent user cannot read every Contact. The checks below are
 * the access control, not record sharing.
 */
public without sharing class DoorCodeService {

    @TestVisible private static final Integer VALID_MINUTES = 5;
    // At most MAX_CODES codes are emailed per contact in any WINDOW_MINUTES window. Counted on the Contact, so a new chat does not reset it.
    @TestVisible private static final Integer MAX_CODES = 3;
    @TestVisible private static final Integer WINDOW_MINUTES = 60;
    @TestVisible private static String lastCodeForTest;

    public class SendRequest {
        @InvocableVariable(required=true label='Customer To Verify')
        public String customerToVerify;

        @InvocableVariable(label='Contact Id')
        public String contactId;

        @InvocableVariable(label='Apartment Id')
        public String apartmentId;
    }

    public class SendResult {
        @InvocableVariable(label='Customer Id')
        public String customerId;

        @InvocableVariable(label='Customer Type')
        public String customerType;

        @InvocableVariable(label='Authentication Key')
        public String authenticationKey;

        @InvocableVariable(label='Email Sent')
        public Boolean emailSent;

        @InvocableVariable(label='Email Matched')
        public Boolean emailMatched;

        @InvocableVariable(label='Rate Limited')
        public Boolean rateLimited;

        @InvocableVariable(label='Send Count')
        public Decimal sendCount;

        @InvocableVariable(label='Window Start')
        public Datetime windowStart;
    }

    @InvocableMethod(
        label='Send Door Code'
        description='Emails a one-time door code to the resident and returns the contact id and a signed authentication key. The code is never returned.'
    )
    public static List<SendResult> sendCode(List<SendRequest> requests) {
        List<SendResult> results = new List<SendResult>();
        for (SendRequest request : requests) {
            results.add(sendOne(request));
        }
        return results;
    }

    private static SendResult sendOne(SendRequest request) {
        SendResult result = new SendResult();
        result.emailSent = false;
        result.emailMatched = false;
        result.rateLimited = false;

        // The resident types their registered email. It must equal the email on the Contact record.
        // The code is then sent to the address stored on the record, never to a different address.
        Contact contact = findContact(request);
        if (contact == null || String.isBlank(request.apartmentId)) {
            return result;
        }
        result.emailMatched = true;
        Id contactId = contact.Id;

        // Read-only here. The portal user cannot update a Contact in Apex, so the Send Door Code flow
        // (system mode) saves the new count and window start from the outputs below.
        Datetime now = Datetime.now();
        Integer used = contact.Door_Code_Sends__c == null ? 0 : contact.Door_Code_Sends__c.intValue();
        Datetime windowStart = contact.Door_Code_Window_Start__c;
        if (windowStart == null || windowStart.addMinutes(WINDOW_MINUTES) < now) {
            used = 0;
            windowStart = now;
        }
        if (used >= MAX_CODES) {
            result.rateLimited = true;
            return result;
        }

        String code = newCode();
        lastCodeForTest = code;
        Long expiry = Datetime.now().addMinutes(VALID_MINUTES).getTime();
        String nonce = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
        String signature = sign(String.valueOf(contactId), request.apartmentId, expiry, nonce, code);

        Door_Code_Secret__mdt config = Door_Code_Secret__mdt.getInstance('Default');
        if (config == null || String.isBlank(config.Sender_Id__c) || String.isBlank(signature)) {
            return result;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setOrgWideEmailAddressId(config.Sender_Id__c);
        message.setToAddresses(new List<String>{ contact.Email });
        message.setSubject('Your Pacific Haven verification code');
        message.setPlainTextBody(
            'Your Pacific Haven verification code is: ' + code + '\n\n'
            + 'Enter this code in the chat to confirm it is you. The code is valid for '
            + VALID_MINUTES + ' minutes. If you did not ask to open your door, ignore this email.'
        );
        message.setSaveAsActivity(false);

        List<Messaging.SendEmailResult> sent = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ message }, false
        );
        if (sent.isEmpty() || !sent[0].isSuccess()) {
            return result;
        }

        result.sendCount = used + 1;
        result.windowStart = windowStart;
        result.customerId = String.valueOf(contactId);
        result.customerType = 'Contact';
        result.authenticationKey = expiry + '.' + nonce + '.' + signature;
        result.emailSent = true;
        return result;
    }

    private static Contact findContact(SendRequest request) {
        if (String.isBlank(request.contactId) || String.isBlank(request.customerToVerify)) {
            return null;
        }
        try {
            Id candidate = Id.valueOf(request.contactId);
            if (candidate.getSObjectType() != Contact.SObjectType) {
                return null;
            }
            List<Contact> rows = [SELECT Id, Email, Door_Code_Sends__c, Door_Code_Window_Start__c FROM Contact WHERE Id = :candidate LIMIT 1];
            if (rows.isEmpty() || String.isBlank(rows[0].Email)) {
                return null;
            }
            String entered = request.customerToVerify.trim().toLowerCase();
            return rows[0].Email.trim().toLowerCase() == entered ? rows[0] : null;
        } catch (Exception e) {
            return null;
        }
    }

    public static Boolean verify(String code, String customerId, String apartmentId, String key) {
        if (String.isBlank(code) || String.isBlank(customerId) || String.isBlank(apartmentId) || String.isBlank(key)) {
            return false;
        }
        List<String> parts = key.split('\\.');
        if (parts.size() != 3) {
            return false;
        }
        Long expiry;
        try {
            expiry = Long.valueOf(parts[0]);
        } catch (Exception e) {
            return false;
        }
        if (expiry < Datetime.now().getTime()) {
            return false;
        }
        String expected = sign(customerId, apartmentId, expiry, parts[1], code.trim());
        return String.isNotBlank(expected) && expected == parts[2];
    }

    private static String sign(String contactId, String apartmentId, Long expiry, String nonce, String code) {
        Door_Code_Secret__mdt secret = Door_Code_Secret__mdt.getInstance('Default');
        if (secret == null || String.isBlank(secret.Secret__c)) {
            return null;
        }
        String payload = contactId + '|' + apartmentId + '|' + expiry + '|' + nonce + '|' + code;
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret.Secret__c));
        return EncodingUtil.convertToHex(mac);
    }

    private static String newCode() {
        Integer value = Math.abs(Math.mod(Crypto.getRandomInteger(), 1000000));
        return String.valueOf(value).leftPad(6, '0');
    }
}
