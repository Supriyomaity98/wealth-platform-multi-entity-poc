package com.acme.wealth;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/account")
public class AccountController {

    private final EntityContext entityContext;

    public AccountController(EntityContext entityContext) {
        this.entityContext = entityContext;
    }

    @PostMapping("/value")
    public Map<String, Object> valuePortfolio(@RequestBody Map<String, Object> request) {
        BigDecimal marketValue = new BigDecimal(request.get("marketValue").toString());

        // Resolve applicable fee tier from entity config fee schedule
        BigDecimal feeBps = resolveFeeBps(marketValue);
        BigDecimal feeRate = feeBps.divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue.multiply(feeRate).setScale(2, RoundingMode.HALF_UP);

        BigDecimal portfolioMinimum = entityContext.getPortfolioMinimumAmount();
        boolean reportable = marketValue.compareTo(portfolioMinimum) >= 0;

        String disclosure = reportable
                ? buildDisclosure()
                : "";

        // Use LinkedHashMap to preserve insertion order
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("portfolioId", request.get("portfolioId"));
        result.put("entityCode", entityContext.getEntityId());
        result.put("currency", entityContext.getCurrency().getCurrencyCode());
        result.put("locale", entityContext.getPrimaryLocale().toString());
        result.put("regulator", entityContext.getPrimaryRegulator());
        result.put("bookingCentre", entityContext.getDataRegionDisplay());
        result.put("marketValue", marketValue);
        result.put("managementFee", managementFee);
        result.put("managementFeeBps", feeBps);
        result.put("reportable", reportable);
        result.put("disclosure", disclosure);

        return result;
    }

    /**
     * Walk the fee schedule tiers in order; return the fee_bps for the first tier
     * whose range contains the given market value. Falls back to the last tier.
     */
    private BigDecimal resolveFeeBps(BigDecimal marketValue) {
        List<Map<String, Object>> feeSchedule = entityContext.getFeeSchedule();
        for (Map<String, Object> tier : feeSchedule) {
            BigDecimal minAmount = new BigDecimal(tier.getOrDefault("threshold_min_amount", "0").toString());
            Object maxObj = tier.get("threshold_max_amount");
            if (maxObj != null) {
                BigDecimal maxAmount = new BigDecimal(maxObj.toString());
                if (marketValue.compareTo(minAmount) >= 0 && marketValue.compareTo(maxAmount) <= 0) {
                    return new BigDecimal(tier.get("fee_bps").toString());
                }
            } else {
                // No upper bound — this tier matches if value >= min
                if (marketValue.compareTo(minAmount) >= 0) {
                    return new BigDecimal(tier.get("fee_bps").toString());
                }
            }
        }
        // Fallback: last tier
        return new BigDecimal(feeSchedule.get(feeSchedule.size() - 1).get("fee_bps").toString());
    }

    /**
     * Build a disclosure string driven by entity config: regulator + suitability framework.
     */
    private String buildDisclosure() {
        String framework = entityContext.getSuitabilityFramework();
        String primaryRegulator = entityContext.getPrimaryRegulator();
        return primaryRegulator + " Notice " + framework + ": Past performance is not indicative of future results.";
    }
}