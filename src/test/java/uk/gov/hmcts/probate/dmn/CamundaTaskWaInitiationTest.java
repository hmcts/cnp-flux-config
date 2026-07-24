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
import static uk.gov.hmcts.probate.DmnDecisionTable.WA_TASK_INITIATION_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.mapAdditionalData;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.resultsMatchUsingNameKey;

class CamundaTaskWaInitiationTest extends DmnDecisionTableBaseUnitTest {

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_INITIATION_PROBATE;
    }

    static Stream<Arguments> scenarioProvider() {
        Map<String,Object> examineDigitalCaseProbateTaskAttributes = Map.of(
                "taskId", EXAMINE_DIGITAL_CASE_PROBATE,
                "name", "Examine Digital Case - Probate",
                "processCategories", "case progression"
        );

        Map<String,Object> examineDeBonisNonTaskAttributes = Map.of(
                "taskId", EXAMINE_DE_BONIS_NON,
                "name", "Examine - De Bonis Non",
                "processCategories", "case progression"
        );

        Map<String,Object> examineFiatWillTaskAttributes = Map.of(
            "taskId", EXAMINE_FIAT_WILL,
            "name", "Examine - Fiat Will",
            "processCategories", "case progression"
        );

        Map<String, Object> additionalData = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "boHandoffReasonList" : []
                  }
                }""");

        Map<String, Object> additionalDataEvidenceHandledTrue = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "true",
                  "caseType" : "gop",
                  "boHandoffReasonList" : []
                  }
                }""");

        Map<String, Object> additionalDataCaseTypeOther = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "other",
                  "boHandoffReasonList" : []
                  }
                }""");

        Map<String, Object> additionalDataHandOffListNotEmpty = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "boHandoffReasonList" : [1]
                  }
                }""");

        Map<String, Object> additionalDataHandOffListDeBonisNon = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "caseHandedOffToLegacySite" : "true",
                  "boHandoffReasonList" : [
                    {
                      "id": "df3be732-2172-49da-80fe-cad8586e4928",
                      "value": {
                        "caseHandoffReason": "DeBonisNon"
                      }
                    },
                    {
                      "id": "df3be732-2172-49da-80fe-cad8586e4928",
                      "value": {
                        "caseHandoffReason": "OtherReason"
                      }
                    }
                  ]
                  }
                }""");

        Map<String, Object> additionalDataHandOffListLegacySiteNo = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "caseHandedOffToLegacySite" : "false",
                  "boHandoffReasonList" : [
                    {
                      "id": "df3be732-2172-49da-80fe-cad8586e4928",
                      "value": {
                        "caseHandoffReason": "DeBonisNon"
                      }
                    },
                    {
                      "id": "df3be732-2172-49da-80fe-cad8586e4928",
                      "value": {
                        "caseHandoffReason": "OtherReason"
                      }
                    }
                  ]
                  }
                }""");

        Map<String, Object> additionalDataHandOffListFiatWill = mapAdditionalData("{\n"
            + "  \"Data\":{\n"
            + "  \"evidenceHandled\" : \"" + false + "\",\n"
            + "  \"caseType\" : \"" + "gop" + "\",\n"
            + "  \"caseHandedOffToLegacySite\" : \"" + true + "\",\n"
            + "  \"boHandoffReasonList\" : [\n"
            + "    {\n"
            + "      \"id\": \"df3be732-2172-49da-80fe-cad8586e4928\",\n"
            + "      \"value\": {\n"
            + "        \"caseHandoffReason\": \"FiatWill\"\n"
            + "      }\n"
            + "    },\n"
            + "    {\n"
            + "      \"id\": \"df3be732-2172-49da-80fe-cad8586e4928\",\n"
            + "      \"value\": {\n"
            + "        \"caseHandoffReason\": \"OtherReason\"\n"
            + "      }\n"
            + "    }\n"
            + "  ]\n"
            + "  }\n"
            + "}");

        Map<String, Object> additionalDataHandOffListOtherReason = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "caseHandedOffToLegacySite" : "true",
                  "boHandoffReasonList" : [
                    {
                      "id": "df3be732-2172-49da-80fe-cad8586e4928",
                      "value": {
                        "caseHandoffReason": "OtherReason"
                      }
                    }
                  ]
                  }
                }""");

        Map<String, Object> additionalDataHandOffListEmpty = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "caseHandedOffToLegacySite" : "true",
                  "boHandoffReasonList" : []
                  }
                }""");

        Map<String, Object> additionalDataHandOffListMissing = mapAdditionalData("""
                {
                  "Data":{
                  "evidenceHandled" : "false",
                  "caseType" : "gop",
                  "caseHandedOffToLegacySite" : "true",
                  }
                }""");

        Map<String, Object> additionalDataEmpty = mapAdditionalData("""
                {
                  "Data":{
                  }
                }""");

        return Stream.of(
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "someOtherEventId",
                        "CasePrinted",
                        additionalData,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                  "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData,
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalDataEvidenceHandledTrue,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalDataCaseTypeOther,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalDataHandOffListNotEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataHandOffListDeBonisNon,
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                    "handleEvidence",
                    "BOReadyToIssue",
                    additionalDataHandOffListFiatWill,
                    List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataHandOffListLegacySiteNo,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataHandOffListOtherReason,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataHandOffListEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataHandOffListMissing,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataHandOffListDeBonisNon,
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                    "boResolveStop",
                    "BOReadyToIssue",
                    additionalDataHandOffListFiatWill,
                    List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataHandOffListLegacySiteNo,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataHandOffListOtherReason,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataHandOffListEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataHandOffListMissing,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataHandOffListDeBonisNon,
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                    "resolveCWEscalation",
                    "BOReadyToIssue",
                    additionalDataHandOffListFiatWill,
                    List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataHandOffListLegacySiteNo,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataHandOffListOtherReason,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataHandOffListEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataHandOffListMissing,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalDataEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataHandOffListDeBonisNon,
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                    "changeState",
                    "BOReadyToIssue",
                    additionalDataHandOffListFiatWill,
                    List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataHandOffListLegacySiteNo,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataHandOffListOtherReason,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataHandOffListEmpty,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataHandOffListMissing,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataEmpty,
                        Collections.emptyList()
                )
        );
    }

    @Test
    void if_this_test_fails_needs_updating_with_your_changes() {
        //The purpose of this test is to prevent adding new rows without being tested
        DmnDecisionTableImpl logic = (DmnDecisionTableImpl) decision.getDecisionLogic();
        assertThat(logic.getInputs().size(), is(7));
        assertThat(logic.getOutputs().size(), is(4));
        assertThat(logic.getRules().size(), is(12));
    }

    @ParameterizedTest(name = "event id: {0} post event state: {1} evidenceHandled: {2} caseType: {3}")
    @MethodSource("scenarioProvider")
    void given_multiple_event_ids_should_evaluate_dmn(String eventId,
                                                      String postEventState,
                                                      Map<String, Object> additionalData,
                                                      List<Map<String, Object>> expectation) {
        VariableMap inputVariables = new VariableMapImpl();
        inputVariables.putValue("eventId", eventId);
        inputVariables.putValue("postEventState", postEventState);
        if (additionalData != null) {
            inputVariables.putAll(additionalData);
        }
        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);
        resultsMatchUsingNameKey(dmnDecisionTableResult.getResultList(), expectation);
    }
}
