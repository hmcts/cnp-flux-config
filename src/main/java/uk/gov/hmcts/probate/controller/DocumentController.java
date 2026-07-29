package uk.gov.hmcts.probate.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import uk.gov.hmcts.probate.config.properties.registries.RegistriesProperties;
import uk.gov.hmcts.probate.config.properties.registries.Registry;
import uk.gov.hmcts.probate.exception.BusinessValidationException;
import uk.gov.hmcts.probate.model.ApplicationType;
import uk.gov.hmcts.probate.model.DocumentIssueType;
import uk.gov.hmcts.probate.model.DocumentStatus;
import uk.gov.hmcts.probate.model.DocumentType;
import uk.gov.hmcts.probate.model.State;
import uk.gov.hmcts.probate.model.ccd.raw.Document;
import uk.gov.hmcts.probate.model.ccd.raw.DocumentLink;
import uk.gov.hmcts.probate.model.ccd.raw.request.CallbackRequest;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseData;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseDetails;
import uk.gov.hmcts.probate.model.ccd.raw.response.CallbackResponse;
import uk.gov.hmcts.probate.model.ccd.willlodgement.request.WillLodgementCallbackRequest;
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
import uk.gov.hmcts.reform.ccd.document.am.model.UploadResponse;
import uk.gov.hmcts.reform.probate.model.idam.UserInfo;
import uk.gov.hmcts.reform.sendletter.api.SendLetterResponse;
import uk.gov.service.notify.NotificationClientException;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.function.Function;

import static org.springframework.http.MediaType.APPLICATION_JSON_VALUE;
import static uk.gov.hmcts.probate.model.ApplicationType.SOLICITOR;
import static uk.gov.hmcts.probate.model.Constants.LATEST_SCHEMA_VERSION;
import static uk.gov.hmcts.probate.model.Constants.NEWCASTLE;
import static uk.gov.hmcts.probate.model.Constants.YES;
import static uk.gov.hmcts.probate.model.DocumentCaseType.INTESTACY;
import static uk.gov.hmcts.probate.model.DocumentType.WILL_LODGEMENT_DEPOSIT_RECEIPT;
import static uk.gov.hmcts.probate.model.State.GRANT_ISSUED;
import static uk.gov.hmcts.probate.model.State.GRANT_ISSUED_INTESTACY;
import static uk.gov.hmcts.probate.model.StateConstants.STATE_BO_CASE_STOPPED;
import static uk.gov.hmcts.probate.model.StateConstants.STATE_BO_GRANT_ISSUED;
import static uk.gov.hmcts.reform.probate.model.cases.grantofrepresentation.GrantType.Constants.EDGE_CASE_NAME;
import static uk.gov.hmcts.reform.probate.model.cases.grantofrepresentation.GrantType.Constants.GRANT_OF_PROBATE_NAME;

@Slf4j
@RequiredArgsConstructor
@RequestMapping(value = "/document", consumes = APPLICATION_JSON_VALUE, produces = APPLICATION_JSON_VALUE)
@RestController
public class DocumentController {

    private final DocumentGeneratorService documentGeneratorService;
    private final RegistryDetailsService registryDetailsService;
    private final PDFManagementService pdfManagementService;
    private final CallbackResponseTransformer callbackResponseTransformer;
    private final CaseDataTransformer caseDataTransformer;
    private final WillLodgementCallbackResponseTransformer willLodgementCallbackResponseTransformer;
    private final NotificationService notificationService;
    private final RegistriesProperties registriesProperties;
    private final BulkPrintService bulkPrintService;
    private final EventValidationService eventValidationService;
    private final List<EmailAddressNotifyValidationRule> emailAddressNotifyValidationRules;
    private final List<BulkPrintValidationRule> bulkPrintValidationRules;
    private final RedeclarationSoTValidationRule redeclarationSoTValidationRule;
    private final ReprintService reprintService;
    private final DocumentValidation documentValidation;
    private final DocumentManagementService documentManagementService;
    private final EvidenceUploadService evidenceUploadService;
    private final UserInfoService userInfoService;
    private final FeatureToggleService featureToggleService;
    private final DocumentTransformer documentTransformer;
    private final CcdSupplementaryDataService ccdSupplementaryDataService;

    private Function<String, State> grantState = (String caseType) -> {
        if (caseType.equals(INTESTACY.getCaseType())) {
            return GRANT_ISSUED_INTESTACY;
        }
        return GRANT_ISSUED;
    };

    @PostMapping(path = "/assembleLetter", consumes = APPLICATION_JSON_VALUE, produces = {APPLICATION_JSON_VALUE})
    public ResponseEntity<CallbackResponse> assembleLetter(
        @RequestBody CallbackRequest callbackRequest,
        BindingResult bindingResult) {
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        CallbackResponse response = callbackResponseTransformer.transformCaseForLetter(callbackRequest, caseworkerInfo);

        return ResponseEntity.ok(response);

    }

    @PostMapping(path = "/previewLetter", consumes = APPLICATION_JSON_VALUE, produces = {APPLICATION_JSON_VALUE})
    public ResponseEntity<CallbackResponse> previewLetter(
        @RequestBody CallbackRequest callbackRequest) {

        Document letterPreview = documentGeneratorService.generateLetter(callbackRequest, false);

        CallbackResponse response =
            callbackResponseTransformer.transformCaseForLetterPreview(callbackRequest, letterPreview);

        return ResponseEntity.ok(response);
    }

    @PostMapping(path = "/generateLetter", consumes = APPLICATION_JSON_VALUE, produces = {APPLICATION_JSON_VALUE})
    public ResponseEntity<CallbackResponse> generateLetter(
        @RequestBody CallbackRequest callbackRequest) {
        CaseData caseData = callbackRequest.getCaseDetails().getData();
        String letterId = null;

        List<Document> documents = new ArrayList<>();
        Document letter = documentGeneratorService.generateLetter(callbackRequest, true);
        Document coversheet = documentGeneratorService.generateCoversheet(callbackRequest);

        documents.add(letter);
        documents.add(coversheet);

        if (caseData.isBoAssembleLetterSendToBulkPrintRequested()) {
            letterId = bulkPrintService.optionallySendToBulkPrint(callbackRequest, coversheet,
                letter, true);
        }
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        CallbackResponse response =
            callbackResponseTransformer.transformCaseForLetter(callbackRequest, documents, letterId, caseworkerInfo);

        return ResponseEntity.ok(response);
    }


    @PostMapping(path = "/generate-grant-draft", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> generateGrantDraft(@RequestBody CallbackRequest callbackRequest) {
        registryDetailsService.getRegistryDetails(callbackRequest.getCaseDetails());
        Document document =
            documentGeneratorService.getDocument(callbackRequest, DocumentStatus.PREVIEW, DocumentIssueType.GRANT);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(callbackResponseTransformer.addDocuments(callbackRequest,
            Arrays.asList(document), null, null, caseworkerInfo));
    }

    @PostMapping(path = "/generate-grant", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> generateGrant(
        @Validated({BulkPrintValidationRule.class})
        @RequestBody CallbackRequest callbackRequest)
        throws NotificationClientException {

        CaseDetails caseDetails = callbackRequest.getCaseDetails();
        @Valid CaseData caseData = caseDetails.getData();

        registryDetailsService.getRegistryDetails(caseDetails);
        CallbackResponse callbackResponse = CallbackResponse.builder().errors(new ArrayList<>()).build();

        Document digitalGrantDocument = documentGeneratorService.getDocument(callbackRequest, DocumentStatus.FINAL,
            DocumentIssueType.GRANT);

        Document coverSheet = pdfManagementService.generateAndUpload(callbackRequest, DocumentType.GRANT_COVER);
        log.info("Generated and Uploaded cover document with template {} for the case id {}",
            DocumentType.GRANT_COVER.getTemplateName(), callbackRequest.getCaseDetails().getId().toString());

        String letterId = null;
        String pdfSize = null;
        if (caseData.isSendForBulkPrintingRequested() && !EDGE_CASE_NAME.equals(caseData.getCaseType())) {
            SendLetterResponse response =
                bulkPrintService.sendToBulkPrintForGrant(callbackRequest, digitalGrantDocument, coverSheet);
            letterId = response != null
                ? response.letterId.toString()
                : null;
            callbackResponse = eventValidationService.validateBulkPrintResponse(letterId, bulkPrintValidationRules);

            pdfSize = getPdfSize(caseData);
        }
        if (!callbackResponse.getErrors().isEmpty()) {
            return ResponseEntity.ok(callbackResponse);
        }

        List<Document> documents = new ArrayList<>();
        documents.add(digitalGrantDocument);
        documents.add(coverSheet);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        if (caseData.isGrantIssuedEmailNotificationRequested()) {
            callbackResponse =
                eventValidationService.validateEmailRequest(callbackRequest, emailAddressNotifyValidationRules);
            if (callbackResponse.getErrors().isEmpty()) {
                Document grantIssuedSentEmail =
                    notificationService.sendEmail(grantState.apply(caseData.getCaseType()), caseDetails);
                documents.add(grantIssuedSentEmail);
            } else {
                return ResponseEntity.ok(callbackResponse);
            }

        }
        if (caseData.getOutsideUKGrantCopies() != null && caseData.getOutsideUKGrantCopies() > 0) {
            documents.add(notificationService.sendSealedAndCertifiedEmail(caseDetails));
        }
        callbackResponse = callbackResponseTransformer
                            .addDocuments(callbackRequest, documents, letterId, pdfSize, caseworkerInfo);
        return ResponseEntity.ok(callbackResponse);
    }

    private String getPdfSize(@Valid CaseData caseData) {
        String pdfSize;
        if (caseData.getExtraCopiesOfGrant() != null) {
            pdfSize = String.valueOf(caseData.getExtraCopiesOfGrant() + 2);
        } else {
            pdfSize = String.valueOf(2);
        }
        return pdfSize;
    }


    @PostMapping(path = "/generate-deposit-receipt", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<WillLodgementCallbackResponse> generateDepositReceipt(
        @RequestBody WillLodgementCallbackRequest callbackRequest) {
        Document document;
        DocumentType template = WILL_LODGEMENT_DEPOSIT_RECEIPT;

        Registry registry = registriesProperties.getRegistries().get(NEWCASTLE);
        callbackRequest.getCaseDetails().setNewcastleRegistryAddress(String.join(" ",
            registry.getAddressLine1(), registry.getAddressLine2(), registry.getAddressLine3(),
            registry.getTown(), registry.getPostcode()));

        document = pdfManagementService.generateAndUpload(callbackRequest, template);

        return ResponseEntity
            .ok(willLodgementCallbackResponseTransformer.addDocuments(callbackRequest, Arrays.asList(document)));
    }

    @PostMapping(path = "/generate-grant-draft-reissue", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> generateGrantDraftReissue(

            @RequestBody CallbackRequest callbackRequest) {

        Document document;
        final CaseDetails caseDetails = callbackRequest.getCaseDetails();
        final CaseData caseData = caseDetails.getData();

        registryDetailsService.getRegistryDetails(caseDetails);


        // The only difference between grant and reissue grant is one statement with the reissue date. Html/pdf template
        // post TC work has lots of complex logic in it that would be difficult to code in Docmosis,
        // so we use html/pdf template instead.
        if (useHtmlPdfGeneratorForReissue(caseData)) {
            document = documentGeneratorService.getDocument(callbackRequest, DocumentStatus.PREVIEW,
                DocumentIssueType.REISSUE);
        } else {
            document = documentGeneratorService.generateGrantReissue(callbackRequest, DocumentStatus.PREVIEW,
                Optional.of(DocumentIssueType.REISSUE));
        }
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(callbackResponseTransformer.addDocuments(callbackRequest,
            Arrays.asList(document), null, null, caseworkerInfo));
    }

    @PostMapping(path = "/generate-grant-reissue", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> generateGrantReissue(
            @RequestBody CallbackRequest callbackRequest)
            throws NotificationClientException {
        final List<Document> documents = new ArrayList<>();
        Document grantDocument;
        Document coversheet;
        final CaseDetails caseDetails = callbackRequest.getCaseDetails();
        final CaseData caseData = caseDetails.getData();

        registryDetailsService.getRegistryDetails(caseDetails);

        // The only difference between grant and reissue grant is one statement with the reissue date. Html/pdf template
        // post TC work has lots of complex logic in it that would be difficult to code in Docmosis,
        // so we use html/pdf template instead.
        if (useHtmlPdfGeneratorForReissue(caseData)) {
            grantDocument = documentGeneratorService.getDocument(callbackRequest, DocumentStatus.FINAL,
                DocumentIssueType.REISSUE);
            coversheet = pdfManagementService.generateAndUpload(callbackRequest, DocumentType.GRANT_COVER);
        } else {
            grantDocument = documentGeneratorService.generateGrantReissue(callbackRequest, DocumentStatus.FINAL,
                Optional.of(DocumentIssueType.REISSUE));
            coversheet = documentGeneratorService.generateCoversheet(callbackRequest);
        }

        documents.add(grantDocument);
        documents.add(coversheet);

        String letterId = null;

        if (caseData.isSendForBulkPrintingRequested() && !EDGE_CASE_NAME.equals(caseData.getCaseType())) {
            letterId = bulkPrintService.optionallySendToBulkPrint(callbackRequest, coversheet,
                grantDocument, true);
        }

        if (caseData.getOutsideUKGrantCopies() != null && caseData.getOutsideUKGrantCopies() > 0) {
            documents.add(notificationService.sendSealedAndCertifiedEmail(caseDetails));
        }
        if (caseData.isGrantReissuedEmailNotificationRequested()) {
            documents.add(notificationService.generateGrantReissue(callbackRequest));
        }
        String pdfSize = getPdfSize(caseData);
        log.info("{} documents generated: {}", documents.size(), documents);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(callbackResponseTransformer.addDocuments(callbackRequest,
            documents, letterId, pdfSize, caseworkerInfo));
    }

    // This only seems to be called once list lists are mapped to exec lists
    @PostMapping(path = "/generate-sot", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> generateStatementOfTruth(@RequestBody CallbackRequest callbackRequest) {
        redeclarationSoTValidationRule.validate(callbackRequest.getCaseDetails());

        log.info("Initiating call for SoT");
        caseDataTransformer.transformCaseDataForLegalStatementRegeneration(callbackRequest);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(callbackResponseTransformer.addSOTDocument(callbackRequest,
            documentGeneratorService.generateSoT(callbackRequest), caseworkerInfo));
    }

    @PostMapping(path = "/default-reprint-values", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> defaultReprintValues(@RequestBody CallbackRequest callbackRequest) {
        return ResponseEntity.ok(callbackResponseTransformer.transformCaseForReprint(callbackRequest));
    }

    @PostMapping(path = "/reprint", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> reprint(@RequestBody CallbackRequest callbackRequest) {
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(reprintService.reprintSelectedDocument(callbackRequest, caseworkerInfo));
    }

    @SuppressWarnings("java:S6863")
    @PostMapping(path = "/evidenceAdded", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> evidenceAdded(@RequestBody CallbackRequest callbackRequest) {
        if (featureToggleService.usePreventUpdatingExistingUploadedDocumentsFeatureToggleOn()) {
            try {
                evidenceUploadService.validateExistingUploadedDocuments(callbackRequest);
            } catch (BusinessValidationException exception) {
                return ResponseEntity.ok(CallbackResponse.builder()
                        .errors(List.of(exception.getUserMessage()))
                        .build());
            }
        }

        evidenceUploadService.updateLastEvidenceAddedDate(callbackRequest.getCaseDetails());
        try {
            final CaseDetails caseDetails = callbackRequest.getCaseDetails();
            if (caseDetails.getData().getApplicationType().equals(SOLICITOR)
                && !caseDetails.getState().equalsIgnoreCase(STATE_BO_GRANT_ISSUED)) {
                Document document = notificationService.sendStopResponseReceivedEmail(callbackRequest.getCaseDetails());
                documentTransformer.addDocument(callbackRequest, document, false);
            }
        } catch (NotificationClientException e) {
            log.warn("evidenceAdded fails to send StopResponseReceived notification for case: {}",
                    callbackRequest.getCaseDetails().getId());
        } catch (RuntimeException e) {
            log.warn("evidenceAdded fails to generate or upload notification pdf for case: {}",
                    callbackRequest.getCaseDetails().getId(), e);
        }
        caseDataTransformer.transformCaseDataForCaseCloseEvidenceHandledNo(callbackRequest);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        CallbackResponse response = callbackResponseTransformer.transformCase(callbackRequest, caseworkerInfo);
        return ResponseEntity.ok(response);
    }

    @PostMapping(path = "/evidenceAddedRPARobot", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> evidenceAddedRPARobot(@RequestBody CallbackRequest callbackRequest) {
        CaseDetails caseDetails = callbackRequest.getCaseDetails();
        CaseData caseData = caseDetails.getData();
        boolean update = true;
        if (caseDetails.getState().equalsIgnoreCase(STATE_BO_CASE_STOPPED)) {
            log.info("Case is stopped: {} ", caseDetails.getId());
            if (caseData.getDocumentUploadedAfterCaseStopped() != null
                    && caseData.getDocumentUploadedAfterCaseStopped().equalsIgnoreCase(YES)) {
                log.info("lastEvidenceAddedDate not updated for case: {} ", caseDetails.getId());
                update = false;
            } else {
                caseData.setDocumentUploadedAfterCaseStopped(YES);
            }
        } else {
            log.info("Case is ongoing: {} ", caseDetails.getId());
        }
        if (update) {
            evidenceUploadService.updateLastEvidenceAddedDate(caseDetails);
        }
        try {
            if (caseDetails.getData().getApplicationType().equals(SOLICITOR)
                    && !caseDetails.getState().equalsIgnoreCase(STATE_BO_GRANT_ISSUED)) {
                Document document = notificationService.sendStopResponseReceivedEmail(callbackRequest.getCaseDetails());
                documentTransformer.addDocument(callbackRequest, document, false);
            }
        } catch (NotificationClientException e) {
            log.warn("evidenceAddedRPARobot fails to send StopResponseReceived notification for case: {}, message: {}",
                    callbackRequest.getCaseDetails().getId(), e.getHttpResult());
        } catch (RuntimeException e) {
            log.warn("evidenceAddedRPARobot fails to generate or upload notification pdf for case: {}",
                    callbackRequest.getCaseDetails().getId(), e);
        }
        CallbackResponse response = callbackResponseTransformer.transformCase(callbackRequest, Optional.empty());
        return ResponseEntity.ok(response);
    }

    private boolean useHtmlPdfGeneratorForReissue(CaseData cd) {
        return GRANT_OF_PROBATE_NAME.equals(cd.getCaseType())
                && (cd.getApplicationType() == null || SOLICITOR.equals(cd.getApplicationType()))
                && (LATEST_SCHEMA_VERSION.equals(cd.getSchemaVersion()));
    }

    @PostMapping(
        path = "/upload",
        consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
        produces = MediaType.APPLICATION_JSON_VALUE
    )
    public List<String> upload(
        @RequestHeader(value = "Authorization") String authorizationToken,
        @RequestHeader(value = "ServiceAuthorization") String serviceAuthorizationToken,
        @RequestPart("file") List<MultipartFile> files) {
        List<String> result = new ArrayList<>();
        List<String> fileValidationErrors = documentValidation.validateFiles(files);
        if (!fileValidationErrors.isEmpty()) {
            result.addAll(fileValidationErrors);
            return result;
        }

        log.info("Uploading document at BackOffice");
        UploadResponse uploadResponse = documentManagementService
            .uploadForCitizen(files, authorizationToken, DocumentType.CITIZEN_HUB_UPLOAD);
        if (uploadResponse != null) {
            result = uploadResponse
                .getDocuments()
                .stream()
                .map(f -> f.links.self.href)
                .toList();
        }

        return result;
    }

    @PostMapping(path = "/citizenHubResponse", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> citizenHubResponse(@RequestBody CallbackRequest callbackRequest) {
        log.info("Citizen Hub Response for caseId: {}  Checkbox: {} documentUploadIssue: {} isSaveAndClose: {}",
                callbackRequest.getCaseDetails().getId(),
                callbackRequest.getCaseDetails().getData().getCitizenResponseCheckbox(),
                callbackRequest.getCaseDetails().getData().getDocumentUploadIssue(),
                callbackRequest.getCaseDetails().getData().getIsSaveAndClose()
        );
        return ResponseEntity.ok(callbackResponseTransformer.transformCitizenHubResponse(callbackRequest));
    }

    @PostMapping(path = "/setup-for-permanent-removal", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> setupForPermanentRemovalGrant(
            @RequestBody CallbackRequest callbackRequest) {
        return ResponseEntity.ok(callbackResponseTransformer.setupOriginalDocumentsForRemoval(callbackRequest));
    }

    @PostMapping(path = "/permanently-delete-removed", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> permanentlyDeleteRemovedGrant(
            @RequestBody CallbackRequest callbackRequest) {
        documentGeneratorService.permanentlyDeleteRemovedDocumentsForGrant(callbackRequest);
        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        return ResponseEntity.ok(callbackResponseTransformer.updateTaskList(callbackRequest, caseworkerInfo));
    }

    @PostMapping(path = "/setup-for-permanent-removal-will", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<WillLodgementCallbackResponse> setupForPermanentRemovalWillLodgement(
            @RequestBody WillLodgementCallbackRequest callbackRequest) {
        return ResponseEntity.ok(willLodgementCallbackResponseTransformer
                .setupOriginalDocumentsForRemoval(callbackRequest));
    }

    @PostMapping(path = "/permanently-delete-removed-will", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<WillLodgementCallbackResponse> permanentlyDeleteRemovedWillLodgement(
            @RequestBody WillLodgementCallbackRequest callbackRequest) {
        documentGeneratorService.permanentlyDeleteRemovedDocumentsForWillLodgement(callbackRequest);
        return ResponseEntity.ok(willLodgementCallbackResponseTransformer.transform(callbackRequest));
    }

    @PostMapping(path = "/startAmendLegalStatement", consumes = APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> startAmendLegalStatement(
            @RequestBody final CallbackRequest callbackRequest) {
        final CaseDetails caseDetails = callbackRequest.getCaseDetails();
        final long caseId = caseDetails.getId();

        log.info("Starting amend legal statement for case: {}", caseId);

        redeclarationSoTValidationRule.validate(caseDetails);

        CallbackResponse response = callbackResponseTransformer.transformCase(callbackRequest, Optional.empty());
        return ResponseEntity.ok(response);
    }

    @PostMapping(path = "/validateAmendLegalStatement", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> validateAmendLegalStatement(
            @RequestBody final CallbackRequest callbackRequest) {
        final CaseDetails caseDetails = callbackRequest.getCaseDetails();
        final long caseId = caseDetails.getId();

        log.info("Validating amend legal statement for case: {}", caseId);

        final DocumentLink amendedLegalStatement = caseDetails.getData().getAmendedLegalStatement();

        if (featureToggleService.enableAmendLegalStatementFiletypeCheck()) {
            final Optional<String> validationErr = documentValidation.validateUploadedDocumentIsType(
                    caseId,
                    amendedLegalStatement,
                    MediaType.APPLICATION_PDF);

            if (validationErr.isPresent()) {
                final String validationMsg = validationErr.get();
                log.info("case {} validation error: {}", caseId, validationMsg);
                CallbackResponse err = CallbackResponse.builder().errors(List.of(validationMsg)).build();
                return ResponseEntity.ok(err);
            }
        } else {
            log.info("Skipping legal statement filetype validation in case {}", caseId);
        }

        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        CallbackResponse response = callbackResponseTransformer.transformCase(callbackRequest, caseworkerInfo);
        return ResponseEntity.ok(response);
    }

    @PostMapping(path = "/amendLegalStatement", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CallbackResponse> amendLegalStatement(
            @RequestBody final CallbackRequest callbackRequest) {
        final long caseId = callbackRequest.getCaseDetails().getId();
        log.info("Amending legal statement for case: {}", caseId);

        final CaseData caseData = callbackRequest.getCaseDetails().getData();
        final ApplicationType applicationType = caseData.getApplicationType();
        final DocumentLink amendedLegalStatement = caseData.getAmendedLegalStatement();

        final String baseFileName = switch (applicationType) {
            case PERSONAL -> "amendedLegalStatement";
            case SOLICITOR -> {
                final DocumentType solsDocType = documentGeneratorService.getSolicitorSoTDocType(callbackRequest);
                final String solsBaseName = solsDocType.getTemplateName();
                yield new StringBuilder()
                        .append("amended")
                        .append(solsBaseName.toUpperCase().substring(0,1))
                        .append(solsBaseName.substring(1))
                        .toString();
            }
        };

        final String currentDate = LocalDate.now().format(DateTimeFormatter.ofPattern("dd-MMM-yyyy"));
        final String amendedFileName = new StringBuilder()
                .append(baseFileName)
                .append("_")
                .append(currentDate)
                .append(".pdf")
                .toString();

        amendedLegalStatement.setDocumentFilename(amendedFileName);

        Optional<UserInfo> caseworkerInfo = userInfoService.getCaseworkerInfo();
        CallbackResponse response = callbackResponseTransformer.transformCase(callbackRequest, caseworkerInfo);
        return ResponseEntity.ok(response);
    }


    @PostMapping(path = "/supplementaryData", consumes = APPLICATION_JSON_VALUE,
            produces = {APPLICATION_JSON_VALUE})
    public ResponseEntity<WillLodgementCallbackResponse> setWillLodgementSupplementaryData(
           @Valid @RequestBody final WillLodgementCallbackRequest willLodgementCallbackRequest) {
        ccdSupplementaryDataService.submitSupplementaryDataToCcd(
                willLodgementCallbackRequest.getCaseDetails().getId().toString());
        WillLodgementCallbackResponse willLodgementCallbackResponse = WillLodgementCallbackResponse.builder().build();

        return ResponseEntity.ok(willLodgementCallbackResponse);
    }

}
