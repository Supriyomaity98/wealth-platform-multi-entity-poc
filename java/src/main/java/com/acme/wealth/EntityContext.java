package com.acme.wealth;

import org.yaml.snakeyaml.Yaml;

import java.io.InputStream;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Immutable entity context loaded once at process start from ACME_ENTITY_ID env var.
 * Defaults to SG when the variable is absent (baseline preservation).
 */
public final class EntityContext {

    private static final EntityContext INSTANCE = load();

    private final String entityId;
    private final String currency;
    private final String locale;
    private final String regulator;
    private final String bookingCentre;
    private final BigDecimal feeBps;
    private final BigDecimal largePositionThreshold;
    private final String suitabilityFramework;
    private final String kmsVaultName;
    private final String dataRegion;
    private final BigDecimal minBalance;
    private final String disclosureLocale;
    private final String auditLogPolicy;
    private final String dbConnectionSecret;
    private final String apiKeySecret;

    private EntityContext(Map<String, Object> cfg) {
        this.entityId = str(cfg, "entity_id");
        this.currency = str(cfg, "currency");
        this.locale = str(cfg, "locale");
        this.regulator = str(cfg, "regulator");
        this.bookingCentre = str(cfg, "booking_centre");
        this.feeBps = decimal(cfg, "fee_bps");
        this.largePositionThreshold = decimal(cfg, "large_position_threshold");
        this.suitabilityFramework = str(cfg, "suitability_framework");
        this.kmsVaultName = str(cfg, "kms_vault_name");
        this.dataRegion = str(cfg, "data_region");
        this.minBalance = decimal(cfg, "min_balance");
        this.disclosureLocale = str(cfg, "disclosure_locale");
        this.auditLogPolicy = str(cfg, "audit_log_policy");
        // Secrets via Azure Key Vault references — never plaintext
        String vault = this.kmsVaultName;
        this.dbConnectionSecret = "${KEYVAULT:" + vault + "-db-connection-string}";
        this.apiKeySecret = "${KEYVAULT:" + vault + "-api-key}";
    }

    @SuppressWarnings("unchecked")
    private static EntityContext load() {
        String entityId = System.getenv("ACME_ENTITY_ID");
        if (entityId == null || entityId.isBlank()) {
            entityId = "SG";
        }
        Yaml yaml = new Yaml();
        try (InputStream is = EntityContext.class.getClassLoader()
                .getResourceAsStream("entity_config.yaml")) {
            if (is == null) {
                throw new IllegalStateException("entity_config.yaml not found on classpath");
            }
            Map<String, Object> root = yaml.load(is);
            List<Map<String, Object>> entities = (List<Map<String, Object>>) root.get("entities");
            for (Map<String, Object> e : entities) {
                if (entityId.equals(str(e, "entity_id"))) {
                    return new EntityContext(e);
                }
            }
        } catch (java.io.IOException ex) {
            throw new IllegalStateException("Failed to load entity_config.yaml", ex);
        }
        throw new IllegalStateException("No config found for entity: " + entityId);
    }

    public static EntityContext getInstance() { return INSTANCE; }

    // Visible-for-testing factory
    @SuppressWarnings("unchecked")
    public static EntityContext fromMap(Map<String, Object> cfg) {
        return new EntityContext(cfg);
    }

    public String getEntityId() { return entityId; }
    public String getCurrency() { return currency; }
    public String getLocale() { return locale; }
    public String getRegulator() { return regulator; }
    public String getBookingCentre() { return bookingCentre; }
    public BigDecimal getFeeBps() { return feeBps; }
    public BigDecimal getLargePositionThreshold() { return largePositionThreshold; }
    public String getSuitabilityFramework() { return suitabilityFramework; }
    public String getKmsVaultName() { return kmsVaultName; }
    public String getDataRegion() { return dataRegion; }
    public BigDecimal getMinBalance() { return minBalance; }
    public String getDisclosureLocale() { return disclosureLocale; }
    public String getAuditLogPolicy() { return auditLogPolicy; }
    public String getDbConnectionSecret() { return dbConnectionSecret; }
    public String getApiKeySecret() { return apiKeySecret; }

    private static String str(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v == null ? "" : v.toString();
    }
    private static BigDecimal decimal(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v == null ? BigDecimal.ZERO : new BigDecimal(v.toString());
    }
}