package uk.gov.hmcts.probate.dmnutils;

import com.fasterxml.jackson.core.type.TypeReference;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.CASE_TYPE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.CASE_TYPE_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DECEASED_FORENAMES;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DECEASED_FORENAMES_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DECEASED_SURNAME;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.DECEASED_SURNAME_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REGION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REGISTRY_LOCATION;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.REGISTRY_LOCATION_VALUE;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ROLE_CATEGORY;
import static uk.gov.hmcts.probate.dmnutils.TaskAttributeConstants.ROLE_CATEGORY_CTSC;

public class CaseDataBuilder {

    Map<String,Object> caseData;

    private CaseDataBuilder(Map<String,Object> caseData) {
        this.caseData = caseData;
    }

    public static CaseDataBuilder defaultCase() {
        Map<String,Object> caseData = new HashMap<>();
        caseData.put("caseNameHmctsInternal", "Joe Blogs");
        caseData.put("isUrgent", "No");
        caseData.put("dueDate", LocalDate.now());
        return new CaseDataBuilder(caseData);
    }

    public static CaseDataBuilder defaultWaCase() {
        Map<String,Object> caseData = new HashMap<>();
        caseData.put("caseNameHmctsInternal", "Joe Blogs");
        caseData.put("isUrgent", "No");
        caseData.put(CASE_TYPE, CASE_TYPE_VALUE);
        caseData.put(DECEASED_FORENAMES, DECEASED_FORENAMES_VALUE);
        caseData.put(DECEASED_SURNAME, DECEASED_SURNAME_VALUE);
        caseData.put(REGION, "someRegion");
        caseData.put(ROLE_CATEGORY, ROLE_CATEGORY_CTSC);
        caseData.put(REGISTRY_LOCATION, REGISTRY_LOCATION_VALUE);
        return new CaseDataBuilder(caseData);
    }

    public Map<String,Object> build() {
        return caseData;
    }

    public CaseDataBuilder isUrgent() {
        caseData.put("isUrgent", "Yes");
        return this;
    }

    private static class MapTypeReference extends TypeReference<Map<String, Object>> {
    }
}
