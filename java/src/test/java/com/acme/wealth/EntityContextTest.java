package com.acme.wealth;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import java.lang.reflect.Field;
import java.math.BigDecimal;
import java.util.Locale;
import static org.junit.jupiter.api.Assertions.*;

/**
 * QA: EntityContext canonical-value preservation tests.
 * Each test that needs a non-default entity resets the singleton via reflection,
 * sets ENTITY_ID in the environment map, then re-initialises.
 * Tests run sequentially (no parallel) to avoid singleton race.
 */
class EntityContextTest {

    // Resets the EntityContext singleton so the next getInstance() re-initialises.
    private void resetSingletonWithEntity(String entityId) throws Exception {
        // Inject ENTITY_ID into system properties (EntityContext must honour
        // System.getProperty("ENTITY_ID") or System.getenv; we patch property).
        if (entityId == null) {
            System.clearProperty("ENTITY_ID");
        } else {
            System.setProperty("ENTITY_ID", entityId);
        }
        // Reset the static INSTANCE field.
        Field instanceField = EntityContext.class.getDeclaredField("INSTANCE");
        instanceField.setAccessible(true);
        instanceField.set(null, null);
        // Re-trigger static initialisation via getInstance().
        EntityContext.getInstance();
    }

    @BeforeEach
    void restoreSgDefault() throws Exception {
        // Always restore SG after each test so suite order doesn't matter.
        resetSingletonWithEntity("SG");
    }

    // ------------------------------------------------------------------ //
    // TC-1  SG baseline – all canonical values                            //
    // ------------------------------------------------------------------ //
    @Test
    void testSgBaseline_allCanonicalValues() throws Exception {
        resetSingletonWithEntity("SG");
        EntityContext ctx = EntityContext.getInstance();

        assertEquals("SGD",            ctx.getCurrency(),              "SG currency");
        assertEquals(Locale.forLanguageTag("en-SG"), ctx.getJavaLocale(), "SG locale");
        assertEquals("MAS",            ctx.getRegulator(),             "SG regulator");
        assertEquals("Singapore",      ctx.getBookingCentre(),         "SG booking centre");
        assertEquals(new BigDecimal("50"),      ctx.getFeeBps(),               "SG fee_bps");
        assertEquals(new BigDecimal("250000"),  ctx.getLargePositionThreshold(),"SG large_position_threshold");
        assertEquals("MAS_FAA_2002",   ctx.getSuitabilityFramework(),  "SG suitability framework");
        assertEquals("SG",             ctx.getEntityId(),              "SG entity id");
    }

    // ------------------------------------------------------------------ //
    // TC-2  HK switch – currency, regulator, fee_bps                     //
    // ------------------------------------------------------------------ //
    @Test
    void testHkSwitch_currencyRegulatorFeeBps() throws Exception {
        resetSingletonWithEntity("HK");
        EntityContext ctx = EntityContext.getInstance();

        assertEquals("HKD",          ctx.getCurrency(),   "HK currency");
        assertEquals("SFC",          ctx.getRegulator(),  "HK regulator");
        assertEquals(new BigDecimal("60"), ctx.getFeeBps(), "HK fee_bps");
        assertEquals("Hong Kong",    ctx.getBookingCentre(), "HK booking centre");
        assertEquals("SFC_COP_2019", ctx.getSuitabilityFramework(), "HK suitability");
        assertEquals(new BigDecimal("1000000"), ctx.getLargePositionThreshold(), "HK threshold");
    }

    // ------------------------------------------------------------------ //
    // TC-3  CH switch – currency, locale, regulator                      //
    // ------------------------------------------------------------------ //
    @Test
    void testChSwitch_currencyRegulatorLocale() throws Exception {
        resetSingletonWithEntity("CH");
        EntityContext ctx = EntityContext.getInstance();

        assertEquals("CHF",   ctx.getCurrency(),  "CH currency");
        assertEquals("FINMA", ctx.getRegulator(), "CH regulator");
        assertEquals(Locale.forLanguageTag("de-CH"), ctx.getJavaLocale(), "CH locale");
        assertEquals("Zurich", ctx.getBookingCentre(), "CH booking centre");
        assertEquals(new BigDecimal("80"), ctx.getFeeBps(), "CH fee_bps");
        assertEquals(new BigDecimal("5000000"), ctx.getLargePositionThreshold(), "CH threshold");
        assertEquals("FINMA_LSFin_2020", ctx.getSuitabilityFramework(), "CH suitability");
    }

    // ------------------------------------------------------------------ //
    // TC-4  Unknown entity falls back to SG                              //
    // ------------------------------------------------------------------ //
    @Test
    void testUnknownEntityFallsBackToSg() throws Exception {
        // "XX" is not a known entity; expect SG defaults (or graceful fallback).
        try {
            resetSingletonWithEntity("XX");
            EntityContext ctx = EntityContext.getInstance();
            // Acceptable: either falls back to SG values or throws a clear exception.
            // If no exception, must have SG currency as fallback.
            assertEquals("SGD", ctx.getCurrency(), "Unknown entity should fall back to SG currency");
        } catch (ExceptionInInitializerError | RuntimeException e) {
            // Also acceptable: fast-fail with a descriptive error.
            assertTrue(e.getMessage() != null || e.getCause() != null,
                    "Unknown entity must produce a meaningful error");
        } finally {
            resetSingletonWithEntity("SG"); // always restore
        }
    }

    // ------------------------------------------------------------------ //
    // TC-5  SG vs HK large_position_threshold differ                     //
    // ------------------------------------------------------------------ //
    @Test
    void testSgVsHkLargePositionThresholdsDiffer() throws Exception {
        resetSingletonWithEntity("SG");
        BigDecimal sgThreshold = EntityContext.getInstance().getLargePositionThreshold();

        resetSingletonWithEntity("HK");
        BigDecimal hkThreshold = EntityContext.getInstance().getLargePositionThreshold();

        assertEquals(0, sgThreshold.compareTo(new BigDecimal("250000")),  "SG threshold");
        assertEquals(0, hkThreshold.compareTo(new BigDecimal("1000000")), "HK threshold");
        assertTrue(hkThreshold.compareTo(sgThreshold) > 0,
                "HK threshold must be larger than SG threshold");
    }

    // ------------------------------------------------------------------ //
    // TC-6  SG vs CH fee_bps differ                                      //
    // ------------------------------------------------------------------ //
    @Test
    void testSgVsChFeeBpsDiffer() throws Exception {
        resetSingletonWithEntity("SG");
        BigDecimal sgFee = EntityContext.getInstance().getFeeBps();

        resetSingletonWithEntity("CH");
        BigDecimal chFee = EntityContext.getInstance().getFeeBps();

        assertEquals(0, sgFee.compareTo(new BigDecimal("50")), "SG fee_bps=50");
        assertEquals(0, chFee.compareTo(new BigDecimal("80")), "CH fee_bps=80");
        assertTrue(chFee.compareTo(sgFee) > 0, "CH fee must be higher than SG fee");
    }
}