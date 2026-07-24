package uk.gov.hmcts.probate.dmn;

import org.camunda.bpm.dmn.engine.DmnDecisionTableResult;
import org.camunda.bpm.dmn.engine.impl.DmnDecisionTableImpl;
import org.camunda.bpm.dmn.engine.impl.DmnDecisionTableInputImpl;
import org.camunda.bpm.dmn.engine.impl.DmnDecisionTableOutputImpl;
import org.camunda.bpm.engine.variable.VariableMap;
import org.camunda.bpm.engine.variable.impl.VariableMapImpl;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import uk.gov.hmcts.probate.DmnDecisionTableBaseUnitTest;

import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import java.util.stream.Stream;

import static java.util.Arrays.asList;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;
import static uk.gov.hmcts.probate.DmnDecisionTable.WA_TASK_PERMISSIONS_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DE_BONIS_NON_SKILL_CODE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_ADMON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_INTESTACY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.FIAT_WILL_SKILL_CODE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.PROBATE_EXAMINE_SKILL_CODE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ROLE_CATEGORY_CTSC;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.resultsMatchUsingNameKey;

class CamundaTaskWaPermissionTest extends DmnDecisionTableBaseUnitTest {

    private static final String DUMMY_CASE_DATA = "someCaseData";

    private static final List<Map<String, Object>> ctscDefaultPermissions = List.of(
            Map.of(
                    "name", "ctsc",
                    "value", "Read,Own,Claim,Unclaim,Manage,Complete",
                    "roleCategory", ROLE_CATEGORY_CTSC,
                    "assignmentPriority", 1,
                    "autoAssignable", false
                )
        );

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_PERMISSIONS_PROBATE;
    }

    static Stream<Arguments> scenarioProvider() {
        return Stream.of(
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_PROBATE,
                        DUMMY_CASE_DATA,
                        getCtscExaminePermissions(PROBATE_EXAMINE_SKILL_CODE)
                ),
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_ADMON,
                        DUMMY_CASE_DATA,
                        ctscDefaultPermissions
                ),
                Arguments.of(
                        EXAMINE_DIGITAL_CASE_INTESTACY,
                        DUMMY_CASE_DATA,
                        ctscDefaultPermissions
                ),
                Arguments.of(
                        EXAMINE_DE_BONIS_NON,
                        DUMMY_CASE_DATA,
                    getCtscExaminePermissions(DE_BONIS_NON_SKILL_CODE)

                ),
                Arguments.of(
                    EXAMINE_FIAT_WILL,
                    DUMMY_CASE_DATA,
                    getCtscExaminePermissions(FIAT_WILL_SKILL_CODE)
                )
        );
    }

    @Test
    void if_this_test_fails_needs_updating_with_your_changes() {
        //The purpose of this test is to prevent adding new rows without being tested
        DmnDecisionTableImpl logic = (DmnDecisionTableImpl) decision.getDecisionLogic();

        List<String> inputColumnIds = asList("taskType", "case");
        //Inputs
        assertThat(logic.getInputs().size(), is(2));
        assertThatInputContainInOrder(inputColumnIds, logic.getInputs());
        //Outputs
        List<String> outputColumnIds = asList(
                "caseAccessCategory",
                "name",
                "value",
                "roleCategory",
                "authorisations",
                "assignmentPriority",
                "autoAssignable"
        );
        assertThat(logic.getOutputs().size(), is(7));
        assertThatOutputContainInOrder(outputColumnIds, logic.getOutputs());
        //Rules
        assertThat(logic.getRules().size(), is(8));
    }

    @ParameterizedTest(name = "task type: {0} case data: {1}")
    @MethodSource("scenarioProvider")
    void given_inputs_should_evaluate_dmn_and_return_expected_rules(String taskType,
                                                                                String caseData,
                                                                                List<Map<String, Object>> expectation) {
        VariableMap inputVariables = new VariableMapImpl();
        inputVariables.putValue("taskAttributes", Map.of("taskType", taskType));
        inputVariables.putValue("case", caseData);

        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);

        resultsMatchUsingNameKey(dmnDecisionTableResult.getResultList(), expectation);
    }

    private void assertThatInputContainInOrder(List<String> inputColumnIds, List<DmnDecisionTableInputImpl> inputs) {
        IntStream.range(0, inputs.size())
                .forEach(i -> assertThat(inputs.get(i).getInputVariable(), is(inputColumnIds.get(i))));
    }

    private void assertThatOutputContainInOrder(List<String> outputColumnIds, List<DmnDecisionTableOutputImpl> output) {
        IntStream.range(0, output.size())
                .forEach(i -> assertThat(output.get(i).getOutputName(), is(outputColumnIds.get(i))));
    }

    private static List<Map<String, Object>> getCtscExaminePermissions(String skillCode) {
        return List.of(
                Map.of(
                        "name", "ctsc",
                        "value", "Read,Own,Claim,Unclaim,Assign,Unassign",
                        "roleCategory", ROLE_CATEGORY_CTSC,
                        "assignmentPriority", 1,
                        "autoAssignable", false,
                        "authorisations", skillCode
                ),
                Map.of(
                        "name", "ctsc-team-leader",
                        "value", "Read,Own,Claim,Unclaim,Manage,Complete,Cancel,Assign,Unassign",
                        "roleCategory", ROLE_CATEGORY_CTSC,
                        "assignmentPriority", 1,
                        "autoAssignable", false
                )
       );
    }

}
