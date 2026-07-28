package uk.gov.hmcts.probate.dmnutils;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ADDITIONAL_PROPERTIES_ROLE_ASSIGNMENT_ID;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.CASE_MANAGEMENT_CATEGORY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DESCRIPTION_EXAMINE_DIGITAL_CASE_PROBATE_DEFAULT_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_INFECTED_BLOOD_COMPENSATION_AUTHORITY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REGION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.CASE_NAME;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DESCRIPTION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_INTERVAL_DAYS;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_NON_WORKING_CALENDAR;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_NON_WORKING_DAYS_OF_WEEK;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_ORIGIN;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_TIME;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.LOCATION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.LOCATION_NAME;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.MAJOR_PRIORITY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.MINOR_PRIORITY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_WORKING_DAYS_OF_WEEK;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.WORK_TYPE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ROLE_CATEGORY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.PRIORITY_DATE_ORIGIN_REF;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ROLE_CATEGORY_CTSC;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REGISTRY_LOCATION_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_NON_WORKING_CALENDAR_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_TIME_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_INTERVAL_DAYS_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DUE_DATE_NON_WORKING_DAYS_OF_WEEK_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.APPLICATIONS_WORK_TYPE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.PRIORITY_DATE_ORIGIN_REF_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REFERENCE_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.READY_TO_ISSUE_STATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DESCRIPTION_EXAMINE_OTHER_CASES;


public class ConfigurationExpectationBuilder {

    private static final List<String> EXPECTED_PROPERTIES = Arrays.asList(
            CASE_NAME, CASE_MANAGEMENT_CATEGORY, REGION, LOCATION, LOCATION_NAME, MAJOR_PRIORITY, MINOR_PRIORITY,
            DUE_DATE_NON_WORKING_CALENDAR, DUE_DATE_WORKING_DAYS_OF_WEEK, WORK_TYPE, ROLE_CATEGORY,
            DUE_DATE_INTERVAL_DAYS,
            ADDITIONAL_PROPERTIES_ROLE_ASSIGNMENT_ID, DESCRIPTION, PRIORITY_DATE_ORIGIN_REF, DUE_DATE_ORIGIN,
            DUE_DATE_TIME
    );

    private final Map<String, Map<String, Object>> expectations = new HashMap<>();

    public static ConfigurationExpectationBuilder defaultExpectations() {
        return new ConfigurationExpectationBuilder();
    }

    public static ConfigurationExpectationBuilder examineDigitalCaseExpectationsForConditions(
            Map<String, String> conditions) {
        ConfigurationExpectationBuilder builder = new ConfigurationExpectationBuilder();

        if (conditions.containsValue(READY_TO_ISSUE_STATE) && conditions.containsKey("taskType")
                && (conditions.get("taskType").equals(EXAMINE_DE_BONIS_NON)
                || conditions.get("taskType").equals(EXAMINE_FIAT_WILL)
                || conditions.get("taskType").equals(EXAMINE_INFECTED_BLOOD_COMPENSATION_AUTHORITY)
            )) {
            builder.expectedValue(DESCRIPTION, DESCRIPTION_EXAMINE_OTHER_CASES, true);
        } else {
            builder.expectedValue(DESCRIPTION, DESCRIPTION_EXAMINE_DIGITAL_CASE_PROBATE_DEFAULT_VALUE, true);
        }
        builder.expectedValue(WORK_TYPE, APPLICATIONS_WORK_TYPE_PROBATE, true)
                .expectedValue(CASE_MANAGEMENT_CATEGORY, "Probate", true)
                .expectedValue(CASE_NAME, REFERENCE_VALUE, true)
                .expectedValue(REGION, "DUMMY_PLACEHOLDER_REGION", true)
                .expectedValue(ROLE_CATEGORY, ROLE_CATEGORY_CTSC, true)
                .expectedValue(LOCATION, REGISTRY_LOCATION_VALUE, true)
                .expectedValue(LOCATION_NAME, REGISTRY_LOCATION_VALUE, true)
                .expectedValue(DUE_DATE_NON_WORKING_CALENDAR, DUE_DATE_NON_WORKING_CALENDAR_VALUE, true)
                .expectedValue(DUE_DATE_TIME, DUE_DATE_TIME_VALUE, true)
                .expectedValue(DUE_DATE_INTERVAL_DAYS, DUE_DATE_INTERVAL_DAYS_VALUE, true)
                .expectedValue(DUE_DATE_NON_WORKING_DAYS_OF_WEEK,
                        DUE_DATE_NON_WORKING_DAYS_OF_WEEK_VALUE, true)
                .expectedValue(PRIORITY_DATE_ORIGIN_REF, PRIORITY_DATE_ORIGIN_REF_VALUE, true);
        return builder;
    }

    public List<Map<String, Object>> build() {
        return EXPECTED_PROPERTIES.stream()
                .filter(expectations::containsKey)
                .map(expectations::get)
                .collect(Collectors.toList());
    }

    public ConfigurationExpectationBuilder expectedValue(String name, Object value, boolean canReconfigure) {
        expectations.put(name, Map.of(
                "name", name,
                "value", value,
                "canReconfigure", canReconfigure
        ));
        return this;
    }
}
