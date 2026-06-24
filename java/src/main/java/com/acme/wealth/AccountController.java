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

    // Hardcoded Singapore deployment — refactoring target for multi-entity config
    private static final Currency CURRENCY = Currency.getInstance("SGD");
    private static final Locale LOCALE = new Locale("en", "SG");
    private static final String REGULATOR = "MAS";
    private static final String BOOKING_CENTRE = "Singapore";
    private static final BigDecimal MGMT_FEE_BPS = new BigDecimal("50");
    private static final BigDecimal LARGE_POSITION_THRESHOLD = new BigDecimal("250000");

    @PostMapping("/value")
    public Map<String, Object> valuePortfolio(@RequestBody Map<String, Object> request) {
        BigDecimal marketValue = new BigDecimal(request.get("marketValue").toString());

        BigDecimal feeRate = MGMT_FEE_BPS.divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue.multiply(feeRate).setScale(2, RoundingMode.HALF_UP);
        boolean reportable = marketValue.compareTo(LARGE_POSITION_THRESHOLD) >= 0;

        return Map.ofEntries(
                Map.entry("portfolioId", request.get("portfolioId")),
                Map.entry("entityCode", "SG"),
                Map.entry("currency", CURRENCY.getCurrencyCode()),
                Map.entry("locale", LOCALE.toString()),
                Map.entry("regulator", REGULATOR),
                Map.entry("bookingCentre", BOOKING_CENTRE),
                Map.entry("marketValue", marketValue),
                Map.entry("managementFee", managementFee),
                Map.entry("managementFeeBps", MGMT_FEE_BPS),
                Map.entry("reportable", reportable),
                Map.entry("disclosure", reportable
                        ? "MAS Notice FAA: Past performance is not indicative of future results."
                        : "")
        );
    }
}
