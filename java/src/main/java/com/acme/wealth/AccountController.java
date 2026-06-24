package com.acme.wealth;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Currency;
import java.util.Locale;
import java.util.Map;

@RestController
@RequestMapping("/api/account")
public class AccountController {

    private final EntityContext ctx = EntityContext.getInstance();

    private final Currency currency = Currency.getInstance(ctx.getCurrency());
    private final Locale locale = ctx.getJavaLocale();
    private final String regulator = ctx.getRegulator();
    private final String bookingCentre = ctx.getBookingCentre();
    private final BigDecimal mgmtFeeBps = ctx.getFeeBps();
    private final BigDecimal largePositionThreshold = ctx.getLargePositionThreshold();
    private final String entityId = ctx.getEntityId();
    private final String suitabilityFramework = ctx.getSuitabilityFramework();
    private final String disclosureLocale = ctx.getDisclosureLocale();

    @PostMapping("/value")
    public Map<String, Object> valuePortfolio(@RequestBody Map<String, Object> request) {
        BigDecimal marketValue = new BigDecimal(request.get("marketValue").toString());

        BigDecimal feeRate = mgmtFeeBps.divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue.multiply(feeRate).setScale(2, RoundingMode.HALF_UP);
        boolean reportable = marketValue.compareTo(largePositionThreshold) >= 0;

        return Map.ofEntries(
                Map.entry("portfolioId", request.get("portfolioId")),
                Map.entry("entityCode", entityId),
                Map.entry("currency", currency.getCurrencyCode()),
                Map.entry("locale", locale.toString()),
                Map.entry("regulator", regulator),
                Map.entry("bookingCentre", bookingCentre),
                Map.entry("marketValue", marketValue),
                Map.entry("managementFee", managementFee),
                Map.entry("managementFeeBps", mgmtFeeBps),
                Map.entry("reportable", reportable),
                Map.entry("disclosure", reportable
                        ? buildDisclosure()
                        : "")
        );
    }

    private String buildDisclosure() {
        switch (entityId) {
            case "SG":
                return "MAS Notice FAA: Past performance is not indicative of future results.";
            case "HK":
                return "SFC COP: Past performance is not indicative of future results.";
            case "CH":
                return "FINMA LSFin: Past performance is not indicative of future results.";
            default:
                return regulator + ": Past performance is not indicative of future results.";
        }
    }
}