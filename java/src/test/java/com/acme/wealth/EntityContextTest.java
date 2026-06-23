package com.acme.wealth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Behaviour-preservation and multi-entity tests for the refactored
 * EntityContext + AccountController.
 *
 * SG baseline tests assert that every value formerly hardcoded in
 * AccountController is now returned identically from EntityContext / YAML.
 * HK and CH tests verify multi-tier fee schedules and correct config loading.
 */
class EntityContextTest {

    // =====================================================================
    //  Helper: build an EntityContext for an arbitrary entity ID without
    //  requiring the Spring container or real environment variables.
    //  Tries, in order:
    //    1. A constructor that accepts a String entity ID directly.
    //    2. Default constructor + reflective field set + @PostConstruct /
    //       init()-style bootstrap method.
    // =====================================================================

    private static EntityContext buildEntityContextForId(String entityId) {
        try {
            // Strategy 1 – single-arg String constructor
            try {
                var ctor = EntityContext.class.getDeclaredConstructor(String.class);
                ctor.setAccessible(true);
                return ctor.newInstance(entityId);
            } catch (NoSuchMethodException ignored) { }

            // Strategy 2 – default ctor + reflection
            EntityContext ctx = EntityContext.class.getDeclaredConstructor().newInstance();

            // Set the entityId / ENTITY_ID field
            for (Field f : EntityContext.class.getDeclaredFields()) {
                String name = f.getName().toLowerCase();
                if ((name.contains("entity") || name.contains("id")) && f.getType() == String.class) {
                    f.setAccessible(true);
                    f.set(ctx, entityId);
                    break;
                }
            }

            // Invoke bootstrap / init method
            for (String mName : List.of("init", "initialize", "postConstruct", "afterPropertiesSet", "load")) {
                try {
                    Method m = EntityContext.class.getDeclaredMethod(mName);
                    m.setAccessible(true);
                    m.invoke(ctx);
                    return ctx;
                } catch (NoSuchMethodException ignored) { }
            }

            // Maybe the no-arg constructor already loaded defaults (SG)
            if (ctx.getCurrency() != null) return ctx;

            throw new RuntimeException("Unable to bootstrap EntityContext for " + entityId);
        } catch (RuntimeException re) {
            throw re;
        } catch (Exception ex) {
            throw new RuntimeException("Failed to build EntityContext for " + entityId, ex);
        }
    }

    /** Reflectively call the package-private resolveFeeBps(BigDecimal). */
    private static BigDecimal invokeResolveFeeBps(AccountController ctrl, BigDecimal marketValue) {
        try {
            Method m = AccountController.class.getDeclaredMethod("resolveFeeBps", BigDecimal.class);
            m.setAccessible(true);
            return (BigDecimal) m.invoke(ctrl, marketValue);
        } catch (Exception e) {
            throw new RuntimeException("Cannot invoke resolveFeeBps", e);
        }
    }

    // =====================================================================
    //  1. SG BASELINE – every formerly-hardcoded constant must survive
    // =====================================================================

    @Nested
    class SgBaselinePreservation {

        private EntityContext sg;

        @BeforeEach
        void setUp() {
            sg = buildEntityContextForId("SG");
        }

        @Test
        void currencyIsSGD() {
            assertEquals("SGD", sg.getCurrency(),
                    "Pre-refactor hardcode: CURRENCY = \"SGD\"");
        }

        @Test
        void localeIsEnSG() {
            assertEquals("en_SG", sg.getLocale(),
                    "Pre-refactor hardcode: LOCALE = \"en_SG\"");
        }

        @Test
        void regulatorIsMAS() {
            assertEquals("MAS", sg.getRegulator(),
                    "Pre-refactor hardcode: REGULATOR = \"MAS\"");
        }

        @Test
        void bookingCentreIsSingapore() {
            assertEquals("Singapore", sg.getBookingCentre(),
                    "Pre-refactor hardcode: BOOKING_CENTRE = \"Singapore\"");
        }

        @Test
        void feeScheduleIsSingleTierOf50Bps() {
            List<Map<String, Object>> schedule = sg.getFeeSchedule();
            assertNotNull(schedule);
            assertEquals(1, schedule.size(),
                    "SG must have exactly 1 fee tier (flat fee preserved)");
            Number bps = (Number) schedule.get(0).get("bps");
            assertEquals(50, bps.intValue(),
                    "Pre-refactor hardcode: MGMT_FEE_BPS = 50");
        }

        @Test
        void portfolioMinimumIsPositive() {
            BigDecimal min = sg.getPortfolioMinimumAmount();
            assertNotNull(min, "LARGE_POSITION_THRESHOLD replacement must be present");
            assertTrue(min.compareTo(BigDecimal.ZERO) > 0);
        }
    }

    // =====================================================================
    //  2. TIERED FEE RESOLUTION (resolveFeeBps)
    // =====================================================================

    @Nested
    class FeeResolution {

        @Test
        void sgAlwaysReturns50BpsRegardlessOfSize() {
            AccountController ctrl = new AccountController(buildEntityContextForId("SG"));
            for (String mv : List.of("1", "100000", "5000000", "99999999")) {
                BigDecimal bps = invokeResolveFeeBps(ctrl, new BigDecimal(mv));
                assertEquals(0, bps.stripTrailingZeros().compareTo(new BigDecimal("50")),
                        "SG flat 50 bps for mv=" + mv);
            }
        }

        @Test
        void hkResolvesToPositiveBps() {
            AccountController ctrl = new AccountController(buildEntityContextForId("HK"));
            BigDecimal bps = invokeResolveFeeBps(ctrl, new BigDecimal("500000"));
            assertNotNull(bps);
            assertTrue(bps.compareTo(BigDecimal.ZERO) > 0);
        }

        @Test
        void chResolvesToPositiveBps() {
            AccountController ctrl = new AccountController(buildEntityContextForId("CH"));
            BigDecimal bps = invokeResolveFeeBps(ctrl, new BigDecimal("500000"));
            assertNotNull(bps);
            assertTrue(bps.compareTo(BigDecimal.ZERO) > 0);
        }

        @Test
        void feeNeverNullAcrossAllEntitiesAndValues() {
            for (String id : List.of("SG", "HK", "CH")) {
                AccountController ctrl = new AccountController(buildEntityContextForId(id));
                for (String mv : List.of("0", "1", "250000", "1000000", "10000000")) {
                    BigDecimal bps = invokeResolveFeeBps(ctrl, new BigDecimal(mv));
                    assertNotNull(bps, id + " bps null for mv=" + mv);
                    assertTrue(bps.compareTo(BigDecimal.ZERO) >= 0,
                            id + " negative bps for mv=" + mv);
                }
            }
        }
    }

    // =====================================================================
    //  3. END-TO-END: valuePortfolio response shape & SG arithmetic
    // =====================================================================

    @Nested
    class ValuePortfolioEndToEnd {

        private AccountController sgCtrl;

        @BeforeEach
        void setUp() {
            sgCtrl = new AccountController(buildEntityContextForId("SG"));
        }

        @Test
        void responseContainsAllContractKeys() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1000000"));
            for (String key : List.of("currency", "marketValue", "managementFee",
                    "feeBps", "reportable", "disclosure", "bookingCentre")) {
                assertTrue(resp.containsKey(key), "Missing key: " + key);
            }
        }

        @Test
        void responseIsLinkedHashMap() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1"));
            assertInstanceOf(LinkedHashMap.class, resp,
                    "Insertion-order preservation requires LinkedHashMap");
        }

        @Test
        void sgCurrencyInResponseIsSGD() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1000000"));
            assertEquals("SGD", resp.get("currency"));
        }

        @Test
        void sgBookingCentreInResponseIsSingapore() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1000000"));
            assertEquals("Singapore", resp.get("bookingCentre"));
        }

        @Test
        void sgManagementFeeArithmetic() {
            // 1,000,000 * 50/10000 = 5000.00
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1000000"));
            BigDecimal fee = new BigDecimal(resp.get("managementFee").toString());
            assertEquals(new BigDecimal("5000.00"), fee,
                    "1M * 50 bps = 5 000.00 (pre-refactor parity)");
        }

        @Test
        void sgFeeBpsInResponseIs50() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1000000"));
            BigDecimal bps = new BigDecimal(resp.get("feeBps").toString());
            assertEquals(0, bps.compareTo(new BigDecimal("50")));
        }

        @Test
        void reportablePositionIncludesMASDisclosure() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "999999999"));
            if (Boolean.TRUE.equals(resp.get("reportable"))) {
                String d = resp.get("disclosure").toString();
                assertTrue(d.contains("MAS"), "Disclosure must cite MAS regulator");
                assertTrue(d.contains("Past performance is not indicative of future results"),
                        "Standard disclaimer text must be present");
            }
        }

        @Test
        void nonReportablePositionHasEmptyDisclosure() {
            Map<String, Object> resp = sgCtrl.valuePortfolio(Map.of("marketValue", "1"));
            if (Boolean.FALSE.equals(resp.get("reportable"))) {
                assertEquals("", resp.get("disclosure"));
            }
        }
    }

    // =====================================================================
    //  4. MULTI-ENTITY CONFIG CORRECTNESS
    // =====================================================================

    @Nested
    class MultiEntityConfig {

        @Test
        void hkCurrencyHKD()   { assertEquals("HKD",   buildEntityContextForId("HK").getCurrency()); }

        @Test
        void hkRegulatorSFC()  { assertEquals("SFC",   buildEntityContextForId("HK").getRegulator()); }

        @Test
        void chCurrencyCHF()   { assertEquals("CHF",   buildEntityContextForId("CH").getCurrency()); }

        @Test
        void chRegulatorFINMA(){ assertEquals("FINMA", buildEntityContextForId("CH").getRegulator()); }

        @Test
        void hkHasMultipleTiers() {
            assertTrue(buildEntityContextForId("HK").getFeeSchedule().size() > 1,
                    "HK entity must define multi-tier fee schedule");
        }

        @Test
        void chHasMultipleTiers() {
            assertTrue(buildEntityContextForId("CH").getFeeSchedule().size() > 1,
                    "CH entity must define multi-tier fee schedule");
        }

        @Test
        void allEntitiesGettersNonNull() {
            for (String id : List.of("SG", "HK", "CH")) {
                EntityContext ctx = buildEntityContextForId(id);
                assertNotNull(ctx.getCurrency(),              id + ".currency");
                assertNotNull(ctx.getLocale(),                id + ".locale");
                assertNotNull(ctx.getRegulator(),             id + ".regulator");
                assertNotNull(ctx.getBookingCentre(),         id + ".bookingCentre");
                assertNotNull(ctx.getFeeSchedule(),           id + ".feeSchedule");
                assertNotNull(ctx.getPortfolioMinimumAmount(),id + ".portfolioMinimum");
            }
        }

        @Test
        void everyTierContainsBpsKey() {
            for (String id : List.of("SG", "HK", "CH")) {
                for (Map<String, Object> tier : buildEntityContextForId(id).getFeeSchedule()) {
                    assertTrue(tier.containsKey("bps"), id + " tier missing 'bps'");
                }
            }
        }
    }

    // =====================================================================
    //  5. ISO FORMAT & ERROR PATHS
    // =====================================================================

    @Nested
    class IsoAndErrorPaths {

        @Test
        void allCurrenciesThreeLetterUpperCase() {
            for (String id : List.of("SG", "HK", "CH")) {
                assertTrue(buildEntityContextForId(id).getCurrency().matches("^[A-Z]{3}$"),
                        id + " currency must be ISO 4217");
            }
        }

        @Test
        void allLocalesMatchLlCC() {
            for (String id : List.of("SG", "HK", "CH")) {
                assertTrue(buildEntityContextForId(id).getLocale().matches("^[a-z]{2}_[A-Z]{2}$"),
                        id + " locale must match ll_CC");
            }
        }

        @Test
        void unknownEntityThrows() {
            assertThrows(Exception.class,
                    () -> buildEntityContextForId("NONEXISTENT_ZZ"),
                    "Missing YAML must cause a failure");
        }
    }
}