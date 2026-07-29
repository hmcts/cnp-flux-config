package uk.gov.hmcts.probate.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
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

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EvidenceUploadServiceTest {

    @InjectMocks
    private EvidenceUploadService evidenceUploadService;

    @Mock
    private CaseDetails caseDetailsMock;
    @Mock
    private CaseData caseDataMock;


    @BeforeEach
    public void setup() {
        MockitoAnnotations.openMocks(this);
    }

    @Test
    void shouldVerifyUpdateOfLastEvidenceAddedDate() {

        when(caseDetailsMock.getData()).thenReturn(caseDataMock);
        evidenceUploadService.updateLastEvidenceAddedDate(caseDetailsMock);

        verify(caseDataMock).setLastEvidenceAddedDate(any(LocalDate.class));

    }

    @Test
    void shouldNotThrowWhenOnlyCommentWasUpdatedOnExistingUploadedDocument() {
        UploadDocument beforeDoc = uploadDocument("http://dm-store/documents/1", "before");
        UploadDocument afterDoc = uploadDocument("http://dm-store/documents/1", "after");

        CaseData beforeData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("before-collection-id", beforeDoc)))
                .build();
        CaseData afterData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("after-collection-id", afterDoc)))
                .build();

        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertDoesNotThrow(() -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldThrowWhenExistingUploadedDocumentWasRemovedOrReplaced() {
        UploadDocument beforeDoc = uploadDocument("http://dm-store/documents/1", "before");
        UploadDocument afterDoc = uploadDocument("http://dm-store/documents/2", "after");

        CaseData beforeData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("before-collection-id", beforeDoc)))
                .build();
        CaseData afterData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("after-collection-id", afterDoc)))
                .build();

        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertThrows(BusinessValidationException.class,
                () -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldNotThrowWhenCollectionMemberIdChangesAndDocumentUrlIsUnchanged() {
        UploadDocument beforeDoc = uploadDocument("http://dm-store/documents/1", "before");
        UploadDocument afterDoc = uploadDocument("http://dm-store/documents/1", "before");

        CaseData beforeData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("collection-id-1", beforeDoc)))
                .build();
        CaseData afterData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("collection-id-2", afterDoc)))
                .build();

        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertDoesNotThrow(() -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldNotThrowWhenExistingDocumentUnchangedAndNewDocumentAdded() {
        UploadDocument existingBeforeDoc = uploadDocument("http://dm-store/documents/1", "existing");
        UploadDocument existingAfterDoc = uploadDocument("http://dm-store/documents/1", "existing");
        UploadDocument newAfterDoc = uploadDocument("http://dm-store/documents/2", "new");

        CaseData beforeData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("existing-before-id", existingBeforeDoc)))
                .build();
        CaseData afterData = CaseData.builder()
                .boDocumentsUploaded(List.of(
                        new CollectionMember<>("existing-after-id", existingAfterDoc),
                        new CollectionMember<>("new-after-id", newAfterDoc)
                ))
                .build();

        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertDoesNotThrow(() -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldThrowBusinessValidationExceptionWhenCaseDetailsBeforeIsNull() {
        CaseData afterData = CaseData.builder().boDocumentsUploaded(Collections.emptyList()).build();
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);

        assertThrows(BusinessValidationException.class,
                () -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldNotThrowWhenDocumentsBeforeIsNull() {
        CaseData beforeData = CaseData.builder().boDocumentsUploaded(null).build();
        CaseData afterData = CaseData.builder().boDocumentsUploaded(Collections.emptyList()).build();
        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertDoesNotThrow(() -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldThrowWhenDocumentsBeforeContainsEntryWithNoResolvableUrl() {
        CaseData beforeData = CaseData.builder().boDocumentsUploaded(List.of(new CollectionMember<UploadDocument>(null),
                new CollectionMember<>(null, UploadDocument.builder().comment("ignored").build()))).build();
        CaseData afterData = CaseData.builder().boDocumentsUploaded(Collections.emptyList()).build();
        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CaseDetails afterDetails = new CaseDetails(afterData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(afterDetails);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertThrows(BusinessValidationException.class,
                () -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    @Test
    void shouldThrowBusinessValidationExceptionWhenCaseDetailsAfterIsNull() {
        UploadDocument beforeDoc = uploadDocument("http://dm-store/documents/1", "before");
        CaseData beforeData = CaseData.builder()
                .boDocumentsUploaded(List.of(new CollectionMember<>("doc-id", beforeDoc)))
                .build();
        CaseDetails beforeDetails = new CaseDetails(beforeData, null, 123L);
        CallbackRequest callbackRequest = new CallbackRequest(null);
        callbackRequest.setCaseDetailsBefore(beforeDetails);

        assertThrows(BusinessValidationException.class,
                () -> evidenceUploadService.validateExistingUploadedDocuments(callbackRequest));
    }

    private UploadDocument uploadDocument(String documentUrl, String comment) {
        return UploadDocument.builder()
                .documentLink(DocumentLink.builder().documentUrl(documentUrl).build())
                .comment(comment)
                .build();
    }
}
