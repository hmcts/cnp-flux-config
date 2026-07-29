package uk.gov.hmcts.probate.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.probate.exception.BusinessValidationException;
import uk.gov.hmcts.probate.model.ccd.raw.CollectionMember;
import uk.gov.hmcts.probate.model.ccd.raw.DocumentLink;
import uk.gov.hmcts.probate.model.ccd.raw.UploadDocument;
import uk.gov.hmcts.probate.model.ccd.raw.request.CallbackRequest;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseData;
import uk.gov.hmcts.probate.model.ccd.raw.request.CaseDetails;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Component
public class EvidenceUploadService {

    private static final String DOCUMENT_MODIFICATION_NOT_ALLOWED_ERROR =
            "You have removed or modified a document that was previously uploaded to this application.";

    private static final String NO_DOCUMENT_RESOLVABLE_ERROR =
            "No document exists with a resolvable document URL for this document. "
                    + "Please check the document has been uploaded correctly.";

    private static final String MISSING_CASE_DETAILS_ERROR = "Case details are missing for this validation request.";

    public void updateLastEvidenceAddedDate(CaseDetails caseDetails) {
        CaseData caseData = caseDetails.getData();
        log.info("Updating lastEvidenceAddedDate for case {}", caseDetails.getId());
        caseData.setLastEvidenceAddedDate(LocalDate.now());
    }

    public void validateExistingUploadedDocuments(CallbackRequest callbackRequest) {
        if (callbackRequest == null || callbackRequest.getCaseDetails() == null
                || callbackRequest.getCaseDetailsBefore() == null) {
            throw new BusinessValidationException(
                    MISSING_CASE_DETAILS_ERROR,
                    MISSING_CASE_DETAILS_ERROR
            );
        }

        List<CollectionMember<UploadDocument>> documentsBefore =
                Optional.ofNullable(callbackRequest.getCaseDetailsBefore())
                .map(CaseDetails::getData)
                .map(CaseData::getBoDocumentsUploaded)
                .orElse(Collections.emptyList());
        if (documentsBefore.isEmpty()) {
            return;
        }

        List<CollectionMember<UploadDocument>> documentsAfter = Optional.ofNullable(callbackRequest.getCaseDetails())
                .map(CaseDetails::getData)
                .map(CaseData::getBoDocumentsUploaded)
                .orElse(Collections.emptyList());

        Set<String> afterDocumentUrls = documentsAfter.stream()
                .map(this::getDocumentUrl)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Long caseId = callbackRequest.getCaseDetails().getId();
        for (CollectionMember<UploadDocument> existingDocument : documentsBefore) {
            String existingDocumentUrl = getDocumentUrl(existingDocument);
            if (existingDocumentUrl == null) {
                log.error("Skipping validation for document with id {} on case {} - no resolvable document URL",
                        existingDocument.getId(),
                        caseId);
                throw new BusinessValidationException(
                        NO_DOCUMENT_RESOLVABLE_ERROR,
                        NO_DOCUMENT_RESOLVABLE_ERROR
                );
            }
            if (!afterDocumentUrls.contains(existingDocumentUrl)) {
                log.error("Document with URL {} has been removed or replaced for case {}",
                        existingDocumentUrl,
                        caseId);
                throw new BusinessValidationException(
                        DOCUMENT_MODIFICATION_NOT_ALLOWED_ERROR,
                        DOCUMENT_MODIFICATION_NOT_ALLOWED_ERROR
                );
            }
        }
    }

    private String getDocumentUrl(CollectionMember<UploadDocument> documentMember) {
        return Optional.ofNullable(documentMember)
                .map(CollectionMember::getValue)
                .map(UploadDocument::getDocumentLink)
                .map(DocumentLink::getDocumentUrl)
                .orElse(null);
    }
}
