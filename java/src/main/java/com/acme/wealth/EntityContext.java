package com.acme.wealth;

import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import java.io.InputStream;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Component
public class EntityContext {

    private final String entityId;
    private final String currency;
    private final String localePrimary;
    private final List<String> localeSupported;
    private final BigDecimal feeBps;
    private final BigDecimal relationshipThresholdAmount;
    private final String dataRegion;
    private final String kvVaultName;
    private final String kvVaultUri;
    private final String regulator;
    private final String suitabilityFramework;
    private final String bookingCentre;
    private final boolean disclosureLocaleRequired;
    private final boolean crossBorderConsentRequired;
    private final boolean dataResidencyStrict;
    private final boolean multilingualDocumentsRequired;
    private final int auditLogRetentionDays;
    private final boolean schemaEntityIdEnforced;

    @SuppressWarnings("unchecked")
    public EntityContext() {
        String envEntityId = System.getenv("ENTITY_ID");
        if (envEntityId == null || envEntityId.isBlank()) {
            throw new IllegalStateException("ENTITY_ID environment variable is not set.");
        }
        Yaml yaml = new Yaml();
        InputStream is = getClass().getClassLoader().getResourceAsStream("entity-config.yaml");
        if (is == null) {
            throw new IllegalStateException("entity-config.yaml not found on classpath.");
        }
        Map<String, Object> root = yaml.load(is);
        Map<String, Object> entities = (Map<String, Object>) root.get("entities");
        if (!entities.containsKey(envEntityId)) {
            throw new IllegalStateException("No manifest entry for ENTITY_ID=" + envEntityId);
        }
        Map<String, Object> cfg = (Map<String, Object>) entities.get(envEntityId);
        String manifestEntityId = (String) cfg.get("entity_id");
        if (!envEntityId.equals(manifestEntityId)) {
            throw new IllegalStateException(
                    "ENTITY_ID mismatch: env=" + envEntityId + " manifest=" + manifestEntityId);
        }
        this.entityId                    = manifestEntityId;
        this.currency                    = (String)  cfg.get("currency");
        this.localePrimary               = (String)  cfg.get("locale_primary");
        this.localeSupported             = (List<String>) cfg.get("locale_supported");
        this.feeBps                      = new BigDecimal(cfg.get("fee_bps").toString());
        this.relationshipThresholdAmount = new BigDecimal(cfg.get("relationship_threshold_amount").toString());
        this.dataRegion                  = (String)  cfg.get("data_region");
        this.kvVaultName                 = (String)  cfg.get("kv_vault_name");
        this.kvVaultUri                  = (String)  cfg.get("kv_vault_uri");
        this.regulator                   = (String)  cfg.get("regulator");
        this.suitabilityFramework        = (String)  cfg.get("suitability_framework");
        this.bookingCentre               = (String)  cfg.get("booking_centre");
        this.disclosureLocaleRequired    = (boolean) cfg.get("disclosure_locale_required");
        this.crossBorderConsentRequired  = (boolean) cfg.get("cross_border_consent_required");
        this.dataResidencyStrict         = (boolean) cfg.get("data_residency_strict");
        this.multilingualDocumentsRequired = (boolean) cfg.get("multilingual_documents_required");
        this.auditLogRetentionDays       = (int)     cfg.get("audit_log_retention_days");
        this.schemaEntityIdEnforced      = (boolean) cfg.get("schema_entity_id_enforced");
    }

    public String  getEntityId()                    { return entityId; }
    public String  getCurrency()                    { return currency; }
    public String  getLocalePrimary()               { return localePrimary; }
    public List<String> getLocaleSupported()        { return localeSupported; }
    public BigDecimal getFeeBps()                   { return feeBps; }
    public BigDecimal getRelationshipThresholdAmount() { return relationshipThresholdAmount; }
    public String  getDataRegion()                  { return dataRegion; }
    public String  getKvVaultName()                 { return kvVaultName; }
    public String  getKvVaultUri()                  { return kvVaultUri; }
    public String  getRegulator()                   { return regulator; }
    public String  getSuitabilityFramework()        { return suitabilityFramework; }
    public String  getBookingCentre()               { return bookingCentre; }
    public boolean isDisclosureLocaleRequired()     { return disclosureLocaleRequired; }
    public boolean isCrossBorderConsentRequired()   { return crossBorderConsentRequired; }
    public boolean isDataResidencyStrict()          { return dataResidencyStrict; }
    public boolean isMultilingualDocumentsRequired(){ return multilingualDocumentsRequired; }
    public int     getAuditLogRetentionDays()       { return auditLogRetentionDays; }
    public boolean isSchemaEntityIdEnforced()       { return schemaEntityIdEnforced; }
}