package com.acme.wealth;

import org.springframework.stereotype.Component;
import org.yaml.snakeyaml.Yaml;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class EntityContext {

    private static final Set<String> SUPPORTED = Set.of("SG", "HK", "CH");

    private String entityId;
    private String currency;
    private String locale;
    private String regulator;
    private String bookingCentre;
    private BigDecimal feeBps;
    private BigDecimal largePositionThreshold;
    private String suitabilityFramework;
    private String dbSecretRef;
    private String jwtSecretRef;
    private String encKeyRef;

    @PostConstruct
    public void init() {
        entityId = System.getenv("ENTITY_ID");
        if (entityId == null || entityId.isBlank()) {
            throw new IllegalStateException("ENTITY_ID env var is absent; startup aborted.");
        }
        entityId = entityId.trim().toUpperCase();
        if (!SUPPORTED.contains(entityId)) {
            throw new IllegalStateException(
                "ENTITY_ID '" + entityId + "' not in supported set " + SUPPORTED);
        }

        String path = "entities/" + entityId + ".yaml";
        Yaml yaml = new Yaml();
        InputStream is = getClass().getClassLoader().getResourceAsStream(path);
        if (is == null) {
            throw new IllegalStateException("Entity config not found on classpath: " + path);
        }

        Map<String, Object> cfg = yaml.load(is);
        String cfgEntity = ((String) cfg.get("entity_id")).trim().toUpperCase();
        if (!entityId.equals(cfgEntity)) {
            throw new IllegalStateException(
                "ENTITY_ID '" + entityId + "' mismatches config entity_id '" + cfgEntity + "'");
        }

        currency               = (String) cfg.get("currency");
        locale                 = (String) cfg.get("locales");
        @SuppressWarnings("unchecked")
        List<String> regs      = (List<String>) cfg.get("regulators");
        regulator              = regs.get(0);
        bookingCentre          = (String) cfg.get("booking_centre");
        feeBps                 = new BigDecimal(cfg.get("fee_bps").toString());
        largePositionThreshold = new BigDecimal(cfg.get("large_position_threshold").toString());
        suitabilityFramework   = (String) cfg.get("suitability_framework");

        String vaultName = (String) cfg.get("kms_vault_name");
        String dbSecret  = (String) cfg.get("kv_db_secret_name");
        String jwtSecret = (String) cfg.get("kv_jwt_secret_name");
        String encKey    = (String) cfg.get("kv_encryption_key_name");

        dbSecretRef  = "${KEYVAULT:" + vaultName + "-" + dbSecret + "}";
        jwtSecretRef = "${KEYVAULT:" + vaultName + "-" + jwtSecret + "}";
        encKeyRef    = "${KEYVAULT:" + vaultName + "-" + encKey + "}";
    }

    public String getEntityId()                    { return entityId; }
    public String getCurrency()                    { return currency; }
    public String getLocale()                      { return locale; }
    public String getRegulator()                   { return regulator; }
    public String getBookingCentre()               { return bookingCentre; }
    public BigDecimal getFeeBps()                  { return feeBps; }
    public BigDecimal getLargePositionThreshold()  { return largePositionThreshold; }
    public String getSuitabilityFramework()        { return suitabilityFramework; }
    public String getDbSecretRef()                 { return dbSecretRef; }
    public String getJwtSecretRef()                { return jwtSecretRef; }
    public String getEncryptionKeyRef()            { return encKeyRef; }
}