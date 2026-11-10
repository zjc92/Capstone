@IsTest(SeeAllData=true)
private class OpsCopilotFlowTest {
    static User manager(String managerName) {
        return [SELECT Id FROM User WHERE Name = :managerName AND IsActive = true LIMIT 1];
    }

    static Map<String, Object> evaluate(String tenantName) {
        Flow.Interview interview = Flow.Interview.createInterview(
            'Evaluate_Tenant_Renewal',
            new Map<String, Object>{ 'tenant_name' => tenantName }
        );
        interview.start();
        return new Map<String, Object>{
            'result_code' => interview.getVariableValue('result_code'),
            'decision' => interview.getVariableValue('decision'),
            'past_due_count' => interview.getVariableValue('past_due_count'),
            'increase_percent' => interview.getVariableValue('increase_percent'),
            'notice_days' => interview.getVariableValue('notice_days'),
            'tone' => interview.getVariableValue('tone'),
            'apartment_name' => interview.getVariableValue('apartment_name'),
            'city' => interview.getVariableValue('city')
        };
    }

    @IsTest
    static void californiaManagerSeesRajOnly() {
        User california = manager('California Manager');
        System.runAs(california) {
            Map<String, Object> raj = evaluate('Raj Patel');
            System.assertEquals('found', raj.get('result_code'));
            System.assertEquals('StandardRenewal', raj.get('decision'));
            System.assertEquals(0, raj.get('past_due_count'));
            System.assertEquals(0, raj.get('increase_percent'));
            System.assertEquals('warm', raj.get('tone'));
            System.assertEquals('San Francisco', raj.get('city'));

            Map<String, Object> other = evaluate('Harpreet Singh');
            System.assertEquals('no_payment_history', other.get('result_code'));
            System.assertEquals('San Francisco', other.get('city'));
            System.assertEquals(null, other.get('decision'));

            Map<String, Object> elsewhere = evaluate('Joseph Smith');
            System.assertEquals('not_found', elsewhere.get('result_code'));
            System.assertEquals(null, elsewhere.get('city'));
            System.assertEquals(null, elsewhere.get('decision'));
        }
    }

    @IsTest
    static void oregonFirstYearHasNoIncrease() {
        User oregon = manager('Oregon Manager');
        System.runAs(oregon) {
            Map<String, Object> harpreet = evaluate('Harpreet Singh');
            System.assertEquals('found', harpreet.get('result_code'));
            System.assertEquals('RenewalNoIncrease', harpreet.get('decision'));
            System.assertEquals(2, harpreet.get('past_due_count'));
            System.assertEquals(0, harpreet.get('increase_percent'));
            System.assertEquals(90, harpreet.get('notice_days'));
            System.assertEquals('strict', harpreet.get('tone'));
            System.assertEquals('Portland', harpreet.get('city'));
        }
    }

    @IsTest
    static void washingtonDecline() {
        User washington = manager('Washington Manager');
        System.runAs(washington) {
            Map<String, Object> vikram = evaluate('Vikram Kumar');
            System.assertEquals('found', vikram.get('result_code'));
            System.assertEquals('Decline', vikram.get('decision'));
            System.assertEquals(4, vikram.get('past_due_count'));
            System.assertEquals(0, vikram.get('increase_percent'));
            System.assertEquals('decline', vikram.get('tone'));
            System.assertEquals('Seattle', vikram.get('city'));
        }
    }

    @IsTest
    static void weeklySummaryUsesThatManager() {
        User california = manager('California Manager');
        System.runAs(california) {
            Flow.Interview interview = Flow.Interview.createInterview(
                'Summarize_Manager_Week',
                new Map<String, Object>()
            );
            interview.start();
            System.assertEquals(21, interview.getVariableValue('building_count'));
            System.assertEquals(500, interview.getVariableValue('apartment_count'));
        }
    }

    @IsTest
    static void wrapperReadsTheRunningUser() {
        User california = manager('California Manager');
        System.runAs(california) {
            Flow.Interview.Review_Tenant_Renewal renewal = new Flow.Interview.Review_Tenant_Renewal(
                new Map<String, Object>{ 'tenant_name' => 'Raj Patel' }
            );
            renewal.start();
            System.assertEquals('found', renewal.result_code);
            System.assertEquals('StandardRenewal', renewal.decision);
            System.assertEquals('San Francisco', renewal.city);
            System.assertEquals('warm', renewal.tone);
            System.assert(renewal.case_table.contains('Faucet is leaking | Closed'));
            System.assert(renewal.case_table.contains('No power | New'));

            Flow.Interview.Weekly_Property_Summary week = new Flow.Interview.Weekly_Property_Summary(
                new Map<String, Object>()
            );
            week.start();
            System.assertEquals(21, week.building_count);
            System.assertEquals(500, week.apartment_count);
        }
    }

    @IsTest
    static void enteredUserIdOverridesTheLogin() {
        User california = manager('California Manager');
        Flow.Interview.Review_Tenant_Renewal renewal = new Flow.Interview.Review_Tenant_Renewal(
            new Map<String, Object>{
                'tenant_name' => 'Raj Patel',
                'manager_user_id' => california.Id
            }
        );
        renewal.start();
        System.assertEquals('found', renewal.result_code);
        System.assertEquals('StandardRenewal', renewal.decision);
        System.assertEquals('San Francisco', renewal.city);
    }
}
