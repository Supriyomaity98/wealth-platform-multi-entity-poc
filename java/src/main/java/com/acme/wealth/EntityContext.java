package com.acme.wealth;

import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * EntityContext encapsulates all entity-specific configuration and secrets.
 * It loads the per-entity YAML config identified by the ENTITY_ID environment
 * variable and validates all required keys at startup.
 *
 * Secrets are referenced via Azure Key Vault pattern:
 *   ${KEYVAULT:<key_vault_name>/<secret_name>}
 * and are never stored in plaintext.
 */
@Component
public class EntityContext {

    private static final List<String> REQUIRED_KEYS = List.of(
            "entity_id",
            "entity_full_name",
            "currency",
            "fee_schedule_bps",
            "min_portfolio_threshold",
            "default_locale",
            "booking_centre",
            "data_region",
            "kms_vault_name",
            "suitability_framework",
            "regulatory_bodies",
            "disclosure_locale_map"
    );

    private String entityId;
    private String entityFullName;
    private String currency;
    private int feeScheduleBps;
    private long minPortfolioThreshold;
    private String defaultLocale;
    private String bookingCentre;
    private String dataRegion;
    private String kmsVaultName;
    private String suitabilityFramework;
    private List<String> regulatoryBodies;
    private Map<String, String> disclosureLocaleMap;

    private String dbConnectionStringRef;
    private String apiKeyRef;
    private String encryptionKeyRef;

    private String disclosureText;

    @PostConstruct
    public void init() {
        String envEntityId = System.getenv("ENTITY_ID");
        if (envEntityId == null || envEntityId.isBlank()) {
            throw new IllegalStateException(
                    "ENTITY_ID environment variable is not set. Cannot start without entity context.");
        }

        String configPath = "configs/entities/" + envEntityId + ".yaml";
        Map<String, Object> config = loadYamlConfig(configPath);

        validateRequiredKeys(config);

        this.entityId = requireString(config, "entity_id");
        if (!this.entityId.equals(envEntityId)) {
            throw new IllegalStateException(
                    "entity_id in config '" + this.entityId
                    + "' does not match ENTITY_ID env var '" + envEntityId + "'");
        }

        this.entityFullName = requireString(config, "entity_full_name");
        this.currency = requireString(config, "currency");
        try {
            java.util.Currency.getInstance(this.currency);
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("Invalid ISO 4217 currency code: " + this.currency);
        }

        this.feeScheduleBps = requireInt(config, "fee_schedule_bps");
        if (this.feeScheduleBps < 0 || this.feeScheduleBps > 10000) {
            throw new IllegalStateException(
                    "fee_schedule_bps must be between 0 and 10000, got: " + this.feeScheduleBps);
        }

        this.minPortfolioThreshold = requireLong(config, "min_portfolio_threshold");
        if (this.minPortfolioThreshold < 0) {
            throw new IllegalStateException(
                    "min_portfolio_threshold must be non-negative, got: " + this.minPortfolioThreshold);
        }

        this.defaultLocale = requireString(config, "default_locale");
        this.bookingCentre = requireString(config, "booking_centre");
        this.dataRegion = requireString(config, "data_region");
        this.kmsVaultName = requireString(config, "kms_vault_name");
        this.suitabilityFramework = requireString(config, "suitability_framework");

        this.regulatoryBodies = requireStringList(config, "regulatory_bodies");
        if (this.regulatoryBodies.isEmpty()) {
            throw new IllegalStateException("regulatory_bodies must contain at least one entry.");
        }

        this.disclosureLocaleMap = requireStringMap(config, "disclosure_locale_map");
        if (this.disclosureLocaleMap.isEmpty()) {
            throw new IllegalStateException("disclosure_locale_map must contain at least one entry.");
        }

        // Secrets via Azure Key Vault references - never plaintext
        this.dbConnectionStringRef = "${KEYVAULT:" + this.kmsVaultName + "/db-connection-string}";
        this.apiKeyRef = "${KEYVAULT:" + this.kmsVaultName + "/api-key}";
        this.encryptionKeyRef = "${KEYVAULT:" + this.kmsVaultName + "/encryption-key}";

        this.disclosureText = buildDisclosureText();

        System.out.println("[EntityContext] Initialized for entity: " + this.entityId
                + " (" + this.entityFullName + "), booking centre: " + this.bookingCentre
                + ", data region: " + this.dataRegion
                + ", vault: " + this.kmsVaultName);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> loadYamlConfig(String resourcePath) {
        Yaml yaml = new Yaml();
        try (InputStream is = getClass().getClassLoader().getResourceAsStream(resourcePath)) {
            if (is == null) {
                throw new IllegalStateException(
                        "Entity config not found on classpath: " + resourcePath);
            }
            Object loaded = yaml.load(is);
            if (!(loaded instanceof Map)) {
                throw new IllegalStateException(
                        "Entity config is not a valid YAML map: " + resourcePath);
            }
            return (Map<String, Object>) loaded;
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Failed to read entity config: " + resourcePath, e);
        }
    }

    private void validateRequiredKeys(Map<String, Object> config) {
        List<String> missing = REQUIRED_KEYS.stream()
                .filter(key -> !config.containsKey(key) || config.get(key) == null)
                .toList();
        if (!missing.isEmpty()) {
            throw new IllegalStateException(
                    "Entity config is missing required keys: " + missing);
        }
    }

    private String requireString(Map<String, Object> config, String key) {
        Object val = config.get(key);
        if (val == null || val.toString().isBlank()) {
            throw new IllegalStateException(
                    "Config key '" + key + "' must be a non-blank string.");
        }
        return val.toString();
    }

    private int requireInt(Map<String, Object> config, String key) {
        Object val = config.get(key);
        if (val instanceof Number) {
            return ((Number) val).intValue();
        }
        throw new IllegalStateException(
                "Config key '" + key + "' must be an integer, got: " + val);
    }

    private long requireLong(Map<String, Object> config, String key) {
        Object val = config.get(key);
        if (val instanceof Number) {
            return ((Number) val).longValue();
        }
        throw new IllegalStateException(
                "Config key '" + key + "' must be a long integer, got: " + val);
    }

    @SuppressWarnings("unchecked")
    private List<String> requireStringList(Map<String, Object> config, String key) {
        Object val = config.get(key);
        if (val instanceof List) {
            return ((List<Object>) val).stream()
                    .map(Object::toString)
                    .toList();
        }
        throw new IllegalStateException(
                "Config key '" + key + "' must be a list, got: " + val);
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> requireStringMap(Map<String, Object> config, String key) {
        Object val = config.get(key);
        if (val instanceof Map) {
            Map<String, String> result = new LinkedHashMap<>();
            ((Map<Object, Object>) val).forEach((k, v) ->
                    result.put(k.toString(), v.toString()));
            return Collections.unmodifiableMap(result);
        }
        throw new IllegalStateException(
                "Config key '" + key + "' must be a map, got: " + val);
    }

    /**
     * Builds the disclosure text based on the entity's suitability framework.
     * Preserves the exact original SG text for MAS_FAA_2002.
     */
    private String buildDisclosureText() {
        return switch (this.suitabilityFramework) {
            case "MAS_FAA_2002" ->
                "MAS Notice FAA: Past performance is not indicative of future results.";
            case "SFC_COP_2019" ->
                "SFC Code of Conduct: Past performance is not indicative of future results. Investment involves risk.";
            case "FINMA_LSFin_2020" ->
                "FINMA LSFin: Vergangene Wertentwicklung ist kein Indikator fuer zukuenftige Ergebnisse.";
            default ->
                "Regulatory disclosure (" + this.suitabilityFramework
                + "): Past performance is not indicative of future results.";
        };
    }

    // --- Getters ---

    public String getEntityId() { return entityId; }
    public String getEntityFullName() { return entityFullName; }
    public String getCurrency() { return currency; }
    public int getFeeScheduleBps() { return feeScheduleBps; }
    public long getMinPortfolioThreshold() { return minPortfolioThreshold; }
    public String getDefaultLocale() { return defaultLocale; }
    public String getBookingCentre() { return bookingCentre; }
    public String getDataRegion() { return dataRegion; }
    public String getKmsVaultName() { return kmsVaultName; }
    public String getSuitabilityFramework() { return suitabilityFramework; }
    public List<String> getRegulatoryBodies() { return regulatoryBodies; }
    public Map<String, String> getDisclosureLocaleMap() { return disclosureLocaleMap; }
    public String getDbConnectionStringRef() { return dbConnectionStringRef; }
    public String getApiKeyRef() { return apiKeyRef; }
    public String getEncryptionKeyRef() { return encryptionKeyRef; }
    public String getDisclosureText() { return disclosureText; }

    /**
     * Returns the first regulatory body — used where the original code
     * expected a single "regulator" string (SG baseline compatibility).
     */
    public String getPrimaryRegulator() { return regulatoryBodies.get(0); }
}