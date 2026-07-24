package uk.gov.hmcts.probate.dmnutils;

public class TaskAttributeConstants {

    private TaskAttributeConstants() {
    }

    public static final String CASE_NAME = "caseName";
    public static final String CASE_MANAGEMENT_CATEGORY = "caseManagementCategory";
    public static final String REGION = "region";
    public static final String LOCATION = "location";
    public static final String LOCATION_NAME = "locationName";
    public static final String DUE_DATE_NON_WORKING_CALENDAR = "dueDateNonWorkingCalendar";
    public static final String DUE_DATE_WORKING_DAYS_OF_WEEK = "dueDateNonWorkingDaysOfWeek";
    public static final String WORK_TYPE = "workType";
    public static final String ROLE_CATEGORY = "roleCategory";
    public static final String MINOR_PRIORITY = "minorPriority";
    public static final String MAJOR_PRIORITY = "majorPriority";
    public static final String DESCRIPTION = "description";
    public static final String DUE_DATE_INTERVAL_DAYS = "dueDateIntervalDays";
    public static final String DUE_DATE_ORIGIN = "dueDateOrigin";
    public static final String DUE_DATE_TIME = "dueDateTime";
    public static final String DUE_DATE_NON_WORKING_DAYS_OF_WEEK = "dueDateNonWorkingDaysOfWeek";
    public static final String PRIORITY_DATE_ORIGIN_REF = "priorityDateOriginRef";
    public static final String ADDITIONAL_PROPERTIES_ROLE_ASSIGNMENT_ID = "additionalProperties_roleAssignmentId";
    public static final String REGISTRY_LOCATION = "registryLocation";
    public static final String DECEASED_FORENAMES = "deceasedForenames";
    public static final String DECEASED_SURNAME = "deceasedSurname";
    public static final String CASE_TYPE = "caseType";

    public static final String DECISION_WORK_TYPE = "decision_making_work";
    public static final String ROUTINE_WORK_TYPE = "routine_work";
    public static final String HEARING_WORK_TYPE = "hearing_work";
    public static final String PRIORITY_WORK_TYPE = "priority";
    public static final String APPLICATION_WORK_TYPE = "applications";
    public static final String ACCESS_WORK_TYPE = "access_requests";

    public static final String ROLE_CATEGORY_ADMIN = "ADMIN";
    public static final String ROLE_CATEGORY_LO = "LEGAL_OPERATIONS";
    public static final String ROLE_CATEGORY_JUDICIAL = "JUDICIAL";
    public static final String ROLE_CATEGORY_CTSC = "CTSC";

    public static final String DEFAULT_MINOR_PRIORITY = "500";
    public static final String DEFAULT_MAJOR_PRIORITY = "5000";
    public static final String URGENT_MAJOR_PRIORITY = "2000";
    public static final String DEFAULT_CASE_MANAGEMENT_CATEGORY = "Criminal Injuries Compensation";
    public static final String DEFAULT_REGION = "1";
    public static final String DEFAULT_LOCATION = "336559";
    public static final String DEFAULT_LOCATION_NAME = "Glasgow Tribunals Centre";
    public static final String DEFAULT_DUE_DATE_NON_WORKING_CALENDAR
        = "https://www.gov.uk/bank-holidays/scotland.json, https://raw.githubusercontent.com/hmcts/sptribs-case-api/master/src/main/resources/dmn/privilege-calendar.json";
    public static final String DEFAULT_DUE_DATE_WORKING_DAYS_OF_WEEK = "SATURDAY,SUNDAY";

    public static final String EXAMINE_DIGITAL_CASE_PROBATE = "ExamineDigitalCaseProbate";
    public static final String EXAMINE_DIGITAL_CASE_ADMON = "ExamineDigitalCaseAdmonWill";
    public static final String EXAMINE_DIGITAL_CASE_INTESTACY = "ExamineDigitalCaseIntestacy";
    public static final String EXAMINE_DE_BONIS_NON = "ExamineDeBonisNon";
    public static final String EXAMINE_FIAT_WILL = "ExamineFiatWill";

    public static final String CREATE_DUE_DATE = "createDueDate";
    public static final String ISSUE_DUE_DATE = "issueDueDate";

    public static final String AUTO_COMPLETE_MODE = "Auto";
    public static final String DEFAULT_NONE_COMPLETE_MODE = "defaultNone";

    public static final String PROCESS_CATEGORY_PROCESSING = "Processing";
    public static final String PROCESS_CATEGORY_HEARING = "Hearing";
    public static final String PROCESS_CATEGORY_DECISION = "Decision";
    public static final String PROCESS_CATEGORY_AMENDMENT = "Amendment";
    public static final String PROCESS_CATEGORY_APPLICATION = "Application";
    public static final String PROCESS_CATEGORY_HEARING_BUNDLE = "HearingBundle";
    public static final String PROCESS_CATEGORY_ISSUE_CASE = "IssueCase";
    public static final String PROCESS_CATEGORY_HEARING_COMPLETION = "HearingCompletion";

    public static final String PROCESS_REINSTATEMENT_DECISION_NOTICE_TASK = "processReinstatementDecisionNotice";

    public static final String CASE_TYPE_VALUE = "someCaseType";
    public static final String DECEASED_FORENAMES_VALUE = "someDeceasedForenames";
    public static final String DECEASED_SURNAME_VALUE = "someDeceasedSurname";
    public static final String REGISTRY_LOCATION_VALUE = "someRegistryLocation";
    public static final String DUE_DATE_INTERVAL_DAYS_VALUE = "10";
    public static final String DUE_DATE_NON_WORKING_DAYS_OF_WEEK_VALUE = "SATURDAY,SUNDAY";
    public static final String PRIORITY_DATE_ORIGIN_REF_VALUE = "dueDate";
    public static final String DUE_DATE_NON_WORKING_CALENDAR_VALUE = "https://www.gov.uk/bank-holidays/england-and-wales.json";
    public static final String DUE_DATE_TIME_VALUE = "16:00";
    public static final String DESCRIPTION_EXAMINE_DIGITAL_CASE_PROBATE_DEFAULT_VALUE =
            "[Amend Case Details](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/boAmendCaseDetails)  "
            + "[Issue Grant](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/boIssueGrantForCaseMatching)  "
            + "[Escalate to Registrar](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/boEscalateToRegistrar)  "
            + "[Select For QA](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/boSelectForQA)  "
            + "[SME Referral](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/moveToCWEscalation)  "
            + "[Stop Case](/cases/case-details/"
            + "${[CASE_REFERENCE]}/trigger/boStopCaseForCasePrinted)";

    public static final String PROBATE_EXAMINE_SKILL_CODE = "SKILL:ABA6:ProbateExamining";
    public static final String DE_BONIS_NON_SKILL_CODE = "SKILL:ABA6:DeBonisNon";
    public static final String FIAT_WILL_SKILL_CODE = "SKILL:ABA6:FiatWill";
}
