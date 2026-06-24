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

    private final EntityContext entity = EntityContext.load();

    @PostMapping("/value")
    public Map<String, Object> valuePortfolio(@RequestBody Map<String, Object> request) {
        BigDecimal marketValue = new BigDecimal(request.get("marketValue").toString());

        BigDecimal feeRate = entity.feeBps().divide(new BigDecimal("10000"), 6, RoundingMode.HALF_UP);
        BigDecimal managementFee = marketValue.multiply(feeRate).setScale(2, RoundingMode.HALF_UP);
        boolean reportable = marketValue.compareTo(entity.minimumAumThreshold()) >= 0;

        String disclosure = reportable ? entity.disclosureText() : "";

        return Map.ofEntries(
                Map.entry("portfolioId",        request.get("portfolioId")),
                Map.entry("entityCode",          entity.entityId()),
                Map.entry("currency",            entity.currencyCode()),
                Map.entry("locale",              entity.defaultLocale()),
                Map.entry("regulator",           entity.primaryRegulator()),
                Map.entry("bookingCentre",       entity.bookingCentre()),
                Map.entry("marketValue",         marketValue),
                Map.entry("managementFee",       managementFee),
                Map.entry("managementFeeBps",    entity.feeBps()),
                Map.entry("reportable",          reportable),
                Map.entry("disclosure",          disclosure)
        );
    }
}