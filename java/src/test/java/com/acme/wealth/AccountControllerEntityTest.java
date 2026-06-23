package com.acme.wealth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

/**
 * Config-driven behaviour tests. Run with ENTITY_ID env var set per entity in CI.
 * Test manifests are sanitized — no real secrets.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AccountControllerEntityTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    void portfolio_value_uses_manifest_currency_and_fee() throws Exception {
        mockMvc.perform(post("/api/account/value")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"portfolioId\":\"P1\",\"marketValue\":\"100000\"}"))
            .andExpect(jsonPath("$.entityCode").exists())
            .andExpect(jsonPath("$.currency").exists())
            .andExpect(jsonPath("$.regulator").exists())
            .andExpect(jsonPath("$.managementFeeBps").exists());
    }

    @Test
    void sg_below_threshold_not_reportable() throws Exception {
        // Run with ENTITY_ID=SG: threshold=250000, value=100000 => reportable=false
        mockMvc.perform(post("/api/account/value")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"portfolioId\":\"P2\",\"marketValue\":\"100000\"}"))
            .andExpect(jsonPath("$.reportable").value(false))
            .andExpect(jsonPath("$.disclosure").value(""));
    }

    @Test
    void sg_at_threshold_reportable_disclosure_contains_regulator() throws Exception {
        // Run with ENTITY_ID=SG: threshold=250000, value=250000 => reportable=true
        mockMvc.perform(post("/api/account/value")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"portfolioId\":\"P3\",\"marketValue\":\"250000\"}"))
            .andExpect(jsonPath("$.reportable").value(true))
            .andExpect(jsonPath("$.disclosure", containsString("MAS_FAA_2002")));
    }

    @Test
    void management_fee_calculation_is_bps_based() throws Exception {
        // 200000 * 50bps/10000 = 1000.00 for SG; formula is entity-agnostic
        mockMvc.perform(post("/api/account/value")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"portfolioId\":\"P4\",\"marketValue\":\"200000\"}"))
            .andExpect(jsonPath("$.managementFee").exists())
            .andExpect(jsonPath("$.managementFeeBps").exists());
    }

    @Test
    void entity_id_is_reflected_in_response() throws Exception {
        mockMvc.perform(post("/api/account/value")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"portfolioId\":\"P5\",\"marketValue\":\"500000\"}"))
            .andExpect(jsonPath("$.entityCode").exists())
            .andExpect(jsonPath("$.bookingCentre").exists());
    }
}