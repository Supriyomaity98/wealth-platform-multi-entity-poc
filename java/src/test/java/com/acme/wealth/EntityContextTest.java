package com.acme.wealth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;

import java.math.BigDecimal;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"ENTITY_ID=SG"})
class EntityContextTest {

    @Autowired
    private EntityContext entityContext;

    @Autowired
    private TestRestTemplate restTemplate;

    // TC1 – SG baseline: every canonical field matches hard-pinned contract
    @Test
    void sgBaseline_allCanonicalValues() {
        assertEquals("SGD",           entityContext.getCurrency());
        assertEquals("en_SG",         entityContext.getLocale());
        assertEquals("MAS",           entityContext.getRegulator());
        assertEquals("Singapore",     entityContext.getBookingCentre());
        assertEquals(new BigDecimal("50"),     entityContext.getFeeBps());
        assertEquals(new BigDecimal("250000"), entityContext.getLargePositionThreshold());
        assertEquals("MAS_FAA_2002",  entityContext.getSuitabilityFramework());
    }

    // TC2 – SG /api/account/value: fee arithmetic + disclosure string preserved
    @Test
    void sgBaseline_valuePortfolio_feeAndDisclosure() {
        Map<String, Object> req = Map.of("portfolioId", "P001", "marketValue", "500000");
        ResponseEntity<Map> resp =
                restTemplate.postForEntity("/api/account/value", req, Map.class);
        assertTrue(resp.getStatusCode().is2xxSuccessful());
        Map<?, ?> body = resp.getBody();
        assertNotNull(body);
        // 500000 * 50/10000 = 2500.00
        assertEquals("2500.00", body.get("managementFee").toString());
        // large position (500000 >= 250000) => disclosure present
        String disc = body.get("disclosure").toString();
        assertTrue(disc.startsWith("MAS_FAA_2002"),
                "disclosure must start with SG suitability framework");
        assertTrue(disc.contains("Past performance is not indicative of future results."),
                "residual hardcoded disclosure suffix must still be present");
        assertEquals("SGD", body.get("currency").toString());
        assertEquals("SG",  body.get("entityCode").toString());
    }

    // TC3 – HK canonical values via direct EntityContext construction
    @Test
    void hkEntity_canonicalValues() {
        EntityContext hk = new EntityContext("HK");
        assertEquals("HKD",           hk.getCurrency());
        assertEquals("en_HK",         hk.getLocale());
        assertEquals("SFC",           hk.getRegulator());
        assertEquals("Hong Kong",     hk.getBookingCentre());
        assertEquals(new BigDecimal("60"),      hk.getFeeBps());
        assertEquals(new BigDecimal("1000000"), hk.getLargePositionThreshold());
        assertEquals("SFC_COP_2019",  hk.getSuitabilityFramework());
    }

    // TC4 – CH canonical values via direct EntityContext construction
    @Test
    void chEntity_canonicalValues() {
        EntityContext ch = new EntityContext("CH");
        assertEquals("CHF",              ch.getCurrency());
        assertEquals("de_CH",            ch.getLocale());
        assertEquals("FINMA",            ch.getRegulator());
        assertEquals("Zurich",           ch.getBookingCentre());
        assertEquals(new BigDecimal("80"),       ch.getFeeBps());
        assertEquals(new BigDecimal("5000000"),  ch.getLargePositionThreshold());
        assertEquals("FINMA_LSFin_2020", ch.getSuitabilityFramework());
    }

    // TC5 – blank ENTITY_ID must fail fast with IllegalStateException
    @Test
    void missingEntityId_failsFast() {
        assertThrows(IllegalStateException.class, () -> new EntityContext(""));
    }

    // TC6 – SG vs HK: every financial field must differ (no accidental YAML copy-paste)
    @Test
    void crossEntity_sgAndHkAllFinancialFieldsDiffer() {
        EntityContext sg = new EntityContext("SG");
        EntityContext hk = new EntityContext("HK");
        assertNotEquals(sg.getFeeBps(),                hk.getFeeBps());
        assertNotEquals(sg.getLargePositionThreshold(), hk.getLargePositionThreshold());
        assertNotEquals(sg.getCurrency(),              hk.getCurrency());
        assertNotEquals(sg.getRegulator(),             hk.getRegulator());
        assertNotEquals(sg.getSuitabilityFramework(),  hk.getSuitabilityFramework());
    }
}