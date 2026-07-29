package uk.gov.hmcts.probate.controller;

import org.apache.commons.io.IOUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.multipart.MultipartFile;
import uk.gov.hmcts.probate.config.properties.registries.RegistriesProperties;
import uk.gov.hmcts.probate.exception.BusinessValidationException;
import uk.gov.hmcts.probate.model.DocumentType;
import uk.gov.hmcts.probate.model.ccd.raw.DocumentLink;
import uk.gov.hmcts.probate.model.ccd.raw.request.CallbackRequest;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseData;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseDetails;
import uk.gov.hmcts.probate.model.ccd.raw.response.CallbackResponse;
import uk.gov.hmcts.probate.model.ccd.willlodgement.request.WillLodgementCallbackRequest;
import uk.gov.hmcts.probate.model.ccd.willlodgement.request.WillLodgementDetails;
import uk.gov.hmcts.probate.model.ccd.willlodgement.response.WillLodgementCallbackResponse;
import uk.gov.hmcts.probate.service.BulkPrintService;
import uk.gov.hmcts.probate.service.DocumentGeneratorService;
import uk.gov.hmcts.probate.service.DocumentValidation;
import uk.gov.hmcts.probate.service.EventValidationService;
import uk.gov.hmcts.probate.service.EvidenceUploadService;
import uk.gov.hmcts.probate.service.FeatureToggleService;
import uk.gov.hmcts.probate.service.NotificationService;
import uk.gov.hmcts.probate.service.RegistryDetailsService;
import uk.gov.hmcts.probate.service.ReprintService;
import uk.gov.hmcts.probate.service.CcdSupplementaryDataService;
import uk.gov.hmcts.probate.service.documentmanagement.DocumentManagementService;
import uk.gov.hmcts.probate.service.template.pdf.PDFManagementService;
import uk.gov.hmcts.probate.service.user.UserInfoService;
import uk.gov.hmcts.probate.transformer.CallbackResponseTransformer;
import uk.gov.hmcts.probate.transformer.CaseDataTransformer;
import uk.gov.hmcts.probate.transformer.DocumentTransformer;
import uk.gov.hmcts.probate.transformer.WillLodgementCallbackResponseTransformer;
import uk.gov.hmcts.probate.validator.BulkPrintValidationRule;
import uk.gov.hmcts.probate.validator.EmailAddressNotifyValidationRule;
import uk.gov.hmcts.probate.validator.RedeclarationSoTValidationRule;
import uk.gov.hmcts.reform.ccd.document.am.model.Document;
import uk.gov.hmcts.reform.ccd.document.am.model.UploadResponse;
import uk.gov.hmcts.reform.probate.model.idam.UserInfo;
import uk.gov.service.notify.NotificationClientException;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Optional;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItems;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.never;

import static uk.gov.hmcts.probate.model.ApplicationType.SOLICITOR;

@ExtendWith(SpringExtension.class)
class DocumentControllerUnitTest {

    private static final String VALID_FILE_NAME = "valid_file.png";

    @Mock
    private DocumentGeneratorService documentGeneratorService;
    @Mock
    private RegistryDetailsService registryDetailsService;
    @Mock
    private PDFManagementService pdfManagementService;
    @Mock
    private CallbackResponseTransformer callbackResponseTransformer;
    @Mock
    private CaseDataTransformer caseDataTransformer;
    @Mock
    private WillLodgementCallbackResponseTransformer willLodgementCallbackResponseTransformer;
    @Mock
    private NotificationService notificationService;
    @Mock
    private RegistriesProperties registriesProperties;
    @Mock
    private BulkPrintService bulkPrintService;
    @Mock
    private EventValidationService eventValidationService;
    @Mock
    private List<EmailAddressNotifyValidationRule> emailAddressNotifyValidationRules;
    @Mock
    private List<BulkPrintValidationRule> bulkPrintValidationRules;
    @Mock
    private RedeclarationSoTValidationRule redeclarationSoTValidationRule;
    @Mock
    private ReprintService reprintService;
    private DocumentValidation documentValidation;
    @Mock
    private DocumentManagementService documentManagementService;
    @Mock
    private EvidenceUploadService evidenceUploadService;
    @Mock
    private UserInfoService userInfoService;
    @Mock
    private FeatureToggleService featureToggleService;
    @Mock
    private DocumentTransformer documentTransformer;
    @Mock
    private CcdSupplementaryDataService ccdSupplementaryDataService;



    /// The object under test
    private DocumentController documentController;

    private static final String DUMMY_OAUTH_2_TOKEN = "oauth2Token";
    private static final String DUMMY_SAUTH_TOKEN = "serviceToken";
    private static final Optional<UserInfo> CASEWORKER_USERINFO = Optional.ofNullable(UserInfo.builder()
            .familyName("familyName")
            .givenName("givenname")
            .roles(Arrays.asList("caseworker-probate"))
            .build());

    @BeforeEach
    public void setUp() {
        MockitoAnnotations.initMocks(this);

        // ick
        DocumentValidation realDocumentValidation = new DocumentValidation(documentManagementService);
        ReflectionTestUtils.setField(realDocumentValidation,
            "allowedFileExtensions", ".pdf .jpeg .bmp .tif .tiff .png");
        ReflectionTestUtils.setField(realDocumentValidation,
            "allowedMimeTypes", "image/jpeg application/pdf image/tiff image/png image/bmp");
        documentValidation = spy(realDocumentValidation);

        documentController = new DocumentController(documentGeneratorService, registryDetailsService,
                    pdfManagementService, callbackResponseTransformer, caseDataTransformer,
            willLodgementCallbackResponseTransformer, notificationService, registriesProperties, bulkPrintService,
            eventValidationService, emailAddressNotifyValidationRules, bulkPrintValidationRules,
            redeclarationSoTValidationRule, reprintService, documentValidation, documentManagementService,
            evidenceUploadService, userInfoService, featureToggleService,documentTransformer,ccdSupplementaryDataService
        );
        doReturn(CASEWORKER_USERINFO).when(userInfoService).getCaseworkerInfo();
    }

    @Test
    void shouldReturnErrorIfThereAreNoFilesInTheRequest() {
        List<String> expectedResult = new ArrayList<>();
        expectedResult.add("Error: no files passed");

        List<String> actualResult = documentController.upload(DUMMY_OAUTH_2_TOKEN, DUMMY_SAUTH_TOKEN, null);
        assertThat(actualResult, equalTo(expectedResult));
    }

    @Test
    void shouldReturnErrorForEmptyFileList() {
        List<String> expectedResult = new ArrayList<>();
        expectedResult.add("Error: no files passed");

        List<String> actualResult = documentController.upload(DUMMY_OAUTH_2_TOKEN, DUMMY_SAUTH_TOKEN,
            Collections.emptyList());
        assertThat(actualResult, equalTo(expectedResult));
    }

    @Test
    void shouldReturnErrorForTooManyFiles() {
        List<String> expectedResult = new ArrayList<>();
        expectedResult.add("Error: too many files");

        MultipartFile file = mock(MultipartFile.class);
        List<MultipartFile> files = new ArrayList<>();
        for (int i = 1; i <= 11; i++) {
            files.add(file);
        }

        List<String> actualResult = documentController.upload(DUMMY_OAUTH_2_TOKEN, DUMMY_SAUTH_TOKEN, files);
        assertThat(actualResult, equalTo(expectedResult));

    }

    @Test
    void shouldReturnErrorForInvalidFileExtension() {
        List<String> expectedResult = new ArrayList<>();
        expectedResult.add("Error: invalid file type: testData");
        MockMultipartFile file = new MockMultipartFile("testData", "filename.txt", "text/plain", "some xml".getBytes());
        List<MultipartFile> files = new ArrayList<>();
        files.add(file);

        List<String> actualResult = documentController.upload(DUMMY_OAUTH_2_TOKEN, DUMMY_SAUTH_TOKEN, files);
        assertThat(actualResult, equalTo(expectedResult));
    }

    @Test
    void shouldUploadSuccessfully() throws IOException {
        final byte[] bytes = IOUtils.toByteArray(getClass().getResourceAsStream("/files/" + VALID_FILE_NAME));


        MockMultipartFile file = new MockMultipartFile(VALID_FILE_NAME, VALID_FILE_NAME, "image/jpeg", bytes);
        List<MultipartFile> files = new ArrayList<>();
        files.add(file);

        UploadResponse uploadResponseMock = mock(UploadResponse.class);
        Document.Links links = new Document.Links();
        Document.Link selfLink = new Document.Link();
        selfLink.href = "someHref";
        links.self = selfLink;
        Document document = Document.builder().links(links).build();
        when(uploadResponseMock.getDocuments()).thenReturn(Collections.singletonList(document));

        when(documentManagementService.uploadForCitizen(any(List.class), any(String.class), any(DocumentType.class)))
            .thenReturn(uploadResponseMock);

        List<String> actualResult = documentController.upload(DUMMY_OAUTH_2_TOKEN, DUMMY_SAUTH_TOKEN, files);
        assertThat(actualResult, hasItems());
    }

    @Test
    void shouldAlwaysUpdateLastEvidenceAddedDateAsCaseworker() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR)
            .build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData,null, 0L);
        mockCaseDetails.setState("BOCaseStopped");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);

        ResponseEntity<CallbackResponse> response = documentController
                .evidenceAdded(callbackRequest);
        ResponseEntity<CallbackResponse> response2 = documentController
                .evidenceAdded(callbackRequest);
        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));
        assertThat(response2.getStatusCode(), equalTo(HttpStatus.OK));

        verify(evidenceUploadService, times(2))
                .updateLastEvidenceAddedDate(mockCaseDetails);
    }

    @Test
    void shouldNotAddSentEmailWhenExceptionThrownInCaseworkerUploadEvent() throws NotificationClientException {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR)
                .build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData,null, 0L);
        mockCaseDetails.setState("BOCaseStopped");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);
        when(notificationService.sendStopResponseReceivedEmail(mockCaseDetails))
                .thenThrow(new NotificationClientException("Error sending email"));

        ResponseEntity<CallbackResponse> response = documentController
                .evidenceAdded(callbackRequest);

        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));
        verify(documentTransformer, times(0)).addDocument(any(), any(), any());
    }

    @Test
    void shouldReturnValidationErrorWhenExistingDocumentIsModified() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR).build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData, null, 0L);
        mockCaseDetails.setState("BOCaseStopped");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);
        when(featureToggleService.usePreventUpdatingExistingUploadedDocumentsFeatureToggleOn()).thenReturn(true);
        doThrow(new BusinessValidationException("validation error", "validation error"))
                .when(evidenceUploadService)
                .validateExistingUploadedDocuments(callbackRequest);

        ResponseEntity<CallbackResponse> response = documentController.evidenceAdded(callbackRequest);

        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));
        assertThat(response.getBody().getErrors(), contains("validation error"));
        verify(evidenceUploadService, never()).updateLastEvidenceAddedDate(mockCaseDetails);
        verify(documentTransformer, never()).addDocument(any(), any(), any());
    }

    @Test
    void shouldUpdateLastEvidenceAddedDateWhenStoppedAsRobot() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR)
                .build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData,null, 0L);
        mockCaseDetails.setState("BOCaseStopped");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);

        ResponseEntity<CallbackResponse> response = documentController
                .evidenceAddedRPARobot(callbackRequest);
        assertThat(mockCaseData.getDocumentUploadedAfterCaseStopped(), equalTo("Yes"));
        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));

        ResponseEntity<CallbackResponse> response2 = documentController
                .evidenceAddedRPARobot(callbackRequest);
        assertThat(response2.getStatusCode(), equalTo(HttpStatus.OK));

        verify(evidenceUploadService, times(1))
                .updateLastEvidenceAddedDate(mockCaseDetails);
    }

    @Test
    void shouldUpdateLastEvidenceAddedDateWhenOngoingAsRobot() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR)
                .build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData,null, 0L);
        mockCaseDetails.setState("BOExamining");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);

        ResponseEntity<CallbackResponse> response = documentController
                .evidenceAddedRPARobot(callbackRequest);
        ResponseEntity<CallbackResponse> response2 = documentController
                .evidenceAddedRPARobot(callbackRequest);

        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));
        assertThat(response2.getStatusCode(), equalTo(HttpStatus.OK));
        verify(evidenceUploadService, times(2))
                .updateLastEvidenceAddedDate(mockCaseDetails);
        verify(documentTransformer, times(2)).addDocument(any(), any(), any());
    }

    @Test
    void shouldNotAddSentEmailWhenExceptionThrownInRobotUploadEvent() throws NotificationClientException {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseData mockCaseData = CaseData.builder().applicationType(SOLICITOR)
                .build();
        CaseDetails mockCaseDetails = new CaseDetails(mockCaseData,null, 0L);
        mockCaseDetails.setState("BOExamining");
        when(callbackRequest.getCaseDetails()).thenReturn(mockCaseDetails);
        when(notificationService.sendStopResponseReceivedEmail(mockCaseDetails))
                .thenThrow(new NotificationClientException("Error sending email"));

        ResponseEntity<CallbackResponse> response = documentController
                .evidenceAddedRPARobot(callbackRequest);

        assertThat(response.getStatusCode(), equalTo(HttpStatus.OK));
        verify(documentTransformer, times(0)).addDocument(any(), any(), any());
    }

    @Test
    void shouldSetupDeleteDocumentsForGrant() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        ResponseEntity<CallbackResponse> response =
                documentController.setupForPermanentRemovalGrant(callbackRequest);
        verify(callbackResponseTransformer, times(1)).setupOriginalDocumentsForRemoval(callbackRequest);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldDeleteDocumentsForGrant() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        ResponseEntity<CallbackResponse> response =
                documentController.permanentlyDeleteRemovedGrant(callbackRequest);
        verify(documentGeneratorService, times(1)).permanentlyDeleteRemovedDocumentsForGrant(callbackRequest);
        verify(callbackResponseTransformer, times(1)).updateTaskList(callbackRequest, CASEWORKER_USERINFO);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldSetupDeleteDocumentsForWillLodgement() {
        WillLodgementCallbackRequest callbackRequest = mock(WillLodgementCallbackRequest.class);
        WillLodgementDetails caseDetailsMock = mock(WillLodgementDetails.class);
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        ResponseEntity<WillLodgementCallbackResponse> response =
                documentController.setupForPermanentRemovalWillLodgement(callbackRequest);
        verify(willLodgementCallbackResponseTransformer, times(1)).setupOriginalDocumentsForRemoval(callbackRequest);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldDeleteDocumentsForWillLodgement() {
        WillLodgementCallbackRequest callbackRequest = mock(WillLodgementCallbackRequest.class);
        WillLodgementDetails caseDetailsMock = mock(WillLodgementDetails.class);
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        ResponseEntity<WillLodgementCallbackResponse> response =
                documentController.permanentlyDeleteRemovedWillLodgement(callbackRequest);
        verify(documentGeneratorService, times(1)).permanentlyDeleteRemovedDocumentsForWillLodgement(callbackRequest);
        verify(willLodgementCallbackResponseTransformer, times(1)).transform(callbackRequest);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldTransformForCitizenHubResponse() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        CaseData mockCaseData = CaseData.builder()
                .build();
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);
        when(caseDetailsMock.getData()).thenReturn(mockCaseData);

        ResponseEntity<CallbackResponse> response =
                documentController.citizenHubResponse(callbackRequest);
        verify(callbackResponseTransformer, times(1)).transformCitizenHubResponse(callbackRequest);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldCallValidateSotForStartAmendLegalStatement() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        ResponseEntity<CallbackResponse> response = documentController.startAmendLegalStatement(callbackRequest);

        verify(redeclarationSoTValidationRule, times(1)).validate(caseDetailsMock);
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldSuccessfullyValidateAmendLegalStatementWhenFlagSetAndNoErrorReturned() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        CaseData caseDataMock = mock(CaseData.class);
        DocumentLink documentLinkMock = mock(DocumentLink.class);
        CallbackResponse callbackResponseMock = mock(CallbackResponse.class);

        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);
        when(caseDetailsMock.getData()).thenReturn(caseDataMock);
        when(caseDataMock.getAmendedLegalStatement()).thenReturn(documentLinkMock);

        when(featureToggleService.enableAmendLegalStatementFiletypeCheck()).thenReturn(true);
        doReturn(Optional.empty())
                .when(documentValidation)
                .validateUploadedDocumentIsType(any(), any(), any());

        when(callbackResponseTransformer.transformCase(any(), any()))
                .thenReturn(callbackResponseMock);

        ResponseEntity<CallbackResponse> response = documentController.validateAmendLegalStatement(callbackRequest);

        verify(documentValidation, times(1)).validateUploadedDocumentIsType(
                any(),
                any(),
                any());
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
        assertThat(response.getBody().getErrors().isEmpty(), is(true));
    }

    @Test
    void shouldFailToValidateAmendLegalStatementWhenFlagSetAndErrorReturned() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        CaseData caseDataMock = mock(CaseData.class);
        DocumentLink documentLinkMock = mock(DocumentLink.class);
        String error = "ERROR";
        CallbackResponse callbackResponseMock = mock(CallbackResponse.class);

        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);
        when(caseDetailsMock.getData()).thenReturn(caseDataMock);
        when(caseDataMock.getAmendedLegalStatement()).thenReturn(documentLinkMock);

        when(featureToggleService.enableAmendLegalStatementFiletypeCheck()).thenReturn(true);
        doReturn(Optional.of(error))
                .when(documentValidation)
                .validateUploadedDocumentIsType(any(), any(), any());

        when(callbackResponseTransformer.transformCase(any(), any()))
                .thenReturn(callbackResponseMock);

        ResponseEntity<CallbackResponse> response = documentController.validateAmendLegalStatement(callbackRequest);

        verify(documentValidation, times(1)).validateUploadedDocumentIsType(
                any(),
                any(),
                any());
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
        assertThat(response.getBody().getErrors().isEmpty(), is(false));
        assertThat(response.getBody().getErrors(), contains(error));
    }

    @Test
    void shouldNotCallValidateFileTypeForValidateAmendLegalStatementWhenFlagUnset() {
        CallbackRequest callbackRequest = mock(CallbackRequest.class);
        CaseDetails caseDetailsMock = mock(CaseDetails.class);
        CaseData caseDataMock = mock(CaseData.class);

        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);
        when(caseDetailsMock.getData()).thenReturn(caseDataMock);

        when(featureToggleService.enableAmendLegalStatementFiletypeCheck()).thenReturn(false);

        ResponseEntity<CallbackResponse> response = documentController.validateAmendLegalStatement(callbackRequest);

        verify(documentValidation, never()).validateUploadedDocumentIsType(
                any(),
                any(),
                any());
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldSubmitSupplementaryData() {
        WillLodgementCallbackRequest callbackRequest = mock(WillLodgementCallbackRequest.class);
        WillLodgementDetails caseDetailsMock = mock(WillLodgementDetails.class);

        when(callbackRequest.getCaseDetails())
                .thenReturn(caseDetailsMock);

        when(callbackRequest.getCaseDetails()).thenReturn(caseDetailsMock);

        when(caseDetailsMock.getId()).thenReturn(1000L);
        ResponseEntity<WillLodgementCallbackResponse> response = documentController
                .setWillLodgementSupplementaryData(callbackRequest);
        verify(ccdSupplementaryDataService).submitSupplementaryDataToCcd(anyString());
        assertThat(response.getStatusCode(), is(HttpStatus.OK));
    }

    @Test
    void shouldThrowExceptionWhenCaseDetailsIsNull() {
        WillLodgementCallbackRequest callbackRequest = mock(WillLodgementCallbackRequest.class);

        when(callbackRequest.getCaseDetails())
                .thenReturn(null);
        assertThrows(
                NullPointerException.class,
                () -> documentController.setWillLodgementSupplementaryData(callbackRequest)
        );
        verifyNoInteractions(ccdSupplementaryDataService);
    }
}
