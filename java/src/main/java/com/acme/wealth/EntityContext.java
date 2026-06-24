package com.acme.wealth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.math.BigDecimal;
import java.util.Map;

/**
 * Loads entity-specific configuration from classpath resources/entities/{entityId}.yaml
 * based on the ENTITY_ID environment variable (defaults to "sg" for SG baseline).
 * Validates required fields on startup to enforce region lock.
 */
@Component
public class EntityContext {

    private static final String DEFAULT_ENTITY = "sg";
    private static final java.util.Set<String> ALLOWED_ENTITIES =
            java.util.Set.of("sg", "hk", "ch");

    private final String entityId;
    private final String currency;
    private final String defaultLocale;
    private final String regulator;
    private final String bookingCentre;
    private final BigDecimal advisoryFeeBps;
    private final BigDecimal largePositionThreshold;
    private final String suitabilityFramework;
    private final String kvVaultUri;
    private final String azureRegion;

    @SuppressWarnings("unchecked")
    public EntityContext() {
        String rawId = System.getenv("ENTITY_ID");
        String resolvedId = (rawId != null && !rawId.isBlank())
                ? rawId.trim().toLowerCase()
                : DEFAULT_ENTITY;

        if (!ALLOWED_ENTITIES.contains(resolvedId)) {
            throw new IllegalStateException(
                    "ENTITY_ID '" + resolvedId + "' is not a supported entity. Allowed: " + ALLOWED_ENTITIES);
        }

        String resourcePath = "entities/" + resolvedId + ".yaml";
        InputStream is = getClass().getClassLoader().getResourceAsStream(resourcePath);
        if (is == null) {
            throw new IllegalStateException("Entity config not found on classpath: " + resourcePath);
        }

        try {
            ObjectMapper mapper = new ObjectMapper(new YAMLFactory());
            Map<String, Object> root = mapper.readValue(is, Map.class);

            Map<String, Object> entity       = (Map<String, Object>) root.get("entity");
            Map<String, Object> locale        = (Map<String, Object>) root.get("locale");
            Map<String, Object> regulatory    = (Map<String, Object>) root.get("regulatory");
            Map<String, Object> productRules  = (Map<String, Object>) root.get("product_rules");
            Map<String, Object> infra         = (Map<String, Object>) root.get("infrastructure");

            assertPresent(entity,      "entity");
            assertPresent(locale,      "locale");
            assertPresent(regulatory,  "regulatory");
            assertPresent(productRules,"product_rules");
            assertPresent(infra,       "infrastructure");

            this.entityId              = required(entity, "entity_id").toString();
            this.currency              = required(locale, "currency").toString();
            this.defaultLocale         = required(locale, "default_locale").toString();
            java.util.List<?> regs     = (java.util.List<?>) required(regulatory, "regulators");
            this.regulator             = regs.get(0).toString();
            this.bookingCentre         = required(regulatory, "booking_centre").toString();
            this.advisoryFeeBps        = new BigDecimal(required(productRules, "advisory_fee_bps").toString());
            this.largePositionThreshold= new BigDecimal(required(productRules, "onboarding_threshold_minor_units").toString());
            this.suitabilityFramework  = required(productRules, "suitability_framework").toString();
            this.azureRegion           = required(infra, "azure_region").toString();
            this.kvVaultUri            = required(infra, "kv_vault_uri").toString();

        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("Failed to load entity config: " + resourcePath, e);
        }
    }

    private static void assertPresent(Map<?,?> section, String name) {
        if (section == null) throw new IllegalStateException("Missing config section: " + name);
    }

    private static Object required(Map<String, Object> map, String key) {
        Object val = map.get(key);
        if (val == null) throw new IllegalStateException("Missing required config key: " + key);
        return val;
    }

    public String getEntityId()              { return entityId; }
    public String getCurrency()              { return currency; }
    public String getDefaultLocale()         { return defaultLocale; }
    public String getRegulator()             { return regulator; }
    public String getBookingCentre()         { return bookingCentre; }
    public BigDecimal getAdvisoryFeeBps()    { return advisoryFeeBps; }
    public BigDecimal getLargePositionThreshold() { return largePositionThreshold; }
    public String getSuitabilityFramework()  { return suitabilityFramework; }
    public String getKvVaultUri()            { return kvVaultUri; }
    public String getAzureRegion()           { return azureRegion; }

    /** Returns the entity-specific DB connection secret as a Key Vault reference. */
    public String getDbConnectionSecret() {
        return "${KEYVAULT:wealth-" + entityId.toLowerCase() + "-db-connection-string}";
    }

    /** Returns the regulatory disclosure string for this entity. */
    public String getDisclosure() {
        return suitabilityFramework + ": Past performance is not indicative of future results.";
    }
}