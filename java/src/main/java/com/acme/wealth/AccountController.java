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

    private final EntityContext ctx;

    public AccountController() {
        this.ctx = EntityContext.getInstance();
    }

    // Visible-for-testing constructor
    AccountController(EntityContext ctx) {
        this.ctx = ctx;
    }

    @PostMapping("/value")
    public Map<String, Object> valuePortfolio(@RequestBody Map<String, Object> request) {
        BigDecimal marketValue = new BigDecimal(request.get("marketValue").toString());

        BigDecimal feeRate = ctx.getFeeBps()
                .divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue.multiply(feeRate)
                .setScale(2, RoundingMode.HALF_UP);
        boolean reportable = marketValue.compareTo(ctx.getLargePositionThreshold()) >= 0;

        String disclosure = "";
        if (reportable) {
            switch (ctx.getEntityId()) {
                case "HK" -> disclosure = "SFC Code of Conduct: Past performance is not indicative of future results.";
                case "CH" -> disclosure = "FINMA LSFin: Past performance is not indicative of future results.";
                default   -> disclosure = "MAS Notice FAA: Past performance is not indicative of future results.";
            }
        }

        return Map.ofEntries(
                Map.entry("portfolioId", request.get("portfolioId")),
                Map.entry("entityCode", ctx.getEntityId()),
                Map.entry("currency", ctx.getCurrency()),
                Map.entry("locale", ctx.getLocale()),
                Map.entry("regulator", ctx.getRegulator()),
                Map.entry("bookingCentre", ctx.getBookingCentre()),
                Map.entry("marketValue", marketValue),
                Map.entry("managementFee", managementFee),
                Map.entry("managementFeeBps", ctx.getFeeBps()),
                Map.entry("reportable", reportable),
                Map.entry("disclosure", disclosure)
        );
    }
}