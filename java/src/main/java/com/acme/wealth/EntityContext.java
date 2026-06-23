package com.acme.wealth;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.Currency;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

/**
 * Immutable entity configuration loaded once at bootstrap.
 * <p>
 * The entity is determined by the {@code ENTITY_ID} environment variable (or
 * {@code entity.id} system property). The matching YAML file is loaded from
 * {@code config/entity/{ENTITY_ID}.yaml}. All values are frozen after
 * {@link #init()} completes — ENTITY_ID is immutable post-bootstrap.
 * </p>
 * <p>
 * Secrets are never stored in the YAML. Any secret reference uses the Azure
 * Key Vault placeholder pattern {@code ${KEYVAULT:wealth-{entity}-[secret-name]}}.
 * </p>
 */
@Component
public final class EntityContext {

    // ---- Immutable fields populated at boot ----
    private String entityId;
    private Currency currency;
    private Locale primaryLocale;
    private List<String> supportedLocales;
    private List<Map<String, Object>> feeSchedule;
    private BigDecimal portfolioMinimumAmount;
    private String portfolioMinimumCurrency;
    private String dataRegion;
    private String kmsVaultName;
    private List<String> regulators;
    private String suitabilityFramework;
    private List<String> disclosureLocales;
    private String auditSiemWorkspace;
    private String dataResidencyRule;

    private volatile boolean initialized = false;

    /** Mapping from data_region slug to human-readable display name. */
    private static final Map<String, String> REGION_DISPLAY_NAMES = Map.of(
            "azure-southeast-asia", "Singapore",
            "azure-east-asia", "Hong Kong",
            "azure-switzerland-north", "Switzerland"
    );

    @PostConstruct
    @SuppressWarnings("unchecked")
    void init() {
        if (initialized) {
            throw new IllegalStateException("EntityContext is already initialized — ENTITY_ID is immutable post-bootstrap.");
        }

        // Resolve entity ID: env var first, then system property, default SG for baseline preservation
        String id = System.getenv("ENTITY_ID");
        if (id == null || id.isBlank()) {
            id = System.getProperty("entity.id", "SG");
        }
        id = id.trim().toUpperCase();

        Map<String, Object> root = loadYaml(id);
        Map<String, Object> entity = (Map<String, Object>) root.get("entity");
        Objects.requireNonNull(entity, "entity key missing from config YAML for " + id);

        this.entityId = entity.get("id").toString();
        this.currency = Currency.getInstance(entity.get("currency").toString());

        Map<String, Object> localeMap = (Map<String, Object>) entity.get("locale");
        String localeStr = localeMap.get("primary").toString();
        String[] localeParts = localeStr.split("_");
        this.primaryLocale = localeParts.length >= 2
                ? new Locale(localeParts[0], localeParts[1])
                : new Locale(localeParts[0]);

        this.supportedLocales = Collections.unmodifiableList((List<String>) localeMap.get("supported"));

        this.feeSchedule = Collections.unmodifiableList((List<Map<String, Object>>) entity.get("fee_schedule"));

        Map<String, Object> portMin = (Map<String, Object>) entity.get("portfolio_minimum");
        this.portfolioMinimumAmount = new BigDecimal(portMin.get("amount").toString());
        this.portfolioMinimumCurrency = portMin.get("currency").toString();

        this.dataRegion = entity.get("data_region").toString();
        this.kmsVaultName = entity.get("kms_vault_name").toString();
        this.regulators = Collections.unmodifiableList((List<String>) entity.get("regulator"));
        this.suitabilityFramework = entity.get("suitability_framework").toString();
        this.disclosureLocales = Collections.unmodifiableList((List<String>) entity.get("disclosure_locale"));
        this.auditSiemWorkspace = entity.get("audit_siem_workspace").toString();
        this.dataResidencyRule = entity.get("data_residency_rule").toString();

        this.initialized = true;
    }

    // ---- YAML loader ----

    @SuppressWarnings("unchecked")
    private Map<String, Object> loadYaml(String entityId) {
        Yaml yaml = new Yaml();

        // 1. Try filesystem path config/entity/{ID}.yaml (production layout)
        Path fsPath = Path.of("config", "entity", entityId + ".yaml");
        if (Files.isReadable(fsPath)) {
            try (InputStream is = Files.newInputStream(fsPath)) {
                return yaml.load(is);
            } catch (IOException e) {
                throw new RuntimeException("Failed to read entity config from " + fsPath, e);
            }
        }

        // 2. Try classpath (for tests / fat-jar)
        String cpResource = "/config/entity/" + entityId + ".yaml";
        try (InputStream is = getClass().getResourceAsStream(cpResource)) {
            if (is != null) {
                return yaml.load(is);
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to read entity config from classpath " + cpResource, e);
        }

        throw new IllegalStateException("No entity config found for ENTITY_ID=" + entityId
                + ". Searched: " + fsPath.toAbsolutePath() + " and classpath:" + cpResource);
    }

    // ---- Immutable accessors ----

    public String getEntityId() {
        assertInitialized();
        return entityId;
    }

    public Currency getCurrency() {
        assertInitialized();
        return currency;
    }

    public Locale getPrimaryLocale() {
        assertInitialized();
        return primaryLocale;
    }

    public List<String> getSupportedLocales() {
        assertInitialized();
        return supportedLocales;
    }

    public List<Map<String, Object>> getFeeSchedule() {
        assertInitialized();
        return feeSchedule;
    }

    public BigDecimal getPortfolioMinimumAmount() {
        assertInitialized();
        return portfolioMinimumAmount;
    }

    public String getPortfolioMinimumCurrency() {
        assertInitialized();
        return portfolioMinimumCurrency;
    }

    public String getDataRegion() {
        assertInitialized();
        return dataRegion;
    }

    /**
     * Human-readable display name derived from the data_region slug.
     */
    public String getDataRegionDisplay() {
        assertInitialized();
        return REGION_DISPLAY_NAMES.getOrDefault(dataRegion, dataRegion);
    }

    public String getKmsVaultName() {
        assertInitialized();
        return kmsVaultName;
    }

    public List<String> getRegulators() {
        assertInitialized();
        return regulators;
    }

    /**
     * Returns the first (primary) regulator from the list.
     */
    public String getPrimaryRegulator() {
        assertInitialized();
        return regulators.get(0);
    }

    public String getSuitabilityFramework() {
        assertInitialized();
        return suitabilityFramework;
    }

    public List<String> getDisclosureLocales() {
        assertInitialized();
        return disclosureLocales;
    }

    public String getAuditSiemWorkspace() {
        assertInitialized();
        return auditSiemWorkspace;
    }

    public String getDataResidencyRule() {
        assertInitialized();
        return dataResidencyRule;
    }

    /**
     * Azure Key Vault reference for the given secret name, following the
     * shared contract pattern: {@code ${KEYVAULT:wealth-{entity}-[secret-name]}}.
     */
    public String keyVaultRef(String secretName) {
        assertInitialized();
        return "${KEYVAULT:wealth-" + entityId.toLowerCase() + "-" + secretName + "}";
    }

    private void assertInitialized() {
        if (!initialized) {
            throw new IllegalStateException("EntityContext not yet initialized.");
        }
    }
}