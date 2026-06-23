package com.acme.wealth;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.math.RoundingMode;
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

        BigDecimal feeRate = entityContext.getFeeBps()
                .divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue
                .multiply(feeRate)
                .setScale(2, RoundingMode.HALF_UP);

        boolean reportable = marketValue.compareTo(
                entityContext.getRelationshipThresholdAmount()) >= 0;

        String disclosure = reportable
                ? entityContext.getRegulator() + " " + entityContext.getSuitabilityFramework()
                        + ": Past performance is not indicative of future results."
                : "";

        return Map.ofEntries(
                Map.entry("portfolioId",      request.get("portfolioId")),
                Map.entry("entityCode",       entityContext.getEntityId()),
                Map.entry("currency",         entityContext.getCurrency()),
                Map.entry("locale",           entityContext.getLocalePrimary()),
                Map.entry("regulator",        entityContext.getRegulator()),
                Map.entry("bookingCentre",    entityContext.getBookingCentre()),
                Map.entry("marketValue",      marketValue),
                Map.entry("managementFee",    managementFee),
                Map.entry("managementFeeBps", entityContext.getFeeBps()),
                Map.entry("reportable",       reportable),
                Map.entry("disclosure",       disclosure)
        );
    }
}