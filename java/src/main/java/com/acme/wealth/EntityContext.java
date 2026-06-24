package com.acme.wealth;

import org.yaml.snakeyaml.Yaml;

import java.io.InputStream;
import java.math.BigDecimal;
import java.util.Locale;
import java.util.Map;

public final class EntityContext {

    private static final EntityContext INSTANCE;

    static {
        String entityId = System.getenv("ENTITY_ID");
        if (entityId == null || entityId.isBlank()) {
            entityId = "SG";
        }
        INSTANCE = new EntityContext(entityId.toUpperCase().trim());
    }

    private final String entityId;
    private final String currency;
    private final String locale;
    private final String regulator;
    private final BigDecimal feeBps;
    private final BigDecimal largePositionThreshold;
    private final String dataRegion;
    private final String kmsVaultName;
    private final String suitabilityFramework;
    private final String disclosureLocale;
    private final String bookingCentre;
    private final boolean auditTrailEnabled;
    private final String dbConnectionSecret;
    private final String apiKeySecret;

    @SuppressWarnings("unchecked")
    private EntityContext(String entityId) {
        this.entityId = entityId;
        String configFile = "config/entity_" + entityId + ".yaml";
        Yaml yaml = new Yaml();
        try (InputStream is = getClass().getClassLoader().getResourceAsStream(configFile)) {
            if (is == null) {
                throw new IllegalStateException("Entity config not found: " + configFile);
            }
            Map<String, Object> cfg = yaml.load(is);
            this.currency = (String) cfg.get("currency");
            this.locale = (String) cfg.get("locale");
            this.regulator = (String) cfg.get("regulator");
            this.feeBps = new BigDecimal(cfg.get("fee_bps").toString());
            this.largePositionThreshold = new BigDecimal(cfg.get("min_threshold").toString());
            this.dataRegion = (String) cfg.get("data_region");
            this.kmsVaultName = (String) cfg.get("kms_vault_name");
            this.suitabilityFramework = (String) cfg.get("suitability_framework");
            this.disclosureLocale = (String) cfg.get("disclosure_locale");
            this.bookingCentre = (String) cfg.get("booking_centre");
            this.auditTrailEnabled = Boolean.TRUE.equals(cfg.get("audit_trail_enabled"));
            this.dbConnectionSecret = (String) cfg.get("db_connection_secret");
            this.apiKeySecret = (String) cfg.get("api_key_secret");
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Failed to load entity config", e);
        }
    }

    public static EntityContext getInstance() { return INSTANCE; }

    public String getEntityId() { return entityId; }
    public String getCurrency() { return currency; }
    public String getLocale() { return locale; }
    public String getRegulator() { return regulator; }
    public BigDecimal getFeeBps() { return feeBps; }
    public BigDecimal getLargePositionThreshold() { return largePositionThreshold; }
    public String getDataRegion() { return dataRegion; }
    public String getKmsVaultName() { return kmsVaultName; }
    public String getSuitabilityFramework() { return suitabilityFramework; }
    public String getDisclosureLocale() { return disclosureLocale; }
    public String getBookingCentre() { return bookingCentre; }
    public boolean isAuditTrailEnabled() { return auditTrailEnabled; }
    public String getDbConnectionSecret() { return dbConnectionSecret; }
    public String getApiKeySecret() { return apiKeySecret; }

    public Locale getJavaLocale() {
        String[] parts = locale.split("_");
        return parts.length >= 2 ? new Locale(parts[0], parts[1]) : new Locale(parts[0]);
    }
}