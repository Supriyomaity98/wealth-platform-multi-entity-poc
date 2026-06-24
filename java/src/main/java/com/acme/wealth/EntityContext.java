package com.acme.wealth;

import org.yaml.snakeyaml.Yaml;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.Map;

public final class EntityContext {

    private static final String ENV_VAR     = "WEALTH_ENTITY_ID";
    private static final String CONFIG_BASE = "/etc/wealth/config/entity-%s.yaml";

    private final String entityId;
    private final String currencyCode;
    private final String defaultLocale;
    private final BigDecimal feeBps;
    private final BigDecimal minimumAumThreshold;
    private final String dataRegion;
    private final String keyVaultName;
    private final String suitabilityFramework;
    private final String disclosureLocale;
    private final String primaryRegulator;
    private final String bookingCentre;
    private final String dbPasswordKeyVaultRef;

    private EntityContext(Map<String, Object> cfg, String id) {
        this.entityId             = id;
        this.currencyCode         = require(cfg, "currency_code");
        this.defaultLocale        = require(cfg, "default_locale");
        this.feeBps               = new BigDecimal(require(cfg, "fee_bps"));
        this.minimumAumThreshold  = new BigDecimal(require(cfg, "minimum_aum_threshold"));
        this.dataRegion           = require(cfg, "data_region");
        this.keyVaultName         = require(cfg, "key_vault_name");
        this.suitabilityFramework = require(cfg, "suitability_framework");
        this.disclosureLocale     = require(cfg, "disclosure_locale");
        this.primaryRegulator     = require(cfg, "primary_regulator");
        this.bookingCentre        = require(cfg, "booking_centre");
        this.dbPasswordKeyVaultRef =
                "${KEYVAULT:wealth-" + id.toLowerCase() + "-db-password}";
    }

    public static EntityContext load() {
        String id = System.getenv(ENV_VAR);
        if (id == null || id.isBlank()) {
            throw new IllegalStateException(
                    ENV_VAR + " environment variable is mandatory but not set.");
        }
        String path = String.format(CONFIG_BASE, id.toUpperCase());
        try (InputStream is = new FileInputStream(path)) {
            Yaml yaml = new Yaml();
            Map<String, Object> cfg = yaml.load(is);
            if (cfg == null || cfg.isEmpty()) {
                throw new IllegalStateException("Entity config is empty: " + path);
            }
            return new EntityContext(cfg, id.toUpperCase());
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Cannot load entity config from " + path, e);
        }
    }

    private static String require(Map<String, Object> cfg, String key) {
        Object v = cfg.get(key);
        if (v == null) {
            throw new IllegalStateException("Missing required config key: " + key);
        }
        return v.toString();
    }

    public String disclosureText() {
        return suitabilityFramework
                + ": Past performance is not indicative of future results.";
    }

    public String entityId()             { return entityId; }
    public String currencyCode()         { return currencyCode; }
    public String defaultLocale()        { return defaultLocale; }
    public BigDecimal feeBps()           { return feeBps; }
    public BigDecimal minimumAumThreshold() { return minimumAumThreshold; }
    public String dataRegion()           { return dataRegion; }
    public String keyVaultName()         { return keyVaultName; }
    public String suitabilityFramework() { return suitabilityFramework; }
    public String disclosureLocale()     { return disclosureLocale; }
    public String primaryRegulator()     { return primaryRegulator; }
    public String bookingCentre()        { return bookingCentre; }
    public String dbPasswordKeyVaultRef(){ return dbPasswordKeyVaultRef; }
}