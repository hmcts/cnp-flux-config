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
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_ADMON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DE_BONIS_NON;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_DIGITAL_CASE_PROBATE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.EXAMINE_FIAT_WILL;
import static uk.gov.hmcts.probate.dmnutils.CamundaVerifier.resultsMatchUsingNameKey;

class CamundaTaskWaInitiationTest extends DmnDecisionTableBaseUnitTest {

    @BeforeAll
    public static void initialization() {
        CURRENT_DMN_DECISION_TABLE = WA_TASK_INITIATION_PROBATE;
    }

    private static Map<String, Map<String, Object>> additionalData(boolean evidenceHandled,
                                                                   String caseType,
                                                                   boolean caseHandedOffToLegacySite,
                                                                   List<Map<String,Object>> boHandoffReasonList) {
        return Map.of(
                "Data", Map.of(
                        "evidenceHandled", evidenceHandled,
                        "caseType", caseType,
                        "caseHandedOffToLegacySite", caseHandedOffToLegacySite,
                        "boHandoffReasonList", boHandoffReasonList
                )
        );
    }

    private static Map<String, Map<String, Object>> additionalDataNoHandOffList() {
        return Map.of(
                "Data", Map.of(
                        "evidenceHandled", false,
                        "caseType", "",
                        "caseHandedOffToLegacySite", true
                )
        );
    }

    private static final List<Map<String,Object>> handOffReasonListFiatWill = List.of(
            Map.of(
                    "id", "df3be732-2172-49da-80fe-cad8586e4928",
                    "value", Map.of("caseHandoffReason", "FiatWill")
            ),
            Map.of(
                    "id", "df3be732-2172-49da-80fe-cad8586e4928",
                    "value", Map.of("caseHandoffReason", "OtherReason")
            )
    );

    private static final List<Map<String,Object>> handOffReasonListDeBonisNon = List.of(
            Map.of(
                    "id", "df3be732-2172-49da-80fe-cad8586e4928",
                    "value", Map.of("caseHandoffReason", "DeBonisNon")
            ),
            Map.of(
                    "id", "df3be732-2172-49da-80fe-cad8586e4928",
                    "value", Map.of("caseHandoffReason", "OtherReason")
            )
    );

    private static final List<Map<String,Object>> handOffReasonListOtherReason = List.of(
            Map.of(
                    "id", "df3be732-2172-49da-80fe-cad8586e4928",
                    "value", Map.of("caseHandoffReason", "OtherReason")
            )
    );

    static Stream<Arguments> probateScenarios() {

        Map<String,Object> examineDigitalCaseProbateTaskAttributes = Map.of(
                "taskId", EXAMINE_DIGITAL_CASE_PROBATE,
                "name", "Examine Digital Case - Probate",
                "processCategories", "case progression"
        );

        return Stream.of(
                Arguments.of(
                        "someOtherEventId",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boAmendCaseDetailsForAwaitingDocumentation",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                  "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "gop", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "gop", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "gop", false, Collections.emptyList()),
                        List.of(examineDigitalCaseProbateTaskAttributes)
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(true, "gop", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "other", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                )
        );
    }

    static Stream<Arguments> admonScenarios() {

        Map<String,Object> examineDigitalCaseAdmonTaskAttributes = Map.of(
                "taskId", EXAMINE_DIGITAL_CASE_ADMON,
                "name", "Examine Digital Case - Admon",
                "processCategories", "case progression"
        );

        return Stream.of(
                Arguments.of(
                        "someOtherEventId",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "CasePrinted",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "attachScannedDocs",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "applyforGrantPaperApplicationMan",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, Collections.emptyList()),
                        List.of(examineDigitalCaseAdmonTaskAttributes)
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(true, "admonWill", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "other", false, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "admonWill", false, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "createCaseFromBulkScan",
                        "CasePrinted",
                        additionalData(false, "admonWill", true, handOffReasonListOtherReason),
                        Collections.emptyList()
                )
        );
    }

    static Stream<Arguments> deBonisNonScenarios() {

        Map<String,Object> examineDeBonisNonTaskAttributes = Map.of(
                "taskId", EXAMINE_DE_BONIS_NON,
                "name", "Examine - De Bonis Non",
                "processCategories", "case progression"
        );

        return Stream.of(
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListDeBonisNon),
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListDeBonisNon),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalDataNoHandOffList(),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        null,
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListDeBonisNon),
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListDeBonisNon),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalDataNoHandOffList(),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListDeBonisNon),
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListDeBonisNon),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListDeBonisNon),
                        List.of(examineDeBonisNonTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListDeBonisNon),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalDataNoHandOffList(),
                        Collections.emptyList()
                )
        );
    }

    static Stream<Arguments> fiatWillScenarios() {

        Map<String,Object> examineFiatWillTaskAttributes = Map.of(
                "taskId", EXAMINE_FIAT_WILL,
                "name", "Examine - Fiat Will",
                "processCategories", "case progression"
        );

        return Stream.of(
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListFiatWill),
                        List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListFiatWill),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "handleEvidence",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListFiatWill),
                        List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListFiatWill),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "changeState",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListFiatWill),
                        List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListFiatWill),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "resolveCWEscalation",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListFiatWill),
                        List.of(examineFiatWillTaskAttributes)
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",false, handOffReasonListFiatWill),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, handOffReasonListOtherReason),
                        Collections.emptyList()
                ),
                Arguments.of(
                        "boResolveStop",
                        "BOReadyToIssue",
                        additionalData(false, "",true, Collections.emptyList()),
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
                        additionalDataNoHandOffList(),
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
        assertThat(logic.getRules().size(), is(5));
    }

    @ParameterizedTest(name = "event id: {0} post event state: {1} evidenceHandled: {2} caseType: {3}")
    @MethodSource({"probateScenarios","admonScenarios","deBonisNonScenarios", "fiatWillScenarios"})
    void given_multiple_event_ids_should_evaluate_dmn_for_probate_scenarios(String eventId,
                                                      String postEventState,
                                                      Map<String, Object> additionalData,
                                                      List<Map<String, Object>> expectation) {
        VariableMap inputVariables = new VariableMapImpl();
        inputVariables.putValue("eventId", eventId);
        inputVariables.putValue("postEventState", postEventState);
        if (additionalData != null) {
            inputVariables.putValue("additionalData", additionalData);
        }
        DmnDecisionTableResult dmnDecisionTableResult = evaluateDmnTable(inputVariables);
        resultsMatchUsingNameKey(dmnDecisionTableResult.getResultList(), expectation);
    }
}
