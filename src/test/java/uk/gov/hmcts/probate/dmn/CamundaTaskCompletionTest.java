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

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;
import static uk.gov.hmcts.probate.DmnDecisionTable.WA_TASK_COMPLETION_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.resultsMatchUsingTaskTypeKey;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.AUTO_COMPLETE_MODE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_ADMON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_INTESTACY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;

class CamundaTaskCompletionTest extends DmnDecisionTableBaseUnitTest {

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_COMPLETION_PROBATE;
    }

    static Stream<Arguments> scenarioProvider() {

        return Stream.of(
                Arguments.of(
                        "boSelectForQA",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_PROBATE
                                ),
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_INTESTACY
                                ),
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_ADMON
                                )
                        )
                ),
                Arguments.of(
                        "boStopCaseForCasePrinted",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_PROBATE
                                )
                        )
                ),
                Arguments.of(
                        "moveToCWEscalation",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_PROBATE
                                ),
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DE_BONIS_NON
                                ),
                                Map.of(
                                    "completionMode", AUTO_COMPLETE_MODE,
                                    "taskType", EXAMINE_FIAT_WILL
                                )
                        )
                ),
                Arguments.of(
                        "boStopCaseForCaseMatchingForExamining",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DE_BONIS_NON
                                ),
                                Map.of(
                                    "completionMode", AUTO_COMPLETE_MODE,
                                    "taskType", EXAMINE_FIAT_WILL
                                )
                        )
                ),
                Arguments.of(
                        "boEscalateToRegistrar",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_PROBATE
                                ),
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DE_BONIS_NON
                                ),
                                Map.of(
                                    "completionMode", AUTO_COMPLETE_MODE,
                                    "taskType", EXAMINE_FIAT_WILL
                                )
                        )
                ),
                Arguments.of(
                        "boIssueGrantForCaseMatching",
                        List.of(
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DIGITAL_CASE_PROBATE
                                ),
                                Map.of(
                                        "completionMode", AUTO_COMPLETE_MODE,
                                        "taskType", EXAMINE_DE_BONIS_NON
                                ),
                                Map.of(
                                    "completionMode", AUTO_COMPLETE_MODE,
                                    "taskType", EXAMINE_FIAT_WILL
                                )
                        )
                ),
                Arguments.of(
                        "otherEventId",
                        Collections.emptyList()
                )
        );
    }

    @Test
    void if_this_test_fails_needs_updating_with_your_changes() {
        //The purpose of this test is to prevent adding new rows without being tested
        DmnDecisionTableImpl logic = (DmnDecisionTableImpl) decision.getDecisionLogic();
        assertThat(logic.getInputs().size(), is(1));
        assertThat(logic.getOutputs().size(), is(2));
        assertThat(logic.getRules().size(), is(9));
    }

    @ParameterizedTest(name = "event id: {0}")
    @MethodSource("scenarioProvider")
    void given_event_ids_should_evaluate_dmn(String eventId, List<Map<String, Object>> expectation) {

        VariableMap inputVariables = new VariableMapImpl();
        inputVariables.putValue("eventId", eventId);

        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);
        resultsMatchUsingTaskTypeKey(dmnDecisionTableResult.getResultList(), expectation);
    }

}
