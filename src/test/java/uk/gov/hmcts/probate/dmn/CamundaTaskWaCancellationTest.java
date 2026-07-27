package uk.gov.hmcts.probate.dmn;

import org.camunda.bpm.dmn.engine.DmnDecisionTableResult;
import org.camunda.bpm.dmn.engine.impl.DmnDecisionTableImpl;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.impl.VariableMapImpl;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ArgumentsSource;
import uk.gov.hmcts.probate.DmnDecisionTableBaseUnitTest;
import uk.gov.hmcts.probate.dmnutils.CancellationScenarioBuilder;

import java.util.List;
import java.util.Map;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;
import static uk.gov.hmcts.probate.DmnDecisionTable.WA_TASK_CANCELLATION_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.READY_TO_ISSUE_STATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.CASE_PRINTED_STATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.BO_CASE_CLOSED;


class CamundaTaskWaCancellationTest extends DmnDecisionTableBaseUnitTest {

    private static final String WITHDRAW_APPLICATION_EVENT_ID_CASE_PRINTED = "boWithdrawApplicationForCasePrinted";
    private static final String WITHDRAW_APPLICATION_EVENT_ID_READY_TO_ISSUE = "boWithdrawApplicationForReadyToIssue";

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_CANCELLATION_PROBATE;
    }

    @Test
    void if_this_test_fails_needs_updating_with_your_changes() {
        //The purpose of this test is to prevent adding new rows without being tested
        DmnDecisionTableImpl logic = (DmnDecisionTableImpl) decision.getDecisionLogic();
        assertThat(logic.getInputs().size(), is(3));
        assertThat(logic.getOutputs().size(), is(4));
        assertThat(logic.getRules().size(), is(2));
    }

    @ParameterizedTest(name = "from state: {0}, event id: {1}, state: {2}")
    @ArgumentsSource(CancellationScenarioBuilder.class)
    void given_multiple_event_ids_should_evaluate_dmn(Map<String, String> cancellationProperties) {

        VariableMap inputVariables = new VariableMapImpl();
        inputVariables = putAllCancellationProperties(inputVariables, cancellationProperties);

        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);
        List<Map<String, Object>> dmnResultList = dmnDecisionTableResult.getResultList();

        // can be modified to use a switch case in future
        if (cancellationProperties.containsValue(WITHDRAW_APPLICATION_EVENT_ID_CASE_PRINTED)
                || cancellationProperties.containsValue(WITHDRAW_APPLICATION_EVENT_ID_READY_TO_ISSUE)) {
            testBoWithdrawApplicationEvent(dmnResultList, cancellationProperties);
        } else {
            Assertions.assertEquals(0, dmnResultList.size());
        }

    }

    private VariableMap putAllCancellationProperties(VariableMap inputVariables,
                                                     Map<String, String> cancellationProperties) {
        if (cancellationProperties != null && !cancellationProperties.isEmpty()) {
            inputVariables.putValue("event", cancellationProperties.get("event"));
            inputVariables.putValue("fromState", cancellationProperties.get("fromState"));
            inputVariables.putValue("state", cancellationProperties.get("state"));
            if (cancellationProperties.size() == 3) {
                return inputVariables;
            }
            inputVariables.putValue("action", cancellationProperties.get("action"));
            // For when it is a 'cancel all' type of task cancellation
            if (cancellationProperties.containsKey("processCategories")) {
                inputVariables.putValue("processCategories",
                        cancellationProperties.get("processCategories"));
            }
        }
        return inputVariables;
    }

    private void testBoWithdrawApplicationEvent(List<Map<String, Object>> dmnResultList,
                                                Map<String, String> cancellationProperties) {
        if ((cancellationProperties.containsValue(CASE_PRINTED_STATE)
                || cancellationProperties.containsValue(READY_TO_ISSUE_STATE))
                && cancellationProperties.containsValue(BO_CASE_CLOSED)) {
            Assertions.assertEquals(1, dmnResultList.size());
            Assertions.assertEquals(dmnResultList.getFirst().get("processCategories"),
                    cancellationProperties.get("processCategories"));
            Assertions.assertEquals(dmnResultList.getFirst().get("action"),
                    cancellationProperties.get("action"));
        } else {
            Assertions.assertEquals(0, dmnResultList.size());
        }
    }
}
