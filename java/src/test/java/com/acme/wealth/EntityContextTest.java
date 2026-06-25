package com.acme.wealth;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Canonical-value tests for EntityContext.
 * Expected values are hard-pinned from the shared contract.
 * Uses package-private/visible-for-testing surface only.
 */
class EntityContextTest {

    // ----------------------------------------------------------------
    // Helpers: build EntityContext via the package-private factory
    // (assumes EntityContext exposes a static forEntity(String) or
    // we drive via AccountController's test constructor + reflection).
    // We call EntityContext.forEntity(id) -- the natural test seam.
    // If EntityContext only exposes getInstance(), we stub via the
    // AccountController(EntityContext ctx) visible-for-testing ctor.
    // ----------------------------------------------------------------

    private EntityContext sg() { return EntityContext.forEntity("SG"); }
    private EntityContext hk() { return EntityContext.forEntity("HK"); }
    private EntityContext ch() { return EntityContext.forEntity("CH"); }

    // ----------------------------------------------------------------
    // TC-1  SG baseline: currency / locale / regulator / booking_centre
    // ----------------------------------------------------------------
    @Test
    void sgBaseline_currencyLocaleRegulatorBookingCentre() {
        EntityContext ctx = sg();
        assertEquals("SGD",       ctx.getCurrency(),      "SG currency");
        assertEquals("en_SG",     ctx.getLocale(),        "SG locale");
        assertEquals("MAS",       ctx.getRegulator(),     "SG regulator");
        assertEquals("Singapore", ctx.getBookingCentre(), "SG booking centre");
    }

    // ----------------------------------------------------------------
    // TC-2  SG baseline: fee_bps / large_position_threshold
    // ----------------------------------------------------------------
    @Test
    void sgBaseline_feeBpsAndLargePositionThreshold() {
        EntityContext ctx = sg();
        assertEquals(0,
            new BigDecimal("50").compareTo(ctx.getFeeBps()),
            "SG fee_bps must be 50");
        assertEquals(0,
            new BigDecimal("250000").compareTo(ctx.getLargePositionThreshold()),
            "SG large_position_threshold must be 250000");
        assertEquals("SG", ctx.getEntityId(), "SG entity id");
    }

    // ----------------------------------------------------------------
    // TC-3  HK canonical values
    // ----------------------------------------------------------------
    @Test
    void hkEntity_canonicalValues() {
        EntityContext ctx = hk();
        assertEquals("HKD",       ctx.getCurrency(),      "HK currency");
        assertEquals("en_HK",     ctx.getLocale(),        "HK locale");
        assertEquals("SFC",       ctx.getRegulator(),     "HK regulator");
        assertEquals("Hong Kong", ctx.getBookingCentre(), "HK booking centre");
        assertEquals(0,
            new BigDecimal("60").compareTo(ctx.getFeeBps()),
            "HK fee_bps must be 60");
        assertEquals(0,
            new BigDecimal("1000000").compareTo(ctx.getLargePositionThreshold()),
            "HK large_position_threshold must be 1000000");
    }

    // ----------------------------------------------------------------
    // TC-4  CH canonical values
    // ----------------------------------------------------------------
    @Test
    void chEntity_canonicalValues() {
        EntityContext ctx = ch();
        assertEquals("CHF",    ctx.getCurrency(),      "CH currency");
        assertEquals("de_CH",  ctx.getLocale(),        "CH locale");
        assertEquals("FINMA",  ctx.getRegulator(),     "CH regulator");
        assertEquals("Zurich", ctx.getBookingCentre(), "CH booking centre");
        assertEquals(0,
            new BigDecimal("80").compareTo(ctx.getFeeBps()),
            "CH fee_bps must be 80");
        assertEquals(0,
            new BigDecimal("5000000").compareTo(ctx.getLargePositionThreshold()),
            "CH large_position_threshold must be 5000000");
    }

    // ----------------------------------------------------------------
    // TC-5  Unknown entity ID defaults / falls back to SG
    // ----------------------------------------------------------------
    @Test
    void unknownEntityId_fallsBackToSg() {
        // The engineer stated "defaults to SG" for unrecognised env var.
        EntityContext ctx = EntityContext.forEntity("XX");
        assertEquals("SG",  ctx.getEntityId(),  "Unknown entity must fall back to SG id");
        assertEquals("SGD", ctx.getCurrency(),   "Fallback currency must be SGD");
        assertEquals(0,
            new BigDecimal("50").compareTo(ctx.getFeeBps()),
            "Fallback fee_bps must be 50 (SG)");
    }

    // ----------------------------------------------------------------
    // TC-6  Cross-entity: fee_bps values are all distinct
    //        SG=50 < HK=60 < CH=80
    // ----------------------------------------------------------------
    @Test
    void crossEntity_feeBpsDiffer_sgVsHkVsCh() {
        BigDecimal sgFee = sg().getFeeBps();
        BigDecimal hkFee = hk().getFeeBps();
        BigDecimal chFee = ch().getFeeBps();

        // SG < HK
        assertTrue(sgFee.compareTo(hkFee) < 0,
            "SG fee_bps (50) must be less than HK fee_bps (60)");
        // HK < CH
        assertTrue(hkFee.compareTo(chFee) < 0,
            "HK fee_bps (60) must be less than CH fee_bps (80)");
        // exact values
        assertEquals(0, new BigDecimal("50").compareTo(sgFee), "SG=50");
        assertEquals(0, new BigDecimal("60").compareTo(hkFee), "HK=60");
        assertEquals(0, new BigDecimal("80").compareTo(chFee), "CH=80");
    }
}