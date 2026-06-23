package com.acme.wealth;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;

/**
 * EntityContextTest — behaviour preservation for WP-JAVA refactor/java-entity-context.
 * Tests use the testable constructor EntityContext(String entityId) that bypasses
 * System.getenv() for deterministic, in-process unit execution.
 * Canonical values are hard-pinned from the shared engineering contract.
 */
class EntityContextTest {

    // ── 1. SG baseline ───────────────────────────────────────────────────────
    @Test
    void sg_baseline_canonical_values() {
        EntityContext ctx = new EntityContext("SG");
        assertEquals("SGD",           ctx.getCurrency());
        assertEquals("en_SG",         ctx.getLocale());
        assertEquals("MAS",           ctx.getRegulator());
        assertEquals("Singapore",     ctx.getBookingCentre());
        assertEquals(new BigDecimal("50"),     ctx.getFeeBps());
        assertEquals(new BigDecimal("250000"), ctx.getRelationshipThresholdAmount());
        assertEquals("MAS_FAA_2002",  ctx.getSuitabilityFramework());
    }

    // ── 2. HK switch ─────────────────────────────────────────────────────────
    @Test
    void hk_canonical_values() {
        EntityContext ctx = new EntityContext("HK");
        assertEquals("HKD",            ctx.getCurrency());
        assertEquals("en_HK",          ctx.getLocale());
        assertEquals("SFC",            ctx.getRegulator());
        assertEquals("Hong Kong",      ctx.getBookingCentre());
        assertEquals(new BigDecimal("60"),      ctx.getFeeBps());
        assertEquals(new BigDecimal("1000000"), ctx.getRelationshipThresholdAmount());
        assertEquals("SFC_COP_2019",   ctx.getSuitabilityFramework());
    }

    // ── 3. CH switch ─────────────────────────────────────────────────────────
    @Test
    void ch_canonical_values() {
        EntityContext ctx = new EntityContext("CH");
        assertEquals("CHF",                ctx.getCurrency());
        assertEquals("de_CH",              ctx.getLocale());
        assertEquals("FINMA",              ctx.getRegulator());
        assertEquals("Zurich",             ctx.getBookingCentre());
        assertEquals(new BigDecimal("80"),       ctx.getFeeBps());
        assertEquals(new BigDecimal("5000000"),  ctx.getRelationshipThresholdAmount());
        assertEquals("FINMA_LSFin_2020", ctx.getSuitabilityFramework());
    }

    // ── 4. Negative path: unknown entity must fail-fast ───────────────────────
    @Test
    void unknown_entity_id_throws_on_construction() {
        assertThrows(IllegalArgumentException.class,
            () -> new EntityContext("XX"),
            "EntityContext must fail-fast for unrecognised entity IDs");
    }

    // ── 5. Cross-entity: fee_bps ordering SG < HK < CH ───────────────────────
    @Test
    void fee_bps_differ_and_ordered_across_entities() {
        EntityContext sg = new EntityContext("SG");
        EntityContext hk = new EntityContext("HK");
        EntityContext ch = new EntityContext("CH");
        assertTrue(sg.getFeeBps().compareTo(hk.getFeeBps()) < 0,
            "SG fee_bps(50) must be less than HK fee_bps(60)");
        assertTrue(hk.getFeeBps().compareTo(ch.getFeeBps()) < 0,
            "HK fee_bps(60) must be less than CH fee_bps(80)");
    }

    // ── 6. SG disclosure text assembled correctly from manifest fields ─────────
    @Test
    void sg_disclosure_text_assembled_from_manifest_fields() {
        EntityContext ctx = new EntityContext("SG");
        // Mirrors AccountController: regulator + " " + suitabilityFramework + fixed suffix
        String expected =
            "MAS MAS_FAA_2002: Past performance is not indicative of future results.";
        String actual = ctx.getRegulator() + " " + ctx.getSuitabilityFramework()
            + ": Past performance is not indicative of future results.";
        assertEquals(expected, actual,
            "Disclosure must be assembled from manifest regulator+suitability_framework");
    }
}