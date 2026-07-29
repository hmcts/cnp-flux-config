package uk.gov.hmcts.probate.service;

import com.launchdarkly.sdk.LDContext;
import com.launchdarkly.sdk.server.LDClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class FeatureToggleService {

    private final LDClient ldClient;
    private final LDContext ldContext;
    private static final String SMEE_AND_FORD_POUND_VALUE_TOGGLE = "probate-smee-ford-pound-value";
    private static final String IRON_MOUNTAIN_IN_BACK_OFFICE = "probate-iron-mountain-in-back-office";
    private static final String EXELA_IN_BACK_OFFICE = "probate-exela-in-back-office";
    private static final String FIRST_STOP_REMINDER_TOGGLE = "probate-cron-first-stop-reminder";
    private static final String SECOND_STOP_REMINDER_TOGGLE = "probate-cron-second-stop-reminder";
    private static final String HSE_REMINDER_TOGGLE = "probate-cron-hse-reminder";
    private static final String DORMANT_WARNING_TOGGLE = "probate-cron-dormant-warning";
    private static final String DORMANT_REMINDER_TOGGLE = "probate-cron-dormant-reminder";
    private static final String UNSUBMITTED_APPLICATION_TOGGLE = "probate-cron-unsubmitted-application";
    private static final String DECLARATION_NOT_SIGNED_TOGGLE = "probate-cron-declaration-not-signed";
    private static final String NFI_DATA_EXTRACT_TOGGLE = "probate-nfi-data-extract";
    private static final String SMEE_AND_FORD_COMMENT_FIELD_TOGGLE = "probate-smee-ford-comment-field";
    private static final String DISABLE_SMEE_AND_FORD_EMAIL_NOTIFICATION_TOGGLE = "probate-disable-smee-ford-email";
    private static final String USE_JSON_LIB_FOR_CASE_MATCHING = "probate-use-json-lib-for-case-matching";
    private static final String USE_PRIMARY_NOTIFY_KEY = "probate-use-primary-notify-key";
    private static final String PREVENT_UPDATING_EXISTING_UPLOADED_DOCUMENTS =
            "probate-prevent-updating-existing-uploaded-documents";

    @Autowired
    public FeatureToggleService(LDClient ldClient, @Value("${ld.user.key}") String ldUserKey,
                                @Value("${ld.user.firstName}") String ldUserFirstName,
                                @Value("${ld.user.lastName}") String ldUserLastName) {
        final String contextName = new StringBuilder()
                .append(ldUserFirstName)
                .append(" ")
                .append(ldUserLastName)
                .toString();

        this.ldClient = ldClient;
        this.ldContext = LDContext.builder(ldUserKey)
                .name(contextName)
                .kind("application")
                .set("timestamp", String.valueOf(System.currentTimeMillis()))
                .build();

    }

    public boolean isNewFeeRegisterCodeEnabled() {
        return isFeatureToggleOn("probate-newfee-register-code", true);
    }

    public boolean isNewFee2026Enabled() {
        return isFeatureToggleOn("probate-fee-increase-2026", false);
    }

    public boolean enableNewMarkdownFiltering() {
        return isFeatureToggleOn("probate-enable-new-markdown-filtering", false);
    }

    public boolean isFeatureToggleOn(String featureToggleCode, boolean defaultValue) {
        return this.ldClient.boolVariation(featureToggleCode, this.ldContext, defaultValue);
    }

    public boolean enableAmendLegalStatementFiletypeCheck() {
        return this.isFeatureToggleOn("enable-amend-legal-statement-filetype-check", false);
    }

    public boolean isPoundValueFeatureToggleOn() {
        return this.isFeatureToggleOn(
                SMEE_AND_FORD_POUND_VALUE_TOGGLE, false);
    }

    public boolean isIronMountainInBackOffice() {
        return this.isFeatureToggleOn(IRON_MOUNTAIN_IN_BACK_OFFICE, false);
    }

    public boolean isExelaInBackOffice() {
        return this.isFeatureToggleOn(EXELA_IN_BACK_OFFICE, false);
    }

    public boolean isFirstStopReminderFeatureToggleOn() {
        return this.isFeatureToggleOn(
                FIRST_STOP_REMINDER_TOGGLE, false);
    }

    public boolean isSecondStopReminderFeatureToggleOn() {
        return this.isFeatureToggleOn(
                SECOND_STOP_REMINDER_TOGGLE, false);
    }

    public boolean isHseReminderFeatureToggleOn() {
        return this.isFeatureToggleOn(
                HSE_REMINDER_TOGGLE, false);
    }

    public boolean isDormantWarningFeatureToggleOn() {
        return this.isFeatureToggleOn(
                DORMANT_WARNING_TOGGLE, false);
    }

    public boolean isUnsubmittedApplicationFeatureToggleOn() {
        return this.isFeatureToggleOn(
                UNSUBMITTED_APPLICATION_TOGGLE, false);
    }

    public boolean isDeclarationNotSignedFeatureToggleOn() {
        return this.isFeatureToggleOn(
                DECLARATION_NOT_SIGNED_TOGGLE, false);
    }

    public boolean isDormantReminderFeatureToggleOn() {
        return this.isFeatureToggleOn(
                DORMANT_REMINDER_TOGGLE, false);
    }

    public boolean isNfiDataExtractFeatureToggleOn() {
        return this.isFeatureToggleOn(
                NFI_DATA_EXTRACT_TOGGLE, false);
    }

    public boolean isSmeeAndFordCommentFieldFeatureToggleOn() {
        return this.isFeatureToggleOn(
                SMEE_AND_FORD_COMMENT_FIELD_TOGGLE, false);
    }

    public boolean isSmeeAndFordEmailNotificationDisabled() {
        return this.isFeatureToggleOn(
                DISABLE_SMEE_AND_FORD_EMAIL_NOTIFICATION_TOGGLE, false);
    }

    public boolean useJsonLibForCaseMatching() {
        return this.isFeatureToggleOn(
                USE_JSON_LIB_FOR_CASE_MATCHING, false);
    }

    public boolean usePrimaryNotifyKey() {
        return this.isFeatureToggleOn(
                USE_PRIMARY_NOTIFY_KEY, true);
    }

    public boolean usePreventUpdatingExistingUploadedDocumentsFeatureToggleOn() {
        return this.isFeatureToggleOn(
                PREVENT_UPDATING_EXISTING_UPLOADED_DOCUMENTS, false);
    }
}
