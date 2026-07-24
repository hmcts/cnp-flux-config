package uk.gov.hmcts.probate.dmn;

import org.camunda.bpm.dmn.engine.DmnDecisionTableResult;
import org.camunda.bpm.dmn.engine.impl.DmnDecisionTableImpl;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.impl.VariableMapImpl;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import uk.gov.hmcts.probate.DmnDecisionTableBaseUnitTest;
import uk.gov.hmcts.probate.dmnutils.CaseDataBuilder;
import uk.gov.hmcts.probate.dmnutils.ConfigurationExpectationBuilder;

import java.io.IOException;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Stream;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static uk.gov.hmcts.probate.DmnDecisionTable.WA_TASK_CONFIGURATION_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.APPLICATION_WORK_TYPE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DESCRIPTION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_ADMON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_INTESTACY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.resultsMatchUsingNameKey;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.WORK_TYPE;

class CamundaTaskWaConfigurationTest extends DmnDecisionTableBaseUnitTest {

    private static final String REQUEST = "classpath:custom-case-data.json";
    private static final String taskId = UUID.randomUUID().toString();
    private static final String roleAssignmentId = UUID.randomUUID().toString();

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_CONFIGURATION_PROBATE;
    }

    static Stream<Arguments> scenarioProvider() throws IOException {
        String dateOrigin = ZonedDateTime.now(ZoneId.of("UTC")).toString();
        return Stream.of(
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_PROBATE,
                        CaseDataBuilder.defaultWaCase()
                                .isUrgent()
                                .build(),
                        "handleEvidence",
                        ConfigurationExpectationBuilder.defaultExamineDigitalCaseProbateExpectations().build()
                ),
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_PROBATE,
                        CaseDataBuilder.defaultWaCase()
                                .isUrgent()
                                .build(),
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        ConfigurationExpectationBuilder.defaultExamineDigitalCaseProbateExpectations().build()
                ),
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_ADMON,
                        CaseDataBuilder.defaultCase()
                                .isUrgent()
                                .build(),
                        "handleEvidence",
                        ConfigurationExpectationBuilder.defaultExpectations()
                                .expectedValue(DESCRIPTION, "[Select For QA](/cases/case-details/${[CASE_REFERENCE]}"
                                         + "/trigger/boSelectForQA)", true)
                                .build()
                ),
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_INTESTACY,
                        CaseDataBuilder.defaultCase()
                                .isUrgent()
                                .build(),
                        "handleEvidence",
                        ConfigurationExpectationBuilder.defaultExpectations()
                                .expectedValue(DESCRIPTION, "[Select For QA](/cases/case-details/${[CASE_REFERENCE]}"
                                        + "/trigger/boSelectForQA)", true)
                                .build()
                ),
                Arguments.of(
                        EXAMINE_DE_BONIS_NON,
                        CaseDataBuilder.defaultWaCase()
                                .isUrgent()
                                .build(),
                        "handleEvidence",
                        ConfigurationExpectationBuilder.defaultExamineDigitalCaseProbateExpectations()
                                .expectedValue(WORK_TYPE, APPLICATION_WORK_TYPE, true)
                                .expectedValue(DESCRIPTION, "[Issue Grant](/cases/case-details/${[CASE_REFERENCE]}"
                                        + "/trigger/boIssueGrantForCaseMatching)  "
                                        + "[Escalate to Registrar](/cases/case-details/${[CASE_REFERENCE]}"
                                        + "/trigger/boEscalateToRegistrar)  "
                                        + "[SME Referral](/cases/case-details/${[CASE_REFERENCE]}"
                                        + "/trigger/moveToCWEscalation)  "
                                        + "[Stop Case](/cases/case-details/${[CASE_REFERENCE]}"
                                        + "/trigger/boStopCaseForCaseMatchingForExamining)", true)
                                .build()
                ),
                Arguments.of(
                    EXAMINE_FIAT_WILL,
                    CaseDataBuilder.defaultWaCase()
                        .isUrgent()
                        .build(),
                    "handleEvidence",
                    ConfigurationExpectationBuilder.defaultExamineDigitalCaseProbateExpectations()
                        .expectedValue(WORK_TYPE, APPLICATION_WORK_TYPE, true)
                        .expectedValue(DESCRIPTION, "[Issue Grant](/cases/case-details/${[CASE_REFERENCE]}"
                            + "/trigger/boIssueGrantForCaseMatching)  "
                            + "[Escalate to Registrar](/cases/case-details/${[CASE_REFERENCE]}"
                            + "/trigger/boEscalateToRegistrar)  "
                            + "[SME Referral](/cases/case-details/${[CASE_REFERENCE]}"
                            + "/trigger/moveToCWEscalation)  "
                            + "[Stop Case](/cases/case-details/${[CASE_REFERENCE]}"
                            + "/trigger/boStopCaseForCaseMatchingForExamining)", true)
                        .build()
                )
        );
    }

    @Test
    void if_this_test_fails_needs_updating_with_your_changes() {
        //The purpose of this test is to prevent adding new rows without being tested
        DmnDecisionTableImpl logic = (DmnDecisionTableImpl) decision.getDecisionLogic();
        assertThat(logic.getInputs().size(), is(2));
        assertThat(logic.getOutputs().size(), is(3));
        assertEquals(18, logic.getRules().size());
    }

    @ParameterizedTest(name = "task type: {0} case data: {1}")
    @MethodSource("scenarioProvider")
    void should_return_correct_configuration_values_for_scenario(
            String taskType, Map<String, Object> caseData,
            String eventId,
            List<Map<String, Object>> expectation) {
        VariableMap inputVariables = new VariableMapImpl();

        Map<String, String> taskAttributes = Map.of(
                "taskType", taskType,
                "roleAssignmentId", roleAssignmentId,
                "taskId", taskId
        );
        inputVariables.putValue("taskAttributes", taskAttributes);
        inputVariables.putValue("taskType", taskType);
        inputVariables.putValue("caseData", caseData);
        inputVariables.putValue("eventId", eventId);

        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);

        resultsMatchUsingNameKey(dmnDecisionTableResult.getResultList(), expectation);
    }

    private boolean validNow(ZonedDateTime expected, ZonedDateTime result) {
        ZonedDateTime now = ZonedDateTime.now();
        return result != null
                && (expected.isEqual(result) || expected.isBefore(result))
                && (now.isEqual(result) || now.isAfter(result));
    }

}
