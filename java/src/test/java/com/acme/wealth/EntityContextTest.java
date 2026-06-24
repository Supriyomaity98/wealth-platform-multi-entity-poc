package com.acme.wealth;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.math.BigDecimal;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Behaviour-preservation tests for EntityContext + AccountController.
 * Asserts CANONICAL values exactly as supplied to the engineer.
 * JUnit 5 — runs under spring-boot-starter-test (already in pom.xml).
 */
class EntityContextTest {

    @SuppressWarnings("unchecked")
    private static void setEnv(String key, String value) throws Exception {
        try {
            Class<?> clazz = Class.forName("java.lang.ProcessEnvironment");
            Field theEnv = clazz.getDeclaredField("theEnvironment");
            theEnv.setAccessible(true);
            Map<String, String> env = (Map<String, String>) theEnv.get(null);
            Field ciEnvField = clazz.getDeclaredField("theCaseInsensitiveEnvironment");
            ciEnvField.setAccessible(true);
            Map<String, String> ciEnv = (Map<String, String>) ciEnvField.get(null);
            if (value == null) { env.remove(key); ciEnv.remove(key); }
            else { env.put(key, value); ciEnv.put(key, value); }
        } catch (NoSuchFieldException e) {
            Class<?> clazz = Class.forName("java.lang.ProcessEnvironment");
            Field theEnv = clazz.getDeclaredField("theEnvironment");
            theEnv.setAccessible(true);
            Map<String, String> env = (Map<String, String>) theEnv.get(null);
            if (value == null) env.remove(key); else env.put(key, value);
        }
    }

    @AfterEach
    void resetEnv() throws Exception { setEnv("WEALTH_ENTITY_ID", null); }

    // TC-1: SG baseline canonical values
    @Test
    void sgBaselineCanonicalValues() throws Exception {
        setEnv("WEALTH_ENTITY_ID", "SG");
        EntityContext ctx = EntityContext.load();
        assertEquals("SG",        ctx.entityId(),        "entityId");
        assertEquals("SGD",       ctx.currencyCode(),     "currencyCode");
        assertEquals("en_SG",     ctx.defaultLocale(),    "defaultLocale");
        assertEquals("MAS",       ctx.primaryRegulator(), "primaryRegulator");
        assertEquals("Singapore", ctx.bookingCentre(),    "bookingCentre");
        assertEquals(0, new BigDecimal("50").compareTo(ctx.feeBps()),           "feeBps=50");
        assertEquals(0, new BigDecimal("250000").compareTo(ctx.minimumAumThreshold()), "threshold=250000");
    }

    // TC-2: HK canonical values
    @Test
    void hkCanonicalValues() throws Exception {
        setEnv("WEALTH_ENTITY_ID", "HK");
        EntityContext ctx = EntityContext.load();
        assertEquals("HK",        ctx.entityId());
        assertEquals("HKD",       ctx.currencyCode());
        assertEquals("en_HK",     ctx.defaultLocale());
        assertEquals("SFC",       ctx.primaryRegulator());
        assertEquals("Hong Kong", ctx.bookingCentre());
        assertEquals(0, new BigDecimal("60").compareTo(ctx.feeBps()),            "feeBps=60");
        assertEquals(0, new BigDecimal("1000000").compareTo(ctx.minimumAumThreshold()), "threshold=1000000");
    }

    // TC-3: CH canonical values
    @Test
    void chCanonicalValues() throws Exception {
        setEnv("WEALTH_ENTITY_ID", "CH");
        EntityContext ctx = EntityContext.load();
        assertEquals("CH",     ctx.entityId());
        assertEquals("CHF",    ctx.currencyCode());
        assertEquals("de_CH",  ctx.defaultLocale());
        assertEquals("FINMA",  ctx.primaryRegulator());
        assertEquals("Zurich", ctx.bookingCentre());
        assertEquals(0, new BigDecimal("80").compareTo(ctx.feeBps()),            "feeBps=80");
        assertEquals(0, new BigDecimal("5000000").compareTo(ctx.minimumAumThreshold()), "threshold=5000000");
    }

    // TC-4: Missing env-var must throw, not silently default to SG
    @Test
    void missingEntityIdThrows() throws Exception {
        setEnv("WEALTH_ENTITY_ID", null);
        assertThrows(IllegalStateException.class, EntityContext::load,
                "WEALTH_ENTITY_ID absent must throw IllegalStateException");
    }

    // TC-5: fee_bps strictly increases SG(50) < HK(60) < CH(80)
    @Test
    void feeBpsDifferAcrossEntities() throws Exception {
        setEnv("WEALTH_ENTITY_ID", "SG");
        BigDecimal sgFee = EntityContext.load().feeBps();
        setEnv("WEALTH_ENTITY_ID", "HK");
        BigDecimal hkFee = EntityContext.load().feeBps();
        setEnv("WEALTH_ENTITY_ID", "CH");
        BigDecimal chFee = EntityContext.load().feeBps();
        assertTrue(sgFee.compareTo(hkFee) < 0, "SG(50) < HK(60)");
        assertTrue(hkFee.compareTo(chFee) < 0, "HK(60) < CH(80)");
    }

    // TC-6: SG AccountController response shape + fee arithmetic
    @Test
    void sgControllerValueResponseShape() throws Exception {
        setEnv("WEALTH_ENTITY_ID", "SG");
        AccountController controller = new AccountController();
        Map<String, Object> req = Map.of("portfolioId", "P-001", "marketValue", "300000");
        Map<String, Object> resp = controller.valuePortfolio(req);
        assertEquals("SG",        resp.get("entityCode"),    "entityCode dynamic not hardcoded");
        assertEquals("SGD",       resp.get("currency"));
        assertEquals("en_SG",     resp.get("locale"));
        assertEquals("MAS",       resp.get("regulator"));
        assertEquals("Singapore", resp.get("bookingCentre"));
        // 300000 * (50/10000) = 1500.00
        assertEquals(0, new BigDecimal("1500.00")
                .compareTo(new BigDecimal(resp.get("managementFee").toString())),
                "SG fee on 300000 must be 1500.00");
        // 300000 >= 250000 threshold
        assertTrue((Boolean) resp.get("largePositionFlag"), "300000 >= 250000 => large position");
    }
}